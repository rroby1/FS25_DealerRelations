-------------------------------------------------------------------------------
-- DealerRelations.lua
--
-- Main entry point for the Dealer Relations mod.
--
-- Responsibilities:
--   * Load supporting modules
--   * Register mod event listeners
--   * Coordinate initialization
--
-- This file should remain small and primarily act as the
-- orchestration layer for the mod.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}

-- Current mod version displayed in startup logging.
DealerRelations.version = "0.7.0"

-------------------------------------------------------------------------------
-- Load supporting modules.
--
-- These files are loaded here rather than in modDesc.xml to keep
-- modDesc compact and centralize module dependencies.
-------------------------------------------------------------------------------
source(g_currentModDirectory .. "scripts/DealerRelationsDebug.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsData.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsPersistence.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsEquipment.lua")

-------------------------------------------------------------------------------
-- Called by the game when a map is loaded.
--
-- Registers Dealer Relations callbacks and loads persisted
-- Dealer Relations data from the active savegame.
-------------------------------------------------------------------------------
function DealerRelations:loadMap()
    DealerRelations.log("Version " .. DealerRelations.version .. " loaded")

    -- Register a callback that will be invoked whenever the game saves.
    -- This allows Dealer Relations data to be persisted alongside the
    -- normal Farming Simulator save process.
    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        DealerRelations.saveSavegame
    )

    -- Load persisted Dealer Relations data from the active savegame.
    -- If no data exists, default values remain in use.
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        DealerRelations.Persistence:load(g_currentMission.missionInfo.savegameDirectory)
    end

    -- Build the eligible equipment list.
    DealerRelations.Equipment:discover()
end

-------------------------------------------------------------------------------
-- Called during the game's save process.
--
-- Persists Dealer Relations data to the active savegame directory.
-------------------------------------------------------------------------------
function DealerRelations.saveSavegame()
    
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        DealerRelations.warning("Cannot save: missionInfo is nil")
        return
    end

    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    DealerRelations.Persistence:save(savegameDirectory)
end

-------------------------------------------------------------------------------
-- Monthly Demo Check
-------------------------------------------------------------------------------

-- Checks whether a monthly demo evaluation should occur.
function DealerRelations:checkMonthlyDemo()
    local currentMonth = g_currentMission.environment.currentPeriod
    local lastMonth = DealerRelations.Data:getLastDemoCheckMonth()

    if currentMonth ~= lastMonth then
        DealerRelations.Data:setLastDemoCheckMonth(currentMonth)

        DealerRelations.log(string.format(
            "Monthly demo check triggered for month %d",
            currentMonth
        ))

        local candidate = DealerRelations.Equipment:getRandomDemoCandidate()

        if candidate == nil then
            DealerRelations.warning("Monthly demo check did not select a candidate")
        end
    end
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function DealerRelations:update(dt)
    self:checkMonthlyDemo()
end

-------------------------------------------------------------------------------
-- Register Dealer Relations as a mod event listener.
-------------------------------------------------------------------------------
addModEventListener(DealerRelations)