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

    DealerRelations.log("Saving dealerRelations.xml to: " .. filePath)

    local xmlFile = createXMLFile("dealerRelationsXML", filePath, "dealerRelations")

    setXMLFloat(xmlFile, "dealerRelations.confidence", DealerRelations.Data:getConfidence())

    saveXMLFile(xmlFile)
    delete(xmlFile)

    DealerRelations.log("Saved dealerRelations.xml")
		
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

    DealerRelations.log("Checking dealerRelations.xml at: " .. filePath)

    if not fileExists(filePath) then
        DealerRelations.log("dealerRelations.xml not found; using default dealer data")
        return
    end

    local xmlFile = loadXMLFile("dealerRelationsXML", filePath)

    if xmlFile == nil or xmlFile == 0 then
        DealerRelations.warning("Could not load dealerRelations.xml; using default dealer data")
        return
    end

    local confidence = getXMLFloat(xmlFile, "dealerRelations.confidence")

    if confidence ~= nil then
        DealerRelations.Data:setConfidence(confidence)
    else
        DealerRelations.warning("Confidence missing from dealerRelations.xml; using default confidence")
    end

    delete(xmlFile)

    DealerRelations.log(
        "Loaded confidence: " ..
        tostring(DealerRelations.Data:getConfidence()) ..
        ", relationship level: " ..
        tostring(DealerRelations.Data:getRelationshipLevel())
    )

end