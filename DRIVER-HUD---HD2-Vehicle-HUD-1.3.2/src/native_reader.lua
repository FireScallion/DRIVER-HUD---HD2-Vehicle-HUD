-- Version-scoped, identity-keyed readers. Only the Win32 adapter reads memory.
-- Pure Lua byte decoding avoids rounding uint64 resource IDs through doubles.
local Native = (function()
 local N={version='r3-cc75948d',ready=false,next_check=0}
 N.roots={network=0x276F0C0,health=0x276C3B8,synced=0x276C9B0,seater=0x276CA88}
 N.pe={machine=0x8664,sections=16,timestamp=0x6A86132E,size=0x3A6B000,checksum=0xEE0D37}
 local function u32(s,o)
  local a,b,c,d=s:byte(o+1,o+4)
  if not d then error('short uint32',0) end
  return a+b*256+c*65536+d*16777216
 end
 local function i32(s,o) local v=u32(s,o);return v>=2147483648 and v-4294967296 or v end
 local function hex64(s,o) return string.format('%08x%08x',u32(s,o+4),u32(s,o)) end
 local function ptr(s,o)
  local lo,hi=u32(s,o),u32(s,o+4)
  if hi>=32768 then error('noncanonical pointer',0) end
  return hi*4294967296+lo
 end
 local function addr(p,n)
  if type(p)~='number' or p~=math.floor(p) or p<65536 or p>=140737488355328
   or type(n)~='number' or n<1 or n>4096 or n~=math.floor(n) or p+n>140737488355328 then error('read bounds',0) end
 end
 local function mul32(a,b)
  local al,ah=a%65536,math.floor(a/65536)
  local bl,bh=b%65536,math.floor(b/65536)
  return (al*bl+((ah*bl+al*bh)%65536)*65536)%4294967296
 end
 local function mod64hex(h,n)
  local hi,lo=tonumber(h:sub(1,8),16),tonumber(h:sub(9,16),16)
  return ((hi%n)*(4294967296%n)+lo%n)%n
 end
 N.u32=u32;N.i32=i32;N.hex64=hex64;N.ptr=ptr;N.mul32=mul32;N.mod64hex=mod64hex
 function N.q4(word)
  local out={};for i=0,3 do out[i+1]=math.floor(word/4^i)%4 end;return out
 end
 local G={};G.__index=G
 function N.graph(read,base)
  return setmetatable({raw=read,base=base,calls=0,bytes=0,watches={},seen={}},G)
 end
 function G:read(p,n)
  addr(p,n)
  if self.calls>=960 or self.bytes+n>65536 then error('native sample budget',0) end
  self.calls=self.calls+1;self.bytes=self.bytes+n
  local b=self.raw(p,n)
  if type(b)~='string' or #b~=n then error('incomplete native read',0) end
  return b
 end
 function G:watch(p,n)
  local key=string.format('%.0f:%d',p,n);local old=self.seen[key]
  if old then return old end
  local b=self:read(p,n);self.seen[key]=b;self.watches[#self.watches+1]={p,n,b};return b
 end
 function G:validate()
  for _,w in ipairs(self.watches) do if self:read(w[1],w[2])~=w[3] then error('identity changed during sample',0) end end
 end
 function G:root(name)
  local p=ptr(self:watch(self.base+N.roots[name],8),0)
  if p==0 then error(name..' manager not ready',0) end
  addr(p,1);return p
 end
 function G:table(p)
  local b=self:watch(p,20);local cap=u32(b,8)
  if cap>1048576 or (cap>0 and 2^math.floor(math.log(cap)/math.log(2)+0.5)~=cap) then error('invalid table capacity',0) end
  local t={p=p,entries=ptr(b,0),capacity=cap,empty=u32(b,12),multiplier=u32(b,16)}
  if cap>0 then addr(t.entries,1) end;return t
 end
 function G:lookup(t,key)
  if type(key)~='number' or key<0 or key>4294967295 or key~=math.floor(key) then error('invalid identity key',0) end
  if key==t.empty or t.capacity==0 then return nil end
  local first=mul32(key,t.multiplier)%t.capacity
  for step=0,math.min(t.capacity,64)-1 do
   local b=self:watch(t.entries+((first+step)%t.capacity)*8,8)
   local k,j=u32(b,0),u32(b,4)
   if k==key then
    if j==4294967295 then return nil end
    if j>=1048576 then error('invalid dense index',0) end
    return j
   end
   if k==t.empty then return nil end
  end
  error('identity lookup probe limit',0)
 end
 function G:descriptor(p)
  local b=self:watch(p,24)
  return {address=p,resource=hex64(b,0),entity=u32(b,8),unit=u32(b,12),goid=u32(b,16),flags=u32(b,20)}
 end
 local function same(a,b)
  return a and b and a.entity==b.entity and a.goid==b.goid and a.resource==b.resource and a.unit==b.unit
 end
 N.same=same
 function G:net(root,key,by_entity)
  if key==4294967295 or (not by_entity and key==32767) then return nil end
  local j=self:lookup(self:table(root+(by_entity and 0xF19A70 or 0xF21A88)),key)
  if j==nil then return nil end
  local d=self:descriptor(root+0xF31AD8+j*24)
  if (by_entity and d.entity or d.goid)~=key then error('network key mismatch',0) end
  return d
 end
 function G:roundtrip(root,d)
  local f=self:net(root,d.entity,true);local b=f and self:net(root,f.goid,false)
  if not same(d,f) or not same(d,b) then error('network roundtrip mismatch',0) end
 end
 function G:component(manager,entity,to,dp)
  local j=self:lookup(self:table(manager+to),entity)
  if j==nil then return nil end
  local array=ptr(self:watch(manager+dp,8),0)
  local d=self:descriptor(ptr(self:watch(array+j*8,8),0))
  if d.entity~=entity then error('component owner mismatch',0) end
  return j,d
 end
 function G:relation(avatar_goid)
  local net,seater=self:root('network'),self:root('seater')
  local av=self:net(net,avatar_goid,false)
  if not av then error('avatar not in native network table',0) end
  self:roundtrip(net,av)
  local j,ad=self:component(seater,av.entity,0x20,0x38)
  if j==nil then self:validate();return {status='NO_SEATER'} end
  if not same(av,ad) then error('Seater avatar mismatch',0) end
  local base=ptr(self:watch(seater+0x48,8),0)
  local e=u32(self:watch(base+j*0x40,4),0)
  if e==0 or e==4294967295 then self:validate();return {status='EMPTY'} end
  local d=self:net(net,e,true)
  if not d or d.goid<=0 or d.goid>=32767 then error('collection not network-linked',0) end
  self:roundtrip(net,d)
  local role=i32(self:read(base+j*0x40+0x1C,4),0)
  self:validate()
  return {status='VEHICLE',vehicle=d,avatar=av,role=role}
 end
 -- Resolve a SeatCollection/proxy descriptor to a FRV Hull without spatial or GOID heuristics.
 -- The only accepted edge is an exact shared native unit key, a known FRV resource,
 -- a Health component and a unique candidate. Table enumeration is limited to the
 -- typed Health entity index; this is not a process/address-space scan.
 function G:frv_hull_for_proxy(collection,known_resources)
  if not collection or type(collection.unit)~='number' or collection.unit<=0 or collection.unit==4294967295 then
   return nil,{reason='proxy has no usable unit key'}
  end
  local net,hm=self:root('network'),self:root('health')
  local live=self:net(net,collection.entity,true)
  if not same(live,collection) then error('proxy identity changed before resolve',0) end
  self:roundtrip(net,live)
  local t=self:table(hm+0x28)
  if t.capacity==0 then return nil,{reason='Health table empty',capacity=0,entries=0,candidates=0} end
  if t.capacity>4096 then error('Health table too large for proxy resolver',0) end
  local bytes=t.capacity*8;local raw={};local off=0
  while off<bytes do
   local n=math.min(4096,bytes-off)
   raw[#raw+1]=self:watch(t.entries+off,n);off=off+n
  end
  raw=table.concat(raw)
  local descs=ptr(self:watch(hm+0x40,8),0)
  local entries,candidates=0,{}
  for pos=0,#raw-8,8 do
   local entity,j=u32(raw,pos),u32(raw,pos+4)
   if entity~=t.empty and j~=4294967295 then
    entries=entries+1
    if j>=1048576 then error('Health dense index outside safety bound',0) end
    local dp=ptr(self:watch(descs+j*8,8),0)
    local d=self:descriptor(dp)
    if d.entity~=entity then error('Health table/descriptor owner mismatch',0) end
    if d.unit==collection.unit and d.entity~=collection.entity and known_resources[d.resource] then
     self:roundtrip(net,d);candidates[#candidates+1]=d
    end
   end
  end
  local meta={reason='no exact same-unit FRV Health owner',unit=collection.unit,capacity=t.capacity,entries=entries,candidates=#candidates}
  if #candidates==1 then meta.reason='unique_same_unit_health';return candidates[1],meta end
  if #candidates>1 then meta.reason='ambiguous same-unit FRV Health owners' end
  self:validate();return nil,meta
 end
 function G:configuration(net,hm,d,expected_zones)
  local j=self:lookup(self:table(hm+0x68),d.entity);local cfg
  if j~=nil then cfg=ptr(self:watch(hm+0xA8,8),0)+j*0x5650
  else
   local t=ptr(self:watch(net+0xF11738,8),0)
   local start=mod64hex(d.resource,984)
   for step=0,63 do
    local b=self:watch(t+((start+step)%984)*16,16);local key=hex64(b,0)
    if key==d.resource then
     local k=u32(b,8);if k>=984 then error('Health settings index',0) end
     cfg=t+0x3D80+k*0x5650;break
    elseif key=='0000000000000000' then break end
   end
  end
  if not cfg then error('no identity-linked Health configuration',0) end
  local max={}
  for i=0,3 do
   local zone=cfg+0x208+i*0x228
   local name=string.format('%08x',u32(self:watch(zone+96,4),0))
   if name~=expected_zones[i+1] then error('wheel zone identity mismatch',0) end
   local mx=i32(self:read(zone+232,4),0)
   if mx<=0 or mx>1000000 then error('invalid wheel maximum',0) end
   max[i+1]=mx
  end
  return max
 end
 function G:health(d,expected_zones)
  local net,hm=self:root('network'),self:root('health')
  self:roundtrip(net,d)
  local hi,hd=self:component(hm,d.entity,0x28,0x40)
  if hi==nil or not same(hd,d) then error('no matching Health component',0) end
  local hpbase=ptr(self:watch(hm+0x50,8),0)
  local record=hpbase+hi*0x1B8
  local data=self:read(record,0x1B8)
  local max=self:configuration(net,hm,hd,expected_zones)
  local hp,hp_valid={},{}
  for i=0,3 do
   local v=i32(data,0xF8+4*i);hp[i+1]=v
   -- Runtime HP can briefly leave [0,max] around a damage transition.  This is
   -- a per-zone data-quality issue, not grounds to discard the other wheels.
   -- Keep the raw value for diagnostics and let the UI fall back to q2 for
   -- this wheel only.  Destroyed state still wins independently in wheel_model.
   hp_valid[i+1]=(v>=0 and v<=max[i+1])
  end
  local out={hp=hp,hp_valid=hp_valid,max=max,body=i32(data,0x14),damage=N.q4(u32(data,0x20)),
   state_low=u32(data,0x20),health_index=hi,health_record=record,flags=hd.flags,precision='UNKNOWN'}
  -- SyncedHealth is ancillary: its absence must not manufacture values or
  -- suppress a valid Health damage state. A complete snapshot still rechecks IDs.
  local sm=ptr(self:watch(self.base+N.roots.synced,8),0)
  if sm~=0 then
   local si,sd=self:component(sm,d.entity,0x20,0x38)
   if si~=nil then
    if not same(hd,sd) then error('SyncedHealth owner mismatch',0) end
    local array=ptr(self:watch(sm+0x40,8),0);local rep=ptr(self:watch(sm+0x50,8),0)
    local cache=self:read(array+si*0xC0,16);local word=u32(self:read(rep+si*16+4,4),0)
    out.q=N.q4(word);out.cache={};out.synced_flags=sd.flags
    for i=0,3 do out.cache[i+1]=i32(cache,4*i) end
    if hd.flags%2==1 and sd.flags%2==1 then out.precision='LOCAL_RUNTIME'
    else out.precision='QUANTIZED_OR_UNKNOWN' end
   end
  end
  self:validate();out.bytes=self.bytes;out.calls=self.calls
  return out
 end
 N.guards={{0xd3e734,"4c8b1d8509a301448bc24c8bc981faff7f000075108b055d8ea4018901488bc1"},{0x634244,"4c8b1d4d88130245896f1041c7471cffffffff41893f3b3d002a1502"},{0x9171b7,"488b4d408bd8488b0cd9e87ab6beff4869cbb8010000488b5c243048034d50488b6c243848056802000039307426ff"},{0x6aaae8,"8b81f80000004189028b81fc000000418942048b8100010000418942088b81040100004189420c"},{0x6ac968,"488d144048c1e20641ffd18b0b33d2488943404c8d0449488bc849c1e006e855ba72"},{0x6ab270,"478b4cb4048d4bfc448b97d8fdffff418bc1d3e80f57c983e003f3480f2ac8f30f5eca4183fa"}}
 function N.check_module(read,base)
  local b=read(base,512)
  if not b or #b~=512 or b:sub(1,2)~='MZ' then return false,'module header unreadable' end
  local off=u32(b,0x3C)
  if off<64 or off>4096 then return false,'module PE offset' end
  local p=read(base+off,112)
  if not p or #p~=112 or p:sub(1,4)~='PE\0\0' then return false,'module PE signature' end
  local machine=p:byte(5)+256*p:byte(6);local sections=p:byte(7)+256*p:byte(8)
  if machine~=N.pe.machine or sections~=N.pe.sections or u32(p,8)~=N.pe.timestamp
   or u32(p,80)~=N.pe.size or u32(p,88)~=N.pe.checksum then return false,'unsupported game.dll PE identity' end
  for _,v in ipairs(N.guards) do
   local want=v[2]:gsub('..',function(h)return string.char(tonumber(h,16))end)
   if read(base+v[1],#want)~=want then return false,string.format('native code guard 0x%X',v[1]) end
  end
  return true,'PE+6 reviewed code guards'
 end
 function N.open_win32()
  local ok,ffi=pcall(require,'ffi')
  if not ok or not ffi or ffi.os~='Windows' or not ffi.abi('64bit') then return nil,'LuaJIT FFI / Windows x64 unavailable' end
  -- No game native calls; all pointed-to bytes go through RPM into owned buffers.
  local declarations={
   'void * __stdcall GetCurrentProcess(void);',
   'void * __stdcall GetModuleHandleA(const char *);',
   'int __stdcall ReadProcessMemory(void *, const void *, void *, size_t, size_t *);',
   'size_t __stdcall VirtualQuery(const void *, void *, size_t);'}
  for _,s in ipairs(declarations) do pcall(ffi.cdef,s) end
  local loaded,k=pcall(ffi.load,'kernel32');if not loaded then return nil,'kernel32 unavailable' end
  local h=k.GetCurrentProcess();local buffer=ffi.new('uint8_t[4096]')
  local got=ffi.new('size_t[1]');local mbi=ffi.new('uint8_t[48]')
  local w={}
  function w.base()
   local p=k.GetModuleHandleA('game.dll')
   if p==nil then return nil end
   return tonumber(ffi.cast('uintptr_t',p))
  end
  function w.read(p,n)
   addr(p,n)
   local at,finish=p,p+n
   for _=1,4 do
    if at>=finish then break end
    local z=tonumber(k.VirtualQuery(ffi.cast('const void *',at),ffi.cast('void *',mbi),48))
    if z~=48 then return nil end
    local b=ffi.string(mbi,48);local start=ptr(b,0);local extent=ptr(b,24)
    local state,protection=u32(b,32),u32(b,36);local kind=protection%256
    if state~=4096 or math.floor(protection/256)%2==1
     or not (kind==2 or kind==4 or kind==8 or kind==32 or kind==64 or kind==128)
     or start>at or extent==0 or start+extent<=at then return nil end
    at=math.min(finish,start+extent)
   end
   if at<finish then return nil end
   got[0]=0
   local success=k.ReadProcessMemory(h,ffi.cast('const void *',p),buffer,n,got)
   if success==0 or tonumber(got[0])~=n then return nil end
   return ffi.string(buffer,n)
  end
  return w
 end
 function N.ensure(now)
  if N.disabled then return false,N.reason end
  if now<N.next_check then return N.ready,N.reason end
  N.next_check=now+10
  if not N.win then
   local ok,w,why=pcall(N.open_win32)
   if not ok or not w then N.disabled=true;N.reason=why or tostring(w);return false,N.reason end
   N.win=w
  end
  local base=N.win.base()
  if not base then N.ready=false;N.next_check=now+1;N.reason='game.dll not yet loaded';return false,N.reason end
  local ok,valid,why=pcall(N.check_module,N.win.read,base)
  if not ok or not valid then
   N.ready=false;N.reason=why or tostring(valid)
   -- Retry loaded-code checks slowly (initialization), never use failed offsets.
   N.next_check=now+10;return false,N.reason
  end
  N.ready=true;N.base=base;N.reason=why;return true
 end
 function N.relation(avatar,now)
  local valid,why=N.ensure(now)
  if not valid then return nil,why end
  local ok,result=pcall(function()return N.graph(N.win.read,N.base):relation(avatar)end)
  if ok then return result end;return nil,tostring(result)
 end
 function N.resolve_proxy(collection,known_resources)
  if not N.ready then return nil,'native version not validated' end
  local ok,result,meta=pcall(function()
   local g=N.graph(N.win.read,N.base)
   local d,m=g:frv_hull_for_proxy(collection,known_resources)
   g:validate();return d,m
  end)
  if ok then return result,meta end
  return nil,tostring(result)
 end
 function N.health(vehicle,zones)
  if not N.ready then return nil,'native version not validated' end
  local ok,result=pcall(function()return N.graph(N.win.read,N.base):health(vehicle,zones)end)
  if ok then return result end;return nil,tostring(result)
 end
 return N
end)()
