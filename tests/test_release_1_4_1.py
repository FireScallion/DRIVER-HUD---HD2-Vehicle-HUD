from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
ui=(ROOT/'src/tank_ui.lua').read_text(encoding='utf-8')
log=(ROOT/'src/log_session.lua').read_text(encoding='utf-8')
build=(ROOT/'build.py').read_text(encoding='utf-8')
m=json.loads((ROOT/'package/manifest.json').read_text(encoding='utf-8'))
checks=[]
def ck(name,ok):
    checks.append((name,bool(ok))); print(('PASS ' if ok else 'FAIL ')+name)
ck('release log version marker', 'version=1.4.1' in log and '1.4.1 START' in build)
ck('tested HF1 manifest guid retained', m['Guid']=='4d9e465c-8d42-4be1-91f6-31a8b3e86140')
ck('manifest name formal release', m['Name']=='DRIVER HUD 1.4.1')
ck('old ring remains left of old main icon', "a.kind=='new' and -25 or 14" in ui)
ck('ring radius compact', "a.kind=='new' and 8.5 or 8.0" in ui)
ck('ring failure isolated', "pcall(Tank.draw_ring,w,h)" in ui and 'TANK_RING_ERROR' in ui)
ck('no unknown targeted read introduced', 'game_object_field(session' not in (ROOT/'src/tank_runtime.lua').read_text(encoding='utf-8'))
if not all(v for _,v in checks): raise SystemExit(1)
print(f'RESULT RELEASE_1_4_1 checks={len(checks)} fails=0')
