-------------------------------------------------------------------------------
-- DealerRelationsData.lua
--
-- Defines the Dealer Relations data model.
--
-- Contains the default values used when a new savegame is created
-- or when persisted data cannot be loaded.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Data = DealerRelations.Data or {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

DealerRelations.CONSTANTS = {
    MIN_CONFIDENCE = 0,
    MAX_CONFIDENCE = 100
}

-------------------------------------------------------------------------------
-- Data Definition
-------------------------------------------------------------------------------

DealerRelations.dealerData = {
    -- Starting confidence value for a new save or failed XML load.
    confidence = 0,

    -- Last in-game month when the monthly demo check was processed.
    -- A value of 0 means no monthly demo check has been processed yet.
    lastDemoCheckMonth = 0
}

-------------------------------------------------------------------------------
-- Internal Helpers
-------------------------------------------------------------------------------

function DealerRelations.Data:clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

-------------------------------------------------------------------------------
-- Confidence
-------------------------------------------------------------------------------

function DealerRelations.Data:getConfidence()
    return DealerRelations.dealerData.confidence
end

function DealerRelations.Data:setConfidence(value)
    DealerRelations.dealerData.confidence = self:clamp(
        value,
        DealerRelations.CONSTANTS.MIN_CONFIDENCE,
        DealerRelations.CONSTANTS.MAX_CONFIDENCE
    )
end

-------------------------------------------------------------------------------
-- Relationship Level
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns the relationship level derived from the current confidence value.
--
-- Relationship level is calculated at runtime and is not stored directly.
--
-- @return number Derived relationship level.
-------------------------------------------------------------------------------
function DealerRelations.Data:getRelationshipLevel()
    local confidence = self:getConfidence()

    if confidence >= 80 then
        return 5
    elseif confidence >= 60 then
        return 4
    elseif confidence >= 40 then
        return 3
    elseif confidence >= 20 then
        return 2
    elseif confidence >= 10 then
        return 1
    end

    return 0
end

-------------------------------------------------------------------------------
-- Monthly Demo Check Data
-------------------------------------------------------------------------------

function DealerRelations.Data:getLastDemoCheckMonth()
    return DealerRelations.dealerData.lastDemoCheckMonth
end

function DealerRelations.Data:setLastDemoCheckMonth(month)
    DealerRelations.dealerData.lastDemoCheckMonth = tonumber(month) or 0
end