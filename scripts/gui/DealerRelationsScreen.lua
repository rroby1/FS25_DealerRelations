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

-- Tab icon displayed in the ESC menu tab bar for the Dealer Relations page.
DealerRelations.Screen.MENU_ICON_FILENAME =
    g_currentModDirectory .. "images/DRMenuIcon.png"

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
    
    -- Store the screen instance for access from other modules.
    -- Rationale:
    -- DemoManager needs to refresh the Overview after async vehicle loading
    -- completes. This reference allows that without coupling DemoManager
    -- directly to the GUI registration flow.
    DealerRelations.Screen.instance = screen

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
        screen.drFinancingTab,
        screen.drSettingsTab,
        screen.drHelpTab
    }

    screen.subCategoryPages = {
        screen.overviewPanel,
        screen.financingPanel,
        screen.settingsPanel,
        screen.helpPanel
    }
    
    -- Populate the paging control once.
    --
    -- Rationale:
    -- The paging control needs one entry per internal page so arrow clicks
    -- can advance through the same pages as the direct tab buttons.
    screen.subCategoryPaging:addText("Overview")
    screen.subCategoryPaging:addText("Financing")
    screen.subCategoryPaging:addText("Settings")
    screen.subCategoryPaging:addText("Help")

    -- Initialize the paging control and visible page.
    screen.subCategoryPaging:setState(1)
    screen:updateSubCategoryPages(1)
    screen:updateConfigurationValues()

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

    screen.forestryOption = screen:addBinaryOption(
        "onClickForestryOption",
        "Forestry Equipment",
        "Include forestry equipment (harvesters, forwarders, etc.) in demo offers."
    )
    screen.forestryOption:setIsChecked(DealerRelations.Data:isForestryEnabled())

    -- Build filter controls after XML controls are exposed.
    -- Rationale:
    -- category and brand layouts are created by the XML and exposed during
    -- initialize(), so dynamic rows should be generated only after initialization.
    screen:buildBrandFilterRows()

    screen.loanTable:setDataSource(screen)
    screen.loanTable:setDelegate(screen)
    screen.selectedLoanIndex = nil
       
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
--
-- Rationale:
-- Switches the visible sub-page to Configuration. Tab switching only
-- toggles child panel visibility within the Dealer Relations ESC page.
function DealerRelations.Screen:onClickSettingsTab()
    self:updateSubCategoryPages(3)
    DealerRelations.log("Dealer Relations Settings tab selected")
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

--- Handles paging arrow clicks on the sub-category control.
--
-- Rationale:
-- Paging arrows update the MultiTextOption state internally. Using that
-- state as the source of truth means arrow clicks and direct tab clicks
-- drive the same page switching path.
function DealerRelations.Screen:onClickSubCategoryPaging(state, element)
    self:updateSubCategoryPages(state)

    if state == 1 then
        self:updateOverviewValues()
    elseif state == 2 then
        self:updateFinancingValues()
    elseif state == 4  then
        self.helpLayout.fillDirections[2] = -1
        self.helpLayout.alignment[2] = 1
        self.helpLayout:invalidateLayout()
        self.helpLayout:raiseSliderUpdateEvent()
    end
end

--- Converts a boolean value to a Yes/No display string.
--
-- @param value boolean Value to format.
-- @return string "Yes" if true, "No" otherwise.
function DealerRelations.Screen:formatBoolean(value)
    if value == true then
        return "Yes"
    end

    return "No"
end

--- Updates Configuration page setting display values.
--
-- Rationale:
-- Settings are now represented by native BinaryOption rows initialized
-- directly after creation. No text placeholders need refreshing here.
function DealerRelations.Screen:updateConfigurationValues()
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

    --- Handles changes to the Forestry Equipment setting.
    --
    -- Rationale:
    -- Forestry has no reliable ownership/usage signal to auto-detect, so it is
    -- exposed as a manual toggle. This callback keeps Dealer Relations runtime
    -- configuration synchronized with the user's selection.
    function DealerRelations.Screen:onClickForestryOption(option, element, isChecked)
        DealerRelations.Data:setForestryEnabled(not isChecked)

        DealerRelations.log(
            "Dealer Relations forestry set to "
            .. tostring(not isChecked)
        )
    end

--- Handles selection of the Financing tab.
--
-- Rationale:
-- Switches the visible sub-page to Financing and refreshes loan data
-- so the player always sees current state when opening the tab.
function DealerRelations.Screen:onClickFinancingTab()
    self:updateSubCategoryPages(2)
    self:updateFinancingValues()
    DealerRelations.log("Dealer Relations Financing tab selected")
