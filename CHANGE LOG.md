# Changelog

## Version 0.24.0

- Removed the Category filter screen and its underlying data: `categoryFilters` field, `initializeCategoryFilters()`, `getCategoryFilters()`, `setCategoryEnabled()`, `isCategoryEnabled()`, `DEFAULT_CATEGORY_FILTERS`, and the persistence load path, all now dead following the 0.21.0/0.22.0 filter retirement.
- Fixed: `MASS_MANAGED_CATEGORIES` (SPRAYERS, FERTILIZERSPREADERS) had no terminal eligibility check and was silently falling through to the now-dead `isCategoryEnabled()` fallback, making both categories permanently ineligible for demo offers. Added an explicit terminal check mirroring `HARVESTER_CATEGORIES`/`TRACTOR_CATEGORIES`.
- Fixed: duplicate `POWER_MANAGED_CATEGORIES` check introduced during the above fix.
- Merged Configuration and Brands tabs into a single Settings tab, ordered General options → Forestry toggle → Brand filters.
- Added Forestry Equipment toggle (`isForestryEnabled()`/`setForestryEnabled()`).
- Fixed: duplicate Debug option row introduced during the Settings merge.
- Renamed "Brands" section to "Brands Filter"; tightened Settings panel spacing to enlarge the brand list scroll window.
- Removed Help tab/panel; added `DealerRelationsHelpDialog.xml`/`.lua` as a standalone dialog opened via `g_gui:showDialog()`.
- Help text is now built from a template with live values substituted at open-time (dealer hours, current demo hour limit, late fee percent, max relationship discount) rather than hardcoded, so it can't drift out of sync with future tuning. Overdue-penalty language kept qualitative (no exact confidence values shown).
- Added Help to the native ESC menu footer bar via `menuButtonInfo`/`MENU_EXTRA_1` (bound to X by default), after an in-page button attempt proved unreliable across two iterations.
- Widened Overview and Financing panels from 900px to 1400px by dropping the `fs25_subCategorySelectorTabbedContainer`/`emptyPanel` wrapper workaround in favor of a plain `GuiElement` with a widened `fs25_subCategoryContainer`; confirmed against a reference mod using the same base class that the 900px cap was self-imposed, not an engine limit.
- Spread Financing's loan table columns to use the reclaimed width, fixing equipment-name truncation (Equipment column 200px → 400px).
- Split `DealerRelationsScreen.lua`: Overview-tab logic moved to new `DealerRelationsOverviewPanel.lua`, Financing-tab logic to new `DealerRelationsFinancingPanel.lua`. No behavior change.
- Deferred: further Overview screen redesign, no concrete plan yet.

## Version 0.23.0

