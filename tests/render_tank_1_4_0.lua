-- Offline preview from the real production Gui.triangle commands, not a mock drawing.
local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='TANK_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local f=assert(loadstring(read(ROOT..'/tests/test_tank_1_4_0.lua')));setfenv(f,env);local H=f()
local cases={}
local h,d,r=H.populate(1);cases[1]={'new_full',h}
local h,d,r=H.populate(1);h.objects[r[1]].f[7]=173;h.objects[r[1]].f[6]=4;h.objects[r[4]].f[18]=9;h.objects[r[5]].f[18]=9;h:tick(.8);cases[2]={'new_partial',h}
local h,d,r=H.populate(1);h.objects[r[1]].f[7]=0;h.objects[r[1]].f[28]=5;h:tick(2);h.objects[r[1]].f[28]=1;h:tick(.3);cases[3]={'new_paused',h}
local h=H.fresh();h:enter(h:add_tank(351,600),1);h.objects[349].f[14]=0;h:tick(1);h.objects[349].f[6]=0;h.objects[349].f[14]=4;h:tick(1.6);cases[4]={'old_reload',h}
local out=assert(io.open(ROOT..'/evidence/tank_preview_commands.json','wb'));out:write('[')
for i,entry in ipairs(cases)do
 if i>1 then out:write(',')end;local name,h=entry[1],entry[2]
 out:write('{"name":"'..name..'","width":1920,"height":1080,"triangles":[')
 local ids={};for id,c in pairs(h.commands)do if c.kind=='triangle'then ids[#ids+1]=id end end;table.sort(ids)
 for j,id in ipairs(ids)do
  if j>1 then out:write(',')end;local a=h.commands[id].args
  out:write(string.format('[[%.4f,%.4f],[%.4f,%.4f],[%.4f,%.4f],[%d,%d,%d,%d]]',a[2][1],a[2][3],a[3][1],a[3][3],a[4][1],a[4][3],a[6][1],a[6][2],a[6][3],a[6][4]))
 end
 out:write(']}')
end
out:write(']\n');out:close()
print('RESULT RENDER_TANK_PREVIEW cases=4')
