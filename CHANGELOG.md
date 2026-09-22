# DRIVER HUD 1.3.4

Performance update for Bastion, HMG FRV and Supply FRV.

- Reduce ownership enumeration during stable native-bound vehicle use.
- Skip redundant tank binding reads.
- Reuse memory protection checks within each native sample and batch selected reads.
- Add optional performance diagnostics (`perf=true`, disabled by default).
- Preserve tank ammunition cadence/logic, FRV health cadence and HUD layout.

Requires Bingus Shared Loader v15 / API 1. Disable old DRIVER HUD versions before installing, then Purge / Deploy. GitHub release includes the bilingual FRV configurator. Nexus distributes the configurator as a separate Optional File.

33 focused offline checks passed. Live game FPS improvement has not been measured here.

# Changelog

## 1.3.3

- Isolate optional SyncedHealth failures from a valid Health sample. Body and destroyed-wheel states remain available; unverified precision is not presented as exact HP.
- Retain an already confirmed HUD for at most 0.3 seconds after the last valid native relation on a classified short read. Explicit exit, observed identity changes, failed owner checks, and compatibility failures do not receive this grace.
- Route the already known Bastion resource and recognized tank weapon types before the FRV proxy scan. Unknown collections retain proxy-first compatibility.
- Fall back to the same sample's valid native body HP when the GameSession value is invalid, not only when it is missing.
- Preserve the 1.3.2 per-wheel fault isolation, HUD layout, colors, configurator, log rotation, and tank ammunition/rendering code.


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
