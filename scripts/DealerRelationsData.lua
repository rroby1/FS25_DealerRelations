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

activeDemoVehicles = {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

DealerRelations.CONSTANTS = {
    MIN_CONFIDENCE = -100,
    MAX_CONFIDENCE = 100,

    CONFIDENCE_IMPACT_ACCEPT_DEMO = 1,
    CONFIDENCE_IMPACT_DECLINE_DEMO = -1,
    CONFIDENCE_IMPACT_EXPIRE_OFFER = -2,  -- Offer ignored until dealer close
    CONFIDENCE_IMPACT_RETURN_DEMO = 3,
    CONFIDENCE_IMPACT_BUY_DEMO = 5,
    
    RELATIONSHIP_PARTNER_MIN = 80,
    RELATIONSHIP_PREFERRED_MIN = 60,
    RELATIONSHIP_TRUSTED_MIN = 40,
    RELATIONSHIP_FAMILIAR_MIN = 20,
    RELATIONSHIP_NEUTRAL_MIN = 0,

    RELATIONSHIP_COOLING_MIN = -20,
    RELATIONSHIP_STRAINED_MIN = -40,
    RELATIONSHIP_POOR_MIN = -60,
    RELATIONSHIP_CONCERNED_MIN = -80,
    
    RELATIONSHIP_DISCOUNT_FAMILIAR = 10,
    RELATIONSHIP_DISCOUNT_TRUSTED = 15,
    RELATIONSHIP_DISCOUNT_PREFERRED = 20,
    RELATIONSHIP_DISCOUNT_PARTNER = 25,
    
    -- Dealer operating hours use whole in-game hours.
    -- Rationale:
    -- Centralizing the schedule prevents dealer-hour checks from being
    -- hard-coded across UI, lifecycle, and notification logic.
    DEALER_OPEN_HOUR = 7,
    DEALER_CLOSE_HOUR = 18,

    -- Demo operating hour limits based on days-per-month setting.
    -- Rationale:
    -- Longer month settings give the player more real time per month.
    -- Limiting demo hours based on month length prevents multi-day month
    -- players from getting a free extended rental.
    DEMO_OPERATING_HOUR_LIMITS = {
        [1] = 2,
        [2] = 3,
        [3] = 4,
        default = 5
    },
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
    activeDemoOffer = nil,
    
    -- Per-save category filter settings.
    -- Controls which equipment categories are eligible for demo offers.
    categoryFilters = {},

    -- Per-save brand filter settings.
    -- Controls which equipment brands are eligible for demo offers.
    brandFilters = {},
    
    -- Per-save Dealer Relations settings.
    -- These values represent player-configurable mod behavior.
    -- Persistence and UI wiring will be added in later steps.
    settings = {
        enabled = false,
        debug = false,
    },
    -- Display name for the dealership assigned to this save.
    -- Rationale:
    -- v0.14.0 introduces a persistent dealer identity. The fallback value keeps
    -- existing saves safe until dealer name selection and persistence are added.
    dealerName = "Dealer",
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

-- Returns the purchase discount percentage associated with the
-- player's current dealer relationship.
--
-- Rationale:
-- Purchase discounts are awarded based on relationship level rather
-- than raw confidence. This allows relationship thresholds and discount
-- values to be tuned independently while keeping gameplay effects
-- consistent and easy for players to understand.
function DealerRelations.Data:getDiscountPercent()
    local level = self:getRelationshipLevel()

    if level == 5 then
        return DealerRelations.CONSTANTS.RELATIONSHIP_DISCOUNT_PARTNER
    elseif level == 4 then
        return DealerRelations.CONSTANTS.RELATIONSHIP_DISCOUNT_PREFERRED
    elseif level == 3 then
        return DealerRelations.CONSTANTS.RELATIONSHIP_DISCOUNT_TRUSTED
    elseif level == 2 then
        return DealerRelations.CONSTANTS.RELATIONSHIP_DISCOUNT_FAMILIAR
    end

    return 0
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

function DealerRelations.Data:addConfidence(amount, reason)
    -- Apply a confidence change through the data layer so every gameplay
    -- impact uses the same clamping rules and stays within the supported range.
    local oldConfidence = self:getConfidence()
    local newConfidence = oldConfidence + (tonumber(amount) or 0)

    self:setConfidence(newConfidence)

    DealerRelations.log(string.format(
        "Confidence changed: %d -> %d (%s)",
        oldConfidence,
        self:getConfidence(),
        tostring(reason or "No reason provided")
    ))
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

    if confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_PARTNER_MIN then
        return 5
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_PREFERRED_MIN then
        return 4
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_TRUSTED_MIN then
        return 3
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_FAMILIAR_MIN then
        return 2
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_NEUTRAL_MIN then
        return 1
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_COOLING_MIN then
        return 0
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_STRAINED_MIN then
        return -1
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_POOR_MIN then
        return -2
    elseif confidence >= DealerRelations.CONSTANTS.RELATIONSHIP_CONCERNED_MIN then
        return -3
    end

    return -4
end

-- Returns the player-facing relationship name derived from the
-- current relationship level.
--
-- Rationale:
-- Gameplay systems should use getRelationshipLevel() when they need
-- a numeric value for calculations. UI screens and notifications
-- should use this function to display a meaningful relationship
-- description to the player.
function DealerRelations.Data:getRelationshipName()
    local level = self:getRelationshipLevel()

    if level == 5 then
        return "Partner"
    elseif level == 4 then
        return "Preferred"
    elseif level == 3 then
        return "Trusted"
    elseif level == 2 then
        return "Familiar"
    elseif level == 1 then
        return "Neutral"
    elseif level == 0 then
        return "Cooling"
    elseif level == -1 then
        return "Strained"
    elseif level == -2 then
        return "Poor"
    elseif level == -3 then
        return "Concerned"
    end

    return "At Risk"
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

-- Adds a vehicle to the active demo vehicle list.
-- Demo vehicles are tracked separately from the game's ownership system.
function DealerRelations.Data:addActiveDemoVehicle(demoVehicle)

    -- Ignore invalid demo records.
    if demoVehicle == nil then
        DealerRelations.warning("Cannot add active demo vehicle: demoVehicle is nil")
        return false
    end

    -- A unique vehicle ID is required so the demo can be found later.
    if demoVehicle.uniqueId == nil then
        DealerRelations.warning("Cannot add active demo vehicle: uniqueId is nil")
        return false
    end

    -- Create the active demo vehicle list if it does not exist yet.
    if DealerRelations.dealerData.activeDemoVehicles == nil then
        DealerRelations.dealerData.activeDemoVehicles = {}
    end

    table.insert(DealerRelations.dealerData.activeDemoVehicles, demoVehicle)

    DealerRelations.log(string.format(
        "Active demo vehicle added: uniqueId=%s name=%s",
        tostring(demoVehicle.uniqueId),
        tostring(demoVehicle.name)
    ))

    return true
end

-- Returns the list of active demo vehicles.
function DealerRelations.Data:getActiveDemoVehicles()
    return DealerRelations.dealerData.activeDemoVehicles or {}
end

-- Removes one active demo vehicle tracking record by uniqueId.
-- Rationale: once a returned demo has been removed from the game world,
-- its Dealer Relations tracking record should no longer remain open.
function DealerRelations.Data:removeActiveDemoVehicleByUniqueId(uniqueId)
    if uniqueId == nil then
        DealerRelations.warning("Cannot remove active demo vehicle: uniqueId is nil")
        return false
    end

    local activeDemoVehicles = self:getActiveDemoVehicles()

    for index, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.uniqueId == uniqueId then
            table.remove(activeDemoVehicles, index)

            DealerRelations.log(
                "Removed active demo tracking record: " .. tostring(demoVehicle.name)
            )

            return true
        end
    end

    DealerRelations.warning(
        "Could not remove active demo tracking record: uniqueId not found " .. tostring(uniqueId)
    )

    return false
end

-------------------------------------------------------------------------------
-- Open Demo State
-------------------------------------------------------------------------------

-- Returns true if the player currently has a demo that has not been resolved.
--
-- Open demos block new demo offers. This includes demos that are still active
-- and demos that have expired but have not yet been returned or purchased.
function DealerRelations.Data:hasOpenDemo()
    local activeDemoVehicles = self:getActiveDemoVehicles()

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "ACTIVE"
            or demoVehicle.state == "EXPIRED"
            or demoVehicle.state == "RETURN_PENDING" then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Expired Demo Lookup
-------------------------------------------------------------------------------

-- Returns the first expired demo waiting for player action.
--
-- This is used by the UI to decide whether the dealer should show the
-- Return / Buy dialog instead of the normal demo offer dialog.
function DealerRelations.Data:getFirstExpiredDemo()
    local activeDemoVehicles = self:getActiveDemoVehicles()

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "EXPIRED" then
            return demoVehicle
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Demo Purchase Price
-------------------------------------------------------------------------------

-- Calculates the demo purchase price after applying the current
-- relationship-based dealer discount.
--
-- Rationale:
-- The return/buy dialog and the actual buy workflow must use the same
-- pricing logic so the price shown to the player matches the amount
-- charged when the demo is purchased.
function DealerRelations.Data:getDemoPurchasePrice(listPrice)
    local price = tonumber(listPrice) or 0
    local discountPercent = self:getDiscountPercent()
    local discountMultiplier = 1 - (discountPercent / 100)

    return math.floor(price * discountMultiplier)
end

    -- Initialize per-save category filters from the default equipment category list.
    -- These values represent player-configurable categories, not hard exclusions.
function DealerRelations.Data:initializeCategoryFilters()
    DealerRelations.dealerData.categoryFilters = {}

    for category, enabled in pairs(DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS) do
        DealerRelations.dealerData.categoryFilters[category] = enabled == true
    end
end

function DealerRelations.Data:getCategoryFilters()
    return DealerRelations.dealerData.categoryFilters
end

    -- Unknown or missing category settings default to false here.
    -- New/loaded saves should be initialized before discovery uses this.
function DealerRelations.Data:isCategoryEnabled(category)
    if category == nil then
        return false
    end
    
    return DealerRelations.dealerData.categoryFilters[tostring(category)] == true
end

    -- Store player preference for one configurable equipment category.
    -- Hard exclusions are handled by Equipment.lua and should not be written here.
function DealerRelations.Data:setCategoryEnabled(category, enabled)
    if category == nil then
        return
    end

    DealerRelations.dealerData.categoryFilters[tostring(category)] = enabled == true
end

-------------------------------------------------------------------------------
-- Returns whether a configurable equipment category is currently enabled.
--
-- Category filter settings are stored per save and determine whether
-- otherwise eligible equipment categories may be considered for demo offers.
--
-- @param category string Equipment category name.
-- @return boolean True when the category is enabled.
-----------------------------------------------------------------------------
function DealerRelations.Data:isCategoryEnabled(category)
    if category == nil then
        return false
    end

    return DealerRelations.dealerData.categoryFilters[tostring(category)] == true
end

-------------------------------------------------------------------------------
-- Returns the per-save brand filter settings.
--
-- Brand filters are populated during equipment discovery. Newly discovered
-- brands default to enabled so base-game and mod-added brands remain eligible
-- unless the player disables them later.
--
-- @return table Brand filter settings keyed by brand name.
-------------------------------------------------------------------------------
function DealerRelations.Data:getBrandFilters()
    return DealerRelations.dealerData.brandFilters
end

-------------------------------------------------------------------------------
-- Ensures a discovered brand has a per-save filter entry.
--
-- Newly discovered brands are enabled by default so base-game and mod-added
-- equipment remain eligible for demo offers until the player explicitly
-- disables the brand through Dealer Relations settings.
--
-- @param brand string Brand name/key.
-------------------------------------------------------------------------------
function DealerRelations.Data:ensureBrandFilter(brand)
    if brand == nil then
        return
    end

    local brandKey = tostring(brand)

    if DealerRelations.dealerData.brandFilters[brandKey] == nil then
        DealerRelations.dealerData.brandFilters[brandKey] = true
    end
end

-------------------------------------------------------------------------------
-- Returns whether a discovered brand is currently enabled.
--
-- Brand filter settings are stored per save and determine whether equipment
-- from a given manufacturer may be considered for demo offers.
--
-- @param brand string Brand name/key.
-- @return boolean True when the brand is enabled.
-------------------------------------------------------------------------------
function DealerRelations.Data:isBrandEnabled(brand)
    if brand == nil then
        return false
    end

    return DealerRelations.dealerData.brandFilters[tostring(brand)] == true
end

-------------------------------------------------------------------------------
-- Sets whether a discovered brand is enabled for demo offers.
--
-- This stores the per-save brand preference used by equipment discovery.
-- Future settings UI will call this when the player enables or disables a brand.
--
-- @param brand string Brand name/key.
-- @param enabled boolean True to allow the brand, false to exclude it.
-------------------------------------------------------------------------------
function DealerRelations.Data:setBrandEnabled(brand, enabled)
    if brand == nil then
        return
    end

    DealerRelations.dealerData.brandFilters[tostring(brand)] = enabled == true
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

-- Returns the Dealer Relations enabled setting.
--
-- Rationale:
-- Gameplay systems should ask the data layer whether Dealer Relations is enabled
-- instead of reading the settings table directly.
function DealerRelations.Data:isEnabled()
    return DealerRelations.dealerData.settings.enabled == true
end

-- Stores the Dealer Relations enabled setting.
--
-- Rationale:
-- Setters keep future validation, persistence hooks, or UI side effects in one
-- place instead of spreading direct table writes across the codebase.
function DealerRelations.Data:setEnabled(enabled)
    DealerRelations.dealerData.settings.enabled = enabled == true
end

-- Returns whether Dealer Relations debug behavior is enabled.
--
-- Rationale:
-- Debug behavior should be controlled through the data layer so logging and
-- diagnostics can later share the same persisted setting.
function DealerRelations.Data:isDebugEnabled()
    return DealerRelations.dealerData.settings.debug == true
end

-- Stores the Dealer Relations debug setting.
function DealerRelations.Data:setDebugEnabled(enabled)
    DealerRelations.dealerData.settings.debug = enabled == true
end

--- Returns true if the dealer is currently open.
--
-- Rationale:
-- Centralizes dealer-hour checks so UI, lifecycle, and notification logic
-- all use the same definition of dealer operating hours.
function DealerRelations.Data:isDealerOpen()
    local currentHour = g_currentMission.environment.currentHour

    return currentHour >= DealerRelations.CONSTANTS.DEALER_OPEN_HOUR
        and currentHour < DealerRelations.CONSTANTS.DEALER_CLOSE_HOUR
end

--- Returns formatted dealer operating hours.
--
-- Rationale:
-- Provides a single source for displaying dealer hours in UI elements.
function DealerRelations.Data:getDealerHoursText()
    -- Return dealer hours in a player-friendly 12-hour format.
    -- Rationale:
    -- Dealer hour constants are stored as 24-hour values for simple open/closed
    -- checks, but the Overview page should display readable clock text.
    local function formatHour(hour)
        local suffix = "AM"
        local displayHour = hour

        if hour == 0 then
            displayHour = 12
        elseif hour == 12 then
            suffix = "PM"
        elseif hour > 12 then
            displayHour = hour - 12
            suffix = "PM"
        end

        return tostring(displayHour) .. ":00 " .. suffix
    end

    return formatHour(DealerRelations.CONSTANTS.DEALER_OPEN_HOUR)
        .. " - "
        .. formatHour(DealerRelations.CONSTANTS.DEALER_CLOSE_HOUR)
end

-------------------------------------------------------------------------------
-- Returns the demo operating hour limit for the current days-per-month setting.
--
-- Rationale:
-- The limit is looked up at demo start so it reflects the player's actual
-- month length setting at that moment.
-------------------------------------------------------------------------------
function DealerRelations.Data:getDemoOperatingHourLimit()
    local daysPerMonth = g_currentMission.environment.daysPerPeriod
    local limit = DealerRelations.CONSTANTS.DEMO_OPERATING_HOUR_LIMITS[daysPerMonth]

    if limit == nil then
        limit = DealerRelations.CONSTANTS.DEMO_OPERATING_HOUR_LIMITS.default
    end

    return limit
end

--- Returns the dealership name assigned to this save.
--
-- @return string Dealer name.
function DealerRelations.Data:getDealerName()
    return DealerRelations.dealerData.dealerName
end

--- Sets the dealership name assigned to this save.
--
-- @param dealerName string Dealer name.
function DealerRelations.Data:setDealerName(dealerName)
    DealerRelations.dealerData.dealerName = dealerName
end

-------------------------------------------------------------------------------
-- Loads dealer names from dealerNames.xml.
--
-- Rationale:
-- Dealer names are defined in XML so names can be added, removed, or
-- localized without modifying Lua code.
--
-- @return table List of dealer names. Empty if the XML cannot be loaded.
-------------------------------------------------------------------------------

function DealerRelations.Data:loadDealerNames()
    local dealerNames = {}
    local xmlFile = loadXMLFile(
        "dealerNames",
        DealerRelations.directory .. "xmls/dealerNames.xml"
    )

    if xmlFile == nil then
        return dealerNames
    end

    local index = 0

    while true do
        local dealerName = getXMLString(
            xmlFile,
            string.format("dealerNames.dealerName(%d)#name", index)
        )

        if dealerName == nil then
            break
        end

        table.insert(dealerNames, dealerName)

        index = index + 1
    end

    delete(xmlFile)

    return dealerNames
end

-------------------------------------------------------------------------------
-- Selects a random dealer name from dealerNames.xml.
--
-- Rationale:
-- Dealer identity is assigned once per save. Selection logic is separated
-- from persistence so it can be tested independently.
--
-- @return string Random dealer name, or "Dealer" if no valid names exist.
-------------------------------------------------------------------------------

function DealerRelations.Data:getRandomDealerName()
    local dealerNames = self:loadDealerNames()

    if #dealerNames == 0 then
        return "Dealer"
    end

    local index = math.random(#dealerNames)

    return dealerNames[index]
end

--- Returns the first active (non-expired) demo vehicle.
-- Rationale:
-- The Overview dashboard needs to display active demo information
-- separately from expired demos awaiting return or purchase.
--
-- @return table|nil Active demo vehicle data, or nil if none exists.
function DealerRelations.Data:getActiveDemo()
    local activeDemoVehicles = self:getActiveDemoVehicles()

    for _, demoVehicle in ipairs(activeDemoVehicles) do
        if demoVehicle.state == "ACTIVE" then
            return demoVehicle
        end
    end

    return nil
end