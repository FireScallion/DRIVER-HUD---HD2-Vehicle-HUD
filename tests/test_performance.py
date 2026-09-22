from pathlib import Path
import struct, json
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parent
old=(ROOT/'baseline_1.3.3.lua').read_text()
new=(ROOT.parent/'driver_hud.lua').read_text()
checks=0

def check(v,msg):
 global checks
 assert v,msg
 checks+=1

def native(source):
 l=LuaRuntime(encoding=None,unpack_returned_tuples=True)
 start=source.index('local Native = (function()');end=source.index('\n-- A small data-only',start)
 n=l.execute(('local C={}\n'+source[start:end]+'\nreturn Native').encode())
 return l,n

class Memory:
 def __init__(self): self.data={};self.calls=[];self.hook=None
 def put(self,p,b): self.data.update({p+i:v for i,v in enumerate(b)})
 def u32(self,p,v): self.put(p,struct.pack('<I',v))
 def ptr(self,p,v): self.put(p,struct.pack('<Q',v))
 def read(self,p,n):
  self.calls.append((p,n))
  if self.hook: self.hook(p,n)
  return bytes(self.data.get(p+i,0) for i in range(n))
 def table(self,p,entries,key,index=0):
  self.ptr(p,entries);self.u32(p+8,8);self.u32(p+12,0xffffffff);self.u32(p+16,1)
  for i in range(8): self.u32(entries+i*8,0xffffffff)
  self.u32(entries+(key%8)*8,key);self.u32(entries+(key%8)*8+4,index)

def fixture():
 m=Memory();base=0x100000;net=0x200000;hm=0x1400000;sm=0x1500000
 m.ptr(base+0x276F0C0,net);m.ptr(base+0x276C3B8,hm);m.ptr(base+0x276C9B0,sm)
 m.table(net+0xF19A70,0x3000000,101);m.table(net+0xF21A88,0x3001000,11)
 desc=struct.pack('<QIIII',int('cc21c7ffd3ebefb9',16),101,7,11,1)
 m.put(net+0xF31AD8,desc)
 m.table(hm+0x28,0x3002000,101);m.ptr(hm+0x40,0x3003000);m.ptr(0x3003000,0x3004000);m.put(0x3004000,desc)
 m.ptr(hm+0x50,0x3005000);m.u32(0x3005000+0x14,900);m.u32(0x3005000+0x20,8)
 for i,hp in enumerate([350,210,0,349]): m.u32(0x3005000+0xF8+i*4,hp)
 m.table(hm+0x68,0x3006000,101);cfg=0x3100000;m.ptr(hm+0xA8,cfg)
 for i,z in enumerate(['fed0a478','f3cb00ad','c6bf05a9','f12186b7']):
  m.u32(cfg+0x208+i*0x228+96,int(z,16));m.u32(cfg+0x208+i*0x228+232,350)
 m.table(sm+0x20,0x3200000,101);m.ptr(sm+0x38,0x3201000);m.ptr(0x3201000,0x3202000);m.put(0x3202000,desc)
 m.ptr(sm+0x40,0x3203000);m.ptr(sm+0x50,0x3204000);m.u32(0x3204000+4,0b11001011)
 return m,base

def run_health(source,alter=None):
 l,n=native(source);m,base=fixture()
 if alter: alter(m)
 d=l.table_from({b'entity':101,b'goid':11,b'unit':7,b'resource':b'cc21c7ffd3ebefb9'})
 zones=l.table_from([b'fed0a478',b'f3cb00ad',b'c6bf05a9',b'f12186b7'])
 g=n.graph(m.read,base)
 try:
  r=g.health(g,d,zones)
  return {k:r[k] for k in [b'body',b'precision',b'sync_valid']}|{k:[r[k][i] for i in range(1,5)] for k in [b'hp',b'hp_valid',b'max',b'damage']},len(m.calls),None
 except Exception as e: return None,len(m.calls),str(e).split('\n')[0]

