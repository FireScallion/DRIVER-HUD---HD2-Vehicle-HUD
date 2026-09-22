-- Executes the built production payload with the existing engine/memory fixtures.
-- No real game, Win32 process or network requests are used by these tests.
local ROOT=arg[1] or '.'
local function slurp(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local hs=slurp(ROOT..'/tests/test_integration.lua')
-- The older 1.3.2 helper exported only fresh; this export enables a baseline
-- counter-test without changing any production function or fixture algorithm.
hs=hs:gsub('return {fresh=fresh} end','return {fresh=fresh,graph_fixture=graph_fixture} end')
local he=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)
 if k=='HUD_TEST_HELPERS' then return '1' end;return os.getenv(k)
end},{__index=os})},{__index=_G})
local load=assert(loadstring(hs,'@test_integration_helpers'));setfenv(load,he)
local helpers=load();local fresh,fixture=helpers.fresh,helpers.graph_fixture
local cases,failed,assertions=0,0,0
local function check(x,msg)assertions=assertions+1;assert(x,msg or 'check failed')end
local function eq(a,b,msg)check(a==b,(msg or 'equal')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,f)
 cases=cases+1;local ok,err=pcall(f)
 if ok then print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(err))end
end
local function wire(z)
 -- fresh() replaces Native.relation for UI tests; reload the real module here.
 z.N=assert(loadstring('local C={}\n'..slurp(ROOT..'/src/native_reader.lua')..'\nreturn Native'))()
 z.N.ready=true;z.N.base=z.base;z.N.ensure=function()return true end
 z.N.win={begin_sample=function()end,read=function(p,n)return z.m:read(p,n)end}
end
local function ready(tank)
 local h=fresh();local d=tank and h:add_tank(351,600) or h:add_frv(336,467)
 if tank then d.resource='16474112801385b6' end
 h:enter(d);h:tick(1);h:clean();return h,d
end
local function fail_relation(h,kind)
 h.a.Native.relation=function()return nil,'incomplete native read',kind or 'TRANSIENT_READ'end
end
local function assert_core(out)
 eq(out.hp[1],327);eq(out.hp[2],350);eq(out.damage[4],2);eq(out.body,2400)
 eq(out.precision,'UNKNOWN');eq(out.q,nil);eq(out.cache,nil);eq(out.synced_flags,nil);eq(out.sync_valid,false)
 check(out.calls<=960 and out.bytes<=65536,'sample budget unchanged')
end

