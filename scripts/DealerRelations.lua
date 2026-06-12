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

-------------------------------------------------------------------------------
-- Demo Lifecycle
--
-- ACTIVE
--     Demo is currently within its evaluation period.
--
-- EXPIRED
--     Demo period has ended. Awaiting player action.
--
-- RETURNED
--     Demo vehicle returned to dealer and removed from game.
--
-- PURCHASED
--     Demo vehicle purchased by player and converted to owned equipment.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}

-- Current mod version displayed in startup logging.
DealerRelations.version = "0.10.0"

-------------------------------------------------------------------------------
-- Load supporting modules.
--
-- These files are loaded here rather than in modDesc.xml to keep
-- modDesc compact and centralize module dependencies.
-------------------------------------------------------------------------------
source(g_currentModDirectory .. "scripts/DealerRelationsDebug.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsData.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsPersistence.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsEquipment.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsUI.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsDemoOfferDialog.lua")
source(g_currentModDirectory .. "scripts/gui/DealerRelationsDemoReturnDialog.lua")
source(g_currentModDirectory .. "scripts/DealerRelationsDemoManager.lua")

-------------------------------------------------------------------------------
-- Called by the game when a map is loaded.
--
-- Registers Dealer Relations callbacks and loads persisted
-- Dealer Relations data from the active savegame.
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

    -- Load persisted Dealer Relations data from the active savegame.
    -- If no data exists, default values remain in use.
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        DealerRelations.Persistence:load(g_currentMission.missionInfo.savegameDirectory)
    end

    -- Build the eligible equipment list.
    DealerRelations.Equipment:discover()
    
    DealerRelations.UI:notifyActiveDemoOfferAvailable()
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

        self:expireDemoOffer(currentMonth)

        -- Update demo vehicle states before deciding whether a new offer
        -- is allowed this month.
        DealerRelations.DemoManager:checkExpiredDemos()

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

        DealerRelations.Data:setActiveDemoOffer({
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
            offerMonth = currentMonth
        })

        DealerRelations.log(string.format(
            "Demo offer created: %s | Brand=%s | Category=%s | HP=%s",
            candidate.name,
            candidate.brand,
            candidate.category,
            tostring(candidate.displayPower or "Unknown")
        ))

        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: The dealer has a demo offer available. Check with the dealer before the end of the month."
        )
    end
end

-------------------------------------------------------------------------------
-- Demo Offer Expiration
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Expires the active demo offer if it is from a previous month.
--
-- Future versions may apply confidence changes when an offer expires.
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

        DealerRelations.Data:clearActiveDemoOffer()
    end
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

function DealerRelations:update(dt)
    self:checkMonthlyDemo()
    
    -- Check player-facing demo notices during normal update processing.
    -- These are separate from monthly demo generation because notices are
    -- time-of-day based, not just month-change based.
    DealerRelations.DemoManager:checkEndingDemoNotices()
    DealerRelations.DemoManager:checkReturnDemoNotices()

    -- TEMP TEST HOOK:
    -- Raw NUMPAD 9 fallback used only while debugging the new-save input binding issue.
    -- Disable this when testing on existing saves because the normal input action also fires,
    -- which causes the dealer dialog to open twice.
    --[[if Input.isKeyPressed(Input.KEY_KP_9) then
        DealerRelations.log("Raw NUMPAD 9 key press detected")
        DealerRelations.UI:onOpenDemoOfferInput()
    end
    ]]

    if not DealerRelations.UI.inputRegistered then
        DealerRelations.UI:registerInput()
    end
end

-------------------------------------------------------------------------------
-- Register Dealer Relations as a mod event listener.
-------------------------------------------------------------------------------
addModEventListener(DealerRelations)