-------------------------------------------------------------------------------
-- DealerRelations.lua
--
-- Main entry point for the Dealer Relations mod.
--
-- Responsibilities:
--   * Load supporting modules
--   * Register mod event listeners
--   * Coordinate initialization
--
-- This file should remain small and primarily act as the
-- orchestration layer for the mod.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}

-- Current mod version displayed in startup logging.
DealerRelations.version = "0.24.0"

-- Store the mod directory for later runtime use.
-- Rationale: g_currentModDirectory is available while sourcing files,
-- but may not be reliable later inside loadMap().
DealerRelations.directory = g_currentModDirectory

-------------------------------------------------------------------------------
-- Load supporting modules.
--
-- These files are loaded here rather than in modDesc.xml to keep
-- modDesc compact and centralize module dependencies.
-------------------------------------------------------------------------------
source(g_currentModDirectory .. "scripts/DealerRelationsDebug.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsUtils.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsData.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsPersistence.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsEquipment.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsCrops.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsUI.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsScreen.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsHelpDialog.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsOverviewPanel.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsFinancingPanel.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsDemoManager.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsFinance.lua")

-------------------------------------------------------------------------------
-- Called by the game when a map is loaded.
--
-- Registers Dealer Relations callbacks, loads persisted data,
-- discovers eligible equipment, and restores any active offer notice.
-------------------------------------------------------------------------------
function DealerRelations:loadMap()
    DealerRelations.log("Version " .. DealerRelations.version .. " loaded")

    -- Register a callback that will be invoked whenever the game saves.
    -- This allows Dealer Relations data to be persisted alongside the
    -- normal Farming Simulator save process.
    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        DealerRelations.saveSavegame
    )
    
    -- Load static dealer name options before persistence.
    -- Rationale:
    -- New saves assign a random dealer name during persistence load when no
    -- dealerRelations.xml exists yet, so the configured names must already be
    -- available.
    DealerRelations.Data:loadDealerNames()

    -- Load persisted Dealer Relations data from the active savegame.
    -- If no data exists, default values remain in use.
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        DealerRelations.Persistence:load(g_currentMission.missionInfo.savegameDirectory)
    end

    -- Build the eligible equipment list.
    DealerRelations.Equipment:discover()

    -- Populate crop history from currently planted fields.
    -- Rationale:
    -- Captures the map's starting crop rotation on first load so early
    -- demo offers can already account for crops the player didn't choose.
    DealerRelations.Crops:scanCropSources()

    -- Validate active offer and demo against current store manager.
    -- Rationale:
    -- Mods providing offered or demoed equipment may have been removed since
    -- the last session. Invalid entries are cleared silently at load time.
    DealerRelations:validateActiveDemoOffer()
    DealerRelations.DemoManager:validateActiveDemo()
    
    -- Register the Dealer Relations page with the ESC menu.
    -- Rationale:
    -- This creates the screen instance, registers the page and tab,
    -- and initializes the Dealer Relations user interface.
    DealerRelations.Screen:register()
    DealerRelations.HelpDialog.register()

    DealerRelations.registerConsoleCommands()
    
    DealerRelations.UI:notifyModDisabled()
    DealerRelations.UI:notifyRelationshipStatus()
    
    -- Remind the player about a carried-over offer on load.
    -- Rationale:
    -- Only notify on load if the offer was already announced in a previous session.
    -- New offers are handled by checkActiveDemoOfferNotification() at dealer open.
    local existingOffer = DealerRelations.Data:getActiveDemoOffer()
    if existingOffer ~= nil and existingOffer.offerNotificationSent == true then
        DealerRelations.UI:notifyActiveDemoOfferAvailable()
    end
end

-------------------------------------------------------------------------------
-- Called during the game's save process.
--
-- Persists Dealer Relations data to the active savegame directory.
-------------------------------------------------------------------------------
function DealerRelations.saveSavegame()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        DealerRelations.warning("Cannot save: missionInfo is nil")
        return
    end

    local savegameDirectory = g_currentMission.missionInfo.savegameDirectory

    DealerRelations.Persistence:save(savegameDirectory)

    DealerRelations.log("Saved dealerRelations.xml")
end

-------------------------------------------------------------------------------
-- Monthly Demo Check
-------------------------------------------------------------------------------

