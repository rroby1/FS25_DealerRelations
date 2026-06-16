--==============================================================================
-- Dealer Relations Settings Manager
--
-- Purpose:
--     Integrates the Dealer Relations settings page with the
--     Farming Simulator 25 in-game Settings menu.
--
-- Responsibilities:
--     * Load and register the Dealer Relations settings page
--     * Insert the Dealer Relations tab into the Settings screen
--     * Manage settings page focus and navigation integration
--     * Coordinate settings UI controls and persistence bindings
--
-- Notes:
--     This module only handles Settings menu integration.
--     Dealer Relations settings values remain owned by the
--     appropriate gameplay and persistence modules.
--==============================================================================

DealerRelations.SettingsManager = {}
local DealerRelationsSettingsManager_mt = Class(DealerRelations.SettingsManager, FrameElement)

function DealerRelations.SettingsManager.new(customMt)
    local self = FrameElement.new(nil, customMt or DealerRelationsSettingsManager_mt)

    -- Assigned later when the Dealer Relations tab is inserted into the
    -- settings sub-category list.
    self.subCategoryIndex = nil

    return self
end

function DealerRelations.SettingsManager:init()
    -- The settings manager is initialized from DealerRelations:loadMap()
    -- after the base game mission/menu objects are available.
    --
    -- This loads the settings page XML and inserts the Dealer Relations
    -- page/tab into the base-game Settings menu.
    if not self:loadPage() then
        return
    end

    self:insertSettingsPage()
    self:registerHeader()

    DealerRelations.log("Settings manager initialized")
end

function DealerRelations.SettingsManager:loadPage()
    -- Load the Dealer Relations settings XML into its controller.
    -- This creates the page and tab objects, but does not insert them into
    -- the base-game Settings menu yet.
    local filename = DealerRelations.directory .. "gui/DealerRelationsSettingsPage.xml"

    DealerRelations.settingsPage = DealerRelations.SettingsPage.new()

    if g_gui:loadGui(filename, "DealerRelationsSettingsPage", DealerRelations.settingsPage) == nil then
        DealerRelations.warning("Failed to load Dealer Relations settings page XML")
        DealerRelations.settingsPage = nil
        return false
    end

    DealerRelations.log("Settings page XML loaded")

    return true
end

function DealerRelations.SettingsManager:addElementAtPosition(element, target, position)
    -- Move an existing GUI element into a target container at a specific index.
    -- This mirrors the pattern used by Better Contracts for settings-page
    -- insertion without cloning or rebuilding the XML element.
    if element.parent ~= nil then
        element.parent:removeElement(element)
    end

    table.insert(target.elements, position, element)
    element.parent = target
end

function DealerRelations.SettingsManager:insertSettingsPage()
    -- Insert the Dealer Relations settings page and tab into the base-game
    -- Settings frame internal structures.
    local pageSettings = g_inGameMenu.pageSettings
    local settingsPage = DealerRelations.settingsPage

    local drPage = settingsPage.drPage
    local drTab = settingsPage.drTab

    local position = #pageSettings.subCategoryTabs + 1
    self.subCategoryIndex = position

    self:addElementAtPosition(drPage, pageSettings.subCategoryPages[1].parent, position)
    self:addElementAtPosition(drTab, pageSettings.subCategoryBox, position)

    pageSettings.subCategoryPages[position] = drPage
    pageSettings.subCategoryTabs[position] = drTab

    pageSettings:updateAbsolutePosition()

    DealerRelations.log("Settings page inserted at sub-category index " .. tostring(position))
end

function DealerRelations.SettingsManager:registerHeader()
    -- Register Dealer Relations as a settings sub-category so the base-game
    -- Settings frame can resolve the correct header/title data when the tab
    -- is selected.
    InGameMenuSettingsFrame.SUB_CATEGORY.DEALER_RELATIONS = self.subCategoryIndex

    InGameMenuSettingsFrame.HEADER_SLICES[self.subCategoryIndex] =
        "gui.icon_options_gameSettings"

    InGameMenuSettingsFrame.HEADER_TITLES[self.subCategoryIndex] =
        InGameMenuSettingsFrame.HEADER_TITLES[1]
        
    DealerRelations.log(
        "Settings header title using existing key: "
        .. tostring(InGameMenuSettingsFrame.HEADER_TITLES[1])
    )
end
