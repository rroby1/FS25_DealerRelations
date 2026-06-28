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
-- Demo Offer Actions
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Accepts the active demo offer and spawns the demo vehicle.
--
-- @see DealerRelations.DemoManager:startDemoFromOffer
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

-------------------------------------------------------------------------------
-- Declines the active demo offer and applies a confidence penalty.
-------------------------------------------------------------------------------
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
-- Displays a notification when an active demo offer is available.
--
-- Called during game load so players are reminded about offers that
-- were saved in a previous session.
-------------------------------------------------------------------------------
function DealerRelations.UI:notifyActiveDemoOfferAvailable()
    if DealerRelations.Data:hasActiveDemoOffer() then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Dealer Relations: A demo offer is available. Visit the dealer before closing time."
        )
    end
end

-------------------------------------------------------------------------------
-- Disabled Mod Notification
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Displays a startup notification when Dealer Relations is disabled.
--
-- Rationale:
-- The mod defaults to disabled so players do not receive demo offers before
-- reviewing settings and filters. This reminder makes that state visible
-- without changing gameplay behavior.
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- Opens the return/buy dialog for an expired demo vehicle.
--
-- Presents the player's current relationship status, discount, and purchase
-- price so they can resolve the demo by returning or purchasing the machine.
--
-- @param demoVehicle table Expired demo vehicle record.
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- Displays the player's current dealer relationship status on load.
--
-- Rationale:
-- Dealer relationship changes gradually through demo interactions.
-- Showing the current relationship and confidence at startup reminds
-- the player of their standing and surfaces changes from previous sessions.
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- Handles direct return of the active demo from the Overview dashboard.
--
-- Rationale:
-- Mirrors onClickReturn from DealerRelationsDemoReturnDialog without
-- requiring the dialog to be open. Called from the Overview Return button.
-------------------------------------------------------------------------------
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

    DealerRelations.DemoManager:applyPendingSuspension()

    DealerRelations.Data:removeActiveDemoVehicleByUniqueId(demoVehicle.uniqueId)

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_RETURN_DEMO,
        "Returned demo vehicle"
    )
end

-------------------------------------------------------------------------------
-- Handles direct purchase of the active demo from the Overview dashboard.
--
-- Rationale:
-- Mirrors onClickBuy from DealerRelationsDemoReturnDialog without
-- requiring the dialog to be open. Called from the Overview Buy button.
-------------------------------------------------------------------------------
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

    DealerRelations.DemoManager:applyPendingSuspension()

    DealerRelations.Data:addConfidence(
        DealerRelations.CONSTANTS.CONFIDENCE_IMPACT_BUY_DEMO,
        "Purchased demo vehicle"
    )
end