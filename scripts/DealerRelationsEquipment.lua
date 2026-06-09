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
            local xmlData = self:readEquipmentXml(item.xmlFilename)
            local brand = xmlData ~= nil and xmlData.brand or item.brandName
            local brandAllowed = DealerRelations.Equipment.BRANDS[brand]

            if brandAllowed == true then
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
    AGCO = false,
    AGIBATCO = false,
    AGISTORM = false,
    AGIWESTFIELD = false,
    AGRIFAC = false,
    AGRIO = false,
    AGRISEM = false,
    AGROMASZ = false,
    ALBUTT = false,
    ALPEGO = false,
    AMAZONE = false,
    AMITYTECH = false,
    ANDERSONGROUP = false,
    ANNABURGER = false,
    ANTONIOCARRARO = false,
    ARCUSIN = false,
    BEDNAR = false,
    BERGMANN = false,
    BERTHOUD = false,
    BOMECH = false,
    BRANDT = false,
    BRANTNER = false,
    BREDAL = false,
    BRESSELUNDLADE = false,
    CAPELLO = false,
    CASEIH = false,
    CHALLENGER = false,
    CLAAS = false,
    CONVEYALL = false,
    DALBO = false,
    DAMCON = false,
    DEMCO = false,
    DEUTZFAHR = false,
    DEWULF = false,
    EINBOECK = false,
    ELHO = false,
    ELMERSMFG = false,
    ERO = false,
    FARESIN = false,
    FARMAX = false,
    FARMET = false,
    FARMTECH = false,
    FENDT = false,
    FIAT = false,
    FLIEGL = false,
    FUHRMANN = false,
    GERINGHOFF = false,
    GESSNER = false,
    GOEWEIL = false,
    GORENC = false,
    GREATPLAINS = false,
    GREGOIRE = false,
    GRIMME = false,
    HARDI = false,
    HAUER = false,
    HAWE = false,
    HEIZOMAT = false,
    HOLMER = false,
    HORSCH = false,
    IMPEX = false,
    ISEKI = false,
    JCB = false,
    JENZ = false,
    JMMANUFACTURING = false,
    JOHNDEERE = false,
    JUNGHEINRICH = false,
    KAWECO = false,
    KEMPER = false,
    KESLA = false,
    KINZE = false,
    KNOCHE = false,
    KOCKERLING = false,
    KOLLER = false,
    KOMATSU = false,
    KOTTE = false,
    KRAMER = false,
    KRAMPE = false,
    KROEGER = false,
    KRONE = false,
    KUBOTA = false,
    KUHN = false,
    KVERNELAND = false,
    LACOTEC = false,
    LANDINI = false,
    LEMKEN = false,
    LINDNER = false,
    LIZARD = false,
    LODEKING = false,
    MACDON = false,
    MAGSI = false,
    MANITOU = false,
    MASSEYFERGUSON = true,
    MCCORMACK = false,
    MCCORMICK = false,
    MERIDIAN = false,
    MERLO = false,
    MZURI = false,
    NARDI = false,
    NEWHOLLAND = false,
    NOVAG = false,
    OXBO = false,
    PALADIN = false,
    PFANZELT = false,
    PITTSTRAILERS = false,
    POETTINGER = false,
    PONSSE = false,
    PRINOTH = false,
    PROVITIS = false,
    QUICKE = false,
    REITER = false,
    RIEDLER = false,
    RIGITRAC = false,
    RISUTEC = false,
    ROPA = false,
    ROTTNE = false,
    RUDOLPH = false,
    SALEK = false,
    SAMASZ = false,
    SAME = false,
    SAMSONAGRO = false,
    SCHAEFFER = false,
    SCHUITEMAKER = false,
    SCHWARZMUELLER = false,
    SENNEBOGEN = false,
    SILOKING = false,
    SIP = false,
    STEYR = false,
    STREUMASTER = false,
    SUMMERSMFG = false,
    TAJFUN = false,
    TENWINKEL = false,
    TMCCANCELA = false,
    TREFFLER = false,
    TT = false,
    UNIA = false,
    VAEDERSTAD = false,
    VALTRA = false,
    VERMEER = false,
    VOLVO = false,
    WALKABOUT = false,
    WESTTECH = false,
    ZETOR = false,
    ZUNHAMMER = false
}

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
            DealerRelations.log("Demo candidate was recently offered; selecting another candidate")
            candidate = nil
        end
    until candidate ~= nil

    DealerRelations.Data:addRecentDemoCandidate(candidateKey)
	
	DealerRelations.log(
		"Added recent demo candidate: " .. candidateKey
	)
	
	DealerRelations.log(
		"Recent demo candidates: " ..
		table.concat(DealerRelations.Data:getRecentDemoCandidates(), " || ")
	)

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
-- Demo Candidate Key
-------------------------------------------------------------------------------

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