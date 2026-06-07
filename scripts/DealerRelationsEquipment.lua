-------------------------------------------------------------------------------
-- DealerRelationsEquipment.lua
--
-- Discovers equipment information from the Farming Simulator store data.
--
-- Builds an in-memory equipment list used by future Dealer Relations systems.
-- This module does not save equipment data and does not select demo equipment.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Equipment = DealerRelations.Equipment or {}

-------------------------------------------------------------------------------
-- Data Definition
-------------------------------------------------------------------------------

DealerRelations.equipmentList = {}

-------------------------------------------------------------------------------
-- Category Classification
--
-- Determines whether a store category is eligible for Dealer Relations
-- demo consideration.
--
-- true  = Eligible
-- false = Excluded
--
-- Categories not present in this table are considered unclassified and
-- will be excluded by default.
-------------------------------------------------------------------------------

DealerRelations.Equipment.CATEGORIES = {

    -- Animal
    ANIMALPENS = false,
    ANIMALTRANSPORT = false,

    -- Harvest & Crop Handling
    AUGERWAGONS = true,
    BALES = false,
    BEETHARVESTERCUTTERS = true,
    BEETHARVESTERS = true,
    BEETLOADING = true,
    BELTS = true,

    -- Consumables
    BIGBAGPALLETS = false,
    BIGBAGS = false,

    -- Vehicles
    CARS = false,
    TRUCKS = false,

    -- Hand Tools
    CHAINSAWS = false,
    FLASHLIGHTS = false,
    HANDTOOLSANIMALS = false,
    HANDTOOLSMISC = false,
    MARKINGSPRAY = false,

    -- Headers
    COMBINEWINDROWER = true,
    CORNHEADERS = true,
    CUTTERS = true,
    FORAGEHARVESTERCUTTERS = true,
    SPECIALHEADERS = true,

    -- Cotton
    COTTONHARVESTERS = true,
    COTTONTRANSPORT = true,

    -- Tillage
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

    -- Placeables
    DECORATION = false,
    DIESELTANKS = false,
    FARMHOUSES = false,
    FENCES = false,
    FLOODLIGHTING = false,
    GARDENSHEDS = false,
    GENERATORS = false,
    PLACEABLEMISC = false,
    PRODUCTIONPOINTS = false,
    SELLINGPOINTS = false,
    SHEDS = false,
    SHIPPINGCONTAINERS = false,
    SILOEXTENSIONS = false,
    SILOS = false,
    STORAGES = false,
    TREES = false,
	BEEHIVES = false,

    -- Fertilizing & Spraying
    FERTILIZERSPREADERS = true,
    MANURESPREADERS = true,
    SLURRYTOOLS = true,
    SPRAYERS = true,

    -- Fillables
    FILLABLETANKS = true,
    IBC = false,
    PALLETS = false,
    PALLETSILAGE = false,
    SEEDTANKS = true,
    SLURRYTANKS = true,
    WATERTANKS = true,

    -- Forage
    FORAGEHARVESTERS = true,
    FORAGEHARVESTERCUTTERTRAILERS = true,
    FORAGEMIXERS = true,
    GRASSLANDCARE = true,
    LOADERWAGONS = true,
    MOWERS = true,
    STRAWBLOWERS = true,
    TEDDERS = true,
    WINDROWERS = true,

    -- Forestry
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

    -- Loaders
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

    -- Grapes & Olives
    GRAPEHARVESTERS = true,
    GRAPETOOLS = true,
    GRAPETRAILERS = true,
    OLIVEHARVESTERS = true,

    -- Harvesters
    GREENBEANHARVESTERS = true,
    HARVESTERS = true,
    PEAHARVESTERS = true,
    POTATOHARVESTING = true,
    RICEHARVESTERS = true,
    SPINACHHARVESTERS = true,
    SUGARCANEHARVESTERS = true,
    VEGETABLEHARVESTERS = true,

    -- Planting
    PLANTERS = true,
    POTATOPLANTING = true,
    RICEPLANTERS = true,
    SEEDERS = true,
    SUGARCANEPLANTERS = true,
    VEGETABLEPLANTERS = true,

    -- Misc
    CUTTERTRAILERS = true,
    LEVELER = false,
    MISC = false,
    MISCDRIVABLES = false,
    OBJECTANIMAL = false,
    SILOCOMPACTION = false,
    WEIGHTS = true,
    WINTEREQUIPMENT = true,
	BARRELS = false,

    -- Transport
    LOWLOADERS = true,
    SLURRYTRANSPORT = true,
    SUGARCANETRANSPORT = true,
    TRAILERS = true,
    TRAILERSCHANGINGSYSTEM = false,
    TRAILERSSEMI = false,

	-- Baling
	BALES = false,
	BALINGMISC = false,
	BALERSSQUARE = true,
	BALERSROUND = true,
	BALELOADERS = true,
	BALEWRAPPERS = true,
	BALETRANSPORT = true,

    -- Tractors
    TRACTORSS = true,
    TRACTORSM = true,
    TRACTORSL = true
}

-------------------------------------------------------------------------------
-- Returns true when a store item should be considered for dealer demos.
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
    local allowed = DealerRelations.Equipment.CATEGORIES[category]

    if allowed == nil then
        DealerRelations.warning("Unclassified equipment category: " .. category)
        return false
    end

    return allowed == true
end

-------------------------------------------------------------------------------
-- Discovers eligible Dealer Relations demo equipment from the FS25 store.
--
-- Builds an in-memory list only. This does not save equipment data and does
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
            candidateCount = candidateCount + 1

            table.insert(DealerRelations.equipmentList, {
                name = item.name,
                brand = item.brandName,
                category = item.categoryName,
                price = item.price,
                xmlFilename = item.xmlFilename
            })
        end
    end

    DealerRelations.log("Store items discovered: " .. tostring(storeItemCount))
    DealerRelations.log("Demo candidates discovered: " .. tostring(candidateCount))
end