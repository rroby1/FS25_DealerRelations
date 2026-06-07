## 0.1.0

### Added
- Established new Dealer Relations baseline.
- Added compact `modDesc.xml` loading through `DealerRelations.lua`.
- Added `DealerRelationsDebug.lua` logging module.
- Added `DealerRelationsData.lua` data model module.
- Added default relationship and confidence values.
- Added constants for valid relationship and confidence ranges.
- Added guarded getters and setters for dealer data.

### Notes
- Design documentation remains outside the mod repository.
- Data module defines defaults and runtime access only.
- Persistence and gameplay logic are not implemented yet.

## 0.2.0

### Changed
- Relationship level is now derived from confidence.
- Relationship level is no longer stored directly.

### Added
- Confidence-based relationship level calculation.
- Validation testing for confidence thresholds.
- Validation testing for confidence guardrails.

### Benefits
- Prevents confidence and relationship level from becoming inconsistent.
- Relationship threshold changes automatically apply to existing savegames.
- Reduces persisted data requirements.

## 0.3.0

### Added
- DealerRelationsPersistence module.
- XML save/load support for confidence values.

### Changed
- Relationship level is derived from confidence and is no longer persisted.
- Dealer Relations data is loaded during map initialization.
- Dealer Relations data is saved during the game save process.

### Verified
- Confidence survives save/load.
- Relationship level restores correctly from persisted confidence.

## 0.4.0

### Added
- Equipment discovery module.
- In-memory demo candidate list.
- Equipment category classification table.
- Warning logs for unclassified equipment categories.

### Verified
- FS25 store items are readable at load.
- All discovered categories are classified.
- Demo candidate list builds successfully.
- Relationship persistence still loads correctly.

## Version 0.5.0

### Added

* Brand classification system (`BRANDS` table).
* Equipment XML reader (`readEquipmentXml()`).
* Brand discovery foundation for future demo filtering.
* Explicit brand classification rules:

  * `true` = eligible
  * `false` = excluded
  * `nil` = unclassified (excluded by default)

### Changed

* Refactored equipment XML access into a reusable helper function.
* Continued use of explicit classification tables for deterministic filtering behavior.

### Removed

* Temporary XML loading diagnostic code.
* Temporary brand discovery export system.
* Temporary brand discovery save callback.

### Verified

* Store items discovered: 1319
* Demo candidates discovered: 559
* Equipment XML loading verified on all eligible candidates.
* Save/load persistence functioning correctly.
* No unclassified category warnings.
* No XML loading failures.

### Notes

This release establishes the foundation for brand-based equipment filtering while maintaining a clean and stable codebase. Brand filtering logic and demo candidate selection will be implemented in future releases.
