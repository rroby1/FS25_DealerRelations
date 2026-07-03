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
DealerRelations.equipmentByXmlFilename = {}

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
    VEGETABLEHARVESTERS = true,
    VEGETABLEPLANTERS = true,

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

    PLOWS = { "MAIZE", "POTATO", "SUGARBEET" },
}

-------------------------------------------------------------------------------
-- Categories considered "tractor" for HP-eligibility purposes.
--
-- Scoped intentionally to tractors only for 0.17.0. Self-propelled
-- harvesters, foragers, and other motorized equipment also carry a "motor"
-- configuration but are out of scope here — their own HP-eligibility
-- treatment (if any) is deferred to the harvester/header work.
-------------------------------------------------------------------------------
DealerRelations.Equipment.TRACTOR_CATEGORIES = {
    TRACTORSS = true,
    TRACTORSM = true,
    TRACTORSL = true,
}

-------------------------------------------------------------------------------
-- Categories managed entirely by HP eligibility rather than a manual
-- player toggle. Missing neededPower in an item's XML defaults to 0 HP
-- (resolveDemoCandidate), not exclusion from discovery.
-------------------------------------------------------------------------------
DealerRelations.Equipment.POWER_MANAGED_CATEGORIES = {
    CULTIVATORS = true,
    DISCHARROWS = true,
    MULCHERS = true,
    POWERHARROWS = true,
    ROLLERS = true,
    SPADERS = true,
    STONEPICKERS = true,
    SUBSOILERS = true,
    WEEDERS = true,
}

