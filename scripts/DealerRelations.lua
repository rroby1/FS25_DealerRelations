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
DealerRelations.version = "0.13.0"

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
source(g_currentModDirectory .. "scripts/DealerRelationsUI.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsScreen.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsDemoManager.lua")

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
    
    -- Register the Dealer Relations page with the ESC menu.
    -- Rationale:
    -- This creates the screen instance, registers the page and tab,
    -- and initializes the Dealer Relations user interface.
    DealerRelations.Screen:register()
    
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
    local currentMonth = g_currentMission.environment.currentPeriod
    local lastMonth = DealerRelations.Data:getLastDemoCheckMonth()

    if currentMonth ~= lastMonth then
        DealerRelations.Data:setLastDemoCheckMonth(currentMonth)

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
-- this helper owns the shape of the offer data that gets persisted.
function DealerRelations:createDemoOfferFromCandidate(candidate, currentMonth)
    return {
        candidateKey = DealerRelations.Equipment:getDemoCandidateKey(candidate),
        name = candidate.name,
        brand = candidate.brand,
        category = candidate.category,
        price = candidate.price,
        xmlFilename = candidate.xmlFilename,
        imageFilename = DealerRelations.Utils:resolveAssetPath(candidate.storeImage),  -- Store image path for Overview display
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
-- Expires the active demo offer at dealer close if still open.
--
-- Rationale:
-- Offers are valid for one business day. If the player has not accepted
-- or declined by dealer close, the offer expires with a confidence penalty
-- for passive neglect.
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

function DealerRelations:checkActiveDemoOfferNotification()
    -- Notify the player about a generated offer only after the dealer opens.
    -- Rationale:
    -- Offers are generated at month change, but player-facing notification
    -- should wait until business hours so the player can act immediately.
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

    -- Check player-facing demo notices during normal update processing.
    -- These are separate from monthly demo generation because notices are
    -- time-of-day based, not just month-change based.
    DealerRelations.DemoManager:checkEndingDemoNotices()
    DealerRelations.DemoManager:checkReturnDemoNotices()
end

-------------------------------------------------------------------------------
-- Register Dealer Relations as a mod event listener.
-------------------------------------------------------------------------------
addModEventListener(DealerRelations)