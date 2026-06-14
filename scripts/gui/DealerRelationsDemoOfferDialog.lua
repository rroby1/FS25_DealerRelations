-------------------------------------------------------------------------------
-- DealerRelationsDemoOfferDialog.lua
--
-- Custom dialog used to display an active dealer demo offer.
--
-- Responsibilities:
--   * Display active offer information
--   * Allow player to accept the offer
--   * Allow player to decline the offer
--   * Allow player to close the dialog without responding
--
-- This dialog extends MessageDialog and is loaded from
-- DealerRelationsDemoOfferDialog.xml.
-------------------------------------------------------------------------------

DealerRelationsDemoOfferDialog = {}
DealerRelationsDemoOfferDialog.INSTANCE = nil

local modDirectory = g_currentModDirectory

-------------------------------------------------------------------------------
-- Class Definition
-------------------------------------------------------------------------------

local DealerRelationsDemoOfferDialog_mt =
    Class(DealerRelationsDemoOfferDialog, MessageDialog)

-------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Creates the demo offer dialog instance used by GIANTS' GUI system.
-------------------------------------------------------------------------------
function DealerRelationsDemoOfferDialog.new(target, customMt)
    local dialog = MessageDialog.new(
        target,
        customMt or DealerRelationsDemoOfferDialog_mt
    )

    return dialog
end

-------------------------------------------------------------------------------
-- Registration
--
-- Loads the dialog XML and stores the singleton instance used by show().
-------------------------------------------------------------------------------
function DealerRelationsDemoOfferDialog.register()
    local dialog = DealerRelationsDemoOfferDialog.new()

    g_gui:loadGui(
        modDirectory .. "gui/DealerRelationsDemoOfferDialog.xml",
        "DealerRelationsDemoOfferDialog",
        dialog
    )

    DealerRelationsDemoOfferDialog.INSTANCE = dialog

    DealerRelations.log("DealerRelationsDemoOfferDialog registered")
end

-------------------------------------------------------------------------------
-- Display
--
-- Ensures the dialog is loaded, fills in the current offer text, and opens it.
-------------------------------------------------------------------------------
function DealerRelationsDemoOfferDialog.show(text)
    if DealerRelationsDemoOfferDialog.INSTANCE == nil then
        DealerRelationsDemoOfferDialog.register()
    end

    local dialog = DealerRelationsDemoOfferDialog.INSTANCE

    dialog.dialogTitleElement:setText("Dealer Demo Offer")
    dialog.messageTextElement:setText(text or "")

    g_gui:showDialog("DealerRelationsDemoOfferDialog")
end

-------------------------------------------------------------------------------
-- Button Callbacks
-------------------------------------------------------------------------------
function DealerRelationsDemoOfferDialog:onClickAccept()
    DealerRelations.UI:acceptActiveDemoOffer()
    self:close()
end

function DealerRelationsDemoOfferDialog:onClickDecline()
    DealerRelations.UI:declineActiveDemoOffer()
    self:close()
end

function DealerRelationsDemoOfferDialog:onClickCancel()
    DealerRelations.UI:cancelDemoOfferScreen()
    self:close()
end

-------------------------------------------------------------------------------
-- Close Handling
-------------------------------------------------------------------------------