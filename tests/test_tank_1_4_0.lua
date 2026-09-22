-- Execute the built production payload, not a second implementation.
local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='HUD_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local load=assert(loadstring(read(ROOT..'/tests/test_integration.lua')));setfenv(load,env);local H=load()
local count,fail,assertions=0,0,0
local function check(v,s)assertions=assertions+1;assert(v,s or 'check')end
local function eq(a,b,s)check(a==b,(s or 'equality')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(n,f)count=count+1;local ok,e=pcall(f);print((ok and 'PASS ' or 'FAIL ')..n..(ok and '' or ': '..tostring(e)));if not ok then fail=fail+1 end end
local function gat()
 return {[1]=1,[2]=64,[3]=50,[4]=false,[5]=0,[6]=6,[7]=300,[8]=true,[9]=0,[10]=false,[11]=true,[12]=1,[13]=35,[14]=25,[15]=0,[16]=1080,[17]=-1012978497,[18]='p1',[19]=2,[20]=0,[21]=10,[22]=0,[23]=false,[24]=0,[25]=699050,[26]=100000,[27]=false,[28]=0}
end
local function rack()
 return {[1]=1,[2]=1,[3]=32767,[4]=32767,[5]=0,[6]=1,[7]=false,[8]=0,[9]=false,[10]=32767,[11]=16,[12]={},[13]=2,[14]=64,[15]=50,[16]=0,[17]=0,[18]=10,[19]=true,[20]=false,[21]=.081,[22]=216,[23]=-793,[24]=10,[25]=0,[26]=false,[27]=0,[28]=699050,[29]=100000,[30]=false,[31]='p1',[32]=2,[33]=0}
end
local function add(h,id,entity,refs)
 refs=refs or {id-5,id-4,id-3,id-2,id-1}
 h.objects[id]={t='new_tank',hp=8000,max=8000,f={[15]=8000,[30]=8000,[22]=15,[56]=refs}}
 h.objects[refs[1]]={t='new_gatling',f=gat()}
 h.objects[refs[2]]={t='control',f={[1]=true,[15]='p1'}}
 h.objects[refs[3]]={t='not_missile',f={[1]=1,[6]=20,[23]=false}}
 h.objects[refs[4]]={t='new_rack',f=rack()};h.objects[refs[5]]={t='new_rack',f=rack()}
 return {entity=entity,goid=id,resource='b0c9faf4af8903f9',unit=entity*7,flags=1},refs
end
local function populate(role)
 local h=H.fresh();local d,refs=add(h,400,600);h:enter(d,role or 0);h:tick(1);h:clean();return h,d,refs
end
local function gvalue(h)local a=h.a.Tank.active;return a.children[a.gatling].value end
local function all_live(h)local n=0;for _ in pairs(h.commands)do n=n+1 end;return n end
local function exact_new_telemetry(h)
 local base=h.env.stingray.GameSession.game_object_field
 h.env.stingray.GameSession.game_object_field=function(s,id,k)
  local o=h.objects[id];check(not o or (o.t~='new_gatling' and o.t~='new_rack'),'unknown targeted getter invoked')
  return base(s,id,k)
 end
end

if os.getenv('TANK_TEST_HELPERS')=='1' then return {fresh=H.fresh,populate=populate,add=add,gat=gat,rack=rack} end

test('new driver direct entry: HP, 300 rounds, 6 belts, two racks',function()
 local h,d,r=populate();local a=h.a.Tank.active
 eq(h.a.M.hull,400);eq(a.kind,'new');eq(h.a.M.hp,8000);eq(gvalue(h).current,300);eq(gvalue(h).reserve,6)
 eq(#a.racks,2);eq(a.children[a.racks[1]].value.ammo+a.children[a.racks[2]].value.ammo,20)
 eq(a.reload.phase,'idle');check(all_live(h)>0);h:clean()
end)
test('new direct gunner entry uses same model without visiting driver',function()local h=populate(1);eq(gvalue(h).current,300);eq(h.a.Tank.active.last_role,1);h:clean()end)
test('no unknown targeted reads, no new tank FRV proxy enumeration',function()
 local h=H.fresh();exact_new_telemetry(h);h.a.Native.resolve_proxy=function()error('unexpected proxy')end
 h:enter((add(h,400,600)));h:tick(3);eq(gvalue(h).reserve,6);h:clean()
end)
test('non-adjacent explicit child IDs are discovered and classified',function()
 local h=H.fresh();local d,r=add(h,500,800,{91,204,602,89,150});h:enter(d);h:tick(2)
 eq(h.a.Tank.active.gatling,91);eq(#h.a.Tank.active.racks,2);eq(gvalue(h).current,300);h:clean()
end)
test('unreferenced same-shape neighbouring weapon is never read',function()
 local h,d,r=populate();h.objects[401]={t='new_gatling',f=gat()};h.objects[401].f[7]=17
 local raw=h.env.stingray.GameSession.game_object_field_batched
 h.env.stingray.GameSession.game_object_field_batched=function(s,id)check(id~=401,'foreign weapon');return raw(s,id)end
 h:tick(3);eq(gvalue(h).current,300);h:clean()
end)
test('combined steady weapon budget <=10Hz and total new batches <=16Hz',function()
 local h=populate();local start=h.a.M.frame;local requests={}
 local raw=h.env.stingray.GameSession.game_object_field_batched
 h.env.stingray.GameSession.game_object_field_batched=function(s,id)requests[id]=(requests[id] or 0)+1;return raw(s,id)end
 h:tick(10,1/144)
 local total=0;for _,n in pairs(requests)do total=total+n end
 check(total<=160,'total batched '..total);check((requests[395] or 0)<=51,'Gatling polling');check((requests[398] or 0)<=26,'rack A polling');check((requests[399] or 0)<=26,'rack B polling')
 print('DETAIL new_tank_10_seconds total_batches='..total..' gatling='..tostring(requests[395])..' racks='..tostring(requests[398])..'/'..tostring(requests[399]));h:clean()
end)
test('single NIL / long GAP preserve valid ammunition, never set zero',function()
 local h=populate();local raw=h.env.stingray.GameSession.game_object_field_batched
 h.env.stingray.GameSession.game_object_field_batched=function(s,id)if id~=400 then return nil end;return raw(s,id)end
 h:tick(8);eq(gvalue(h).current,300);eq(gvalue(h).reserve,6);check(h.a.M.draw_key:find('true',1,true),'stale visual not marked');h:clean()
end)
test('late remote snapshot reconciles jump without predicted rounds',function()
 local h,d,refs=populate();h.objects[refs[1]].f[6]=4;h.objects[refs[1]].f[7]=135
 h:tick(.4);eq(gvalue(h).reserve,4);eq(gvalue(h).current,135);h:tick(2);eq(gvalue(h).current,135);h:clean()
end)
test('empty belt does not begin an automatic reload',function()
 local h,d,r=populate(1);h.objects[r[1]].f[7]=0;h:tick(4);eq(gvalue(h).current,0);eq(h.a.Tank.active.reload.phase,'idle');eq(#h.a.Tank.ring_ids,0);h:clean()
end)
test('partial-belt R, pause, resume and completion use authoritative reserve',function()
 local h,d,refs=populate(1);local f=h.objects[refs[1]].f
 f[7]=246;h:tick(.25);f[7]=0;f[28]=5;h:tick(.8)
 local r=h.a.Tank.active.reload;eq(r.phase,'running');check(r.elapsed>0);eq(gvalue(h).reserve,6)
 f[28]=1;h:tick(.3);eq(r.phase,'paused');local e=r.elapsed;h:tick(2);eq(r.elapsed,e);eq(gvalue(h).reserve,6)
 f[28]=5;h:tick(.6);check(r.elapsed>e);eq(gvalue(h).reserve,6)
 f[28]=7;h:tick(.5);f[6]=5;f[7]=300;f[28]=0;h:tick(.5)
 eq(r.phase,'idle');eq(gvalue(h).reserve,5);eq(gvalue(h).current,300);h:clean()
end)
test('same-instance exit/re-entry preserves known paused progress, but not ammo cache',function()
 local h,d,refs=populate(1);local f=h.objects[refs[1]].f
 f[7]=0;f[28]=5;h:tick(.8);f[28]=1;h:tick(.3);local before=h.a.Tank.active.reload.elapsed
 h.seated=false;h:tick(1);eq(h.a.Tank.active,nil);eq(all_live(h),0)
 h:enter(d,1);h:tick(1);local r=h.a.Tank.active.reload
 eq(r.phase,'paused');eq(r.elapsed,before);h:tick(1);eq(r.elapsed,before)
 f[28]=5;h:tick(.5);check(r.elapsed>before);h:clean()
end)
test('joining unknown already-paused reload does not fabricate percentage',function()
 local h=H.fresh();local d,refs=add(h,400,600);h.objects[refs[1]].f[7]=0;h.objects[refs[1]].f[28]=1
 h:enter(d);h:tick(1);eq(h.a.Tank.active.reload.known_start,false);eq(h.a.Tank.active.reload.phase,'paused');check(#h.a.Tank.ring_ids>0);h:clean()
end)
test('long reload-state gap holds uncertain, timer never grants ammunition',function()
 local h,d,refs=populate();local f=h.objects[refs[1]].f;f[28]=4;f[7]=282;h:tick(.3)
 local raw=h.env.stingray.GameSession.game_object_field_batched
 h.env.stingray.GameSession.game_object_field_batched=function(s,id)if id==refs[1] then return nil end;return raw(s,id)end
 h:tick(8);eq(h.a.Tank.active.reload.phase,'uncertain');check(h.a.Tank.active.reload.elapsed<2);eq(gvalue(h).reserve,6);eq(gvalue(h).current,282);h:clean()
end)
test('unknown reload state degrades ring only, not ammo or body',function()
 local h,d,refs=populate();local f=h.objects[refs[1]].f;f[28]=5;f[7]=0;h:tick(.4);f[28]=99;f[7]=211
 h:tick(.4);eq(gvalue(h).current,211);eq(h.a.M.hp,8000);eq(h.a.Tank.active.reload.phase,'uncertain');h:clean()
end)
test('missile total follows each independent rack, bad rack not coerced to zero',function()
 local h,d,r=populate();h.objects[r[4]].f[18]=9;h:tick(.5);h.objects[r[5]].f[18]=9;h:tick(.5)
 local a=h.a.Tank.active;eq(a.children[r[4]].value.ammo+a.children[r[5]].value.ammo,18)
 h.objects[r[5]].f[18]=0/0;h:tick(1);eq(a.children[r[5]].value.ammo,9);eq(gvalue(h).current,300);h:clean()
end)
test('one removed child loses its channel, not body or other rack/gun',function()
 local h,d,r=populate();h.objects[r[4]]=nil;h:tick(1);eq(h.a.M.hp,8000);eq(gvalue(h).current,300);eq(h.a.Tank.active.children[r[4]],nil);h:clean()
end)
test('explicit changed child references discard old ammo immediately',function()
 local h,d,r=populate();h.objects[400].f[56]={391,392,393,394,390};h:tick(.3)
 eq(h.a.Tank.active.gatling,nil);check(not h.a.M.draw_key:find(':300:6:',1,true));eq(h.a.M.hp,8000);h:clean()
end)
test('malformed child list fails closed without hiding vehicle HP',function()
 local h=populate();h.objects[400].f[56]={395,395,397,398,399};h:tick(.3)
 eq(#h.a.Tank.active.refs,0);eq(h.a.Tank.active.gatling,nil);eq(h.a.M.hp,8000);h:clean()
end)
test('two tanks and resource/GOID reuse cannot share ammunition',function()
 local h,d,r=populate();h.objects[r[1]].f[7]=17;h:tick(.3)
 local d2,r2=add(h,500,700);h:enter(d2,1);h:tick(1);eq(gvalue(h).current,300);eq(h.a.M.hull,500)
 d2.entity=701;d2.unit=701*7;h.objects[r2[1]].f[7]=99;h:enter(d2,0);h:tick(1);eq(gvalue(h).current,99);h:clean()
end)
test('new -> old -> FRV -> new clears variant/ring geometry',function()
 local h,d,r=populate();h.objects[r[1]].f[28]=5;h.objects[r[1]].f[7]=0;h:tick(.4);check(#h.a.Tank.ring_ids>0)
 local old=h:add_tank(351,900);h:enter(old,1);h:tick(1);eq(h.a.Tank.active.kind,'old');eq(h.a.M.ammo,31);eq(h.a.M.mg,2000)
 local frv=h:add_frv(336,467);h:enter(frv);h:tick(.5);eq(h.a.Tank.active,nil);eq(#h.a.Tank.ring_ids,0);eq(h.a.FRV.mode,'FRV')
 h.objects[r[1]].f[28]=0;h.objects[r[1]].f[7]=300;h:enter(d);h:tick(1);eq(gvalue(h).current,300);h:clean()
end)
test('old reload keeps original 31/2000 readers and post-commit phase',function()
 local h=H.fresh();h:enter(h:add_tank(351,600),1);local f=h.objects[349].f;f[14]=0;h:tick(1)
 eq(h.a.M.ammo,31);eq(h.a.M.mg,2000);f[6]=0;h:tick(.3);eq(h.a.M.ammo,30);eq(h.a.Tank.active.reload.phase,'idle')
 f[14]=4;h:tick(1);f[14]=5;h:tick(1);f[14]=7;h:tick(.7);f[5]=29;f[6]=1;f[14]=4;h:tick(.3)
 eq(h.a.Tank.active.reload.phase,'settling');eq(h.a.M.ammo,30)
 f[14]=0;h:tick(.3);eq(h.a.Tank.active.reload.phase,'idle');eq(h.a.M.mg,2000);h:clean()
end)
test('old interrupted state0 empty stays paused until nonzero resume',function()
 local h=H.fresh();h:enter(h:add_tank(351,600),1);local f=h.objects[349].f;f[14]=0;h:tick(1)
 f[6]=0;f[14]=4;h:tick(.8);f[14]=0;h:tick(.3);local r=h.a.Tank.active.reload
 eq(r.phase,'paused');local e=r.elapsed;h:tick(1);eq(r.elapsed,e);f[14]=4;h:tick(.5);eq(r.phase,'running');check(r.elapsed>e);h:clean()
end)
test('static new HUD is retained at 144Hz; ring never rebuilds static IDs',function()
 local h,d,r=populate();local before=h.next_id;h:tick(2,1/144);eq(h.next_id,before)
 h.objects[r[1]].f[28]=5;h.objects[r[1]].f[7]=0;h:tick(.3)
 local static=h.a.M.ids;local first=static[1][2];h:tick(.5,1/144)
 eq(h.a.M.ids,static);check(h.commands[first]~=nil);check(#h.a.Tank.ring_ids>0);h:clean()
end)
test('cursor hide, resize, exit clean all static and dynamic primitives',function()
 local h,d,r=populate();h.objects[r[1]].f[28]=5;h:tick(.5);h.cursor=true;h:tick(.1);eq(all_live(h),0)
 h.cursor=false;h.width=2560;h.height=1440;h:tick(.2);check(all_live(h)>0)
 h.seated=false;h:tick(.1);eq(all_live(h),0);eq(#h.a.Tank.ring_ids,0);h:clean()
end)
test('changed session/avatar cannot recover another context reload cache',function()
 local h,d,r=populate();h.objects[r[1]].f[28]=5;h.objects[r[1]].f[7]=0;h:tick(.6)
 h.seated=false;h:tick(.2);h.session='s2';h:enter(d);h.objects[r[1]].f[28]=1;h:tick(1)
 eq(h.a.Tank.active.reload.known_start,false);eq(h.a.Tank.active.reload.elapsed,0);h:clean()
end)
test('slow frame has no catch-up sampling burst',function()
 local h=populate();h:tick(5,.25);h:clean();check(gvalue(h).current==300)
end)
test('sparse telemetry with missing signature fields retains the valid channel',function()
 local h,d,refs=populate();local f=h.objects[refs[1]].f;f[12]=nil;h:tick(1)
 eq(gvalue(h).current,300);eq(h.a.M.hp,8000);h:clean()
end)
test('driver leaving during another gunner reload never restores invented paused time',function()
 local h,d,refs=populate(0);local f=h.objects[refs[1]].f;f[28]=5;f[7]=0;h:tick(.6)
 h.seated=false;h:tick(1);h:enter(d,0);h:tick(1)
 eq(h.a.Tank.active.reload.known_start,false);h:clean()
end)
test('changed reserve while away invalidates the old reload cycle',function()
 local h,d,refs=populate(1);local f=h.objects[refs[1]].f;f[28]=5;f[7]=0;h:tick(.6)
 h.seated=false;h:tick(.5);f[6]=5;f[28]=5;h:enter(d,1);h:tick(1)
 eq(h.a.Tank.active.reload.known_start,false);eq(gvalue(h).reserve,5);h:clean()
end)
test('ring reaching its expected duration never commits a reload',function()
 local h,d,refs=populate(1);local f=h.objects[refs[1]].f;f[28]=5;f[7]=0;h:tick(8)
 local r=h.a.Tank.active.reload;eq(r.phase,'running');check(r.elapsed<4);eq(gvalue(h).reserve,6);eq(gvalue(h).current,0);h:clean()
end)
test('stale parent references suspend child reads rather than chase reused IDs',function()
 local h=populate();local raw=h.env.stingray.GameSession.game_object_field_batched
 local children=0
 h.env.stingray.GameSession.game_object_field_batched=function(s,id)if id==400 then return nil end;children=children+1;return raw(s,id)end
 h:tick(1);local before=children;h:tick(1);eq(children,before);eq(gvalue(h).current,300);h:clean()
end)
test('missing parent reference field is unavailable, not explicit weapon removal',function()
 local h=populate();h.objects[400].f[56]=nil;h:tick(2)
 eq(gvalue(h).current,300);eq(gvalue(h).reserve,6);eq(h.a.M.hp,8000);h:clean()
end)
test('partial child table without final field retains old valid sample',function()
 local h,d,refs=populate();h.objects[refs[1]].f[28]=nil;h.objects[refs[4]].f[33]=nil
 h:tick(2);eq(gvalue(h).current,300);eq(h.a.Tank.active.children[refs[4]].value.ammo,10);h:clean()
end)
print(string.format('RESULT TANK_1_4_0 cases=%d assertions=%d fails=%d',count,assertions,fail))
if fail>0 then os.exit(1) end
