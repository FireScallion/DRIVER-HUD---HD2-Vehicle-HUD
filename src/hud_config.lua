-- Unified data dictionary. No eval/loadstring, shell, external executable or writes
-- to game state. Existing CFG/FRV position settings are imported on first creation.
local HudConfig={next_read=0,revision=0}
HudConfig.schema={
 tank_offset_y={45,500},tank_scale={.5,2},frv_x={0,1},frv_y={0,1},frv_scale={.5,2},
 alpha={.1,1},font={new=true,old=true},reload_ring={boolean=true},reticle={boolean=true},
 weapon_cache={boolean=true},debug={boolean=true},perf={boolean=true}
}
function HudConfig.current()
 return {tank_offset_y=C.offset_y,tank_scale=C.scale,frv_x=Position.x,frv_y=Position.y,frv_scale=Position.scale,
  alpha=C.alpha,font=C.geometry_numbers and 'new' or 'old',reload_ring=C.reload_ring~=false,reticle=C.reticle~=false,
  weapon_cache=C.weapon_cache~=false,debug=C.debug,perf=C.perf}
end
function HudConfig.parse(s)
 if type(s)~='string' or #s>8192 then return nil,'file exceeds 8 KiB' end
 s=s:gsub('^\239\187\191','')
 if s:sub(1,2)=='\255\254' or s:sub(1,2)=='\254\255' then
  local le=s:sub(1,2)=='\255\254';if #s%2~=0 then return nil,'invalid UTF-16' end
  local out={};for i=3,#s,2 do local a,b=s:byte(i,i+1);local n=le and (a+b*256) or (b+a*256);out[#out+1]=n<128 and string.char(n) or '?' end;s=table.concat(out)
 end
 if s:find('\0',1,true) then return nil,'invalid encoding' end
 local out={}
 for line in (s..'\n'):gmatch('(.-)\n') do
  line=line:gsub('[#;].*$',''):match('^%s*(.-)%s*$')
  if line~='' then
   local k,v=line:match('^([a-z_]+)%s*=%s*([%w%.%-]+)$');local spec=k and HudConfig.schema[k]
   if not spec or out[k]~=nil then return nil,'unknown/duplicate setting '..tostring(k) end
   if spec.boolean then
    if v~='true' and v~='false' then return nil,'expected true/false for '..k end;out[k]=v=='true'
   elseif spec[1] then
    if not (v:match('^%d+$') or v:match('^%d+%.%d+$')) then return nil,'invalid decimal '..k end
    local n=tonumber(v);if not n or n~=n or n<spec[1] or n>spec[2] then return nil,'out of range '..k end;out[k]=n
   else if not spec[v] then return nil,'expected new/old for font' end;out[k]=v end
  end
 end
 for k in pairs(HudConfig.schema) do if out[k]==nil then return nil,'missing setting '..k end end
 return out
end
function HudConfig.template(v)
 local lines={
 '# DRIVER HUD 1.4.3 - Unified HUD settings / 统一设置',
 '# Edit in Notepad and save; applies in about 2 seconds / 记事本保存后约两秒生效',
 '# Invalid edits preserve ALL previous settings / 格式错误保留全部上次设置',
 '# font = new (default / 默认几何字体) or old (旧版字体)',
 '# tank_offset_y: 45..500, from bottom at reference resolution / 参考分辨率距底部',
 '# tank_scale / frv_scale: 0.5..2; alpha: 0.1..1',
 '# frv_x: left 0 -> right 1; frv_y: top 0 -> bottom 1 / FRV中心归一化位置',
 '# weapon_cache=false uses bounded batch only / 关闭组件缓存仅保留有限频率批量读取',
 '# debug writes diagnostics; perf adds 10-second CPU/call summaries',
 '# 原 driver_hud.cfg / frv_hud_position.txt 仅首次迁入；以后修改本文件', ''}
 for _,k in ipairs({'tank_offset_y','tank_scale','frv_x','frv_y','frv_scale','alpha','font','reload_ring','reticle','weapon_cache','debug','perf'}) do lines[#lines+1]=k..' = '..tostring(v[k]) end
 return table.concat(lines,'\r\n')..'\r\n'
end
function HudConfig.apply(v)
 local prev=HudConfig.current();local changed=false
 for k,x in pairs(v) do if prev[k]~=x then changed=true end end
 if not changed then return end
 C.offset_y,C.scale,C.alpha=v.tank_offset_y,v.tank_scale,v.alpha
 C.geometry_numbers=v.font=='new';C.reload_ring,C.reticle,C.weapon_cache=v.reload_ring,v.reticle,v.weapon_cache
 C.debug,C.perf=v.debug,v.perf;Native.perf=C.perf
 Position.x,Position.y,Position.scale=v.frv_x,v.frv_y,v.frv_scale
 Position.revision=Position.revision+1;HudConfig.revision=HudConfig.revision+1;M.draw_key=nil
 if Tank then Tank.ring_key=nil end
 log('HUD_CONFIG applied revision='..HudConfig.revision..' font='..v.font)
end
function HudConfig.reload(now)
 if now<HudConfig.next_read then return end;HudConfig.next_read=now+2
 if not dir or not io or not io.open then return end
 local path=dir..'/Arrowhead/Helldivers2/driver_hud_settings.txt'
 local ok,f,err,code=pcall(io.open,path,'rb');if not ok then return end
 if not f then
  if code~=2 and not (err==nil and code==nil) then return end
  if not HudConfig.imported then Position.reload(now);HudConfig.imported=true end
  if now<(HudConfig.next_create or 0) then return end;HudConfig.next_create=now+30
  local check,existing,again_error,again_code=pcall(io.open,path,'rb');if not check then return end
  if existing then pcall(existing.close,existing);return end
  if again_code~=2 and not (again_error==nil and again_code==nil) then return end
  local good,output=pcall(io.open,path,'wb')
  if good and output then local wrote,result=pcall(output.write,output,HudConfig.template(HudConfig.current()));pcall(output.close,output);if wrote and result then log('HUD_CONFIG created=driver_hud_settings.txt') end end
  return
 end
 HudConfig.imported=true
 local good,s=pcall(f.read,f,8193);pcall(f.close,f);if not good then return end
 local value,why=HudConfig.parse(s)
 if value then HudConfig.error=nil;HudConfig.apply(value)
 elseif HudConfig.error~=why then log('HUD_CONFIG rejected='..tostring(why)..' keeping_previous=true');HudConfig.error=why end
end
