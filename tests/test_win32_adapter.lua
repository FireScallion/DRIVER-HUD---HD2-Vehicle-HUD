-- Exercise production adapter with real LuaJIT FFI owned buffers, fake Win32 calls.
local root=arg[1] or '.'
local file=assert(io.open(root..'/src/native_reader.lua','rb'));local source=file:read('*a');file:close()
local ffi=require('ffi');local state={protect=4,committed=4096,partial=false,vqsize=48,calls=0}
local base=0x100000000
local k={}
k.GetCurrentProcess=function()return ffi.cast('void *',-1)end
k.GetModuleHandleA=function()return ffi.cast('void *',base)end
k.VirtualQuery=function(p,buffer,n)
 ffi.fill(buffer,48,0)
 local u=ffi.cast('uint64_t *',buffer);u[0]=base;u[1]=base;u[3]=4096
 local w=ffi.cast('uint32_t *',buffer);w[8]=state.committed;w[9]=state.protect
 return state.vqsize
end
k.ReadProcessMemory=function(handle,p,b,n,got)
 state.calls=state.calls+1;ffi.fill(b,n,65);got[0]=state.partial and n-1 or n;return 1
end
local proxy=setmetatable({os='Windows',abi=function(x)return x=='64bit'end,load=function(name)assert(name=='kernel32');return k end},{__index=ffi})
local env=setmetatable({C={},require=function(name)if name=='ffi'then return proxy end;return require(name)end},{__index=_G})
local chunk=assert(loadstring(source..'\nreturn Native'));setfenv(chunk,env);local N=chunk();local w=assert(N.open_win32());local checks=0
local function check(value,label)checks=checks+1;assert(value,label);print('PASS '..label)end
check(w.base()==base,'module pointer converted without precision loss')
check(w.read(base+32,16)==string.rep('A',16),'RPM copies exact length into owned buffer')
state.partial=true;check(w.read(base,16)==nil,'partial reads rejected');state.partial=false
w.begin_sample();state.protect=0x104;check(w.read(base,16)==nil,'guard pages rejected before RPM')
w.begin_sample();state.protect=1;check(w.read(base,16)==nil,'NOACCESS rejected')
w.begin_sample();state.protect=4;state.committed=0x10000;check(w.read(base,16)==nil,'uncommitted pages rejected')
w.begin_sample();state.committed=4096;state.vqsize=0;check(w.read(base,16)==nil,'failed VirtualQuery rejected')
w.begin_sample();state.vqsize=48;check(w.read(base+4090,32)==nil,'read crossing unknown region rejected')
check(not pcall(w.read,0,16),'null/unbounded read rejected')
check(not pcall(w.read,base,4097),'oversized request rejected')
check(state.calls==2,'guarded cases never call RPM')
N.perf=true;w.begin_sample();state.protect=4;state.committed=4096;state.vqsize=48
check(w.read(base+32,4)==string.rep('A',4),'new sample readable')
check(w.read(base+36,4)==string.rep('A',4),'same-sample read works')
check(w.stats.reads==2 and w.stats.queries==1 and w.stats.bytes==8,'per-sample protection cache and profiler counters')
state.partial=true;check(w.read(base+40,4)==nil,'cached protection never hides RPM short read');state.partial=false
w.begin_sample();w.read(base+40,4);check(w.stats.queries==2,'next sample invalidates protection cache')
print('RESULT WIN32_ADAPTER checks='..checks..' fails=0 (MOCK_WIN32, OWNED_FFI_BUFFERS, runtime='..tostring(jit and jit.version or _VERSION)..')')
