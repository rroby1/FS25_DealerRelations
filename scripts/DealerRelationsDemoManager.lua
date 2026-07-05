-------------------------------------------------------------------------------
-- DealerRelationsDemoManager.lua
--
-- Handles Dealer Relations demo vehicle functionality.
--
-- Responsibilities:
-- * Spawn accepted demo offer vehicles
-- * Set demo vehicles to mission property state
-- * Track active demo vehicle unique IDs
-- * Detect demo expiration
-- * Support demo return and purchase workflows
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Demo Lifecycle
--
-- ACTIVE
--     Demo is currently within its evaluation period.
--
-- EXPIRED
--     Demo period has ended. Awaiting player action.
--
-- RETURNED
--     Demo vehicle returned to dealer and removed from game.
--
-- PURCHASED
--     Demo vehicle purchased by player and converted to owned equipment.
-------------------------------------------------------------------------------

DealerRelations.DemoManager = {}

-------------------------------------------------------------------------------
-- Spawns a demo vehicle from an accepted demo offer.
--
-- Creates the vehicle, assigns it to the current farm, and sets MISSION
-- property state to prevent selling, repairing, repainting, or shop
-- modifications. Loading is asynchronous; onPrimaryDemoVehicleLoaded()
-- completes the setup once the vehicle is available, and continues on to
-- load the companion vehicle (e.g. a header's trailer) if the offer has one.
--
-- @param offer table Active demo offer data.
-- @return boolean True if loading was initiated, false if validation failed.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:startDemoFromOffer(offer)
    if offer == nil then
        DealerRelations.warning("Cannot start demo: offer is nil")
        return false
    end

    if offer.xmlFilename == nil then
        DealerRelations.warning("Cannot start demo: offer xmlFilename is nil")
        return false
    end

    -- Confirm room exists for the primary AND (if present) the companion
    -- BEFORE reserving or spawning either one.
    if not self:isDualSpawnSpaceAvailable(offer.xmlFilename, offer.companionXmlFilename) then
        DealerRelations.warning("Cannot start demo: no free shop loading place available")
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: No space available at the shop right now. Try accepting the offer again later."
        )
        return false
    end

    local farmId = self:getDemoOwnerFarmId()

    -- Shared tracking for this spawn group. Both vehicles (if there's a
    -- companion) have their loading place reserved sequentially, BEFORE
    -- either one is actually loaded -- mirroring
    -- AbstractMission:spawnVehicles()'s real loop, which calls
    -- setLoadingPlace() back-to-back for every vehicle in a mission's
    -- borrowed set before any of them finish loading asynchronously. This
    -- is the actual fix for the header/trailer overlap: the previous
    -- "load primary, then start companion afterward" sequencing placed
    -- the companion against a world where the primary hadn't necessarily
    -- settled/registered yet, unlike this proven, already-working pattern.
    local spawnGroup = {
        offer = offer,
        allLoadingData = {},
        pendingLoadingData = {},
        pendingCount = 0,
        failed = false,
        loadedVehicles = {},
    }

    DealerRelations.log(string.format(
        "Starting demo vehicle: %s",
        tostring(offer.xmlFilename)
    ))

    local primaryData = VehicleLoadingData.new()
    primaryData:setFilename(offer.xmlFilename)
    primaryData:setPropertyState(VehiclePropertyState.MISSION)
    primaryData:setOwnerFarmId(farmId)

    if not primaryData:setLoadingPlace(g_currentMission.storeSpawnPlaces, g_currentMission.usedStorePlaces) then
        -- Shouldn't happen given isDualSpawnSpaceAvailable just confirmed
        -- capacity, but handled defensively in case something else
        -- claimed a spot in the brief window between the dry run and now.
        DealerRelations.warning("Cannot start demo: shop loading place became unavailable")
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: No space available at the shop right now. Try accepting the offer again later."
        )
        return false
    end

    table.insert(spawnGroup.allLoadingData, primaryData)
    table.insert(spawnGroup.pendingLoadingData, primaryData)

    local companionData = nil

    if offer.companionXmlFilename ~= nil then
        DealerRelations.log(string.format(
            "Starting companion demo vehicle: %s",
            tostring(offer.companionXmlFilename)
        ))

        companionData = VehicleLoadingData.new()
        companionData:setFilename(offer.companionXmlFilename)
        companionData:setPropertyState(VehiclePropertyState.MISSION)
        companionData:setOwnerFarmId(farmId)

        if not companionData:setLoadingPlace(g_currentMission.storeSpawnPlaces, g_currentMission.usedStorePlaces) then
            DealerRelations.warning("Cannot start demo: shop loading place became unavailable for companion equipment")
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                "Dealer Relations: No space available at the shop right now. Try accepting the offer again later."
            )
            return false
        end

        table.insert(spawnGroup.allLoadingData, companionData)
        table.insert(spawnGroup.pendingLoadingData, companionData)
    end

    spawnGroup.pendingCount = #spawnGroup.allLoadingData

    -- Begin asynchronous loading for both -- only now, after both spots
    -- are genuinely reserved, matching AbstractMission's sequencing.
    primaryData:load(
        DealerRelations.DemoManager.onGroupVehicleLoaded,
        DealerRelations.DemoManager,
        { spawnGroup = spawnGroup, role = "PRIMARY", loadingData = primaryData }
    )

    if companionData ~= nil then
        companionData:load(
            DealerRelations.DemoManager.onGroupVehicleLoaded,
            DealerRelations.DemoManager,
            { spawnGroup = spawnGroup, role = "SECONDARY", loadingData = companionData }
        )
    end

    return true
