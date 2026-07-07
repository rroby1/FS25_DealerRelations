# FS25 Dealer Relations

Dealer Relations is a Farming Simulator 25 mod that adds dealer relationship mechanics and equipment demo programs.

**Status:** Early Development

## Current Features

### Relationship System

* Dealer confidence tracking
* Confidence gains and losses from player actions
* Relationship level calculation
* Relationship status names
* Relationship-based purchase discounts
* Save/load persistence

### Equipment Discovery

* Equipment discovery from the in-game store
* Brand filtering
* Brand identification
* Power and equipment role identification
* Automatic eligibility by equipment type -- no manual category toggles:
  * Crop-tied equipment (headers, harvesters, cutters) gated on crop history
  * Windrow-tied equipment gated on windrow-capable crop history
  * Animal-tied equipment (manure/slurry/straw handling) gated on owned husbandry
  * Forestry equipment gated on a manual Forestry setting (no reliable auto-detection signal)
  * Bundled equipment (header/trailer, slurry tank/tool, seeder/seed tank) resolved as combined primary/secondary demo pairs
* HP and mass-based power eligibility for tractors and implements, weighted toward the closest match rather than uniform random selection
* Savegame-persistent brand filters

### Demo Program

* Monthly demo offer generation
* Duplicate offer prevention
* Demo offer acceptance and decline
* Demo vehicle spawning
* Active demo vehicle tracking
* Demo offer persistence
* Demo vehicle persistence across save/load
* Operating-hour-based demo limits, scaled to month length

### Demo Lifecycle

* Demo expiration tracking
* Open demo detection
* Return workflow
* Purchase workflow
* Relationship-based purchase pricing
* Demo vehicle removal on return
* Demo ownership conversion on purchase
* Four-level escalating overdue consequence system: warning, confidence penalty with offer suspension, additional penalty with late fee, repossession

### Financing

* Dealer-issued loans on demo equipment purchases
* Credit-score-derived finance rate
* Monthly payment processing
* Early payoff with confidence boost
* Multiple simultaneous loans, processed highest rate first
* Savegame-persistent loan state

### User Interface

* Startup relationship notifications
* Relationship display in demo offer dialogs
* Relationship display in return/purchase dialogs
* Purchase discount display
* Purchase price display
* Dedicated Dealer Relations ESC menu page (Overview, Financing, Settings tabs)
* Overview dashboard
* Financing dashboard with loan table and pay-off actions
* Settings tab: enable/disable, debug logging, Forestry toggle, brand filter management
* Standalone Help dialog with values sourced from live settings/constants
* Relationship and confidence overview display
* Active demo and current offer overview display

### Settings

* Dealer Relations enable/disable setting
* Debug logging setting
* Forestry equipment toggle
* Savegame-persistent settings

## Development Status

Dealer Relations is under active development and is not yet considered feature complete.

Several planned systems are not yet implemented, including:

* Self-propelled harvester/forager HP eligibility and header-to-harvester connector compatibility
* Mass/weight-based gating for sprayers and fertilizer spreaders beyond current HP proxy
* Further Overview screen layout revisions
* Additional dealer relationship features

Current releases are intended for development and testing.