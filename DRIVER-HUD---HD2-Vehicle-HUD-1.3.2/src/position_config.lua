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
 function Position.reload(now)
  if now<Position.next_read then return end;Position.next_read=now+2
  if not dir or not io or not io.open then return end
  local ok,f=pcall(io.open,dir..'/Arrowhead/Helldivers2/frv_hud_position.json','rb')
  if not ok then return end
  local value,why
  if f then
   local readok,s=pcall(f.read,f,4097);pcall(f.close,f)
   if not readok or type(s)~='string' then return end
   value,why=parse(s)
  else value=defaults end
  if not value then
   if Position.error~=why then log('FRV_CONFIG rejected='..why..' keeping_previous=true');Position.error=why end
   return
  end
  Position.error=nil
  if value.x~=Position.x or value.y~=Position.y or value.scale~=Position.scale then
   Position.x,Position.y,Position.scale=value.x,value.y,value.scale;Position.revision=Position.revision+1
   log('FRV_CONFIG x='..value.x..' y='..value.y..' scale='..value.scale)
  end
 end
end
