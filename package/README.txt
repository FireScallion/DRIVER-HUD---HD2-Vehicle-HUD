DRIVER HUD 1.3.4 — Tank + FRV HUD

Features
- Bastion driver/gunner: body HP, main ammunition, coax ammunition, and center reticle.
  Full main-gun ammunition is 31 rounds (30+1).
- HMG FRV and Supply FRV: body HP plus one continuous internal durability bar per tire.
  Tire HP numbers are not shown. Tire order is LF / RF / LR / RR when facing forward.
- FRV body outline, window outline, and body HP number are white above 75%, yellow at <=75%, and red at <=50%.
- FRV HUD screen position and scale can be changed with the included graphical configurator.

Installation (Arsenal)
1. Disable/remove ALL previous DRIVER HUD versions, including FRV / Resolver / Probe test branches.
   Do not enable multiple DRIVER HUD versions at the same time.
2. Import DRIVER_HUD_1.3.4.zip and enable Core.
3. Separately install and enable Bingus Shared Loader v15 (BSL, API 1). BSL is not included.
4. With the default priority mode, place BSL at the bottom so it loads last.
   If First-Mod Priority is enabled, reverse the order as needed so BSL keeps final override priority.
5. Purge, Deploy, then launch the game.

FRV HUD Position Adjustment
You do not need to open or edit JSON files manually.

1. Extract DRIVER_HUD_1.3.4.zip to any normal folder.
2. Double-click CONFIGURE_FRV_HUD.cmd in the root folder.
3. Adjust:
   - Horizontal position
   - Vertical position
   - Scale
   You can also use the Left / Right / Up / Down buttons for small movements.
4. Click Apply. A running HUD picks up the new settings in about 2 seconds; no Purge, Deploy, or game restart is needed.
5. Reset Defaults restores the default values in the window; click Apply to save them.

The configurator follows the Windows display language automatically and can also be switched between English and Chinese from the top-right button.
No administrator permissions, VS Code, Python, or extra software are required.
The active settings are stored at:
  %APPDATA%\Arrowhead\Helldivers2\frv_hud_position.json
Most users never need to edit this file directly.

Other configuration
Optional driver_hud.cfg goes to:
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
Defaults: debug=true, offset_y=155, scale=1, alpha=0.76.
offset_y/scale control the tank HUD; FRV position and size use the separate configurator; alpha affects both HUDs.
Restart the game after editing driver_hud.cfg.

Troubleshooting
Logs:
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.log            current game process
  %APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log   previous game process
The log rotates once when a new helldivers2.exe process starts. Mod/Lua reloads inside the same game process keep appending to the current log.
If the issue happened in the just-ended run, include driver_hud_previous.log too.

BSL loader log:
  %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log

Include the game version, vehicle, seat, host/client status, whether you switched vehicles, and the sequence leading to the issue.
Keep debug=true while reporting problems. Share logs privately.

Credits / open source
Project-owned code retains the MIT License. Third-party material retains its original permissions.
Source repository: https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD
See CREDITS.txt for third-party sources and acknowledgements. No game DLLs, dumps, third-party loaders, or fonts are included.

Performance diagnostics (optional): set perf=true together with debug=true in driver_hud.cfg and restart. Default perf=false. See PERFORMANCE_说明.txt for validation limits.
