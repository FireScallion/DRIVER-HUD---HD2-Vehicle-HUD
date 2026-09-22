# Changelog

## 1.3.2

- Fixed a FRV tire-state failure where one transient wheel HP value outside its configured range could make all four tire indicators unreadable.
- Invalid continuous HP now degrades per wheel to synchronized coarse state; unaffected wheels keep their continuous bars.
- Destroyed-wheel hub rendering remains independent and takes priority.
- Corrected session/reload log headers to report version 1.3.2.

## 1.3.1

- Integrated Bastion tank and FRV HUD support on the 1.2.1 tank baseline.
- Added HMG FRV and Supply FRV body/tire HUD support.
- Added continuous internal tire durability bars without numeric tire labels.
- Added destroyed-wheel hub representation.
- Added FRV body status colors: white above 75%, yellow at 75% or lower, red at 50% or lower.
- Added bilingual graphical FRV HUD position/scale configurator.
- Added per-game-process log rotation (`driver_hud.log` + `driver_hud_previous.log`).
- Preserved Bastion body HP, main ammunition, coax ammunition, reticle, and driver/gunner support.

## 1.2.1

- Stable Bastion tank HUD release.
- Driver/gunner hull HP display.
- Main-gun and coaxial machine-gun ammunition display.
- Center-screen reticle.