end

-------------------------------------------------------------------------------
-- Finalizes a demo start once all of its vehicles (primary, and companion
-- if any) have finished loading successfully.
--
-- Clears the pending offer, applies the accept confidence bonus, and
-- refreshes the Overview screen if open. Split out from the loading
-- callbacks so both the "no companion" and "companion loaded" paths finish
-- the same way.
--
-- @param offer table Active demo offer data.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:finishDemoStart(offer)
    DealerRelations.Data:clearActiveDemoOffer()

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_ACCEPT_DEMO,
        "Accepted demo offer"
    )

    -- Refresh the Overview screen if it is currently open.
    -- Rationale:
    -- Vehicle loading is asynchronous. The Overview must be refreshed here,
    -- after the offer is cleared and demo is recorded, not at the point of
    -- the button click where the data has not changed yet.
    if DealerRelations.Screen ~= nil and DealerRelations.Screen.instance ~= nil then
        DealerRelations.Screen.instance:updateOverviewValues()
    end

    DealerRelations.log(string.format(
        "Active demo count: %d",
        #DealerRelations.dealerData.activeDemoVehicles
    ))
end

-- Gets the farm ID that should own the spawned demo vehicle.
-- Rationale: demo spawning should always attach the machine to a valid farm.
-- If the current mission reports no farm or spectator farm, fall back to the
-- single-player farm so the vehicle is usable in normal gameplay.
function DealerRelations.DemoManager:getDemoOwnerFarmId()
    local farmId = g_currentMission:getFarmId()

    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        farmId = FarmManager.SINGLEPLAYER_FARM_ID
    end

    return farmId
end

