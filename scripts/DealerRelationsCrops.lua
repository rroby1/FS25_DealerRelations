-------------------------------------------------------------------------------
-- DealerRelationsCrops.lua
--
-- Tracks crop history across fields owned by the player.
--
-- Responsibilities:
--   - Scanning owned fields for currently planted crops
--   - Recording crops into the per-save "ever grown" history
--
-- This module does not perform demo selection or eligibility filtering.
-- It only maintains the crop history data that eligibility filtering
-- will read from.
-------------------------------------------------------------------------------

DealerRelations = DealerRelations or {}
DealerRelations.Crops = DealerRelations.Crops or {}

-------------------------------------------------------------------------------
-- Scans all fields owned by the player's farm and records any currently
-- planted crop into the per-save crop history.
--
-- Rationale:
-- Crop history is append-only and intentionally never reflects the current
-- planting state on its own — a field being fallow or replanted with a
-- different crop does not remove a previously recorded crop. This scan is
-- the only way entries are added; nothing else writes to crop history.
--
-- farmId is read fresh at the start of each scan rather than cached across
-- scans. This mirrors the pattern used for loan origination in
-- DealerRelationsFinance.lua, where g_currentMission.player.farmId was
-- found reliable to read once per operation but not to rely on across a
-- longer-lived process.
--
-- Called once during map load, and again on every PERIOD_CHANGED event.
-------------------------------------------------------------------------------
function DealerRelations.Crops:scanOwnedFields()
    if g_fieldManager == nil or g_fieldManager.fields == nil then
        DealerRelations.warning("Cannot scan fields: field manager is unavailable")
        return
    end

    local farmId = g_currentMission.player and g_currentMission.player.farmId or 1
    local fieldCount = 0
    local newCropCount = 0

    for _, field in pairs(g_fieldManager.fields) do
        fieldCount = fieldCount + 1

        if field.farmland ~= nil and field.farmland.farmId == farmId then
            local fruitTypeIndex = field.fieldState ~= nil and field.fieldState.fruitTypeIndex or nil

            if fruitTypeIndex ~= nil and fruitTypeIndex > 0 then
                local fruitTypeName = g_fruitTypeManager:getFruitTypeNameByIndex(fruitTypeIndex)

                if fruitTypeName ~= nil
                    and fruitTypeName ~= "UNKNOWN"
                    and not DealerRelations.Data:hasCropBeenGrown(fruitTypeName) then
                    DealerRelations.Data:addCropEverGrown(fruitTypeName)
                    newCropCount = newCropCount + 1
                end
            end
        end
    end

    DealerRelations.log(string.format(
        "Crop scan complete: %d field(s) checked, %d new crop(s) recorded",
        fieldCount,
        newCropCount
    ))
end
