-------------------------------------------------------------------------------
-- Dealer Relations Screen
--
-- Main ESC menu page for Dealer Relations.
--
-- Future responsibilities:
-- - Overview page
-- - Active demo information
-- - Relationship history
-- - Configuration and filter management
--
-- This module currently defines only the screen class metadata.
-- Screen registration and XML loading will be added in later steps.
-------------------------------------------------------------------------------

DealerRelations.Screen = {}

-------------------------------------------------------------------------------
-- Class Metadata
-------------------------------------------------------------------------------

-- Dealer Relations will be implemented as a custom InGameMenu page.
--
-- Rationale:
-- Using TabbedMenuFrameElement aligns with the architecture used by existing
-- Farming Simulator menu pages and provides built-in support for integration
-- with the ESC menu page system.
DealerRelations.Screen._mt = Class(
    DealerRelations.Screen,
    TabbedMenuFrameElement
)

-- GUI class name used by the GIANTS GUI system when loading XML.
DealerRelations.Screen.CLASS_NAME = "DealerRelationsScreen"

-- Internal page identifier used when registering the page with InGameMenu.
DealerRelations.Screen.MENU_PAGE_NAME = "menuDealerRelations"

-- XML definition file for the Dealer Relations screen.
--
-- Rationale:
-- Store the full XML path while the mod directory is known, so later runtime
-- GUI loading does not depend on g_currentModDirectory still being available.
DealerRelations.Screen.XML_FILENAME =
    g_currentModDirectory .. "gui/DealerRelationsScreen.xml"

-- Temporary tab icon.
-- Rationale:
-- The ESC menu requires a tab icon when adding a page tab. The mod icon is
-- good enough while the screen architecture is being proven.
DealerRelations.Screen.MENU_ICON_FILENAME =
    g_currentModDirectory .. "icon.dds"

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------

-- Creates the Dealer Relations menu frame instance.
--
-- Rationale:
-- Dealer Relations uses the same base frame type as other in-game menu pages.
-- This constructor only creates the frame object; XML loading and menu
-- registration are intentionally handled later so each lifecycle step can be
-- tested independently.
function DealerRelations.Screen.new(target, customMt)
    local self = TabbedMenuFrameElement.new(
        target,
        customMt or DealerRelations.Screen._mt
    )

    self:setTitle("Dealer Relations")

    return self
end

function DealerRelations.Screen:createInstance()
    -- Create the screen object without loading XML or registering it.
    --
    -- Rationale:
    -- This verifies the Dealer Relations screen can be instantiated before
    -- involving GIANTS GUI XML loading or InGameMenu registration.
    return DealerRelations.Screen.new()
end

-------------------------------------------------------------------------------
-- GUI Loading
-------------------------------------------------------------------------------

-- Creates the screen instance and loads the Dealer Relations GUI XML into it.
--
-- Rationale:
-- This step verifies XML loading separately from ESC menu registration. The
-- screen is not added to InGameMenu yet, so a failure here can only come from
-- GUI loading or XML structure.
function DealerRelations.Screen:loadGui()
    local screen = DealerRelations.Screen:createInstance()

    g_gui:loadGui(
        DealerRelations.Screen.XML_FILENAME,
        DealerRelations.Screen.CLASS_NAME,
        screen,
        true
    )

    return screen
end

-------------------------------------------------------------------------------
-- ESC Menu Registration
-------------------------------------------------------------------------------

