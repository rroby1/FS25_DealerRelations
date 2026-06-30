-------------------------------------------------------------------------------
-- DealerRelationsFinance.lua
--
-- Manages the dealer financing system for Dealer Relations.
--
-- Responsibilities:
-- - Loan origination and eligibility checks
-- - Monthly payment processing
-- - Missed payment ladder consequences
-- - Early payoff and principal payment handling
-- - Passive confidence recovery
-- - Monthly payment calculation
--
-- This module operates on data owned by DealerRelationsData.lua.
-- It does not access dealerData directly; all state is read and
-- written through DealerRelations.Data getters and setters.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Finance = DealerRelations.Finance or {}

-------------------------------------------------------------------------------
-- Loan Record Template
--
-- Documents the structure of a loan record created by originateLoan().
-- All fields are required unless noted.
--
-- {
--     uniqueId = string,            -- demo vehicle uniqueId this loan covers
--     name = string,                -- equipment name for display
--     brand = string,               -- equipment brand for display
--     xmlFilename = string,         -- source XML for mod removal validation
--     farmId = number,              -- farmID for the player
--
--     principal = number,           -- original loan amount (price after discount)
--     remainingPrincipal = number,  -- current outstanding principal
--     annualRate = number,          -- annual interest rate (e.g. 0.06 for 6%)
--     termMonths = number,          -- original loan term in months
--     remainingMonths = number,     -- months remaining
--     monthlyPayment = number,      -- fixed monthly payment amount
--
--     missCount = number,           -- consecutive missed payments (0-4)
--     missNoticeSent = boolean,     -- whether consequence for current miss fired
--
--     originationMonth = number,    -- calendar month when loan was created (1-12)
--     originationYear = number,     -- game year when loan was created
--     monthsSinceLastBoost = number,  -- payment cycles since last annual confidence boost
-- }
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

-- Internal Helpers
-------------------------------------------------------------------------------
--- Calculates the fixed monthly payment for a loan.
--
-- Uses standard amortization formula:
-- M = P * (r * (1 + r)^n) / ((1 + r)^n - 1)
--
-- Where P = principal, r = monthly interest rate, n = term in months.
-- Edge case: if annualRate is 0%, monthly payment = principal / termMonths.
--
-- @param principal number Original loan amount.
-- @param annualRate number Annual interest rate as a decimal (e.g. 0.06 for 6%).
-- @param termMonths number Loan term in months.
-- @return number Fixed monthly payment amount.
function DealerRelations.Finance:calculateMonthlyPayment(principal, annualRate, termMonths)
    if principal <= 0 or termMonths <= 0 then
        return 0
    end

    if annualRate == 0 then
        return principal / termMonths
    end

    local monthlyRate = annualRate / 12
    local factor = (1 + monthlyRate) ^ termMonths

    return principal * (monthlyRate * factor) / (factor - 1)
end

-------------------------------------------------------------------------------
-- Eligibility
-------------------------------------------------------------------------------

--- Returns whether the player currently qualifies for financing.
--
-- Qualification requires a positive relationship level and a credit score
-- at or above the refusal threshold.
--
-- Floor rule: a player with a positive relationship level and no active
-- missed payments always qualifies at their base rate regardless of score.
-- The refusal threshold only applies when the player has active overdue loans.
--
-- @return boolean True if the player qualifies for financing.
-- @return string Reason string if the player does not qualify, nil otherwise.
function DealerRelations.Finance:isEligibleForFinancing()
    local constants = DealerRelations.CONSTANTS
    local level = DealerRelations.Data:getRelationshipLevel()

    -- Negative relationship levels never qualify.
    if level <= 0 then
        return false, "Relationship level too low for financing."
    end

    -- Floor rule: positive relationship and no active missed payments
    -- always qualifies regardless of credit score.
    if not DealerRelations.Data:hasOverdueLoans() then
        return true, nil
    end

    -- Active missed payments exist — apply credit score refusal threshold.
    local score = DealerRelations.Data:getCreditScore()

    if score < constants.CREDIT_SCORE_REFUSAL_THRESHOLD then
        return false, "Credit score too low for financing."
    end

    return true, nil
end

-------------------------------------------------------------------------------
-- Loan Origination
-------------------------------------------------------------------------------