- Fixed `isDemoCandidate()` logging `Unclassified equipment category: FORAGEHARVESTERS` and silently excluding all forage harvesters from discovery — `FORAGEHARVESTERS` had never been added to any category bucket. Added new `FORAGEHARVESTER_CATEGORIES` and `FORAGEHEADER_CATEGORIES` tables and wired both into `isDemoCandidate()`'s classification check.
- Confirmed via XML inspection (`series9000.xml`, `fr780.xml`, `plus360_johnDeere.xml`/`plus360.xml`) that forage cutters carry combination data structured identically to grain headers: a shared base cutter (e.g. Kemper) combos to multiple harvester brands, and each brand-specific rebadge narrows its own combo list down to one harvester via `<clearList keepIndex="1">` — the same rebadge-narrowing pattern already confirmed for grain headers in 0.21.0.
- Confirmed forage cutters do **not** carry a usable power signal analogous to grain headers' `powerConsumer#neededMaxPtoPower`: `plus360.xml` carries two different, unreconciled power values (`storeData.specs.neededPower=580`, `powerConsumer#neededMaxPtoPower=150kW`≈204hp), and which one (if either) reflects what the harvester chassis needs could not be confirmed. Design decision: forage harvester/cutter eligibility is **combo-only**, no HP fallback — a missing combo entry means ineligible, full stop.
- `readEquipmentXml()`: added an `elseif FORAGEHEADER_CATEGORIES[category] == true` branch, checked *before* the generic `storeData.specs.neededPower` check, so forage cutters don't fall into the `IMPLEMENT` powerRole and get incorrectly gated against tractor HP using that ambiguous `neededPower` value. `powerRole` intentionally left `"NONE"` for this category.
- `isCurrentlyEligible()`: added combo-only gate blocks for `FORAGEHEADER_CATEGORIES`/`FORAGEHARVESTER_CATEGORIES`, mirroring the header/harvester gate shape. `FORAGEHARVESTERCUTTERS` remains dual-classified in `CROP_CATEGORIES` (crop-history gating still applies on top of the combo gate, same pattern as `CORNHEADERS`/`CUTTERS`/`SPECIALHEADERS`); `FORAGEHARVESTERS` has no other category membership, so its block returns directly rather than falling through to `isCategoryEnabled()`.
- **Brand-safety fix, applied to both the new forage gate and the existing grain header/harvester gate**: the original header/harvester logic treated combo match and HP match as independent OR'd signals, meaning a header with real (but non-matching) combo data could still pass eligibility on raw horsepower alone — e.g. a JOHNDEERE-only header could be handed to a CLAAS-only owner if the CLAAS combine had enough HP. Fixed so that if a candidate declares *any* combo data at all, that data must actually match; HP fallback is now only used when a candidate declares zero combo entries.
- Caught via live testing, not review: the discovery-time cache (`equipmentByXmlFilename`, used by `isCombinationMatchedToOwnedCategory()`) was never extended to include the two new forage categories, so combo matching against an owned forage harvester/cutter could never succeed regardless of ownership. Fixed in `discover()`.
- Added `dr_forageMatch` (raw combo/configFileName dump, mirrors `dr_headerHarvesterMatch`) and `dr_forageEligibility` (comboMatch/eligible per candidate, combo-only) console commands.
- Corrected `dr_headerHarvesterEligibility`: previously reported `comboMatch`/`hpMatch` as independent booleans, which could show a misleadingly-passing `hpMatch=true` for a candidate that's actually ineligible under the new combo-required-if-present rule. Now reports which signal was actually used (`signalUsed`) and the real `eligible` result.
- Verified live: forage combo-only gating confirmed across a 27-candidate sweep (all Kemper/New-Holland-badged cutters correctly eligible against an owned `fr780`; all JOHNDEERE-badged and other-brand cutters correctly excluded; no cutter owned → both `FORAGEHARVESTERS` and `FORAGEHARVESTERCUTTERS` correctly ineligible in both directions). Grain header/harvester brand-safety fix regression-verified across a 46-candidate sweep with only an `MF 8570` owned — confirmed the specific cross-brand leak this fix targets (`VARIO 620`, 67.98hp, previously would have HP-matched against the 250hp Massey combine) is now correctly blocked.
- Not exercised by this round of testing: the "zero combo data at all" HP-fallback path on the grain header/harvester side — no header/harvester with an empty combo list was present in the currently active mod set to test against. Fallback logic itself is unchanged from 0.21.0/0.22.0, but worth a dedicated check if a no-combo-data example turns up later.

## Version 0.22.0

