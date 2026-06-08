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
    FILLABLETANKS = false,
    IBC = false,
    PALLETS = false,
    PALLETSILAGE = false,
    SEEDTANKS = true,
    SLURRYTANKS = true,
    WATERTANKS = false,

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
-- Reads equipment data directly from a vehicle XML file.
--
-- Used by Dealer Relations to access XML attributes that are not available
-- from store manager data alone.
--
-- Currently reads:
--   - Brand
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

			local xmlData = self:readEquipmentXml(item.xmlFilename)

			table.insert(DealerRelations.equipmentList, {
				name = item.name,
				brand = item.brandName,
				category = item.categoryName,
				price = item.price,
				xmlFilename = item.xmlFilename,
				powerRole = xmlData ~= nil and xmlData.powerRole or "NONE",
				displayPower = xmlData ~= nil and xmlData.displayPower or nil,
				powerMin = xmlData ~= nil and xmlData.powerMin or nil,
				powerMax = xmlData ~= nil and xmlData.powerMax or nil,
				xmlBrand = xmlData ~= nil and xmlData.brand or nil
			})
		end
    end

    DealerRelations.log("Store items discovered: " .. tostring(storeItemCount))
    DealerRelations.log("Demo candidates discovered: " .. tostring(candidateCount))
end

-------------------------------------------------------------------------------
-- Brand Classification
--
-- Determines whether a brand is eligible for Dealer Relations demo consideration.
--
-- true  = Eligible
-- false = Excluded
--
-- Brands not present in this table are considered unclassified and will be
-- excluded by default.
-------------------------------------------------------------------------------

DealerRelations.Equipment.BRANDS = {
    AGCO = true,
    AGIBATCO = true,
    AGISTORM = true,
    AGIWESTFIELD = true,
    AGRIFAC = true,
    AGRIO = true,
    AGRISEM = true,
    AGROMASZ = true,
    ALBUTT = true,
    ALPEGO = true,
    AMAZONE = true,
    AMITYTECH = true,
    ANDERSONGROUP = true,
    ANNABURGER = true,
    ANTONIOCARRARO = true,
    ARCUSIN = true,
    BEDNAR = true,
    BERGMANN = true,
    BERTHOUD = true,
    BOMECH = true,
    BRANDT = true,
    BRANTNER = true,
    BREDAL = true,
    BRESSELUNDLADE = true,
    CAPELLO = true,
    CASEIH = true,
    CHALLENGER = true,
    CLAAS = true,
    CONVEYALL = true,
    DALBO = true,
    DAMCON = true,
    DEMCO = true,
    DEUTZFAHR = true,
    DEWULF = true,
    EINBOECK = true,
    ELHO = true,
    ELMERSMFG = true,
    ERO = true,
    FARESIN = true,
    FARMAX = true,
    FARMET = true,
    FARMTECH = true,
    FENDT = true,
    FIAT = true,
    FLIEGL = true,
    FUHRMANN = true,
    GERINGHOFF = true,
    GESSNER = true,
    GOEWEIL = true,
    GORENC = true,
    GREATPLAINS = true,
    GREGOIRE = true,
    GRIMME = true,
    HARDI = true,
    HAUER = true,
    HAWE = true,
    HEIZOMAT = true,
    HOLMER = true,
    HORSCH = true,
    IMPEX = true,
    ISEKI = true,
    JCB = true,
    JENZ = true,
    JMMANUFACTURING = true,
    JOHNDEERE = true,
    JUNGHEINRICH = true,
    KAWECO = true,
    KEMPER = true,
    KESLA = true,
    KINZE = true,
    KNOCHE = true,
    KOCKERLING = true,
    KOLLER = true,
    KOMATSU = true,
    KOTTE = true,
    KRAMER = true,
    KRAMPE = true,
    KROEGER = true,
    KRONE = true,
    KUBOTA = true,
    KUHN = true,
    KVERNELAND = true,
    LACOTEC = true,
    LANDINI = true,
    LEMKEN = true,
    LINDNER = true,
    LIZARD = true,
    LODEKING = true,
    MACDON = true,
    MAGSI = true,
    MANITOU = true,
    MASSEYFERGUSON = true,
    MCCORMACK = true,
    MCCORMICK = true,
    MERIDIAN = true,
    MERLO = true,
    MZURI = true,
    NARDI = true,
    NEWHOLLAND = true,
    NOVAG = true,
    OXBO = true,
    PALADIN = true,
    PFANZELT = true,
    PITTSTRAILERS = true,
    POETTINGER = true,
    PONSSE = true,
    PRINOTH = true,
    PROVITIS = true,
    QUICKE = true,
    REITER = true,
    RIEDLER = true,
    RIGITRAC = true,
    RISUTEC = true,
    ROPA = true,
    ROTTNE = true,
    RUDOLPH = true,
    SALEK = true,
    SAMASZ = true,
    SAME = true,
    SAMSONAGRO = true,
    SCHAEFFER = true,
    SCHUITEMAKER = true,
    SCHWARZMUELLER = true,
    SENNEBOGEN = true,
    SILOKING = true,
    SIP = true,
    STEYR = true,
    STREUMASTER = true,
    SUMMERSMFG = true,
    TAJFUN = true,
    TENWINKEL = true,
    TMCCANCELA = true,
    TREFFLER = true,
    TT = true,
    UNIA = true,
    VAEDERSTAD = true,
    VALTRA = true,
    VERMEER = true,
    VOLVO = true,
    WALKABOUT = true,
    WESTTECH = true,
    ZETOR = true,
    ZUNHAMMER = true
}