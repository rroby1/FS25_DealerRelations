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
    TRAILERS = true,

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
    LOADERWAGONS = "WINDROW",
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
    AUGERWAGONS = true,
}

-------------------------------------------------------------------------------
-- Categories whose eligibility is governed by laden mass rather than a
-- manual player toggle or a real neededPower attribute in XML.
--
-- Neither sprayers nor fertilizer spreaders carry neededPower — confirmed
-- via XML inspection in 0.18.0. Their real constraint is the mass of the
-- implement plus whatever it's loaded with at max capacity (lime/dry
-- fertilizer for spreaders, liquid fertilizer/herbicide for sprayers).
-- See vault design note: 0.19.0 Mass-Based HP Eligibility.
-------------------------------------------------------------------------------
DealerRelations.Equipment.MASS_MANAGED_CATEGORIES = {
    FERTILIZERSPREADERS = true,
    SPRAYERS = true,
}

-------------------------------------------------------------------------------
-- Categories whose eligibility depends on live animal ownership and/or
-- husbandry building capability, rather than a manual filter, crop history,
-- or HP.
--
-- Unlike CROP_CATEGORIES, "ever" has no meaning here -- animal ownership is
-- binary and re-evaluated live at isCurrentlyEligible() time. See vault
-- design note: Bucket D - Animal-Tied Equipment.
-------------------------------------------------------------------------------
DealerRelations.Equipment.ANIMAL_CATEGORIES = {
    FORAGEMIXERS = "CATTLE",

    MANURESPREADERS = "MANURE_HEAP",

    SLURRYTANKS = "SLURRY",
    SLURRYTOOLS = "SLURRY",
    SLURRYTRANSPORT = "SLURRY",

    STRAWBLOWERS = "STRAW_BARN",
}

-------------------------------------------------------------------------------
-- HARVESTERS no longer has a manual toggle. This set exists purely for
-- category recognition in isDemoCandidate() -- eligibility itself is fully
-- automatic, handled by the combo/HP gate in isCurrentlyEligible(), mirroring
-- how TRACTOR_CATEGORIES lost its manual toggle earlier.
-------------------------------------------------------------------------------
DealerRelations.Equipment.HARVESTER_CATEGORIES = {
    HARVESTERS = true,
}

