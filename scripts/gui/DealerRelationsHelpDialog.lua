-------------------------------------------------------------------------------
-- DealerRelationsHelpDialog.lua
--
-- Standalone Help dialog for Dealer Relations, opened via g_gui:showDialog()
-- from a persistent button on the main ESC page rather than as one of its
-- tabs.
--
-- Content is built dynamically in _buildContent() rather than hardcoded in
-- XML so that player-facing numbers (dealer hours, late fee percent, max
-- discount, current demo hour limit) always match the live constants/data
-- instead of drifting out of sync if those values are tuned later.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.HelpDialog = {}
local DealerRelations_HelpDialog_mt = Class(DealerRelations.HelpDialog, ScreenElement)

DealerRelations.HelpDialog.CLASS_NAME = "DealerRelationsHelpDialog"
DealerRelations.HelpDialog.XML_FILENAME = g_currentModDirectory .. "gui/DealerRelationsHelpDialog.xml"

-------------------------------------------------------------------------------
-- Content template.
--
-- Each row is {t, v, args}:
--   t    = "H" (section header) or "B" (body paragraph)
--   v    = display text; may contain string.format placeholders
--   args = optional list of value keys (resolved in _buildContent) to fill
--          those placeholders, in order
-------------------------------------------------------------------------------
DealerRelations.HelpDialog.CONTENT_TEMPLATE = {
    { t = "H", v = "Offers" },
    { t = "B", v = "Each month your dealer selects a piece of equipment and makes you a demo offer. You will be notified when the dealer opens. You can Accept or Decline the offer during dealer hours (%s). If you ignore the offer until the dealer closes or until the next month, a small confidence penalty applies.",
      args = { "dealerHours" } },

    { t = "H", v = "Demos" },
    { t = "B", v = "When you accept an offer, the equipment is delivered to the shop for a one-month demo period. Your current demo operating hour limit is %.1f hours, based on your month length setting. Once the demo expires -- either by month end or hour limit -- you must return or purchase the equipment.",
      args = { "demoHourLimit" } },

    { t = "H", v = "Overdue Equipment" },
    { t = "B", v = "If you do not return or purchase the equipment after the demo expires, consequences escalate each day at dealer close:" },
    { t = "B", v = "First missed deadline: Warning notification." },
    { t = "B", v = "Second missed deadline: Confidence penalty and demo offers suspended for one month." },
    { t = "B", v = "Third missed deadline: Additional confidence penalty, suspension extended by one month, and a %d%% late fee charged to your farm account. Suspension begins when the demo is resolved.",
      args = { "lateFeePercent" } },
    { t = "B", v = "Fourth missed deadline: Equipment is repossessed." },

    { t = "H", v = "Relationship and Confidence" },
    { t = "B", v = "Your relationship with the dealer is tracked through a confidence score. Accepting demos, returning equipment, and purchasing equipment improve confidence. Ignoring offers or missing deadlines reduces it. Higher relationship levels unlock purchase discounts up to %d%%.",
      args = { "maxDiscountPercent" } },

    { t = "H", v = "Settings" },
    { t = "B", v = "Use the Settings tab to control which equipment brands the dealer will offer, and to toggle forestry equipment." },
}

-------------------------------------------------------------------------------
-- Constructor.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog.new(target, customMt)
    local self = ScreenElement.new(target, customMt or DealerRelations_HelpDialog_mt)
    self._contentLineEls = {}
    return self
end

-------------------------------------------------------------------------------
-- Registers the dialog once, independent of the main ESC page.
--
-- Rationale:
-- Unlike DealerRelations.Screen, this is never attached to InGameMenu
-- paging -- it's opened on demand via g_gui:showDialog().
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog.register()
    if DealerRelations.HelpDialog.instance ~= nil then
        return
    end

    local dialog = DealerRelations.HelpDialog.new()

    g_gui:loadGui(
        DealerRelations.HelpDialog.XML_FILENAME,
        DealerRelations.HelpDialog.CLASS_NAME,
        dialog
    )

    DealerRelations.HelpDialog.instance = dialog

    DealerRelations.log("Dealer Relations Help dialog registered")
end

-------------------------------------------------------------------------------
-- Lifecycle: onGuiSetupFinished.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:onGuiSetupFinished()
    DealerRelations.HelpDialog:superClass().onGuiSetupFinished(self)
end

-------------------------------------------------------------------------------
-- Lifecycle: onOpen.
--
-- Rationale:
-- Content is rebuilt on every open rather than once at registration so the
-- templated values (demo hour limit, in particular) always reflect the
-- current save rather than whatever was true when the dialog first loaded.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:onOpen()
    DealerRelations.HelpDialog:superClass().onOpen(self)

    self:_buildContent()

    self.helpLayout.fillDirections[2] = -1
    self.helpLayout.alignment[2] = 1
    self.helpLayout:invalidateLayout()
    self.helpLayout:raiseSliderUpdateEvent()
end

-------------------------------------------------------------------------------
-- Lifecycle: onClose.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:onClose()
    DealerRelations.HelpDialog:superClass().onClose(self)

    self:_clearContent()
end

-------------------------------------------------------------------------------
-- Resolves the live values referenced by CONTENT_TEMPLATE's args lists.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:_resolveValues()
    return {
        dealerHours = DealerRelations.Data:getDealerHoursText(),
        demoHourLimit = DealerRelations.Data:getDemoOperatingHourLimit(),
        lateFeePercent = DealerRelations.CONSTANTS.OVERDUE_LEVEL_3_FEE_PERCENT,
        maxDiscountPercent = DealerRelations.CONSTANTS.RELATIONSHIP_DISCOUNT_PARTNER,
    }
end

-------------------------------------------------------------------------------
-- Builds the help content into helpLayout from CONTENT_TEMPLATE, resolving
-- each row's args against live values before formatting.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:_buildContent()
    local profileH = g_gui:getProfile("dr_helpHeader")
    local profileB = g_gui:getProfile("dr_helpBody")

    if not profileH or not profileB then
        DealerRelations.warning("HelpDialog: required text profiles not found")
        return
    end

    local values = self:_resolveValues()

    for _, row in ipairs(DealerRelations.HelpDialog.CONTENT_TEMPLATE) do
        local profile = (row.t == "H") and profileH or profileB
        local text = row.v

        if row.args ~= nil then
            local resolved = {}
            for i, key in ipairs(row.args) do
                resolved[i] = values[key]
            end
            text = string.format(row.v, unpack(resolved))
        end

        local el = TextElement.new()
        el:loadProfile(profile, true)
        el:setText(text)
        self.helpLayout:addElement(el)
        el:onGuiSetupFinished()

        table.insert(self._contentLineEls, el)
    end

    self.helpLayout:invalidateLayout()
end

-------------------------------------------------------------------------------
-- Removes all dynamically built content rows.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:_clearContent()
    for _, el in ipairs(self._contentLineEls) do
        self.helpLayout:removeElement(el)
    end

    self._contentLineEls = {}
end

-------------------------------------------------------------------------------
-- Handles the Close button.
-------------------------------------------------------------------------------
function DealerRelations.HelpDialog:onClickClose()
    g_gui:closeDialogByName(DealerRelations.HelpDialog.CLASS_NAME)
end
