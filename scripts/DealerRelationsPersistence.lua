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
-- Save
-------------------------------------------------------------------------------

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

    local filePath = savegameDirectory .. "/" .. self.FILE_NAME
    local xmlFile = createXMLFile("dealerRelationsXML", filePath, "dealerRelations")

    -- Keep save() as the orchestration point only.
    -- Each helper owns one saved data group so future persistence changes
    -- can be added without turning save() into one large mixed block.
    self:saveCoreData(xmlFile)
    self:saveRecentDemoCandidates(xmlFile)
    self:saveActiveDemoOffer(xmlFile)
    self:saveActiveDemoVehicles(xmlFile)

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
        DealerRelations.warning("Cannot load dealerRelations.xml: savegameDirectory is nil")
        return
    end

    local filePath = savegameDirectory .. "/" .. self.FILE_NAME

    if not fileExists(filePath) then
        return
    end

    local xmlFile = loadXMLFile("dealerRelationsXML", filePath)

    if xmlFile == nil or xmlFile == 0 then
        DealerRelations.warning("Could not load dealerRelations.xml; using default dealer data")
        return
    end

    local confidence = getXMLFloat(xmlFile, "dealerRelations.confidence")

    local lastDemoCheckMonth = getXMLInt(
        xmlFile,
        "dealerRelations.lastDemoCheckMonth"
    )

    if lastDemoCheckMonth ~= nil then
        DealerRelations.Data:setLastDemoCheckMonth(lastDemoCheckMonth)
    else
        DealerRelations.warning(
            "lastDemoCheckMonth missing from dealerRelations.xml; using default value"
        )
    end

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

    local activeOfferCandidateKey = getXMLString(
        xmlFile,
        "dealerRelations.activeDemoOffer#candidateKey"
    )

    if activeOfferCandidateKey ~= nil then
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
    else
        DealerRelations.Data:clearActiveDemoOffer()
    end

    if confidence ~= nil then
        DealerRelations.Data:setConfidence(confidence)
    else
        DealerRelations.warning(
            "Confidence missing from dealerRelations.xml; using default confidence"
        )
    end
    
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

    delete(xmlFile)

    DealerRelations.log(
        "Loaded confidence: " ..
        tostring(DealerRelations.Data:getConfidence()) ..
        ", relationship level: " ..
        tostring(DealerRelations.Data:getRelationshipLevel()) ..
        ", active demo vehicles: " ..
        tostring(#DealerRelations.dealerData.activeDemoVehicles)
    )
end