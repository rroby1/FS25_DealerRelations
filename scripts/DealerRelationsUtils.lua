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