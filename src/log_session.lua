-- One log generation per helldivers2.exe process. A script reload in the same
-- process must append to the current log instead of rotating it again.
local LOG_DIR = dir and (dir..'/Arrowhead/Helldivers2') or nil
local LOG_PATH = LOG_DIR and (LOG_DIR..'/driver_hud.log') or nil
local LOG_PREVIOUS_PATH = LOG_DIR and (LOG_DIR..'/driver_hud_previous.log') or nil
local LOG_SESSION_PATH = LOG_DIR and (LOG_DIR..'/driver_hud_session.id') or nil

local function process_session_identity()
 if not C.debug then return nil,nil end
 local ok,ffi=pcall(require,'ffi')
 if not ok or not ffi or ffi.os~='Windows' or not ffi.abi('64bit') then return nil,nil end
 pcall(ffi.cdef,'unsigned long __stdcall GetCurrentProcessId(void);')
 pcall(ffi.cdef,'void * __stdcall GetCurrentProcess(void);')
 pcall(ffi.cdef,'int __stdcall GetProcessTimes(void *, void *, void *, void *, void *);')
 local loaded,k=pcall(ffi.load,'kernel32');if not loaded or not k then return nil,nil end
 local ok_pid,pid=pcall(k.GetCurrentProcessId);pid=ok_pid and tonumber(pid) or nil
 if not pid then return nil,nil end
 local created=ffi.new('uint32_t[2]')
 local exit_t=ffi.new('uint32_t[2]');local kernel_t=ffi.new('uint32_t[2]');local user_t=ffi.new('uint32_t[2]')
 local ok_h,h=pcall(k.GetCurrentProcess);if not ok_h or h==nil then return tostring(pid),pid end
 local ok_t,worked=pcall(k.GetProcessTimes,h,ffi.cast('void *',created),ffi.cast('void *',exit_t),ffi.cast('void *',kernel_t),ffi.cast('void *',user_t))
 if ok_t and tonumber(worked)~=0 then
  return string.format('%u:%08x%08x',pid,tonumber(created[1]),tonumber(created[0])),pid
 end
 return tostring(pid),pid
end

local function read_first_line(path)
 local ok,f=pcall(io.open,path,'rb');if not ok or not f then return nil end
 local ok_r,s=pcall(f.read,f,'*l');pcall(f.close,f)
 return ok_r and s or nil
end
local function write_text(path,s)
 local ok,f=pcall(io.open,path,'wb');if not ok or not f then return false end
 local ok_w=pcall(f.write,f,s);pcall(f.close,f);return ok_w
end
local function file_exists(path)
 local ok,f=pcall(io.open,path,'rb');if ok and f then pcall(f.close,f);return true end
 return false
end
local function copy_then_truncate(src,dst)
 local ok_s,s=pcall(io.open,src,'rb');if not ok_s or not s then return false end
 local ok_d,d=pcall(io.open,dst,'wb');if not ok_d or not d then pcall(s.close,s);return false end
 local good=true
 while true do
  local ok_r,chunk=pcall(s.read,s,65536)
  if not ok_r then good=false;break end
  if not chunk or #chunk==0 then break end
  if not pcall(d.write,d,chunk) then good=false;break end
 end
 pcall(s.close,s);pcall(d.close,d)
 if not good then return false end
 local ok_t,t=pcall(io.open,src,'wb');if not ok_t or not t then return false end
 pcall(t.close,t);return true
end

local function init_log_session()
 if not C.debug or not LOG_PATH or not io or not io.open then return nil,nil,'disabled' end
 local global_key=rawget(_G,'__DRIVER_HUD_LOG_SESSION_KEY')
 if global_key then return global_key,rawget(_G,'__DRIVER_HUD_LOG_SESSION_PID'),'same_process' end
 local key,pid=process_session_identity()
 if not key then
  -- Fail safe: without a process identity, never rotate on a possible script reload.
  key='lua_state:'..tostring({}):gsub('table: ','')
  rawset(_G,'__DRIVER_HUD_LOG_SESSION_KEY',key);rawset(_G,'__DRIVER_HUD_LOG_SESSION_PID',pid)
  return key,pid,'no_process_identity'
 end
 local previous_key=LOG_SESSION_PATH and read_first_line(LOG_SESSION_PATH) or nil
 local status='same_process'
 if previous_key~=key then
  status='new_process_no_old_log'
  if file_exists(LOG_PATH) then
   if os and os.remove then pcall(os.remove,LOG_PREVIOUS_PATH) end
   local renamed=false
   if os and os.rename then local ok_r,r=pcall(os.rename,LOG_PATH,LOG_PREVIOUS_PATH);renamed=ok_r and r and true or false end
   if renamed then status='rotated_previous'
   elseif copy_then_truncate(LOG_PATH,LOG_PREVIOUS_PATH) then status='copied_previous'
   else status='rotation_failed_append' end
  end
  if LOG_SESSION_PATH and not write_text(LOG_SESSION_PATH,key..'\n') then status=status..'+session_marker_failed' end
 end
 rawset(_G,'__DRIVER_HUD_LOG_SESSION_KEY',key);rawset(_G,'__DRIVER_HUD_LOG_SESSION_PID',pid)
 return key,pid,status
end

local LOG_SESSION_KEY,LOG_SESSION_PID,LOG_ROTATION = init_log_session()
local function log(s)
 if not C.debug or not LOG_PATH or not io or not io.open then return end
 local ok,f=pcall(io.open,LOG_PATH,'a')
 if ok and f then pcall(f.write,f,tostring(s)..'\n');pcall(f.close,f) end
end
local LOG_UTC=(os and os.date and call(os.date,'!%Y-%m-%dT%H:%M:%SZ')) or 'unknown'
if LOG_ROTATION=='same_process' then
 log('DRIVER_HUD SCRIPT_RELOAD version=1.3.4 pid='..tostring(LOG_SESSION_PID or 'unknown')..' utc='..tostring(LOG_UTC))
else
 log('DRIVER_HUD SESSION_START version=1.3.4 pid='..tostring(LOG_SESSION_PID or 'unknown')..' session='..tostring(LOG_SESSION_KEY)..' rotation='..tostring(LOG_ROTATION)..' utc='..tostring(LOG_UTC))
end
