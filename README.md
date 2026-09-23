# DRIVER HUD — HD2 Vehicle HUD

A lightweight vehicle-status HUD mod for **Helldivers 2**, built around one simple idea: vehicle crews should be able to read the state of their machine without turning the HUD into another source of noise.

**Current version: 1.4.3**  
[中文说明](README_中文.md) · [Nexus Mods](https://www.nexusmods.com/helldivers2/mods/16358) · [Latest GitHub Release](https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD/releases/latest) · [Changelog](CHANGELOG.md)

DRIVER HUD adds compact status displays for both supported tank variants and the HMG / Supply FRVs. It shows information such as hull health, weapon ammunition, reload state, and tire condition while keeping the presentation close to the visual language of the game.

The mod is **display-only**: it does not change vehicle health, damage, ammunition capacity, reload rules, handling, weapon behavior, or other gameplay values.

## Supported vehicles

| Vehicle | HUD information |
| --- | --- |
| **Original Bastion tank** | Hull HP, main-gun ammunition, coaxial machine-gun ammunition, main-gun reload indicator, center reticle |
| **Gatling / missile tank** | Hull HP, 300-round current-belt bar, six reserve-belt indicators, combined missile count, Gatling reload indicator, center reticle |
| **HMG FRV** | Hull HP, four independent tire-durability displays, destroyed-wheel / hub state |
| **Supply FRV** | Hull HP, four independent tire-durability displays, destroyed-wheel / hub state |

### Original Bastion tank

- Current / maximum hull HP with a horizontal health bar.
- Main-gun ammunition.
- Coaxial machine-gun ammunition.
- Full main-gun load is **31 rounds (30 + 1)**.
- Main-gun reload indicator positioned to the **left of the weapon icon**, so it does not crowd the ammunition display.
- Center-screen vehicle reticle.
- Supports the tank driver and gunner HUD paths.

### Gatling / missile tank

- Current / maximum hull HP.
- Gatling current belt displayed as a **0–300 bar**.
- **Six** reserve-belt indicators below the current belt.
- Remaining missiles calculated from the two independent missile racks.
- Gatling reload indicator positioned to the **left of the weapon group**.
- Center-screen vehicle reticle.
- Manual reload behavior follows observed game state; empty ammunition alone does not make DRIVER HUD invent an automatic reload.

### HMG FRV and Supply FRV

- Vehicle body HP.
- Independent condition display for all four tires.
- A continuous durability bar inside each tire rather than four additional HP numbers.
- Destroyed tires switch to a hub-only visual state.
- Tire order is **LF / RF / LR / RR** when facing forward.
- If precise tire data is temporarily unavailable, the HUD degrades conservatively instead of inventing a precise value.
- FRV body outline and body HP follow the existing condition-color rules:
  - above 75%: white
  - 75% or lower: yellow
  - 50% or lower: red
- Position and scale can be changed while the game is running through a simple external text file.


## Performance and stability

Performance is a first-class design goal of the project.

The production runtime uses bounded sampling and cached presentation rather than the broad/high-frequency scanning used during reverse-engineering probes. For the newer tank, weapon reads share a limited schedule; the HUD does not increase the entire vehicle system to a 20 Hz scan just to make the Gatling bar move one round at a time.

Static tank graphics and the animated reload overlay are cached separately, so advancing a reload ring does not require recreating the full HUD every frame.

The native FRV reader is version-scoped and guarded. If the expected game layout no longer matches after a Helldivers 2 update, the affected native path is designed to fail closed rather than continue reading arbitrary memory.

## Requirement

**Bingus Shared Loader v15 / API 1** is required and must be installed separately.

- Nexus Mods: https://www.nexusmods.com/helldivers2/mods/16292

With Arsenal's default priority behavior, place **Bingus Shared Loader at the bottom of the mod list** so it receives the final effective override priority.

If you use Arsenal's **First-Mod Priority** option, use the equivalent reversed list order so BSL still has the correct final effective priority.

## Installation

1. Close the game.
2. Disable or remove every older DRIVER HUD version, including Resolver / FRV / Tank Probe test builds.
3. Import `DRIVER_HUD_1.4.3.zip` directly into Arsenal and enable **Core**.
4. Install and enable **Bingus Shared Loader v15** separately.
5. Confirm BSL has the correct final effective priority.
6. Run **Purge**.
7. Run **Deploy**.
8. Launch the game.

Do **not** enable multiple DRIVER HUD versions or development probes at the same time.

The same installation ZIP is suitable for the GitHub Release and Nexus Main File.

## HUD Unified settings

After starting the game once, use Notepad to open:

`%APPDATA%\Arrowhead\Helldivers2\driver_hud_settings.txt`

Save to apply in about two seconds. Keep every setting. Invalid, incomplete, duplicate or out-of-range dictionaries retain the entire previous configuration. UTF-8 and BOM-marked UTF-16 are supported.

| Key | Default | Meaning |
|---|---:|---|
| tank_offset_y | 155 | Tank bottom offset at reference resolution, 45–500 |
| tank_scale | 1 | Tank scale, 0.5–2 |
| frv_x | 0.714 | FRV center, left 0 to right 1 |
| frv_y | 0.90 | FRV center, top 0 to bottom 1 |
| frv_scale | 1 | FRV scale, 0.5–2 |
| alpha | 0.76 | HUD opacity, 0.1–1 |
| font | new | `new` geometry digits / `old` original game font |
| reload_ring | true | Tank reload indicator |
| reticle | true | Tank center dot |
| weapon_cache | true | Experimental cross-checked component reads |
| debug | true | Diagnostic logging |
| perf | false | Ten-second CPU/native-call summaries |

Existing `driver_hud.cfg` and `frv_hud_position.txt`/`.json` values are imported on first creation, including an existing font preference. Afterwards edit only the unified file. The packaged `.example.txt` is reference material and is not deployed over your settings. There is no external executable or shell configurator. Nexus scanning was not performed.

The old font uses the original source's `core/performance_hud/debug` resource. Its source identity is verified; the user-provided screenshot is consistent with the legacy path, but final pixel appearance needs an in-game comparison.

## Other configuration

Optional `driver_hud.cfg` lives in the same AppData folder. A template is included in the installation ZIP.

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
```

Default values:

```ini
debug=true
perf=false
offset_y=155
scale=1
alpha=0.76
geometry_numbers=true
```

- `offset_y` — tank HUD vertical position
- `scale` — tank HUD scale
- `alpha` — opacity used by both HUD styles
- `debug` — diagnostic logging
- `perf` — optional performance diagnostics; intended for debugging
- `geometry_numbers=false` — restores the original numeric font path instead of geometry numerals

Changes to `driver_hud.cfg` require a game restart. FRV position TXT changes do not.

## Troubleshooting

If the HUD does not appear:

1. Make sure only one DRIVER HUD version is enabled.
2. Remove old Tank / FRV / Resolver probe builds.
3. Confirm Bingus Shared Loader v15 is enabled.
4. Check the effective BSL priority in Arsenal.
5. Run Purge and Deploy again.
6. Open `driver_hud.log` and confirm the startup lines report the version you expected to install.

Game updates can change internal vehicle/network structures. A fresh log is particularly useful when a problem starts immediately after a Helldivers 2 update.

## Logs and bug reports

DRIVER HUD keeps the current and previous game-process logs:

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
%APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
```

Bingus Shared Loader log:

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

When reporting an issue, please include:

- DRIVER HUD version and game version
- vehicle type
- driver / gunner / passenger seat where relevant
- host or client status
- whether you switched seats or vehicles before the problem
- whether multiple vehicles were active
- the actions immediately before the issue
- screenshot or video when useful
- the complete DRIVER HUD log, preferably zipped for larger reports

## Building from source

The repository contains the editable Lua modules, the stable Bastion baseline, build script, package template, focused regression tests, and release-validation evidence.

Build the installation ZIP with:

```text
python build.py dist/DRIVER_HUD_1.4.1.zip
```

The build system preserves the original stable Bastion sections from the 1.2.1 baseline, composes the current runtime/UI modules, writes the binary patch payload, and packages `package/` into the Arsenal-ready ZIP.

Useful source locations:

```text
src/tank_runtime.lua        tank variant identity, weapon telemetry and reload state
src/tank_ui.lua             tank HUD, Gatling belt/reserve presentation, reload overlay
src/native_reader.lua       version-scoped read-only native vehicle / Health reader
src/frv_runtime.lua         FRV identity, Health and tire-state model
src/frv_ui.lua              FRV geometry and rendering
src/hud_numbers.lua         shared geometry-number rendering
src/position_config.lua     FRV TXT configuration and old-JSON migration
src/integration_update.lua  runtime integration / arbitration
src/log_session.lua         per-game-process log rotation
baseline/                   stable original Bastion baseline
package/                    release-package template
package/CORE/               packaged patch / GUI material payloads
tests/                      focused offline regression tests
evidence/                   validation outputs for the source snapshot
```

No game DLLs, process dumps, heap snapshots, third-party loaders, font files, or Windows configurator executables are distributed in the repository/release package.

## Open source and credits

Project-owned source code is released under the **MIT License**. Third-party assets and materials retain their original permissions; see [`CREDITS.txt`](CREDITS.txt).

Key dependency / reference credits:

- **CowboyBingus** — Bingus Shared Loader.
- **DDRK1NG** — HD2 HUD+, an important reference during the early bootstrap/UI research; retained reused material is separately credited in `CREDITS.txt`.

Helldivers 2 and its game assets, names, interfaces, and identifiers belong to their respective owners. This project is not affiliated with Arrowhead Game Studios or Sony Interactive Entertainment.