-------------------------------------------------------------------------------
-- Checks all active demo vehicles for expiration.
--
-- A demo expires when the current game month reaches or exceeds the
-- vehicle's configured end month.
--
-- Only PRIMARY records are evaluated -- a SECONDARY (e.g. a header's
-- trailer) has no independent expiration clock of its own and always
-- follows the primary's state instead. This is an explicit role check,
-- not reliance on nil fields: startOperatingHours/operatingHourLimit/
-- endMonth default to 0 (not nil) once a SECONDARY record round-trips
-- through a save/reload, which would otherwise make it appear expired
-- immediately.
--
-- Expired demos are not removed automatically. They remain open and continue
-- blocking new demo offers until the player chooses Return or Buy.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkExpiredDemos()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    -- Note: currentPeriod is 1-based from March, not January.
    -- Period 1 = March, Period 12 = February.
    local currentMonth = g_currentMission.environment.currentPeriod
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)
    local currentDay = g_currentMission.environment.currentDay

    for _, demoVehicle in ipairs(activeDemoVehicles) do

        if demoVehicle.state == "ACTIVE" and demoVehicle.role == "PRIMARY" then

            -- Check month-end expiration.
            local monthExpired = demoVehicle.endMonth ~= nil
                and currentMonth >= demoVehicle.endMonth

            -- Check operating-hour expiration.
            local hoursExpired = false

            if demoVehicle.startOperatingHours ~= nil
                and demoVehicle.operatingHourLimit ~= nil then

                local vehicle = self:findVehicleByUniqueId(demoVehicle.uniqueId)

                if vehicle ~= nil then
                    local currentHours = vehicle:getOperatingTime() / (1000 * 60 * 60)
                    local hoursUsed = currentHours - demoVehicle.startOperatingHours
                    hoursExpired = hoursUsed >= demoVehicle.operatingHourLimit
                end
            end

            if monthExpired or hoursExpired then
                demoVehicle.state = "EXPIRED"

                -- Set the overdue clock start day using the noon rule.
                -- Before noon: tonight's dealer close is Miss 1.
                -- Noon or after: tomorrow's dealer close is Miss 1.
                if currentHour < DealerRelations.CONSTANTS.OVERDUE_GRACE_CUTOFF_HOUR then
                    DealerRelations.Data:setDemoOverdueClockStartDay(demoVehicle, currentDay)
                else
                    DealerRelations.Data:setDemoOverdueClockStartDay(demoVehicle, currentDay + 1)
                end

                -- Cascade to the companion, if any -- it follows the
                -- primary's state rather than tracking its own expiration.
                local secondary = self:findSecondaryDemoVehicle()
                if secondary ~= nil then
                    secondary.state = "EXPIRED"
                end

                DealerRelations.log(string.format(
                    "Demo expired: %s (reason=%s, overdueClockStartDay=%d)",
                    tostring(demoVehicle.name),
                    monthExpired and "month-end" or "operating-hours",
                    DealerRelations.Data:getDemoOverdueClockStartDay(demoVehicle)
                ))
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Checks whether any active demo has exceeded its operating hour limit.
--
-- Rationale:
-- Operating-hour expiration must be checked every update cycle, not just
-- at month change. This allows demos to expire mid-month when the player
-- has consumed their allotted hours.
--
-- Only PRIMARY records are evaluated -- see checkExpiredDemos() for why.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkDemoOperatingHours()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)
    local currentDay = g_currentMission.environment.currentDay

    for _, demoVehicle in ipairs(activeDemoVehicles) do

        if demoVehicle.state == "ACTIVE"
            and demoVehicle.role == "PRIMARY"
            and demoVehicle.startOperatingHours ~= nil
            and demoVehicle.operatingHourLimit ~= nil then

            local vehicle = self:findVehicleByUniqueId(demoVehicle.uniqueId)

            if vehicle ~= nil then
                local currentHours = vehicle:getOperatingTime() / (1000 * 60 * 60)
                local hoursUsed = currentHours - demoVehicle.startOperatingHours

                if hoursUsed >= demoVehicle.operatingHourLimit then
                    demoVehicle.state = "EXPIRED"

                    -- Set the overdue clock start day using the noon rule.
                    -- Before noon: tonight's dealer close is Miss 1.
                    -- Noon or after: tomorrow's dealer close is Miss 1.
                    if currentHour < DealerRelations.CONSTANTS.OVERDUE_GRACE_CUTOFF_HOUR then
                        DealerRelations.Data:setDemoOverdueClockStartDay(demoVehicle, currentDay)
                    else
                        DealerRelations.Data:setDemoOverdueClockStartDay(demoVehicle, currentDay + 1)
                    end

                    -- Cascade to the companion, if any.
                    local secondary = self:findSecondaryDemoVehicle()
                    if secondary ~= nil then
                        secondary.state = "EXPIRED"
                    end

                    DealerRelations.log(string.format(
                        "Demo expired: %s (reason=operating-hours, overdueClockStartDay=%d)",
                        tostring(demoVehicle.name),
                        DealerRelations.Data:getDemoOverdueClockStartDay(demoVehicle)
                    ))
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Checks whether any active demo needs the 5 PM final-day notice.
--
-- This notice is intentionally separate from expiration. The demo may expire
-- at the month transition, but the player-facing warning should happen during
-- a visible play window so it is not missed while sleeping through the night.
--
-- Only PRIMARY records trigger this -- a demo unit gets one notice, named
-- after the primary, not one per vehicle in the pair.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkEndingDemoNotices()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    -- Note: currentPeriod is 1-based from March, not January.
    -- Period 1 = March, Period 12 = February.
    local currentMonth = g_currentMission.environment.currentPeriod

    -- FS stores dayTime as milliseconds since midnight.
    -- Converting to a whole hour gives us a simple "at or after 5 PM" check.
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)

    for _, demoVehicle in ipairs(activeDemoVehicles) do

        -- The demo is still active during the month before endMonth.
        -- Example: startMonth=3, endMonth=4 means month 3 is the final
        -- active month, and month 4 is when the demo becomes expired.
        local isFinalDemoMonth = demoVehicle.endMonth ~= nil
            and currentMonth == demoVehicle.endMonth - 1

        if demoVehicle.state == "ACTIVE"
            and demoVehicle.role == "PRIMARY"
            and isFinalDemoMonth
            and demoVehicle.endingNoticeSent ~= true
            and currentHour >= 17 then

            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                string.format(
                    "Dealer Relations: Demo for %s ends today. Return or purchase tomorrow.",
                    tostring(demoVehicle.name)
                )
            )

            -- Mark the notice as sent immediately so it cannot repeat
            -- during later update cycles in the same evening.
            demoVehicle.endingNoticeSent = true

            DealerRelations.log(string.format(
                "Ending notice sent for demo: %s",
                tostring(demoVehicle.name)
            ))
        end
    end
