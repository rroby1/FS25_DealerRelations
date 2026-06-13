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
-- Shows the expired demo return dialog for one specific demo vehicle.
-- Rationale: the button handlers need the demo record later so they can locate
-- the actual in-game vehicle by uniqueId.
function DealerRelationsDemoReturnDialog.show(text, demoVehicle)
    if DealerRelationsDemoReturnDialog.INSTANCE == nil then
        DealerRelationsDemoReturnDialog.register()
    end

    local dialog = DealerRelationsDemoReturnDialog.INSTANCE

    -- Store the tracking record on the dialog instance.
    -- Rationale: onClickReturn runs later, after the dialog is already open.
    dialog.demoVehicle = demoVehicle
    
    DealerRelations.log(
        "Expired demo dialog received demoVehicle: " .. tostring(demoVehicle ~= nil and demoVehicle.name or nil)
    )

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

    -- Keep a local copy before closing the dialog.
    -- Rationale: once the dialog closes, UI state may be cleared later.
    local demoVehicle = self.demoVehicle

    self:close()

    -- Stop here if the dialog was opened without a demo record.
    -- Rationale: Return must operate on one known active demo.
    if demoVehicle == nil then
        DealerRelations.warning("Cannot return expired demo: demoVehicle is nil")
        return
    end

    -- Locate the actual in-game vehicle from the saved uniqueId.
    -- Rationale: the demo record is only tracking data; removal must act on the spawned vehicle object.
    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning("Cannot return expired demo: vehicle not found for uniqueId " .. tostring(demoVehicle.uniqueId))
        return
    end

    DealerRelations.log("Return vehicle located: " .. tostring(vehicle:getName()))

    -- Remove only the in-game vehicle for this test step.
    -- Rationale: tracking cleanup is a separate future step.
    DealerRelations.DemoManager:removeDemoVehicle(vehicle)
    
    -- Mark the demo as returned.
    -- Rationale: the vehicle has been successfully removed from the game,
    -- so the demo lifecycle can advance from EXPIRED to RETURNED.
    demoVehicle.state = "RETURNED"

    DealerRelations.log(
        "Demo marked RETURNED: " .. tostring(demoVehicle.name)
    )
end

-- Handles the Buy button during the first wiring test.
function DealerRelationsDemoReturnDialog:onClickBuy()
    DealerRelations.log("Expired demo dialog Buy button pressed")
    self:close()
end

-------------------------------------------------------------------------------
-- Close Handling
-------------------------------------------------------------------------------