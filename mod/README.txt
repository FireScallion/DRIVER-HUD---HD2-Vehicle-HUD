DRIVER HUD 1.2.1 Release

Features
Displays hull health, main-gun ammunition, coaxial machine-gun ammunition,
and a center-screen reticle in both the driver and gunner seats of the Bastion tank.
The main gun carries 31 rounds when fully loaded.
After entering the tank, the HUD appears once vehicle ownership has been confirmed.

Requirements
Bingus Shared Loader v15 (BSL, API 1) must be installed separately.
BSL is not included in this package. HD2 HUD+ is optional; DRIVER HUD does not depend on it.

Installation (Arsenal)
1. Disable or remove all older DRIVER HUD versions, including previous test or combined builds.
   Do not enable multiple DRIVER HUD versions at the same time.
2. Import DRIVER_HUD_1.2.1.zip into your mod manager and enable Core.
3. Import and enable Bingus Shared Loader v15.
4. With the default load-priority behavior, place BSL at the bottom of the mod list so it loads last.
   Place DRIVER HUD and HD2 HUD+ (if installed) above BSL.
   Example, top to bottom:
     HD2 HUD+ (optional)
     DRIVER HUD 1.2.1
     Bingus Shared Loader v15
   If First-Mod Priority is enabled, load priority is reversed.
   Adjust BSL accordingly so it retains the final effective override priority.
5. Run Purge, then Deploy, and start the game.

Configuration (Optional)
The default settings work without manual configuration.
To customize them, place driver_hud.cfg from this package in:
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
If the file already exists, edit it directly and restart the game after making changes.

Defaults:
  debug=true
  offset_y=155
  scale=1
  alpha=0.76

debug: Enables the diagnostic log. It is on by default to make issue reports easier.
offset_y: Vertical HUD position.
scale: HUD scale.
alpha: HUD opacity.
The diagnostic log does not add anything to the in-game display.

If the HUD Does Not Appear or Ammo Is Incorrect
First check that BSL is enabled, the load order is correct, and no older DRIVER HUD version is still enabled.
After changing the setup, run Purge / Deploy again.
After entering a tank, allow a short moment for vehicle detection.

When reporting an issue, include the following log and mention whether you were in the driver or gunner seat,
whether you changed tanks, whether multiple tanks were present, and what you did immediately before the issue:
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.log

BSL loader log:
  %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log

You can paste either path directly into the Windows File Explorer address bar.
If no log is created, check that debug is set to true and that the mod loaded successfully.

Support and Credits
This release currently supports the Bastion tank. Other vehicles are outside the scope of this version.
See CREDITS.txt for third-party sources and acknowledgements.
