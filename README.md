# DRIVER HUD — HD2 Vehicle HUD

A lightweight vehicle-status HUD mod for **Helldivers 2**.

**Current version: 1.3.2**  
[中文说明](README_中文.md) · [Nexus Mods](https://www.nexusmods.com/helldivers2/mods/16358) · [Latest GitHub Release](https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD/releases/latest)

## Supported vehicles

### Bastion tank

- Hull HP with current / maximum value and health bar.
- Main-gun ammunition.
- Coaxial machine-gun ammunition.
- Center-screen reticle.
- Works in both the driver and gunner seats.
- Full main-gun load is 31 rounds (30+1).

### HMG FRV and Supply FRV

- Vehicle body HP.
- Independent condition display for all four tires.
- Continuous durability bar inside each tire; individual tire HP numbers are not shown.
- Destroyed tires switch to a hub-only visual state.
- FRV body outline, window outline, and HP number change color with body condition:
  - above 75%: white
  - 75% or lower: yellow
  - 50% or lower: red
- FRV HUD position and scale can be changed with the included graphical configurator.

DRIVER HUD only displays vehicle state. It does not change vehicle health, damage, ammunition capacity, or other gameplay values.

![FRV HUD preview](docs/frv_ui_preview.png)

## Requirement

**Bingus Shared Loader v15 / API 1** is required and must be installed separately.

- Nexus Mods: https://www.nexusmods.com/helldivers2/mods/16292
- BSL v15 keeps API 1 compatibility and supports addon discovery for third-party mods.

With Arsenal's default priority behavior, place **Bingus Shared Loader at the bottom of the mod list** so it loads last / has the final effective override priority.

## Installation

1. Close the game.
2. Disable or remove every older DRIVER HUD version, including FRV / Resolver / Probe test builds.
3. Import the current `DRIVER_HUD_1.3.2.zip` into Arsenal and enable **Core**.
4. Install and enable **Bingus Shared Loader v15** separately.
5. Keep BSL at the correct final priority.
6. Run **Purge**, then **Deploy**.
7. Launch the game.

Do not enable multiple DRIVER HUD versions at the same time.

## FRV HUD position and scale

Normal users do not need to edit JSON files.

1. Extract `DRIVER_HUD_1.3.2.zip` to any normal folder.
2. Double-click `CONFIGURE_FRV_HUD.cmd`.
3. Adjust horizontal position, vertical position, and scale.
4. Click **Apply**.

The configurator supports English and Chinese. If the game is already running, the FRV HUD normally picks up the new settings in about two seconds; no Purge, Deploy, or restart is required.

The active configuration is stored at:

```text
%APPDATA%\Arrowhead\Helldivers2\frv_hud_position.json
```

## Other configuration

Optional `driver_hud.cfg` can be placed at:

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
```

Default values:

```text
debug=true
offset_y=155
scale=1
alpha=0.76
```

- `offset_y` / `scale` control the Bastion HUD.
- FRV position and size use the separate configurator.
- `alpha` affects both HUD styles.
- Restart the game after editing `driver_hud.cfg`.

## Logs and bug reports

DRIVER HUD keeps the current and previous game-process logs:

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
%APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
```

BSL log:

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

When reporting an issue, include the DRIVER HUD version, game version, vehicle, seat, host/client status, whether you switched vehicles or seats, and the action sequence immediately before the problem. Please share complete logs privately when possible.

## Building from source

The repository contains the editable Lua source, build script, package template, and focused tests used for the release.

```text
python build.py dist/DRIVER_HUD_1.3.2.zip
```

The build script assembles `driver_hud.lua` from the 1.2.1 Bastion baseline plus the current FRV/runtime modules, writes the patch payload, and packages the contents of `package/`.

Useful source locations:

```text
src/native_reader.lua       version-scoped read-only native vehicle/Health reader
src/frv_runtime.lua         FRV identity, Health, precision, and wheel-state model
src/frv_ui.lua              FRV geometry and rendering
src/position_config.lua     FRV position/scale configuration
src/log_session.lua         per-game-process log rotation
tests/                      focused offline tests
package/                    release-package template
```

No game DLLs, process dumps, third-party loaders, or font files are included in this repository.

## Development note

The FRV reader uses version-scoped game structures and is designed to fail closed when its compatibility guards do not match. A Helldivers 2 update can therefore require a DRIVER HUD compatibility update even when the UI code itself has not changed.

## Open source and credits

Project-owned source code is released under the **MIT License**. Third-party assets and materials retain their original permissions; see [CREDITS.txt](CREDITS.txt).

Key dependency / reference credits:

- **CowboyBingus** — Bingus Shared Loader.
- **DDRK1NG** — HD2 HUD+, used as an important reference during early HUD/bootstrap research; relevant reused material remains separately credited in `CREDITS.txt`.

Helldivers 2 and its game assets, names, interfaces, and identifiers belong to their respective owners. This project is not affiliated with Arrowhead Game Studios or Sony Interactive Entertainment.
