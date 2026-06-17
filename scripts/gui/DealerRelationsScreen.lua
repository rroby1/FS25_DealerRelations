-------------------------------------------------------------------------------
-- Dealer Relations Screen
--
-- Main ESC menu page for Dealer Relations.
--
-- Future responsibilities:
-- - Overview page
-- - Active demo information
-- - Relationship history
-- - Configuration and filter management
--
-- This module currently defines only the screen class metadata.
-- Screen registration and XML loading will be added in later steps.
-------------------------------------------------------------------------------

DealerRelations.Screen = {}

-------------------------------------------------------------------------------
-- Class Metadata
-------------------------------------------------------------------------------

-- Dealer Relations will be implemented as a custom InGameMenu page.
--
-- Rationale:
-- Using TabbedMenuFrameElement aligns with the architecture used by existing
-- Farming Simulator menu pages and provides built-in support for integration
-- with the ESC menu page system.
DealerRelations.Screen._mt = Class(
    DealerRelations.Screen,
    TabbedMenuFrameElement
)

-- GUI class name used by the GIANTS GUI system when loading XML.
DealerRelations.Screen.CLASS_NAME = "DealerRelationsScreen"

-- Internal page identifier used when registering the page with InGameMenu.
DealerRelations.Screen.MENU_PAGE_NAME = "menuDealerRelations"

-- XML definition file for the Dealer Relations screen.
--
-- Rationale:
-- Store the full XML path while the mod directory is known, so later runtime
-- GUI loading does not depend on g_currentModDirectory still being available.
DealerRelations.Screen.XML_FILENAME =
    g_currentModDirectory .. "gui/DealerRelationsScreen.xml"

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------

-- Creates the Dealer Relations menu frame instance.
--
-- Rationale:
-- Dealer Relations uses the same base frame type as other in-game menu pages.
-- This constructor only creates the frame object; XML loading and menu
-- registration are intentionally handled later so each lifecycle step can be
-- tested independently.
function DealerRelations.Screen.new(target, customMt)
    local self = TabbedMenuFrameElement.new(
        target,
        customMt or DealerRelations.Screen._mt
    )

    self:setTitle("Dealer Relations")

    return self
end

function DealerRelations.Screen:createInstance()
    -- Create the screen object without loading XML or registering it.
    --
    -- Rationale:
    -- This verifies the Dealer Relations screen can be instantiated before
    -- involving GIANTS GUI XML loading or InGameMenu registration.
    return DealerRelations.Screen.new()
end

-------------------------------------------------------------------------------
-- GUI Loading
-------------------------------------------------------------------------------

-- Creates the screen instance and loads the Dealer Relations GUI XML into it.
--
-- Rationale:
-- This step verifies XML loading separately from ESC menu registration. The
-- screen is not added to InGameMenu yet, so a failure here can only come from
-- GUI loading or XML structure.
function DealerRelations.Screen:loadGui()
    local screen = DealerRelations.Screen:createInstance()

    g_gui:loadGui(
        DealerRelations.Screen.XML_FILENAME,
        DealerRelations.Screen.CLASS_NAME,
        screen,
        true
    )

    return screen
end