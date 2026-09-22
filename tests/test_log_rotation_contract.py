from pathlib import Path
import sys,zipfile
root=Path(__file__).resolve().parents[1]
VERSION=(root/"VERSION").read_text().strip()
source=(root/"driver_hud.lua").read_text(encoding="utf-8")
checks={
 "previous log path":"driver_hud_previous.log" in source,
 "process id":"GetCurrentProcessId" in source,
 "process creation time":"GetProcessTimes" in source,
 "persistent session marker":"driver_hud_session.id" in source,
 "same-process reload":"DRIVER_HUD SCRIPT_RELOAD" in source,
 "new-session header":"DRIVER_HUD SESSION_START" in source,
 "fail-safe no process identity":"no_process_identity" in source,
 "rotation before normal start":source.index("init_log_session()") < source.index("DRIVER_HUD "+VERSION+" START"),
}
archive=Path(sys.argv[1]) if len(sys.argv)>1 else root/("DRIVER_HUD_"+VERSION+".zip")
with zipfile.ZipFile(archive) as z:
 payload=z.read("CORE/9ba626afa44a3aa3.patch_0")[192:].decode("utf-8")
 checks["installed payload contains rotation"]= "driver_hud_previous.log" in payload and "GetProcessTimes" in payload
 checks["installed payload equals tested source"]=payload==source
 checks["CN docs mention previous log"]= "driver_hud_previous.log" in z.read("README_中文.txt").decode("utf-8")
 checks["EN docs mention previous log"]= "driver_hud_previous.log" in z.read("README.txt").decode("utf-8")
failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(("PASS " if v else "FAIL ")+k)
print(f"RESULT LOG_ROTATION checks={len(checks)} fails={len(failed)}")
if failed: raise SystemExit(1)
