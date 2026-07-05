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

    addConsoleCommand(
        "dr_fillTypeDensities",
        "Dump massPerLiter (raw and kg/L) for LIME, FERTILIZER, and HERBICIDE",
        "consoleCommandFillTypeDensities",
        DealerRelations
    )

    addConsoleCommand(
        "dr_massEligibility",
        "Dump dry mass, capacity, resolved density, and computed HP for all mass-managed candidates",
        "consoleCommandMassEligibility",
        DealerRelations
    )

    addConsoleCommand(
        "dr_husbandryCapacity",
        "Dump MANURE/LIQUIDMANURE/STRAW capacity and fill level for all owned husbandry placeables",
        "consoleCommandHusbandryCapacity",
        DealerRelations
    )

    addConsoleCommand(
        "dr_animalCategoryCount",
        "Counts total discovered candidates (regardless of eligibility)",
        "consoleCommandAnimalCategoryCount",
        DealerRelations
    )
    
    addConsoleCommand(
        "dr_headerHarvesterMatch",
        "Dump raw combination xmlFilenames and configFileNames for owned/candidate headers and harvesters",
        "consoleCommandHeaderHarvesterMatch",
        DealerRelations
    )

    addConsoleCommand(
        "dr_headerHarvesterEligibility",
        "Dump comboMatch/hpMatch/displayPower for all discovered header/harvester candidates",
        "consoleCommandHeaderHarvesterEligibility",
        DealerRelations
    )

    addConsoleCommand(
        "dr_testXmlFileLoad",
        "Compare raw XML read vs XMLFile.load (parentFile-aware?) for a given file/path",
        "consoleCommandTestXmlFileLoad",
        DealerRelations,
        "[xmlFilename] [path]"
    )

    addConsoleCommand(
        "dr_trailerFallback",
        "Show which trailer (combo or width/length fallback) each header resolves to",
        "consoleCommandTrailerFallback",
        DealerRelations,
        "[headerXmlFilename]"
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

-------------------------------------------------------------------------------
-- Dumps massPerLiter for LIME, FERTILIZER, and HERBICIDE, both as stored at
-- runtime and unscaled back to kg/L.
--
-- GDN source (FillTypeDesc:loadFromXMLFile) shows massPerLiter is read from
-- XML then multiplied by 0.001 on load:
--   self.massPerLiter = xmlFile:getValue(key..".physics#massPerLiter", ...) * 0.001
-- The XML attribute itself is kg/L (confirmed: lime = 1.2 in this mod's
-- fillTypes.xml). This means g_fillTypeManager:getFillTypeByName(name)
-- .massPerLiter is NOT directly usable as kg/L at runtime — it must be
-- multiplied back by 1000. This command exists to confirm that live,
-- rather than trust the source read alone.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandFillTypeDensities()
    if g_fillTypeManager == nil then
        return "dr_fillTypeDensities: g_fillTypeManager unavailable"
    end

    local namesToCheck = { "LIME", "FERTILIZER", "HERBICIDE" }

    for _, fillTypeName in ipairs(namesToCheck) do
        local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)

        if fillType == nil then
            print(string.format("[DealerRelations] FillType '%s' not found", fillTypeName))
        else
            local raw = fillType.massPerLiter
            local unscaled = raw ~= nil and (raw * 1000) or nil

            print(string.format(
                "[DealerRelations] FillType='%s' massPerLiter(raw)=%s massPerLiter(x1000, expected kg/L)=%s",
                fillTypeName,
                tostring(raw),
                tostring(unscaled)
            ))
        end
    end

    return "dr_fillTypeDensities: checked LIME, FERTILIZER, HERBICIDE"
end