end

-------------------------------------------------------------------------------
-- Checks whether any expired demo needs the 8 AM return notice.
--
-- This notice is intentionally separate from the expiration state change.
-- A demo may expire during a month transition or sleep period, but the player
-- should receive the return reminder during a visible morning play window.
--
-- Only PRIMARY records trigger this -- see checkEndingDemoNotices() for why.
-- A SECONDARY record's state does get cascaded to EXPIRED, so this guard
-- is necessary to avoid a duplicate notice for the same demo unit.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkReturnDemoNotices()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()

    -- FS stores dayTime as milliseconds since midnight.
    -- Converting to a whole hour gives us a simple "at or after 8 AM" check.
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "EXPIRED"
            and demoVehicle.role == "PRIMARY"
            and demoVehicle.returnNoticeSent ~= true
            and currentHour >= 8 then

            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                string.format(
                    "Dealer Relations: Demo for %s has ended. Return or purchase the equipment.",
                    tostring(demoVehicle.name)
                )
            )

            -- Mark the notice as sent immediately so it cannot repeat
            -- during later update cycles after 8 AM.
            demoVehicle.returnNoticeSent = true

            DealerRelations.log(string.format(
                "Return notice sent for expired demo: %s",
                tostring(demoVehicle.name)
            ))
        end
    end
end

-------------------------------------------------------------------------------
-- Removes a demo vehicle from the game world.
--
-- Returns:
-- true  = removal call was made
-- false = vehicle was not valid for removal
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:removeDemoVehicle(vehicle)
    -- Stop if lookup failed before this point.
    -- Rationale: removal must only run against a confirmed vehicle object.
    if vehicle == nil then
        DealerRelations.warning("Cannot remove demo vehicle: vehicle is nil")
        return false
    end

    DealerRelations.log(
        "Removing demo vehicle: " .. tostring(vehicle:getName())
    )

    -- Delete the in-game vehicle object.
    -- Rationale: this is the smallest testable return action.
    -- No Dealer Relations tracking state is changed in this step.
    vehicle:delete()

    DealerRelations.log("Demo vehicle removal call completed")

    return true
end

-------------------------------------------------------------------------------
-- Converts a demo vehicle into an owned vehicle.
--
-- Returns:
-- true  = ownership conversion call was made
-- false = vehicle was not valid for conversion
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:buyDemoVehicle(vehicle)
    -- Stop if lookup failed before this point.
    -- Rationale: buying must only run against a confirmed vehicle object.
    if vehicle == nil then
        DealerRelations.warning("Cannot buy demo vehicle: vehicle is nil")
        return false
    end

    DealerRelations.log(
        "Converting demo vehicle to owned: " .. tostring(vehicle:getName())
    )

    -- Change the in-game property state from MISSION/demo behavior to OWNED.
    -- Rationale: the player is choosing to keep the machine instead of returning it.
    vehicle:setPropertyState(VehiclePropertyState.OWNED)

    DealerRelations.log("Demo vehicle ownership conversion call completed")

    return true
end

