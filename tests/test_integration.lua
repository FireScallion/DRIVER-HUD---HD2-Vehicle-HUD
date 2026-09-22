-- Target runtime: LuaJIT 2.1. Engine APIs and memory are synthetic.
-- See validation report for the actual runner used in this delivery.
local ROOT=arg[1] or '.'
local function slurp(p) local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local SOURCE=slurp(ROOT..'/driver_hud.lua')
local count,failed=0,0
local function eq(a,b,label) if a~=b then error((label or 'comparison')..': '..tostring(a)..' ~= '..tostring(b),2) end end
local function near(a,b) if math.abs(a-b)>1e-5 then error(tostring(a)..' not near '..tostring(b),2) end end
local function test(name,f)
 count=count+1;local ok,err=pcall(f)
 if ok then print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local function fresh(config_text)
 local h={objects={},logs={},commands={},batches={},owned={0,315},player=0,avatar=315,seated=false,session='s1',world='main',peer='p1',cursor=false,width=1920,height=1080,next_id=0,original_calls=0}
 local env=setmetatable({},{__index=_G});env._G=env
 local function vec(x,y,z)return {x=x or 0,y=y or 0,z=z or 0,[1]=x,[2]=y,[3]=z}end
 env.os={getenv=function()return '/mock'end}
 env.io={open=function(p,mode)
  if p:match('driver_hud.cfg$') and mode=='r' and config_text then
   local lines={};for line in (config_text..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end
   return {lines=function()local i=0;return function()i=i+1;return lines[i]end end,close=function()end}
  end
  if mode=='a' then return {write=function(_,...)local t={...};for i,v in ipairs(t)do t[i]=tostring(v)end;h.logs[#h.logs+1]=table.concat(t)end,close=function()end}end
  if p:match('frv_hud_position.json$') and h.position_json then return {read=function()return h.position_json end,close=function()end}end
 end}
 local gs={}
 gs.game_object_exists=function(_,id)return h.objects[id]~=nil end
 gs.game_object_is_type=function(_,id,t)return h.objects[id] and h.objects[id].t==t or false end
 gs.game_object_field_batched=function(_,id)
  local frame=h.a.M.frame;h.batches[frame]=(h.batches[frame] or 0)+1
  if h.block_batches then return nil end
  return h.objects[id] and h.objects[id].f
 end
 gs.in_session=function()return true end;gs.objects_owned_by=function()return h.owned end
 gs.game_object_field=function(_,id,key)
  local o=h.objects[id];if not o then return nil end
  if id==h.player and key=='baegche' then return h.avatar end
  if id==h.avatar then
   if key=='motion_enabled' or key=='rotation_enabled' then if h.missing_seated then return nil end;return not h.seated end
   if key=='gls4w9b' then return 100 end;if key=='state' then return 0 end
  end
  if key=='nZ5Vxt8x' then return o.max elseif key=='sd7m7FWA' then return o.hp end
 end
 local net={game_session=function()return h.session end,peer_id=function()return h.peer end}
 net.object_info=function(t)
  if h.bad_schema then return {fields={}} end
  for _,p in pairs(h.a.FRV.profiles)do if p.t==t then local f={};for i,v in ipairs(p.fields)do f[i]={id=v}end;return {fields=f}end end
 end
 local gui={resolution=function()return h.width,h.height end}
 local function command(kind,...)
  h.next_id=h.next_id+1;h.commands[h.next_id]={kind=kind,args={...}};return h.next_id
 end
 gui.triangle=function(...)return command('triangle',...)end
 gui.text=function(...)return command('text',...)end
 gui.destroy_triangle=function(_,id)h.commands[id]=nil end;gui.destroy_text=gui.destroy_triangle
 gui.text_extents=function(_,s,font,size)
  -- Includes asymmetric bearings: this catches old character-count centering.
  return vec(-1,-3),vec(#s*size*0.53-2,size*0.75)
 end
 env.stingray={Application={worlds=function()return {h.world,'ui'}end,main_world=function()return h.world end},
  Network=net,GameSession=gs,World={create_screen_gui=function()return 'gui'end,destroy_gui=function()end},Gui=gui,
  Vector2=setmetatable({x=function(v)return v[1]end,y=function(v)return v[2]end},{__call=function(_,...)return vec(...)end}),Vector3=vec,Color=function(...)return {...}end,Window={show_cursor=function()return h.cursor end}}
 env.update=function()h.original_calls=h.original_calls+1 end
 local exports='return {installed=true,test={Tank=Tank,M=M,Native=Native,FRV=FRV,Position=Position,C=C,HudNumber=HudNumber,update=update,clear=clear,reset=full_reset,refresh=refresh_bound}}'
 local s,n=SOURCE:gsub('return {installed=true}%s*$',exports);assert(n==1)
 local chunk=assert(loadstring(s,'@production_payload.lua'));setfenv(chunk,env)
 h.a=assert(chunk()).test;h.env=env
 h.objects[0]={t='un6y1d',f={}};h.objects[315]={t='avatar',f={[64]={[25]=32767}}}
 h.relation={status='EMPTY'}
 h.a.Native.relation=function()return h.relation,h.native_error or 'synthetic_read_failure'end
 h.a.Native.health=function(d)
  if h.health_fail then return nil,'synthetic_health_failure' end
  return h.health[d.entity]
 end
 h.a.Native.resolve_proxy=function(d)
  local x=h.proxy_map and h.proxy_map[d.entity]
  if x then return x,{reason='unique_same_unit_health',unit=d.unit,entries=3,candidates=1} end
  return nil,{reason='no exact same-unit FRV Health owner',unit=d.unit,entries=3,candidates=0}
 end
 h.health={}
 function h:add_frv(id,entity,resource)
  resource=resource or 'cc21c7ffd3ebefb9';local p=self.a.FRV.profiles[resource]
  self.objects[id]={t=p.t,hp=2400,max=2400,f={}}
  local d={entity=entity,goid=id,resource=resource,unit=entity*7,flags=1}
  self.health[entity]={hp={350,350,350,350},max={350,350,350,350},q={3,3,3,3},damage={0,0,0,0},precision='LOCAL_RUNTIME',body=2400,flags=1,synced_flags=1,health_index=7,health_record=123456,bytes=3000,calls=64}
  return d
 end
 function h:add_tank(id,entity)
  self.objects[id]={t='tank',hp=8000,max=8000,f={[15]=8000,[30]=8000,[22]=14,[56]={id-2,id-1}}}
  self.objects[id-2]={t='rHVbvgIu',f={[5]=30,[6]=1,[11]=1}}
  self.objects[id-1]={t='fZwFCDKT',f={[6]=2000,[11]=0}}
  return {entity=entity,goid=id,resource='1122334455667788',unit=entity*7,flags=1}
 end
 function h:enter(d,role)self.seated=true;self.relation={status='VEHICLE',vehicle=d,avatar={entity=446,goid=self.avatar},role=role or 0}end
 function h:tick(seconds,dt)
  dt=dt or 1/60
  for i=1,math.ceil(seconds/dt)do self.env.update(dt)end
 end
 function h:clean()
  for _,l in ipairs(self.logs)do assert(not l:find('HUD_RECOVERABLE_ERROR',1,true),l);assert(not l:find('FRV_DRAW_ERROR',1,true),l)end
  for _,v in pairs(self.batches)do assert(v<=4,'batch limit')end
 end
 function h:texts()local a={};for _,v in pairs(self.commands)do if v.kind=='text'then a[#a+1]=v end end;return a end
 return h
end
-- Sparse synthetic memory, fed through the EXACT production graph reader.
local function memory(N)
 local m={b={}}
 function m:put(p,s)for i=1,#s do self.b[p+i-1]=s:byte(i)end end
 function m:zero(p,n)self:put(p,string.rep('\0',n))end
 function m:w32(p,x)local t={};x=x%4294967296;for i=1,4 do t[i]=string.char(x%256);x=math.floor(x/256)end;self:put(p,table.concat(t))end
 function m:w64(p,x)self:w32(p,x%4294967296);self:w32(p+4,math.floor(x/4294967296))end
 function m:resource(p,h)self:w32(p,tonumber(h:sub(9),16));self:w32(p+4,tonumber(h:sub(1,8),16))end
 function m:read(p,n)local b={};for i=0,n-1 do if self.b[p+i]==nil then return nil end;b[#b+1]=string.char(self.b[p+i])end;return table.concat(b)end
 function m:table(p,ep,items,empty,mult)
  empty=empty or 0;mult=mult or 2654435761
  self:w64(p,ep);self:w32(p+8,16);self:w32(p+12,empty);self:w32(p+16,mult)
  self:zero(ep,128);for i=0,15 do self:w32(ep+i*8,empty)end
  for _,v in ipairs(items)do
   local slot=N.mul32(v[1],mult)%16
   while N.u32(self:read(ep+slot*8,4),0)~=empty do slot=(slot+1)%16 end
   self:w32(ep+slot*8,v[1]);self:w32(ep+slot*8+4,v[2])
  end
 end
 function m:descriptor(p,e,g,res,flag,unit)
  self:resource(p,res or 'cc21c7ffd3ebefb9');self:w32(p+8,e);self:w32(p+12,unit or (e*7)%4294967296);self:w32(p+16,g);self:w32(p+20,flag or 1)
 end
 return m
end
local function graph_fixture()
 local N=fresh().a.Native;local m=memory(N)
 local z={N=N,m=m,base=0x100000000,net=0x200000000,hm=0x210000000,sm=0x220000000,seat=0x230000000,hr=0x400000000,sr=0x500000000,rp=0x600000000,seatr=0x700000000}
 z.av,z.e1,z.e2=0x0200000c,0x0100000c,0x0100001c
 for name,p in pairs({network=z.net,health=z.hm,synced=z.sm,seater=z.seat})do m:w64(z.base+N.roots[name],p)end
 m:table(z.net+0xF1AEB0,0x300000000,{{z.av,2},{z.e1,4},{z.e2,1}})
 m:table(z.net+0xF22EC8,0x300001000,{{315,2},{363,4},{462,1}})
 for _,v in ipairs({{z.av,315,2},{z.e1,363,4},{z.e2,462,1}})do m:descriptor(z.net+0xF32F18+v[3]*24,v[1],v[2])end
 m:table(z.hm+0x1030,0x300002000,{{z.e1,3},{z.e2,0}})
 m:table(z.sm+0x20,0x300003000,{{z.e1,1},{z.e2,0}})
 m:table(z.seat+0x20,0x300004000,{{z.av,0}})
 m:w64(z.hm+0x1048,0x300005000);m:w64(z.sm+0x38,0x300006000)
 m:w64(z.seat+0x38,0x300007000);m:w64(0x300007000,z.net+0xF32F18+2*24)
 m:w64(z.seat+0x48,z.seatr);m:zero(z.seatr,64);m:w32(z.seatr,z.e1)
 m:w64(z.hm+0x1058,z.hr);m:w64(z.sm+0x40,z.sr);m:w64(z.sm+0x50,z.rp)
 for _,v in ipairs({{z.e1,363,3,1,4},{z.e2,462,0,0,1}})do
  local dp=z.net+0xF32F18+v[5]*24
  m:w64(0x300005000+v[3]*8,dp);m:w64(0x300006000+v[4]*8,dp)
  m:zero(z.hr+v[3]*440,440);m:w32(z.hr+v[3]*440+20,2400)
  m:zero(z.sr+v[4]*192,192);m:zero(z.rp+v[4]*16,16);m:w32(z.rp+v[4]*16+4,0xffffffff)
  for i=0,3 do m:w32(z.hr+v[3]*440+248+4*i,350);m:w32(z.sr+v[4]*192+4*i,350)end
 end
 m:table(z.hm+0x1070,0x300008000,{})
 z.st=0x800000000;m:w64(z.net+0xF12B78,z.st);m:zero(z.st,1002*16)
 local slot=N.mod64hex('cc21c7ffd3ebefb9',1002)
 m:resource(z.st+slot*16,'cc21c7ffd3ebefb9');m:w32(z.st+slot*16+8,0)
 z.cfg=z.st+0x3EA0; m:zero(z.cfg,0x5650) -- Real mapped configuration includes inter-field bytes read by 1.3.4 batching.
 local hashes=fresh().a.FRV.zone_hashes
 for i=0,3 do m:w32(z.cfg+0x208+i*552+96,tonumber(hashes[i+1],16));m:w32(z.cfg+0x208+i*552+232,350)end
 z.hashes=hashes
 function z:g()return self.N.graph(function(p,n)return self.m:read(p,n)end,self.base)end
 function z:d(e)return self:g():net(self.net,e or self.e1,true)end
 function z:health(e)return self:g():health(self:d(e),self.hashes)end
 return z
end

if os.getenv('HUD_TEST_HELPERS')=='1' then return {fresh=fresh,graph_fixture=graph_fixture} end

test('native table uses full entity and separate dense index domains',function()
 local z=graph_fixture();local r=z:g():relation(315);eq(r.vehicle.entity,z.e1);eq(r.vehicle.goid,363)
 local a,b=z:health(),z:health(z.e2);eq(a.health_index,3);eq(b.health_index,0);eq(a.hp[1],350);eq(a.precision,'LOCAL_RUNTIME');assert(a.calls<200);assert(a.bytes<12000)
end)
test('native proxy resolves only unique same-unit known FRV Health owner',function()
 local z=graph_fixture();local N,m=z.N,z.m
 local proxy=0x0100003c;local proxy_goid=67;local proxy_idx=6
 local e1desc=z.net+0xF32F18+4*24;local unit=N.u32(m:read(e1desc+12,4),0)
 m:table(z.net+0xF1AEB0,0x300000000,{{z.av,2},{z.e1,4},{z.e2,1},{proxy,proxy_idx}})
 m:table(z.net+0xF22EC8,0x300001000,{{315,2},{363,4},{462,1},{proxy_goid,proxy_idx}})
 m:descriptor(z.net+0xF32F18+proxy_idx*24,proxy,proxy_goid,'e9cd1d0d118886af',1,unit)
 local g=z:g();local pd=g:net(z.net,proxy,true)
 local d,meta=g:frv_hull_for_proxy(pd,{['cc21c7ffd3ebefb9']=true,['9b2140378640432e']=true})
 eq(d.entity,z.e1);eq(d.goid,363);eq(meta.reason,'unique_same_unit_health')
 local e2desc=z.net+0xF32F18+1*24;m:w32(e2desc+12,unit)
 local g2=z:g();local pd2=g2:net(z.net,proxy,true);local d2,meta2=g2:frv_hull_for_proxy(pd2,{['cc21c7ffd3ebefb9']=true,['9b2140378640432e']=true})
 eq(d2,nil);eq(meta2.candidates,2)
end)
test('native same-model simultaneous entities have isolated wheel HP',function()
 local z=graph_fixture();z.m:w32(z.hr+3*440+248,327);eq(z:health().hp[1],327);eq(z:health(z.e2).hp[1],350)
end)
test('native dense compaction re-resolves pointer and index',function()
 local z=graph_fixture();z:health();local old=z.m:read(z.hr+3*440,440)
 z.m:put(z.hr+440,old);z.m:w32(z.hr+440+248,222)
 z.m:table(z.hm+0x1030,0x300002000,{{z.e1,1},{z.e2,0}});z.m:w64(0x300005000+8,z.net+0xF32F18+4*24)
 local r=z:health();eq(r.hp[1],222);eq(r.health_index,1);eq(r.health_record,z.hr+440)
end)
test('native owner mismatch fails closed',function()local z=graph_fixture();z.m:w64(0x300005000+24,z.net+0xF32F18+24);eq(pcall(function()z:health()end),false)end)
test('native reverse mapping mismatch fails closed',function()local z=graph_fixture();z.m:table(z.net+0xF22EC8,0x300001000,{{315,2},{363,1},{462,4}});eq(pcall(function()z:g():relation(315)end),false)end)
test('native unknown zone configuration rejected',function()local z=graph_fixture();z.m:w32(z.cfg+0x208+96,0);eq(pcall(function()z:health()end),false)end)
test('native out-of-range wheel HP invalidates only that wheel',function()
 for _,hp in ipairs({-1,351})do
  local z=graph_fixture();z.m:w32(z.hr+3*440+248,hp);local r=z:health()
  eq(r.hp[1],hp);eq(r.hp_valid[1],false);eq(r.hp_valid[2],true);eq(r.hp[2],350)
 end
end)
test('native local/remote precision distinct and q2 low-byte decode',function()local z=graph_fixture();z.m:w32(z.net+0xF32F18+4*24+20,0);z.m:w32(z.rp+16+4,0xfffffffe);local r=z:health();eq(r.precision,'QUANTIZED_OR_UNKNOWN');eq(r.q[1],2);eq(r.q[4],3)end)
test('native damage words are independent of HP and q2',function()local z=graph_fixture();z.m:w32(z.hr+3*440+0x20,0x82);local r=z:health();eq(r.damage[1],2);eq(r.damage[2],0);eq(r.damage[4],2)end)
test('native absent synced component keeps damage but unknown precision',function()local z=graph_fixture();z.m:w64(z.base+z.N.roots.synced,0);local r=z:health();eq(r.precision,'UNKNOWN');eq(r.damage[1],0);eq(r.q,nil)end)
test('native collection zero means empty, no nearest fallback',function()local z=graph_fixture();z.m:w32(z.seatr,0);eq(z:g():relation(315).status,'EMPTY')end)
test('native watches detect an owner change after initial read',function()local z=graph_fixture();local g=z:g();g:net(z.net,z.e1,true);z.m:w32(z.net+0xF32F18+4*24+8,123);eq(pcall(function()g:validate()end),false)end)
test('native table non-power-two and short reads rejected',function()local z=graph_fixture();z.m:w32(z.hm+0x1038,15);eq(pcall(function()z:health()end),false);local g=z.N.graph(function(p,n)return string.rep('\0',n-1)end,z.base);eq(pcall(function()g:relation(315)end),false)end)
test('native budget and noncanonical pointer rejected',function()local z=graph_fixture();local g=z:g();g.calls=959;eq(#g:read(z.hm+0x1058,8),8);eq(pcall(function()g:read(z.hm+0x1058,8)end),false);z.m:w64(z.base+z.N.roots.health,140737488355328);eq(pcall(function()z:health()end),false)end)
test('native hash multiplication does not lose low bits in double arithmetic',function()local n=fresh().a.Native;eq(n.mul32(4294967295,4294967295),1);eq(n.mul32(0xFEDCBA98,0x9E3779B1),0x7176DB18);eq(n.mod64hex('cc21c7ffd3ebefb9',1002),325)end)
-- Module gate is tested against source guard bytes in a synthetic PE.
test('module PE identity plus all reviewed exact code guards required',function()
 local n=fresh().a.Native;local m=memory(n);local b=0x100000000;m:zero(b,512);m:put(b,'MZ');m:w32(b+0x3c,272);m:put(b+272,'PE\0\0');m:put(b+276,string.char(0x64,0x86,16,0))
 m:w32(b+280,n.pe.timestamp);m:w32(b+272+80,n.pe.size);m:w32(b+272+88,n.pe.checksum)
 for _,g in ipairs(n.guards)do m:put(b+g[1],g[2]:gsub('..',function(h)return string.char(tonumber(h,16))end))end
 local read=function(p,len)return m:read(p,len)end;eq(n.check_module(read,b),true)
 m:w32(b+280,1);eq(n.check_module(read,b),false);m:w32(b+280,n.pe.timestamp);m:put(b+n.guards[1][1],'\0');eq(n.check_module(read,b),false)
end)
-- Actual complete production update and drawings, with mocked engine calls.
test('player GOID zero and HMG native seat show FRV, no numeric wheel HP',function()
 local h=fresh();h.a.C.geometry_numbers=false;h:enter(h:add_frv(336,467));h:tick(1);eq(h.a.M.player,0);eq(h.a.FRV.mode,'FRV');eq(h.a.FRV.vehicle.entity,467);eq(#h:texts(),1);eq(h:texts()[1].args[2],'2400');h:clean()
end)
test('Supply driver/passenger share same entity and continuous HP',function()
 local h=fresh();local d=h:add_frv(327,457,'9b2140378640432e');h:enter(d,0);h:tick(.5);h:enter(d,2);h.health[457].hp[1]=327;h:tick(.3)
 eq(h.a.FRV.vehicle.entity,457);near(h.a.FRV.wheel_model(h.a.FRV.data,1).ratio,327/350);h:clean()
end)
test('two identical FRVs switch by explicit identity without stale data',function()
 local h=fresh();local a=h:add_frv(336,467);local b=h:add_frv(345,599);h.health[467].damage[1]=2;h.health[467].hp[1]=0
 h:enter(a);h:tick(.3);eq(h.a.FRV.data.damage[1],2);h:enter(b);h:tick(.3);eq(h.a.FRV.vehicle.entity,599);eq(h.a.FRV.data.hp[1],350);eq(h.a.FRV.data.damage[1],0);h:clean()
end)
test('rear-seat proxy relation resolves exact FRV Hull and never uses proxy as Health owner',function()
 local h=fresh();local hull=h:add_frv(336,467)
 local proxy={entity=1128,goid=67,resource='e9cd1d0d118886af',unit=hull.unit,flags=1}
 h.proxy_map={[1128]=hull};h.objects[67]={t='seat_proxy',f={}}
 h:enter(proxy,2);h:tick(.4)
 eq(h.a.FRV.mode,'FRV');eq(h.a.FRV.vehicle.entity,467);eq(h.a.FRV.vehicle.goid,336)
 assert(table.concat(h.logs):find('FRV_PROXY_RESOLVE',1,true));h:clean()
end)
test('unresolved proxy stays hidden and cannot fall to nearby FRV',function()
 local h=fresh();h:add_frv(336,467)
 local proxy={entity=1128,goid=67,resource='e9cd1d0d118886af',unit=777,flags=1}
 h.objects[67]={t='seat_proxy',f={}};h:enter(proxy,2);h:tick(.6)
 eq(h.a.FRV.mode,'NONE');eq(h.a.FRV.vehicle,nil);eq(h.a.M.hull,nil);eq(next(h.commands),nil)
 assert(table.concat(h.logs):find('FRV_PROXY_REJECT',1,true));h:clean()
end)
test('tank direct driver entry retains body main 31 and coax 2000',function()
 local h=fresh();h:enter(h:add_tank(351,600));h:tick(3);eq(h.a.FRV.mode,'TANK');eq(h.a.M.hull,351);eq(h.a.M.hp,8000);eq(h.a.M.ammo,31);eq(h.a.M.mg,2000);h:clean()
end)
test('tank direct-to-gunner native identity does not require prior driving',function()
 local h=fresh();h:enter(h:add_tank(351,600),1);h:tick(3);eq(h.a.M.hull,351);eq(h.a.M.ammo,31);eq(h.a.M.mg,2000);h:clean()
end)
test('tank to FRV to tank clears shared GUI and restores ammunition',function()
 local h=fresh();h.a.C.geometry_numbers=false;local tank=h:add_tank(351,600);local frv=h:add_frv(336,467)
 h:enter(tank);h:tick(2);eq(h.a.M.hull,351);h:enter(frv);h:tick(.5);eq(h.a.M.hull,nil);eq(#h:texts(),1);eq(h.a.FRV.vehicle.entity,467)
 h:enter(tank);h:tick(2);eq(h.a.FRV.vehicle,nil);eq(h.a.M.hull,351);eq(h.a.M.ammo,31);assert(#h:texts()>1);h:clean()
end)
test('native read failure cannot revive stale avatar tank ref after FRV',function()
 local h=fresh();h:add_tank(351,600);local d=h:add_frv(336,467);h.objects[315].f[64][25]=351
 h:enter(d);h:tick(.3);h.relation=nil;h:tick(.4);eq(h.a.FRV.mode,'NONE');eq(h.a.M.hull,nil);eq(h.a.FRV.vehicle,nil);eq(next(h.commands),nil);h:clean()
end)
test('native initially unavailable retains 1.2.1 direct tank fallback',function()
 local h=fresh();h:add_tank(351,600);h.seated=true;h.relation=nil;h.objects[315].f[64][25]=351;h:tick(4);eq(h.a.M.hull,351);eq(h.a.M.ammo,31);h:clean()
end)
test('invalid schema rejects FRV and never falls through to tank',function()
 local h=fresh();h.bad_schema=true;h:enter(h:add_frv(336,467));h:tick(1);eq(h.a.FRV.vehicle,nil);eq(h.a.M.hull,nil);eq(next(h.commands),nil);h:clean()
end)
test('positive vehicle exit clears FRV immediately',function()
 local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.seated=false;h:tick(1/60);eq(h.a.FRV.vehicle,nil);eq(h.a.M.seated,false);eq(next(h.commands),nil);h:clean()
end)
test('missing seated data has bounded grace, not indefinite HUD',function()
 local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.missing_seated=true;h:tick(.2);eq(h.a.M.seated,true);h:tick(.6);eq(h.a.M.seated,false);eq(h.a.FRV.vehicle,nil);h:clean()
end)
test('despawn and unsupported collection hide old HUD',function()
 local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.objects[336]=nil;h:tick(.3);eq(h.a.FRV.vehicle,nil)
 h:enter({goid=550,entity=999,resource='0000000000000010',unit=1});h.objects[550]={t='unsupported',f={}};h:tick(.3);eq(h.a.M.hull,nil);eq(h.a.FRV.mode,'NONE');h:clean()
end)
test('session and avatar changes clear old identity before new read',function()
 local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.session='s2';h.relation={status='EMPTY'};h:tick(.1);eq(h.a.FRV.vehicle,nil);eq(h.a.M.hull,nil);h:clean()
end)
test('health failure expires bars but retains valid body-only FRV',function()
 local h=fresh();h.a.C.geometry_numbers=false;h:enter(h:add_frv(336,467));h:tick(.3);h.health_fail=true;h:tick(.6);eq(h.a.FRV.data,nil);eq(h.a.FRV.hp,2400);eq(#h:texts(),1);eq(h.a.M.hull,nil);h:clean()
end)
test('all four tire state2 and 0x02/0x80/0x82 mappings',function()
 local a=fresh().a
 for _,word in ipairs({0,2,128,130})do local states=a.Native.q4(word);local data={hp={0,0,0,0},max={350,350,350,350},damage=states,precision='LOCAL_RUNTIME'}
  for i=1,4 do eq(a.FRV.wheel_model(data,i).kind,states[i]==2 and 'hub' or 'tire')end
 end
end)
test('q2 zero, HP zero, unknown state1 or state3 never invent destroyed',function()
 local f=fresh().a.FRV
 for _,st in ipairs({0,1,3})do
  for _,hp in ipairs({97,28,0})do local d={hp={hp},max={350},q={0},damage={st},precision='LOCAL_RUNTIME'};eq(f.wheel_model(d,1).kind,'tire');d.precision='QUANTIZED_OR_UNKNOWN';local m=f.wheel_model(d,1);eq(m.kind,'tire');near(m.upper,1/3)end
 end
end)
test('one invalid local wheel falls back to q2 without blanking other wheels',function()
 local f=fresh().a.FRV
 local d={hp={-23,186,104,350},hp_valid={false,true,true,true},max={350,350,350,350},q={0,1,0,3},damage={0,0,0,0},precision='LOCAL_RUNTIME'}
 local a,b,c,e=f.wheel_model(d,1),f.wheel_model(d,2),f.wheel_model(d,3),f.wheel_model(d,4)
 eq(a.kind,'tire');eq(a.precision,'QUANTIZED_OR_UNKNOWN');near(a.ratio,0)
 eq(b.precision,'LOCAL_RUNTIME');near(b.ratio,186/350)
 eq(c.precision,'LOCAL_RUNTIME');near(c.ratio,104/350)
 eq(e.precision,'LOCAL_RUNTIME');near(e.ratio,1)
end)
test('destroyed wheel remains hub even when raw HP is invalid',function()
 local f=fresh().a.FRV
 local d={hp={-77,350,350,350},hp_valid={false,true,true,true},max={350,350,350,350},q={0,3,3,3},damage={2,0,0,0},precision='LOCAL_RUNTIME'}
 eq(f.wheel_model(d,1).kind,'hub');eq(f.wheel_model(d,2).kind,'tire')
end)
test('runtime Health sample with one invalid wheel keeps other three readable',function()
 local h=fresh();local d=h:add_frv(336,467);h:enter(d);h:tick(.3)
 h.health[467].hp={-1,186,104,350};h.health[467].hp_valid={false,true,true,true};h.health[467].q={0,1,0,3};h:tick(.3)
 eq(h.a.FRV.data.hp_valid[1],false);near(h.a.FRV.wheel_model(h.a.FRV.data,2).ratio,186/350);near(h.a.FRV.wheel_model(h.a.FRV.data,4).ratio,1);h:clean()
end)
test('body contour and number thresholds include exactly 75 and 50 percent',function()
 local f=fresh().a.FRV;eq(f.color(0.7501)[2],244);eq(f.color(.75)[2],205);eq(f.color(.5001)[2],205);eq(f.color(.5)[2],96)
 local h=fresh();h.a.C.geometry_numbers=false;local d=h:add_frv(336,467);h.objects[336].hp=1800;h:enter(d);h:tick(.3);local t=h:texts()[1];eq(t.args[7][3],205)
 h.objects[336].hp=1200;h:tick(.3);t=h:texts()[1];eq(t.args[7][3],96);h:clean()
end)
test('body number uses min+max bounds for exact x/y centering',function()
 local h=fresh();h.a.C.geometry_numbers=false;h:enter(h:add_frv(336,467));h:tick(.3);local t=h:texts()[1].args;local x,y,s=h.a.FRV.layout(1920,1080)
 local lo,hi=h.env.stingray.Gui.text_extents(nil,t[2],nil,t[4]);near(t[6].x+(lo.x+hi.x)/2,x+64*s);near(t[6].y+(lo.y+hi.y)/2,y+62*s)
end)
test('Vector2 accessor-only text extents stay on the native font path',function()
 local h=fresh();h.a.C.geometry_numbers=false;h.env.stingray.Gui.text_extents=function(_,label,font,size)return {-1,-3},{#label*size*.53-2,size*.75}end
 h:enter(h:add_frv(336,467));h:tick(.3);eq(#h:texts(),1);h:clean()
end)
test('no text extents gracefully uses centered geometric body digits',function()
 local h=fresh();h.env.stingray.Gui.text_extents=nil;h:enter(h:add_frv(336,467));h:tick(.3);eq(#h:texts(),0);assert(next(h.commands));h:clean()
end)
test('cursor hides HUD, close cursor redraws without data changes',function()local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.cursor=true;h:tick(.1);eq(next(h.commands),nil);h.cursor=false;h:tick(.1);assert(next(h.commands));h:clean()end)
test('position data-only dictionary parsing and bounds',function()
 local p=fresh().a.Position
 local good=assert(p.parse('{"_说明":"坐标从左上角计算", "x":0,"y":1,"scale":0.5}'));eq(good.x,0);eq(good.y,1)
 assert(p.parse('\239\187\191{"x":0.7,"y":0.9,"scale":1}'))
 for _,s in ipairs({'{"x":2,"y":.1,"scale":1}','{"x":0.5,"x":0.6,"y":0.5,"scale":1}','{"x":0.5,"y":0.5}','{"x":0.5,"y":0.5,"scale":3}','{"x":0.5,"y":0.5,"scale":1,}','{"x":0.5,"y":0.5,"scale":1,"run":"code"}','return os.execute("anything")'})do eq(p.parse(s),nil,s)end
end)
test('position hot reload applies after 2s and invalid file keeps last good',function()
 local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);local base=h.a.Position.revision
 h.position_json='{"x":0.4,"y":0.3,"scale":1.2}';h:tick(2.1);eq(h.a.Position.x,.4);eq(h.a.Position.y,.3);eq(h.a.Position.revision,base+1)
 h.position_json='{"x":99,"y":0.3,"scale":1.2}';h:tick(2.1);eq(h.a.Position.x,.4);h:clean()
end)
test('FRV position uses top-left fractions, is independent of tank scale',function()
 local h=fresh();local p=h.a.Position;p.x=.4;p.y=.3;p.scale=1;h.a.C.scale=2
 local x,y,s=h.a.FRV.layout(1920,1080);near(s,1);near(x+64,768);near(y+62,756)
 p.x=0;p.y=1;local lx,ly=h.a.FRV.layout(1920,1080);assert(lx>=8 and ly>=8)
end)
test('10 Hz native poll remains useful at 10 FPS and batch cap respected',function()local h=fresh();h:enter(h:add_frv(336,467));h:tick(2,.1);eq(h.a.FRV.vehicle.entity,467);h:clean();eq(h.original_calls,20)end)
test('recoverable drawing errors never stop game original update',function()local h=fresh();h.env.stingray.Gui.triangle=function()error('mock draw failure')end;h:enter(h:add_frv(336,467));h:tick(.5);eq(h.original_calls,30);assert(table.concat(h.logs):find('FRV_DRAW_ERROR',1,true))end)
test('public reset closes native lifecycle state, not shadowed local',function()local h=fresh();h:enter(h:add_frv(336,467));h:tick(.3);h.a.reset();eq(h.a.FRV.vehicle,nil);eq(h.a.FRV.native_seen,false);eq(h.a.M.hull,nil)end)
-- Optional generated capture replay: only reduced numerical observations, no pointers.
local replay=loadfile(ROOT..'/tests/capture_fixture.lua')
if replay then
 test('replay all 98 captured vehicle rows through production wheel model',function()
  local rows=replay();local f=fresh().a.FRV;eq(#rows,98);local hubs=0
  for _,r in ipairs(rows)do
   for i=1,4 do
    local m=f.wheel_model(r,i)
    if r.damage[i]==2 then eq(m.kind,'hub');hubs=hubs+1
    else eq(m.kind,'tire');near(m.ratio,r.hp[i]/r.max[i])end
   end
  end
  assert(hubs>0)
 end)
end
print(string.format('RESULT HUD_INTEGRATION cases=%d fails=%d',count,failed))
if failed>0 then os.exit(1)end
