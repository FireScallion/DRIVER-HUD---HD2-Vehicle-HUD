-- A small data-only flat JSON parser. Never execute an editable config as Lua.
local Position = {x=0.714,y=0.90,scale=1,revision=0,next_read=0}
do
 local defaults={x=0.714,y=0.90,scale=1}
 local function parse(s)
  if #s>4096 then return nil,'configuration exceeds 4 KiB' end
  s=s:gsub('^\239\187\191','')
  local at,len=1,#s
  local function ws() while at<=len and s:sub(at,at):match('%s') do at=at+1 end end
  local function quoted()
   if s:sub(at,at)~='"' then error('expected JSON string',0) end
   at=at+1;local out={}
   while at<=len do
    local c=s:sub(at,at);at=at+1
    if c=='"' then return table.concat(out) end
    if c=='\\' then
     local e=s:sub(at,at);at=at+1
     if e=='u' then
      local h=s:sub(at,at+3);if not h:match('^%x%x%x%x$') then error('invalid JSON escape',0) end
      out[#out+1]='\\u'..h;at=at+4
     elseif e=='"' or e=='\\' or e=='/' or e=='n' or e=='r' or e=='t' or e=='b' or e=='f' then out[#out+1]=e
     else error('invalid JSON escape',0) end
    elseif c:byte()<32 then error('control character in string',0)
    else out[#out+1]=c end
   end
   error('unterminated JSON string',0)
  end
  local function decode()
   ws();if s:sub(at,at)~='{' then error('expected JSON object',0) end;at=at+1;ws()
   local out,seen={},{}
   if s:sub(at,at)=='}' then error('missing position keys',0) end
   while true do
    ws();local key=quoted();if seen[key] then error('duplicate key '..key,0) end;seen[key]=true
    ws();if s:sub(at,at)~=':' then error('expected colon',0) end;at=at+1;ws()
    if key:sub(1,1)=='_' then quoted()
    elseif key=='x' or key=='y' or key=='scale' then
     local start=at
     while at<=len and s:sub(at,at):match('[%d%.%+%-%e%E]') do at=at+1 end
     local token=s:sub(start,at-1)
     -- This dictionary intentionally accepts finite ordinary decimal JSON numbers.
     if not (token:match('^%-?%d+$') or token:match('^%-?%d+%.%d+$')) then error('use an ordinary decimal for '..key,0) end
     local digits=token:gsub('^%-','');if digits:match('^0%d') then error('invalid leading zero',0) end
     local v=tonumber(token)
     if not v or v~=v or v==math.huge or v==-math.huge then error('invalid number '..key,0) end
     if key=='scale' then if v<0.5 or v>2 then error('scale must be 0.5..2',0) end
     elseif v<0 or v>1 then error(key..' must be 0..1',0) end
     out[key]=v
    else error('unknown position key '..key,0) end
    ws();local c=s:sub(at,at);at=at+1
    if c=='}' then break elseif c~=',' then error('expected comma or object end',0) end
   end
   ws();if at<=len then error('trailing JSON content',0) end
   if out.x==nil or out.y==nil or out.scale==nil then error('x, y and scale are required',0) end
   return out
  end
  local ok,out=pcall(decode);if ok then return out end;return nil,tostring(out)
 end
 Position.parse=parse

 -- TXT is authoritative after first creation. JSON parser above is migration-only.
 local function ascii_text(s)
  s=s:gsub('^\239\187\191','')
  local le=s:sub(1,2)=='\255\254';local be=s:sub(1,2)=='\254\255'
  if le or be then
   if #s%2~=0 then return nil end
   local t={}
   for i=3,#s,2 do
    local a,b=s:byte(i,i+1);local n=le and (a+b*256) or (b+a*256)
    t[#t+1]=n<128 and string.char(n) or '?'
   end
   return table.concat(t)
  end
  return s
 end
 function Position.parse_txt(s)
  if type(s)~='string' or #s>4096 then return nil,'configuration exceeds 4 KiB' end
  s=ascii_text(s);if not s or s:find('\0',1,true) then return nil,'invalid text encoding' end
  local out={}
  for line in (s..'\n'):gmatch('(.-)\n') do
   line=line:gsub('[#;].*$',''):match('^%s*(.-)%s*$')
   if line~='' then
    local k,v=line:match('^([a-z_]+)%s*=%s*([%d%.%-%+]+)%s*$')
    if not k or (k~='x' and k~='y' and k~='scale') or out[k]~=nil then return nil,'invalid or duplicate setting' end
    if not (v:match('^%d+$') or v:match('^%d+%.%d+$')) then return nil,'use ordinary positive decimals' end
    local n=tonumber(v)
    if not n or n~=n or n==math.huge or (k=='scale' and (n<.5 or n>2)) or (k~='scale' and (n<0 or n>1)) then return nil,'setting out of range' end
    out[k]=n
   end
  end
  if out.x==nil or out.y==nil or out.scale==nil then return nil,'x, y and scale are all required' end
  return out
 end
 function Position.template(v)
  return '# DRIVER HUD 1.4 - FRV HUD position / FRV HUD 位置与大小\r\n'
   ..'# Edit THIS file in Notepad, save, wait about 2 seconds in game.\r\n'
   ..'# 使用记事本修改本文件，保存后约两秒生效；无需重新部署。\r\n'
   ..'# This file is outside the Arsenal ZIP. Do not edit the ZIP copy.\r\n'
   ..'# 本文件位于 AppData，不在安装 ZIP 内；更新 MOD 不会覆盖它。\r\n'
   ..'# x: 0 = left / 左, 1 = right / 右 (HUD centre / 中心)\r\n'
   ..'# y: 0 = top / 顶部, 1 = bottom / 底部 (HUD centre / 中心)\r\n'
   ..'# scale: 0.5 to 2.0 / 大小范围 0.5 至 2.0\r\n'
   ..'# Keep all three settings. Defaults / 默认: x=0.714 y=0.90 scale=1\r\n'
   ..'# Invalid or incomplete edits keep the previous position.\r\n'
   ..'# 格式错误或缺项时保留上次有效设置；不要改文件扩展名。\r\n'
   ..string.format('\r\nx = %.6f\r\ny = %.6f\r\nscale = %.6f\r\n',v.x,v.y,v.scale)
 end
 local function read_file(path)
  local ok,f,err,code=pcall(io.open,path,'rb')
  if not ok then return nil,'open_error' end
  if not f then return nil,(code==2 or (code==nil and err==nil)) and 'missing' or 'open_error' end
  local rok,s=pcall(f.read,f,4097);pcall(f.close,f)
  if not rok or type(s)~='string' then return nil,'read_error' end
  return s
 end
 function Position.reload(now)
  if now<Position.next_read then return end;Position.next_read=now+2
  if not dir or not io or not io.open then return end
  local path=dir..'/Arrowhead/Helldivers2/frv_hud_position.txt'
  local content,reason=read_file(path)
  local value,why
  if content then value,why=Position.parse_txt(content)
  elseif reason=='missing' then
   -- Do not revert to obsolete JSON after a player's TXT has already been loaded.
   value={x=Position.x,y=Position.y,scale=Position.scale}
   if not Position.txt_seen then
    local old=read_file(dir..'/Arrowhead/Helldivers2/frv_hud_position.json')
    local imported=old and parse(old);if imported then value=imported end
   end
   if now>=(Position.next_create or 0) then
    Position.next_create=now+30
    -- Recheck immediately before creation; never intentionally truncate an existing file.
    local check,absent=read_file(path)
    if not check and absent=='missing' then
     local ok,f=pcall(io.open,path,'wb')
     if ok and f then
      local wrote,result=pcall(f.write,f,Position.template(value));pcall(f.close,f)
      if wrote and result~=nil then Position.txt_seen=true;log('FRV_CONFIG created=frv_hud_position.txt') end
     end
    end
   end
  else return end
  if not value then
   if Position.error~=why then log('FRV_CONFIG rejected='..tostring(why)..' keeping_previous=true');Position.error=why end
   return
  end
  if content then Position.txt_seen=true end
  Position.error=nil
  if value.x~=Position.x or value.y~=Position.y or value.scale~=Position.scale then
   Position.x,Position.y,Position.scale=value.x,value.y,value.scale;Position.revision=Position.revision+1
   log('FRV_CONFIG x='..value.x..' y='..value.y..' scale='..value.scale)
  end
 end
end
