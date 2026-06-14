-------------------------------------------------------------------------------
-- DealerRelationsDemoReturnDialog.lua
--
-- Custom dialog used to resolve an expired demo vehicle.
--
-- Responsibilities:
-- * Display expired demo information
-- * Return the demo vehicle
-- * Purchase the demo vehicle
-- * Close the dialog without taking action
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
-- Creates the demo return dialog instance used by GIANTS' GUI system.
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
--
-- Loads the dialog XML and stores the singleton instance used by show().
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
--
-- Populates the dialog with expired demo information and opens it.
-------------------------------------------------------------------------------
-- Shows the expired demo return/buy dialog.
--
-- The demoVehicle record is stored on the dialog instance so
-- Return and Buy actions can operate on the correct vehicle.
function DealerRelationsDemoReturnDialog.show(text, demoVehicle)
    if DealerRelationsDemoReturnDialog.INSTANCE == nil then
        DealerRelationsDemoReturnDialog.register()
    end

    local dialog = DealerRelationsDemoReturnDialog.INSTANCE

    -- Store the tracking record on the dialog instance.
    -- Rationale: onClickReturn runs later, after the dialog is already open.
    dialog.demoVehicle = demoVehicle
    
    dialog.dialogTitleElement:setText("Dealer Demo Offer")
    dialog.messageTextElement:setText(text or "")

    g_gui:showDialog("DealerRelationsDemoReturnDialog")
end

-------------------------------------------------------------------------------
-- Button Callbacks
-------------------------------------------------------------------------------
-- Handles the Return button for an expired demo.
--
-- Workflow:
-- 1. Locate the tracked demo vehicle.
-- 2. Remove the vehicle from the game.
-- 3. Mark the demo as RETURNED.
-- 4. Remove the demo from active tracking.
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

   -- Removes an active demo tracking record by uniqueId.
    --
    -- Used when a demo lifecycle is complete and should no longer
    -- participate in open-demo checks or future processing.
    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning("Cannot return expired demo: vehicle not found for uniqueId " .. tostring(demoVehicle.uniqueId))
        return
    end

    DealerRelations.log("Return vehicle located: " .. tostring(vehicle:getName()))

    -- Removes a demo vehicle from the game world.
    --
    -- Used when a player returns an expired demo rather than purchasing it.
    DealerRelations.DemoManager:removeDemoVehicle(vehicle)
    
    -- Mark the demo as returned.
    -- Rationale: the vehicle has been successfully removed from the game,
    -- so the demo lifecycle can advance from EXPIRED to RETURNED.
    demoVehicle.state = "RETURNED"

    DealerRelations.log(
        "Demo marked RETURNED: " .. tostring(demoVehicle.name)
    )

    -- Remove the returned demo from active tracking.
    -- Rationale: RETURNED demos are resolved and should no longer block future demo offers.
    DealerRelations.Data:removeActiveDemoVehicleByUniqueId(demoVehicle.uniqueId)
end

-- Handles the Buy button for an expired demo.
--
-- Workflow:
-- 1. Locate the tracked demo vehicle.
-- 2. Convert the vehicle to OWNED.
-- 3. Calculate the discounted purchase price.
-- 4. Charge the player's farm.
-- 5. Mark the demo as PURCHASED.
function DealerRelationsDemoReturnDialog:onClickBuy()
    DealerRelations.log("Expired demo dialog Buy button pressed")

    -- Keep a local copy before closing the dialog.
    -- Rationale: once the dialog closes, UI state may be cleared later.
    local demoVehicle = self.demoVehicle

    self:close()

    if demoVehicle == nil then
        DealerRelations.warning("Cannot buy expired demo: demoVehicle is nil")
        return
    end

    -- Locate the actual in-game vehicle from the saved uniqueId.
    -- Rationale: buying must operate on the spawned demo vehicle object.
    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning("Cannot buy expired demo: vehicle not found for uniqueId " .. tostring(demoVehicle.uniqueId))
        return
    end

    DealerRelations.log("Buy vehicle located: " .. tostring(vehicle:getName()))

    -- Change the live vehicle property state to owned.
    -- Rationale: the live vehicle object does not expose setPropertyState(),
    -- but it does have a propertyState field.
    vehicle.propertyState = VehiclePropertyState.OWNED

    -- Calculate the demo purchase price from the live vehicle price.
    -- Rationale: the active demo tracking record does not currently store price,
    -- but the live vehicle object has the original list price.
    local purchasePrice = math.floor(vehicle.price * 0.90)

    DealerRelations.log(
        string.format(
            "Demo purchase price calculated: $%d (list price $%d)",
            purchasePrice,
            vehicle.price
        )
    )

    -- Charge the player's farm for the demo purchase.
    -- Rationale: the demo is being converted to owned equipment, so the farm
    -- should pay the agreed demo purchase price.
    local farmId = vehicle:getOwnerFarmId()

    DealerRelations.log(
        string.format(
            "Charging farm %d for demo purchase: $%d",
            farmId,
            purchasePrice
        )
    )

    g_currentMission:addMoney(
        -purchasePrice,
        farmId,
        MoneyType.SHOP_VEHICLE_BUY,
        true,
        true
    )

    DealerRelations.log(
        string.format(
            "Demo purchase charge completed: $%d",
            purchasePrice
        )
    )

    demoVehicle.state = "PURCHASED"

    DealerRelations.log(
        "Demo marked PURCHASED: " .. tostring(demoVehicle.name)
    )
end
