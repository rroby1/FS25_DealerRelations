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
-- Input Registration
-------------------------------------------------------------------------------

function DealerRelations.UI:registerInput()
    -- Confirm that the custom input action from modDesc.xml was loaded
    -- before asking GIANTS to register an action event for it.
    if InputAction.DR_OPEN_DEMO_OFFER == nil then
        DealerRelations.warning("Cannot register demo offer input: DR_OPEN_DEMO_OFFER is missing")
        return
    end

    -- Register the demo offer hotkey as a player action event.
    -- This function is now called from the player input registration flow,
    -- so we do not need update-loop retry logic here.
    local _, actionEventId = g_inputBinding:registerActionEvent(
        InputAction.DR_OPEN_DEMO_OFFER,
        DealerRelations.UI,
        DealerRelations.UI.onOpenDemoOfferInput,
        false,
        true,
        false,
        true
    )

    if actionEventId == nil then
        DealerRelations.warning("Demo offer input registration failed: actionEventId is nil")
        return
    end

    -- Keep the action hidden from the F1 help menu for now.
    -- The key is meant as a direct shortcut, not an always-visible prompt.
    g_inputBinding:setActionEventText(actionEventId, "Open Dealer Demo Offer")
    g_inputBinding:setActionEventTextVisibility(actionEventId, false)

    self.openDemoOfferActionEventId = actionEventId

    DealerRelations.log("Dealer Relations demo offer input registered")
end

-------------------------------------------------------------------------------
-- Input Callbacks
-------------------------------------------------------------------------------

function DealerRelations.UI:onOpenDemoOfferInput()
    -- Dashboard now handles all demo offer and demo management actions.
    -- Direct the player to the ESC menu Dealer Relations page.
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_INFO,
        "Dealer Relations: Open the ESC menu to manage offers and demos."
    )
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
    
    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_DECLINE_DEMO,
        "Declined demo offer"
    )
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
            "Dealer Relations: A demo offer is available."
        )
    end
end

-------------------------------------------------------------------------------
-- Disabled Mod Notification
-------------------------------------------------------------------------------

-- Displays a startup notification when Dealer Relations is disabled.
--
-- Rationale:
-- The mod now defaults to disabled so players do not receive demo offers before
-- reviewing settings and filters. This reminder makes that state visible without
-- changing gameplay behavior yet.
function DealerRelations.UI:notifyModDisabled()
    if DealerRelations.Data:isEnabled() then
        return
    end

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_INFO,
        "Dealer Relations is currently disabled."
    )
end

-------------------------------------------------------------------------------
-- Expired Demo Return / Buy Screen
-------------------------------------------------------------------------------

-- Opens the return/buy dialog for an expired demo vehicle.
--
-- The dialog lets the player resolve the active demo by either returning
-- the machine or purchasing it.
function DealerRelations.UI:openExpiredDemoDialog(demoVehicle)
    if demoVehicle == nil then
        DealerRelations.warning("Cannot open expired demo dialog: demoVehicle is nil")
        return
    end

    DealerRelations.log("Opening expired demo return/buy dialog")
    
    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning(
            "Cannot calculate expired demo purchase price: vehicle not found for uniqueId "
            .. tostring(demoVehicle.uniqueId)
        )
        return
    end
    
    local relationshipName = DealerRelations.Data:getRelationshipName()
    local confidence = DealerRelations.Data:getConfidence()
    local discountPercent = DealerRelations.Data:getDiscountPercent()
    local purchasePrice =
        DealerRelations.Data:getDemoPurchasePrice(vehicle.price)
    local formattedPurchasePrice =
        DealerRelations.Utils:formatMoney(purchasePrice)
    local brandDisplayName =
        DealerRelations.Utils:getBrandDisplayName(demoVehicle.brand)

    local message = string.format(
        "Dealer Relationship: %s (Confidence %d)\nPurchase Discount: %d%%\n\nEquipment: %s\nBrand: %s\nStatus: Demo Expired\nPurchase Price: $%s\n\nThis demo period has ended. Return the machine or purchase it at your dealer discount.",
        relationshipName,
        confidence,
        discountPercent,
        tostring(demoVehicle.name),
        brandDisplayName,
        formattedPurchasePrice
    )

    -- Register and show the expired demo dialog.
    DealerRelationsDemoReturnDialog.register()
    DealerRelationsDemoReturnDialog.show(message, demoVehicle)