-------------------------------------------------------------------------------
-- Checks all expired demo vehicles for overdue consequences.
--
-- Fires at dealer close. Applies escalating consequences for each missed
-- return window. Each level fires exactly once per period via overdueNoticeSent.
--
-- Only PRIMARY records are evaluated -- a SECONDARY record's state does get
-- cascaded to EXPIRED (see checkExpiredDemos/checkDemoOperatingHours), but
-- overdue consequences (confidence hits, fees, suspension, repossession)
-- must only ever apply once per demo unit, not once per vehicle in the pair.
-- At Miss 4, the companion is repossessed alongside the primary.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkOverdueDemos()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)
    local currentDay = g_currentMission.environment.currentDay

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "EXPIRED" and demoVehicle.role == "PRIMARY" then

            -- Only act at dealer close.
            if currentHour >= DealerRelations.CONSTANTS.DEALER_CLOSE_HOUR then

                local clockStartDay = DealerRelations.Data:getDemoOverdueClockStartDay(demoVehicle)

                -- Clock must be set before we can evaluate anything.
                if clockStartDay ~= nil then

                    -- Calculate how many dealer closes have passed since the clock started.
                    local missCount = currentDay - clockStartDay

                    -- Reset the notice flag when missCount has advanced past the
                    -- current overdue level so the next level can fire.
                    local currentOverdueLevel = DealerRelations.Data:getDemoOverdueLevel(demoVehicle)

                    if missCount == DealerRelations.CONSTANTS.OVERDUE_MISS_1
                        and currentOverdueLevel < 1 then

                        DealerRelations.Data:setDemoOverdueLevel(demoVehicle, 1)
                        DealerRelations.Data:setDemoOverdueNoticeSent(demoVehicle, true)

                        g_currentMission:addIngameNotification(
                            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                            string.format(
                                "Dealer Relations: %s is overdue for return. Please return or purchase the equipment.",
                                tostring(demoVehicle.name)
                            )
                        )

                        DealerRelations.log(string.format(
                            "Overdue Miss 1 warning sent for demo: %s",
                            tostring(demoVehicle.name)
                        ))

                    elseif missCount == DealerRelations.CONSTANTS.OVERDUE_MISS_2
                        and currentOverdueLevel < 2 then

                        DealerRelations.Data:setDemoOverdueLevel(demoVehicle, 2)
                        DealerRelations.Data:setDemoOverdueNoticeSent(demoVehicle, true)

                        DealerRelations.Data:addConfidence(
                            DealerRelations.CONSTANTS.OVERDUE_LEVEL_2_CONFIDENCE,
                            "Overdue demo not returned - Miss 2"
                        )

                        DealerRelations.Data:setPendingSuspensionMonths(
                            DealerRelations.CONSTANTS.OVERDUE_LEVEL_2_SUSPENSION_MONTHS
                        )

                        g_currentMission:addIngameNotification(
                            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                            string.format(
                                "Dealer Relations: %s is overdue. Confidence reduced and demo offers suspended for %d month(s).",
                                tostring(demoVehicle.name),
                                DealerRelations.CONSTANTS.OVERDUE_LEVEL_2_SUSPENSION_MONTHS
                            )
                        )

                        DealerRelations.log(string.format(
                            "Overdue Miss 2 applied for demo: %s",
                            tostring(demoVehicle.name)
                        ))

                    elseif missCount == DealerRelations.CONSTANTS.OVERDUE_MISS_3
                        and currentOverdueLevel < 3 then

                        DealerRelations.Data:setDemoOverdueLevel(demoVehicle, 3)
                        DealerRelations.Data:setDemoOverdueNoticeSent(demoVehicle, true)

                        DealerRelations.Data:addConfidence(
                            DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_CONFIDENCE,
                            "Overdue demo not returned - Miss 3"
                        )

                        DealerRelations.Data:setPendingSuspensionMonths(
                            (DealerRelations.Data:getPendingSuspensionMonths() or 0) +
                            DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_SUSPENSION_MONTHS
                        )

                        local farm = g_farmManager:getFarmById(DealerRelations.DemoManager:getDemoOwnerFarmId())
                        local feeAmount = math.floor(
                            (demoVehicle.price or 0) *
                            (DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_FEE_PERCENT / 100)
                        )

                        if farm ~= nil and farm.money >= feeAmount then
                            farm:changeBalance(-feeAmount, "DEALER_RELATIONS_OVERDUE_FEE")

                            g_currentMission:addIngameNotification(
                                FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                                string.format(
                                    "Dealer Relations: %s is overdue. Confidence reduced, demo offers suspended for %d month(s), and a %d%% late fee of $%d has been charged. Return or purchase the equipment or it will be repossessed.",
                                    tostring(demoVehicle.name),
                                    DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_SUSPENSION_MONTHS,
                                    DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_FEE_PERCENT,
                                    feeAmount
                                )
                            )

                            DealerRelations.log(string.format(
                                "Overdue Miss 3 fee applied for demo: %s (fee=%d)",
                                tostring(demoVehicle.name),
                                feeAmount
                            ))
                        else
                            DealerRelations.Data:addConfidence(
                                DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_INSUFFICIENT_FUNDS_CONFIDENCE,
                                "Overdue demo Miss 3 - insufficient funds for fee"
                            )

                            g_currentMission:addIngameNotification(
                                FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                                string.format(
                                    "Dealer Relations: %s is overdue. Confidence reduced and demo offers suspended for %d month(s). Insufficient funds for late fee. Return or purchase the equipment or it will be repossessed.",
                                    tostring(demoVehicle.name),
                                    DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_SUSPENSION_MONTHS
                                )
                            )

                            DealerRelations.log(string.format(
                                "Overdue Miss 3 insufficient funds for demo: %s",
                                tostring(demoVehicle.name)
                            ))
                        end

                    elseif missCount >= DealerRelations.CONSTANTS.OVERDUE_MISS_4
                        and currentOverdueLevel < 4 then

                        DealerRelations.Data:setDemoOverdueLevel(demoVehicle, 4)
                        DealerRelations.Data:setDemoOverdueNoticeSent(demoVehicle, true)

                        DealerRelations.Data:addConfidence(
                            DealerRelations.CONSTANTS.OVERDUE_LEVEL_4_CONFIDENCE,
                            "Overdue demo not returned - Miss 4"
                        )

                        g_currentMission:addIngameNotification(
                            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                            string.format(
                                "Dealer Relations: %s has been repossessed due to non-return.",
                                tostring(demoVehicle.name)
                            )
                        )

                        DealerRelations.log(string.format(
                            "Overdue Miss 4 repossession for demo: %s",
                            tostring(demoVehicle.name)
                        ))

                        DealerRelations.DemoManager:applyPendingSuspension()

                        local vehicle = self:findVehicleByUniqueId(demoVehicle.uniqueId)
                        self:removeDemoVehicle(vehicle)
                        DealerRelations.Data:removeActiveDemoVehicleByUniqueId(demoVehicle.uniqueId)

                        -- Repossess the companion alongside the primary, if
                        -- one exists -- it was never a separate obligation,
                        -- so it doesn't get its own overdue consequences,
                        -- but it does get removed at the same time.
                        local secondary = self:findSecondaryDemoVehicle()
                        if secondary ~= nil then
                            local secondaryVehicle = self:findVehicleByUniqueId(secondary.uniqueId)
                            self:removeDemoVehicle(secondaryVehicle)
                            DealerRelations.Data:removeActiveDemoVehicleByUniqueId(secondary.uniqueId)

                            DealerRelations.log(string.format(
                                "Companion repossessed alongside primary: %s",
                                tostring(secondary.name)
                            ))
                        end

                    end -- end if/elseif miss level chain

                end -- end clockStartDay ~= nil
            end -- end dealer close hour check
        end -- end state == EXPIRED and role == PRIMARY
    end -- end for loop