end

--- Updates Financing page display values.
--
-- Refreshes credit score, finance rate, and loan list.
-- Called when the tab is selected and after any loan action.
function DealerRelations.Screen:updateFinancingValues()
    local data = DealerRelations.Data

    -- Credit score and finance rate summary.
    self.creditScoreValueText:setText(tostring(data:getCreditScore()))

    local rate = data:getFinanceRate()
    if rate ~= nil then
        self.financeRateValueText:setText(string.format("%.0f%%", rate * 100))
    else
        self.financeRateValueText:setText("N/A")
    end

    -- Show loan list or empty state.
    local loans = data:getActiveLoans()

    if #loans == 0 then
        self.financeTableContainer:setVisible(false)
        self.financeNoLoansContainer:setVisible(true)
        self.loanActionsLayout:setVisible(false)
        return
    end

    self.financeTableContainer:setVisible(true)
    self.financeNoLoansContainer:setVisible(false)

    self.loanTable:reloadData()

    -- Show Pay Off button if a loan is selected.
    self:refreshLoanActionButtons()
end

--- Populates a loan table cell for the given index.
--
-- @param list table SmoothList element.
-- @param section number Section index (always 1).
-- @param index number Row index.
-- @param cell table Cell element to populate.
function DealerRelations.Screen:populateCellForItemInSection(list, section, index, cell)
    local loan = DealerRelations.Data:getActiveLoans()[index]

    if loan == nil then
        return
    end

    cell:getAttribute("loan_name"):setText(tostring(loan.name))
    cell:getAttribute("loan_payment"):setText(
        "$" .. DealerRelations.Utils:formatMoney(loan.monthlyPayment)
    )
    cell:getAttribute("loan_rate"):setText(
        string.format("%.0f%%", (loan.annualRate or 0) * 100)
    )
    cell:getAttribute("loan_months"):setText(tostring(loan.remainingMonths or 0))
    cell:getAttribute("loan_remaining"):setText(
        "$" .. DealerRelations.Utils:formatMoney(loan.remainingPrincipal)
    )
end

--- Returns the number of sections in the loan table.
--
-- @return number Always 1.
function DealerRelations.Screen:getNumberOfSections()
    return 1
end

--- Returns the number of loans in the loan table.
--
-- @param list table SmoothList element.
-- @param section number Section index.
-- @return number Number of active loans.
function DealerRelations.Screen:getNumberOfItemsInSection(list, section)
    return #DealerRelations.Data:getActiveLoans()
end

--- Returns the section header title.
--
-- @return string Empty string — no section header needed.
function DealerRelations.Screen:getTitleForSectionHeader(list, section)
    return ""
end

--- Handles loan table selection change.
--
-- @param list table SmoothList element.
-- @param section number Section index.
-- @param index number Selected row index.
function DealerRelations.Screen:onListSelectionChanged(list, section, index)
    self.selectedLoanIndex = index
    self:refreshLoanActionButtons()
end

--- Rebuilds the loan action buttons for the currently selected loan.
--
-- Rationale:
-- The actions layout is cleared and rebuilt on selection change so
-- the Pay Off button always reflects the selected loan state.
function DealerRelations.Screen:refreshLoanActionButtons()
    while #self.loanActionsLayout.elements > 0 do
        self.loanActionsLayout:removeElement(self.loanActionsLayout.elements[1])
    end

    local loans = DealerRelations.Data:getActiveLoans()
    local loan = loans[self.selectedLoanIndex]

    if loan == nil then
        self.loanActionsLayout:setVisible(false)
        return
    end

    self.loanActionsLayout:setVisible(true)
    self:addButtonToLayout(self.loanActionsLayout, "onClickPayOffLoan", "Pay Off")
end

--- Handles Pay Off button click.
--
-- Rationale:
-- Attempts early payoff on the selected loan and refreshes the
-- Financing tab to reflect the updated loan state.
function DealerRelations.Screen:onClickPayOffLoan()
    local loans = DealerRelations.Data:getActiveLoans()
    local loan = loans[self.selectedLoanIndex]

    if loan == nil then
        return
    end

    local success, reason = DealerRelations.Finance:processEarlyPayoff(loan)

    if success then
        self.selectedLoanIndex = nil
        self:updateFinancingValues()
    else
        DealerRelations.log("Pay Off failed: " .. tostring(reason))
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "Dealer Relations: " .. tostring(reason)
        )
    end
