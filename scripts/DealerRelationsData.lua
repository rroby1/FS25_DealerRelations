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
--
-- Defines the valid ranges for Dealer Relations values.
-------------------------------------------------------------------------------

DealerRelations.CONSTANTS = {
    MIN_RELATIONSHIP_LEVEL = 0,
    MAX_RELATIONSHIP_LEVEL = 5,

    MIN_CONFIDENCE = 0,
    MAX_CONFIDENCE = 100
}

-------------------------------------------------------------------------------
-- Data Definition
-------------------------------------------------------------------------------

DealerRelations.dealerData = {
    -- Starting relationship level for a new save or failed XML load.
    relationshipLevel = 0,

    -- Starting confidence value for a new save or failed XML load.
    confidence = 0
}

-------------------------------------------------------------------------------
-- Internal Helpers
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Clamps a numeric value between a minimum and maximum value.
--
-- @param value number Value to clamp.
-- @param minValue number Minimum allowed value.
-- @param maxValue number Maximum allowed value.
--
-- @return number Clamped value.
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
-- Relationship Level
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns the current relationship level.
--
-- @return number Current relationship level.
-------------------------------------------------------------------------------
function DealerRelations.Data:getRelationshipLevel()
    return DealerRelations.dealerData.relationshipLevel
end

-------------------------------------------------------------------------------
-- Sets the relationship level.
--
-- Relationship level is limited to the configured valid range.
--
-- @param value number New relationship level.
-------------------------------------------------------------------------------
function DealerRelations.Data:setRelationshipLevel(value)
    DealerRelations.dealerData.relationshipLevel = self:clamp(
        value,
        DealerRelations.CONSTANTS.MIN_RELATIONSHIP_LEVEL,
        DealerRelations.CONSTANTS.MAX_RELATIONSHIP_LEVEL
    )
end

-------------------------------------------------------------------------------
-- Confidence
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns the current confidence value.
--
-- @return number Current confidence value.
-------------------------------------------------------------------------------
function DealerRelations.Data:getConfidence()
    return DealerRelations.dealerData.confidence
end

-------------------------------------------------------------------------------
-- Sets the confidence value.
--
-- Confidence is limited to the configured valid range.
--
-- @param value number New confidence value.
-------------------------------------------------------------------------------
function DealerRelations.Data:setConfidence(value)
    DealerRelations.dealerData.confidence = self:clamp(
        value,
        DealerRelations.CONSTANTS.MIN_CONFIDENCE,
        DealerRelations.CONSTANTS.MAX_CONFIDENCE
    )
end