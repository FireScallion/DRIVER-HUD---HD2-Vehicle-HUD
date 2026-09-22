from pathlib import Path
import sys,zipfile
root=Path(__file__).resolve().parents[1]
VERSION=(root/"VERSION").read_text().strip()
source=(root/"driver_hud.lua").read_text(encoding="utf-8")
checks={
 "raw HP validity stored per wheel":"local hp,hp_valid={},{}" in source and "hp_valid[i+1]=(v>=0 and v<=max[i+1])" in source,
 "no whole-sample HP range rejection":"wheel HP outside configuration" not in source,
 "wheel model gates local exact HP per wheel":"data.hp_valid==nil or data.hp_valid[i]~=false" in source,
 "q2 fallback retained":"precision='QUANTIZED_OR_UNKNOWN'" in source and "ratio=q/3" in source,
 "destroyed state wins before HP validity":"if state==2 then return {kind='hub',state=2} end" in source,
 "diagnostic validity bits":"hp_valid='..valid_text" in source,
}
archive=Path(sys.argv[1]) if len(sys.argv)>1 else root/("DRIVER_HUD_"+VERSION+".zip")
with zipfile.ZipFile(archive) as z:
 payload=z.read("CORE/9ba626afa44a3aa3.patch_0")[192:].decode("utf-8")
 checks["installed payload equals tested source"]=payload==source
 checks["installed payload has fault isolation"]="hp_valid" in payload and "wheel HP outside configuration" not in payload
failed=[k for k,v in checks.items() if not v]
for k,v in checks.items(): print(("PASS " if v else "FAIL ")+k)
print(f"RESULT WHEEL_FAULT_ISOLATION checks={len(checks)} fails={len(failed)}")
if failed: raise SystemExit(1)
