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
        DealerRelations.log("Opening active demo offer screen")
    else
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: No active demo offer is available."
        )
    end
end
