# Changelog

## Version 0.19.0

- Added mass-based HP eligibility for `SPRAYERS` and `FERTILIZERSPREADERS` via new `MASS_MANAGED_CATEGORIES`, since neither carries a `neededPower` attribute in XML: required power computed from laden mass (dry mass + max capacity × heaviest supported fill type's real density) rather than read from XML.
- Added `MASS_TO_HP_RATIO` constant (~97 kg/HP), calibrated against a third-party mod's own documented "Required Power" values for the same real-world models and validated live in-game to a near-exact match.
- Fill type density now resolved live from `g_fillTypeManager` at read time rather than hardcoded — confirmed the internal `massPerLiter` field is stored at 1/1000th of the XML kg/L value and must be unscaled accordingly.
- Added `collectFillTypeNames()`, `getMaxFillTypeDensity()`, `getMassBasedRequiredPower()` to `DealerRelationsEquipment.lua`; `readEquipmentXml()` now also reads dry mass, max capacity, and fill types for every item.
- Existing `isCurrentlyEligible()` HP gate required no changes — mass-derived candidates flow through the same `IMPLEMENT`/`displayPower` check tractors and power-managed implements already use.
- Moved `AUGERWAGONS` from manual filter to `POWER_MANAGED_CATEGORIES`: confirmed both real models actually carry genuine `neededPower` data, so no mass-based logic was needed after all.
- Moved `TRAILERS` from manual filter to `EXCLUDED_CATEGORIES`: worst-supported-fill-type isn't representative for a category this broad (a grain trailer that also supports stone/dirt would gate on the heavier material), and a plain hauling trailer doesn't fit the purpose of a demo system in the first place.
- Added `dr_fillTypeDensities` and `dr_massEligibility` console commands (debug) for verifying fill type density unscaling and cross-checking cached vs. recomputed mass-based HP per candidate.
- Deferred: manure/slurry equipment, still earmarked for a future animal-related filter grouping.
- Deferred: self-propelled sprayer HP eligibility — would be a tractor-style `neededPower`/`getOwnedMaxTractorPower()` problem if ever needed, not mass-based; nothing currently indicates it's needed.

## Version 0.18.0

- Added bidirectional HP eligibility: implements require an owned tractor with sufficient power; tractor demos require sufficient power for the player's most demanding owned implement. No ceiling/floor beyond what's actually owned on the other side.
- Added per-engine-configuration expansion for tractors: each motor configuration is now its own demo candidate, not one entry per model.
- Added weighted demo selection: candidates chosen via HP-distance weighting instead of uniform random — tractor configs biased toward the cheapest that clears the floor, implements biased toward the closest match under the ceiling.
- Added `TRACTOR_CATEGORIES` and `POWER_MANAGED_CATEGORIES`: tractors and towed tillage implements (cultivators, disc harrows, mulchers, power harrows, rollers, spaders, stone pickers, subsoilers, weeders) removed from manual category filters, now fully automatic.
- Added `PLOWS` to `CROP_CATEGORIES`, gated on MAIZE/POTATO/SUGARBEET crop history; removed from manual filter.
- Generalized the missing-power default: any automatically-managed category (crop, forestry, power-managed) defaults to 0 HP when its XML defines none, rather than becoming invisible to eligibility and weighting.
- Added `HP_WEIGHT_CONSTANT` and `HP_WEIGHT_STEEPNESS` constants for tuning selection weighting.
- Added `dr_motorConfigs` console command (debug) for inspecting owned vehicle engine configuration data.
- Deferred: self-propelled harvester/forager HP eligibility and header-to-harvester connector compatibility.
- Deferred: mass/weight-based gating for sprayers and fertilizer spreaders (remain manually toggled).
- Deferred: UI rebuild, still pending further automated selection logic.

## Version 0.17.0

- Added crop-eligibility gating: equipment tied to specific crops becomes demo-eligible once the player has ever grown a fruit type it requires, resolved from XML (`fruitTypeCategories`, `fruitTypes`, or `vineFruitType`) rather than a hardcoded crop-to-category map.
- Added windrow-tied equipment eligibility: mowers, windrowers, balers, and bale transport unlock once the player has grown any crop whose fruit type produces a windrow, checked live against `g_fruitTypeManager` so mod-added windrow crops qualify automatically.
- Added orchard/vineyard crop tracking: new `scanOwnedPlaceables()` complements `scanOwnedFields()` so grape/olive equipment can gate on planted trees/vines, not just field crops.
- Added forestry toggle: forestry categories are gated behind a single player-facing setting (default off) rather than individual per-category filters, since forestry has no ownership signal to auto-detect.
- Consolidated `CROP_CATEGORIES` into a single table supporting three eligibility shapes: full XML-resolved multi-crop categories, single/fixed crop lists, and the `"WINDROW"` sentinel.
- Removed all crop-gated categories from `DEFAULT_CATEGORY_FILTERS`, since eligibility for those is now automatic rather than a manual player toggle.
- Added `LOWLOADERS` and `FORAGEHARVESTERCUTTERTRAILERS` to permanent category exclusions.
- Re-evaluated eligibility fresh on every demo selection (`isCurrentlyEligible()`) rather than caching at map load (`discover()`), since crop history, category toggles, brand toggles, and the forestry toggle can all change mid-save.
- Added console command `dr_forestryCount`: counts forestry-category items in the discovered equipment list.
- Added console command `dr_eligibleCount`: counts currently-eligible demo candidates by category, re-evaluated live rather than from a stale discovery-time snapshot.
- Deferred `TRAILERS` category reconsideration to a future version.
- Deferred HP-based eligibility (implement power requirements vs. owned tractor power, in both directions) to 0.18.0.
- Deferred demo configuration selection (currently always selects the first available configuration rather than choosing among available options) to 0.18.0.
- Deferred UI rebuild (`fs25_menuContainer`, full-width Overview+Financing, Help as popup dialog) until automated selection logic is more complete.

## Version 0.16.0

- Added financing system: loans originate from demo vehicles at relationship-based rates and terms.
- Added credit score system: derived at runtime from relationship level, loans repaid, and missed payments.
- Added missed payment ladder: four-level consequence system mirroring the overdue demo system.
- Added passive confidence recovery: +1 per month while relationship is negative.
- Added annual on-time payment confidence boost per loan.
- Added early payoff: clears loan with confidence boost and partial missed payment rehabilitation.
- Added Financing tab to the DR screen: displays credit score, finance rate, active loans, and Pay Off button.
- Added loan persistence: active loans, totalLoansRepaid, and totalMissedPayments saved and loaded per save.
- Added console commands: dr_status, dr_addTestLoan, dr_advanceLoan, dr_missPayment, dr_clearLoans, dr_setConfidence, dr_addRepaidLoan, dr_addMissedPayment, dr_clearMissedPayments, dr_resetAll.
- Added getMonthName() utility helper for calendar month index to name conversion.
- Added loan origination year and month fields for future display use.
- Fixed farm account access using stored farmId on loan record instead of g_currentMission.player.
- Fixed paging arrow navigation not triggering tab content refresh for Overview and Financing tabs.
- Fixed equipment image persisting on Overview when no offer or demo is active.
- Deferred principal payment UI to a future version.
- Deferred debt-to-asset ratio and base game loan integration to 0.17.0.

## Version 0.15.0

- Added Categories and Brands filter panels with scrolling layouts and linked sliders.
- Added alphabetical sorting of filter rows by display name.
- Added equipment image display on the Overview page using fs25_vehiclesDetailsImage profile.
- Added Help tab with in-screen documentation covering offers, demos, overdue rules, relationship system, and filters.
- Added dealer name persistence and random name assignment on new saves.
- Fixed duplicate notification bug on save/load using offerNotificationSent flag.
- Fixed nil key reference in loadActiveDemoOffer for overdueLevel and overdueClockStartDay fields.
- Fixed unclassified category logging for unknown store categories.
- Removed keybind (DR_OPEN_DEMO_OFFER) input action.
- Removed retired dialog screen files replaced by ESC menu dashboard.
- Code review pass: updated comments, corrected misattributed headers, removed duplicate function definitions, removed dead code.

## Version 0.14.0

- Added grace period and overdue system for unreturned demo equipment with four escalating consequence levels.
- Added demo offer suspension that applies from demo resolution date.
- Added 1% late fee at overdue level 3 with insufficient funds fallback.
- Added equipment repossession at overdue level 4.
- Fixed expired demo not showing return/buy buttons in Overview.
- Fixed category, brand, and operating hour display formatting in Overview.
- Updated return notice language from "machine" to "equipment".

## Version 0.13.0

- Added a dedicated Dealer Relations page to the ESC menu.
- Added Overview, Configuration, Categories, and Brands tabs.
- Added configurable Dealer Relations enable/disable setting.
- Added configurable debug logging setting.
- Added category filter configuration with savegame persistence.
- Added brand filter configuration with savegame persistence.
- Added relationship, confidence, active demo, and current offer overview display.
- Added internal tab navigation with paging arrow support.
- Added Dealer Relations ESC menu icon.
- Improved settings and filter management workflow.

## v0.12.0
* Added relationship-based confidence changes from demo actions.
* Added relationship levels and player-facing relationship names.
* Added relationship status display to startup, offer, and return/purchase dialogs.
* Added relationship-based demo purchase discounts.
* Added formatted money display for dealer prices.

## v0.11.0
* Refactored persistence save/load architecture.
* Improved code organization through helper extraction and modularization.
* Standardized persistence handling for demo offers and active demo vehicles.
* Improved code readability and maintainability.
* Updated project documentation and README.
* No gameplay changes.

## v0.10.1

* Fixed demo offer input registration.
* Improved reliability of demo offer hotkey handling.

## v0.10.0

* Added complete demo equipment lifecycle.
* Added demo vehicle spawning and tracking.
* Added demo return workflow.
* Added demo purchase workflow.
* Added demo lifecycle notifications.
* Added active demo persistence across save/load.

## v0.9.0

* Added demo offer interaction system.
* Added custom demo offer dialog.
* Added accept, decline, and cancel actions.
* Added demo offer notifications and reminders.
* Added configurable input action support.

## v0.8.0

* Added active demo offer system.
* Added persistent demo offers.
* Added automatic offer expiration.

## v0.7.0

* Added monthly demo candidate selection.
* Added duplicate offer prevention.
* Added recent demo history persistence.

## v0.6.0

* Added equipment discovery system.
* Added brand and category classification.
* Added equipment XML attribute discovery.
* Added power and role identification.

## v0.5.0

* Added brand classification system.
* Added equipment XML reading framework.

## v0.4.0

* Added equipment discovery and category filtering.

## v0.3.0

* Added confidence save/load persistence.

## v0.2.0

* Added confidence-based relationship levels.

## v0.1.0

* Initial project foundation.
* Added dealer confidence data model.
* Added logging framework.