end

--- Updates Overview page display values.
--
-- Rationale:
-- Overview values are displayed through GUI text controls. This helper
-- centralizes all Overview field updates so future refreshes only need to
-- call one function.
function DealerRelations.Screen:updateOverviewValues()
    self.dealerLogoImage:setImageFilename(
        DealerRelations.directory .. "Icon.dds"
    )

    self.dealerNameValueText:setText(
        DealerRelations.Data:getDealerName()
    )

    self.dealerHoursValueText:setText(
        DealerRelations.Data:getDealerHoursText()
    )

    if DealerRelations.Data:isDealerOpen() then
        self.dealerStatusValueText:setText("Open")
        self.dealerStatusValueText:setTextColor(0, 1, 0, 1)
    else
        self.dealerStatusValueText:setText("Closed")
        self.dealerStatusValueText:setTextColor(0.7, 0, 0, 1)
    end

    self.relationshipLevelValueText:setText(
        DealerRelations.Data:getRelationshipName()
    )

    self.confidenceValueText:setText(
        tostring(DealerRelations.Data:getConfidence())
    )

    -- Clear the offer actions layout before rebuilding.
    -- Rationale:
    -- updateOverviewValues can be called multiple times. Clearing first
    -- prevents duplicate buttons from accumulating in the layout.
    while #self.offerActionsLayout.elements > 0 do
        self.offerActionsLayout:removeElement(self.offerActionsLayout.elements[1])
    end

    local offer = DealerRelations.Data:getActiveDemoOffer()
    local demo = DealerRelations.Data:getActiveDemo()

    if offer ~= nil then
        self.dealerActivityTitleText:setVisible(false)

        local storeItem = g_storeManager:getItemByXMLFilename(offer.xmlFilename)
        if storeItem ~= nil then
            self.offerImage:setVisible(true)
            self.offerImage:setImageFilename(storeItem.imageFilename)
        end

        if DealerRelations.Data:isDealerOpen() then
            self.offerActionsLayout:setVisible(true)
            self:addButtonToLayout(self.offerActionsLayout, "onClickAcceptOffer", "Accept")
            self:addButtonToLayout(self.offerActionsLayout, "onClickDeclineOffer", "Decline")
        else
            self.offerActionsLayout:setVisible(false)
        end

        -- Include the companion's name and price, if the offer has one
        -- (e.g. a header bundled with a trailer) -- the player should see
        -- both pieces and the combined price before accepting, not just
        -- the primary.
        local equipmentDisplayName = tostring(offer.name)
        local combinedListPrice = offer.price or 0

        if offer.companionName ~= nil then
            equipmentDisplayName = equipmentDisplayName .. " + " .. tostring(offer.companionName)
            combinedListPrice = combinedListPrice + (offer.companionPrice or 0)
        end

        self.dealerActivityDetail1Text:setText(
            "Equipment: " .. equipmentDisplayName
        )

        self.dealerActivityDetail2Text:setText(
            "Brand: " .. DealerRelations.Utils:getBrandDisplayName(offer.brand)
        )

        self.dealerActivityDetail3Text:setText(
            "Category: " .. DealerRelations.Utils:getCategoryDisplayName(offer.category)
        )
        self.dealerActivityDetail4Text:setText(
            "Power: " .. tostring(offer.displayPower)
        )
        self.dealerActivityDetail5Text:setText(
            "Price: " .. DealerRelations.Utils:formatMoney(combinedListPrice)
        )

        self.dealerActivityDetail6Text:setText(
            string.format("Equipment Hour Limit: %.2f hr",
                DealerRelations.Data:getDemoOperatingHourLimit()
            )
        )

    elseif demo ~= nil then
        self.dealerActivityTitleText:setVisible(false)

        local storeItem = g_storeManager:getItemByXMLFilename(demo.xmlFilename)
        if storeItem ~= nil then
            self.offerImage:setVisible(true)
            self.offerImage:setImageFilename(storeItem.imageFilename)
        end

        if DealerRelations.Data:isDealerOpen() then
            self.offerActionsLayout:setVisible(true)
            self:addButtonToLayout(self.offerActionsLayout, "onClickReturnDemo", "Return")
            self:addButtonToLayout(self.offerActionsLayout, "onClickBuyDemo", "Buy")
        else
            self.offerActionsLayout:setVisible(false)
        end

        local discountPercent = DealerRelations.Data:getDiscountPercent()
        local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demo.uniqueId)
        local purchasePrice = 0
        local hoursUsed = 0

        -- Include the companion's price, if one exists, matching the
        -- combined price buyActiveDemo() actually charges -- this display
        -- must never show a lower number than what clicking Buy will
        -- actually cost.
        local secondary = DealerRelations.DemoManager:findSecondaryDemoVehicle()
        local equipmentDisplayName = tostring(demo.name)
        local combinedListPrice = 0

        if vehicle ~= nil then
            combinedListPrice = vehicle.price
            local currentHours = vehicle:getOperatingTime() / (1000 * 60 * 60)
            hoursUsed = currentHours - (demo.startOperatingHours or 0)
        end

        if secondary ~= nil then
            equipmentDisplayName = equipmentDisplayName .. " + " .. tostring(secondary.name)

            local secondaryVehicle = DealerRelations.DemoManager:findVehicleByUniqueId(secondary.uniqueId)
            if secondaryVehicle ~= nil then
                combinedListPrice = combinedListPrice + secondaryVehicle.price
            end
        end

        purchasePrice = DealerRelations.Data:getDemoPurchasePrice(combinedListPrice)

        self.dealerActivityDetail1Text:setText(
            "Equipment: " .. equipmentDisplayName
        )
        self.dealerActivityDetail2Text:setText(
            "Brand: " .. DealerRelations.Utils:getBrandDisplayName(demo.brand)
        )
        self.dealerActivityDetail3Text:setText(
            "Status: " .. tostring(demo.state)
        )
        self.dealerActivityDetail4Text:setText(
            "Discount: " .. tostring(discountPercent) .. "%"
        )
        self.dealerActivityDetail5Text:setText(
            "Purchase Price: " .. DealerRelations.Utils:formatMoney(purchasePrice)
        )

        self.dealerActivityDetail6Text:setText(
            string.format("Equipment Hour Limit: %.2f hr",
                DealerRelations.Data:getDemoOperatingHourLimit()
            )
        )

    else
        self.dealerActivityTitleText:setVisible(true)
        self.dealerActivityTitleText:setText("No dealer activity.")
        self.offerActionsLayout:setVisible(false)
        self.dealerActivityDetail1Text:setText("")
        self.dealerActivityDetail2Text:setText("")
        self.dealerActivityDetail3Text:setText("")
        self.dealerActivityDetail4Text:setText("")
        self.dealerActivityDetail5Text:setText("")
        self.offerImage:setVisible(false)
    end
