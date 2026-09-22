-- Fallback test runner for environments without LuaJIT. It adapts environment
-- loading only; this is NOT a claim of LuaJIT runtime compatibility or HD2 testing.
loadstring=loadstring or load
unpack=unpack or table.unpack
if not setfenv then
 function setfenv(f,env)
  local i=1
  while true do
   local name=debug.getupvalue(f,i)
   if not name then break end
   if name=='_ENV' then debug.upvaluejoin(f,i,function()return env end,1);break end
   i=i+1
  end
  return f
 end
end
local file=assert(arg[1],'test file required')
local root=arg[2] or '.';arg={root}
assert(loadfile(file))()