-------------------------------------------------------------------------------
-- Dumps dry mass, max capacity, resolved fill-type density, and computed
-- required HP for every discovered SPRAYERS/FERTILIZERSPREADERS candidate.
--
-- Independently re-reads XML and recomputes rather than trusting the
-- cached candidate.displayPower alone -- if the two disagree, that points
-- to a real bug in resolveDemoCandidate()'s wiring, not just a value to
-- eyeball. Requires discover() to have already run (equipmentList
-- populated) -- run after a save has loaded.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandMassEligibility()
    if DealerRelations.equipmentList == nil or #DealerRelations.equipmentList == 0 then
        return "dr_massEligibility: equipmentList unavailable -- has discover() run yet?"
    end

    local count = 0

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        if DealerRelations.Equipment.MASS_MANAGED_CATEGORIES[candidate.category] == true then
            count = count + 1

            if candidate.powerRole == "SELF_PROPELLED" then
                print(string.format(
                    "[DealerRelations] name='%s' category=%s SELF_PROPELLED -- mass formula not applied, real engine HP=%s",
                    tostring(candidate.name),
                    tostring(candidate.category),
                    tostring(candidate.displayPower)
                ))
            else
                local xmlData = DealerRelations.Equipment:readEquipmentXml(candidate.xmlFilename, candidate.category)
                local dryMass = xmlData ~= nil and xmlData.dryMass or nil
                local maxCapacity = xmlData ~= nil and xmlData.maxCapacity or nil
                local density = xmlData ~= nil
                    and DealerRelations.Equipment:getMaxFillTypeDensity(xmlData.fillTypeNames)
                    or nil
                local recomputedPower = xmlData ~= nil
                    and DealerRelations.Equipment:getMassBasedRequiredPower(dryMass, maxCapacity, xmlData.fillTypeNames)
                    or nil

                local fillTypeList = {}
                if xmlData ~= nil and xmlData.fillTypeNames ~= nil then
                    for name in pairs(xmlData.fillTypeNames) do
                        table.insert(fillTypeList, name)
                    end
                end

                print(string.format(
                    "[DealerRelations] name='%s' category=%s dryMass=%s maxCapacity=%s density=%s fillTypes=%s recomputedHP=%s cachedHP=%s",
                    tostring(candidate.name),
                    tostring(candidate.category),
                    tostring(dryMass),
                    tostring(maxCapacity),
                    tostring(density),
                    table.concat(fillTypeList, ","),
                    tostring(recomputedPower),
                    tostring(candidate.displayPower)
                ))
            end
        end
    end

    if count == 0 then
        return "dr_massEligibility: no mass-managed candidates found -- check MASS_MANAGED_CATEGORIES / DEFAULT_CATEGORY_FILTERS migration"
    end

    return string.format("dr_massEligibility: checked %d mass-managed candidate(s)", count)
end

-------------------------------------------------------------------------------
-- Dumps MANURE, LIQUIDMANURE, and STRAW capacity and current fill level for
-- every farm-owned husbandry placeable. Temporary -- used to verify whether
-- MANURE capacity going from 0 to nonzero actually reflects a manure heap
-- being linked as a storage extension (inferred from the
-- "info_husbandryMissingManureHeap" string in PlaceableHusbandryStraw's
-- getConditionInfos(), but not yet confirmed against a live placeable with
-- and without a heap connected).
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandHusbandryCapacity()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil then
        return "dr_husbandryCapacity: placeableSystem unavailable"
    end

    local farmId = g_currentMission:getFarmId()
    local namesToCheck = { "MANURE", "LIQUIDMANURE", "STRAW" }
    local count = 0

    for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
        if placeable.spec_husbandry ~= nil and placeable:getOwnerFarmId() == farmId then
            count = count + 1

            print(string.format(
                "[DealerRelations] placeable='%s' hasStraw=%s",
                tostring(placeable.configFileName),
                tostring(placeable.spec_husbandryStraw ~= nil)
            ))

            for _, fillTypeName in ipairs(namesToCheck) do
                local fillTypeIndex = g_fillTypeManager ~= nil
                    and g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
                    or nil

                if fillTypeIndex == nil then
                    print(string.format("[DealerRelations]   %s: fill type not found", fillTypeName))
                else
                    local capacity = placeable:getHusbandryCapacity(fillTypeIndex, farmId)
                    local fillLevel = placeable:getHusbandryFillLevel(fillTypeIndex, farmId)

                    print(string.format(
                        "[DealerRelations]   %s: capacity=%s fillLevel=%s",
                        fillTypeName,
                        tostring(capacity),
                        tostring(fillLevel)
                    ))
                end
            end
        end
    end

    if count == 0 then
        return "dr_husbandryCapacity: no owned husbandry placeables found"
    end

    return string.format("dr_husbandryCapacity: checked %d husbandry placeable(s) -- see log", count)
end

