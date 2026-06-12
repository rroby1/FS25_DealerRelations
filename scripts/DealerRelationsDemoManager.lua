------------------------------------------------------------------------------
-- DealerRelationsDemoManager.lua
--
-- Handles Dealer Relations demo vehicle functionality.
--
-- Responsibilities:
--   * Spawn accepted demo offer vehicles
--   * Set demo vehicles to mission property state
--   * Track active demo vehicle unique IDs
--   * Support future demo expiration and return handling
------------------------------------------------------------------------------

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

    -- Get the current farm ID.
    -- If no valid farm is available, fall back to the single-player farm.
    local farmId = g_currentMission:getFarmId()

    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        farmId = FarmManager.SINGLEPLAYER_FARM_ID
    end

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

    -- Temporary test spawn location near the vehicle dealer.
    -- This will be replaced later with a proper dealer spawn point.
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
        role = "PRIMARY"
    })
    
    DealerRelations.Data:clearActiveDemoOffer()
    
    DealerRelations.log(string.format(
        "Active demo count: %d",
        #DealerRelations.dealerData.activeDemoVehicles
    ))

    -- TODO v0.10.0:
    -- Save active demo information to dealerRelations.xml.
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