end




-- Displays the player's current dealer relationship status when a save
-- is loaded.
--
-- Rationale:
-- Dealer relationship is a long-term progression system that changes
-- gradually through demo interactions. Showing the current relationship
-- and confidence score at startup reminds the player of their standing
-- with the dealership and provides visibility into relationship changes
-- that may have occurred during previous play sessions.
function DealerRelations.UI:notifyRelationshipStatus()
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_INFO,
        string.format(
            "Dealer Relations: %s relationship (Confidence %d)",
            DealerRelations.Data:getRelationshipName(),
            DealerRelations.Data:getConfidence()
        )
    )
end

--- Handles direct return of the active demo from the Overview dashboard.
--
-- Rationale:
-- Mirrors onClickReturn from DealerRelationsDemoReturnDialog without
-- requiring the dialog to be open. Called from the Overview Return button.
function DealerRelations.UI:returnActiveDemo()
    local demoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local demoVehicle = nil

    for _, v in ipairs(demoVehicles) do
        if v.state == "ACTIVE" or v.state == "EXPIRED" then
            demoVehicle = v
            break
        end
    end

    if demoVehicle == nil then
        DealerRelations.warning("Cannot return demo: no active demo found")
        return
    end

    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning("Cannot return demo: vehicle not found for uniqueId " .. tostring(demoVehicle.uniqueId))
        return
    end

    DealerRelations.DemoManager:removeDemoVehicle(vehicle)

    demoVehicle.state = "RETURNED"

    DealerRelations.log("Demo marked RETURNED: " .. tostring(demoVehicle.name))

    DealerRelations.Data:removeActiveDemoVehicleByUniqueId(demoVehicle.uniqueId)

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_RETURN_DEMO,
        "Returned demo vehicle"
    )
end

--- Handles direct purchase of the active demo from the Overview dashboard.
--
-- Rationale:
-- Mirrors onClickBuy from DealerRelationsDemoReturnDialog without
-- requiring the dialog to be open. Called from the Overview Buy button.
function DealerRelations.UI:buyActiveDemo()
    local demoVehicles = DealerRelations.Data:getActiveDemoVehicles()
    local demoVehicle = nil

    for _, v in ipairs(demoVehicles) do
        if v.state == "ACTIVE" or v.state == "EXPIRED" then
            demoVehicle = v
            break
        end
    end

    if demoVehicle == nil then
        DealerRelations.warning("Cannot buy demo: no active demo found")
        return
    end

    local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demoVehicle.uniqueId)

    if vehicle == nil then
        DealerRelations.warning("Cannot buy demo: vehicle not found for uniqueId " .. tostring(demoVehicle.uniqueId))
        return
    end

    vehicle.propertyState = VehiclePropertyState.OWNED

    local discountPercent = DealerRelations.Data:getDiscountPercent()
    local purchasePrice = DealerRelations.Data:getDemoPurchasePrice(vehicle.price)

    DealerRelations.log(string.format(
        "Demo purchase price: $%d (list $%d, discount %d%%)",
        purchasePrice,
        vehicle.price,
        discountPercent
    ))

    local farmId = vehicle:getOwnerFarmId()

    g_currentMission:addMoney(
        -purchasePrice,
        farmId,
        MoneyType.SHOP_VEHICLE_BUY,
        true,
        true
    )

    demoVehicle.state = "PURCHASED"

    DealerRelations.log("Demo marked PURCHASED: " .. tostring(demoVehicle.name))

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_BUY_DEMO,
        "Purchased demo vehicle"
    )
end