-- Checks whether a monthly demo evaluation should occur and creates a new offer.
function DealerRelations:checkMonthlyDemo()
    -- currentPeriod increments each period change and functions as a
    -- monotonic month counter. Used here to detect when a new month
    -- has started rather than as a calendar month value.
    local currentMonth = g_currentMission.environment.currentPeriod
    local lastMonth = DealerRelations.Data:getLastDemoCheckMonth()

    if currentMonth ~= lastMonth then
        DealerRelations.Data:setLastDemoCheckMonth(currentMonth)

        -- Process passive confidence recovery before loan payments.
        DealerRelations.Finance:checkPassiveConfidenceRecovery()

        -- Rescan owned fields for new crops each month.
        -- Rationale:
        -- Crop history should keep accumulating even while Dealer Relations
        -- is disabled, consistent with loan aging continuing regardless of
        -- the enabled setting.
         DealerRelations.Crops:scanCropSources()

        -- Process monthly loan payments before demo offer generation.
        -- Rationale:
        -- Payment state gates new demo offers. Loans must be processed first
        -- so hasOverdueLoans() reflects the current month when the offer
        -- check runs.
        local allPaid = DealerRelations.Finance:checkMonthlyLoanPayments()

        if not allPaid then
            DealerRelations.log(
                "Monthly demo offer skipped: one or more loan payments missed"
            )
        end

        -- Existing active demos must continue to age/expire even when the mod is
        -- disabled, otherwise the player can become stuck with a demo they cannot
        -- return or buy.
        DealerRelations.DemoManager:checkExpiredDemos()

        -- Dealer Relations may be disabled by player settings.
        --
        -- Rationale:
        -- Disabled blocks new monthly activity, but does not freeze existing demo
        -- obligations or delete existing state.
        if not DealerRelations.Data:isEnabled() then
            DealerRelations.log(
                "Monthly demo offer skipped: Dealer Relations is disabled"
            )
            return
        end

        self:expireDemoOffer(currentMonth)

        -- Prevent new demo offers while the player still has a demo that
        -- has not been returned or purchased.
        if DealerRelations.Data:hasOpenDemo() then
            DealerRelations.log(
                "Monthly demo offer skipped: an open demo already exists"
            )
            return
        end

        -- Prevent new demo offers while the player is under a demo suspension.
        if DealerRelations.Data:isUnderSuspension() then
            DealerRelations.log(
                "Monthly demo offer skipped: player is under demo suspension"
            )
            return
        end

        -- Prevent new demo offers while any loan has missed payments.
        if DealerRelations.Data:hasOverdueLoans() then
            DealerRelations.log(
                "Monthly demo offer skipped: active loan in missed state"
            )
            return
        end

        DealerRelations.log(string.format(
            "Monthly demo check triggered for month %d",
            currentMonth
        ))

        local candidate = DealerRelations.Equipment:getRandomDemoCandidate()

        if candidate == nil then
            DealerRelations.warning("Monthly demo check did not select a candidate")
            return
        end

        DealerRelations.Data:setActiveDemoOffer(
            self:createDemoOfferFromCandidate(candidate, currentMonth)
        )

        DealerRelations.log(string.format(
            "Demo offer created: %s | Brand=%s | Category=%s | HP=%s",
            candidate.name,
            candidate.brand,
            candidate.category,
            tostring(candidate.displayPower or "Unknown")
        ))
    end
end

-- Builds the saved demo offer data from a selected equipment candidate.
-- Rationale: checkMonthlyDemo() should decide when an offer is created;
-- this helper owns the structure of the offer data that gets persisted.
--
-- Headers carry a companion trailer unless they're foldable (see
-- isFoldable -- a foldable header travels the road on its own and never
-- needed one). Slurry tanks always carry a companion tool. Seeders/planters
-- carry a companion tank whenever a combo match exists, but never require
-- one. All attached here as flat "companion*" fields rather than a nested
-- table, matching the existing flat-field convention already used for the
-- primary vehicle and in DealerRelationsPersistence.lua.
function DealerRelations:createDemoOfferFromCandidate(candidate, currentMonth)
    local offer = {
        candidateKey = DealerRelations.Equipment:getDemoCandidateKey(candidate),
        name = candidate.name,
        brand = candidate.brand,
        category = candidate.category,
        price = candidate.price,
        xmlFilename = candidate.xmlFilename,
        powerRole = candidate.powerRole,
        displayPower = candidate.displayPower,
        powerMin = candidate.powerMin,
        powerMax = candidate.powerMax,
        offerMonth = currentMonth,

        -- Tracks whether the player has been notified about this offer.
        -- Rationale:
        -- Offers are generated at month change, but the player-facing notice
        -- should wait until the dealer opens.
        offerNotificationSent = false,
    }

    local companion = nil

    if DealerRelations.Equipment.HEADER_CATEGORIES[candidate.category] == true
        and candidate.isFoldable ~= true then
        companion = DealerRelations.Equipment:getCompatibleTrailerForHeader(candidate)
    elseif candidate.category == "SLURRYTANKS" then
        companion = DealerRelations.Equipment:getCompatibleToolForTank(candidate)
    elseif candidate.category == "PLANTERS" or candidate.category == "SEEDERS" then
        companion = DealerRelations.Equipment:getCompatibleTankForSeeder(candidate)
    end

    if companion ~= nil then
        offer.companionName = companion.name
        offer.companionBrand = companion.brand
        offer.companionCategory = companion.category
        offer.companionXmlFilename = companion.xmlFilename
        offer.companionPrice = companion.price
    end

    return offer