end

-------------------------------------------------------------------------------
-- Applies any pending suspension earned during the overdue period.
--
-- Called at demo resolution (return, buy, or repossession) so the suspension
-- starts counting from when the demo is resolved, not when the miss fired.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:applyPendingSuspension()
     local pendingSuspensionMonths = DealerRelations.Data:getPendingSuspensionMonths()

    if pendingSuspensionMonths == nil then
        return
    end

    -- Note: currentPeriod is 1-based from March, not January.
    -- Period 1 = March, Period 12 = February.
    local currentMonth = g_currentMission.environment.currentPeriod
    DealerRelations.Data:setSuspensionEndMonth(currentMonth + pendingSuspensionMonths)
    DealerRelations.Data:clearPendingSuspensionMonths()

    DealerRelations.log(string.format(
        "Suspension applied: %d month(s), ends month %d",
        pendingSuspensionMonths,
        DealerRelations.Data:getSuspensionEndMonth()
    ))
end

-------------------------------------------------------------------------------
-- Validates all active demo vehicles against the current store manager.
--
-- Rationale:
-- If the mod providing a demo vehicle has been removed since the last session,
-- the vehicle no longer exists in the game world. The demo record is cleared
-- silently with no confidence penalty or overdue consequences since the player
-- made a mod management decision, not a gameplay decision.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:validateActiveDemo()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    for _, demoVehicle in ipairs(activeDemoVehicles) do
        local storeItem = g_storeManager:getItemByXMLFilename(demoVehicle.xmlFilename)
        if storeItem == nil then
            DealerRelations.log(string.format(
                "Active demo cleared: source mod no longer available (%s)",
                tostring(demoVehicle.xmlFilename)
            ))
            DealerRelations.Data:removeActiveDemoVehicleByUniqueId(demoVehicle.uniqueId)
        end
    end