--- Creates and registers a new loan for the given demo vehicle.
--
-- Validates eligibility, calculates terms, deducts no funds at origination.
-- Converts the demo vehicle to OWNED state after successful origination.
--
-- @param demoVehicle table Demo vehicle record to finance.
-- @return boolean True if the loan was successfully originated.
-- @return string Reason string if origination failed, nil otherwise.
function DealerRelations.Finance:originateLoan(demoVehicle)
    if demoVehicle == nil then
        return false, "No demo vehicle provided."
    end

    -- Prevent duplicate loans for the same vehicle.
    if DealerRelations.Data:hasActiveLoan(demoVehicle.uniqueId) then
        return false, "An active loan already exists for this vehicle."
    end

    local eligible, reason = self:isEligibleForFinancing()

    if not eligible then
        return false, reason
    end

    local annualRate = DealerRelations.Data:getFinanceRate()
    local termMonths = DealerRelations.Data:getFinanceTerm()

    if annualRate == nil or termMonths == nil then
        return false, "Could not determine financing terms."
    end

    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        return false, "Could not find vehicle to determine loan amount."
    end

    local principal = DealerRelations.Data:getDemoPurchasePrice(vehicle.price)

    if principal <= 0 then
        return false, "Vehicle price is not valid for financing."
    end

    local monthlyPayment = self:calculateMonthlyPayment(
        principal,
        annualRate,
        termMonths
    )

    local loan = {
        uniqueId = demoVehicle.uniqueId,
        name = demoVehicle.name,
        brand = demoVehicle.brand,
        xmlFilename = demoVehicle.xmlFilename,
        farmId = g_currentMission.player and g_currentMission.player.farmId or 1,

        principal = principal,
        remainingPrincipal = principal,
        annualRate = annualRate,
        termMonths = termMonths,
        remainingMonths = termMonths,
        monthlyPayment = monthlyPayment,

        missCount = 0,
        missNoticeSent = false,

        originationMonth = g_currentMission.environment.currentPeriod,
        originationYear = g_currentMission.environment.currentYear,
        monthsSinceLastBoost = 0,
    }

    DealerRelations.Data:addActiveLoan(loan)

    -- Mark vehicle as owned and apply origination confidence.
    demoVehicle.state = "OWNED"
    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.FINANCE_ORIGINATION_CONFIDENCE,
        "Loan originated for " .. tostring(demoVehicle.name)
    )

    DealerRelations.log(string.format(
        "Loan originated: uniqueId=%s name=%s principal=%d rate=%.2f term=%d payment=%d",
        tostring(loan.uniqueId),
        tostring(loan.name),
        loan.principal,
        loan.annualRate,
        loan.termMonths,
        loan.monthlyPayment
    ))

    return true, nil
end

-------------------------------------------------------------------------------
-- Monthly Payment Processing
-------------------------------------------------------------------------------

--- Processes all active loan payments for the current month.
--
-- Called at month change before demo offer generation.
-- Loans are processed highest interest rate first.
-- Any loan in missed state after processing blocks demo offer generation.
--
-- @return boolean True if all payments succeeded, false if any were missed.
function DealerRelations.Finance:checkMonthlyLoanPayments()
    local loans = DealerRelations.Data:getActiveLoans()

    if #loans == 0 then
        return true
    end

    -- Sort by annual rate descending (highest rate first).
    table.sort(loans, function(a, b)
        return (a.annualRate or 0) > (b.annualRate or 0)
    end)

    local allPaid = true

    for _, loan in ipairs(loans) do
        local success = self:processLoanPayment(loan)

        if not success then
            allPaid = false
        end
    end

    return allPaid
end

--- Attempts to process a single monthly payment for a loan.
--
-- On success: deducts payment, applies confidence, advances counters.
-- On failure: triggers missed payment ladder.
--
-- @param loan table Loan record to process.
-- @return boolean True if payment succeeded.
function DealerRelations.Finance:processLoanPayment(loan)
    if loan == nil then
        return false
    end

    local farmId = loan.farmId or 1
    local balance = g_currentMission:getMoney(farmId)

    if balance >= loan.monthlyPayment then
        -- Payment succeeds.
        g_currentMission:addMoney(
            -loan.monthlyPayment,
            farmId,
            MoneyType.SHOP_VEHICLE_BUY,
            true,
            true
        )

        loan.remainingPrincipal = math.max(
            0,
            loan.remainingPrincipal - self:calculatePrincipalPortion(loan)
        )
        loan.remainingMonths = loan.remainingMonths - 1
        loan.missCount = 0
        loan.missNoticeSent = false

        DealerRelations.Data:addConfidence(
            DealerRelations.CONSTANTS.FINANCE_ONTIME_CONFIDENCE,
            "Monthly loan payment made for " .. tostring(loan.name)
        )

        self:checkAnnualConfidenceBoost(loan)

        -- Loan fully repaid.
        if loan.remainingMonths <= 0 or loan.remainingPrincipal <= 0 then
            self:closeLoan(loan, false)
        end

        return true
    else
        -- Payment fails.
        self:advanceMissLadder(loan)
        return false
    end
end

