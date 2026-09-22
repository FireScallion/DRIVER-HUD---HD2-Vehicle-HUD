# DRIVER HUD — HD2 Vehicle HUD

Lightweight vehicle-status HUD for the original Bastion, Gatling/missile tank, HMG FRV and Supply FRV.

## 1.4.1

The Gatling tank uses a **current-belt bar plus six reserve indicators**, rather than rapidly changing ammunition digits. Two independent missile-rack readings are combined. Both tank variants gain reload indicators. The original Bastion keeps its existing weapon layout.

The installation ZIP is shared by GitHub Release and Nexus Main File. No external script configurator is included.

## Installation
1. Close the game. Disable/remove every earlier DRIVER HUD and all tank/FRV probes.
2. Import DRIVER_HUD_1.4.1.zip directly into Arsenal and enable Core.
3. Install/enable Bingus Shared Loader separately. Under Arsenal's default priority convention, put BSL at the bottom. With First-Mod Priority, use the equivalent final effective priority.
4. Purge, then Deploy, then launch the game.
Do not enable multiple DRIVER HUD/probe versions together.

## FRV HUD position and scale
Start the game once with the mod enabled. Then press Win+R and paste:
%APPDATA%\Arrowhead\Helldivers2
Open frv_hud_position.txt in Notepad. It contains English/Chinese instructions.
Edit x, y and scale, save, and wait about two seconds in game.
x: 0 = left, 1 = right. y: 0 = top, 1 = bottom. Coordinates refer to the HUD centre.
scale: 0.5 to 2.0. Defaults: x=0.714, y=0.90, scale=1.
Keep all three values. Invalid/incomplete edits keep the last valid position.
The live file is OUTSIDE the ZIP. There is no need to extract the mod, modify the Arsenal package, confirm a ZIP update, Purge/Deploy, or restart the game when changing these three values.
On first creation, valid settings from the old frv_hud_position.json are migrated. Once TXT exists, edit TXT only; the old configurator no longer controls this version. Updating the mod does not intentionally overwrite an existing TXT.

## Other configuration
Optional driver_hud.cfg lives in the same AppData folder. A template is in the ZIP.
Defaults: debug=true, offset_y=155, scale=1, alpha=0.76, perf=false, geometry_numbers=true.
offset_y and scale affect the tank HUD; alpha affects both HUD styles.
geometry_numbers=false restores the original numeric font.
Restart the game after changes to driver_hud.cfg (unlike FRV position TXT).

## Bug reports
Please include mod/game version, vehicle, seat, host/client role, preceding actions, and a screenshot/video where useful.
Current log: %APPDATA%\Arrowhead\Helldivers2\driver_hud.log
Previous log: %APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
BSL log: %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
Please ZIP and share full logs privately. Game updates may require a compatibility update.

Project code: MIT. See CREDITS.txt for third-party attribution.