baseline=[]
for label,alter in [
 ('healthy',None),('sync absent',lambda m:m.ptr(0x100000+0x276C9B0,0)),
 ('sync wrong owner',lambda m:m.u32(0x3202000+8,999)),
 ('one wheel out of range',lambda m:m.u32(0x3005000+0xF8,999)),
 ('wrong zone',lambda m:m.u32(0x3100000+0x208+96,0)),
 ('wrong core owner',lambda m:m.u32(0x3004000+8,102))]:
 a,ac,ae=run_health(old,alter);b,bc,be=run_health(new,alter)
 check(a==b and ae==be,'health parity '+label)
 baseline.append([label,ac,bc])
check(baseline[0][2]<baseline[0][1],'health reduces reads')
# Watch validation must remain fresh, including overlaps, mutation, bounds.
l,n=native(new);m=Memory();m.put(0x10000,b'abcdefghijklmnop')
g=n.graph(m.read,0);g.watch(g,0x10000,8);g.watch(g,0x10008,8);g.watch(g,0x10004,8)
count=len(m.calls);g.validate(g);check(len(m.calls)-count==1,'coalesced fresh validation')
m.put(0x10009,b'X')
try:g.validate(g);check(False,'mutation rejected')
except Exception as e:check('identity changed' in str(e),'mutation rejected')
# Verify full script compiles in the game's LuaJIT dialect.
l.execute(b'assert(loadstring(...))',new.encode());check(True,'LuaJIT syntax')
# Ammo readers and sampling intervals must be byte-for-byte unchanged.
for start,end in [('local function read_coax(', 'local function hash_of_field('),('local function read_main(', 'local function refresh_bound('),('local function refresh_bound(', '-- Version-scoped'),('function FRV.wheel_model(', 'function FRV.color('),('local material=', 'local function update(')]:
 check(old[old.index(start):old.index(end)]==new[new.index(start):new.index(end)],'frozen '+start)

# Integration fixture runs the production update / reset / wrapper path.
setup=r'''
owned_calls=0;reads=0;draws=0;motion=false;session=1;peer=1;world=10;avatar=2;fail_owned=false
stingray={Application={worlds=function()return {10,20}end,main_world=function()return world end},
 Network={game_session=function()return session end,peer_id=function()return peer end},
 GameSession={in_session=function()return true end,objects_owned_by=function()owned_calls=owned_calls+1;if not fail_owned then return {0}end end,
 game_object_is_type=function(s,id,t)return id==0 and t=='un6y1d'end,game_object_exists=function(s,id)return id~=nil end,
 game_object_field=function(s,id,f)if id==0 then return avatar end;if f=='motion_enabled' or f=='rotation_enabled' then return motion end;return 0 end},
 World={create_screen_gui=function()return 1 end,destroy_gui=function()end},Gui={resolution=function()return 1920,1080 end}}
update=function()end
'''
def full(source):
 l=LuaRuntime(unpack_returned_tuples=True);l.execute(setup)
 src=source.rsplit('return {installed=true}',1)[0]+'return {M=M,FRV=FRV,Native=Native,update=update,sample=sample,refresh=refresh_bound,C=C,wrapped=_G.update}'
 t=l.execute(src)
 l.globals().T=t
 l.execute("T.FRV.poll=function()T.FRV.mode='FRV';T.FRV.vehicle={entity=1,goid=3};return 'FRV'end;T.FRV.draw=function()draws=draws+1 end")
 return l,t