-- Registers the Dealer Relations screen as a page in the in-game ESC menu.
--
-- Rationale:
-- This follows the proven InGameMenu registration sequence used by other FS25
-- mods: load XML, attach the frame to the paging element, register the page,
-- add a tab icon, then rebuild the tab list.
function DealerRelations.Screen:register()
    local screen = DealerRelations.Screen:loadGui()
    local inGameMenu = g_gui.screenControllers[InGameMenu] or g_inGameMenu

    inGameMenu[DealerRelations.Screen.MENU_PAGE_NAME] = screen

    inGameMenu.pagingElement:addElement(screen)
    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    inGameMenu:registerPage(
        screen,
        nil,
        function()
            return true
        end
    )

    inGameMenu:addPageTab(
        screen,
        DealerRelations.Screen.MENU_ICON_FILENAME,
        GuiUtils.getUVs({0, 0, 1024, 1024})
    )

    inGameMenu:rebuildTabList()

    screen:initialize()

    -- Store Dealer Relations internal tab controls after XML loading.
    -- Rationale:
    -- The FS25 subcategory selector pattern expects parallel tab/page arrays.
    -- This mirrors the known-working NWT implementation and keeps tab switching
    -- inside one ESC menu page.
    screen.subCategoryTabs = {
        screen.drOverviewTab,
        screen.drConfigurationTab
    }

    screen.subCategoryPages = {
        screen.overviewPanel,
        screen.configurationPanel
    }

    -- Populate the paging control once.
    --
    -- Rationale:
    -- The paging control should contain exactly one entry per internal page.
    -- Adding entries from a click handler causes the list to grow every time
    -- the tab is selected, which breaks page/state mapping.
    screen.subCategoryPaging:addText("Overview")
    screen.subCategoryPaging:addText("Configuration")

    -- Initialize the paging control and visible page.
    screen.subCategoryPaging:setState(1)
    screen:updateSubCategoryPages(1)
    screen:updateConfigurationValues()
    screen:updateOverviewValues()
    
    screen.enabledOption = screen:addBinaryOption(
        "onClickEnabledOption",
        "Enabled",
        "Enable or disable Dealer Relations systems."
    )
    
    screen.enabledOption:setIsChecked(DealerRelations.Data:isEnabled())
    
    screen.debugOption = screen:addBinaryOption(
        "onClickDebugOption",
        "Debug",
        "Enable or disable Dealer Relations debug logging."
    )

    screen.debugOption:setIsChecked(DealerRelations.Data:isDebugEnabled())

    DealerRelations.log("Dealer Relations ESC menu page registered")
end

--- Handles selection of the Overview tab.
--  Rationale:
--  The tab bar is part of one Dealer Relations ESC page. Switching tabs only
--  toggles visibility of child panels; it does not change the FS25 menu page.
function DealerRelations.Screen:onClickOverviewTab()
    self:updateSubCategoryPages(1)
    self:updateOverviewValues()

    DealerRelations.log("Dealer Relations Overview tab selected")
end

--- Handles selection of the Configuration tab.
--  Rationale:
--  The tab bar is part of one Dealer Relations ESC page. Switching tabs only
--  toggles visibility of child panels; it does not change the FS25 menu page.
function DealerRelations.Screen:onClickConfigurationTab()
    self:updateSubCategoryPages(2)
    DealerRelations.log("Dealer Relations Configuration tab selected")
end

--- Updates the active Dealer Relations sub-page.
--
-- Rationale:
-- Mirrors the proven NWT implementation so internal page visibility is
-- managed in one place.
function DealerRelations.Screen:updateSubCategoryPages(state)
    for i, _ in ipairs(self.subCategoryPages) do
        self.subCategoryPages[i]:setVisible(false)
        self.subCategoryTabs[i]:setSelected(false)
    end

    self.subCategoryPages[state]:setVisible(true)
    self.subCategoryTabs[state]:setSelected(true)
    self.subCategoryPaging.state = state
end

function DealerRelations.Screen:onClickSubCategoryPaging(state, element)
    -- Paging arrows update the MultiTextOption state internally.
    -- Use that state as the source of truth so arrow clicks and direct tab clicks
    -- drive the same page switching path.
    self:updateSubCategoryPages(state)
end

--- Updates Configuration page setting display values.
--
-- Rationale:
-- Settings are stored in DealerRelations.Data and persisted per save.
-- The Configuration page should display the current saved runtime values
-- instead of static XML placeholder text.
function DealerRelations.Screen:formatBoolean(value)
    if value == true then
        return "Yes"
    end

    return "No"
end

function DealerRelations.Screen:updateConfigurationValues()
    -- Configuration values are now represented by native BinaryOption rows.
    -- Rationale:
    -- The rows are initialized directly after creation, so no text placeholders
    -- need to be refreshed here.
end

