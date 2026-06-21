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
        startMonth = g_currentMission.environment.currentPeriod,
        endMonth = g_currentMission.environment.currentPeriod + 1,
        state = "ACTIVE",
        role = "PRIMARY",

        -- Tracks whether the final-day 5 PM warning has already been shown.
        -- This prevents the reminder from repeating every update cycle.
        endingNoticeSent = false,

        -- Tracks whether the post-expiration 8 AM return reminder has been shown.
        -- Prevents the return reminder from repeating after it has been shown..
        returnNoticeSent = false
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
    local currentMonth = g_currentMission.environment.currentPeriod

    for _, demoVehicle in ipairs(activeDemoVehicles) do

        -- Only active demos should transition to expired.
        -- This prevents the same expired demo from logging every update cycle.
        if demoVehicle.state == "ACTIVE"
            and demoVehicle.endMonth ~= nil
            and currentMonth >= demoVehicle.endMonth then

            -- Keep the demo record, but mark it unresolved.
            -- This is the "open demo" state that blocks future offers.
            demoVehicle.state = "EXPIRED"

            DealerRelations.log(string.format(
                "Demo expired and remains open: %s (uniqueId=%s)",
                tostring(demoVehicle.name),
                tostring(demoVehicle.uniqueId)
            ))

            -- Confirm whether the expired demo vehicle still exists in-game.
            -- Removal will happen later from the Return dialog, not here.
            local vehicle = self:findVehicleByUniqueId(demoVehicle.uniqueId)

            if vehicle ~= nil then
                DealerRelations.log(string.format(
                    "Found expired demo vehicle: %s",
                    tostring(vehicle:getName())
                ))
            else
                DealerRelations.warning(string.format(
                    "Could not find expired demo vehicle: %s",
                    tostring(demoVehicle.uniqueId)
                ))
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
                    "Dealer Relations: Demo for %s has ended. Return or purchase the machine.",
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