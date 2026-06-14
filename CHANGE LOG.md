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

## v0.6.0
### Added
- Equipment discovery system.
- Category classification system.
- Brand discovery system.
- XML attribute discovery system.
- Power attribute discovery system.
- Equipment record generation from store items.

### Equipment Records
Added support for storing:
- Name
- Brand
- Category
- Price
- XML filename
- XML brand
- Power role
- Display power
- Minimum power
- Maximum power

### Discovery Pipeline
Store Data
→ Category Filter
→ XML Read
→ Brand Discovery
→ Power Discovery
→ Equipment Record

### Discovery Results
- Store Items Scanned: 1319
- Demo Candidates Identified: 559

### Verified Power Roles
- SELF_PROPELLED
- IMPLEMENT
- NONE

### Internal Changes
- Refactored equipment discovery into a dedicated module.
- Established equipment record structure for future demo selection.
- Added XML parsing framework for equipment metadata extraction.
- Added logging for discovery and attribute analysis.

### Notes
- Establishes the equipment data foundation required for future demo candidate selection and dealer offer systems.

## v0.7.0

### Added
- Monthly demo evaluation system.
- Random demo candidate selection from eligible equipment.
- Duplicate prevention using recent demo candidate history.
- Demo candidate key generation.
- Brand eligibility filtering.
- Equipment power classification support.
- XML-based equipment metadata extraction.
- Persistence for recent demo candidate history.

### Improved
- Equipment discovery and candidate filtering.
- Equipment metadata collection.
- Internal documentation and code organization.

### Changed
- Demo offers are now evaluated once per in-game month.
- Demo candidate selection now respects recent offer history.

### Fixed
- Monthly demo checks triggering repeatedly within the same month.
- Persistence loading for recent demo candidate history.
- Various save/load reliability issues discovered during development.

### Cleanup
- Removed temporary testing hooks.
- Removed obsolete debugging and XML diagnostic logging.
- Simplified startup and persistence logging.

## v0.8.0

### Added
- Active demo offer system.
- Active demo offer data model and accessors.
- Monthly demo offer creation from selected candidates.
- Persistence for active demo offers.
- Active demo offer loading during savegame startup.
- Automatic expiration of previous-month demo offers.

### Improved
- Monthly demo workflow now creates persistent offers.
- Save/load process now restores active offer state.
- Lua file indentation standardized.

### Changed
- Monthly demo evaluations now generate and store active offers.
- Previous-month offers are automatically removed when a new month begins.

### Cleanup
- Additional logging review and refinement.
- Consistent formatting across updated modules.

## v0.9.0 - Demo Offer Interaction System

### New Features

* Added custom Dealer Relations demo offer dialog.
* Added Accept, Decline, and Cancel response options for demo offers.
* Added keyboard and mouse support for offer responses.
* Added reminder notification when loading a save that contains an active demo offer.
* Added configurable input action for opening the active demo offer.

### User Interface

* Added custom XML-based offer dialog.
* Added offer details display including equipment name, brand, category, power, and price.
* Added dedicated keyboard shortcuts:

  * Enter = Accept
  * X = Decline
  * Esc = Cancel
* Added localization support for the demo offer input action.

### Persistence

* Active demo offers now remain available after saving and reloading the game.
* Offer reminder notification appears when an active offer is loaded from a save.

### Internal Changes

* Added DealerRelationsDemoOfferDialog controller and XML layout.
* Expanded DealerRelationsUI module to manage offer notifications and dialog interaction.
* Improved separation between persistence, UI, and offer interaction systems.

### Known Limitations

* Accepting a demo offer currently records the acceptance but does not yet spawn demo equipment.
* Relationship impacts for accepting or declining offers are planned for a future update.
* Demo equipment tracking and return workflows are planned for a future update.

# v0.10.0

## Added

### Complete Demo Machine Lifecycle

Implemented the full demo equipment workflow from offer generation through final disposition.

#### Demo Offer System
- Monthly demo offer generation.
- Demo offer persistence across save/load.
- Demo offer expiration handling.
- Prevention of duplicate active offers.
- Open demo tracking to prevent overlapping offers.

#### Demo Acceptance
- Accept demo offers through the Dealer Relations UI.
- Spawn demo equipment at the dealer location.
- Track spawned demo vehicles using vehicle unique IDs.
- Persist active demo vehicle data across save/load.

#### Demo Notifications
- End-of-demo reminder notification.
- Return reminder notification.
- Time-based demo lifecycle messaging.

#### Demo Return Workflow
- Return demo equipment through the demo management dialog.
- Locate demo vehicles by unique ID.
- Remove returned demo vehicles from the game.
- Clear active demo tracking after successful return.
- Allow future demo offers once no active demos remain.

#### Demo Purchase Workflow
- Purchase demo equipment instead of returning it.
- Convert demo equipment ownership from demo status to owned status.
- Calculate purchase price from original vehicle value.
- Deduct purchase cost from the player's farm account.
- Mark demo records as purchased.
- Allow future demo offers once the active demo is resolved.

## Persistence

### Active Demo Vehicle Tracking
- Save active demo vehicle records to `dealerRelations.xml`.
- Load active demo vehicle records on game load.
- Track demo state using vehicle unique IDs rather than runtime object references.
- Support return and purchase actions after save/load cycles.

## Verification

Successfully tested:

- Demo offer generation.
- Demo offer persistence.
- Demo acceptance.
- Demo vehicle spawning.
- Active demo tracking.
- Save/load of active demos.
- Demo expiration handling.
- Demo return workflow.
- Demo purchase workflow.
- Ownership conversion.
- Purchase price calculation.
- Farm money deduction.
- Future offer generation after return.
- Future offer generation after purchase.

# v0.10.1

## Fixed

### Demo Offer Input Registration

Resolved an issue where the `DR_OPEN_DEMO_OFFER` input action behaved inconsistently between new and existing saves.

#### Symptoms
- New saves: demo offer hotkey did not respond.
- Existing saves: demo offer hotkey responded correctly.
- Input action appeared in the Controls menu but was not reliably firing the callback.

#### Root Cause
Dealer Relations was registering its input action from the mod update loop rather than through the GIANTS player input registration lifecycle. Additionally, the `registerActionEvent()` parameter configuration did not match the pattern used by known-working FS25 player action registrations.

#### Changes
- Removed update-loop based input registration.
- Integrated demo offer input registration into the GIANTS player input registration flow using:
  - `PlayerInputComponent.registerGlobalPlayerActionEvents`
- Updated `registerActionEvent()` parameters to match the working player-action pattern used by other FS25 mods.

#### Verification
Tested successfully on:
- New save games
- Existing save games

Results:
- Demo offer hotkey appears in Controls.
- NUMPAD 9 opens the demo offer dialog.
- No errors or warnings generated during testing.