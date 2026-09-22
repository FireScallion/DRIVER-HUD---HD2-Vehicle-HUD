-- New-build offsets are fixture literals independent from the production constants.
-- All data below is synthetic; no live game functions are invoked.
local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='HUD_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local load=assert(loadstring(read(ROOT..'/tests/test_integration.lua')));setfenv(load,env);local helpers=load()
local count,failed,assertions=0,0,0
local function check(x,s)assertions=assertions+1;assert(x,s or 'check failed')end
local function eq(a,b,s)check(a==b,(s or 'equal')..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b,s)check(math.abs(a-b)<1e-5,s or ('not near '..a..' '..b))end
local function test(name,f)count=count+1;local ok,e=pcall(f);print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(e)));if not ok then failed=failed+1 end end
local function rawbytes(hex)return (hex:gsub('..',function(x)return string.char(tonumber(x,16))end))end
local function command_bounds(h,ids)
 local xmin,ymin,xmax,ymax=math.huge,math.huge,-math.huge,-math.huge
 for _,entry in ipairs(ids or h.a.M.ids) do
  local c=assert(h.commands[entry[2]])
  eq(c.kind,'triangle');eq(c.args[1],h.a.M.gui);eq(c.args[5],3);eq(c.args[7],'mods/driver_hud/solid')
  for i=2,4 do local p=c.args[i];eq(p[2],0);xmin=math.min(xmin,p[1]);xmax=math.max(xmax,p[1]);ymin=math.min(ymin,p[3]);ymax=math.max(ymax,p[3])end
 end
 return xmin,ymin,xmax,ymax
end
local function populated(tank)
 local h=helpers.fresh();h:enter(tank and h:add_tank(351,600) or h:add_frv(336,467));h:tick(1);h:clean();return h
end

