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
    lastDemoCheckMonth = 0,
	
	-- Recently selected demo candidate keys.
    -- Used to prevent the same equipment configuration from being
    -- offered repeatedly within a short period of time.
	recentDemoCandidates = {},
	
	-- Currently active demo offer.
    -- Only one offer may exist at a time.
    -- Nil indicates no active offer is available.
    activeDemoOffer = nil
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

-------------------------------------------------------------------------------
-- Recent Demo Candidates
-------------------------------------------------------------------------------

-- Returns the list of recently selected demo candidate keys.
--
-- Used by duplicate prevention logic to avoid offering the same
-- equipment configuration repeatedly within a short period of time.
--
-- @return table List of recent demo candidate keys.
-------------------------------------------------------------------------------

function DealerRelations.Data:getRecentDemoCandidates()
    return DealerRelations.dealerData.recentDemoCandidates
end

-------------------------------------------------------------------------------
-- Adds a demo candidate key to the recent candidates list.
--
-- The list is maintained as a fixed-size history. Older entries
-- are removed when the maximum history size is exceeded.
--
-- @param candidateKey string Unique key identifying the selected
--                           demo candidate.
-------------------------------------------------------------------------------

function DealerRelations.Data:addRecentDemoCandidate(candidateKey)
    table.insert(DealerRelations.dealerData.recentDemoCandidates, candidateKey)

    while #DealerRelations.dealerData.recentDemoCandidates > 5 do
        table.remove(DealerRelations.dealerData.recentDemoCandidates, 1)
    end
end

-------------------------------------------------------------------------------
-- Checks whether a demo candidate key exists in the recent
-- candidates history.
--
-- @param candidateKey string Unique key identifying the selected
--                           demo candidate.
--
-- @return boolean True if the candidate was recently offered.
-------------------------------------------------------------------------------

function DealerRelations.Data:isRecentDemoCandidate(candidateKey)
    for _, recentKey in ipairs(DealerRelations.dealerData.recentDemoCandidates) do
        if recentKey == candidateKey then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Active Demo Offer
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns the currently active demo offer.
--
-- An active demo offer represents equipment that has been offered
-- to the player for evaluation. Only one active offer may exist
-- at a time.
--
-- @return table|nil Active demo offer data, or nil if no offer exists.
-------------------------------------------------------------------------------
function DealerRelations.Data:getActiveDemoOffer()
    return DealerRelations.dealerData.activeDemoOffer
end

-------------------------------------------------------------------------------
-- Stores the active demo offer.
--
-- Replaces any existing active offer.
--
-- @param offer table Demo offer data to store.
-------------------------------------------------------------------------------
function DealerRelations.Data:setActiveDemoOffer(offer)
    DealerRelations.dealerData.activeDemoOffer = offer
end

-------------------------------------------------------------------------------
-- Clears the currently active demo offer.
--
-- Used when an offer expires, is declined, or is otherwise removed
-- from the system.
-------------------------------------------------------------------------------
function DealerRelations.Data:clearActiveDemoOffer()
    DealerRelations.dealerData.activeDemoOffer = nil
end

-------------------------------------------------------------------------------
-- Returns whether an active demo offer currently exists.
--
-- @return boolean True when an active offer is present.
-------------------------------------------------------------------------------
function DealerRelations.Data:hasActiveDemoOffer()
    return DealerRelations.dealerData.activeDemoOffer ~= nil
end