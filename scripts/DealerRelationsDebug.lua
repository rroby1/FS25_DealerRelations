-------------------------------------------------------------------------------
-- DealerRelationsDebug.lua
--
-- Provides logging utilities and console commands for Dealer Relations.
--
-- Responsibilities:
--   - Debug logging helpers
--   - Console command registration
--   - Console command handlers
--
-- Console commands are registered for singleplayer only.
-- Commands execute immediately with no confirmation step.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}

DealerRelations.debug = true

-------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes a debug message to the log when debug mode is enabled.
--
-- @param message string Message to write to the game log.
-------------------------------------------------------------------------------
function DealerRelations.log(message)
    if DealerRelations.debug then
        print("[DealerRelations] " .. tostring(message))
    end
end

-------------------------------------------------------------------------------
-- Writes a warning message to the log unconditionally.
-- Warning messages are always printed regardless of debug mode.
--
-- @param message string Message to write to the game log.
-------------------------------------------------------------------------------
function DealerRelations.warning(message)
    print("[DealerRelations WARNING] " .. tostring(message))
end

-------------------------------------------------------------------------------
-- Console Command Registration
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Registers all Dealer Relations console commands.
--
-- Called from DealerRelations:loadMap() after initialization.
-- Singleplayer only — manipulating loan and relationship state in
-- multiplayer could cause desyncs.
-------------------------------------------------------------------------------
function DealerRelations.registerConsoleCommands()
    if not g_currentMission:getIsServer() or
       g_currentMission.missionDynamicInfo.isMultiplayer then
        return
    end

    addConsoleCommand(
        "dr_status",
        "Dump all Dealer Relations state to log",
        "consoleCommandStatus",
        DealerRelations
    )

    addConsoleCommand(
        "dr_addTestLoan",
        "Originate a loan on the current active demo vehicle",
        "consoleCommandAddTestLoan",
        DealerRelations
    )

    addConsoleCommand(
        "dr_advanceLoan",
        "Simulate x monthly payment cycles on all active loans",
        "consoleCommandAdvanceLoan",
        DealerRelations,
        "[months]"
    )

    addConsoleCommand(
        "dr_missPayment",
        "Force a missed payment on the highest rate active loan",
        "consoleCommandMissPayment",
        DealerRelations
    )

    addConsoleCommand(
        "dr_clearLoans",
        "Clear all active loans",
        "consoleCommandClearLoans",
        DealerRelations
    )

    addConsoleCommand(
        "dr_setConfidence",
        "Set confidence to x",
        "consoleCommandSetConfidence",
        DealerRelations,
        "[confidence]"
    )

    addConsoleCommand(
        "dr_addRepaidLoan",
        "Increment lifetime loans repaid count by one",
        "consoleCommandAddRepaidLoan",
        DealerRelations
    )

    addConsoleCommand(
        "dr_addMissedPayment",
        "Increment lifetime missed payments count by one",
        "consoleCommandAddMissedPayment",
        DealerRelations
    )

    addConsoleCommand(
        "dr_clearMissedPayments",
        "Reset lifetime missed payments count to zero",
        "consoleCommandClearMissedPayments",
        DealerRelations
    )

    addConsoleCommand(
        "dr_resetAll",
        "Full reset of all Dealer Relations state to defaults",
        "consoleCommandResetAll",
        DealerRelations
    )

    addConsoleCommand(
        "dr_toggleForestry",
        "Toggle the forestry equipment demo setting",
        "consoleCommandToggleForestry",
        DealerRelations
    )

    addConsoleCommand(
        "dr_forestryCount",
        "Count forestry items in discovered equipment list",
        "consoleCommandForestryCount",
        DealerRelations
    )

    addConsoleCommand(
        "dr_eligibleCount",
        "Count currently eligible demo candidates by category",
        "consoleCommandEligibleCount",
        DealerRelations
    )

    addConsoleCommand(
        "dr_motorConfigs",
        "Dump store-side motor configuration data for owned vehicles",
        "consoleCommandMotorConfigs",
        DealerRelations
    )
    
    DealerRelations.log("Console commands registered")
end