l,t=full(new)
for _ in range(144):t.update(1/144)
check(5<=l.globals().owned_calls<=6,'stable ownership 5 Hz')
check(l.globals().draws==144,'render still per frame')
l.globals().motion=True;t.update(1/144);check(not t.M.seated and t.FRV.vehicle is None,'exit clears immediately')
l.globals().motion=False;t.update(1/144);check(t.M.seated,'reentry')
l.globals().avatar=4;t.update(1/144);check(t.M.avatar==4,'avatar change immediate')
l.globals().session=2;t.update(1/144);check(t.M.session==2,'session reset immediate')
l.globals().fail_owned=True
for _ in range(32):t.update(1/144)
check(not t.M.seated,'ownership failure resets')
# Stable tank relation avoids a redundant batch; changed identity cannot use it.
l,t=full(new)
l.execute("T.M.hull=12;T.M.vehicle_ref=12;T.FRV.mode='TANK';stingray.GameSession.game_object_field=function()reads=reads+1 end")
check(t.FRV.poll_tank(1,l.table_from({'goid':12}))=='TANK','same tank retained')
check(l.globals().reads==0,'stable tank no redundant field read')
l.execute("T.FRV.clear_identity('test')")
check(t.M.hull is None,'identity clear drops fast path')
print(json.dumps({'checks':checks,'native_read_counts_old_new':baseline},indent=2))
# Execute the actual Win32 adapter with fake OS calls backed by local bytes.
# This covers protection-cache lifetime and RPM failure after a cached check.
def adapter(source):
 l,n=native(source);m,base=fixture();vq=[0];failed=[False]
 def query(p):
  vq[0]+=1;start=(p//4096)*4096
  return struct.pack('<QQIIQIIII',start,start,4,0,4096,4096,4,0,0)
 l.globals().memread=m.read;l.globals().query=query;l.globals().rpmfail=lambda:failed[0]
 l.execute(b'''local real=require('ffi')
 local kernel={GetCurrentProcess=function()return 1 end,GetModuleHandleA=function()return real.cast('void *',0x100000)end}
 kernel.VirtualQuery=function(p,out,n)local b=query(tonumber(real.cast('uintptr_t',p)));real.copy(out,b,48);return 48 end
 kernel.ReadProcessMemory=function(h,p,out,n,got)
  if rpmfail() then got[0]=0;return 0 end
  local b=memread(tonumber(real.cast('uintptr_t',p)),n);real.copy(out,b,n);got[0]=n;return 1
 end
 local shim={os='Windows',abi=function()return true end,cdef=real.cdef,new=real.new,cast=real.cast,string=real.string,load=function()return kernel end}
 require=function()return shim end''')
 w=n.open_win32();return l,n,m,base,w,vq,failed
adapter_counts=[]
for src in (old,new):
 l,n,m,base,w,vq,failed=adapter(src)
 if w.begin_sample: w.begin_sample()
 g=n.graph(w.read,base)
 d=l.table_from({b'entity':101,b'goid':11,b'unit':7,b'resource':b'cc21c7ffd3ebefb9'})
 zones=l.table_from([b'fed0a478',b'f3cb00ad',b'c6bf05a9',b'f12186b7'])
 r=g.health(g,d,zones);check(r[b'body']==900,'adapter health')
 adapter_counts.append([len(m.calls),vq[0]])
check(adapter_counts[1][1]<adapter_counts[0][1],'VirtualQuery reduced')
c=vq[0];w.read(0x3005000,4);check(vq[0]==c,'same sample metadata reused')
failed[0]=True;check(w.read(0x3005000,4) is None,'RPM failure still rejected')
failed[0]=False;w.begin_sample();w.read(0x3005000,4);check(vq[0]==c+1,'next sample rechecks protection')
print(json.dumps({'final_checks':checks,'adapter_RPM_VirtualQuery_old_new':adapter_counts},indent=2))

# Optional profiler must not change the update chain or fail at its flush boundary.
l,t=full(new);t.C.perf=True
for _ in range(1441): t.wrapped(1/144)
check(t.M.frame==1441 and l.globals().draws==1441,'profiler wrapper and flush')
print('TOTAL',checks,'PASS')
l,n,m,base,w,vq,failed=adapter(new);n.perf=True;w.begin_sample()
w.read(0x3005000,4);w.read(0x3005004,4)
check(w.stats[b'reads']==2 and w.stats[b'queries']==1 and w.stats[b'bytes']==8,'native profiler counters')
print('FINAL',checks,'PASS')