end

-------------------------------------------------------------------------------
-- Expires the active demo offer if it is from a previous month.
-------------------------------------------------------------------------------
function DealerRelations:expireDemoOffer(currentMonth)
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        return
    end

    if offer.offerMonth ~= currentMonth then
        DealerRelations.log(
            "Demo offer expired: " ..
            tostring(offer.name)
        )

        DealerRelations.Data:addConfidence(
            DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_EXPIRE_OFFER,
            "Demo offer ignored until expiration"
        )

        DealerRelations.Data:clearActiveDemoOffer()
    end
end

-------------------------------------------------------------------------------
-- Expires the active demo offer when the dealer is closed, if the offer
-- was already announced to the player.
--
-- Rationale:
-- Offers are valid for one business day. If the player has not accepted
-- or declined before the dealer closes, the offer expires with a confidence
-- penalty for passive neglect. The offerExpired flag prevents repeated
-- triggering across update ticks while the dealer remains closed.
-------------------------------------------------------------------------------
function DealerRelations:checkOfferExpiration()
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        return
    end

    if offer.offerExpired == true then
        return
    end

    if DealerRelations.Data:isDealerOpen() then
        return
    end

    if offer.offerNotificationSent ~= true then
        return
    end

    DealerRelations.log(
        "Demo offer expired at dealer close: " ..
        tostring(offer.name)
    )

    offer.offerExpired = true

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_EXPIRE_OFFER,
        "Demo offer ignored until dealer close"
    )

    DealerRelations.Data:clearActiveDemoOffer()
end

-------------------------------------------------------------------------------
-- Notifies the player about a pending demo offer once the dealer opens.
--
-- Rationale:
-- Offers are generated at month change, but player-facing notification
-- should wait until business hours so the player can act immediately.
-------------------------------------------------------------------------------
function DealerRelations:checkActiveDemoOfferNotification()
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        return
    end

    if offer.offerNotificationSent == true then
        return
    end

    if not DealerRelations.Data:isDealerOpen() then
        return
    end

    DealerRelations.UI:notifyActiveDemoOfferAvailable()
    offer.offerNotificationSent = true
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function DealerRelations:update(dt)
    self:checkMonthlyDemo()
    self:checkActiveDemoOfferNotification()
    self:checkOfferExpiration()

    DealerRelations.DemoManager:checkDemoOperatingHours()
    
    -- Check player-facing demo notices during normal update processing.
    -- These are separate from monthly demo generation because notices are
    -- time-of-day based, not just month-change based.
    DealerRelations.DemoManager:checkEndingDemoNotices()
    DealerRelations.DemoManager:checkReturnDemoNotices()

    DealerRelations.DemoManager:checkOverdueDemos()
end

-------------------------------------------------------------------------------
-- Validates the active demo offer against the current store manager.
--
-- Rationale:
-- If the mod providing the offered equipment has been removed since the last
-- session, the offer can no longer be fulfilled. The offer is cleared silently
-- with no confidence penalty since the player made a mod management decision,
-- not a gameplay decision.
-------------------------------------------------------------------------------
function DealerRelations:validateActiveDemoOffer()
    local offer = DealerRelations.Data:getActiveDemoOffer()
    if offer == nil then return end

    local storeItem = g_storeManager:getItemByXMLFilename(offer.xmlFilename)
    if storeItem == nil then
        DealerRelations.log(string.format(
            "Active offer cleared: source mod no longer available (%s)",
            tostring(offer.xmlFilename)
        ))
        DealerRelations.Data:clearActiveDemoOffer()
    end
end

-------------------------------------------------------------------------------
-- Register Dealer Relations as a mod event listener.
-------------------------------------------------------------------------------
addModEventListener(DealerRelations)