-------------------------------------------------------------------------------
-- Console Command Handlers
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Dumps all Dealer Relations finance state to the log.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandStatus()
    local data = DealerRelations.Data

    print("[DealerRelations] === DR Status ===")
    print(string.format(
        "[DealerRelations] Confidence: %d | Relationship: %s (Level %d)",
        data:getConfidence(),
        data:getRelationshipName(),
        data:getRelationshipLevel()
    ))
    print(string.format(
        "[DealerRelations] Forestry Demos Enabled: %s",
        tostring(data:isForestryEnabled())
    ))
    print(string.format(
        "[DealerRelations] Credit Score: %d | Finance Rate: %s | Finance Term: %s",
        data:getCreditScore(),
        tostring(data:getFinanceRate()),
        tostring(data:getFinanceTerm())
    ))
    print(string.format(
        "[DealerRelations] Total Loans Repaid: %d | Total Missed Payments: %d",
        data:getTotalLoansRepaid(),
        data:getTotalMissedPayments()
    ))

    local loans = data:getActiveLoans()
    print(string.format(
        "[DealerRelations] Active Loans: %d",
        #loans
    ))

    for i, loan in ipairs(loans) do
        print(string.format(
            "[DealerRelations] Loan %d: %s | Principal: $%d | Remaining: $%d | Rate: %.0f%% | Months Left: %d | Miss: %d",
            i,
            tostring(loan.name),
            loan.principal or 0,
            loan.remainingPrincipal or 0,
            (loan.annualRate or 0) * 100,
            loan.remainingMonths or 0,
            loan.missCount or 0
        ))
    end

    local eligible, reason = DealerRelations.Finance:isEligibleForFinancing()
    print(string.format(
        "[DealerRelations] Finance Eligible: %s %s",
        tostring(eligible),
        reason ~= nil and ("(" .. reason .. ")") or ""
    ))

    return "DR status dumped to log"
end

-------------------------------------------------------------------------------
-- Originates a loan on the current active demo vehicle.
-- Bypasses the UI confirmation step. Uses the normal origination code path.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandAddTestLoan()
    local demoVehicle = DealerRelations.Data:getActiveDemo()

    if demoVehicle == nil then
        return "dr_addTestLoan: no active demo vehicle found"
    end

    local success, reason = DealerRelations.Finance:originateLoan(demoVehicle)

    if success then
        return string.format(
            "dr_addTestLoan: loan originated for %s",
            tostring(demoVehicle.name)
        )
    else
        return string.format(
            "dr_addTestLoan: failed — %s",
            tostring(reason)
        )
    end
end

-------------------------------------------------------------------------------
-- Simulates x monthly payment cycles on all active loans.
--
-- @param months string Number of months to advance (parsed to number).
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandAdvanceLoan(months)
    months = tonumber(months)

    if months == nil or months < 1 then
        return "dr_advanceLoan: usage: dr_advanceLoan [months]"
    end

    local loans = DealerRelations.Data:getActiveLoans()

    if #loans == 0 then
        return "dr_advanceLoan: no active loans"
    end

    for i = 1, months do
        DealerRelations.Finance:checkMonthlyLoanPayments()
    end

    return string.format(
        "dr_advanceLoan: advanced %d payment cycle(s). Active loans: %d",
        months,
        #DealerRelations.Data:getActiveLoans()
    )
end

-------------------------------------------------------------------------------
-- Forces a missed payment on the highest rate active loan.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandMissPayment()
    local loans = DealerRelations.Data:getActiveLoans()

    if #loans == 0 then
        return "dr_missPayment: no active loans"
    end

    -- Find highest rate loan.
    local targetLoan = loans[1]
    for _, loan in ipairs(loans) do
        if (loan.annualRate or 0) > (targetLoan.annualRate or 0) then
            targetLoan = loan
        end
    end

    DealerRelations.Finance:advanceMissLadder(targetLoan)

    return string.format(
        "dr_missPayment: miss applied to %s — missCount now %d",
        tostring(targetLoan.name),
        targetLoan.missCount or 0
    )
end

-------------------------------------------------------------------------------
-- Clears all active loans.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandClearLoans()
    local loans = DealerRelations.Data:getActiveLoans()
    local count = #loans

    for i = #loans, 1, -1 do
        DealerRelations.Data:removeActiveLoanByUniqueId(loans[i].uniqueId)
    end

    return string.format("dr_clearLoans: %d loan(s) cleared", count)
end

-------------------------------------------------------------------------------
-- Sets confidence to the given value.
--
-- @param confidence string Confidence value (parsed to number).
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandSetConfidence(confidence)
    confidence = tonumber(confidence)

    if confidence == nil then
        return "dr_setConfidence: usage: dr_setConfidence [confidence]"
    end

    DealerRelations.Data:setConfidence(confidence)

    return string.format(
        "dr_setConfidence: confidence set to %d (relationship: %s)",
        DealerRelations.Data:getConfidence(),
        DealerRelations.Data:getRelationshipName()
    )
end

-------------------------------------------------------------------------------
-- Increments the lifetime loans repaid count by one.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandAddRepaidLoan()
    DealerRelations.Data:incrementTotalLoansRepaid()

    return string.format(
        "dr_addRepaidLoan: totalLoansRepaid now %d | credit score now %d",
        DealerRelations.Data:getTotalLoansRepaid(),
        DealerRelations.Data:getCreditScore()
    )
end

-------------------------------------------------------------------------------
-- Increments the lifetime missed payments count by one.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandAddMissedPayment()
    DealerRelations.Data:incrementTotalMissedPayments()

    return string.format(
        "dr_addMissedPayment: totalMissedPayments now %d | credit score now %d",
        DealerRelations.Data:getTotalMissedPayments(),
        DealerRelations.Data:getCreditScore()
    )