- Implemented the header↔trailer fallback deferred from 0.21.0: headers with no `storeData.specs.combination` trailer declaration now resolve via derived width/length matching instead of remaining permanently ineligible.
- Added `sizeWidth`/`sizeLength`/`workingWidth` reads to `readEquipmentXml()` (`vehicle.base.size#width`/`#length`, `vehicle.storeData.specs.workingWidth`), read unconditionally for any category and passed through `resolveDemoCandidate()`'s candidate table — checked against the earlier `combinationXmlFilenames` omission bug from 0.21.0 to make sure the same "silently dropped" mistake wasn't repeated.
- Confirmed header dimension convention is inverted from every other vehicle type: `size.width` is a header's longest measurement (the span across the cutting face, perpendicular to travel direction), `size.length` is the short front-to-back housing depth — opposite of normal vehicles, where `length` is the long axis. Confirmed via `header4408.xml`/`powerFlow.xml`. Fallback rule compares header `size.width` (falling back to `workingWidth` if missing) against trailer `size.length`, since a header rides lengthwise on the trailer bed.
- `getCompatibleTrailerForHeader()` extended with the fallback pass: combo match still tried first and takes priority; fallback selects the **smallest sufficient trailer**, not the first one that clears the size requirement, avoiding pairing a header with a needlessly larger/costlier trailer when a properly-sized one is available.
- Mid-implementation discovery, caught via live testing rather than review: three corn headers (`diamant8`, `northStar1230FB`, `headerC16F`) showed `size.width` *smaller* than `workingWidth` — the opposite relationship from every other header checked. Root cause: these are folding headers, and `size.width` reflects the folded transport footprint, not the true working span.
- Reframed the fix per design feedback: a folding header's entire purpose is not needing a trailer at all, not needing a different width number. Added `isFoldable` detection via `xmlFile:hasProperty("vehicle.foldable")` (existence check only, no schema registration needed) as a hard exemption from the trailer requirement in `isCurrentlyEligible()` and from companion lookup in `createDemoOfferFromCandidate()`.
- Confirmed `isFoldable` is a reliable, structural signal across genuinely different header types and mod authors, not a `CORNHEADERS`-specific quirk: present on the three corn headers, `CressoniCRX720` (a folding grain header from a different mod entirely), and `fd140` (MacDon FlexDraper, found live during testing, not one of the original examples).
- Confirmed the equivalent seed tank fallback from the 0.21.0 open-items list is unnecessary and requires no work: unlike headers, a seeder/planter with no seed tank combo genuinely doesn't need one — "no combo" already means the correct thing today. 0.22.0 scope narrowed to header↔trailer only.
- Added/updated `dr_trailerFallback` console command for validation — caught mid-session that it needed an explicit `isFoldable` update, since it independently reimplements the production logic rather than calling into it and doesn't automatically inherit logic changes.
- Verified live across a 32-header sweep: all combo-matched headers unchanged from 0.21.0 behavior; all four folding headers correctly exempted with no trailer match attempted; all non-folding no-combo headers (`PowerFlow`, `PowerFlow 30FT`, `DynaFlex 9255`) correctly resolve via fallback to the smallest sufficient trailer.
- Open items carried forward: generic multi-brand header exclusion still undocumented-in-code (design decision only); fixed demo spawn point/rotation for two-vehicle offers; empty Categories settings tab — both deferred to Rick's planned full screens pass.

## Version 0.21.0

