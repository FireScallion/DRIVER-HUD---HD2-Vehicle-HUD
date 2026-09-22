-- Emit actual production FRV drawing commands; this is NOT an in-game screenshot.
local root=arg[1]
local helpers=assert(loadfile(root..'/tests/test_integration.lua'))()
local function json(v)
 local t=type(v)
 if t=='nil'then return 'null' elseif t=='boolean'or t=='number'then return tostring(v)
 elseif t=='string'then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
 local out={};local array=#v>0
 if array then for i,x in ipairs(v)do out[#out+1]=json(x)end
 else for k,x in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(x)end end
 return (array and '['or'{')..table.concat(out,',')..(array and']'or'}')
end
local all={}
for _,case in ipairs({{name='healthy',hp=2400,w={350,350,350,350},damage={0,0,0,0}},
 {name='yellow_75',hp=1800,w={327,350,350,235},damage={0,0,0,0}},
 {name='red_50',hp=1200,w={97,350,166,28},damage={0,0,0,0}},
 {name='lf_rr_destroyed',hp=1200,w={0,350,350,0},damage={2,0,0,2}}})do
 local h=helpers.fresh();local d=h:add_frv(336,467);h.objects[336].hp=case.hp;h.health[467].hp=case.w;h.health[467].damage=case.damage
 h:enter(d);h:tick(.3);local x,y,s=h.a.FRV.layout(h.width,h.height);local commands={}
 for _,id in ipairs(h.a.M.ids)do commands[#commands+1]=h.commands[id[2]]end
 all[#all+1]={name=case.name,origin_x=x,origin_y=y,scale=s,commands=commands}
end
local f=assert(io.open(root..'/evidence/ui_draw_commands.json','w'));f:write(json(all));f:close()
