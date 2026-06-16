-------------------------------------------------------------------------------
-- DealerRelationsSettingsPage.lua
--
-- Controller for the Dealer Relations settings page.
--
-- Current scope:
--   * Provide a minimal frame/controller that can be loaded by GIANTS GUI
--   * Locate key XML elements after load
--   * Do not register the page in the ESC menu yet
--
-- Rationale:
--   The registration approach needs more investigation before this page is
--   inserted into the GIANTS settings screen.
-------------------------------------------------------------------------------

DealerRelations.SettingsPage = {}
local DealerRelationsSettingsPage_mt = Class(
    DealerRelations.SettingsPage,
    FrameElement
)

function DealerRelations.SettingsPage.new(customMt)
    local self = FrameElement.new(
        nil,
        customMt or DealerRelationsSettingsPage_mt
    )

    return self
end

-------------------------------------------------------------------------------
-- Called when the Dealer Relations settings tab is clicked.
--
-- Currently only logs because the page is not registered yet.
-------------------------------------------------------------------------------
function DealerRelations.SettingsPage:onClickDealerRelations()
    DealerRelations.log("Dealer Relations settings tab clicked")
end

-------------------------------------------------------------------------------
-- Called after the GUI XML has been loaded.
--
-- Stores references to XML elements so later registration work can verify
-- that the GUI loaded correctly before attempting to insert it.
-------------------------------------------------------------------------------
function DealerRelations.SettingsPage:onGuiSetupFinished()
    self.drPage = self:getDescendantById("drPage")
    self.drTab = self:getDescendantById("drTab")

    DealerRelations.log(
        "Dealer Relations settings XML elements found: page="
        .. tostring(self.drPage ~= nil)
        .. ", tab="
        .. tostring(self.drTab ~= nil)
    )
end