- Resolved header/harvester/trailer eligibility in full, replacing the last two active manual category toggles (`HARVESTERS`, `CUTTERTRAILERS`) with live combo/HP-based gates, following the same automatic-eligibility precedent established for crop/animal/mass-managed categories.
- Added `HEADER_CATEGORIES` (`CORNHEADERS`, `CUTTERS`, `SPECIALHEADERS`) and `HARVESTER_CATEGORIES` (`HARVESTERS`) tables. `COMBINEWINDROWER`/`VEGETABLEHARVESTERS` explicitly excluded from the new gate — remain crop-eligibility-only, not cutting-front attachments.
- Implemented `storeData.specs.combination` reading generically in `readEquipmentXml()` (`combinationXmlFilenames`), usable by any category rather than header-specific — the same native FS mechanism confirmed present on headers, harvesters, cutter trailers, seed tanks, and seeders/planters.
- Added `isCombinationMatch()`/`isCombinationMatchedToOwnedCategory()` — checked bidirectionally, since combo data is confirmed unreliable/incomplete even for a mod author's own harvester+header pair (`headerC16F` has harvester combos but no trailer combo; `delta9380` has none at all). Design rule: combo match OR HP fallback, never combo-exclusive — absence of a declared combo is never treated as evidence of incompatibility.
- Added header-side HP derivation: headers carry no `storeData.specs.neededPower`, so required HP is derived from the raw `powerConsumer#neededMaxPtoPower` (kW) via new `KW_TO_HP_RATIO` constant, under a new `powerRole = "HEADER"` kept distinct from `"IMPLEMENT"` so headers are never checked against tractor HP.
- Added `getOwnedMaxHarvesterPower()`/`getOwnedMaxHeaderRequiredPower()`, mirroring the existing tractor/implement HP-lookup pair.
- Generic multi-brand headers (selectable per-brand couplers via `inputAttacherJointConfigurations`, confirmed via `CressoniCRX720`) excluded from the demo pool by design decision — **not yet implemented in code**, deferred pending in-game verification of actual coupler behavior (Claas Lexion vs. Evion, Fendt vs. MF Ideal platform-sharing) that hasn't been tested.
- Built full bundling mechanism from scratch for header↔trailer, discovering along the way that the "reuse the 0.17.0 slurry bundling pattern" assumption was wrong — slurry was eligibility-gating (`ownsAccumulatedSlurry()`), not actual two-vehicle bundling; no working precedent existed to extend.
- Added `getCompatibleTrailerForHeader()`, two-vehicle async spawn (`startCompanionDemoVehicle`/`onCompanionDemoVehicleLoaded`, primary-then-companion sequencing with all-or-nothing rollback on companion load failure), and `role` (`PRIMARY`/`SECONDARY`) finally wired to real behavior after sitting as a stub since introduction.
- Companion lifecycle explicitly has no independent clock — all five lifecycle check functions (`checkExpiredDemos`, `checkDemoOperatingHours`, `checkEndingDemoNotices`, `checkReturnDemoNotices`, `checkOverdueDemos`) gated on `role == "PRIMARY"` (explicit check, not reliance on nil fields — confirmed `loadActiveDemoVehicles()` defaults missing numeric fields to `0`, not `nil`, which would have made a companion self-expire immediately after any save/reload). Primary's state (expiration, Miss 4 repossession) cascades onto its companion explicitly.
- `returnActiveDemo()`/`buyActiveDemo()`/`openExpiredDemoDialog()`/Overview display (`updateOverviewValues()`) all updated to resolve and act on both vehicles as one unit, combined pricing shown consistently everywhere a price is displayed.
- Extended the same bundling mechanism to slurry (`SLURRYTANKS` primary/`SLURRYTOOLS` secondary) and seed tanks (`PLANTERS`/`SEEDERS` primary/`SEEDTANKS` secondary, optional companion never gating primary eligibility) — nearly all downstream infrastructure (persistence, spawn, lifecycle, UI, display) proved fully generic and needed zero changes for either.
- Fixed a real bug caught during testing: `CUTTERTRAILERS` initially remained independently offerable despite the bundling logic being built, since it still fell through to `isCategoryEnabled()` with no explicit rejection — added unconditional standalone-rejection blocks for `CUTTERTRAILERS`/`SLURRYTOOLS`/`SEEDTANKS` in `isCurrentlyEligible()`.
- Retired the manual category filter system entirely — `DEFAULT_CATEGORY_FILTERS` emptied to `{}`, no category in the mod is manually toggleable any longer. Settings screen's "Categories" tab now always renders empty; explicitly deferred to a later full screens pass rather than fixed now.
- Discovered and fixed a systemic bug unrelated to header/trailer work but found while testing it: `readEquipmentXml()`'s raw `loadXMLFile()`/`getXMLInt()` API doesn't resolve `<parentFile>`/`<set>` rebadge inheritance (confirmed via `dr_testXmlFileLoad`: raw read returned `nil` for `af11.xml`'s inherited power, `XMLFile.load()` with schema returned the correct `775`). Rewrote `readEquipmentXml()` to use `XMLFile.load()` + a one-time-built schema, matching the mechanism the game itself uses in `Vehicle:load()`. Fixed every previously-`nil` rebadged vehicle across the harvester/header list (`AF11`, `CR11 Gold Edition`, `LEXION 6900`, `5275 C SL`, multiple `FD250 FlexDraper®` variants, `980CR 8-30`/`18-30`), and improves accuracy for any rebadged vehicle in any category, not just headers/harvesters.
- Fixed two additional bugs found only through direct console-command verification (`dr_headerHarvesterMatch`), not caught by review alone: combination `xmlFilename` values carry an unresolved `$data` template prefix never stripped before comparison (fixed by stripping a leading `$`), and `equipmentByXmlFilename` — the cache both combo-matching and `getOwnedMaxHeaderRequiredPower()` depend on — was only ever populated for `powerRole == "IMPLEMENT"`, silently excluding every header and harvester from the owned-vehicle lookup regardless of the other two fixes.
- Fixed a separate pre-existing bug surfaced only because seed tank testing was the first time `PLANTERS`/`SEEDERS` eligibility was checked directly against real crop history: `readEquipmentXml()` only ever read `<cutter>`/`<vineCutter>` fruit-type elements, never `<sowingMachine><seedFruitTypeCategories>`, meaning seeders/planters have never been able to pass crop-eligibility since the category was added. Fixed with one additional `getValue()` fallback; confirmed against `maps_fruitTypes.xml` category definitions (`SOWINGMACHINE`, `PLANTER`, `SUGARCANE_PLANTER`, `PLANTER_SMALL`) and verified live.
- Added debug console commands `dr_headerHarvesterMatch`, `dr_headerHarvesterEligibility`, `dr_testXmlFileLoad` — used throughout to isolate the four bugs above; none of them would have been caught by code review alone.
- Verified live: header/harvester combo and HP eligibility in both directions, slurry tank/tool bundling, seeder/planter/seed tank bundling (including the fruit-type fix), rebadge fix across the full affected vehicle list, and confirmed `CUTTERTRAILERS`/`SLURRYTOOLS`/`SEEDTANKS` no longer independently offerable via `dr_eligibleCount`.
- Deferred: header↔trailer fallback for headers with no declared trailer combo (moved to 0.22.0). Fixed demo spawn point/rotation for two-vehicle offers flagged as a placeholder needing revisiting.

## Version 0.20.0

- Resolved Bucket D (animal-tied equipment) in full: `FORAGEMIXERS`, `MANURESPREADERS`, `SLURRYTANKS`, `SLURRYTOOLS`, `SLURRYTRANSPORT`, `STRAWBLOWERS`, and `LOADERWAGONS` all moved off manual category filters onto live, ownership-based eligibility gates.
- Added `ANIMAL_CATEGORIES` table and `isAnimalEligible()` dispatcher to `DealerRelationsEquipment.lua`, following the same per-category-rule pattern as `CROP_CATEGORIES`/`isCropEligible()` rather than a flat toggle table, since the four gate shapes (cattle-only, cattle+heap, slurry accumulation, cattle+straw-barn) aren't interchangeable.
- Added four new live detection functions: `ownsCattleNow()`, `ownsAnyManureHeapPlaceable()`, `ownsAccumulatedSlurry()`, `ownsStrawCapableBarn()`.
- Cattle detection confirmed via `AnimalType.COW` (barn-level `getAnimalTypeIndex()`/`getNumOfAnimals()`), not the originally planned `COW_` subType-prefix match — animal type is a single barn-level value, not something requiring per-cluster inspection, and this correctly covers all cattle breeds (including water buffalo, highland cattle) as subtypes under one type rather than needing each enumerated.
- Manure heap linkage confirmed to be readable directly off the barn placeable itself via `getHusbandryCapacity(FillType.MANURE)`, rather than searching for a separate manure heap/extension placeable — barns never store dry manure internally (capacity is `0` until a heap is linked as a storage extension), so capacity `> 0` is itself the live "heap connected" signal. Removed the need for a dedicated heap-search function entirely.
- Slurry accumulation and straw capability both resolved to direct live API calls instead of save-XML parsing: `getHusbandryFillLevel(FillType.LIQUIDMANURE)` for accumulation, `spec_husbandryStraw ~= nil` for straw capability — both confirmed against real GIANTS specialization source (`PlaceableHusbandry.lua`, `PlaceableHusbandryAnimals.lua`, `PlaceableHusbandryStraw.lua`) rather than assumed from save file shape alone.
- `LOADERWAGONS` required no dedicated function at all — joined `CROP_CATEGORIES` under the existing `"WINDROW"` rule, since `hasGrownAnyWindrowCrop()` (built in 0.17.0) already covers grass/hay and straw-dropping cereals like wheat in one flag with no hardcoded crop list.
- Fixed a real discovery-time bug caught during testing: `isDemoCandidate()`'s category allow-list checked six specific tables but not the new `ANIMAL_CATEGORIES`, silently excluding all seven categories from `equipmentList` before `isCurrentlyEligible()` ever ran. All animal-tied categories showed zero discovered candidates until this was added.
- Added `dr_animalTypes`, `dr_husbandryCapacity`, and `dr_animalCategoryCount` console commands (debug) — used to confirm the `AnimalType` enum, verify barn/heap capacity behavior live (`cowBarnSmall` vs. `cowBarnMedium` with heap linked), and isolate the discovery-vs-eligibility bug above.
- Verified live in-game, both negative and positive cases: starting cows alone correctly enabled only `FORAGEMIXERS`; adding a straw-capable barn with a linked manure heap correctly added `MANURESPREADERS` and `STRAWBLOWERS` without affecting any other category's count.
- Not yet stress-tested live: `SLURRYTANKS`/`SLURRYTOOLS`/`SLURRYTRANSPORT` flipping eligible once `LIQUIDMANURE` actually accumulates — logic confirmed via the same API, just not observed live due to production time.
- Open question carried forward from the design note: whether `LIQUIDMANURE` persists in storage after a player sells off all cattle, which would leave a farm eligible on old slurry alone. Not stress-tested.
- Deferred: HP-aware selection for equipment-pairing dependencies (harvester/header) and broader HP-awareness beyond mass-managed/tractor categories — earmarked as its own future bucket, likely alongside finance-aware selection.

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