-------------------------------------------------------------------------------
-- Counts total discovered candidates (regardless of eligibility) for each
-- ANIMAL_CATEGORIES category. Temporary -- used to distinguish "no items in
-- this category exist in equipmentList" from "isAnimalEligible() is
-- returning false when it shouldn't."
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandAnimalCategoryCount()
    local countByCategory = {}

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        if DealerRelations.Equipment.ANIMAL_CATEGORIES[candidate.category] ~= nil then
            countByCategory[candidate.category] = (countByCategory[candidate.category] or 0) + 1
        end
    end

    for category in pairs(DealerRelations.Equipment.ANIMAL_CATEGORIES) do
        print(string.format(
            "[DealerRelations] %s: %d discovered (eligible=%s)",
            category,
            countByCategory[category] or 0,
            tostring(DealerRelations.Equipment:isAnimalEligible(category))
        ))
    end

    return "dr_animalCategoryCount: see log"
end

-------------------------------------------------------------------------------
-- Dumps raw combinationXmlFilenames and xmlFilename/configFileName values
-- for every owned harvester/header and every discovered header/harvester
-- candidate. Temporary -- used to diagnose why isCombinationMatch() is
-- returning false across the board (see dr_eligibleCount-adjacent testing,
-- 0.21.0 header/harvester session): the derived comboMatch/hpMatch booleans
-- don't show *why* a match fails, only that it did. This prints the actual
-- strings being compared so a path/case mismatch is visible directly rather
-- than inferred.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandHeaderHarvesterMatch()
    if DealerRelations.equipmentList == nil or #DealerRelations.equipmentList == 0 then
        return "dr_headerHarvesterMatch: equipmentList unavailable -- has discover() run yet?"
    end

    print("[DealerRelations] === Owned harvesters/headers ===")

    if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil
        and g_currentMission.vehicleSystem.vehicles ~= nil then

        for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
            local entry = DealerRelations.equipmentByXmlFilename[vehicle.configFileName]

            if entry ~= nil
                and (DealerRelations.Equipment.HARVESTER_CATEGORIES[entry.category] == true
                    or DealerRelations.Equipment.HEADER_CATEGORIES[entry.category] == true) then

                print(string.format(
                    "[DealerRelations] OWNED name='%s' category=%s configFileName='%s' xmlFilename='%s'",
                    tostring(entry.name),
                    tostring(entry.category),
                    tostring(vehicle.configFileName),
                    tostring(entry.xmlFilename)
                ))

                if entry.combinationXmlFilenames == nil or #entry.combinationXmlFilenames == 0 then
                    print("[DealerRelations]   combinationXmlFilenames: (none)")
                else
                    for _, comboFilename in ipairs(entry.combinationXmlFilenames) do
                        print(string.format("[DealerRelations]   combinationXmlFilenames: '%s'", tostring(comboFilename)))
                    end
                end
            end
        end
    end

    print("[DealerRelations] === Discovered header/harvester candidates ===")

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        if DealerRelations.Equipment.HARVESTER_CATEGORIES[candidate.category] == true
            or DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true then

            print(string.format(
                "[DealerRelations] CANDIDATE name='%s' category=%s xmlFilename='%s'",
                tostring(candidate.name),
                tostring(candidate.category),
                tostring(candidate.xmlFilename)
            ))

            if candidate.combinationXmlFilenames == nil or #candidate.combinationXmlFilenames == 0 then
                print("[DealerRelations]   combinationXmlFilenames: (none)")
            else
                for _, comboFilename in ipairs(candidate.combinationXmlFilenames) do
                    print(string.format("[DealerRelations]   combinationXmlFilenames: '%s'", tostring(comboFilename)))
                end
            end
        end
    end

    return "dr_headerHarvesterMatch: see log"
end

