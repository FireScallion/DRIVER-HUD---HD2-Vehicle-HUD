-- Focused retention/scheduling checks, not an FPS or GPU benchmark.
local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='HUD_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local chunk=assert(loadstring(read(ROOT..'/tests/test_integration.lua')));setfenv(chunk,env);local H=chunk()
local count=0
local function check(x,s)assert(x,s);count=count+1;print('PASS '..s)end
local z=H.graph_fixture();local m=z.m;local p=0x123450000;m:put(p,'abcdefghijklmnop')
local g=z:g();g:watch(p,8);g:watch(p+8,8);g:watch(p+4,8)
local before=g.calls;g:validate();check(g.calls-before==1,'adjacent and overlapping watches use one fresh read')
m:put(p+9,'X');local ok,e=pcall(function()g:validate()end);check(not ok and e=='identity changed during sample','coalescing still rejects mutation')
local h=H.fresh();local owned,relations,reads,draws=0,0,0,0
local gs=h.env.stingray.GameSession;local get=gs.objects_owned_by
local relation,health,draw=h.a.Native.relation,h.a.Native.health,h.a.FRV.draw
h.env.os.clock=os.clock;h.a.C.perf=true
-- The API contract is checked under the actual production wrapper at 144 FPS.
gs.objects_owned_by=function(...)owned=owned+1;return get(...)end
h.a.Native.relation=function(...)relations=relations+1;return relation(...)end
h.a.Native.health=function(...)reads=reads+1;return health(...)end
h.a.FRV.draw=function(...)draws=draws+1;return draw(...)end
h:enter(h:add_frv(336,467));h:tick(.4,1/144)
owned,relations,reads,draws=0,0,0,0
local created=h.next_id;local original=h.original_calls
h:tick(1,1/144)
check(owned>=4 and owned<=6,'stable ownership remains approximately 5 Hz')
check(relations>=9 and relations<=10 and reads==relations,'identity and native telemetry retain 10 Hz cap')
check(draws==144 and h.original_calls-original==144,'render and original game update still run each frame')
check(h.next_id==created,'unchanged geometry creates no new retained objects')
h.health[467].hp[1]=327;h:tick(.12,1/144);check(h.next_id>created,'real telemetry change redraws')
local live=0;for _ in pairs(h.commands)do live=live+1 end;check(live==#h.a.M.ids,'redraw retains no abandoned triangles')
h.seated=false;h:tick(1/144);check(next(h.commands)==nil and not h.a.M.seated,'exit clears without waiting for ownership poll')
h:enter(h:add_frv(336,467));h:tick(.3,1/144);check(h.a.FRV.mode=='FRV','reentry restores display')
h.avatar=400;h.objects[400]=h.objects[315];h.relation={status='EMPTY'};h:tick(1/144);check(h.a.M.avatar==400 and h.a.FRV.vehicle==nil,'avatar change clears immediately')
h.session='s2';h:tick(1/144);check(h.a.M.session=='s2','session reset remains immediate')
h.avatar=315;h:enter(h:add_frv(336,467));h:tick(.3,1/144)
h.env.stingray.GameSession.objects_owned_by=function()return nil end;h:tick(.25,1/144);check(not h.a.M.seated and h.a.FRV.vehicle==nil,'ownership refresh failure clears')
h.env.stingray.GameSession.objects_owned_by=get;h:enter(h:add_frv(336,467));h:tick(11,1/144);h:clean()
check(table.concat(h.logs):find('PERF mode=',1,true)~=nil,'profiler crosses flush boundary without blocking update')
local tank=H.fresh();local td=tank:add_tank(351,600);td.resource='16474112801385b6';tank:enter(td);tank:tick(2)
local calls=0;tank.a.Native.resolve_proxy=function()calls=calls+1;error('unexpected proxy enumeration')end
local frame=tank.a.M.frame;local first_id=tank.next_id;tank:tick(1,1/144)
check(calls==0 and tank.a.M.hull==351,'stable Bastion avoids FRV table enumeration')
check(tank.next_id==first_id,'stable tank geometry not rebuilt per frame')
local batches=0;for f,n in pairs(tank.batches)do if f>frame then batches=batches+n end end
check(batches<=40,'tank telemetry stays within its four-read, 10 Hz budget')
print('DETAIL tank_batched_reads_per_second='..batches)
tank:clean()
print('DETAIL stable FRV live_triangles='..live..' native_calls_last_window='..reads)
print('RESULT PERFORMANCE_CONTRACT checks='..count..' fails=0 (SYNTHETIC, NOT FPS)')
