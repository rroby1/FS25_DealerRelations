# Changelog

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
