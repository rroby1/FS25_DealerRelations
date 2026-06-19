-------------------------------------------------------------------------------
-- DealerRelationsEquipment.lua
--
-- Discovers equipment information from the Farming Simulator store data.
--
-- Builds an in-memory equipment list used by Dealer Relations demo selection.
-- This module does not save equipment data.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Equipment = DealerRelations.Equipment or {}

-------------------------------------------------------------------------------
-- Data Definition
-------------------------------------------------------------------------------

DealerRelations.equipmentList = {}

-------------------------------------------------------------------------------
-- Categories that Dealer Relations should never offer as equipment demos.
--
-- These are hard exclusions, not player settings. They represent store
-- categories that do not fit the purpose of an equipment demo system.
-------------------------------------------------------------------------------
DealerRelations.Equipment.EXCLUDED_CATEGORIES = {
    ANIMALPENS = true,
    ANIMALTRANSPORT = true,

    BALES = true,
    BIGBAGPALLETS = true,
    BIGBAGS = true,

    CARS = true,
    TRUCKS = true,

    CHAINSAWS = true,
    FLASHLIGHTS = true,
    HANDTOOLSANIMALS = true,
    HANDTOOLSMISC = true,
    MARKINGSPRAY = true,

    DECORATION = true,
    DIESELTANKS = true,
    FARMHOUSES = true,
    FENCES = true,
    FLOODLIGHTING = true,
    GARDENSHEDS = true,
    GENERATORS = true,
    PLACEABLEMISC = true,
    PRODUCTIONPOINTS = true,
    SELLINGPOINTS = true,
    SHEDS = true,
    SHIPPINGCONTAINERS = true,
    SILOEXTENSIONS = true,
    SILOS = true,
    STORAGES = true,
    TREES = true,
    BEEHIVES = true,

    FILLABLETANKS = true,
    IBC = true,
    PALLETS = true,
    PALLETSILAGE = true,
    WATERTANKS = true,

    LEVELER = true,
    MISC = true,
    MISCDRIVABLES = true,
    OBJECTANIMAL = true,
    SILOCOMPACTION = true,
    BARRELS = true,

    TRAILERSCHANGINGSYSTEM = true,
    TRAILERSSEMI = true,

    BALINGMISC = true
}

-------------------------------------------------------------------------------
-- Default player-configurable category filters.
--
-- These categories are valid equipment-demo categories. New saves will start
-- with these enabled, and later save-specific settings can override them.
-------------------------------------------------------------------------------
DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS = {
    AUGERWAGONS = true,
    BEETHARVESTERCUTTERS = true,
    BEETHARVESTERS = true,
    BEETLOADING = true,
    BELTS = true,

    COMBINEWINDROWER = true,
    CORNHEADERS = true,
    CUTTERS = true,
    FORAGEHARVESTERCUTTERS = true,
    SPECIALHEADERS = true,

    COTTONHARVESTERS = true,
    COTTONTRANSPORT = true,

    CULTIVATORS = true,
    DISCHARROWS = true,
    MULCHERS = true,
    PLOWS = true,
    POWERHARROWS = true,
    ROLLERS = true,
    SPADERS = true,
    STONEPICKERS = true,
    SUBSOILERS = true,
    WEEDERS = true,

    FERTILIZERSPREADERS = true,
    MANURESPREADERS = true,
    SLURRYTOOLS = true,
    SPRAYERS = true,

    SEEDTANKS = true,
    SLURRYTANKS = true,

    FORAGEHARVESTERS = true,
    FORAGEHARVESTERCUTTERTRAILERS = true,
    FORAGEMIXERS = true,
    GRASSLANDCARE = true,
    LOADERWAGONS = true,
    MOWERS = true,
    STRAWBLOWERS = true,
    TEDDERS = true,
    WINDROWERS = true,

    FORESTRYEXCAVATORS = true,
    FORESTRYEXCAVATORTOOLS = true,
    FORESTRYFORWARDERS = true,
    FORESTRYHARVESTERS = true,
    FORESTRYMISC = true,
    FORESTRYMULCHERS = true,
    FORESTRYPLANTERS = true,
    FORESTRYSTUMPCUTTERS = true,
    FORESTRYWINCHES = true,
    WOODCHIPPERS = true,
    WOODTRANSPORT = true,

    FORKLIFTS = true,
    FRONTLOADERS = true,
    FRONTLOADERTOOLS = true,
    FRONTLOADERVEHICLES = true,
    SKIDSTEERTOOLS = true,
    SKIDSTEERVEHICLES = true,
    TELELOADERTOOLS = true,
    TELELOADERVEHICLES = true,
    WHEELLOADERTOOLS = true,
    WHEELLOADERVEHICLES = true,

    GRAPEHARVESTERS = true,
    GRAPETOOLS = true,
    GRAPETRAILERS = true,
    OLIVEHARVESTERS = true,

    GREENBEANHARVESTERS = true,
    HARVESTERS = true,
    PEAHARVESTERS = true,
    POTATOHARVESTING = true,
    RICEHARVESTERS = true,
    SPINACHHARVESTERS = true,
    SUGARCANEHARVESTERS = true,
    VEGETABLEHARVESTERS = true,

    PLANTERS = true,
    POTATOPLANTING = true,
    RICEPLANTERS = true,
    SEEDERS = true,
    SUGARCANEPLANTERS = true,
    VEGETABLEPLANTERS = true,

    CUTTERTRAILERS = true,
    WEIGHTS = true,
    WINTEREQUIPMENT = true,

    LOWLOADERS = true,
    SLURRYTRANSPORT = true,
    SUGARCANETRANSPORT = true,
    TRAILERS = true,

    BALERSSQUARE = true,
    BALERSROUND = true,
    BALELOADERS = true,
    BALEWRAPPERS = true,
    BALETRANSPORT = true,

    TRACTORSS = true,
    TRACTORSM = true,
    TRACTORSL = true
}

