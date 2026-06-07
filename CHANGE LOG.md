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

