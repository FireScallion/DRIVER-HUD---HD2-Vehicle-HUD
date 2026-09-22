local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='HUD_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local fn=assert(loadstring(read(ROOT..'/tests/test_integration.lua')));setfenv(fn,env);local H=fn()
local count,failed=0,0
local function check(v,label)assert(v,label or 'check')end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(n,f)count=count+1;local ok,e=pcall(f);print((ok and 'PASS ' or 'FAIL ')..n..(ok and '' or ': '..tostring(e)));if not ok then failed=failed+1 end end
local function fs(h)
 local store,writes={},{}
 local base=h.env.io.open
 h.env.io.open=function(p,mode)
  local name=p:match('([^/]+)$')
  if name=='frv_hud_position.txt' or name=='frv_hud_position.json' then
   if mode=='rb' then
    if h.locked then return nil,'Permission denied',13 end
    if store[name]==nil then return nil,'No such file',2 end
    return {read=function(_,n)return store[name]:sub(1,n)end,close=function()end}
   elseif mode=='wb' then
    if h.read_only then return nil,'Permission denied',13 end
    check(store[name]==nil,'attempt to overwrite existing configuration')
    return {write=function(self,s)store[name]=s;writes[#writes+1]=s;return self end,close=function()end}
   end
  end
  return base(p,mode)
 end
 return store,writes
end
local function pos(h)h.a.Position.reload(h.a.M.clock)end
local valid='x = 0.23\ny = 0.84\nscale = 1.25\n'
test('first run creates bilingual external TXT, not ZIP/package edits',function()
 local h=H.fresh();local s,w=fs(h);pos(h);eq(#w,1);check(s['frv_hud_position.txt']:find('位置',1,true));eq(h.a.Position.x,.714);eq(h.a.Position.y,.90)
end)
test('existing TXT never overwritten and three values applied together',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.txt']=valid;pos(h);eq(#w,0);eq(h.a.Position.x,.23);eq(h.a.Position.y,.84);eq(h.a.Position.scale,1.25)
end)
test('old JSON migrates exactly once; subsequent JSON edits ignored',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.json']='{"x":0.15,"y":0.4,"scale":0.8}'
 pos(h);eq(h.a.Position.x,.15);eq(#w,1)
 s['frv_hud_position.json']='{"x":0.99,"y":0.4,"scale":1}'
 h.a.M.clock=3;pos(h);eq(h.a.Position.x,.15);eq(#w,1)
end)
test('invalid legacy JSON uses defaults without executing contents',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.json']='os.execute("BAD")';pos(h);eq(h.a.Position.x,.714);eq(#w,1)
end)
test('valid file hot reload waits two seconds, no redeploy',function()
 local h=H.fresh();local s,w=fs(h);pos(h);s['frv_hud_position.txt']=valid;h.a.M.clock=1;pos(h);eq(h.a.Position.x,.714)
 h.a.M.clock=2.01;pos(h);eq(h.a.Position.x,.23);eq(h.a.Position.revision,1);eq(#w,1)
end)
test('half-written, blank, duplicate or out-of-range TXT keeps last good',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.txt']=valid;pos(h)
 for _,bad in ipairs({'','x=0.9\ny=0.2','x=2\ny=0.3\nscale=1','x=0.3\nx=0.4\ny=0.3\nscale=1','x=0.3\ny=0.3\nscale=0.1','x=nan\ny=0.3\nscale=1'})do
  s['frv_hud_position.txt']=bad;h.a.M.clock=h.a.M.clock+3;pos(h);eq(h.a.Position.x,.23);eq(h.a.Position.y,.84);eq(h.a.Position.scale,1.25)
 end
 eq(#w,0)
end)
test('UTF-8 BOM / CRLF / inline comments and bilingual instructions accepted',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.txt']='\239\187\191# 中文说明\r\nx=0.23 # 横向\r\ny=0.84\r\nscale=1.25 ; size\r\n';pos(h);eq(h.a.Position.x,.23)
end)
test('Notepad UTF-16 LE and BE files parse correctly',function()
 for _,le in ipairs({true,false})do
  local h=H.fresh();local s,w=fs(h);local t={le and '\255\254' or '\254\255'}
  for i=1,#valid do local c=valid:sub(i,i);t[#t+1]=le and c..'\0' or '\0'..c end
  s['frv_hud_position.txt']=table.concat(t);pos(h);eq(h.a.Position.scale,1.25);eq(h.a.Position.x,.23)
 end
end)
test('permission error does not trigger truncating write or position reset',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.txt']=valid;pos(h);h.locked=true;h.a.M.clock=3;pos(h);eq(#w,0);eq(h.a.Position.x,.23)
end)
test('unwritable AppData does not stop HUD or overwrite legacy settings',function()
 local h=H.fresh();local s,w=fs(h);h.read_only=true;h:enter(h:add_frv(336,467));h:tick(3);h:clean();eq(#w,0);eq(h.a.FRV.mode,'FRV')
end)
test('deleting an active TXT retains current settings rather than stale JSON',function()
 local h=H.fresh();local s,w=fs(h);s['frv_hud_position.txt']=valid;pos(h);s['frv_hud_position.txt']=nil
 s['frv_hud_position.json']='{"x":0.99,"y":0.99,"scale":2}';h.a.M.clock=3;pos(h);eq(h.a.Position.x,.23)
end)
test('oversized input / executable text rejected with no side effects',function()
 local p=H.fresh().a.Position;eq(p.parse_txt(string.rep('a',4097)),nil);eq(p.parse_txt('x=0.1\ny=0.1\nscale=1\nos.execute("bad")'),nil)
end)
print('RESULT POSITION_TXT cases='..count..' fails='..failed)
if failed>0 then os.exit(1)end
