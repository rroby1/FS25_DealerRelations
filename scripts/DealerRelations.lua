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

DealerRelations.version = "0.1.0"

-- Load supporting modules.
-- These files are loaded here rather than in modDesc.xml
-- to keep the modDesc compact and centralize dependencies.
source(g_currentModDirectory .. "scripts/DealerRelationsDebug.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsData.lua")

function DealerRelations:loadMap()
    DealerRelations.log("Version " .. DealerRelations.version .. " loaded")
end

addModEventListener(DealerRelations)