--- Calculates the principal portion of the current monthly payment.
--
-- Rationale:
-- Monthly payment covers both interest and principal. Only the principal
-- portion reduces the remaining balance.
--
-- @param loan table Loan record.
-- @return number Principal portion of the current monthly payment.
function DealerRelations.Finance:calculatePrincipalPortion(loan)
    local monthlyRate = loan.annualRate / 12
    local interestPortion = loan.remainingPrincipal * monthlyRate

    return math.max(0, loan.monthlyPayment - interestPortion)
end

--- Checks whether the annual confidence boost should fire for a loan.
--
-- Fires once per in-game year per loan while in good standing.
-- Does not fire if the loan has any missed payments.
--
-- @param loan table Loan record.
function DealerRelations.Finance:checkAnnualConfidenceBoost(loan)
    if (loan.missCount or 0) > 0 then
        return
    end

    loan.monthsSinceLastBoost = (loan.monthsSinceLastBoost or 0) + 1

    if loan.monthsSinceLastBoost >= 12 then
        loan.monthsSinceLastBoost = 0

        DealerRelations.Data:addConfidence(
            DealerRelations.CONSTANTS.FINANCE_ANNUAL_CONFIDENCE,
            "Annual on-time payment boost for " .. tostring(loan.name)
        )
    end
end

-------------------------------------------------------------------------------
-- Missed Payment Ladder
-------------------------------------------------------------------------------

--- Advances the miss ladder for a loan and applies consequences.
--
-- Miss counter increments on each failed payment.
-- Miss 4 triggers repossession and clears the loan.
--
-- @param loan table Loan record.
function DealerRelations.Finance:advanceMissLadder(loan)
    if loan == nil then
        return
    end

    local constants = DealerRelations.CONSTANTS

    loan.missCount = (loan.missCount or 0) + 1
    loan.missNoticeSent = false

    DealerRelations.Data:incrementTotalMissedPayments()

    DealerRelations.log(string.format(
        "Loan miss ladder advanced: uniqueId=%s missCount=%d",
        tostring(loan.uniqueId),
        loan.missCount
    ))

    if loan.missCount == 1 then
        self:applyMiss1(loan)
    elseif loan.missCount == 2 then
        self:applyMiss2(loan)
    elseif loan.missCount == 3 then
        self:applyMiss3(loan)
    elseif loan.missCount >= 4 then
        self:applyMiss4(loan)
    end
end

--- Applies Miss 1 consequences: confidence penalty and notification.
--
-- @param loan table Loan record.
function DealerRelations.Finance:applyMiss1(loan)
    local constants = DealerRelations.CONSTANTS

    DealerRelations.Data:addConfidence(
        constants.FINANCE_MISS_1_CONFIDENCE,
        "Missed loan payment (Miss 1) for " .. tostring(loan.name)
    )

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        string.format(
            "Dealer Relations: Missed payment on %s. Your relationship has been affected.",
            tostring(loan.name)
        )
    )

    loan.missNoticeSent = true
end

--- Applies Miss 2 consequences: confidence penalty, late fee, term extension.
--
-- @param loan table Loan record.
function DealerRelations.Finance:applyMiss2(loan)
    local constants = DealerRelations.CONSTANTS

    DealerRelations.Data:addConfidence(
        constants.FINANCE_MISS_2_CONFIDENCE,
        "Missed loan payment (Miss 2) for " .. tostring(loan.name)
    )

    self:applyLateFee(loan)

    loan.remainingMonths = loan.remainingMonths + 1

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        string.format(
            "Dealer Relations: Second missed payment on %s. Late fee charged, loan extended.",
            tostring(loan.name)
        )
    )

    loan.missNoticeSent = true
end

--- Applies Miss 3 consequences: confidence penalty, late fee, term extension.
--
-- @param loan table Loan record.
function DealerRelations.Finance:applyMiss3(loan)
    local constants = DealerRelations.CONSTANTS

    DealerRelations.Data:addConfidence(
        constants.FINANCE_MISS_3_CONFIDENCE,
        "Missed loan payment (Miss 3) for " .. tostring(loan.name)
    )

    self:applyLateFee(loan)

    loan.remainingMonths = loan.remainingMonths + 1

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        string.format(
            "Dealer Relations: Third missed payment on %s. Late fee charged, loan extended.",
            tostring(loan.name)
        )
    )

    loan.missNoticeSent = true
end

--- Applies Miss 4 consequences: confidence penalty and repossession.
--
-- @param loan table Loan record.
function DealerRelations.Finance:applyMiss4(loan)
    local constants = DealerRelations.CONSTANTS

    DealerRelations.Data:addConfidence(
        constants.FINANCE_MISS_4_CONFIDENCE,
        "Missed loan payment (Miss 4) for " .. tostring(loan.name)
    )

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
        string.format(
            "Dealer Relations: Loan on %s has been repossessed.",
            tostring(loan.name)
        )
    )

    self:repossessVehicle(loan)
end