end

-------------------------------------------------------------------------------
-- Returns the current demo's companion (SECONDARY) record, if one exists.
--
-- Only one demo (offer or active) can exist at a time, so there is never
-- more than one SECONDARY record to disambiguate between -- no separate
-- pairing key is needed beyond the role field itself.
--
-- @return table|nil The SECONDARY demo vehicle record, or nil if none.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:findSecondaryDemoVehicle()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.role == "SECONDARY" then
            return demoVehicle
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Returns the live vehicle object for a given demo vehicle record's
-- uniqueId, or nil if it no longer exists (e.g. deleted, sold, or removed
-- outside of Dealer Relations' own flow).
--
-- Thin wrapper around VehicleSystem:getVehicleByUniqueId(), the game's own
-- native uniqueId lookup.
--
-- @param uniqueId string The demo vehicle record's stored uniqueId.
-- @return table|nil The live vehicle object, or nil if not found.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:findVehicleByUniqueId(uniqueId)
    if uniqueId == nil then
        return nil
    end

    return g_currentMission.vehicleSystem:getVehicleByUniqueId(uniqueId)
end

-------------------------------------------------------------------------------
-- Checks whether room exists for the primary AND (if present) the
-- companion vehicle, using the SAME reserve-then-release pattern
-- AbstractMission:isSpawnSpaceAvailable() uses for mission-borrowed
-- vehicle sets: call PlacementUtil.getPlace()/markPlaceUsed() for real,
-- against the real g_currentMission.usedStorePlaces table, then
-- unmarkPlaceUsed() everything afterward regardless of outcome.
--
-- Confirmed via AbstractMission's real source that unmarkPlaceUsed() is a
-- safe, working way to release a reservation -- this replaces the earlier
-- deep-clone dry-run approach, which existed specifically because we
-- didn't yet know a safe release mechanism was available.
--
-- @param primaryXmlFilename string Primary vehicle's XML filename.
-- @param companionXmlFilename string|nil Companion's XML filename, if any.
-- @return boolean True if room exists for all vehicles in the offer.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:isDualSpawnSpaceAvailable(primaryXmlFilename, companionXmlFilename)
    local places = g_currentMission.storeSpawnPlaces
    local usedPlaces = g_currentMission.usedStorePlaces
    local placesFilled = {}
    local result = true

    local filenames = { primaryXmlFilename }
    if companionXmlFilename ~= nil then
        table.insert(filenames, companionXmlFilename)
    end

    for _, filename in ipairs(filenames) do
        local storeItem = g_storeManager:getItemByXMLFilename(filename)

        if storeItem == nil then
            result = false
            break
        end

        local size = StoreItemUtil.getSizeValues(filename, "vehicle", storeItem.rotation, {})
        size.width = math.max(size.width, VehicleLoadingData.MIN_SPAWN_PLACE_WIDTH)
        size.length = math.max(size.length, VehicleLoadingData.MIN_SPAWN_PLACE_LENGTH)
        size.height = math.max(size.height, VehicleLoadingData.MIN_SPAWN_PLACE_HEIGHT)
        size.width = size.width + VehicleLoadingData.SPAWN_WIDTH_OFFSET

        local x, _, _, place, width, _ = PlacementUtil.getPlace(places, size, usedPlaces, true, true, false, true)

        if x == nil then
            result = false
            break
        end

        PlacementUtil.markPlaceUsed(usedPlaces, place, width)
        table.insert(placesFilled, place)
    end

    for _, place in ipairs(placesFilled) do
        PlacementUtil.unmarkPlaceUsed(usedPlaces, place)
    end

    return result
end

-------------------------------------------------------------------------------
-- Shared callback for every vehicle in a spawn group (primary and, if
-- present, companion). Both loads run in parallel, so this fires once per
-- vehicle as each one completes -- not necessarily in primary-then-
-- companion order.
--
-- On any failure, mirrors AbstractMission:onSpawnedVehicle()'s real
-- pattern: cancel whatever else in the group is still loading, delete
-- whatever already succeeded, and stop -- rather than assuming a simple
-- one-at-a-time rollback, which doesn't hold once loads run concurrently.
--
-- Once every vehicle in the group has reported in successfully, hands off
-- to finalizeSpawnGroup() to create the actual demo vehicle records.
--
-- @param vehicles table List of loaded vehicles returned by the engine.
-- @param loadingState number VehicleLoadingState result code.
-- @param args table { spawnGroup, role, loadingData }.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:onGroupVehicleLoaded(vehicles, loadingState, args)
    local spawnGroup = args.spawnGroup
    local role = args.role
    local loadingData = args.loadingData

    table.removeElement(spawnGroup.pendingLoadingData, loadingData)

    -- Group already failed via the other vehicle -- clean up silently if
    -- this one still managed to load, and stop.
    if spawnGroup.failed then
        if loadingState == VehicleLoadingState.OK and vehicles ~= nil then
            for _, vehicle in ipairs(vehicles) do
                vehicle:delete()
            end
        end
        return
    end

    if loadingState ~= VehicleLoadingState.OK or vehicles == nil or #vehicles == 0 then
        DealerRelations.warning(string.format(
            "Demo vehicle failed to load (role=%s) -- rolling back spawn group",
            tostring(role)
        ))

        spawnGroup.failed = true

        for _, pendingData in ipairs(spawnGroup.pendingLoadingData) do
            pendingData:cancelLoading()
        end

        for _, loaded in ipairs(spawnGroup.loadedVehicles) do
            loaded.vehicle:delete()
        end
        spawnGroup.loadedVehicles = {}

        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: Something went wrong starting the demo. Please try again."
        )

        return
    end

    local vehicle = vehicles[1]
    table.insert(spawnGroup.loadedVehicles, { vehicle = vehicle, role = role })
    spawnGroup.pendingCount = spawnGroup.pendingCount - 1

    if spawnGroup.pendingCount <= 0 then
        self:finalizeSpawnGroup(spawnGroup)
    end
