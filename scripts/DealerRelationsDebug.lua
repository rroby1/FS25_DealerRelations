-------------------------------------------------------------------------------
-- DealerRelationsDebug.lua
--
-- Provides logging utilities used throughout the mod.
-- Debug logging can be enabled or disabled globally.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}

DealerRelations.debug = true

-------------------------------------------------------------------------------
-- Writes a debug message to the log when debug mode is enabled.
--
-- @param message string Message to write to the game log.
-------------------------------------------------------------------------------
function DealerRelations.log(message)
    if DealerRelations.debug then
        print("[DealerRelations] " .. tostring(message))
    end
end

-------------------------------------------------------------------------------
-- Writes a warning message to the log unconditionally.
-- Warning messages are always printed regardless of debug mode.
--
-- @param message string Message to write to the game log.
-------------------------------------------------------------------------------
function DealerRelations.warning(message)
    print("[DealerRelations WARNING] " .. tostring(message))
end