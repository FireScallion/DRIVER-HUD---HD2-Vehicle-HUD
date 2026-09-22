"""Checks packaged source identity and stable-release install assets. Does not launch HD2."""
from pathlib import Path
import hashlib,json,struct,sys,zipfile,re
ROOT=Path(__file__).resolve().parents[1]
archive=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'DRIVER_HUD_1.3.2.zip'
checks=[]
def check(name,ok):
 checks.append({'name':name,'pass':bool(ok)})
 if not ok: raise AssertionError(name)
with zipfile.ZipFile(archive) as z:
 check('ZIP CRC',z.testzip() is None)
 names=z.namelist();check('no path traversal',all(not n.startswith('/') and '..' not in Path(n).parts for n in names))
 required=['manifest.json','CONFIGURE_FRV_HUD.cmd','Tools/FRV_HUD_Configurator.ps1','README.txt','README_中文.txt','CHANGELOG.txt']
 check('stable root/configurator assets present',all(n in names for n in required))
 check('legacy manual JSON helper removed','APPLY_FRV_POSITION.cmd' not in names and 'frv_hud_position.json' not in names)
 manifest=json.loads(z.read('manifest.json'));check('stable manifest identity',manifest['Version']==1 and manifest['Guid']=='9e31f36d-3865-4af5-b9b3-5368261394d0' and manifest['Name']=='DRIVER HUD 1.3.2')
 check('Arsenal only deploys CORE',manifest['Options'][0]['Include']==['CORE'])
 payload=z.read('CORE/9ba626afa44a3aa3.patch_0');source=(ROOT/'driver_hud.lua').read_bytes()
 check('installed Lua equals built source',payload[192:]==source)
 check('both archive lengths updated',struct.unpack_from('<I',payload,160)[0]==len(source)+8 and struct.unpack_from('<I',payload,184)[0]==len(source))
 check('stable runtime label',b'DRIVER_HUD 1.3.2 START native_contract=' in source and b'1.3.2 TEST START' not in source)
 check('per-wheel HP fault isolation present',b'hp_valid' in source and b"data.hp_valid[i]~=false" in source)
 check('old whole-FRV wheel HP reject removed',b'wheel HP outside configuration' not in source)
 expected=json.loads((ROOT/'evidence/baseline_resources.json').read_text())
 check('retained material and auxiliary assets byte-identical',all(hashlib.sha256(z.read(n)).hexdigest()==digest for n,digest in expected.items()))
 cmd=z.read('CONFIGURE_FRV_HUD.cmd')
 ps=z.read('Tools/FRV_HUD_Configurator.ps1')
 check('launcher is extraction-safe and PowerShell-only',b'Tools\\FRV_HUD_Configurator.ps1' in cmd and b'powershell.exe' in cmd.lower() and b'runas' not in cmd.lower() and b'python ' not in cmd.lower())
 check('configurator uses WinForms and per-user config',b'System.Windows.Forms' in ps and b'Arrowhead\\Helldivers2' in ps and b'frv_hud_position.json' in ps)
 check('configurator bilingual',all(x in ps for x in [b'FRV HUD Position Adjustment','FRV HUD'.encode()]) and 'FRV HUD位置修改'.encode('utf-8') in ps)
 check('configurator provides x y scale apply reset',all(x in ps for x in [b'Horizontal position',b'Vertical position',b"Scale = 'Scale'",b"Apply = 'Apply'",b"Reset = 'Reset Defaults'"]))
 check('no game dump executable DLL or font distribution',not any(n.lower().endswith(('.dll','.exe','.ttf','.otf','.dmp','.mem.bin'))for n in names))
 en=z.read('README.txt').decode('utf-8');zh=z.read('README_中文.txt').decode('utf-8')
 check('README position headings updated','FRV HUD Position Adjustment' in en and 'FRV HUD位置修改' in zh and '字典含义' not in zh)
 check('README requested technical sections removed',all(term not in en for term in ['HD2 HUD+','Precision and compatibility','q2==0','native Seater']) and all(term not in zh for term in ['HD2 HUD+','数值精度与损毁状态','版本兼容与验证范围','q2==0','原生玩家→座位集合→车辆实体关系']))
 check('README graphical configurator instructions present','CONFIGURE_FRV_HUD.cmd' in en and 'CONFIGURE_FRV_HUD.cmd' in zh and 'VS Code' in en and 'VS Code' in zh)
 check('stage files equal package',all((ROOT/'package'/n).read_bytes()==z.read(n) for n in names))
 check('third-party credits kept',b'CowboyBingus' in z.read('CREDITS.txt') and b'DDRK1NG' in z.read('CREDITS.txt'))
report={'archive':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'size_bytes':archive.stat().st_size,'checks':checks,'total':len(checks),'fails':sum(not c['pass']for c in checks)}
(ROOT/'evidence/package_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('RESULT PACKAGE checks=%d fails=%d'%(report['total'],report['fails']))
