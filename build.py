"""Reproducible 1.2.1-based integration. No compiler or game runtime required."""
from pathlib import Path
import hashlib, json, struct, zipfile, shutil, difflib
ROOT=Path(__file__).resolve().parent
BASE=ROOT/'baseline'

def assemble():
    source=(BASE/'driver_hud_1_2_1.lua').read_text(encoding='utf-8')
    source=source.replace('-- DRIVER HUD 1.2.1. Multi-Bastion binding hotfix; main gun is 30+1 (31 total); debug logging enabled by default.',
        '-- DRIVER HUD 1.4.1. Tank + FRV integration with isolated telemetry and bounded read-error grace.')
    source=source.replace("log('DRIVER_HUD 1.2.1 START')", "log('DRIVER_HUD 1.4.1 START native_contract=r4-73374bd4 proxy_unit_health=1 wheel_fault_isolation=1 robustness_pass=1 geometry_numbers='..tostring(C.geometry_numbers))")
    source=source.replace('local M={ids={}', 'local FRV, Tank -- Forward declarations for lifecycle reset.\nlocal M={ids={}',1)
    source=source.replace('local function full_reset()\n', "local function full_reset()\n if Tank then Tank.detach() end\n if FRV then FRV.reset() end\n",1)
    source=source.replace('local C={debug=true,','local C={geometry_numbers=true,perf=false,debug=true,',1)
    source=source.replace("if k=='debug' then C.debug=v=='true'", "if k=='geometry_numbers' then if v=='true' or v=='false' then C[k]=v=='true' end elseif k=='debug' or k=='perf' then C[k]=v=='true'",1)
    # Exact native identity is an additional acquisition seam, not a replacement
    # for any tank ammo/read/draw code. Its snapshot has already been rechecked.
    source=source.replace("and why~='local_gunner_owned_weapon' then return false end", "and why~='local_gunner_owned_weapon' and why~='native_seater' then return false end",1)
    source=source.replace("if why=='avatar64.25_hull' or why=='avatar64.25_weapon' then M.bind_weak=false end", "if why=='avatar64.25_hull' or why=='avatar64.25_weapon' or why=='native_seater' then M.bind_weak=false end",1)
    source=source.replace(' if not pending or pending.hid~=hid or M.clock-pending.last>5 then', " if why~='native_seater' and (not pending or pending.hid~=hid or M.clock-pending.last>5) then",1)
    source=source.replace(' if pending.frame==M.frame then return false end', " if why~='native_seater' and pending.frame==M.frame then return false end",1)
    source=source.replace("M.bind_weak=not (why=='avatar64.25_hull' or why=='avatar64.25_weapon')", "M.bind_weak=not (why=='avatar64.25_hull' or why=='avatar64.25_weapon' or why=='native_seater')",1)
    # File logging must not disable HUDs because of a locked/read-only log file.
    # Rotate exactly once per helldivers2.exe process; script reloads append.
    start=source.index('local function log(s)');end=source.index("log('DRIVER_HUD",start)
    source=source[:start]+(ROOT/'src/log_session.lua').read_text(encoding='utf-8')+source[end:]
    insertion='\n'.join((ROOT/'src'/name).read_text(encoding='utf-8') for name in ('native_reader.lua','position_config.lua','frv_runtime.lua','tank_runtime.lua'))
    insertion=insertion.replace('local FRV = {next_poll=0}','FRV = {next_poll=0}',1)
    at=source.index("local material='mods/driver_hud/solid'")
    source=source[:at]+insertion+'\n'+source[at:]
    # Only the numeric rendering helper changes; tank data, layout and reticle stay frozen.
    number_at=source.index('local function text(s,x,y,size,a)')
    source=source[:number_at]+(ROOT/'src/hud_numbers.lua').read_text(encoding='utf-8')+'\n'+source[number_at:]
    old_text="local function text(s,x,y,size,a) remember('destroy_text',Gui.text(M.gui,s,'core/performance_hud/debug',size,'core/performance_hud/debug',V2(x,y),Color(math.floor(a*255),255,255,255))) end"
    new_text="local function text(s,x,y,size,a) if C.geometry_numbers and HudNumber.draw(s,x,y,size,a,nil,'left') then return end;remember('destroy_text',Gui.text(M.gui,s,'core/performance_hud/debug',size,'core/performance_hud/debug',V2(x,y),Color(math.floor(a*255),255,255,255))) end"
    assert source.count(old_text)==1,'tank text helper location changed'
    source=source.replace(old_text,new_text,1)
    at=source.index('local function draw(w,h)')
    source=source[:at]+(ROOT/'src/frv_ui.lua').read_text(encoding='utf-8')+'\n'+source[at:]
    at=source.index('local function update(dt)')
    source=source[:at]+(ROOT/'src/tank_ui.lua').read_text(encoding='utf-8')+'\n'+source[at:]
    source=source.replace('local function clear()\n', 'local function clear()\n if Tank and Tank.clear_ring then Tank.clear_ring() end\n',1)
    source=source.replace('M.ids={};M.gui=nil;M.gui_world=nil;M.draw_key=nil', 'M.ids={};M.gui=nil;M.gui_world=nil;M.draw_key=nil\n if Tank then Tank.ring_ids={};Tank.ring_key=nil;Tank.ring_gui=nil end',1)
    at=source.index('local function update(dt)')
    source=source[:at]+(ROOT/'src/integration_update.lua').read_text(encoding='utf-8')
    return source

