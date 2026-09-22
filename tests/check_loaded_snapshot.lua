-- Optional: verify production compatibility gates against a user-supplied loaded
-- module image (RVA-indexed bytes), without executing or publishing that image.
local root,path=arg[1],arg[2]
local f=assert(io.open(root..'/src/native_reader.lua','rb'));local s=f:read('*a');f:close()
local N=assert(loadstring('local C={}\n'..s..'\nreturn Native'))()
local input=assert(io.open(path,'rb'));local base=0x100000000
local ok,why=N.check_module(function(p,n)assert(input:seek('set',p-base));return input:read(n)end,base)
input:close();assert(ok,why)
print('PASS production native gate matches the actual supplied loaded module')
print('DETAIL '..why)