test('sync short reads at root/table/cache/q2 preserve core and no partial enrichment',function()
 for _,area in ipairs({'root','table','cache','q2'}) do
  local z=fixture();z.m:w32(z.hr+3*440+248,327);z.m:w32(z.hr+3*440+32,0x80)
  local p=({root=z.base+z.N.roots.synced,table=z.sm+32,cache=z.sr+192,q2=z.rp+20})[area]
  local g=z.N.graph(function(a,n)if a==p then return nil end;return z.m:read(a,n)end,z.base)
  local out=g:health(z:d(),z.hashes);assert_core(out);eq(out.sync_error,'incomplete native read')
 end
end)
test('sync wrong owner and independently changed watches do not poison core validation',function()
 for _,how in ipairs({'wrong_owner','moved_root'}) do
  local z=fixture();z.m:w32(z.hr+3*440+248,327);z.m:w32(z.hr+3*440+32,0x80)
  if how=='wrong_owner' then z.m:w64(0x300006000+8,z.net+0xF32F18+24) end
  local g=z.N.graph(function(p,n)
   local b=z.m:read(p,n)
   if how=='moved_root' and p==z.rp+20 then z.m:w64(z.base+z.N.roots.synced,z.sm+0x1000) end
   return b
  end,z.base)
  assert_core(g:health(z:d(),z.hashes))
 end
end)
test('sync failure cannot hide a concurrent core owner or configuration change',function()
 for _,area in ipairs({'owner','configuration'}) do
  local z=fixture();local d=z:d()
  local g=z.N.graph(function(p,n)
   if p==z.base+z.N.roots.synced then
    z.m:w32(area=='owner' and (z.net+0xF32F18+4*24+8) or (z.cfg+0x208+96),123)
    return nil
   end
   return z.m:read(p,n)
  end,z.base)
  local ok,err=pcall(function()return g:health(d,z.hashes)end)
  eq(ok,false);eq(err,'identity changed during sample')
 end
end)
test('optional budget exhaustion reserves enough calls and bytes for core final validation',function()
 for _,limit in ipairs({'calls','bytes'}) do
  local z=fixture();z.m:w64(z.base+z.N.roots.synced,0)
  local core=z:health();z.m:w64(z.base+z.N.roots.synced,z.sm)
  z.m:w32(z.hr+3*440+248,327);z.m:w32(z.hr+3*440+32,0x80)
  local g=z:g()
  if limit=='calls' then g.calls=960-core.calls else g.bytes=65536-core.bytes end
  local out=g:health(z:d(),z.hashes);assert_core(out);eq(out.sync_error,'ancillary sample budget')
 end
end)
test('real relation wrapper classifies only plain short reads as transient',function()
 for _,how in ipairs({'short','late_collection','late_unit','no_seater','owner','guard'}) do
  local z=fixture();wire(z);local before=z.g and z:g():relation(315)
  if how=='guard' then z.N.ensure=function()return false,'unsupported game.dll PE identity'end
  elseif how=='owner' then z.m:w64(0x300007000,z.net+0xF32F18+24)
  elseif how=='late_collection' then z.m:w32(z.seatr,z.e2)
  elseif how=='late_unit' then z.m:w32(z.net+0xF32F18+4*24+12,900)
  elseif how=='no_seater' then z.m:table(z.seat+32,0x300004000,{}) end
  local reads=0
  z.N.win.read=function(p,n)
   if p==z.base+z.N.roots.seater then reads=reads+1;if how=='no_seater' and reads==2 then return nil end end
   if how=='short' and p==z.base+z.N.roots.network then return nil end
   if (how=='late_collection' or how=='late_unit') and p==z.seatr+0x1C then return nil end
   return z.m:read(p,n)
  end
  local result,_,kind=z.N.relation(315,1,before);eq(result,nil,how)
  eq(kind,how=='short' and 'TRANSIENT_READ' or how=='guard' and 'UNAVAILABLE' or 'INVALID',how)
 end
end)
test('short read keeps FRV visible without refreshing uncertain identity and then recovers',function()
 local h,d=ready();h:add_tank(351,600);h.objects[315].f[64][25]=351
 local resume=h.a.Native.relation;local reads=0;local health=h.a.Native.health
 h.a.Native.health=function(...)reads=reads+1;return health(...)end
 fail_relation(h);h:tick(.11);eq(h.a.FRV.mode,'FRV');eq(h.a.FRV.vehicle.entity,d.entity)
 check(h.a.FRV.grace_until~=nil);check(next(h.commands)~=nil);eq(reads,0);eq(h.a.M.hull,nil)
 h.a.Native.relation=resume;h.health[d.entity].hp[1]=327;h:tick(.12)
 eq(h.a.FRV.grace_until,nil);eq(h.a.FRV.data.hp[1],327);check(reads>0);h:clean()
end)
test('grace does not renew on repeated misses and expires without another poll',function()
 local h=ready();local at=h.a.FRV.relation_at
 fail_relation(h);h:tick(.11);local deadline=h.a.FRV.grace_until
 check(deadline~=nil);check(math.abs(deadline-(at+.3))<1e-9)
 h:tick(.09);eq(h.a.FRV.grace_until,deadline)
 h.a.FRV.next_poll=h.a.M.clock+10
 h.env.update(deadline-h.a.M.clock)
 eq(h.a.FRV.mode,'NONE');eq(h.a.FRV.vehicle,nil);eq(next(h.commands),nil)
 eq(h.a.FRV.last_relation,nil);eq(h.a.FRV.proxy_vehicle,nil);h:clean()
end)
test('tank grace freezes ammo display instead of refreshing an unconfirmed relation',function()
 local h=ready(true);eq(h.a.M.ammo,31);local resume=h.a.Native.relation
 fail_relation(h);h:tick(.11);eq(h.a.FRV.mode,'TANK');check(h.a.FRV.grace_until)
 h.objects[349].f[5]=12;h:tick(.05);eq(h.a.M.ammo,31)
 h.a.Native.relation=resume;h:tick(.15);eq(h.a.M.ammo,13);eq(h.a.FRV.grace_until,nil);h:clean()
end)
test('positive exit/absence/context change/despawn cancels active grace',function()
 for _,how in ipairs({'exit','empty','no_seater','session','avatar','world','despawn'}) do
  local h=ready();fail_relation(h);h:tick(.11);check(h.a.FRV.grace_until,how)
  if how=='exit' then h.seated=false
  elseif how=='empty' then h.a.Native.relation=function()return {status='EMPTY'}end
  elseif how=='no_seater' then h.a.Native.relation=function()return {status='NO_SEATER'}end
  elseif how=='session' then h.session='s2'
  elseif how=='avatar' then h.avatar=316;h.objects[316]={t='avatar',f={}}
  elseif how=='world' then h.world='new_world'
  else h.objects[336]=nil end
  h.a.FRV.next_poll=0;h:tick(1/60)
  eq(h.a.FRV.vehicle,nil,how);eq(h.a.M.hull,nil,how);eq(next(h.commands),nil,how);h:clean()
 end
end)
test('new identity after a short read never inherits damaged wheels from the old FRV',function()
 local h,a=ready();h.health[a.entity].hp[1]=0;h.health[a.entity].damage[1]=2;h:tick(.12)
 local resume=h.a.Native.relation;fail_relation(h);h:tick(.11);check(h.a.FRV.grace_until)
 local b=h:add_frv(345,599);h:enter(b);h.a.Native.relation=resume;h:tick(.12)
 eq(h.a.FRV.vehicle.entity,599);eq(h.a.FRV.data.hp[1],350);eq(h.a.FRV.data.damage[1],0);eq(h.a.FRV.grace_until,nil);h:clean()
end)
test('real relation observing a different collection before a late short read clears old HUD',function()
 local z=fixture();wire(z);local h=fresh()
 h:add_frv(363,z.e1);h:add_frv(462,z.e2)
 h.a.Native.relation=function(...)return z.N.relation(...)end
 h:enter(z:d());h:tick(.4);eq(h.a.FRV.vehicle.entity,z.e1)
 z.m:w32(z.seatr,z.e2)
 z.N.win.read=function(p,n)if p==z.seatr+0x1C then return nil end;return z.m:read(p,n)end
 h:tick(.11);eq(h.a.FRV.mode,'NONE');eq(h.a.FRV.grace_until,nil);eq(next(h.commands),nil)
 z.N.win.read=function(p,n)return z.m:read(p,n)end
 h:tick(.12);eq(h.a.FRV.vehicle.entity,z.e2);eq(h.a.FRV.data.hp[1],350);h:clean()
end)
test('proxy removal during grace clears the HUD even when its resolved Hull still exists',function()
 local h=fresh();local hull=h:add_frv(336,467)
 local proxy={entity=1128,goid=67,resource='e9cd1d0d118886af',unit=hull.unit,flags=1}
 h.objects[67]={t='seat_proxy',f={}};h.proxy_map={[1128]=hull};h:enter(proxy,2);h:tick(.4)
 fail_relation(h);h:tick(.11);check(h.a.FRV.grace_until);h.objects[67]=nil;h:tick(1/60)
 eq(h.a.FRV.vehicle,nil);eq(h.a.FRV.proxy_vehicle,nil);eq(next(h.commands),nil);h:clean()
end)
test('hard or unclassified failures never get grace or revive a stale tank reference',function()
 for _,kind in ipairs({'INVALID','UNAVAILABLE','unclassified'}) do
  local h=ready();h:add_tank(351,600);h.objects[315].f[64][25]=351
  fail_relation(h,kind);h:tick(.11)
  eq(h.a.FRV.grace_until,nil);eq(h.a.FRV.mode,'NONE');eq(h.a.FRV.vehicle,nil);eq(h.a.M.hull,nil);h:clean()
 end
end)
test('known Bastion driver/gunner and typed weapon skip FRV proxy enumeration',function()
 for _,how in ipairs({'driver','gunner','main','coax'}) do
  local h=fresh();local tank=h:add_tank(351,600);tank.resource='16474112801385b6'
  local d=tank
  if how=='main' or how=='coax' then d={goid=how=='main' and 349 or 350,entity=601,resource='1111111111111111',unit=8} end
  local proxy=0;h.a.Native.resolve_proxy=function()proxy=proxy+1;error('tank must not scan FRV Health')end
  h:enter(d,how=='gunner' and 1 or 0);h:tick(3)
  eq(proxy,0,how);eq(h.a.FRV.mode,'TANK',how);eq(h.a.M.hull,351);eq(h.a.M.ammo,31);eq(h.a.M.mg,2000);h:clean()
 end
end)
test('unknown FRV proxy retains precedence even if its fields resemble a tank',function()
 local h=fresh();local hull=h:add_frv(336,467)
 h:add_tank(67,1128)
 local proxy={entity=1128,goid=67,resource='e9cd1d0d118886af',unit=hull.unit,flags=1}
 h.proxy_map={[1128]=hull};h:enter(proxy,2);h:tick(.4)
 eq(h.a.FRV.mode,'FRV');eq(h.a.FRV.vehicle.entity,467);eq(h.a.M.hull,nil);h:clean()
 -- An unlisted actual tank retains the old fallback rather than being disabled.
 local other=fresh();other:enter(other:add_tank(351,600));other:tick(3)
 eq(other.a.FRV.mode,'TANK');eq(other.a.M.ammo,31);other:clean()
end)
test('known tank temporary batch starvation neither invokes proxy nor loses binding',function()
 local h=ready(true);h.a.Native.resolve_proxy=function()error('unnecessary proxy')end
 h.block_batches=true;h:tick(.25);eq(h.a.M.hull,351);eq(h.a.FRV.mode,'TANK')
 h.block_batches=false;h:tick(.2);eq(h.a.M.ammo,31);h:clean()
end)
test('invalid GS body values fall back to this sample native body, valid GS zero wins',function()
 for _,v in ipairs({{}, {hp=-1},{hp=2147483647},{hp=2400.5},{hp=0/0},{hp=math.huge},{hp='unknown'}}) do
  local h,d=ready();h.a.C.geometry_numbers=false;h.a.clear();h.health[d.entity].body=1673;h.objects[336].hp=v.hp;h:tick(.12)
  eq(h.a.FRV.hp,1673);eq(h.a.FRV.max,2400);eq(h:texts()[1].args[2],'1673');h:clean()
 end
 local h,d=ready();h.a.C.geometry_numbers=false;h.a.clear();h.health[d.entity].body=1673;h.objects[336].hp=0;h:tick(.12)
 eq(h.a.FRV.hp,0);eq(h:texts()[1].args[2],'0');h:clean()
end)
test('invalid body max/both sources stay unknown without hiding tires or reusing stale data',function()
 for _,v in ipairs({{}, {max=0},{max=-1},{max=0/0},{max=math.huge},{max='2400'}}) do
  local h=ready();h.a.C.geometry_numbers=false;h.a.clear();h.objects[336].max=v.max;h:tick(.12)
  eq(h.a.FRV.hp,nil);eq(h:texts()[1].args[2],'--');eq(h.a.FRV.data.hp[2],350);h:clean()
 end
 local h,d=ready();h.a.C.geometry_numbers=false;h.a.clear();h.health[d.entity].body=-1;h.objects[336].hp=-1;h:tick(.12)
 eq(h.a.FRV.hp,nil);eq(h.a.FRV.data.hp[1],350)
 h.health[d.entity].body=1200;h.objects[336].hp=1200;h:tick(.12);eq(h.a.FRV.hp,1200)
 h.health_fail=true;h.objects[336].hp=-1;h:tick(.12)
 eq(h.a.FRV.hp,nil);check(h.a.FRV.data~=nil,'last display exists but is not a native body fallback');h:clean()
end)
test('production graph-to-UI sync failure keeps body and hub, recovers normal tire bars',function()
 local z=fixture();z.m:w32(z.hr+3*440+32,2);z.m:w32(z.hr+3*440+248,0)
 local h=fresh();local d=h:add_frv(363,z.e1);d=z:d()
 local broken=true
 h.a.Native.health=function(vehicle)
  local g=z.N.graph(function(p,n)
   if broken and p==z.rp+20 then return nil end;return z.m:read(p,n)
  end,z.base)
  local ok,out=pcall(function()return g:health(vehicle,z.hashes)end)
  if ok then return out end;return nil,out
 end
 h:enter(d);h:tick(.3);eq(h.a.FRV.mode,'FRV');check(h.a.FRV.data~=nil)
 eq(h.a.FRV.hp,2400);eq(h.a.FRV.wheel_model(h.a.FRV.data,1).kind,'hub')
 eq(h.a.FRV.data.hp[2],350);eq(h.a.FRV.data.sync_valid,false);eq(h.a.FRV.data.precision,'UNKNOWN');h:clean()
 broken=false;h:tick(.12);eq(h.a.FRV.data.sync_valid,true);eq(h.a.FRV.wheel_model(h.a.FRV.data,2).kind,'tire')
 eq(h.a.FRV.wheel_model(h.a.FRV.data,2).ratio,1);h:clean()
end)
print(string.format('RESULT ROBUSTNESS cases=%d assertions=%d fails=%d',cases,assertions,failed))
if failed>0 then os.exit(1)end
