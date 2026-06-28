-------------------------------------------------------------------------------
-- Dealer Relations Utility Functions
--
-- Provides shared helper functions used throughout the Dealer Relations mod.
--
-- Responsibilities:
--   - Common formatting helpers
--   - Reusable utility functions
--   - General-purpose support logic that does not belong to a specific
--     gameplay, persistence, UI, or data module
--
-- Rationale:
-- Keeping generic helper functions in a dedicated utility module avoids
-- duplicating code across multiple systems and ensures consistent behavior
-- throughout the mod.
-------------------------------------------------------------------------------

DealerRelations.Utils = DealerRelations.Utils or {}

-- Formats a whole-number currency value using comma separators.
--
-- Rationale:
-- Dealer Relations displays vehicle prices in multiple places. Keeping
-- money formatting in one utility helper ensures offer dialogs, purchase
-- dialogs, logs, and future dealer reports all present prices consistently.
function DealerRelations.Utils:formatMoney(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))

    while true do
        local updated
        updated, count = string.gsub(
            formatted,
            "^(-?%d+)(%d%d%d)",
            "%1,%2"
        )

        formatted = updated

        if count == 0 then
            break
        end
    end

    return formatted
end

-- Convert the stored brand key used by GIANTS and Dealer Relations
-- into the player-facing brand title shown in dialogs.
-- If the brand cannot be resolved, fall back to the stored key so the
-- dialog still displays useful information instead of failing.
function DealerRelations.Utils:getBrandDisplayName(brandName)

    local brandKey = tostring(brandName)
    local brand = g_brandManager:getBrandByName(brandKey)

    return brand ~= nil and brand.title or brandKey
end

-------------------------------------------------------------------------------
-- Known category display name overrides.
--
-- Rationale:
-- Some category keys are not registered in g_storeManager or return
-- incorrect titles. Overrides here ensure the player-facing name is
-- accurate regardless of what the store manager returns.
-------------------------------------------------------------------------------
local CATEGORY_DISPLAY_NAME_OVERRIDES = {
    BALETRANSPORT = "Bale Transport",
}

-------------------------------------------------------------------------------
-- Returns the player-facing display name for an equipment category.
--
-- Checks the override table first, then falls back to g_storeManager.
-- If neither resolves, returns the raw category key so dialogs still
-- display useful information instead of failing silently.
--
-- @param categoryName string Category key used by GIANTS and Dealer Relations.
-- @return string Player-facing category title.
-------------------------------------------------------------------------------
function DealerRelations.Utils:getCategoryDisplayName(categoryName)
    local categoryKey = tostring(categoryName)

    if CATEGORY_DISPLAY_NAME_OVERRIDES[categoryKey] ~= nil then
        return CATEGORY_DISPLAY_NAME_OVERRIDES[categoryKey]
    end

    local category = g_storeManager:getCategoryByName(categoryKey)

    return category ~= nil and category.title or categoryKey
end