-------------------------------------------------------------------------------
-- Default player-configurable category filters.
--
-- These categories are valid equipment-demo categories. New saves will start
-- with these enabled, and later save-specific settings can override them.
-------------------------------------------------------------------------------
DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS = {
    AUGERWAGONS = true,

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
    CUTTERTRAILERS = true,

    SLURRYTRANSPORT = true,
    TRAILERS = true,
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
        and DealerRelations.Equipment.TRACTOR_CATEGORIES[category] == nil
        and DealerRelations.Equipment.POWER_MANAGED_CATEGORIES[category] == nil
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
        return {}
    end

    local category = tostring(item.categoryName)
    local xmlData = self:readEquipmentXml(item.xmlFilename)

    local brand = xmlData ~= nil and xmlData.brand or item.brandName
    DealerRelations.Data:ensureBrandFilter(brand)

    -- Tractors are expanded into one candidate per engine configuration so
    -- HP eligibility and future weighted selection operate on the specific
    -- configuration actually offered, not the model's full range. Deferred
    -- for other self-propelled categories (harvesters, foragers) until
    -- their own HP-eligibility work is scoped.
    if DealerRelations.Equipment.TRACTOR_CATEGORIES[category] == true
        and item.configurations ~= nil
        and item.configurations["motor"] ~= nil then

        local candidates = {}

        for _, configEntry in ipairs(item.configurations["motor"]) do
            if configEntry.power ~= nil and configEntry.isSelectable ~= false then
                table.insert(candidates, {
                    name = configEntry.name or item.name,
                    brand = brand,
                    storeBrand = item.brandName,
                    xmlBrand = xmlData ~= nil and xmlData.brand or nil,
                    category = category,
                    fruitTypes = xmlData ~= nil and xmlData.fruitTypes or nil,
                    -- Assumes configEntry.price is the incremental upgrade
                    -- cost added to the base vehicle price ("0, 6000,
                    -- 13000..." pattern seen in store XML) — flagging as an
                    -- assumption, not yet separately confirmed.
                    price = item.price + (configEntry.price or 0),
                    xmlFilename = item.xmlFilename,
                    storeImage = xmlData ~= nil and xmlData.storeImage or nil,
                    powerRole = "SELF_PROPELLED",
                    displayPower = configEntry.power,
                    powerMin = configEntry.power,
                    powerMax = configEntry.power,
                    motorConfigId = configEntry.index,
                })
            end
        end

        if #candidates > 0 then
            return candidates
        end
        -- Fall through to single-candidate behavior below if no usable
        -- motor configuration data was found, so a tractor with malformed
        -- config data doesn't silently vanish from the equipment list.
    end

    -- Categories fully managed by HP eligibility default to a 0 HP
    -- requirement when the XML defines none, rather than falling through
    -- to powerRole "NONE" and becoming invisible to both the eligibility
    -- gate and the selection weighting. A modder omitting neededPower is
    -- treated the same as an implement that genuinely needs none — the
    -- resulting low weight against large tractors is an acceptable outcome
    -- either way.
    local powerRole = xmlData ~= nil and xmlData.powerRole or "NONE"
    local displayPower = xmlData ~= nil and xmlData.displayPower or nil
    local powerMin = xmlData ~= nil and xmlData.powerMin or nil
    local powerMax = xmlData ~= nil and xmlData.powerMax or nil

    -- Any automatically-managed category (crop, forestry, or power-managed)
    -- defaults to 0 HP when the XML defines no neededPower, rather than
    -- falling through to powerRole "NONE" and becoming invisible to both
    -- HP eligibility and selection weighting. Tractors are excluded since
    -- they already set powerRole explicitly during config expansion above.
    if powerRole == "NONE"
        and (DealerRelations.Equipment.CROP_CATEGORIES[category] ~= nil
            or DealerRelations.Equipment.FORESTRY_CATEGORIES[category] ~= nil
            or DealerRelations.Equipment.POWER_MANAGED_CATEGORIES[category] == true) then
        powerRole = "IMPLEMENT"
        displayPower = 0
        powerMin = 0
        powerMax = 0
    end

    return {
        {
            name = item.name,
            brand = brand,
            storeBrand = item.brandName,
            xmlBrand = xmlData ~= nil and xmlData.brand or nil,
            category = category,
            fruitTypes = xmlData ~= nil and xmlData.fruitTypes or nil,
            price = item.price,
            xmlFilename = item.xmlFilename,
            storeImage = xmlData ~= nil and xmlData.storeImage or nil,
            powerRole = powerRole,
            displayPower = displayPower,
            powerMin = powerMin,
            powerMax = powerMax,
        }
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
    DealerRelations.equipmentByXmlFilename = {}

    if g_storeManager == nil or g_storeManager.items == nil then
        DealerRelations.warning("Cannot discover equipment: store manager is unavailable")
        return
    end

    local storeItemCount = 0
    local candidateCount = 0

    for _, item in pairs(g_storeManager.items) do
        storeItemCount = storeItemCount + 1

        local candidates = self:resolveDemoCandidate(item)

        for _, candidate in ipairs(candidates) do
            candidateCount = candidateCount + 1
            table.insert(DealerRelations.equipmentList, candidate)

            -- Only implements are looked up by xmlFilename (see
            -- getOwnedMaxImplementNeededPower). Tractors are expanded into
            -- multiple entries sharing one xmlFilename and would collide
            -- here, but nothing looks tractors up through this map, so
            -- skipping them is safe.
            if candidate.powerRole == "IMPLEMENT" and candidate.xmlFilename ~= nil then
                DealerRelations.equipmentByXmlFilename[candidate.xmlFilename] = candidate
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

    -- Computed once per selection cycle, not per candidate, since both
    -- values depend only on current ownership state.
    local ownedMaxTractorPower = self:getOwnedMaxTractorPower()
    local ownedMaxImplementNeededPower = self:getOwnedMaxImplementNeededPower()

    local weights = {}
    local totalWeight = 0

    for i, candidate in ipairs(eligibleCandidates) do
        local weight = self:getHpWeight(candidate, ownedMaxTractorPower, ownedMaxImplementNeededPower)
        weights[i] = weight
        totalWeight = totalWeight + weight
    end

    local candidate = nil
    local candidateKey = nil
    local attemptsRemaining = #eligibleCandidates

    repeat
        local roll = math.random() * totalWeight
        local cumulative = 0
        local pickedIndex = #eligibleCandidates

        for i, weight in ipairs(weights) do
            cumulative = cumulative + weight
            if roll <= cumulative then
                pickedIndex = i
                break
            end
        end

        candidate = eligibleCandidates[pickedIndex]
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

    -- Implements requiring more power than the player's best owned tractor
    -- are excluded. No floor beyond this.
    if candidate.powerRole == "IMPLEMENT" and candidate.displayPower ~= nil then
        if self:getOwnedMaxTractorPower() < candidate.displayPower then
            return false
        end
    end

    -- Tractor configurations underpowered for the player's most demanding
    -- owned implement are excluded. No ceiling beyond this.
    if DealerRelations.Equipment.TRACTOR_CATEGORIES[candidate.category] == true
        and candidate.displayPower ~= nil then
        if candidate.displayPower < self:getOwnedMaxImplementNeededPower() then
            return false
        end
    end

    if DealerRelations.Equipment.FORESTRY_CATEGORIES[candidate.category] == true then
        return DealerRelations.Data:isForestryEnabled()
    end

    if DealerRelations.Equipment.POWER_MANAGED_CATEGORIES[candidate.category] == true then
        return true
    end

    if DealerRelations.Equipment.CROP_CATEGORIES[candidate.category] ~= nil then
        return self:isCropEligible(candidate.category, candidate.fruitTypes)
    end

    if DealerRelations.Equipment.TRACTOR_CATEGORIES[candidate.category] == true then
        -- Tractors no longer have a DEFAULT_CATEGORY_FILTERS entry; the HP
        -- gate above is their only eligibility check.
        return true
    end

    return DealerRelations.Data:isCategoryEnabled(candidate.category)
end

-------------------------------------------------------------------------------
-- Returns the highest engine power (HP) among the player's currently owned
-- tractors.
--
-- Evaluated fresh at selection time, not cached at discovery, since owned
-- tractors change mid-save. Only the specific engine configuration the
-- player owns counts, not the store's full range of purchasable options.
-- Scoped to TRACTOR_CATEGORIES only.
--
-- @return number Highest owned tractor power in HP, 0 if none owned.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getOwnedMaxTractorPower()
    local maxPower = 0

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return maxPower
    end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle.configurations ~= nil and vehicle.configurations["motor"] ~= nil then
            local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)

            if storeItem ~= nil
                and DealerRelations.Equipment.TRACTOR_CATEGORIES[tostring(storeItem.categoryName)] == true
                and storeItem.configurations ~= nil
                and storeItem.configurations["motor"] ~= nil then

                local motorConfigId = vehicle.configurations["motor"]
                local configEntry = storeItem.configurations["motor"][motorConfigId]

                if configEntry ~= nil and configEntry.power ~= nil and configEntry.power > maxPower then
                    maxPower = configEntry.power
                end
            end
        end
    end

    return maxPower
end

-------------------------------------------------------------------------------
-- Returns the highest required power (neededPower) among the player's
-- currently owned implements.
--
-- Uses the equipmentByXmlFilename lookup built at discovery rather than
-- re-reading XML, since implement power requirements are static. Ownership
-- itself is live state, so this loop still runs fresh on every call.
--
-- @return number Highest owned implement neededPower in HP, 0 if none owned.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getOwnedMaxImplementNeededPower()
    local maxNeededPower = 0

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return maxNeededPower
    end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        local entry = DealerRelations.equipmentByXmlFilename[vehicle.configFileName]

        if entry ~= nil and entry.powerRole == "IMPLEMENT" and entry.displayPower ~= nil then
            if entry.displayPower > maxNeededPower then
                maxNeededPower = entry.displayPower
            end
        end
    end

    return maxNeededPower
end

-------------------------------------------------------------------------------
-- Returns a candidate's selection weight based on HP distance from the
-- relevant boundary:
--   - Tractor configs: distance above the owned-implement floor (biases
--     toward the cheapest config that still clears it).
--   - Implements: distance below the owned-tractor ceiling (biases toward
--     the implement closest to, but under, the ceiling).
--   - Anything else (categories still on a manual toggle): flat weight of 1.
--     No dedicated fallback constant, since manual categories are being
--     phased out.
--
-- @param candidate table Entry from equipmentList.
-- @param ownedMaxTractorPower number Precomputed once per selection cycle.
-- @param ownedMaxImplementNeededPower number Precomputed once per selection
--        cycle.
-- @return number Selection weight, always > 0.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getHpWeight(candidate, ownedMaxTractorPower, ownedMaxImplementNeededPower)
    local distance = nil

    if DealerRelations.Equipment.TRACTOR_CATEGORIES[candidate.category] == true
        and candidate.displayPower ~= nil then
        distance = candidate.displayPower - ownedMaxImplementNeededPower
    elseif candidate.powerRole == "IMPLEMENT" and candidate.displayPower ~= nil then
        distance = ownedMaxTractorPower - candidate.displayPower
    end

    if distance == nil then
        return 1
    end

    -- Eligibility should already guarantee this, but never let a negative
    -- distance reach the exponent.
    distance = math.max(distance, 0)

    return 1 / (distance + DealerRelations.CONSTANTS.HP_WEIGHT_CONSTANT) ^ DealerRelations.CONSTANTS.HP_WEIGHT_STEEPNESS
end
