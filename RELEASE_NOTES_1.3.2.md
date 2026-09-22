# DRIVER HUD 1.3.2

## Highlights

- Bastion tank HUD: hull HP, main-gun ammo, coax ammo, center reticle, driver/gunner support.
- HMG FRV and Supply FRV HUD: body HP plus four independent tire-condition bars.
- Continuous tire durability bars; fully destroyed tires use a hub-only visual state.
- FRV body warning colors: yellow at 75% or lower, red at 50% or lower.
- Bilingual graphical FRV HUD position/scale configurator.
- Per-game-process log rotation keeps `driver_hud.log` for the current run and `driver_hud_previous.log` for the previous run.
- 1.3.2 fixes the case where one transient invalid wheel-HP sample could make all four tires appear unreadable.

## Requirement

Bingus Shared Loader v15 / API 1 must be installed separately:
https://www.nexusmods.com/helldivers2/mods/16292

## Update

Disable/remove older DRIVER HUD, Resolver, FRV test or Probe packages before installing. Do not enable multiple DRIVER HUD versions at the same time. Run Purge → Deploy after updating.
