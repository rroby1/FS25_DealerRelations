-------------------------------------------------------------------------------
-- DealerRelationsDemoReturnDialog.lua
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
-- DealerRelationsDemoReturnDialog.xml.
-------------------------------------------------------------------------------

DealerRelationsDemoReturnDialog = {}

local DealerRelationsDemoReturnDialog_mt = Class(DealerRelationsDemoReturnDialog, ScreenElement)

local modDirectory = g_currentModDirectory

-------------------------------------------------------------------------------
-- Class Definition
-------------------------------------------------------------------------------

local DealerRelationsDemoReturnDialog_mt =
    Class(DealerRelationsDemoReturnDialog, MessageDialog)

-------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Creates a new Dealer Relations demo offer dialog instance.
--
-- @param target table Optional target object.
-- @param customMt table Optional custom metatable.
--
-- @return table New dialog instance.
-------------------------------------------------------------------------------
function DealerRelationsDemoReturnDialog.new(target, customMt)
    local dialog = MessageDialog.new(
        target,
        customMt or DealerRelationsDemoReturnDialog_mt
    )

    return dialog
end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------
function DealerRelationsDemoReturnDialog.register()
    local dialog = DealerRelationsDemoReturnDialog.new()

    g_gui:loadGui(
        modDirectory .. "gui/DealerRelationsDemoReturnDialog.xml",
        "DealerRelationsDemoReturnDialog",
        dialog
    )

    DealerRelationsDemoReturnDialog.INSTANCE = dialog

    DealerRelations.log("DealerRelationsDemoReturnDialog registered")
end

-------------------------------------------------------------------------------
-- Display
-------------------------------------------------------------------------------
function DealerRelationsDemoReturnDialog.show(text)
    if DealerRelationsDemoReturnDialog.INSTANCE == nil then
        DealerRelationsDemoReturnDialog.register()
    end

    local dialog = DealerRelationsDemoReturnDialog.INSTANCE

    dialog.dialogTitleElement:setText("Dealer Demo Offer")
    dialog.messageTextElement:setText(text or "")

    g_gui:showDialog("DealerRelationsDemoReturnDialog")
end

-------------------------------------------------------------------------------
-- Button Callbacks
-------------------------------------------------------------------------------
-- Handles the Return button during the first wiring test.
function DealerRelationsDemoReturnDialog:onClickReturn()
    DealerRelations.log("Expired demo dialog Return button pressed")
    self:close()
end

-- Handles the Buy button during the first wiring test.
function DealerRelationsDemoReturnDialog:onClickBuy()
    DealerRelations.log("Expired demo dialog Buy button pressed")
    self:close()
end

-------------------------------------------------------------------------------
-- Close Handling
-------------------------------------------------------------------------------