--- Creates a native FS25 binary settings row.
--
-- Rationale:
-- GIANTS settings pages and Advanced Damage System build boolean settings
-- from Lua using fs25_multiTextOptionContainer plus fs25_settingsBinaryOption.
-- Keeping row creation in one helper lets Configuration add Enabled/Debug
-- controls later without hand-placing fragile XML controls.
function DealerRelations.Screen:addBinaryOption(onClickCallback, title, tooltip)
    local row = BitmapElement.new()
    row:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)
    
    -- Keep the generated settings row transparent.
    -- Rationale:
    -- Dealer Relations already draws its own page background, so the row
    -- container should only provide layout for the option and title.
    row:setImageColor(0, 0, 0, 0)

    local option = BinaryOptionElement.new()
    option.useYesNoTexts = true
    option:loadProfile(g_gui:getProfile("fs25_settingsBinaryOption"), true)
    option.target = self
    option:setCallback("onClickCallback", onClickCallback)

    local titleText = TextElement.new()
    titleText:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
    titleText:setText(title)

    local tooltipText = TextElement.new()
    tooltipText.name = "ignore"
    tooltipText:loadProfile(g_gui:getProfile("fs25_multiTextOptionTooltip"), true)
    tooltipText:setText(tooltip or "")

    option:addElement(tooltipText)
    row:addElement(option)
    row:addElement(titleText)

    option:onGuiSetupFinished()
    titleText:onGuiSetupFinished()
    tooltipText:onGuiSetupFinished()

    self.settingsLayout:addElement(row)
    row:onGuiSetupFinished()

    -- Recalculate the scrolling layout after adding a dynamic settings row.
    -- Rationale:
    -- Advanced Damage System invalidates the settings layout after generating
    -- dynamic settings controls. Without this, the row can exist as a child but
    -- not be positioned/drawn by the layout.
    self.settingsLayout:invalidateLayout()

    return option
end

--- Handles changes to the Enabled setting.
--
-- Rationale:
-- The BinaryOption already manages its own visual state. This callback
-- updates Dealer Relations runtime data to match the UI selection.
function DealerRelations.Screen:onClickEnabledOption(option, element, isChecked)
    DealerRelations.Data:setEnabled(not isChecked)
end

--- Handles changes to the Debug setting.
--
-- Rationale:
-- The BinaryOption manages its own visual Yes/No state. This callback keeps
-- Dealer Relations runtime configuration synchronized with the user's
-- selection. Debug logging behavior is not modified here; that integration
-- will be implemented in a later step. For now, the callback only updates
-- the stored setting value so it can be persisted across save/load.
function DealerRelations.Screen:onClickDebugOption(option, element, isChecked)
    DealerRelations.Data:setDebugEnabled(not isChecked)

    DealerRelations.log(
        "Dealer Relations debug set to "
        .. tostring(not isChecked)
    )
end

--- Updates Overview page display values.
--
-- Rationale:
-- Overview values are displayed through GUI text controls. This helper
-- centralizes all Overview field updates so future refreshes only need to
-- call one function.
function DealerRelations.Screen:updateOverviewValues()
    self.relationshipLevelValueText:setText(
        DealerRelations.Data:getRelationshipName()
    )

    self.confidenceValueText:setText(
        tostring(DealerRelations.Data:getConfidence())
    )

    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer ~= nil then
        self.currentOfferValueText:setText(tostring(offer.name))
    else
        self.currentOfferValueText:setText("None")
    end
    
    local activeDemoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local activeDemoText = "None"

    if activeDemoVehicles ~= nil and #activeDemoVehicles > 0 then
        activeDemoText = tostring(activeDemoVehicles[1].name)
    end

    self.activeDemoValueText:setText(activeDemoText)
end

function DealerRelations.Screen:onFrameOpen()
    DealerRelations.Screen:superClass().onFrameOpen(self)

    -- Refresh Overview values when the ESC page is opened.
    -- Rationale:
    -- Demo offers can be created after the screen is registered, so the
    -- Overview page must read current runtime data whenever the player opens
    -- the Dealer Relations page.
    self:updateOverviewValues()
end