-------------------------------------------------------------------------------
-- Categories whose eligibility is governed by harvester-HP matching rather
-- than a manual player toggle. Distinct from POWER_MANAGED_CATEGORIES since
-- the comparison is against owned harvester HP, not tractor HP.
--
-- COMBINEWINDROWER and VEGETABLEHARVESTERS remain CROP_CATEGORIES-only —
-- they are not cutting-front attachments and are intentionally excluded
-- from this gate. Generic multi-brand headers (selectable per-brand
-- couplers via inputAttacherJointConfigurations) are excluded from the
-- demo pool entirely; see vault design note: 0.21.0 Header/Harvester/
-- Trailer/SeedTank Eligibility.
-------------------------------------------------------------------------------
DealerRelations.Equipment.HEADER_CATEGORIES = {
    CORNHEADERS = true,
    CUTTERS = true,
    SPECIALHEADERS = true,
}
-------------------------------------------------------------------------------
-- Default player-configurable category filters.
--
-- These categories are valid equipment-demo categories. New saves will start
-- with these enabled, and later save-specific settings can override them.
-------------------------------------------------------------------------------
DealerRelations.Equipment.DEFAULT_CATEGORY_FILTERS = {
    SEEDTANKS = true,
    CUTTERTRAILERS = true,
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
        and DealerRelations.Equipment.MASS_MANAGED_CATEGORIES[category] == nil
        and DealerRelations.Equipment.ANIMAL_CATEGORIES[category] == nil
        and DealerRelations.Equipment.HARVESTER_CATEGORIES[category] == nil
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

function DealerRelations.Equipment:readEquipmentXml(xmlFilename, category)
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

    -- Combination entries declare compatible vehicles (harvesters, trailers,
    -- seeders/planters, etc.) by XML filename. Not type-separated in the XML —
    -- a single item's list can mix categories — so this just collects the raw
    -- filenames; resolving what each one actually is happens at eligibility-
    -- check time via g_storeManager:getItemByXMLFilename(). Confirmed present
    -- on headers, harvesters, cutter trailers, seed tanks, and seeders/planters.
    -- Absence of an entry is not evidence of incompatibility -- modders
    -- frequently omit these even for their own mod's compatible pairs -- so
    -- this is used as an additional-eligibility signal, never an exclusive one.
    --
    -- The raw XML value carries the unresolved "$data" template prefix
    -- (e.g. "$data/vehicles/caseIH/axialFlow150/axialFlow150.xml"), while
    -- item.xmlFilename / vehicle.configFileName / equipmentByXmlFilename
    -- keys all use the resolved form with no "$" (confirmed via
    -- dr_headerHarvesterMatch -- every comboMatch was silently false
    -- because of this exact mismatch). Stripping a leading "$" here keeps
    -- this list in the same key space as everything it gets compared
    -- against. Only handles the "$data" case actually observed; a
    -- combination pointing into another mod's own directory (e.g.
    -- "$moddir_SomeOtherMod/...") hasn't been seen yet and may need
    -- separate handling if it turns up.
    -- See vault design note: 0.21.0 Header/Harvester/Trailer/SeedTank Eligibility.
    local combinationXmlFilenames = {}
    local combinationIndex = 0
    local combinationXmlFilename = getXMLString(xmlFile, string.format("vehicle.storeData.specs.combination(%d)#xmlFilename", combinationIndex))

    while combinationXmlFilename ~= nil do
        if combinationXmlFilename:sub(1, 1) == "$" then
            combinationXmlFilename = combinationXmlFilename:sub(2)
        end

        table.insert(combinationXmlFilenames, combinationXmlFilename)
        combinationIndex = combinationIndex + 1
        combinationXmlFilename = getXMLString(xmlFile, string.format("vehicle.storeData.specs.combination(%d)#xmlFilename", combinationIndex))
    end

    -- Dry mass: component can repeat (confirmed — the MF 9S tractor has two,
    -- summing to total chassis mass), so this sums every index found rather
    -- than assuming one. Same loop-until-nil shape as the motorConfiguration
    -- read below.
    local dryMass = nil
    local componentIndex = 0
    local componentMass = getXMLFloat(xmlFile, string.format("vehicle.base.components.component(%d)#mass", componentIndex))

    while componentMass ~= nil do
        dryMass = (dryMass or 0) + componentMass
        componentIndex = componentIndex + 1
        componentMass = getXMLFloat(xmlFile, string.format("vehicle.base.components.component(%d)#mass", componentIndex))
    end

    -- Capacity and fill types: both fillUnitConfiguration and fillUnit can
    -- repeat (confirmed — the K165 has two fillUnitConfigurations, 15600L and
    -- 18950L). Existence is checked via the #capacity read itself, same
    -- nil-terminated pattern as everything else in this function, rather than
    -- a separate existence-check API not otherwise used in this codebase.
    -- Max capacity across all entries is kept (worst-case load); fill type
    -- names accumulate across all entries into one combined set.
    local maxCapacity = nil
    local fillTypeNames = {}
    local configIndex = 0

    while true do
        local unitIndex = 0
        local foundAnyUnit = false

        while true do
            local unitKey = string.format(
                "vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(%d).fillUnits.fillUnit(%d)",
                configIndex, unitIndex
            )
            local capacity = getXMLFloat(xmlFile, unitKey .. "#capacity")

            if capacity == nil then
                break
            end

            foundAnyUnit = true

            if maxCapacity == nil or capacity > maxCapacity then
                maxCapacity = capacity
            end

            local fillTypesDirect = getXMLString(xmlFile, unitKey .. "#fillTypes")
            local fillTypeCategories = getXMLString(xmlFile, unitKey .. "#fillTypeCategories")

            self:collectFillTypeNames(fillTypeNames, fillTypesDirect, fillTypeCategories)

            unitIndex = unitIndex + 1
        end

        if not foundAnyUnit then
            break
        end

        configIndex = configIndex + 1
    end

    local data = {
        brand = getXMLString(xmlFile, "vehicle.storeData.brand"),
        storeImage = getXMLString(xmlFile, "vehicle.storeData.image"),  -- Store image path for Overview display
        fruitTypes = self:resolveFruitTypes(fruitTypeCategories, fruitTypesDirect, vineFruitType),
        dryMass = dryMass,
        maxCapacity = maxCapacity,
        fillTypeNames = fillTypeNames,
        combinationXmlFilenames = combinationXmlFilenames,
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
    elseif DealerRelations.Equipment.HEADER_CATEGORIES[category] == true then
        -- Headers carry no storeData.specs.neededPower. The only power
        -- attribute available is the raw physics PTO draw (kW), which needs
        -- converting to the HP units used everywhere else in this system.
        -- powerRole "HEADER" is kept distinct from "IMPLEMENT" so a header
        -- is never accidentally checked against tractor HP.
        local neededMaxPtoPower = getXMLFloat(xmlFile, "vehicle.powerConsumer#neededMaxPtoPower")

        if neededMaxPtoPower ~= nil then
            local headerRequiredHp = neededMaxPtoPower * DealerRelations.CONSTANTS.KW_TO_HP_RATIO
            data.powerRole = "HEADER"
            data.displayPower = headerRequiredHp
            data.powerMin = headerRequiredHp
            data.powerMax = headerRequiredHp
        end
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
    local xmlData = self:readEquipmentXml(item.xmlFilename, category)

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
    --
    -- Headers are excluded too: powerRole "HEADER" is set explicitly in
    -- readEquipmentXml() when neededMaxPtoPower is present, and a header
    -- with no neededMaxPtoPower at all is a malformed/unusual case that
    -- should surface as powerRole "NONE" rather than being silently
    -- defaulted to 0 HP like the categories below.
    if powerRole == "NONE"
        and (DealerRelations.Equipment.CROP_CATEGORIES[category] ~= nil
            or DealerRelations.Equipment.FORESTRY_CATEGORIES[category] ~= nil
            or DealerRelations.Equipment.POWER_MANAGED_CATEGORIES[category] == true)
        and DealerRelations.Equipment.HEADER_CATEGORIES[category] ~= true then
        powerRole = "IMPLEMENT"
        displayPower = 0
        powerMin = 0
        powerMax = 0
    end

    -- Mass-managed categories (SPRAYERS, FERTILIZERSPREADERS) also carry no
    -- neededPower, but unlike the categories above they don't default to 0 HP
    -- -- their real constraint is laden mass, computed from the dry mass, max
    -- capacity, and fill type data read in readEquipmentXml(). Falls back to
    -- 0 HP if that data is missing/malformed, same "modder omission treated
    -- like genuine non-requirement" philosophy as the block above, rather
    -- than excluding the item from discovery.
    --
    -- A self-propelled sprayer never reaches this branch: it already
    -- resolved to powerRole "SELF_PROPELLED" via storeData.specs.power
    -- upstream in readEquipmentXml(), excluded by construction.
    if powerRole == "NONE"
        and DealerRelations.Equipment.MASS_MANAGED_CATEGORIES[category] == true then

        local massBasedPower = xmlData ~= nil
            and self:getMassBasedRequiredPower(xmlData.dryMass, xmlData.maxCapacity, xmlData.fillTypeNames)
            or nil

        powerRole = "IMPLEMENT"
        displayPower = massBasedPower or 0
        powerMin = displayPower
        powerMax = displayPower
    end

    return {
        {
            name = item.name,
            brand = brand,
            storeBrand = item.brandName,
            xmlBrand = xmlData ~= nil and xmlData.brand or nil,
            category = category,
            fruitTypes = xmlData ~= nil and xmlData.fruitTypes or nil,
            combinationXmlFilenames = xmlData ~= nil and xmlData.combinationXmlFilenames or nil,
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

            -- Implements, headers, and harvesters are looked up by
            -- xmlFilename (see getOwnedMaxImplementNeededPower,
            -- getOwnedMaxHeaderRequiredPower, isCombinationMatchedToOwnedCategory).
            -- Headers and harvesters are category-gated rather than
            -- powerRole-gated because harvesters share powerRole
            -- "SELF_PROPELLED" with tractors, and tractors must stay
            -- excluded here: they're expanded into multiple candidates
            -- per engine config sharing one xmlFilename and would collide
            -- in this map. Headers/harvesters are never expanded this way
            -- (one candidate per xmlFilename), so caching them is safe.
            if candidate.xmlFilename ~= nil
                and (candidate.powerRole == "IMPLEMENT"
                    or DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true
                    or DealerRelations.Equipment.HARVESTER_CATEGORIES[candidate.category] == true) then
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
-- Resolves the set of fill type names a single fillUnit entry supports,
-- from whichever fill-type-linkage attribute is present in its XML, and
-- adds them into an accumulating result set.
--
-- Mirrors resolveFruitTypes() in shape: checked in order, first match wins.
--   1. fillTypeCategories — one or more space-separated category names,
--      resolved via g_fillTypeManager:getFillTypesByCategoryNames()
--   2. fillTypes          — direct fill type name(s), space-separated
--
-- Takes a `result` set rather than returning a new one, since an implement
-- can have multiple fillUnitConfigurations/fillUnits (e.g. two tank-size
-- tiers) whose fill types need to accumulate into one combined set.
--
-- @param result table Set to add resolved names into, keyed by name.
-- @param fillTypesDirect string|nil Direct fillTypes attribute value.
-- @param fillTypeCategories string|nil fillTypeCategories attribute value.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:collectFillTypeNames(result, fillTypesDirect, fillTypeCategories)
    if fillTypeCategories ~= nil then
        for categoryName in fillTypeCategories:gmatch("%S+") do
            local fillTypeIndices = g_fillTypeManager:getFillTypesByCategoryNames(categoryName)

            if fillTypeIndices ~= nil then
                for _, fillTypeIndex in ipairs(fillTypeIndices) do
                    local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)

                    if fillTypeName ~= nil then
                        result[string.upper(fillTypeName)] = true
                    end
                end
            end
        end
        return
    end

    if fillTypesDirect ~= nil then
        for name in fillTypesDirect:gmatch("%S+") do
            result[string.upper(name)] = true
        end
    end
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
-- Returns true when a candidate's animal-tied eligibility rule is currently
-- satisfied.
--
-- @param category string Candidate's store category.
-- @return boolean True when eligible, or when category has no animal rule.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isAnimalEligible(category)
    local rule = DealerRelations.Equipment.ANIMAL_CATEGORIES[category]

    if rule == nil then
        return true
    end

    if rule == "CATTLE" then
        return self:ownsCattleNow()
    end

    if rule == "MANURE_HEAP" then
        return self:ownsCattleNow() and self:ownsAnyManureHeapPlaceable()
    end

    if rule == "SLURRY" then
        return self:ownsAccumulatedSlurry()
    end

    if rule == "STRAW_BARN" then
        return self:ownsCattleNow() and self:ownsStrawCapableBarn()
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

    -- Headers require either a curated compatibility declaration with an
    -- owned harvester, or a derived HP match -- combo data is confirmed
    -- unreliable/incomplete (headerC16F has harvester combos but no trailer
    -- combo; delta9380 has none at all), so this is OR, not AND: either
    -- signal alone is sufficient, and a header with neither (powerRole
    -- "NONE", no neededMaxPtoPower in XML) can only qualify via combo match.
    -- No owned harvester yet means getOwnedMaxHarvesterPower() returns 0,
    -- which naturally excludes headers until a capable harvester is owned
    -- -- same floor-of-0 pattern as the implement/tractor gate above.
    if DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true then
        local comboMatch = self:isCombinationMatchedToOwnedCategory(candidate, DealerRelations.Equipment.HARVESTER_CATEGORIES)
        local hpMatch = candidate.displayPower ~= nil
            and candidate.displayPower <= self:getOwnedMaxHarvesterPower()

        if not comboMatch and not hpMatch then
            return false
        end
    end

    -- Harvesters require either a curated compatibility declaration with an
    -- owned header, or a derived HP match -- mirrors the header gate above.
    -- No owned header yet means getOwnedMaxHeaderRequiredPower() returns 0,
    -- so this never rejects a harvester on HP alone until the player owns
    -- a header demanding more than it -- same "base machine always
    -- available" pattern as tractors relative to implements.
    if DealerRelations.Equipment.HARVESTER_CATEGORIES[candidate.category] == true then
        local comboMatch = self:isCombinationMatchedToOwnedCategory(candidate, DealerRelations.Equipment.HEADER_CATEGORIES)
        local hpMatch = candidate.displayPower ~= nil
            and candidate.displayPower >= self:getOwnedMaxHeaderRequiredPower()

        if not comboMatch and not hpMatch then
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

    if DealerRelations.Equipment.ANIMAL_CATEGORIES[candidate.category] ~= nil then
        return self:isAnimalEligible(candidate.category)
    end

    if DealerRelations.Equipment.HARVESTER_CATEGORIES[candidate.category] == true then
        -- Harvesters no longer have a DEFAULT_CATEGORY_FILTERS entry; the
        -- combo/HP gate above is their only eligibility check.
        return true
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

-------------------------------------------------------------------------------
-- Returns the highest real-world density (kg/L) among a set of resolved
-- fill type names, read live from g_fillTypeManager rather than any
-- hardcoded per-fill-type constant.
--
-- g_fillTypeManager:getFillTypeByName(name).massPerLiter is stored
-- internally at 1/1000th of the XML kg/L value (confirmed via GDN source
-- and live dr_fillTypeDensities output: LIME raw 0.0012 -> x1000 -> 1.2,
-- matching XML) -- must be multiplied back by 1000 here.
--
-- Taking the max reproduces the lime-overrides-fertilizer rule (1.2 > 0.8)
-- without a hardcoded per-category branch, and resolves correctly if a
-- map/mod changes any density or adds another fill type.
--
-- @param fillTypeNames table Set of fill type names, keyed by name.
-- @return number|nil Highest density in kg/L, nil if none resolved.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getMaxFillTypeDensity(fillTypeNames)
    if fillTypeNames == nil or g_fillTypeManager == nil then
        return nil
    end

    local maxDensity = nil

    for fillTypeName in pairs(fillTypeNames) do
        local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)

        if fillType ~= nil and fillType.massPerLiter ~= nil then
            local densityKgPerLiter = fillType.massPerLiter * 1000

            if maxDensity == nil or densityKgPerLiter > maxDensity then
                maxDensity = densityKgPerLiter
            end
        end
    end

    return maxDensity
end

-------------------------------------------------------------------------------
-- Computes required HP for a mass-managed implement (SPRAYERS,
-- FERTILIZERSPREADERS), derived from laden mass rather than a real
-- neededPower XML attribute -- neither category carries one (confirmed
-- 0.18.0).
--
-- ladenMass = dryMass + (maxCapacity * densityOfHeaviestSupportedFillType)
-- requiredPower = ladenMass / MASS_TO_HP_RATIO
--
-- Gates on max capacity (worst-case load), not current fill level, since
-- demo selection happens before an implement is ever loaded -- same
-- static-attribute assumption HP eligibility already makes for neededPower.
-- See vault design note: 0.19.0 Mass-Based HP Eligibility.
--
-- @param dryMass number|nil Implement dry mass in kg.
-- @param maxCapacity number|nil Max fillUnit capacity in liters.
-- @param fillTypeNames table|nil Set of supported fill type names.
-- @return number|nil Required HP, nil if mass, capacity, or density
--         couldn't be resolved.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getMassBasedRequiredPower(dryMass, maxCapacity, fillTypeNames)
    if dryMass == nil or maxCapacity == nil then
        return nil
    end

    local density = self:getMaxFillTypeDensity(fillTypeNames)

    if density == nil then
        return nil
    end

    local ladenMass = dryMass + (maxCapacity * density)

    return ladenMass / DealerRelations.CONSTANTS.MASS_TO_HP_RATIO
end

-------------------------------------------------------------------------------
-- Returns true when the player currently owns any cattle on a farm-owned
-- husbandry placeable.
--
-- Live/current signal only -- no "ever owned" tracking, unlike crop history.
-- Detects via AnimalType.COW at the barn level (confirmed via dr_animalTypes
-- debug dump: AnimalType.COW = 1), not via subType/cluster matching or the
-- base-game ANIMAL fill type category -- animal type is a single barn-level
-- value (spec_husbandryAnimals.animalTypeIndex via getAnimalTypeIndex()),
-- not something that needs per-cluster inspection. This correctly includes
-- all cattle breeds (e.g. water buffalo, highland cattle) as subtypes under
-- the one COW type, rather than needing each breed enumerated separately.
--
-- @return boolean True if any farm-owned husbandry placeable currently has
--         cattle.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:ownsCattleNow()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil then
        return false
    end

    local farmId = g_currentMission:getFarmId()

    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable.spec_husbandryAnimals ~= nil
            and placeable:getOwnerFarmId() == farmId
            and placeable:getAnimalTypeIndex() == AnimalType.COW
            and placeable:getNumOfAnimals() > 0 then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true when the player currently has a manure heap (or extension)
-- linked to a farm-owned husbandry placeable.
--
-- Confirmed live via dr_husbandryCapacity: a cow barn's own MANURE capacity
-- is 0 with no heap connected (cowBarnSmall, matching cowBarnBig's static
-- store XML), and becomes nonzero once a manure heap + extension are placed
-- and linked as a storage extension (cowBarnMedium, capacity=4000000 after
-- linking, confirmed by Rick). Barns never store dry manure internally --
-- capacity > 0 is a direct signal that an external heap is currently
-- linked, not a search for a separate heap placeable.
--
-- @return boolean True if any farm-owned husbandry placeable currently has
--         nonzero MANURE capacity.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:ownsAnyManureHeapPlaceable()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil
        or g_fillTypeManager == nil then
        return false
    end

    local manureIndex = g_fillTypeManager:getFillTypeIndexByName("MANURE")

    if manureIndex == nil then
        return false
    end

    local farmId = g_currentMission:getFarmId()

    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable.spec_husbandry ~= nil
            and placeable:getOwnerFarmId() == farmId
            and placeable:getHusbandryCapacity(manureIndex, farmId) > 0 then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true when the player currently has any LIQUIDMANURE accumulated
-- in a farm-owned husbandry placeable.
--
-- Accumulation signal, not capability -- LIQUIDMANURE production has no
-- straw dependency (cows produce it regardless of bedding), and slow
-- production means a demo offered before any has accumulated would be
-- useless for the entire demo window. getHusbandryFillLevel() is a live
-- runtime call (registered function, delegates to
-- unloadingStation:getFillLevel()), replacing the save-XML "search for an
-- accumulated fill node" approach entirely.
--
-- @return boolean True if any farm-owned husbandry placeable currently has
--         LIQUIDMANURE fill level > 0.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:ownsAccumulatedSlurry()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil
        or g_fillTypeManager == nil then
        return false
    end

    local liquidManureIndex = g_fillTypeManager:getFillTypeIndexByName("LIQUIDMANURE")

    if liquidManureIndex == nil then
        return false
    end

    local farmId = g_currentMission:getFarmId()

    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable.spec_husbandry ~= nil
            and placeable:getOwnerFarmId() == farmId
            and placeable:getHusbandryFillLevel(liquidManureIndex, farmId) > 0 then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true when the player currently owns a husbandry placeable capable
-- of accepting straw.
--
-- Capability signal, not accumulation -- confirmed via
-- PlaceableHusbandryStraw.lua: the straw/manure mechanism only exists on a
-- placeable at all if its XML defines a <husbandry.straw> block, exposed at
-- runtime as spec_husbandryStraw. Presence of this spec table is a direct
-- existence check, requiring no fill-type index lookup.
--
-- @return boolean True if any farm-owned husbandry placeable currently
--         supports straw intake.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:ownsStrawCapableBarn()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil then
        return false
    end

    local farmId = g_currentMission:getFarmId()

    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable.spec_husbandryStraw ~= nil
            and placeable:getOwnerFarmId() == farmId then
            return true
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true if candidate and an owned vehicle's cached equipment entry
-- reference each other via storeData.specs.combination, checked in both
-- directions since modders do not reliably mirror these entries (confirmed:
-- headerC16F lists harvester combos but no trailer combo; delta9380 lists
-- none at all). A match on either side is sufficient -- this function never
-- treats absence as disqualifying, only presence as confirming.
--
-- Combination xmlFilename strings are compared directly against
-- equipmentByXmlFilename keys (themselves store item xmlFilename values) --
-- the same untranslated key space getOwnedMaxImplementNeededPower already
-- trusts for vehicle.configFileName lookups, so no additional normalization
-- is applied here.
--
-- @param candidate table Entry from equipmentList.
-- @param ownedEntry table Cached equipment entry for an owned vehicle, from
--        equipmentByXmlFilename.
-- @return boolean True if either side's combination list references the other.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isCombinationMatch(candidate, ownedEntry)
    if candidate == nil or ownedEntry == nil then
        return false
    end

    if candidate.combinationXmlFilenames ~= nil then
        for _, xmlFilename in ipairs(candidate.combinationXmlFilenames) do
            if xmlFilename == ownedEntry.xmlFilename then
                return true
            end
        end
    end

    if ownedEntry.combinationXmlFilenames ~= nil then
        for _, xmlFilename in ipairs(ownedEntry.combinationXmlFilenames) do
            if xmlFilename == candidate.xmlFilename then
                return true
            end
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns true if candidate is combination-matched (either direction, via
-- isCombinationMatch) to any currently owned vehicle whose category is in
-- the given category set.
--
-- Evaluated fresh at eligibility-check time, not cached, since ownership is
-- live state -- same rationale as getOwnedMaxTractorPower and
-- getOwnedMaxImplementNeededPower.
--
-- @param candidate table Entry from equipmentList.
-- @param categorySet table Set of category names to check ownership against
--        (e.g. { HARVESTERS = true } or HEADER_CATEGORIES).
-- @return boolean True if a combination match exists with any owned vehicle
--         in categorySet.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:isCombinationMatchedToOwnedCategory(candidate, categorySet)
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return false
    end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        local ownedEntry = DealerRelations.equipmentByXmlFilename[vehicle.configFileName]

        if ownedEntry ~= nil and categorySet[ownedEntry.category] == true then
            if self:isCombinationMatch(candidate, ownedEntry) then
                return true
            end
        end
    end

    return false
end

-------------------------------------------------------------------------------
-- Returns the highest engine power (HP) among the player's currently owned
-- harvesters.
--
-- Mirrors getOwnedMaxTractorPower() exactly -- reads the live selected motor
-- configuration rather than the cached equipmentList range, since a specific
-- owned harvester's actual engine tier (if the store offers more than one)
-- is what matters for matching against a header's required power, not the
-- model's full range.
--
-- @return number Highest owned harvester power in HP, 0 if none owned.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getOwnedMaxHarvesterPower()
    local maxPower = 0

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return maxPower
    end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle.configurations ~= nil and vehicle.configurations["motor"] ~= nil then
            local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)

            if storeItem ~= nil
                and tostring(storeItem.categoryName) == "HARVESTERS"
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
-- Returns the highest required power (derived HP) among the player's
-- currently owned headers.
--
-- Mirrors getOwnedMaxImplementNeededPower() exactly, filtered to powerRole
-- "HEADER" instead of "IMPLEMENT". Uses the cached equipmentByXmlFilename
-- entry rather than a live per-config read, since headers don't get the
-- tractor-style per-motor-config candidate expansion in resolveDemoCandidate
-- -- a header's required power is fixed per model, not per selected engine
-- tier.
--
-- @return number Highest owned header required power in HP, 0 if none owned.
-------------------------------------------------------------------------------
function DealerRelations.Equipment:getOwnedMaxHeaderRequiredPower()
    local maxRequiredPower = 0

    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return maxRequiredPower
    end

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        local entry = DealerRelations.equipmentByXmlFilename[vehicle.configFileName]

        if entry ~= nil and entry.powerRole == "HEADER" and entry.displayPower ~= nil then
            if entry.displayPower > maxRequiredPower then
                maxRequiredPower = entry.displayPower
            end
        end
    end

    return maxRequiredPower
end
