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

    -- Convert the stored category key used by GIANTS and Dealer Relations
    -- into the player-facing category title shown in dialogs.
    -- If the category cannot be resolved, fall back to the stored key so the
    -- dialog still displays useful information instead of failing.
function DealerRelations.Utils:getCategoryDisplayName(categoryName)

    local categoryKey = tostring(categoryName)
    local category = g_storeManager:getCategoryByName(categoryKey)

    return category ~= nil and category.title or categoryKey
end

--- Resolves the $data token in a Farming Simulator asset path.
-- Rationale:
-- getXMLString returns raw XML values. FS25 does not resolve $data
-- tokens in string results, so paths like '$data/vehicles/...' must
-- be converted to 'data/vehicles/...' before use with BitmapElement.
--
-- @param path string Raw path string from XML.
-- @return string Resolved path, or nil if path was nil.
function DealerRelations.Utils:resolveAssetPath(path)
    if path == nil then
        return nil
    end

    return path:gsub("^%$data/", "data/")
end