-------------------------------------------------------------------------------
-- Returns true when a store item should be considered for dealer demos.
--
-- Categories are evaluated in two stages:
-- 1. Hard exclusions remove known non-equipment categories.
-- 2. Default category filters define equipment categories that may later become
--    player-configurable per save.
--
-- Unknown categories are excluded by default and logged so new FS25/mod
-- categories can be reviewed later.
--
-- @param item table Store item from g_storeManager.items.
-- @return boolean True when item is eligible for demo consideration.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isDemoCandidate(item)
    if item == nil then
        return false
    end

    if item.categoryName == nil then
        DealerRelations.warning("Store item has no category: " .. tostring(item.name))
        return false
    end

    local category = tostring(item.categoryName)

    if DealerRelations.Equipment.EXCLUDED_CATEGORIES[category] == true then
        return false
    end

    if DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS[category] == nil then
        DealerRelations.warning("Unclassified equipment category: " .. category)
        return false
    end

    return DealerRelations.Data:isCategoryEnabled(category)
end

-------------------------------------------------------------------------------
-- Reads equipment data directly from a vehicle XML file.
--
-- Used by Dealer Relations to access XML attributes that are not available
-- from store manager data alone.
--
-- -- Currently reads:
--    - Brand
--    - Self-propelled display horsepower
--    - Implement required horsepower
--    - Min/max motor configuration horsepower when available
--
-- Additional attributes may be added in future versions for equipment cache
-- generation and demo selection logic.
--
-- @param xmlFilename string Path to the equipment XML file.
-- @return table|nil Equipment data table when successful, otherwise nil.
----------------------------------------------------------------------------

function DealerRelations.Equipment:readEquipmentXml(xmlFilename)
    if xmlFilename == nil or xmlFilename == "" then
        DealerRelations.warning("Cannot read equipment XML: xmlFilename is missing")
        return nil
    end

    local xmlFile = loadXMLFile("dealerRelationsEquipmentXML", xmlFilename)

    if xmlFile == nil or xmlFile == 0 then
        DealerRelations.warning("Failed to load equipment XML: " .. tostring(xmlFilename))
        return nil
    end

    local displayPower = getXMLInt(xmlFile, "vehicle.storeData.specs.power")
    local displayNeededPower = getXMLInt(xmlFile, "vehicle.storeData.specs.neededPower")
    local displayNeededMaxPower = getXMLInt(xmlFile, "vehicle.storeData.specs.neededPower#maxPower")

    local data = {
        brand = getXMLString(xmlFile, "vehicle.storeData.brand"),
        powerRole = "NONE",
        displayPower = nil,
        powerMin = nil,
        powerMax = nil
    }

    if displayPower ~= nil then
        data.powerRole = "SELF_PROPELLED"
        data.displayPower = displayPower
        data.powerMin = displayPower
        data.powerMax = displayPower
    elseif displayNeededPower ~= nil then
        data.powerRole = "IMPLEMENT"
        data.displayPower = displayNeededPower
        data.powerMin = displayNeededPower
        data.powerMax = displayNeededMaxPower or displayNeededPower
    end

    if data.powerRole == "SELF_PROPELLED" then
        local motorIndex = 0
        local motorHp = getXMLInt(
            xmlFile,
            string.format(
                "vehicle.motorized.motorConfigurations.motorConfiguration(%d)#hp",
                motorIndex
            )
        )

        while motorHp ~= nil do
            if data.powerMin == nil or motorHp < data.powerMin then
                data.powerMin = motorHp
            end

            if data.powerMax == nil or motorHp > data.powerMax then
                data.powerMax = motorHp
            end

            motorIndex = motorIndex + 1
            motorHp = getXMLInt(
                xmlFile,
                string.format(
                    "vehicle.motorized.motorConfigurations.motorConfiguration(%d)#hp",
                    motorIndex
                )
            )
        end
    end

    delete(xmlFile)

    return data
