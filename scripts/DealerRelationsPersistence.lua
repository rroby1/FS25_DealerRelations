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

function DealerRelations.Persistence:getFilePath(savegameDirectory)
    -- Build the full path to dealerRelations.xml for the
    -- specified savegame directory.
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
    self:saveRecentDemoCandidates(xmlFile)
    self:saveActiveDemoOffer(xmlFile)
    self:saveActiveDemoVehicles(xmlFile)
    
    -- Player settings
    self:saveCategoryFilters(xmlFile)
    self:saveBrandFilters(xmlFile)

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function DealerRelations.Persistence:saveCoreData(xmlFile)
    -- Save core dealer state values that are always present.
    -- Derived values, such as relationship level, are recalculated at runtime.
    setXMLFloat(xmlFile, "dealerRelations.confidence", DealerRelations.Data:getConfidence())

    setXMLInt(
        xmlFile,
        "dealerRelations.lastDemoCheckMonth",
        DealerRelations.Data:getLastDemoCheckMonth()
    )
end

function DealerRelations.Persistence:saveSettings(xmlFile)
    -- Save player-configurable Dealer Relations settings.
    --
    -- Rationale:
    -- Settings are saved as their own group so future settings can be added
    -- without mixing configuration data into core relationship state.
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
end

function DealerRelations.Persistence:saveRecentDemoCandidates(xmlFile)
    -- Save the recent demo candidate keys used to reduce repeated offers.
    -- Only the stable candidate key is persisted, not the full equipment record.
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

function DealerRelations.Persistence:saveActiveDemoOffer(xmlFile)
    -- Save the currently open demo offer, if one exists.
    -- If there is no open offer, this section is omitted from the XML.
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
end

function DealerRelations.Persistence:saveActiveDemoVehicles(xmlFile)
    -- Save active demo vehicle records.
    -- Runtime vehicle objects are not persisted; vehicles are restored later
    -- by looking up their saved uniqueId.
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
    end
end

function DealerRelations.Persistence:saveCategoryFilters(xmlFile)
    -- Save per-save category filter settings.
    -- Only configurable equipment categories are saved here; hard-excluded
    -- categories remain code-defined in Equipment.lua.
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

function DealerRelations.Persistence:saveBrandFilters(xmlFile)
    -- Save per-save brand filter settings.
    -- Brands are discovered dynamically during equipment discovery, so this
    -- saves only the brands that have actually been seen in the current save.
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
        -- Initialize category filters so equipment discovery can still use
        -- valid default settings before the first save creates the XML file.
        DealerRelations.Data:initializeCategoryFilters()

        DealerRelations.warning("Cannot load dealerRelations.xml: savegameDirectory is nil")
        return
    end

    local filePath = self:getFilePath(savegameDirectory)

    if not fileExists(filePath) then
        -- New saves have no Dealer Relations XML yet.
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
    self:loadRecentDemoCandidates(xmlFile)
    self:loadActiveDemoOffer(xmlFile)
    self:loadActiveDemoVehicles(xmlFile)
    
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

function DealerRelations.Persistence:loadCoreData(xmlFile)
    -- Load core dealer state values.
    -- Relationship level is derived from confidence and is not saved directly.
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
end

function DealerRelations.Persistence:loadSettings(xmlFile)
    -- Load player-configurable Dealer Relations settings.
    --
    -- Rationale:
    -- Missing settings should not break older saves. Defaults remain owned by
    -- DealerRelationsData, so this loader only applies values that actually
    -- exist in dealerRelations.xml.
    local enabled = getXMLBool(
        xmlFile,
        "dealerRelations.settings#enabled"
    )

    local debug = getXMLBool(
        xmlFile,
        "dealerRelations.settings#debug"
    )

    if enabled ~= nil then
        DealerRelations.Data:setEnabled(enabled)
    end

    if debug ~= nil then
        DealerRelations.Data:setDebugEnabled(debug)
    end

    DealerRelations.log(string.format(
        "Loaded settings: enabled=%s, debug=%s",
        tostring(DealerRelations.Data:isEnabled()),
        tostring(DealerRelations.Data:isDebugEnabled())
    ))
end

function DealerRelations.Persistence:loadRecentDemoCandidates(xmlFile)
    -- Reset and reload the recent demo candidate history.
    -- DealerRelationsData currently exposes add/get helpers for this list,
    -- so loading resets the backing table and then reuses the normal add path.
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

function DealerRelations.Persistence:loadActiveDemoOffer(xmlFile)
    -- Load the active demo offer if one was saved.
    -- If no offer is present, clear the runtime value so old state cannot linger.
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
        displayPower = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#displayPower"),
        powerMin = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMin"),
        powerMax = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#powerMax"),
        offerMonth = getXMLInt(xmlFile, "dealerRelations.activeDemoOffer#offerMonth")
    })

    local activeOffer = DealerRelations.Data:getActiveDemoOffer()

    DealerRelations.log(string.format(
        "Loaded active demo offer: %s | Brand=%s | Category=%s | HP=%s | Month=%s",
        tostring(activeOffer.name),
        tostring(activeOffer.brand),
        tostring(activeOffer.category),
        tostring(activeOffer.displayPower or "Unknown"),
        tostring(activeOffer.offerMonth)
    ))
end

function DealerRelations.Persistence:loadActiveDemoVehicles(xmlFile)
    -- Load active demo vehicle records.
    -- Runtime vehicle objects are not saved; vehicles are looked up later by uniqueId.
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
                state = getXMLString(xmlFile, key .. "#state") or "ACTIVE",
                role = getXMLString(xmlFile, key .. "#role") or "PRIMARY"
            }
        )

        demoVehicleIndex = demoVehicleIndex + 1
    end
end

function DealerRelations.Persistence:loadCategoryFilters(xmlFile)
    -- Load per-save category filter settings.
    -- If this section is missing, initialize defaults so existing saves
    -- continue behaving exactly as they did before settings were added.
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

function DealerRelations.Persistence:loadBrandFilters(xmlFile)
    -- Load per-save brand filter settings.
    -- Brands are discovered dynamically, so missing brand settings are not
    -- initialized here. Discovery will add any newly found brands as enabled.
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