--- Charges a late fee equal to one monthly payment.
--
-- If insufficient funds, applies an additional confidence penalty instead.
--
-- @param loan table Loan record.
function DealerRelations.Finance:applyLateFee(loan)
    local constants = DealerRelations.CONSTANTS
    local farmId = loan.farmId or 1
    local balance = g_currentMission:getMoney(farmId)

    if balance >= loan.monthlyPayment then
        g_currentMission:addMoney(
            -loan.monthlyPayment,
            farmId,
            MoneyType.SHOP_VEHICLE_BUY,
            true,
            true
        )

        DealerRelations.log(string.format(
            "Late fee charged: uniqueId=%s amount=%d",
            tostring(loan.uniqueId),
            loan.monthlyPayment
        ))
    else
        DealerRelations.Data:addConfidence(
            constants.FINANCE_MISS_INSUFFICIENT_FUNDS_CONFIDENCE,
            "Insufficient funds for late fee on " .. tostring(loan.name)
        )

        DealerRelations.log(string.format(
            "Late fee not collected: insufficient funds for uniqueId=%s",
            tostring(loan.uniqueId)
        ))
    end
end

--- Repossesses the vehicle associated with a loan and clears the loan.
--
-- @param loan table Loan record.
function DealerRelations.Finance:repossessVehicle(loan)
    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(loan.uniqueId)

    if vehicle ~= nil then
        DealerRelations.DemoManager:removeDemoVehicle(vehicle)

        DealerRelations.log(string.format(
            "Vehicle repossessed: uniqueId=%s name=%s",
            tostring(loan.uniqueId),
            tostring(loan.name)
        ))
    else
        DealerRelations.log(string.format(
            "Repossession: vehicle not found for uniqueId=%s, clearing loan only.",
            tostring(loan.uniqueId)
        ))
    end

    self:closeLoan(loan, true)
end

--- Closes a loan and updates lifetime statistics.
--
-- @param loan table Loan record to close.
-- @param repossessed boolean True if closed due to repossession.
function DealerRelations.Finance:closeLoan(loan, repossessed)
    if not repossessed then
        DealerRelations.Data:incrementTotalLoansRepaid()

        DealerRelations.log(string.format(
            "Loan repaid: uniqueId=%s name=%s",
            tostring(loan.uniqueId),
            tostring(loan.name)
        ))
    end

    DealerRelations.Data:removeActiveLoanByUniqueId(loan.uniqueId)
end

-------------------------------------------------------------------------------
-- Early Payoff
-------------------------------------------------------------------------------

--- Processes a full early payoff for a loan.
--
-- Deducts remaining principal from farm account.
-- Applies confidence boost on success.
-- Reduces lifetime missed payment count if loan had missed payments.
--
-- @param loan table Loan record to pay off.
-- @return boolean True if payoff succeeded.
-- @return string Reason string if payoff failed, nil otherwise.
function DealerRelations.Finance:processEarlyPayoff(loan)
    if loan == nil then
        return false, "No loan provided."
    end

    local farmId = loan.farmId or 1
    local balance = g_currentMission:getMoney(farmId)

    if balance < loan.remainingPrincipal then
        return false, "Insufficient funds for early payoff."
    end

    g_currentMission:addMoney(
        -loan.remainingPrincipal,
        farmId,
        MoneyType.SHOP_VEHICLE_BUY,
        true,
        true
    )

    DealerRelations.log(string.format(
        "Early payoff processed: uniqueId=%s name=%s amount=%d",
        tostring(loan.uniqueId),
        tostring(loan.name),
        loan.remainingPrincipal
    ))

    -- Partial rehabilitation for loans with missed payment history.
    if (loan.missCount or 0) > 0 then
        DealerRelations.Data:decrementTotalMissedPayments()
    end

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.FINANCE_PAYOFF_CONFIDENCE,
        "Early payoff completed for " .. tostring(loan.name)
    )

    self:closeLoan(loan, false)

    return true, nil
end

-------------------------------------------------------------------------------
-- Passive Confidence Recovery
-------------------------------------------------------------------------------

--- Applies passive monthly confidence recovery while relationship is negative.
--
-- Called at month change before loan payment processing.
-- Recovery stops when confidence reaches zero.
-- Rationale:
-- Prevents permanent dead-end states for players who have fallen into
-- negative relationship territory without being exploitable as a farming
-- strategy — recovery only applies while confidence is below zero.
function DealerRelations.Finance:checkPassiveConfidenceRecovery()
    local confidence = DealerRelations.Data:getConfidence()

    if confidence >= 0 then
        return
    end

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.FINANCE_RECOVERY_CONFIDENCE,
        "Passive monthly confidence recovery"
    )

    DealerRelations.log(string.format(
        "Passive confidence recovery applied: confidence %d -> %d",
        confidence,
        DealerRelations.Data:getConfidence()
    ))
end