test('new PE and four independently expected roots',function()
 local n=helpers.fresh().a.Native
 eq(n.version,'r4-73374bd4');eq(n.pe.size,0x4770000);eq(n.pe.timestamp,0x6AA96B14);eq(n.pe.checksum,0xF05B12)
 eq(n.roots.network,0x346BF98);eq(n.roots.health,0x3326688);eq(n.roots.synced,0x3326C98);eq(n.roots.seater,0x3326D78)
end)
test('each of the 14 code guards independently rejects mismatch and truncation',function()
 local z=helpers.graph_fixture();local n,m,b=z.N,z.m,z.base
 m:zero(b,512);m:put(b,'MZ');m:w32(b+0x3c,256);m:put(b+256,'PE\0\0');m:put(b+260,string.char(0x64,0x86,16,0))
 m:w32(b+264,0x6AA96B14);m:w32(b+336,0x4770000);m:w32(b+344,0xF05B12)
 for _,g in ipairs(n.guards)do m:put(b+g[1],rawbytes(g[2]))end
 local function r(p,s)return m:read(p,s)end
 eq(#n.guards,14);eq(n.check_module(r,b),true)
 for _,g in ipairs(n.guards)do
  local p=b+g[1];local original=rawbytes(g[2]);m:put(p,string.char((original:byte(1)+1)%256))
  local ok,why=n.check_module(r,b);eq(ok,false);check(why:find('native code guard',1,true)~=nil);m:put(p,original)
  eq(n.check_module(function(a,s)if a==p then return r(a,s-1)end;return r(a,s)end,b),false)
 end
 m:w32(b+264,0x6A86132E);eq(n.check_module(r,b),false)
 eq(n.check_module(function()return nil end,b),false)
end)
test('new Health fields work while all obsolete fields are poison',function()
 local z=helpers.graph_fixture();z.m:zero(z.hm+0x28,0x88)
 z.m:w64(z.hm+0x40,1);z.m:w64(z.hm+0x50,1);z.m:w64(z.net+0xF11738,1)
 local r=z:g():relation(315);eq(r.vehicle.entity,z.e1)
 z.m:w32(z.hr+3*440+248,327);local out=z:health();eq(out.hp[1],327);eq(out.body,2400);eq(out.sync_valid,true)
end)
test('new settings table includes slot and record index 1001',function()
 local z=helpers.graph_fixture();local res='00000000000003e9' -- 1001 modulo 1002
 for _,j in ipairs({1,4})do z.m:resource(z.net+0xF32F18+j*24,res)end
 z.m:zero(z.st,1002*16);z.m:resource(z.st+1001*16,res);z.m:w32(z.st+1001*16+8,1001)
 local cfg=z.st+0x3EA0+1001*0x5650;z.m:put(cfg,assert(z.m:read(z.cfg,0x5650)))
 eq(z:health().max[1],350)
 z.m:w32(z.st+1001*16+8,1002)
 local ok,e=pcall(function()return z:health()end);eq(ok,false);eq(e,'Health settings index')
end)
test('1002-slot settings probing wraps from last slot to zero',function()
 local z=helpers.graph_fixture();local res='00000000000003e9'
 for _,j in ipairs({1,4})do z.m:resource(z.net+0xF32F18+j*24,res)end
 z.m:zero(z.st,1002*16);z.m:resource(z.st+1001*16,'0000000000000123');z.m:resource(z.st,res);z.m:w32(z.st+8,0)
 eq(z:health().max[4],350)
end)
test('entity-specific Health override uses new index and array fields',function()
 local z=helpers.graph_fixture();z.m:table(z.hm+0x1070,0x300008000,{{z.e1,2}})
 local base=0x900000000;local cfg=base+2*0x5650;z.m:w64(z.hm+0x10B0,base);z.m:put(cfg,assert(z.m:read(z.cfg,0x5650)))
 z.m:w32(cfg+0x208+232,400);z.m:w64(z.net+0xF12B78,0)
 local out=z:health();eq(out.max[1],400);eq(out.max[2],350);eq(out.hp[1],350)
end)
test('new Health proxy enumeration still rejects ambiguous same-unit owners',function()
 local z=helpers.graph_fixture();local av=z:g():net(z.net,z.av,true)
 local d1,d2=z:d(),z:d(z.e2)
 z.m:w32(d1.address+12,av.unit)
 local d,meta=z:g():frv_hull_for_proxy(av,{cc21c7ffd3ebefb9=true});eq(d.entity,z.e1);eq(meta.candidates,1)
 z.m:w32(d2.address+12,av.unit)
 d,meta=z:g():frv_hull_for_proxy(av,{cc21c7ffd3ebefb9=true});eq(d,nil);eq(meta.candidates,2)
end)
test('production module layout does not round-trip unrelated dense indices',function()
 local z=helpers.graph_fixture();local a,b=z:health(),z:health(z.e2)
 eq(a.health_index,3);eq(b.health_index,0);z.m:w32(z.hr+3*440+248,12);z.m:w32(z.hr+3*440+32,0x80)
 a,b=z:health(),z:health(z.e2);eq(a.hp[1],12);eq(b.hp[1],350);eq(a.damage[4],2);eq(b.damage[4],0)
end)
test('default FRV and tank numeric paths do not call the font API',function()
 for _,tank in ipairs({false,true})do
  local h=helpers.fresh();eq(h.a.C.geometry_numbers,true)
  h.env.stingray.Gui.text=function()error('separate font path must not run')end
  h.env.stingray.Gui.text_extents=h.env.stingray.Gui.text
  h:enter(tank and h:add_tank(351,600)or h:add_frv(336,467));h:tick(2)
  eq(h.a.FRV.mode,tank and 'TANK'or'FRV');eq(#h:texts(),0);check(#h.a.M.ids>50);h:clean()
 end
end)
test('geometry bounds center actual narrow digits, zero, slash and unknown',function()
 for _,label in ipairs({'2400','1800','1200','1','11','0','--','31','2000','8000 / 8000'})do
  local h=helpers.fresh();h.a.M.gui='gui';check(h.a.HudNumber.draw(label,500,240,17,.8,{240,244,239},'center'))
  local x,y,xx,yy=command_bounds(h);near((x+xx)/2,500,label);near((y+yy)/2,240,label)
  local lx,ly,hx,hy=h.a.HudNumber.bounds(label,17);near(xx-x,hx-lx);near(yy-y,hy-ly)
 end
end)
test('geometric FRV label matches body center and warning colors',function()
 for _,hp in ipairs({2400,1800,1200})do
  local h=helpers.fresh();local d=h:add_frv(336,467);h.objects[336].hp=hp
  local saved=h.a.HudNumber.draw;local got
  h.a.HudNumber.draw=function(label,x,y,size,a,c,anchor)
   got={label=label,x=x,y=y,c=c,anchor=anchor};return saved(label,x,y,size,a,c,anchor)
  end
  h:enter(d);h:tick(.3);local x,y,s=h.a.FRV.layout(h.width,h.height)
  eq(got.label,tostring(hp));near(got.x,x+64*s);near(got.y,y+62*s);eq(got.anchor,'center')
  local want=h.a.FRV.color(hp/2400);for i=1,3 do eq(got.c[i],want[i])end;h:clean()
 end
end)
test('only body numerals are emitted for FRV, tires remain graphical and hub independent',function()
 local h=helpers.fresh();local d=h:add_frv(336,467);local calls={};local draw=h.a.HudNumber.draw
 h.a.HudNumber.draw=function(label,...)calls[#calls+1]=label;return draw(label,...)end
 h.health[467].hp={0,97,350,0};h.health[467].damage={2,0,0,2};h:enter(d);h:tick(.5)
 eq(#calls,1);eq(calls[1],'2400');eq(h.a.FRV.wheel_model(h.a.FRV.data,1).kind,'hub');eq(h.a.FRV.wheel_model(h.a.FRV.data,2).kind,'tire');eq(h.a.FRV.wheel_model(h.a.FRV.data,4).kind,'hub')
 eq(#h:texts(),0);h:clean()
end)
test('tank HP, main and coax numbers retain layout and no text overlap at normal capacities',function()
 local h=helpers.fresh();local seen={};local draw=h.a.HudNumber.draw
 h.a.HudNumber.draw=function(label,x,y,size,a,c,anchor)
  local x0,y0,x1,y1=h.a.HudNumber.bounds(label,size)
  seen[#seen+1]={label=label,left=x,right=x+x1-x0,y=y};return draw(label,x,y,size,a,c,anchor)
 end
 h:enter(h:add_tank(351,600));h:tick(2);seen={seen[#seen-2],seen[#seen-1],seen[#seen]};eq(seen[1].label,'8000 / 8000');eq(seen[2].label,'31');eq(seen[3].label,'2000')
 check(seen[1].right<seen[2].left-12);check(seen[2].right<seen[3].left-14)
 near(seen[1].y,seen[2].y);near(seen[2].y,seen[3].y);check(seen[3].right<1110);h:clean()
end)
test('retained geometry is not recreated on unchanged frames and is cleared on vehicle switch and exit',function()
 local h=populated();local before=h.next_id;h:tick(2);eq(h.next_id,before)
 local ids=h.a.M.ids;local tank=h:add_tank(351,600);h:enter(tank);h:tick(.5)
 for _,v in ipairs(ids)do eq(h.commands[v[2]],nil)end
 ids=h.a.M.ids;h:enter(h:add_frv(336,467));h:tick(.3)
 for _,v in ipairs(ids)do eq(h.commands[v[2]],nil)end
 h.seated=false;h:tick(1/60);eq(next(h.commands),nil);h:clean()
end)
test('geometry labels follow FRV screen placement and scale at common resolutions',function()
 for _,res in ipairs({{1920,1080},{2560,1440},{3840,2160},{3440,1440}})do
  for _,scale in ipairs({.55,1,1.5})do
   local h=helpers.fresh();h.width,h.height=res[1],res[2];h.a.Position.scale=scale
   h:enter(h:add_frv(336,467));h:tick(.2)
   local x,y,xx,yy=command_bounds(h);check(x>=0 and y>=0 and xx<=h.width and yy<=h.height);h:clean()
  end
 end
end)
test('native font opt-out remains available in both HUDs',function()
 for _,tank in ipairs({false,true})do
  local h=helpers.fresh();h.a.C.geometry_numbers=false;h:enter(tank and h:add_tank(351,600)or h:add_frv(336,467));h:tick(2)
  eq(#h:texts(),tank and 3 or 1);eq(h.a.FRV.mode,tank and'TANK'or'FRV');h:clean()
 end
end)
test('unsupported label and invalid size fail before emitting partial geometry',function()
 local h=helpers.fresh();h.a.M.gui='gui'
 for _,label in ipairs({'2400A','',string.rep('8',33)})do eq(h.a.HudNumber.draw(label,0,0,17,1,nil,'center'),false)end
 for _,sz in ipairs({0,-1,math.huge,0/0})do eq(h.a.HudNumber.draw('12',0,0,sz,1,nil,'center'),false)end
 eq(next(h.commands),nil)
end)
test('startup config parses explicit false and ignores malformed numeric-mode settings',function()
 local h=helpers.fresh('geometry_numbers=false\n');eq(h.a.C.geometry_numbers,false)
 h:enter(h:add_frv(336,467));h:tick(.3);eq(#h:texts(),1);h:clean()
 h=helpers.fresh('geometry_numbers=true\n');eq(h.a.C.geometry_numbers,true)
 h=helpers.fresh('geometry_numbers=unexpected\n');eq(h.a.C.geometry_numbers,true)
 h=helpers.fresh('debug=true\noffset_y=155\n');eq(h.a.C.geometry_numbers,true)
end)
print(string.format('RESULT UPDATE_1_3_5 cases=%d assertions=%d fails=%d',count,assertions,failed))
if failed>0 then os.exit(1)end
