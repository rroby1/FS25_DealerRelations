-------------------------------------------------------------------------------
-- DealerRelationsOverviewPanel.lua
--
-- Overview tab logic for the Dealer Relations ESC menu page.
--
-- Split out of DealerRelationsScreen.lua as part of the 0.24.0 width
-- redesign -- these functions attach to the same DealerRelations.Screen
-- table (Lua doesn't care which file a method is defined in), this is
-- purely a file-organization change with no behavior change.
--
-- Responsibilities:
--   * Rendering dealer status, relationship, and active offer/demo state
--   * Offer action buttons (Accept/Decline/Return/Buy)
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Screen = DealerRelations.Screen or {}

--- Updates Overview page display values.
--
-- Rationale:
-- Overview values are displayed through GUI text controls. This helper
-- centralizes all Overview field updates so future refreshes only need to
-- call one function.
function DealerRelations.Screen:updateOverviewValues()
    self.dealerLogoImage:setImageFilename(
        DealerRelations.directory .. "Icon.dds"
    )

    self.dealerNameValueText:setText(
        DealerRelations.Data:getDealerName()
    )

    self.dealerHoursValueText:setText(
        DealerRelations.Data:getDealerHoursText()
    )

    if DealerRelations.Data:isDealerOpen() then
        self.dealerStatusValueText:setText("Open")
        self.dealerStatusValueText:setTextColor(0, 1, 0, 1)
    else
        self.dealerStatusValueText:setText("Closed")
        self.dealerStatusValueText:setTextColor(0.7, 0, 0, 1)
    end

    self.relationshipLevelValueText:setText(
        DealerRelations.Data:getRelationshipName()
    )

    self.confidenceValueText:setText(
        tostring(DealerRelations.Data:getConfidence())
    )

    -- Clear the offer actions layout before rebuilding.
    -- Rationale:
    -- updateOverviewValues can be called multiple times. Clearing first
    -- prevents duplicate buttons from accumulating in the layout.
    while #self.offerActionsLayout.elements > 0 do
        self.offerActionsLayout:removeElement(self.offerActionsLayout.elements[1])
    end

    local offer = DealerRelations.Data:getActiveDemoOffer()
    local demo = DealerRelations.Data:getActiveDemo()

    if offer ~= nil then
        self.dealerActivityTitleText:setVisible(false)

        local storeItem = g_storeManager:getItemByXMLFilename(offer.xmlFilename)
        if storeItem ~= nil then
            self.offerImage:setVisible(true)
            self.offerImage:setImageFilename(storeItem.imageFilename)
        end

        if DealerRelations.Data:isDealerOpen() then
            self.offerActionsLayout:setVisible(true)
            self:addButtonToLayout(self.offerActionsLayout, "onClickAcceptOffer", "Accept")
            self:addButtonToLayout(self.offerActionsLayout, "onClickDeclineOffer", "Decline")
        else
            self.offerActionsLayout:setVisible(false)
        end

        -- Include the companion's name and price, if the offer has one
        -- (e.g. a header bundled with a trailer) -- the player should see
        -- both pieces and the combined price before accepting, not just
        -- the primary.
        local equipmentDisplayName = tostring(offer.name)
        local combinedListPrice = offer.price or 0

        if offer.companionName ~= nil then
            equipmentDisplayName = equipmentDisplayName .. " + " .. tostring(offer.companionName)
            combinedListPrice = combinedListPrice + (offer.companionPrice or 0)
        end

        self.dealerActivityDetail1Text:setText(
            "Equipment: " .. equipmentDisplayName
        )

        self.dealerActivityDetail2Text:setText(
            "Brand: " .. DealerRelations.Utils:getBrandDisplayName(offer.brand)
        )

        self.dealerActivityDetail3Text:setText(
            "Category: " .. DealerRelations.Utils:getCategoryDisplayName(offer.category)
        )
        self.dealerActivityDetail4Text:setText(
            "Power: " .. tostring(offer.displayPower)
        )
        self.dealerActivityDetail5Text:setText(
            "Price: " .. DealerRelations.Utils:formatMoney(combinedListPrice)
        )

        self.dealerActivityDetail6Text:setText(
            string.format("Equipment Hour Limit: %.2f hr",
                DealerRelations.Data:getDemoOperatingHourLimit()
            )
        )

    elseif demo ~= nil then
        self.dealerActivityTitleText:setVisible(false)

        local storeItem = g_storeManager:getItemByXMLFilename(demo.xmlFilename)
        if storeItem ~= nil then
            self.offerImage:setVisible(true)
            self.offerImage:setImageFilename(storeItem.imageFilename)
        end

        if DealerRelations.Data:isDealerOpen() then
            self.offerActionsLayout:setVisible(true)
            self:addButtonToLayout(self.offerActionsLayout, "onClickReturnDemo", "Return")
            self:addButtonToLayout(self.offerActionsLayout, "onClickBuyDemo", "Buy")
        else
            self.offerActionsLayout:setVisible(false)
        end

        local discountPercent = DealerRelations.Data:getDiscountPercent()
        local vehicle = DealerRelations.DemoManager:findVehicleByUniqueId(demo.uniqueId)
        local purchasePrice = 0
        local hoursUsed = 0

        -- Include the companion's price, if one exists, matching the
        -- combined price buyActiveDemo() actually charges -- this display
        -- must never show a lower number than what clicking Buy will
        -- actually cost.
        local secondary = DealerRelations.DemoManager:findSecondaryDemoVehicle()
        local equipmentDisplayName = tostring(demo.name)
        local combinedListPrice = 0

        if vehicle ~= nil then
            combinedListPrice = vehicle.price
            local currentHours = vehicle:getOperatingTime() / (1000 * 60 * 60)
            hoursUsed = currentHours - (demo.startOperatingHours or 0)
        end

        if secondary ~= nil then
            equipmentDisplayName = equipmentDisplayName .. " + " .. tostring(secondary.name)

            local secondaryVehicle = DealerRelations.DemoManager:findVehicleByUniqueId(secondary.uniqueId)
            if secondaryVehicle ~= nil then
                combinedListPrice = combinedListPrice + secondaryVehicle.price
            end
        end

        purchasePrice = DealerRelations.Data:getDemoPurchasePrice(combinedListPrice)

        self.dealerActivityDetail1Text:setText(
            "Equipment: " .. equipmentDisplayName
        )
        self.dealerActivityDetail2Text:setText(
            "Brand: " .. DealerRelations.Utils:getBrandDisplayName(demo.brand)
        )
        self.dealerActivityDetail3Text:setText(
            "Status: " .. tostring(demo.state)
        )
        self.dealerActivityDetail4Text:setText(
            "Discount: " .. tostring(discountPercent) .. "%"
        )
        self.dealerActivityDetail5Text:setText(
            "Purchase Price: " .. DealerRelations.Utils:formatMoney(purchasePrice)
        )

        self.dealerActivityDetail6Text:setText(
            string.format("Equipment Hour Limit: %.2f hr",
                DealerRelations.Data:getDemoOperatingHourLimit()
            )
        )

    else
        self.dealerActivityTitleText:setVisible(true)
        self.dealerActivityTitleText:setText("No dealer activity.")
        self.offerActionsLayout:setVisible(false)
        self.dealerActivityDetail1Text:setText("")
        self.dealerActivityDetail2Text:setText("")
        self.dealerActivityDetail3Text:setText("")
        self.dealerActivityDetail4Text:setText("")
        self.dealerActivityDetail5Text:setText("")
        self.offerImage:setVisible(false)
    end
end

--- Handles Accept Offer button click on the Overview page.
-- Rationale:
-- Accepts the active demo offer, clears the offer actions layout,
-- and refreshes the Overview so the player sees the updated state
-- without closing the ESC menu.
function DealerRelations.Screen:onClickAcceptOffer()
    DealerRelations.UI:acceptActiveDemoOffer()
    self:updateOverviewValues()
end

--- Handles Decline Offer button click on the Overview page.
-- Rationale:
-- Declines the active demo offer and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickDeclineOffer()
    DealerRelations.UI:declineActiveDemoOffer()
    self:updateOverviewValues()
end

--- Handles Return Demo button click on the Overview page.
-- Rationale:
-- Returns the active demo vehicle and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickReturnDemo()
    DealerRelations.UI:returnActiveDemo()
    self:updateOverviewValues()
end

--- Handles Buy Demo button click on the Overview page.
-- Rationale:
-- Purchases the active demo vehicle and refreshes the Overview so the
-- player sees the updated state without closing the ESC menu.
function DealerRelations.Screen:onClickBuyDemo()
    DealerRelations.UI:buyActiveDemo()
    self:updateOverviewValues()
end
