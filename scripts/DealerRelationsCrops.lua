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
                    and not DealerRelations.Data:hasCropBeenGrown(fruitTypeName:upper()) then
                    DealerRelations.Data:addCropEverGrown(fruitTypeName:upper())
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

-------------------------------------------------------------------------------
-- Maps orchard/vineyard placeable config filenames to the fruit type they
-- represent. Unlike field crops, these are not read from fieldState —
-- the placeable's configFileName is the only signal that identifies which
-- crop it represents.
-------------------------------------------------------------------------------
DealerRelations.Crops.PLACEABLE_CROP_MAP = {
    ["data/placeables/orchards/grape/grapeSingleton.xml"] = "GRAPE",
    ["data/placeables/orchards/olive/oliveSingleton.xml"] = "OLIVE"
}

-------------------------------------------------------------------------------
-- Scans all placeables owned by the player's farm and records any orchard
-- or vineyard crop into the per-save crop history.
--
-- Rationale:
-- Orchards and vineyards are placeables, not fields, so they are invisible
-- to scanOwnedFields(). configFileName is the only available signal for
-- which crop a given placeable represents, since Placeable exposes no
-- generic fruit type field. See PLACEABLE_CROP_MAP.
--
-- Called once during map load, and again on every PERIOD_CHANGED event,
-- alongside scanOwnedFields() via the scanCropSources() coordinator.
-------------------------------------------------------------------------------
function DealerRelations.Crops:scanOwnedPlaceables()
    if g_currentMission == nil or g_currentMission.placeableSystem == nil then
        DealerRelations.warning("Cannot scan placeables: placeable system is unavailable")
        return
    end

    local farmId = g_currentMission.player and g_currentMission.player.farmId or 1
    local placeableCount = 0
    local newCropCount = 0

    for _, placeable in ipairs(g_currentMission.placeableSystem.placeables) do
        placeableCount = placeableCount + 1

        if placeable:getOwnerFarmId() == farmId then
            local fruitTypeName = DealerRelations.Crops.PLACEABLE_CROP_MAP[placeable.configFileName]

            if fruitTypeName ~= nil and not DealerRelations.Data:hasCropBeenGrown(fruitTypeName) then
                DealerRelations.Data:addCropEverGrown(fruitTypeName)
                newCropCount = newCropCount + 1
            end
        end
    end

    DealerRelations.log(string.format(
        "Placeable scan complete: %d placeable(s) checked, %d new crop(s) recorded",
        placeableCount,
        newCropCount
    ))
end

-------------------------------------------------------------------------------
-- Coordinates a full crop history scan across every crop source.
--
-- Acts as the orchestration point only: calls each source-specific scan
-- in turn. Adding a new crop source (e.g. a future greenhouse output, if
-- ever tied to demo eligibility) means adding one more call here, not
-- touching the callers of this function.
-------------------------------------------------------------------------------
function DealerRelations.Crops:scanCropSources()
    self:scanOwnedFields()
    self:scanOwnedPlaceables()
end