end

-------------------------------------------------------------------------------
-- Discovers eligible Dealer Relations demo equipment from the FS25 store.
--
-- Builds an in-memory list only. This does not save equipment data.
-- not select demo equipment.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:discover()
    DealerRelations.equipmentList = {}

    if g_storeManager == nil or g_storeManager.items == nil then
        DealerRelations.warning("Cannot discover equipment: store manager is unavailable")
        return
    end

    local storeItemCount = 0
    local candidateCount = 0

    for _, item in pairs(g_storeManager.items) do
        storeItemCount = storeItemCount + 1

        if self:isDemoCandidate(item) then
            local xmlData = self:readEquipmentXml(item.xmlFilename)

            -- Prefer the brand resolved from the vehicle XML when available.
            -- Fall back to the store item brand so discovery can still continue
            -- if XML brand data cannot be read.
            local brand = xmlData ~= nil and xmlData.brand or item.brandName

            -- Ensure every discovered brand has a per-save filter entry.
            -- New brands default to enabled so mod-added brands remain eligible
            -- unless the player disables them later.
            DealerRelations.Data:ensureBrandFilter(brand)
 
            if DealerRelations.Data:isBrandEnabled(brand) then
                candidateCount = candidateCount + 1

                table.insert(DealerRelations.equipmentList, {
                    name = item.name,
                    brand = brand,
                    storeBrand = item.brandName,
                    xmlBrand = xmlData ~= nil and xmlData.brand or nil,
                    category = item.categoryName,
                    price = item.price,
                    xmlFilename = item.xmlFilename,
                    powerRole = xmlData ~= nil and xmlData.powerRole or "NONE",
                    displayPower = xmlData ~= nil and xmlData.displayPower or nil,
                    powerMin = xmlData ~= nil and xmlData.powerMin or nil,
                    powerMax = xmlData ~= nil and xmlData.powerMax or nil
                })
            end
        end
    end

    DealerRelations.log(string.format(
        "Equipment discovery complete: %d store items, %d demo candidates",
        storeItemCount,
        candidateCount
    ))
end

-------------------------------------------------------------------------------
-- Returns a random eligible piece of equipment from the discovered equipment list.
-- This is used when generating a demo offer.
--
-- Returns:
--   table  Selected equipment entry from equipmentList.
--   nil    If no eligible equipment is available.
-------------------------------------------------------------------------------

function DealerRelations.Equipment:getRandomDemoCandidate()
    if DealerRelations.equipmentList == nil or #DealerRelations.equipmentList == 0 then
        DealerRelations.warning("No eligible demo candidates available")
        return nil
    end

    local candidate = nil
    local candidateKey = nil

    repeat
        local index = math.random(1, #DealerRelations.equipmentList)
        candidate = DealerRelations.equipmentList[index]
        candidateKey = self:getDemoCandidateKey(candidate)

        if DealerRelations.Data:isRecentDemoCandidate(candidateKey) then
            candidate = nil
        end
    until candidate ~= nil

    DealerRelations.Data:addRecentDemoCandidate(candidateKey)

    DealerRelations.log(string.format(
        "Selected demo candidate: %s | Brand=%s | Category=%s | HP=%s",
        candidate.name,
        candidate.brand,
        candidate.category,
        tostring(candidate.displayPower or "Unknown")
    ))

    return candidate
end

-------------------------------------------------------------------------------
-- Builds a unique key for a demo candidate.
--
-- The key identifies a specific equipment configuration so duplicate
-- prevention can avoid offering the same configuration repeatedly.
--
-- @param candidate table Equipment entry selected from the eligible list.
--
-- @return string Unique demo candidate key.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getDemoCandidateKey(candidate)
    if candidate == nil then
        return nil
    end

    return string.format(
        "%s|%s|%s",
        tostring(candidate.brand or "UNKNOWN"),
        tostring(candidate.name or "UNKNOWN"),
        tostring(candidate.displayPower or "UNKNOWN")
    )
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