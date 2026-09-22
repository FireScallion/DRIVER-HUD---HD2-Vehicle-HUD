# DRIVER HUD 1.4.1

## 1.4.1

- Formalizes the live-tested 1.4.0-HF1 hotfix under version 1.4.1.
- Uses the fresh Arsenal GUID introduced by HF1, preventing stale 1.3.5 deployment identity from masking the new build.
- Keeps reload progress indicators to the **left** of the reloadable weapon icon on both tank variants, avoiding the icon/ammunition spacing conflict.
- Preserves the 1.4.0 tank telemetry/UI model, external bilingual FRV TXT configuration, and bounded low-frequency polling design.

## 1.4.0

Adds the Gatling/missile tank HUD: a 300-round current-belt bar, six reserve-belt indicators, and combined independent missile-rack counts. New and original tanks gain state-driven reload indicators with conservative pause/unknown handling.

Performance remains the priority. New weapons share a maximum 10 Hz query schedule (Gatling up to 5 Hz; each rack up to 2.5 Hz), plus 5 Hz hull sampling. No world/nearby-GOID discovery, unknown targeted getters, or 20 Hz probe loops are added. Static graphics are reused; only the reload overlay changes during animation.

FRV position settings now use an external bilingual `frv_hud_position.txt`, with approximately two-second hot reload and one-time migration from valid old JSON. The Windows script configurator is removed. The ordinary installation ZIP and Nexus Main File are identical.

Original tank ammo/read/draw blocks, native module guards, FRV runtime/geometry (apart from the new tank's early type routing), and material resources are retained.

Validation is offline, not a live-game certification. Long remote-state gaps and unknown initial reload progress intentionally show a held/unknown indicator rather than invented readiness. The shader/material curvature fix is retained from 1.3.5; no new live curvature test was performed.


# Changelog

## 1.3.5 — New game build compatibility and numeric rendering

- Re-derived the Network/Seater/Health/SyncedHealth roots and member offsets from the supplied new module; migrated the Health settings table from 984 to 1002 slots.
- Kept compatibility fail-closed and expanded the checked code locations to 14 reviewed ranges. No old-version offset fallback.
- Added shared-material geometry numerals for both HUDs as the default HUD Curve compatibility path, with `geometry_numbers=false` to restore the original font.
- Retained tank ammo logic, FRV fault isolation, HUD placement, body colors, log rotation and 1.3.4 polling optimizations.
- Updated offline fixtures for new layout and added targeted layout/geometry checks. Live HD2 compatibility and curvature visuals still require confirmation.

## 1.3.4

Performance update for Bastion, HMG FRV and Supply FRV.

- Reduce ownership enumeration during stable native-bound vehicle use.
- Skip redundant tank binding reads.
- Reuse memory protection checks within each native sample and batch selected reads.
- Add optional performance diagnostics (`perf=true`, disabled by default).
- Preserve tank ammunition cadence/logic, FRV health cadence and HUD layout.

Requires Bingus Shared Loader v15 / API 1. Disable old DRIVER HUD versions before installing, then Purge / Deploy. GitHub release includes the bilingual FRV configurator. Nexus distributes the configurator as a separate Optional File.

33 focused offline checks passed. Live game FPS improvement has not been measured here.

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