def build(destination=None):
    text=assemble();payload=text.encode('utf-8')
    (ROOT/'driver_hud.lua').write_bytes(payload)
    raw=(BASE/'9ba626afa44a3aa3.patch_0.header').read_bytes();header=bytearray(raw)
    assert len(header)==192
    struct.pack_into('<I',header,160,len(payload)+8);struct.pack_into('<I',header,184,len(payload))
    stage=ROOT/'package';patch=stage/'CORE/9ba626afa44a3aa3.patch_0';patch.parent.mkdir(parents=True,exist_ok=True)
    patch.write_bytes(bytes(header)+payload)
    report={'version':'1.4.1','lua_bytes':len(payload),'source_sha256':hashlib.sha256(payload).hexdigest(),
      'baseline_sha256':hashlib.sha256((BASE/'driver_hud_1_2_1.lua').read_bytes()).hexdigest(),
      'runtime_validation':'AUTOMATED_OFFLINE_PLUS_USER_LIVE_SMOKE; exhaustive multiplayer/FPS validation not executed here'}
    # Frozen blocks: exact bytes after extraction, including all tank ammunition profiles.
    baseline=(BASE/'driver_hud_1_2_1.lua').read_text(encoding='utf-8')
    blocks={
      'tank_ammo_and_refresh':("-- Only the coax type confirmed", "local material='mods/driver_hud/solid'"),
      'tank_draw':('local function draw(w,h)','local function update(dt)'),
      'tank_original_reference_resolver':('local function bind_current_vehicle(', '-- Only the coax type confirmed')}
    report['frozen_blocks']={}
    for name,(a,b) in blocks.items():
        before=baseline[baseline.index(a):baseline.index(b,baseline.index(a))]
        # Inserted native blocks follow refresh, and FRV drawing precedes tank drawing.
        if name=='tank_ammo_and_refresh':
            after=text[text.index(a):text.index('-- Version-scoped, identity-keyed readers.')]
        elif name=='tank_draw':after=text[text.index(a):text.index('-- Tank variant presentation',text.index(a))]
        else:after=text[text.index(a):text.index(b,text.index(a))]
        assert before.rstrip()==after.rstrip(),name+' changed unexpectedly'
        report['frozen_blocks'][name]=hashlib.sha256(before.rstrip().encode()).hexdigest()
    (ROOT/'evidence').mkdir(exist_ok=True)
    (ROOT/'evidence/source_changes.diff').write_text(''.join(difflib.unified_diff(baseline.splitlines(True),text.splitlines(True),fromfile='1.2.1/driver_hud.lua',tofile='1.4.1/driver_hud.lua')),encoding='utf-8')
    if destination:
        destination=Path(destination);destination.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for p in sorted(stage.rglob('*')):
                if p.is_file():
                    info=zipfile.ZipInfo(p.relative_to(stage).as_posix(),(2026,9,23,0,0,0))
                    info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16
                    z.writestr(info,p.read_bytes(),compresslevel=9)
        with zipfile.ZipFile(destination) as z:
            assert z.testzip() is None
            p=z.read('CORE/9ba626afa44a3aa3.patch_0')
            assert p[192:]==payload and struct.unpack_from('<I',p,160)[0]==len(payload)+8 and struct.unpack_from('<I',p,184)[0]==len(payload)
        report['zip_sha256']=hashlib.sha256(destination.read_bytes()).hexdigest();report['zip_bytes']=destination.stat().st_size
    (ROOT/'evidence/build_report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report
if __name__=='__main__':
    import sys
    print(json.dumps(build(sys.argv[1] if len(sys.argv)>1 else None),indent=2))
