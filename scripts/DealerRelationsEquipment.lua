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

    BALELOADERS = true,
    BALINGMISC = true,
    WEIGHTS = true,
    WINTEREQUIPMENT = true,
    BELTS  = true,
    LOWLOADERS = true,
    FORAGEHARVESTERCUTTERTRAILERS = true,

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
}

-------------------------------------------------------------------------------
-- Forestry categories are gated behind a single player-facing toggle rather
-- than individual per-category filters.
--
-- Forestry has no reliable ownership/usage signal the way fields have for
-- crops, so it cannot be auto-detected. These categories remain listed in
-- DEFAULT_CATEGORY_FILTERS as valid equipment categories, but are only
-- offered when the Forestry setting is enabled. Default OFF.
-------------------------------------------------------------------------------
DealerRelations.Equipment.FORESTRY_CATEGORIES = {
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
}

-------------------------------------------------------------------------------
-- Categories whose eligibility depends on the player's crop history
-- (cropsEverGrown), rather than a manual filter or forestry-style toggle.
-------------------------------------------------------------------------------
DealerRelations.Equipment.CROP_CATEGORIES = {
    COMBINEWINDROWER = true,
    CORNHEADERS = true,
    CUTTERS = true,
    FORAGEHARVESTERCUTTERS = true,
    SPECIALHEADERS = true,
    PLANTERS = true,
    SEEDERS = true,

    BEETHARVESTERCUTTERS = { "SUGARBEET" },
    BEETHARVESTERS = { "SUGARBEET" },
    BEETLOADING = { "SUGARBEET" },
    COTTONHARVESTERS = { "COTTON" },
    COTTONTRANSPORT = { "COTTON" },
    GRAPEHARVESTERS = { "GRAPE" },
    GRAPETOOLS = { "GRAPE" },
    GRAPETRAILERS = { "GRAPE" },
    OLIVEHARVESTERS = { "OLIVE" },
    GREENBEANHARVESTERS = { "GREENBEAN" },
    PEAHARVESTERS = { "PEA" },
    POTATOHARVESTING = { "POTATO" },
    POTATOPLANTING = { "POTATO" },
    RICEHARVESTERS = { "RICE", "RICELONGGRAIN" },
    RICEPLANTERS = { "RICE", "RICELONGGRAIN" },
    SPINACHHARVESTERS = { "SPINACH" },
    SUGARCANEHARVESTERS = { "SUGARCANE" },
    SUGARCANEPLANTERS = { "SUGARCANE" },
    SUGARCANETRANSPORT = { "SUGARCANE" },
    TEDDERS = { "GRASS", "ALFALFA", "CLOVER" },
    GRASSLANDCARE = { "GRASS" },

    MOWERS = "WINDROW",
    WINDROWERS = "WINDROW",
    BALERSSQUARE = "WINDROW",
    BALERSROUND = "WINDROW",
    BALETRANSPORT = "WINDROW",
    BALEWRAPPERS = { "GRASS" },
}

