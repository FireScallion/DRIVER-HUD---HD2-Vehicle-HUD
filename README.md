# DRIVER HUD — HD2 Vehicle HUD

<img src="mod/icon.png" alt="DRIVER HUD icon" width="128">

A lightweight vehicle-status HUD mod for **HELLDIVERS 2**.

DRIVER HUD currently supports the **Bastion tank**, displaying hull health, main-gun ammunition, coaxial machine-gun ammunition, and a center-screen reticle in both the driver and gunner seats. Support for additional vehicles such as FRVs may be explored in separate experimental builds before being merged into the main release.

> Current release: **1.2.1**

## Features

- Bastion hull health
- Bastion main-gun ammunition — **31 rounds when fully loaded**
- Bastion coaxial machine-gun ammunition
- Center-screen reticle
- Works in both the driver and gunner seats
- Diagnostic logging enabled by default for easier issue reports
- No process-memory reading; the current implementation uses Stingray Lua/network APIs with runtime object/schema validation

## Requirements

- **Bingus Shared Loader v15 (BSL, API 1)** — required and installed separately

BSL: https://www.nexusmods.com/helldivers2/mods/16292  

## Installation

For normal use, download the installable ZIP from the repository's **Releases** page rather than the GitHub source-code archive.

Using Arsenal:

1. Disable or remove older DRIVER HUD versions. Do not enable multiple DRIVER HUD versions at the same time.
2. Import the DRIVER HUD release ZIP and enable **Core**.
3. Import and enable Bingus Shared Loader v15.
4. With Arsenal's default load-priority behavior, place BSL at the bottom so it loads last.
5. Run **Purge**, then **Deploy**, and start the game.

Typical order, top to bottom:

```text
HD2 HUD+ (optional)
DRIVER HUD
Bingus Shared Loader v15
```

If **First-Mod Priority** is enabled, the effective priority is reversed; adjust BSL accordingly.

## Configuration

The default configuration works without manual changes. To customize it, copy `mod/driver_hud.cfg` to:

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
```

Default values:

```ini
debug=true
offset_y=155
scale=1
alpha=0.76
```

- `debug`: writes the diagnostic log; enabled by default
- `offset_y`: vertical HUD position
- `scale`: HUD scale
- `alpha`: HUD opacity

Restart the game after changing the configuration.

## Issue Reports

If the HUD does not appear or the ammunition display is incorrect, first check that:

- BSL is enabled and loaded with the correct priority
- no older DRIVER HUD version is still enabled
- Arsenal has been Purged and Deployed again after changes

Please include this log when reporting a DRIVER HUD issue:

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
```

BSL loader log:

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

It also helps to mention whether you were in the driver or gunner seat, whether you changed vehicles, whether multiple vehicles were present, and what happened immediately before the issue.

## Repository Layout

```text
mod/                  Current installable mod files
  CORE/               Arsenal/HD2 patch payloads
  manifest.json
  driver_hud.cfg
  ...
src/
  driver_hud.lua      Readable Lua payload used by the current patch
README.md             English project page
README_zh-CN.md       Chinese project page
CREDITS.md            Third-party credits and notices
CONTRIBUTING.md       Contribution and fork policy
LICENSE               MIT license for project-owned source
```

`src/driver_hud.lua` is a readable copy of the Lua payload embedded in the current `patch_0` file. The repository does **not currently include an automated patch-build pipeline**, so contributors should treat the packaged files under `mod/` as the current release build and the Lua file under `src/` as the readable source reference.

## Technical Overview

At a high level, DRIVER HUD follows this path:

```text
Local player / avatar
        ↓
Current vehicle discovery
        ↓
Bastion hull confirmation
        ↓
Main / coax GameObject resolution
        ↓
Network type + field declaration validation
        ↓
Targeted field reads + last-valid cache
        ↓
Stingray screen GUI
```

The current ammo path was developed using the game's network declarations together with runtime validation. The mod avoids blind high-frequency field guessing and does not read Helldivers 2 process memory.

## Scope and Roadmap

The stable release currently supports the **Bastion tank**. Additional vehicle support may be investigated, especially FRVs, but experimental support may remain in separate test builds until it is considered stable enough for the main release.

No feature or vehicle support is guaranteed on a schedule.

## Contributing and Forks

Research, modifications, forks, and independently maintained variants are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

Please note that the maintainer may not have time to review or merge external pull requests. Maintaining your own fork is completely fine.

## Credits

See [CREDITS.md](CREDITS.md) for third-party sources and acknowledgements.

## License

Project-owned source code in this repository is released under the [MIT License](LICENSE).

Third-party code, tools, game assets, names, interfaces, and identifiers remain subject to their respective licenses and ownership. The MIT license does not relicense third-party material.

## 中文

中文说明见 [README_zh-CN.md](README_zh-CN.md)。
