-------------------------------------------------------------------------------
-- DealerRelationsUI.lua
--
-- Handles Dealer Relations user interface functionality.
--
-- Responsibilities:
--   * Demo offer screen
--   * Settings screen
--   * Menu integration
--   * UI-related input handling
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.UI = DealerRelations.UI or {}

DealerRelations.log("DealerRelationsDemoOfferDialog loaded")

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

DealerRelations.UI.inputRegistered = false

-------------------------------------------------------------------------------
-- Input Registration
-------------------------------------------------------------------------------

function DealerRelations.UI:registerInput()
    if InputAction.DR_OPEN_DEMO_OFFER == nil then
        DealerRelations.warning("Cannot register demo offer input: DR_OPEN_DEMO_OFFER is missing")
        return
    end

    local _, actionEventId = g_inputBinding:registerActionEvent(
        InputAction.DR_OPEN_DEMO_OFFER,
        self,
        self.onOpenDemoOfferInput,
        false,
        true,
        false,
        true
    )
    
    DealerRelations.log(string.format(
        "Demo offer actionEventId=%s",
        tostring(actionEventId)
    ))

    g_inputBinding:setActionEventText(actionEventId, "Open Dealer Demo Offer")
    g_inputBinding:setActionEventTextVisibility(actionEventId, false)
    g_inputBinding:setActionEventActive(actionEventId, true)

    self.openDemoOfferActionEventId = actionEventId

    DealerRelations.log("Dealer Relations demo offer input registered")
    self.inputRegistered = true
end

-------------------------------------------------------------------------------
-- Input Callbacks
-------------------------------------------------------------------------------

function DealerRelations.UI:onOpenDemoOfferInput()
     if DealerRelations.Data:hasActiveDemoOffer() then
        self:openActiveDemoOffer()
    else
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: No active demo offer is available."
        )
    end
end

-------------------------------------------------------------------------------
-- Demo Offer Actions
-------------------------------------------------------------------------------

function DealerRelations.UI:acceptActiveDemoOffer()
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        DealerRelations.warning("Cannot accept demo offer: no active offer exists")
        return
    end

    DealerRelations.log(
        "Demo offer accepted: " ..
        tostring(offer.name)
    )
    
    DealerRelations.DemoManager:startDemoFromOffer(offer)
end

function DealerRelations.UI:declineActiveDemoOffer()
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        DealerRelations.warning("Cannot decline demo offer: no active offer exists")
        return
    end

    DealerRelations.log(
        "Demo offer declined: " ..
        tostring(offer.name)
    )
    
    DealerRelations.Data:clearActiveDemoOffer()
end

function DealerRelations.UI:cancelDemoOfferScreen()
    DealerRelations.log("Demo offer screen cancelled")
end

-------------------------------------------------------------------------------
-- Demo Offer Screen
-------------------------------------------------------------------------------

function DealerRelations.UI:openActiveDemoOffer()
    local offer = DealerRelations.Data:getActiveDemoOffer()

    if offer == nil then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: No active demo offer is available."
        )
        return
    end
    
    DealerRelations.log("Opening active demo offer screen")

    local powerText = tostring(offer.displayPower or "Unknown")

    if offer.powerMin ~= nil and offer.powerMax ~= nil and offer.powerMin ~= offer.powerMax then
        powerText = string.format("%d - %d", offer.powerMin, offer.powerMax)
    end

    local message = string.format(
        "Dealer Demo Offer\n\nEquipment: %s\nBrand: %s\nCategory: %s\nPower: %s HP\nPrice: $%s\n\nOffer expires at the end of the current month.",
        tostring(offer.name),
        tostring(offer.brand),
        tostring(offer.category),
        powerText,
        tostring(offer.price)
    )
    
    DealerRelationsDemoOfferDialog.register()
    
    DealerRelationsDemoOfferDialog.show(message)
end

-------------------------------------------------------------------------------
-- Active Offer Notification
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Displays a notification when an active demo offer is available.
--
-- Called during game load so players are reminded about offers that
-- were saved in a previous session.
-------------------------------------------------------------------------------
function DealerRelations.UI:notifyActiveDemoOfferAvailable()
    if DealerRelations.Data:hasActiveDemoOffer() then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: A demo offer is currently available."
        )
    end
end