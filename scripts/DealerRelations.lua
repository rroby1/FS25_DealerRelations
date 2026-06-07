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
DealerRelations.version = "0.6.0"

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

    DealerRelations.log("Savegame callback registered")

    -- Load persisted Dealer Relations data from the active savegame.
    -- If no data exists, default values remain in use.
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        DealerRelations.Persistence:load(g_currentMission.missionInfo.savegameDirectory)
    end
	
		DealerRelations.Equipment:discover()
end

-------------------------------------------------------------------------------
-- Called during the game's save process.
--
-- Persists Dealer Relations data to the active savegame directory.
-------------------------------------------------------------------------------
function DealerRelations.saveSavegame()
    DealerRelations.log("Savegame callback fired")

    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        DealerRelations.warning("Cannot save: missionInfo is nil")
        return
    end

    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    DealerRelations.Persistence:save(savegameDirectory)
		
end

-------------------------------------------------------------------------------
-- Register Dealer Relations as a mod event listener.
-------------------------------------------------------------------------------
addModEventListener(DealerRelations)