-------------------------------------------------------------------------------
-- DealerRelationsFinancingPanel.lua
--
-- Financing tab logic for the Dealer Relations ESC menu page.
--
-- Split out of DealerRelationsScreen.lua as part of the 0.24.0 width
-- redesign -- these functions attach to the same DealerRelations.Screen
-- table (Lua doesn't care which file a method is defined in), this is
-- purely a file-organization change with no behavior change.
--
-- Responsibilities:
--   * Rendering credit score, finance rate, and the loan list
--   * Loan table SmoothList delegate methods
--   * Loan actions (Pay Off)
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Screen = DealerRelations.Screen or {}

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
-- @return string Empty string -- no section header needed.
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