end

-------------------------------------------------------------------------------
-- Creates the activeDemoVehicles record(s) for a fully-loaded spawn group
-- and finalizes the demo start. Only ever called once every vehicle in
-- the group has succeeded -- see onGroupVehicleLoaded().
--
-- Record shapes are unchanged from the original single-callback design:
-- PRIMARY carries the full operating-hour/expiration tracking fields,
-- SECONDARY carries none -- its lifecycle is entirely driven by the
-- primary's state (see checkExpiredDemos and friends).
--
-- @param spawnGroup table The completed spawn group.
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:finalizeSpawnGroup(spawnGroup)
    local offer = spawnGroup.offer

    for _, loaded in ipairs(spawnGroup.loadedVehicles) do
        local vehicle = loaded.vehicle
        local uniqueId = vehicle:getUniqueId()

        if loaded.role == "PRIMARY" then
            DealerRelations.log(string.format(
                "Demo vehicle loaded successfully. uniqueId=%s",
                tostring(uniqueId)
            ))

            DealerRelations.Data:addActiveDemoVehicle({
                uniqueId = uniqueId,
                name = offer.name,
                brand = offer.brand,
                xmlFilename = offer.xmlFilename,
                imageFilename = offer.imageFilename,
                price = offer.price,
                startMonth = g_currentMission.environment.currentPeriod,
                endMonth = g_currentMission.environment.currentPeriod + 1,
                state = "ACTIVE",
                role = "PRIMARY",
                startOperatingHours = vehicle:getOperatingTime() / (1000 * 60 * 60),
                operatingHourLimit = DealerRelations.Data:getDemoOperatingHourLimit(),
                endingNoticeSent = false,
                returnNoticeSent = false,
                overdueNoticeSent = false,
            })
        else
            DealerRelations.log(string.format(
                "Companion demo vehicle loaded successfully. uniqueId=%s",
                tostring(uniqueId)
            ))

            DealerRelations.Data:addActiveDemoVehicle({
                uniqueId = uniqueId,
                name = offer.companionName,
                brand = offer.companionBrand,
                xmlFilename = offer.companionXmlFilename,
                price = offer.companionPrice,
                state = "ACTIVE",
                role = "SECONDARY",
            })
        end
    end

    self:finishDemoStart(offer)
end