end

-------------------------------------------------------------------------------
-- Called when the Dealer Relations ESC page is opened.
--
-- Rationale:
-- Demo offers can be created after the screen is registered, so the
-- Overview page must read current runtime data whenever the player opens
-- the Dealer Relations page.
-------------------------------------------------------------------------------
function DealerRelations.Screen:onFrameOpen()
    DealerRelations.Screen:superClass().onFrameOpen(self)

    -- Refresh Overview values when the ESC page is opened.
    -- Rationale:
    -- Demo offers can be created after the screen is registered, so the
    -- Overview page must read current runtime data whenever the player opens
    -- the Dealer Relations page.
    self:updateOverviewValues()
end

--- Creates a binary option row in a specific scrolling layout.
-- Rationale:
-- Category and brand filters use the same native FS25 BinaryOption row pattern
-- as Configuration settings, but they live on their own pages and layouts.
function DealerRelations.Screen:addBinaryOptionToLayout(layout, onClickCallback, title, tooltip)
    local row = BitmapElement.new()
    row:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)

    -- Keep generated filter rows transparent so the Dealer Relations panel
    -- background remains visually consistent.
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

    layout:addElement(row)
    row:onGuiSetupFinished()

    -- Dynamic rows are not positioned until the scrolling layout recalculates.
    layout:invalidateLayout()

    return option
end