end

-------------------------------------------------------------------------------
-- Resets the lifetime missed payments count to zero.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandClearMissedPayments()
    DealerRelations.dealerData.totalMissedPayments = 0

    return string.format(
        "dr_clearMissedPayments: totalMissedPayments reset to 0 | credit score now %d",
        DealerRelations.Data:getCreditScore()
    )
end

-------------------------------------------------------------------------------
-- Resets all Dealer Relations state to defaults.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandResetAll()
    DealerRelations.Data:setConfidence(0)
    DealerRelations.dealerData.totalLoansRepaid = 0
    DealerRelations.dealerData.totalMissedPayments = 0
    DealerRelations.dealerData.activeLoans = {}
    DealerRelations.Data:clearActiveDemoOffer()
    DealerRelations.Data:clearSuspensionEndMonth()
    DealerRelations.Data:clearPendingSuspensionMonths()

    return "dr_resetAll: all Dealer Relations state reset to defaults"
end

-------------------------------------------------------------------------------
-- Toggles the forestry equipment demo setting.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandToggleForestry()
    local newValue = not DealerRelations.Data:isForestryEnabled()
    DealerRelations.Data:setForestryEnabled(newValue)

    return string.format(
        "dr_toggleForestry: forestry demos now %s",
        tostring(newValue)
    )
end

-------------------------------------------------------------------------------
-- Counts forestry-category entries in the discovered equipment list.
-- Useful for verifying the forestry toggle without relying on random
-- demo offers to happen to surface (or not surface) a forestry item.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandForestryCount()
    local count = 0

    for _, entry in ipairs(DealerRelations.equipmentList) do
        if DealerRelations.Equipment.FORESTRY_CATEGORIES[tostring(entry.category)] == true then
            count = count + 1
        end
    end

    return string.format(
        "dr_forestryCount: %d forestry item(s) in equipment list (forestryEnabled=%s)",
        count,
        tostring(DealerRelations.Data:isForestryEnabled())
    )
end

-------------------------------------------------------------------------------
-- Counts currently-eligible demo candidates by category, re-evaluating
-- eligibility fresh via isCurrentlyEligible() rather than reading a stale
-- snapshot from discovery time. Useful for verifying category toggles and
-- crop-history gating without waiting on a random monthly offer to happen
-- to surface (or not surface) a given category.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandEligibleCount()
    local eligibleByCategory = {}
    local eligibleCount = 0
    local categoryCount = 0

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        if DealerRelations.Equipment:isCurrentlyEligible(candidate) then
            eligibleCount = eligibleCount + 1

            if eligibleByCategory[candidate.category] == nil then
                categoryCount = categoryCount + 1
            end

            eligibleByCategory[candidate.category] = (eligibleByCategory[candidate.category] or 0) + 1
        end
    end

    print(string.format("[DealerRelations] Total currently eligible: %d", eligibleCount))
    for category, count in pairs(eligibleByCategory) do
        print(string.format("[DealerRelations]   %s: %d", category, count))
    end

    return string.format(
        "dr_eligibleCount: %d total eligible item(s) across %d categorie(s) (see log for breakdown)",
        eligibleCount,
        categoryCount
    )
end

-------------------------------------------------------------------------------
-- Dumps store-side "motor" configuration data for every owned vehicle that
-- has one. Temporary — used to confirm actual field names (specifically HP)
-- before writing HP-eligibility logic.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandMotorConfigs()
    if g_currentMission == nil or g_currentMission.vehicleSystem == nil
        or g_currentMission.vehicleSystem.vehicles == nil then
        return "dr_motorConfigs: vehicleSystem.vehicles unavailable"
    end

    local count = 0

    for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
        if vehicle.configurations ~= nil and vehicle.configurations["motor"] ~= nil then
            count = count + 1
            local motorConfigId = vehicle.configurations["motor"]
            local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)

            print(string.format(
                "[DealerRelations] vehicle='%s' configFileName='%s' motorConfigId=%s",
                tostring(vehicle.getName ~= nil and vehicle:getName() or "?"),
                tostring(vehicle.configFileName),
                tostring(motorConfigId)
            ))

            if storeItem == nil then
                print("[DealerRelations]   storeItem is nil")
            elseif storeItem.configurations == nil or storeItem.configurations["motor"] == nil then
                print("[DealerRelations]   storeItem.configurations[\"motor\"] is nil")
            else
                local configEntry = storeItem.configurations["motor"][motorConfigId]
                if configEntry == nil then
                    print("[DealerRelations]   configEntry is nil for this id")
                else
                    for key, value in pairs(configEntry) do
                        print(string.format("[DealerRelations]   configEntry.%s = %s", tostring(key), tostring(value)))
                    end
                end
            end
        end
    end

    return string.format("dr_motorConfigs: checked %d vehicle(s) with a motor config", count)
end