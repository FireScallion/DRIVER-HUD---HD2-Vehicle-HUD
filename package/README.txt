DRIVER HUD 1.4.1

Vehicle status HUD for Helldivers 2. Requires Bingus Shared Loader v15 / API 1.

SUPPORTED VEHICLES
Original Bastion: hull health, main-gun ammunition (30 + 1), coax ammunition and a main-gun reload indicator.
Gatling/missile tank: hull health, current 300-round belt, six reserve-belt indicators, two missile-rack counts combined, and a Gatling reload indicator. Gatling on the left, missiles on the right. Original Bastion layout is retained.
HMG FRV / Supply FRV: vehicle health and individual tire condition. Existing wheel visuals and colour thresholds are retained.
The mod displays game state; it does not change health, ammunition, damage or reload rules.

INSTALLATION
1. Close the game. Disable/remove every earlier DRIVER HUD and all tank/FRV probes.
2. Import DRIVER_HUD_1.4.1.zip directly into Arsenal and enable Core.
3. Install/enable Bingus Shared Loader separately. Under Arsenal's default priority convention, put BSL at the bottom. With First-Mod Priority, use the equivalent final effective priority.
4. Purge, then Deploy, then launch the game.
Do not enable multiple DRIVER HUD/probe versions together.
The same install ZIP is used for GitHub Release and Nexus Main File.

FRV HUD Position Adjustment
No PowerShell, CMD or graphical configurator is included or needed.
Start the game once with the mod enabled. Then press Win+R and paste:
%APPDATA%\Arrowhead\Helldivers2
Open frv_hud_position.txt in Notepad. It contains English/Chinese instructions.
Edit x, y and scale, save, and wait about two seconds in game.
x: 0 = left, 1 = right. y: 0 = top, 1 = bottom. Coordinates refer to the HUD centre.
scale: 0.5 to 2.0. Defaults: x=0.714, y=0.90, scale=1.
Keep all three values. Invalid/incomplete edits keep the last valid position.
The live file is OUTSIDE the ZIP. There is no need to extract the mod, modify the Arsenal package, confirm a ZIP update, Purge/Deploy, or restart the game when changing these three values.
On first creation, valid settings from the old frv_hud_position.json are migrated. Once TXT exists, edit TXT only; the old configurator no longer controls this version. Updating the mod does not intentionally overwrite an existing TXT.

OTHER CONFIGURATION
Optional driver_hud.cfg lives in the same AppData folder. A template is in the ZIP.
Defaults: debug=true, offset_y=155, scale=1, alpha=0.76, perf=false, geometry_numbers=true.
offset_y and scale affect the tank HUD; alpha affects both HUD styles.
geometry_numbers=false restores the original numeric font.
Restart the game after changes to driver_hud.cfg (unlike FRV position TXT).

READING AND RELOAD INDICATORS
Ammunition may update in steps. Missing readings are not treated as zero.
A dimmed bar/count with a dotted underline is last-known telemetry, not a fresh reading.
Reload indicators follow observed reload states; zero ammunition does not start them automatically.
A known pause retains observed progress. Re-entry does not automatically restart a reload.
A static dotted ring means exact starting progress was not observed. Long state gaps hold the indicator rather than falsely completing it. The ring never adds ammunition or spends a reserve belt.

BUG REPORTS
Please include mod/game version, vehicle, seat, host/client role, preceding actions, and a screenshot/video where useful.
Current log: %APPDATA%\Arrowhead\Helldivers2\driver_hud.log
Previous log: %APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
BSL log: %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
Please ZIP and share full logs privately. Game updates may require a compatibility update.

RELEASE VALIDATION
1.4.1 formalizes the live-tested 1.4.0-HF1 hotfix: tank HUD display was restored and reload indicators were moved to the left of the reloadable weapon icon. Offline regression tests were rerun; exhaustive multiplayer/FPS validation is still outside the automated test scope.
Project code: MIT. See CREDITS.txt for third-party attribution.