-------------------------------------------------------------------------------
-- Dumps comboMatch, hpMatch, and displayPower for every discovered header/
-- harvester candidate, recomputing the same signals isCurrentlyEligible()
-- uses rather than reading a cached decision. Temporary -- used to verify
-- the combo/HP eligibility gate in isolation, without needing to trigger a
-- full isCurrentlyEligible() pass across every category via dr_eligibleCount.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandHeaderHarvesterEligibility()
    if DealerRelations.equipmentList == nil or #DealerRelations.equipmentList == 0 then
        return "dr_headerHarvesterEligibility: equipmentList unavailable -- has discover() run yet?"
    end

    local count = 0

    for _, candidate in ipairs(DealerRelations.equipmentList) do
        local comboMatch, hpMatch

        if DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true then
            comboMatch = DealerRelations.Equipment:isCombinationMatchedToOwnedCategory(candidate, DealerRelations.Equipment.HARVESTER_CATEGORIES)
            hpMatch = candidate.displayPower ~= nil
                and candidate.displayPower <= DealerRelations.Equipment:getOwnedMaxHarvesterPower()
        elseif DealerRelations.Equipment.HARVESTER_CATEGORIES[candidate.category] == true then
            comboMatch = DealerRelations.Equipment:isCombinationMatchedToOwnedCategory(candidate, DealerRelations.Equipment.HEADER_CATEGORIES)
            hpMatch = candidate.displayPower ~= nil
                and candidate.displayPower >= DealerRelations.Equipment:getOwnedMaxHeaderRequiredPower()
        end

        if comboMatch ~= nil then
            count = count + 1

            print(string.format(
                "[DealerRelations] name='%s' category=%s displayPower=%s comboMatch=%s hpMatch=%s",
                tostring(candidate.name),
                tostring(candidate.category),
                tostring(candidate.displayPower),
                tostring(comboMatch),
                tostring(hpMatch)
            ))
        end
    end

    if count == 0 then
        return "dr_headerHarvesterEligibility: no header/harvester candidates found"
    end

    return string.format("dr_headerHarvesterEligibility: checked %d candidate(s) -- see log", count)
end

-------------------------------------------------------------------------------
-- Compares two ways of reading an XML value: the raw loadXMLFile/getXMLString
-- mechanism readEquipmentXml() currently uses, versus XMLFile.load() with a
-- minimal schema -- the mechanism Vehicle:load() actually uses at runtime
-- (self.xmlFile = XMLFile.load("vehicleXML", self.configFileName,
-- Vehicle.xmlSchema)). Temporary -- exists to determine whether
-- XMLFile.load() transparently resolves <parentFile>/<set> rebadge
-- inheritance (confirmed present in af11.xml, pointing at cr11.xml) before
-- deciding how to fix the af11-style displayPower=nil gap.
--
-- @param xmlFilename string Resolved path, e.g.
--        "data/vehicles/caseIH/af11/af11.xml" (no leading "$", matching the
--        format already confirmed working via candidate.xmlFilename).
-- @param path string Optional XML path to test. Defaults to
--        "vehicle.storeData.specs.power".
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandTestXmlFileLoad(xmlFilename, path)
    if xmlFilename == nil or xmlFilename == "" then
        return "dr_testXmlFileLoad: usage: dr_testXmlFileLoad [xmlFilename] [path] -- e.g. dr_testXmlFileLoad data/vehicles/caseIH/af11/af11.xml vehicle.storeData.specs.power"
    end

    path = path or "vehicle.storeData.specs.power"

    -- Raw read: same mechanism readEquipmentXml() uses today.
    local rawResult
    local rawXmlFile = loadXMLFile("dealerRelationsTestRawXML", xmlFilename)

    if rawXmlFile ~= nil and rawXmlFile ~= 0 then
        rawResult = tostring(getXMLString(rawXmlFile, path))
        delete(rawXmlFile)
    else
        rawResult = "FAILED TO LOAD"
    end

    -- Resolved read: XMLFile.load() with a minimal one-path schema, root
    -- node name forced to "vehicle" to match the actual root element
    -- (mirrors Vehicle.xmlSchemaSounds needing an explicit setRootNodeName
    -- when its schema name doesn't match the file's root tag).
    local resolvedResult
    local testSchema = XMLSchema.new("dealerRelationsTestSchema")
    testSchema:setRootNodeName("vehicle")
    testSchema:register(XMLValueType.STRING, path, "Test value")

    local resolvedXmlFile = XMLFile.load("dealerRelationsTestResolvedXML", xmlFilename, testSchema)

    if resolvedXmlFile ~= nil then
        resolvedResult = tostring(resolvedXmlFile:getValue(path))
        resolvedXmlFile:delete()
    else
        resolvedResult = "FAILED TO LOAD"
    end

    print(string.format("[DealerRelations] xmlFilename='%s' path='%s'", tostring(xmlFilename), tostring(path)))
    print(string.format("[DealerRelations]   raw (loadXMLFile/getXMLString): %s", rawResult))
    print(string.format("[DealerRelations]   resolved (XMLFile.load):        %s", resolvedResult))

    return "dr_testXmlFileLoad: see log"