-------------------------------------------------------------------------------
-- Default player-configurable category filters.
--
-- These categories are valid equipment-demo categories. New saves will start
-- with these enabled, and later save-specific settings can override them.
-------------------------------------------------------------------------------
DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS = {
    AUGERWAGONS = true,

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
    FORAGEMIXERS = true,
    LOADERWAGONS = true,
    STRAWBLOWERS = true,

    HARVESTERS = true,
    VEGETABLEHARVESTERS = true,
    VEGETABLEPLANTERS = true,

    CUTTERTRAILERS = true,

    SLURRYTRANSPORT = true,
    TRAILERS = true,

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

    if DealerRelations.Equipment.CROP_CATEGORIES[category] == nil
        and DealerRelations.Equipment.FORESTRY_CATEGORIES[category] == nil
        and DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS[category] == nil then
        DealerRelations.warning("Unclassified equipment category: " .. category)
        return false
    end

    return true
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
-----------------------------------------------------------------------------

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

    local fruitTypeCategories = getXMLString(xmlFile, "vehicle.cutter#fruitTypeCategories")
    local fruitTypesDirect = getXMLString(xmlFile, "vehicle.cutter#fruitTypes")
    local vineFruitType = getXMLString(xmlFile, "vehicle.vineCutter#fruitType")

    local data = {
        brand = getXMLString(xmlFile, "vehicle.storeData.brand"),
        storeImage = getXMLString(xmlFile, "vehicle.storeData.image"),  -- Store image path for Overview display
        fruitTypes = self:resolveFruitTypes(fruitTypeCategories, fruitTypesDirect, vineFruitType),
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
-- Evaluates a single store item and builds its equipmentList entry if it
-- passes every gate.
--
-- Coordinates the per-item pipeline in order: category gate, XML read,
-- crop-history gate, brand filter. Each gate is a single-purpose check
-- owned elsewhere; this function's only job is calling them in the right
-- order and stopping at the first failure.
--
-- @param item table Store item from g_storeManager.items.
-- @return table|nil Equipment entry ready for equipmentList, or nil if the
--         item failed any gate.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:resolveDemoCandidate(item)
    if not self:isDemoCandidate(item) then
        return nil
    end

    local category = tostring(item.categoryName)
    local xmlData = self:readEquipmentXml(item.xmlFilename)

    -- Prefer the brand resolved from the vehicle XML when available.
    -- Fall back to the store item brand so discovery can still continue
    -- if XML brand data cannot be read.
    local brand = xmlData ~= nil and xmlData.brand or item.brandName

    -- Ensure every discovered brand has a per-save filter entry.
    -- New brands default to enabled so mod-added brands remain eligible
    -- unless the player disables them later. This is one-time housekeeping,
    -- not an eligibility check — whether the brand is currently enabled is
    -- decided fresh at selection time, not here.
    DealerRelations.Data:ensureBrandFilter(brand)

    return {
        name = item.name,
        brand = brand,
        storeBrand = item.brandName,
        xmlBrand = xmlData ~= nil and xmlData.brand or nil,
        category = category,
        fruitTypes = xmlData ~= nil and xmlData.fruitTypes or nil,
        price = item.price,
        xmlFilename = item.xmlFilename,
        storeImage = xmlData ~= nil and xmlData.storeImage or nil,  -- Store image path for Overview display
        powerRole = xmlData ~= nil and xmlData.powerRole or "NONE",
        displayPower = xmlData ~= nil and xmlData.displayPower or nil,
        powerMin = xmlData ~= nil and xmlData.powerMin or nil,
        powerMax = xmlData ~= nil and xmlData.powerMax or nil
    }
end

-------------------------------------------------------------------------------
-- Discovers eligible Dealer Relations demo equipment from the FS25 store.
--
-- Builds an in-memory list only. This does not save equipment data
-- and does not select demo equipment.
--
-- Acts as the orchestration point only: loops over store items and
-- delegates the full per-item gating pipeline (category, XML read,
-- crop history, brand filter) to resolveDemoCandidate().
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

        local candidate = self:resolveDemoCandidate(item)

        if candidate ~= nil then
            candidateCount = candidateCount + 1
            table.insert(DealerRelations.equipmentList, candidate)
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

    local eligibleCandidates = {}

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        if self:isCurrentlyEligible(candidate) then
            table.insert(eligibleCandidates, candidate)
        end
    end

    if #eligibleCandidates == 0 then
        DealerRelations.warning("No eligible demo candidates available")
        return nil
    end

    local candidate = nil
    local candidateKey = nil
    local attemptsRemaining = #eligibleCandidates

    repeat
        local index = math.random(1, #eligibleCandidates)
        candidate = eligibleCandidates[index]
        candidateKey = self:getDemoCandidateKey(candidate)

        if DealerRelations.Data:isRecentDemoCandidate(candidateKey) then
            candidate = nil
        end

        attemptsRemaining = attemptsRemaining - 1
    until candidate ~= nil or attemptsRemaining <= 0

    if candidate == nil then
        DealerRelations.warning("No eligible demo candidates available after excluding recent offers")
        return nil
    end

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
-- Resolves the set of fruit type names an equipment item is tied to, from
-- whichever crop-linkage attribute is present in its XML.
--
-- Checked in order, first match wins:
--   1. cutter#fruitTypeCategories — one or more space-separated category
--      names. Each is resolved via getFruitTypesByCategoryNames(), which
--      returns full fruit type definition tables (confirmed via live log);
--      the .name field is read directly, no index lookup required.
--   2. cutter#fruitTypes          — direct fruit type name(s), space-separated
--   3. vineCutter#fruitType       — a single direct fruit type name
--
-- All resolved names are uppercased, since crop history (cropsEverGrown)
-- stores fruit type names uppercase, and source XML casing is inconsistent
-- across store files.
--
-- @return table Set of fruit type names, keyed by name. Empty if none found.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:resolveFruitTypes(fruitTypeCategories, fruitTypesDirect, vineFruitType)
    local result = {}

    if fruitTypeCategories ~= nil then
        for categoryName in fruitTypeCategories:gmatch("%S+") do
            local fruitTypeDefs = g_fruitTypeManager:getFruitTypesByCategoryNames(categoryName)

            if fruitTypeDefs ~= nil then
                for _, fruitTypeDef in ipairs(fruitTypeDefs) do
                    if fruitTypeDef.name ~= nil then
                        result[string.upper(fruitTypeDef.name)] = true
                    end
                end
            end
        end
        return result
    end

    if fruitTypesDirect ~= nil then
        for name in fruitTypesDirect:gmatch("%S+") do
            result[string.upper(name)] = true
        end
        return result
    end

    if vineFruitType ~= nil then
        result[string.upper(vineFruitType)] = true
    end

    return result
end

-------------------------------------------------------------------------------
-- Returns true when a store item's resolved fruit types satisfy the crop
-- history requirement for its category.
--
-- Categories outside CROP_CATEGORIES are unaffected by crop history and
-- always pass this gate. For CROP_CATEGORIES, the item is eligible once
-- the player has ever grown at least one fruit type it is tied to
-- (DealerRelations.Data:hasCropBeenGrown), regardless of what is currently
-- planted.
--
-- @param category string Store item category name.
-- @param fruitTypes table Set of fruit type names, keyed by name, as
--        returned by resolveFruitTypes(). May be empty.
-- @return boolean True when the item passes the crop-history gate.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isCropEligible(category, fruitTypes)
    local cropRule = DealerRelations.Equipment.CROP_CATEGORIES[category]

    if cropRule == nil then
        return true
    end

    if cropRule == "WINDROW" then
        return self:hasGrownAnyWindrowCrop()
    end

    if cropRule == true then
        if fruitTypes == nil then
            return false
        end

        for fruitTypeName in pairs(fruitTypes) do
            if DealerRelations.Data:hasCropBeenGrown(fruitTypeName:upper()) then
                return true
            end
        end

        return false
    end

    for _, cropName in ipairs(cropRule) do
        if DealerRelations.Data:hasCropBeenGrown(cropName) then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true when the player has ever grown any crop whose fruit type
-- definition produces a windrow (fruitType.hasWindrow == true).
--
-- Unlike other crop-gated categories, windrow-tied equipment (mowers,
-- windrowers, balers) isn't linked to a fixed crop list — any crop that
-- produces a windrow qualifies, including future mod-added crops with no
-- entry in CROP_CATEGORIES. This checks live against g_fruitTypeManager
-- rather than a hardcoded list, so new windrow-capable crops are picked
-- up automatically.
--
-- @return boolean True if any crop in cropsEverGrown has hasWindrow == true.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:hasGrownAnyWindrowCrop()
    for cropName in pairs(DealerRelations.Data:getCropsEverGrown()) do
        local fruitType = g_fruitTypeManager:getFruitTypeByName(cropName)

        if fruitType ~= nil and fruitType.hasWindrow then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true when a discovered candidate is currently eligible to be
-- selected as a demo offer.
--
-- This is evaluated fresh every time a demo is selected, not cached at
-- discovery time. Category toggles, brand toggles, forestry toggle, and
-- crop history can all change over the life of a save, so eligibility
-- must be re-checked against current state each time, not baked into
-- equipmentList once at map load.
--
-- @param candidate table Entry from equipmentList, as built by
--        resolveDemoCandidate().
-- @return boolean True when the candidate is currently eligible.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isCurrentlyEligible(candidate)
    if candidate == nil then
        return false
    end

    if not DealerRelations.Data:isBrandEnabled(candidate.brand) then
        return false
    end

    if DealerRelations.Equipment.FORESTRY_CATEGORIES[candidate.category] == true then
        return DealerRelations.Data:isForestryEnabled()
    end

    if DealerRelations.Equipment.CROP_CATEGORIES[candidate.category] ~= nil then
        return self:isCropEligible(candidate.category, candidate.fruitTypes)
    end

    return DealerRelations.Data:isCategoryEnabled(candidate.category)
end
