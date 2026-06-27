------------------------------------------------------------------------------
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
------------------------------------------------------------------------------

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

-- Starts a demo machine from an accepted demo offer.
-- Creates the vehicle, spawns it near the dealer,
-- and marks it as a mission vehicle so it cannot
-- be sold, modified, repaired, or repainted.
function DealerRelations.DemoManager:startDemoFromOffer(offer)

    -- Validate the offer data before attempting to load a vehicle.
    if offer == nil then
        DealerRelations.warning("Cannot start demo: offer is nil")
        return false
    end

    -- The vehicle XML path is required to load the machine.
    if offer.xmlFilename == nil then
        DealerRelations.warning("Cannot start demo: offer xmlFilename is nil")
        return false
    end

    local farmId = self:getDemoOwnerFarmId()

    DealerRelations.log(string.format(
        "Starting demo vehicle: %s",
        tostring(offer.xmlFilename)
    ))

    -- Create vehicle loading data for the demo machine.
    local data = VehicleLoadingData.new()

    -- Load the vehicle from the store item XML.
    data:setFilename(offer.xmlFilename)

    -- Use MISSION property state to prevent selling,
    -- repairing, repainting, and shop modifications.
    data:setPropertyState(VehiclePropertyState.MISSION)

    -- Assign the vehicle to the current farm.
    data:setOwnerFarmId(farmId)

    -- Spawn the demo near the dealer area.
    -- A configurable dealer spawn point can replace this later.
    data:setPosition(-120, nil, -135, 0.2)

    -- Spawn facing north for now.
    -- Rotation can be adjusted later if needed.
    data:setRotation(0, 0, 0)

    -- Begin asynchronous vehicle loading.
    data:load(
        DealerRelations.DemoManager.onDemoVehicleLoaded,
        DealerRelations.DemoManager,
        {
            offer = offer
        }
    )

    return true
end

-- Called when the demo vehicle finishes loading.
function DealerRelations.DemoManager:onDemoVehicleLoaded(vehicles, loadingState, args)

    -- Loading failed.
    if loadingState ~= VehicleLoadingState.OK then
        DealerRelations.warning("Demo vehicle failed to load")
        return
    end

    -- No vehicles were returned even though loading succeeded.
    if vehicles == nil or #vehicles == 0 then
        DealerRelations.warning(
            "Demo vehicle load completed but no vehicles were returned"
        )
        return
    end

    -- Retrieve the spawned vehicle.
    local vehicle = vehicles[1]

    -- Store the unique ID for future demo tracking.
    local uniqueId = vehicle:getUniqueId()

    DealerRelations.log(string.format(
        "Demo vehicle loaded successfully. uniqueId=%s",
        tostring(uniqueId)
    ))
    
    -- Record the active demo vehicle.
    DealerRelations.Data:addActiveDemoVehicle({
        uniqueId = uniqueId,
        name = args.offer.name,
        brand = args.offer.brand,
        xmlFilename = args.offer.xmlFilename,
        imageFilename = args.offer.imageFilename,  -- Store image path for Overview display
        price = args.offer.price,  -- Stored for overdue fee calculation at Miss 3
        -- Note: currentPeriod is 1-based from March, not January.
        -- Period 1 = March, Period 12 = February.
        startMonth = g_currentMission.environment.currentPeriod,
        endMonth = g_currentMission.environment.currentPeriod + 1,
        state = "ACTIVE",
        role = "PRIMARY",

        -- Operating hour baseline recorded at demo start.
        -- Rationale:
        -- Demo expiration is based on hours consumed, not calendar time.
        -- Storing the starting hours allows the check to calculate usage
        -- regardless of what the vehicle had accumulated before the demo.
        startOperatingHours = vehicle:getOperatingTime() / (1000 * 60 * 60),
        operatingHourLimit = DealerRelations.Data:getDemoOperatingHourLimit(),

        -- Tracks whether the final-day 5 PM warning has already been shown.
        -- This prevents the reminder from repeating every update cycle.
        endingNoticeSent = false,

        -- Tracks whether the post-expiration 8 AM return reminder has been shown.
        -- Prevents the return reminder from repeating after it has been shown..
        returnNoticeSent = false,

        -- Tracks whether the overdue consequence for the current level has fired.
        -- Reset to false each time the overdue level advances.
        overdueNoticeSent = false,
    })
    
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

        if demoVehicle.state == "ACTIVE" then

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
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkDemoOperatingHours()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)
    local currentDay = g_currentMission.environment.currentDay

    for _, demoVehicle in ipairs(activeDemoVehicles) do

        if demoVehicle.state == "ACTIVE"
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

------------------------------------------------------------------------------
-- Finds a vehicle by unique ID.
--
-- Returns:
--   vehicle if found
--   nil if not found
------------------------------------------------------------------------------
function DealerRelations.DemoManager:findVehicleByUniqueId(uniqueId)
    if uniqueId == nil then
        return nil
    end

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil then
        return nil
    end

    return g_currentMission.vehicleSystem:getVehicleByUniqueId(uniqueId)
end

-------------------------------------------------------------------------------
-- Checks whether any active demo needs the 5 PM final-day notice.
--
-- This notice is intentionally separate from expiration. The demo may expire
-- at the month transition, but the player-facing warning should happen during
-- a visible play window so it is not missed while sleeping through the night.
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
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkReturnDemoNotices()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()

    -- FS stores dayTime as milliseconds since midnight.
    -- Converting to a whole hour gives us a simple "at or after 8 AM" check.
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "EXPIRED"
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
-------------------------------------------------------------------------------
function DealerRelations.DemoManager:checkOverdueDemos()
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local currentHour = math.floor(g_currentMission.environment.dayTime / 1000 / 60 / 60)
    local currentDay = g_currentMission.environment.currentDay

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "EXPIRED" then

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

                        -- Note: currentPeriod is 1-based from March, not January.
                        -- Period 1 = March, Period 12 = February.
                        local currentMonth = g_currentMission.environment.currentPeriod

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

                        -- Note: currentPeriod is 1-based from March, not January.
                        -- Period 1 = March, Period 12 = February.
                        local currentMonth = g_currentMission.environment.currentPeriod
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

                    end -- end if/elseif miss level chain

                end -- end clockStartDay ~= nil
            end -- end dealer close hour check
        end -- end state == EXPIRED
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