end

-------------------------------------------------------------------------------
-- Shows which trailer (if any) each header resolves to, and whether it came
-- from a combo match or the width/length fallback. Mirrors
-- getCompatibleTrailerForHeader()'s two-phase logic independently rather
-- than modifying its signature, so the match path and actual dimension
-- values are visible for verification.
--
-- Foldable headers (isFoldable) never need a trailer at all -- mirrors
-- the isFoldable ~= true guard in isCurrentlyEligible() and
-- createDemoOfferFromCandidate(). Reported separately rather than run
-- through the combo/fallback check at all, since production code never
-- calls getCompatibleTrailerForHeader() for these.
--
-- @param headerXmlFilename string|nil If given, checks only that header
--        (matched by exact xmlFilename, e.g. "powerFlow.xml"). If omitted,
--        checks every discovered HEADER_CATEGORIES candidate.
-------------------------------------------------------------------------------
function DealerRelations:consoleCommandTrailerFallback(headerXmlFilename)
    if DealerRelations.equipmentList == nil or #DealerRelations.equipmentList == 0 then
        return "dr_trailerFallback: equipmentList unavailable -- has discover() run yet?"
    end

    local headersToCheck = {}

    if headerXmlFilename ~= nil and headerXmlFilename ~= "" then
        for _, candidate in ipairs(DealerRelations.equipmentList) do
            if candidate.xmlFilename == headerXmlFilename then
                table.insert(headersToCheck, candidate)
            end
        end

        if #headersToCheck == 0 then
            return string.format("dr_trailerFallback: no candidate found with xmlFilename '%s'", tostring(headerXmlFilename))
        end
    else
        for _, candidate in ipairs(DealerRelations.equipmentList) do
            if DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true then
                table.insert(headersToCheck, candidate)
            end
        end
    end

    for _, header in ipairs(headersToCheck) do
        local headerWidth = header.sizeWidth or header.workingWidth

        print(string.format(
            "[DealerRelations] HEADER name='%s' xmlFilename='%s' isFoldable=%s sizeWidth=%s workingWidth=%s (usedWidth=%s)",
            tostring(header.name),
            tostring(header.xmlFilename),
            tostring(header.isFoldable),
            tostring(header.sizeWidth),
            tostring(header.workingWidth),
            tostring(headerWidth)
        ))

        if header.isFoldable == true then
            print("[DealerRelations]   NO TRAILER NEEDED: header folds for road travel")
        else
            -- Combo check (mirrors getCompatibleTrailerForHeader's first pass).
            local comboTrailer = nil

            for _, candidate in ipairs(DealerRelations.equipmentList) do
                if candidate.category == "CUTTERTRAILERS" then
                    if DealerRelations.Equipment:isCombinationMatch(header, candidate) then
                        comboTrailer = candidate
                        break
                    end
                end
            end

            if comboTrailer ~= nil then
                print(string.format(
                    "[DealerRelations]   MATCH via combo: '%s' sizeLength=%s",
                    tostring(comboTrailer.name),
                    tostring(comboTrailer.sizeLength)
                ))
            elseif headerWidth == nil then
                print("[DealerRelations]   NO MATCH: header has no sizeWidth or workingWidth to fall back on")
            else
                -- Fallback check (mirrors getCompatibleTrailerForHeader's second pass).
                local bestTrailer = nil

                for _, candidate in ipairs(DealerRelations.equipmentList) do
                    if candidate.category == "CUTTERTRAILERS"
                        and candidate.sizeLength ~= nil
                        and candidate.sizeLength >= headerWidth then

                        if bestTrailer == nil or candidate.sizeLength < bestTrailer.sizeLength then
                            bestTrailer = candidate
                        end
                    end
                end

                if bestTrailer ~= nil then
                    print(string.format(
                        "[DealerRelations]   MATCH via fallback: '%s' sizeLength=%s (smallest trailer >= %s)",
                        tostring(bestTrailer.name),
                        tostring(bestTrailer.sizeLength),
                        tostring(headerWidth)
                    ))
                else
                    print(string.format(
                        "[DealerRelations]   NO MATCH: no trailer found with sizeLength >= %s",
                        tostring(headerWidth)
                    ))
                end
            end
        end
    end

    return string.format("dr_trailerFallback: checked %d header(s) -- see log", #headersToCheck)
end