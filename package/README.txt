DRIVER HUD 1.4.3

Vehicle HUDs for the original Bastion, Gatling/missile tank, HMG FRV and Supply FRV. Requires Bingus Shared Loader v15 / API 1, installed separately.

INSTALL
Close the game. Disable other DRIVER HUD versions and vehicle probe mods. Import DRIVER_HUD_1.4.3.zip into Arsenal, enable Core, then Purge and Deploy. Keep your existing working BSL setup and load order. Enable only one DRIVER HUD version.

SETTINGS
After starting the game once, open this file with Notepad:
%APPDATA%\Arrowhead\Helldivers2\driver_hud_settings.txt

Save to apply in about two seconds. Keep all settings in the file. Invalid or incomplete settings preserve the previous configuration. UTF-8 and BOM-marked UTF-16 are supported.

tank_offset_y = 155  Tank distance from bottom at reference resolution (45–500)
tank_scale = 1       Tank scale (0.5–2)
frv_x = 0.714        FRV center, left 0 to right 1
frv_y = 0.9          FRV center, top 0 to bottom 1
frv_scale = 1        FRV scale (0.5–2)
alpha = 0.76         Opacity (0.1–1)
font = new           Geometry digits; use old for the original game font
reload_ring = true  Tank reload indicator
reticle = true      Tank center dot
weapon_cache = true Validated native weapon component reads
debug = true        Diagnostic logging
perf = false        Periodic performance summaries

Existing driver_hud.cfg and frv_hud_position.txt/.json settings are imported only when the unified file is first created. Afterwards edit driver_hud_settings.txt. The packaged example is a reference and does not overwrite your settings.

DISPLAY
Unavailable initial values use --. Brief read failures retain the last valid value. A dotted ammunition underline indicates that recent synchronization is unconfirmed. An unknown reload starting point uses a dotted ring. Reload timing is an estimate within observed stages; ammo counts come from readings. Pauses and read gaps retain ring brightness. Exiting or changing vehicles clears the previous HUD.

LOGS
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
The previous game process log is retained as driver_hud_previous.log. Set debug = false to disable diagnostic messages.

LICENSE
MIT for project-owned code. See LICENSE.txt and CREDITS.txt for third-party notices.