--- Creates a native FS25 button row in a scrolling layout.
-- Rationale:
-- Mirrors addBinaryOptionToLayout using ButtonElement instead of
-- BinaryOptionElement. Allows dynamic button creation in ScrollingLayouts
-- using the same proven pattern as the Configuration and filter pages.
function DealerRelations.Screen:addButtonToLayout(layout, onClickCallback, buttonText)
    local row = BitmapElement.new()
    row:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)
    row:setImageColor(0, 0, 0, 0)

    local button = ButtonElement.new(self)
    button:loadProfile(g_gui:getProfile("dr_settingsButton"), true)
    button.target = self
    button:setCallback("onClickCallback", onClickCallback)
   
    -- Add the background ThreePartBitmap to the button.
    -- Rationale:
    -- Without this child element the button renders as a black box.
    -- This mirrors the pattern used in the working mod's XML button definition.
    local bg = ThreePartBitmapElement.new()
    bg:loadProfile(g_gui:getProfile("fs25_settingsButtonBg"), true)
    button:addElement(bg)
    bg:onGuiSetupFinished()

    local tooltip = TextElement.new()
    tooltip:loadProfile(g_gui:getProfile("fs25_multiTextOptionTooltip"), true)
    tooltip.name = "tooltip"
    tooltip:setText("")
    button:addElement(tooltip)
    tooltip:onGuiSetupFinished()

    local titleText = TextElement.new()
    titleText:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
    titleText:setText("")

    row:addElement(button)
    row:addElement(titleText)

    button:onGuiSetupFinished()
    titleText:onGuiSetupFinished()

    button:setText(buttonText)

    layout:addElement(row)
    row:onGuiSetupFinished()

    layout:invalidateLayout()

    return button
end

--- Builds the Brand filter rows.
-- Rationale:
-- Brand filter persistence and discovery logic already use the
-- DealerRelations.Data brand filter table. The UI should edit that same
-- source of truth instead of maintaining a separate brand list.
function DealerRelations.Screen:buildBrandFilterRows()
    if self.brandRowsBuilt == true then
        return
    end

    local brandFilters = DealerRelations.Data:getBrandFilters()
    local brandNames = {}

    for brandName, _ in pairs(brandFilters) do
        table.insert(brandNames, brandName)
    end

    -- Sort by display name rather than internal key so the player sees
    -- an alphabetical list regardless of how GIANTS names the brand internally.
    table.sort(brandNames, function(a, b)
        return DealerRelations.Utils:getBrandDisplayName(a)
            < DealerRelations.Utils:getBrandDisplayName(b)
    end)

    for _, brandName in ipairs(brandNames) do
        local brandDisplayName = DealerRelations.Utils:getBrandDisplayName(brandName)

        local option = self:addBinaryOptionToLayout(
            self.brandsLayout,
            "onClickBrandFilterOption",
            brandDisplayName,
            "Allow demo offers from the " .. brandDisplayName .. " brand."
        )

        -- Store the brand key directly on the option so the callback can
        -- update the matching persisted filter entry without lookup tables.
        option.brandName = brandName
        option:setIsChecked(DealerRelations.Data:isBrandEnabled(brandName))
    end

    self.brandRowsBuilt = true
end

--- Handles changes to one brand filter row.
-- Rationale:
-- Dynamically generated BinaryOption rows pass the selected state first and
-- the option element second. The brand key is stored on the option element
-- so the callback updates the matching persisted filter entry.
function DealerRelations.Screen:onClickBrandFilterOption(state, element, isChecked)
    if element == nil or element.brandName == nil then
        return
    end

    local enabled = not isChecked

    DealerRelations.Data:setBrandEnabled(element.brandName, enabled)

    DealerRelations.log(
        "Dealer Relations brand filter set: "
        .. tostring(element.brandName)
        .. "="
        .. tostring(enabled)
    )
end

--- Handles Accept Offer button click on the Overview page.
-- Rationale:
-- Accepts the active demo offer, clears the offer actions layout,
-- and refreshes the Overview so the player sees the updated state
-- without closing the ESC menu.
function DealerRelations.Screen:onClickAcceptOffer()
    DealerRelations.UI:acceptActiveDemoOffer()
    self:updateOverviewValues()
end

--- Handles Decline Offer button click on the Overview page.
-- Rationale:
-- Declines the active demo offer and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickDeclineOffer()
    DealerRelations.UI:declineActiveDemoOffer()
    self:updateOverviewValues()
end

--- Handles Return Demo button click on the Overview page.
-- Rationale:
-- Returns the active demo vehicle and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickReturnDemo()
    DealerRelations.UI:returnActiveDemo()
    self:updateOverviewValues()
end

--- Handles Buy Demo button click on the Overview page.
-- Rationale:
-- Purchases the active demo vehicle and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickBuyDemo()
    DealerRelations.UI:buyActiveDemo()
    self:updateOverviewValues()
end
