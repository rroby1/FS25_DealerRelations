-------------------------------------------------------------------------------
-- DealerRelationsPersistence.lua
--
-- Handles saving and loading Dealer Relations data.
--
-- Only stored data is persisted. Derived values, such as relationship level,
-- are calculated at runtime and are not saved.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Persistence = DealerRelations.Persistence or {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

DealerRelations.Persistence.FILE_NAME = "dealerRelations.xml"

-------------------------------------------------------------------------------
-- File Path
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Builds the full path to dealerRelations.xml for the given savegame directory.
--
-- @param savegameDirectory string Active savegame directory.
-- @return string Full file path to dealerRelations.xml.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:getFilePath(savegameDirectory)
    return savegameDirectory .. "/" .. self.FILE_NAME
end

-------------------------------------------------------------------------------
-- Saves Dealer Relations data to XML in the active savegame directory.
--
-- @param savegameDirectory string Active savegame directory.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:save(savegameDirectory)
    if savegameDirectory == nil then
        DealerRelations.warning("Cannot save dealerRelations.xml: savegameDirectory is nil")
        return
    end

    local filePath = self:getFilePath(savegameDirectory)
    local xmlFile = createXMLFile("dealerRelationsXML", filePath, "dealerRelations")

    -- Keep save() as the orchestration point only.
    -- Each helper owns one saved data group so future persistence changes
    -- can be added without turning save() into one large mixed block.
    self:saveCoreData(xmlFile)
    self:saveSettings(xmlFile)
    self:saveDealerName(xmlFile)
    self:saveRecentDemoCandidates(xmlFile)
    self:saveActiveDemoOffer(xmlFile)
    self:saveActiveDemoVehicles(xmlFile)
    self:saveActiveLoans(xmlFile)
    self:saveCropsEverGrown(xmlFile)

    -- Player settings
    self:saveCategoryFilters(xmlFile)
    self:saveBrandFilters(xmlFile)

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

-------------------------------------------------------------------------------
-- Saves core dealer state values to XML.
--
-- Derived values such as relationship level are recalculated at runtime
-- and are not saved. Suspension fields are omitted when nil to keep
-- older saves clean.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveCoreData(xmlFile)
    setXMLFloat(xmlFile, "dealerRelations.confidence", DealerRelations.Data:getConfidence())

    setXMLInt(
        xmlFile,
        "dealerRelations.lastDemoCheckMonth",
        DealerRelations.Data:getLastDemoCheckMonth()
    )

    -- Save suspension end month only when active.
    -- Omitting the node when nil keeps older saves clean.
    local suspensionEndMonth = DealerRelations.Data:getSuspensionEndMonth()

    if suspensionEndMonth ~= nil then
        setXMLInt(xmlFile, "dealerRelations.suspensionEndMonth", suspensionEndMonth)
    end

    -- Save pending suspension months only when set.
    local pendingSuspensionMonths = DealerRelations.Data:getPendingSuspensionMonths()

    if pendingSuspensionMonths ~= nil then
        setXMLInt(xmlFile, "dealerRelations.pendingSuspensionMonths", pendingSuspensionMonths)
    end

    setXMLInt(xmlFile, "dealerRelations.totalLoansRepaid",
        DealerRelations.Data:getTotalLoansRepaid())

    setXMLInt(xmlFile, "dealerRelations.totalMissedPayments",
        DealerRelations.Data:getTotalMissedPayments())
end

-------------------------------------------------------------------------------
-- Saves player-configurable Dealer Relations settings to XML.
--
-- Settings are written as their own group so future additions do not
-- mix configuration data into core relationship state.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveSettings(xmlFile)
    setXMLBool(
        xmlFile,
        "dealerRelations.settings#enabled",
        DealerRelations.Data:isEnabled()
    )

    setXMLBool(
        xmlFile,
        "dealerRelations.settings#debug",
        DealerRelations.Data:isDebugEnabled()
    )

    setXMLBool(
        xmlFile,
        "dealerRelations.settings#forestryEnabled",
        DealerRelations.Data:isForestryEnabled()
    )
end

-------------------------------------------------------------------------------
-- Saves the recent demo candidate history to XML.
--
-- Only the stable candidate key is persisted, not the full equipment record.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveRecentDemoCandidates(xmlFile)
    local recentCandidates = DealerRelations.Data:getRecentDemoCandidates()

    for index, candidateKey in ipairs(recentCandidates) do
        local key = string.format(
            "dealerRelations.recentDemoCandidates.candidate(%d)",
            index - 1
        )

        setXMLString(
            xmlFile,
            key .. "#key",
            candidateKey
        )
    end
end

-------------------------------------------------------------------------------
-- Saves active demo vehicle records to XML.
--
-- Runtime vehicle objects are not persisted. Vehicles are restored on
-- load by looking up their saved uniqueId in the game vehicle system.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveActiveDemoOffer(xmlFile)
    local activeOffer = DealerRelations.Data:getActiveDemoOffer()

    if activeOffer == nil then
        return
    end

    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#candidateKey", activeOffer.candidateKey)
    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#name", activeOffer.name)
    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#brand", activeOffer.brand)
    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#category", activeOffer.category)
    setXMLFloat(xmlFile, "dealerRelations.activeDemoOffer#price", activeOffer.price or 0)
    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#xmlFilename", activeOffer.xmlFilename)
    setXMLString(xmlFile, "dealerRelations.activeDemoOffer#powerRole", activeOffer.powerRole)
    setXMLInt(xmlFile, "dealerRelations.activeDemoOffer#displayPower", activeOffer.displayPower or 0)
    setXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMin", activeOffer.powerMin or 0)
    setXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMax", activeOffer.powerMax or 0)
    setXMLInt(xmlFile, "dealerRelations.activeDemoOffer#offerMonth", activeOffer.offerMonth or 0)

    -- Companion fields (e.g. the trailer bundled with a header offer).
    -- Omitted entirely when there is no companion, same "nil means absent"
    -- convention as overdueClockStartDay below -- a candidateKey with no
    -- companion fields present simply means this offer has no companion,
    -- not a load error.
    if activeOffer.companionXmlFilename ~= nil then
        setXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionName", activeOffer.companionName)
        setXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionBrand", activeOffer.companionBrand)
        setXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionCategory", activeOffer.companionCategory)
        setXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionXmlFilename", activeOffer.companionXmlFilename)
        setXMLFloat(xmlFile, "dealerRelations.activeDemoOffer#companionPrice", activeOffer.companionPrice or 0)
    end
end

-------------------------------------------------------------------------------
-- Saves active demo vehicle records to XML.
--
-- Runtime vehicle objects are not persisted. Vehicles are restored on
-- load by looking up their saved uniqueId in the game vehicle system.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveActiveDemoVehicles(xmlFile)
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()

    for index, demoVehicle in ipairs(activeDemoVehicles) do
        local key = string.format(
            "dealerRelations.activeDemoVehicles.activeDemoVehicle(%d)",
            index - 1
        )

        setXMLString(xmlFile, key .. "#uniqueId", demoVehicle.uniqueId)
        setXMLString(xmlFile, key .. "#name", demoVehicle.name)
        setXMLString(xmlFile, key .. "#brand", demoVehicle.brand)
        setXMLString(xmlFile, key .. "#xmlFilename", demoVehicle.xmlFilename)
        setXMLInt(xmlFile, key .. "#startMonth", demoVehicle.startMonth or 0)
        setXMLInt(xmlFile, key .. "#endMonth", demoVehicle.endMonth or 0)
        setXMLString(xmlFile, key .. "#state", demoVehicle.state or "ACTIVE")
        setXMLString(xmlFile, key .. "#role", demoVehicle.role or "PRIMARY")
        setXMLFloat(xmlFile, key .. "#startOperatingHours", demoVehicle.startOperatingHours or 0)
        setXMLFloat(xmlFile, key .. "#operatingHourLimit", demoVehicle.operatingHourLimit or 0)
        setXMLFloat(xmlFile, key .. "#price", demoVehicle.price or 0)

        -- overdueClockStartDay omitted when nil so older saves remain valid.
        setXMLInt(xmlFile, key .. "#overdueLevel", demoVehicle.overdueLevel or 0)

        if demoVehicle.overdueClockStartDay ~= nil then
            setXMLInt(xmlFile, key .. "#overdueClockStartDay", demoVehicle.overdueClockStartDay)
        end

        setXMLBool(xmlFile, key .. "#overdueNoticeSent", demoVehicle.overdueNoticeSent == true)
    end
end

-------------------------------------------------------------------------------
-- Saves per-save category filter settings to XML.
--
-- Only player-configurable categories are saved. Hard exclusions remain
-- code-defined in Equipment.lua and are never written here.
-- Categories are sorted alphabetically for consistent XML output.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveCategoryFilters(xmlFile)
    local categoryFilters = DealerRelations.Data:getCategoryFilters()
    local categories = {}

    for category, _ in pairs(categoryFilters) do
        table.insert(categories, category)
    end

    table.sort(categories)

    for index, category in ipairs(categories) do
        local key = string.format(
            "dealerRelations.categoryFilters.category(%d)",
            index - 1
        )

        setXMLString(xmlFile, key .. "#name", category)
        setXMLBool(xmlFile, key .. "#enabled", categoryFilters[category] == true)
    end
end

-------------------------------------------------------------------------------
-- Saves per-save brand filter settings to XML.
--
-- Only brands that have been discovered in the current save are written.
-- Brands are sorted alphabetically for consistent XML output.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveBrandFilters(xmlFile)
    local brandFilters = DealerRelations.Data:getBrandFilters()
    local brands = {}

    for brand, _ in pairs(brandFilters) do
        table.insert(brands, brand)
    end

    table.sort(brands)

    for index, brand in ipairs(brands) do
        local key = string.format(
            "dealerRelations.brandFilters.brand(%d)",
            index - 1
        )

        setXMLString(xmlFile, key .. "#name", brand)
        setXMLBool(xmlFile, key .. "#enabled", brandFilters[brand] == true)
    end
end

-------------------------------------------------------------------------------
-- Saves the dealership name to XML.
--
-- Dealer identity is generated once per save and persisted so the player
-- sees the same dealer name after reloading.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveDealerName(xmlFile)
    local dealerName = DealerRelations.Data:getDealerName()

    if dealerName ~= nil then
        setXMLString(xmlFile, "dealerRelations.dealer#name", dealerName)
    end
end

-------------------------------------------------------------------------------
-- Saves active loan records to XML.
--
-- Each loan record is saved as a child element with all fields as attributes.
-- Mirrors the structure used by saveActiveDemoVehicles.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveActiveLoans(xmlFile)
    local activeLoans = DealerRelations.Data:getActiveLoans()

    for index, loan in ipairs(activeLoans) do
        local key = string.format(
            "dealerRelations.activeLoans.loan(%d)",
            index - 1
        )

        setXMLString(xmlFile, key .. "#uniqueId",           loan.uniqueId)
        setXMLString(xmlFile, key .. "#name",               loan.name)
        setXMLString(xmlFile, key .. "#brand",              loan.brand)
        setXMLString(xmlFile, key .. "#xmlFilename",        loan.xmlFilename)
        setXMLInt(xmlFile,    key .. "#farmId",             loan.farmId or 1)
        setXMLFloat(xmlFile,  key .. "#principal",          loan.principal or 0)
        setXMLFloat(xmlFile,  key .. "#remainingPrincipal", loan.remainingPrincipal or 0)
        setXMLFloat(xmlFile,  key .. "#annualRate",         loan.annualRate or 0)
        setXMLInt(xmlFile,    key .. "#termMonths",         loan.termMonths or 0)
        setXMLInt(xmlFile,    key .. "#remainingMonths",    loan.remainingMonths or 0)
        setXMLFloat(xmlFile,  key .. "#monthlyPayment",     loan.monthlyPayment or 0)
        setXMLInt(xmlFile,    key .. "#missCount",          loan.missCount or 0)
        setXMLBool(xmlFile,   key .. "#missNoticeSent",     loan.missNoticeSent == true)
        setXMLInt(xmlFile,    key .. "#originationMonth",   loan.originationMonth or 0)
        setXMLInt(xmlFile,    key .. "#originationYear",    loan.originationYear or 0)
        setXMLInt(xmlFile,    key .. "#monthsSinceLastBoost", loan.monthsSinceLastBoost or 0)
    end
end

-------------------------------------------------------------------------------
-- Saves the per-save crop history to XML.
--
-- Crop history is append-only; only crop names are written, since presence
-- in the list is the only meaningful state — there is no "disabled" crop.
-- Crops are sorted alphabetically for consistent XML output.
--
-- @param xmlFile number Active XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:saveCropsEverGrown(xmlFile)
    local cropsEverGrown = DealerRelations.Data:getCropsEverGrown()
    local crops = {}

    for fruitTypeName, _ in pairs(cropsEverGrown) do
        table.insert(crops, fruitTypeName)
    end

    table.sort(crops)

    for index, fruitTypeName in ipairs(crops) do
        local key = string.format(
            "dealerRelations.cropsEverGrown.crop(%d)",
            index - 1
        )

        setXMLString(xmlFile, key .. "#name", fruitTypeName)
    end
end

-------------------------------------------------------------------------------
-- Load
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Loads Dealer Relations data from XML in the active savegame directory.
--
-- If the XML file does not exist or cannot be loaded, the default values already
-- defined in DealerRelationsData.lua remain in use.
--
-- @param savegameDirectory string Active savegame directory.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:load(savegameDirectory)
    if savegameDirectory == nil then
        -- New saves may not have a savegame directory available yet.
        -- Assign a dealer identity before the first save creates
        -- dealerRelations.xml.
        --
        -- Rationale:
        -- If the savegame directory is not available yet, this is still part
        -- of first-load initialization. Dealer identity must be assigned here
        -- or the default "Dealer" value will be saved.
        DealerRelations.Data:setDealerName(
            DealerRelations.Data:getRandomDealerName()
        )

        -- Initialize category filters so equipment discovery can still use
        -- valid default settings before the first save creates the XML file.
        DealerRelations.Data:initializeCategoryFilters()

        DealerRelations.warning("Cannot load dealerRelations.xml: savegameDirectory is nil")
        return
    end

    local filePath = self:getFilePath(savegameDirectory)

    if not fileExists(filePath) then
        -- New saves have no Dealer Relations XML yet.
        -- Assign the dealer identity once before the first save creates
        -- dealerRelations.xml.
        --
        -- Rationale:
        -- Dealer identity should be generated per save, then persisted so it
        -- does not change on future loads.
        DealerRelations.Data:setDealerName(
            DealerRelations.Data:getRandomDealerName()
        )

        -- Initialize configurable category filters from defaults so discovery and
        -- the first save both have valid per-save settings to use.
        DealerRelations.Data:initializeCategoryFilters()

        return
    end

    local xmlFile = loadXMLFile("dealerRelationsXML", filePath)

    if xmlFile == nil or xmlFile == 0 then
        DealerRelations.Data:initializeCategoryFilters()

        DealerRelations.warning("Could not load dealerRelations.xml; using default dealer data")
        return
    end

    -- Keep load() as the orchestration point only.
    -- Each helper restores one saved data group so future persistence changes
    -- can be added without turning load() into one large mixed block.
    self:loadCoreData(xmlFile)
    self:loadSettings(xmlFile)
    self:loadDealerName(xmlFile)
    self:loadRecentDemoCandidates(xmlFile)
    self:loadActiveDemoOffer(xmlFile)
    self:loadActiveDemoVehicles(xmlFile)
    self:loadActiveLoans(xmlFile)
    self:loadCropsEverGrown(xmlFile)
    
    -- Player settings
    self:loadCategoryFilters(xmlFile)
    self:loadBrandFilters(xmlFile)

    delete(xmlFile)

    DealerRelations.log(
        "Loaded confidence: " .. tostring(DealerRelations.Data:getConfidence()) ..
        ", relationship level: " .. tostring(DealerRelations.Data:getRelationshipLevel()) ..
        ", active demo vehicles: " .. tostring(#DealerRelations.Data:getActiveDemoVehicles())
    )
end

-------------------------------------------------------------------------------
-- Loads core dealer state values from XML.
--
-- Relationship level is derived from confidence at runtime and is not
-- loaded directly. Missing suspension fields default to nil, which is
-- the correct state for saves that predate the suspension system.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadCoreData(xmlFile)
    local confidence = getXMLFloat(xmlFile, "dealerRelations.confidence")
    local lastDemoCheckMonth = getXMLInt(
        xmlFile,
        "dealerRelations.lastDemoCheckMonth"
    )

    if confidence ~= nil then
        DealerRelations.Data:setConfidence(confidence)
    else
        DealerRelations.warning(
            "Confidence missing from dealerRelations.xml; using default confidence"
        )
    end

    if lastDemoCheckMonth ~= nil then
        DealerRelations.Data:setLastDemoCheckMonth(lastDemoCheckMonth)
    else
        DealerRelations.warning(
            "lastDemoCheckMonth missing from dealerRelations.xml; using default value"
        )
    end

    -- Missing node means no active suspension, which is the correct
    -- default for existing saves.
    local suspensionEndMonth = getXMLInt(xmlFile, "dealerRelations.suspensionEndMonth")

    if suspensionEndMonth ~= nil then
        DealerRelations.Data:setSuspensionEndMonth(suspensionEndMonth)
    else
        DealerRelations.Data:clearSuspensionEndMonth()
    end

    -- Missing node means no pending suspension, correct default for existing saves.
    local pendingSuspensionMonths = getXMLInt(xmlFile, "dealerRelations.pendingSuspensionMonths")

    if pendingSuspensionMonths ~= nil then
        DealerRelations.Data:setPendingSuspensionMonths(pendingSuspensionMonths)
    else
        DealerRelations.Data:clearPendingSuspensionMonths()
    end

    local totalLoansRepaid = getXMLInt(xmlFile, "dealerRelations.totalLoansRepaid")
    if totalLoansRepaid ~= nil then
        DealerRelations.dealerData.totalLoansRepaid = totalLoansRepaid
    end

    local totalMissedPayments = getXMLInt(xmlFile, "dealerRelations.totalMissedPayments")
    if totalMissedPayments ~= nil then
        DealerRelations.dealerData.totalMissedPayments = totalMissedPayments
    end
end

-------------------------------------------------------------------------------
-- Loads player-configurable Dealer Relations settings from XML.
--
-- Missing settings are not treated as errors. Defaults defined in
-- DealerRelationsData.lua remain in effect for any value not present.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadSettings(xmlFile)
    local enabled = getXMLBool(
        xmlFile,
        "dealerRelations.settings#enabled"
    )

    local debug = getXMLBool(
        xmlFile,
        "dealerRelations.settings#debug"
    )

    local forestryEnabled = getXMLBool(
        xmlFile,
        "dealerRelations.settings#forestryEnabled"
    )

    if enabled ~= nil then
        DealerRelations.Data:setEnabled(enabled)
    end

    if debug ~= nil then
        DealerRelations.Data:setDebugEnabled(debug)
    end

    if forestryEnabled ~= nil then
        DealerRelations.Data:setForestryEnabled(forestryEnabled)
    end

    DealerRelations.log(string.format(
        "Loaded settings: enabled=%s, debug=%s, forestryEnabled=%s",
        tostring(DealerRelations.Data:isEnabled()),
        tostring(DealerRelations.Data:isDebugEnabled()),
        tostring(DealerRelations.Data:isForestryEnabled())
    ))
end

-------------------------------------------------------------------------------
-- Loads the recent demo candidate history from XML.
--
-- Resets the backing table before loading and reuses the normal add path
-- so history size limits are enforced consistently on load.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadRecentDemoCandidates(xmlFile)
    DealerRelations.dealerData.recentDemoCandidates = {}

    local index = 0
    local key = getXMLString(
        xmlFile,
        string.format(
            "dealerRelations.recentDemoCandidates.candidate(%d)#key",
            index
        )
    )

    while key ~= nil do
        DealerRelations.Data:addRecentDemoCandidate(key)

        index = index + 1
        key = getXMLString(
            xmlFile,
            string.format(
                "dealerRelations.recentDemoCandidates.candidate(%d)#key",
                index
            )
        )
    end

    DealerRelations.log(
        "Loaded recent demo candidates: " ..
        tostring(#DealerRelations.Data:getRecentDemoCandidates())
    )
end

-------------------------------------------------------------------------------
-- Loads the active demo offer from XML if one was saved.
--
-- If no offer is present, clears the runtime value so stale state
-- cannot carry over from a previous session.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadActiveDemoOffer(xmlFile)
    local activeOfferCandidateKey = getXMLString(
        xmlFile,
        "dealerRelations.activeDemoOffer#candidateKey"
    )

    if activeOfferCandidateKey == nil then
        DealerRelations.Data:clearActiveDemoOffer()
        return
    end

    DealerRelations.Data:setActiveDemoOffer({
        candidateKey = activeOfferCandidateKey,
        name = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#name"),
        brand = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#brand"),
        category = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#category"),
        price = getXMLFloat(xmlFile, "dealerRelations.activeDemoOffer#price"),
        xmlFilename = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#xmlFilename"),
        powerRole = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#powerRole"),
        -- Missing fields default to clean state for existing saves.
        overdueLevel = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#overdueLevel") or 0,
        overdueClockStartDay = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#overdueClockStartDay"),
        displayPower = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#displayPower"),
        powerMin = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMin"),
        powerMax = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMax"),
        offerMonth = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#offerMonth"),

        -- Companion fields. All nil on older saves or offers with no
        -- companion -- startDemoFromOffer() must treat a nil
        -- companionXmlFilename as "nothing to spawn," not an error.
        companionName = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionName"),
        companionBrand = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionBrand"),
        companionCategory = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionCategory"),
        companionXmlFilename = getXMLString(xmlFile, "dealerRelations.activeDemoOffer#companionXmlFilename"),
        companionPrice = getXMLFloat(xmlFile, "dealerRelations.activeDemoOffer#companionPrice"),
    })

    local activeOffer = DealerRelations.Data:getActiveDemoOffer()

    DealerRelations.log(string.format(
        "Loaded active demo offer: %s | Brand=%s | Category=%s | HP=%s | Month=%s%s",
        tostring(activeOffer.name),
        tostring(activeOffer.brand),
        tostring(activeOffer.category),
        tostring(activeOffer.displayPower or "Unknown"),
        tostring(activeOffer.offerMonth),
        activeOffer.companionName ~= nil
            and (" | Companion=" .. tostring(activeOffer.companionName))
            or ""
    ))
end

-------------------------------------------------------------------------------
-- Loads active demo vehicle records from XML.
--
-- Runtime vehicle objects are not saved. Vehicles are looked up later
-- by their persisted uniqueId.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadActiveDemoVehicles(xmlFile)
    DealerRelations.dealerData.activeDemoVehicles = {}

    local demoVehicleIndex = 0

    while true do
        local key = string.format(
            "dealerRelations.activeDemoVehicles.activeDemoVehicle(%d)",
            demoVehicleIndex
        )

        local uniqueId = getXMLString(xmlFile, key .. "#uniqueId")

        if uniqueId == nil then
            break
        end

        table.insert(
            DealerRelations.dealerData.activeDemoVehicles,
            {
                uniqueId = uniqueId,
                name = getXMLString(xmlFile, key .. "#name"),
                brand = getXMLString(xmlFile, key .. "#brand"),
                xmlFilename = getXMLString(xmlFile, key .. "#xmlFilename"),
                startMonth = getXMLInt(xmlFile, key .. "#startMonth") or 0,
                endMonth = getXMLInt(xmlFile, key .. "#endMonth") or 0,
                startOperatingHours = getXMLFloat(xmlFile, key .. "#startOperatingHours") or 0,
                operatingHourLimit = getXMLFloat(xmlFile, key .. "#operatingHourLimit") or 0,
                price = getXMLFloat(xmlFile, key .. "#price") or 0,
                state = getXMLString(xmlFile, key .. "#state") or "ACTIVE",
                role = getXMLString(xmlFile, key .. "#role") or "PRIMARY",
                -- Missing fields default to clean state for existing saves.
                overdueLevel = getXMLInt(xmlFile, key .. "#overdueLevel") or 0,
                overdueClockStartDay = getXMLInt(xmlFile, key .. "#overdueClockStartDay"),
                overdueNoticeSent = getXMLBool(xmlFile, key .. "#overdueNoticeSent") == true,
            }
        )

        demoVehicleIndex = demoVehicleIndex + 1
    end
end

-------------------------------------------------------------------------------
-- Loads per-save category filter settings from XML.
--
-- If no category data is present, initializes defaults so existing saves
-- continue behaving as they did before settings were added.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadCategoryFilters(xmlFile)
    DealerRelations.dealerData.categoryFilters = {}

    local index = 0

    while true do
        local key = string.format(
            "dealerRelations.categoryFilters.category(%d)",
            index
        )

        local category = getXMLString(xmlFile, key .. "#name")

        if category == nil then
            break
        end

        local enabled = getXMLBool(xmlFile, key .. "#enabled")

        DealerRelations.Data:setCategoryEnabled(
            category,
            enabled == true
        )

        index = index + 1
    end

    if index == 0 then
        DealerRelations.Data:initializeCategoryFilters()
    end

    local count = 0

    for _, _ in pairs(DealerRelations.Data:getCategoryFilters()) do
        count = count + 1
    end

    DealerRelations.log(
        "Loaded category filters: " .. tostring(count)
    )
end

-------------------------------------------------------------------------------
-- Loads per-save brand filter settings from XML.
--
-- Resets the brand filter table before loading. Brands not present in the
-- XML will be re-added as enabled when equipment discovery runs.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadBrandFilters(xmlFile)
    DealerRelations.dealerData.brandFilters = {}

    local index = 0

    while true do
        local key = string.format(
            "dealerRelations.brandFilters.brand(%d)",
            index
        )

        local brand = getXMLString(xmlFile, key .. "#name")

        if brand == nil then
            break
        end

        local enabled = getXMLBool(xmlFile, key .. "#enabled")

        DealerRelations.Data:setBrandEnabled(
            brand,
            enabled == true
        )

        index = index + 1
    end

    DealerRelations.log(
        "Loaded brand filters: " .. tostring(index)
    )
end

-------------------------------------------------------------------------------
-- Loads the dealership name from XML.
--
-- If no dealer name is present, the existing value set during load
-- initialization is preserved.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadDealerName(xmlFile)
    local dealerName = getXMLString(
        xmlFile,
        "dealerRelations.dealer#name"
    )

    if dealerName ~= nil then
        DealerRelations.Data:setDealerName(dealerName)
    end
end

-------------------------------------------------------------------------------
-- Loads active loan records from XML.
--
-- Resets the active loans table before loading.
-- Missing fields default to safe values for forward compatibility.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadActiveLoans(xmlFile)
    DealerRelations.dealerData.activeLoans = {}

    local index = 0

    while true do
        local key = string.format(
            "dealerRelations.activeLoans.loan(%d)",
            index
        )

        local uniqueId = getXMLString(xmlFile, key .. "#uniqueId")

        if uniqueId == nil then
            break
        end

        table.insert(
            DealerRelations.dealerData.activeLoans,
            {
                uniqueId           = uniqueId,
                name               = getXMLString(xmlFile, key .. "#name"),
                brand              = getXMLString(xmlFile, key .. "#brand"),
                xmlFilename        = getXMLString(xmlFile, key .. "#xmlFilename"),
                farmId             = getXMLInt(xmlFile,    key .. "#farmId") or 1,
                principal          = getXMLFloat(xmlFile,  key .. "#principal") or 0,
                remainingPrincipal = getXMLFloat(xmlFile,  key .. "#remainingPrincipal") or 0,
                annualRate         = getXMLFloat(xmlFile,  key .. "#annualRate") or 0,
                termMonths         = getXMLInt(xmlFile,    key .. "#termMonths") or 0,
                remainingMonths    = getXMLInt(xmlFile,    key .. "#remainingMonths") or 0,
                monthlyPayment     = getXMLFloat(xmlFile,  key .. "#monthlyPayment") or 0,
                missCount          = getXMLInt(xmlFile,    key .. "#missCount") or 0,
                missNoticeSent     = getXMLBool(xmlFile,   key .. "#missNoticeSent") == true,
                originationMonth   = getXMLInt(xmlFile,    key .. "#originationMonth") or 0,
                originationYear    = getXMLInt(xmlFile,    key .. "#originationYear") or 0,
                monthsSinceLastBoost = getXMLInt(xmlFile,  key .. "#monthsSinceLastBoost") or 0,
            }
        )

        index = index + 1
    end

    DealerRelations.log(
        "Loaded active loans: " .. tostring(#DealerRelations.dealerData.activeLoans)
    )
end

-------------------------------------------------------------------------------
-- Loads the per-save crop history from XML.
--
-- Missing crop history is not treated as an error — new saves, and saves
-- from before crop history existed, simply start with an empty set. The
-- next scan (on load or monthly) begins populating it from there.
--
-- @param xmlFile number Loaded XML file handle.
-------------------------------------------------------------------------------
function DealerRelations.Persistence:loadCropsEverGrown(xmlFile)
    DealerRelations.dealerData.cropsEverGrown = {}

    local index = 0

    while true do
        local key = string.format(
            "dealerRelations.cropsEverGrown.crop(%d)",
            index
        )

        local fruitTypeName = getXMLString(xmlFile, key .. "#name")

        if fruitTypeName == nil then
            break
        end

        DealerRelations.Data:addCropEverGrown(fruitTypeName)

        index = index + 1
    end

    DealerRelations.log(
        "Loaded crop history: " .. tostring(index) .. " crop(s)"
    )
end

