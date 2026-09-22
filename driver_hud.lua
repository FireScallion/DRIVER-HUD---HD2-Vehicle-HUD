-- HD2-Addon: mods/driverhud/driver_hud
-- DRIVER HUD 1.3.2. Tank + FRV integration with per-wheel Health fault isolation.
local sr = rawget(_G, 'stingray')
if not sr then return {installed=false} end
if rawget(_G,'__DRIVER_HUD_INSTALLED') then return {installed=true} end
local App,Net,GS,World,Gui = sr.Application,sr.Network,sr.GameSession,sr.World,sr.Gui
local V2,V3,Color = sr.Vector2,sr.Vector3,sr.Color
local function call(f,...) if type(f)~='function' then return nil end local ok,a,b=pcall(f,...);if ok then return a,b end end
local C={debug=true,offset_y=155,scale=1,alpha=0.76}
local dir=call(os.getenv,'APPDATA')
if dir and io and io.open then
 local f=io.open(dir..'/Arrowhead/Helldivers2/driver_hud.cfg','r')
 if f then
  for l in f:lines() do
   local k,v=l:match('^%s*([%w_]+)%s*=%s*([%w%.%-]+)')
   if k=='debug' then C.debug=v=='true' elseif C[k]~=nil then
    local n=tonumber(v);if n and n==n then
     if k=='offset_y' then C[k]=math.max(45,math.min(500,n))
     elseif k=='scale' then C[k]=math.max(0.5,math.min(2,n))
     elseif k=='alpha' then C[k]=math.max(0.1,math.min(1,n)) end
    end
   end
  end
  f:close()
 end
end
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
 log('DRIVER_HUD SCRIPT_RELOAD version=1.3.2 pid='..tostring(LOG_SESSION_PID or 'unknown')..' utc='..tostring(LOG_UTC))
else
 log('DRIVER_HUD SESSION_START version=1.3.2 pid='..tostring(LOG_SESSION_PID or 'unknown')..' session='..tostring(LOG_SESSION_KEY)..' rotation='..tostring(LOG_ROTATION)..' utc='..tostring(LOG_UTC))
end
log('DRIVER_HUD 1.3.2 START native_contract=r3-cc75948d proxy_unit_health=1 wheel_fault_isolation=1')
local FRV -- Forward declaration for lifecycle reset.
local M={ids={},frame=0,clock=0,seated=false,hull=nil,vehicle_ref=nil,cache={},known={},bind_retry=0,bind_weak=false,seat_enter_frame=0,preseat_owned={},entry_new_seen={},entry_owned_cursor=1,bg_owned_cursor=1}
local function clear()
 if M.gui then for _,p in ipairs(M.ids) do call(Gui[p[1]],M.gui,p[2]) end end
 M.ids={};M.draw_key=nil
end
local function live(worlds,w) for _,v in pairs(worlds or {}) do if v==w then return true end end return false end
local function surface_reset(worlds)
 if M.gui and live(worlds,M.gui_world) then clear();call(World.destroy_gui,M.gui_world,M.gui) end
 M.ids={};M.gui=nil;M.gui_world=nil;M.draw_key=nil
end
local function clear_values()
 M.hp=nil;M.max=nil;M.ammo=nil;M.mg=nil
end
local function full_reset()
 if FRV then FRV.reset() end
 M.cache={};M.pending_bind=nil;M.seat_hint=nil;M.ownership=nil;M.seat_scan=nil;M.next_bind=0;M.seat_unknown_since=nil
 M.seated=false;M.hull=nil;M.vehicle_ref=nil;M.bind_retry=0;M.bind_weak=false;M.seat_enter_frame=0;M.entry_new_seen={};M.entry_owned_cursor=1;clear_values()
end
local function integer(n,hi) return type(n)=='number' and n==math.floor(n) and n>=0 and n<=hi end
-- One shared native batch budget; time-based, never catch-up bursts.
local batch_clock,batch_tokens,batch_frame,batch_count=0,4,-1,0
local discovery_clock,discovery_tokens=0,2
local function sample(session,id)
 local now=M.clock
 batch_tokens=math.min(4,batch_tokens+math.max(0,now-batch_clock)*40);batch_clock=now
 if batch_frame~=M.frame then batch_frame=M.frame;batch_count=0 end
 if batch_tokens<1 or batch_count>=4 then return nil end
 if type(id)~='number' or call(GS.game_object_exists,session,id)~=true then return nil end
 batch_tokens=batch_tokens-1;batch_count=batch_count+1
 local f=call(GS.game_object_field_batched,session,id,{})
 return type(f)=='table' and f or nil
end
local function discovery_sample(session,id)
 local now=M.clock
 discovery_tokens=math.min(2,discovery_tokens+math.max(0,now-discovery_clock)*8);discovery_clock=now
 if discovery_tokens<1 then return nil end
 discovery_tokens=discovery_tokens-1
 return sample(session,id)
end
local function hull_sig(f)
 return type(f)=='table' and type(f[15])=='number' and math.abs(f[15]-8000)<0.001 and type(f[30])=='number' and f[30]>=0 and f[30]<=f[15]
end
local function main_sig(f)
 return type(f)=='table' and integer(f[5],30) and integer(f[6],1) and integer(f[11],1)
end
local function coax_sig(f)
 return type(f)=='table' and integer(f[6],2000) and type(f[11])=='number' and f[11]>=0 and f[11]<=100
end
local function valid_goid(session,v)
 return type(v)=='number' and v==math.floor(v) and v>0 and v<32767 and call(GS.game_object_exists,session,v)==true
end
local function current_vehicle_ref(session,avatar)
 local av=discovery_sample(session,avatar)
 if type(av)~='table' then return nil,'unknown' end
 local a64=av[64]
 if type(a64)~='table' then return nil,'unknown' end
 local v=a64[25]
 if type(v)~='number' then return nil,'unknown' end
 if v==32767 then return 32767,'none' end
 return v,'ref'
end
local function cache_for(hid)
 local c=M.cache[hid]
 if not c then c={};M.cache[hid]=c end
 return c
end
local function seat_mask(f)
 local v=type(f)=='table' and f[22] or nil
 if integer(v,15) then return v end
 return nil
end
local function hull_has_ref(f,ref)
 local t=type(f)=='table' and f[56] or nil
 if type(t)~='table' then return false end
 for _,v in pairs(t) do if v==ref then return true end end
 return false
end
local function remember_hull(hid,hf)
 local k=M.known[hid]
 if not k then k={};M.known[hid]=k end
 local sm=seat_mask(hf)
 if sm~=nil then k.seatmask=sm;k.last_seen=M.frame;k.seen_time=M.clock end
end
local function bind_hull(hid,hf,why)
 if not hull_sig(hf) then return false end
 -- Seat changes elsewhere are a hint, never proof of local occupancy.
 if why=='known_seat_bit' then
  M.seat_hint=hid
  return false
 end
 if why~='avatar64.25_hull' and why~='avatar64.25_weapon' and why~='local_gunner_owned_weapon' and why~='native_seater' then return false end
 if M.hull==hid then
  if why=='avatar64.25_hull' or why=='avatar64.25_weapon' or why=='native_seater' then M.bind_weak=false end
  return
 end
 local pending=M.pending_bind
 if why~='native_seater' and (not pending or pending.hid~=hid or M.clock-pending.last>5) then
  M.pending_bind={hid=hid,last=M.clock,frame=M.frame}
  log('BASTION_CONFIRM_PENDING hull='..hid..' evidence='..why)
  return false
 end
 -- The discovery scheduler provides separate observations; no fixed UI delay.
 if why~='native_seater' and pending.frame==M.frame then return false end
 M.pending_bind=nil;M.seat_hint=nil
 M.hull=hid;M.bind_retry=0;M.seat_scan=nil;M.ownership=nil
 M.bind_weak=not (why=='avatar64.25_hull' or why=='avatar64.25_weapon' or why=='native_seater')
 remember_hull(hid,hf)
 local c={};M.cache={[hid]=c};c.hp=hf[30];c.max=hf[15];c.hull_valid_at=M.clock;c.bound_at=M.clock
 c.main_id=hid-2;c.coax_id=hid-1;c.next_weapon_resolve=M.clock
 if c.next_hull==nil then c.next_hull=M.clock+0.033333 end
 if c.next_main==nil then c.next_main=M.clock end
 if c.next_coax==nil then c.next_coax=M.clock+0.066667 end
 M.hp,M.max,M.ammo,M.mg=c.hp,c.max,c.ammo,c.mg
 log('BASTION_BIND '..tostring(why)..' hull='..tostring(hid))
end
local function resolve_weapon_hull(session,ref)
 local offset
 if call(GS.game_object_is_type,session,ref,'rHVbvgIu')==true then offset=2
 elseif call(GS.game_object_is_type,session,ref,'fZwFCDKT')==true then offset=1 end
 if not offset then return nil,nil end
 local hid=ref+offset
 local hf=discovery_sample(session,hid)
 if hull_sig(hf) then return hid,hf end
 return nil,nil
end
local function single_seat_clear(old,new)
 if not integer(old,15) or not integer(new,15) then return false end
 local cleared=0
 for _,b in ipairs({1,2,4,8}) do
  local o=math.floor(old/b)%2
  local n=math.floor(new/b)%2
  if n>o then return false end
  if o==1 and n==0 then cleared=cleared+1 end
 end
 return cleared==1
end
local function gunner_seat_occupied(hf)
 local sm=seat_mask(hf)
 return sm~=nil and math.floor(sm/2)%2==0
end
local function discover_owned_bastions(session,ids)
 if M.clock<(M.next_background or 0) or #ids==0 then return end
 M.next_background=M.clock+0.5
 if M.bg_owned_cursor>#ids then M.bg_owned_cursor=1 end
 local id=ids[M.bg_owned_cursor];M.bg_owned_cursor=M.bg_owned_cursor+1
 local f=discovery_sample(session,id)
 if hull_sig(f) then remember_hull(id,f) end
end
local COAX_TYPE='fZwFCDKT'
local MAIN_BIND_TYPE='rHVbvgIu'
local function bind_local_gunner_ownership(session,ids)
 if M.hull or #ids==0 then return false end
 local present={};for _,id in ipairs(ids) do present[id]=true end
 local j=M.ownership
 if not j then
  local list={};for _,id in ipairs(ids) do list[#list+1]=id end;table.sort(list)
  j={list=list,index=1,hulls={}};M.ownership=j
 end
 -- Only type checks while searching; no full-batch expansion of arbitrary objects.
 for _=1,8 do
  local id=j.list[j.index]
  if not id then break end
  j.index=j.index+1
  if present[id] and valid_goid(session,id) then
   local hid
   if call(GS.game_object_is_type,session,id,MAIN_BIND_TYPE)==true then hid=id+2
   elseif call(GS.game_object_is_type,session,id,COAX_TYPE)==true then hid=id+1 end
   if hid then j.hulls[id]=hid end
  end
 end
 if j.index<=#j.list then return false end
 local all,fresh={},{}
 for id,hid in pairs(j.hulls) do
  if present[id] then all[hid]=true;if not M.preseat_owned[id] then fresh[hid]=true end end
 end
 local choices=next(fresh) and fresh or all
 local hid,count=nil,0;for h in pairs(choices) do hid=h;count=count+1 end
 if count==1 then
  local hf=discovery_sample(session,hid)
  if hull_sig(hf) then M.ownership=nil;bind_hull(hid,hf,'local_gunner_owned_weapon');return true end
 end
 M.ownership=nil
 return false
end
local function refresh_known_masks(session,force)
 if M.clock<(M.next_masks or 0) then return end
 M.next_masks=M.clock+0.5
 local keys={};for hid in pairs(M.known) do keys[#keys+1]=hid end;table.sort(keys)
 if #keys==0 then return end
 M.mask_cursor=(M.mask_cursor or 0)%#keys+1
 local hid=keys[M.mask_cursor]
 if call(GS.game_object_exists,session,hid)~=true then M.known[hid]=nil;return end
 local hf=discovery_sample(session,hid)
 if hull_sig(hf) then remember_hull(hid,hf) end
end
local function bind_known_seat_transition(session)
 if M.hull or not M.seat_enter_time or M.clock-M.seat_enter_time>5 then return false end
 local j=M.seat_scan
 if not j then
  j={keys={},index=1,count=0,updates={}}
  for hid,k in pairs(M.known) do
   if M.clock-(k.seen_time or -100)<5 then j.keys[#j.keys+1]=hid end
  end
  table.sort(j.keys);M.seat_scan=j
 end
 local hid=j.keys[j.index]
 if hid then
  local hf=discovery_sample(session,hid)
  if not hull_sig(hf) then return false end
  j.index=j.index+1
  local k=M.known[hid];local sm=seat_mask(hf)
  if sm~=nil and k then
   j.updates[hid]={sm=sm,hf=hf}
   if single_seat_clear(k.seatmask,sm) then j.count=j.count+1;j.hid=hid;j.hf=hf end
  end
  return false
 end
 M.seat_scan=nil
 for h,v in pairs(j.updates) do remember_hull(h,v.hf) end
 if j.count==1 then bind_hull(j.hid,j.hf,'known_seat_bit');return true end
 return false
end
local function fallback_bind(session,owned_ids)
 -- Local ownership is specific to this player; the global seat-bit heuristic can
 -- be triggered by another player's seat change when several Bastions are alive.
 if bind_local_gunner_ownership(session,owned_ids) then return true end
 if M.ownership then return false end
 return bind_known_seat_transition(session)
end
local function bind_current_vehicle(session,avatar,owned_ids)
 local ref,state=current_vehicle_ref(session,avatar)
 if state=='unknown' then
  if not M.hull then fallback_bind(session,owned_ids) end
  return
 end
 M.vehicle_ref=ref
 if state=='none' then
  if M.hull then return end
  fallback_bind(session,owned_ids)
  return
 end
 if not valid_goid(session,ref) then
  if not M.hull then fallback_bind(session,owned_ids) end
  return
 end
 if M.hull==ref then M.bind_weak=false;return end
 if M.pending_bind and ref~=M.pending_bind.hid and ref~=M.pending_bind.hid-2 and ref~=M.pending_bind.hid-1 then M.pending_bind=nil end
 if M.hull and ref~=M.hull then
  local c=M.cache[M.hull]
  if not c or (ref~=c.main_id and ref~=c.coax_id) then M.hull=nil;M.cache={};clear_values() end
 end
 local is_weapon=call(GS.game_object_is_type,session,ref,MAIN_BIND_TYPE)==true or call(GS.game_object_is_type,session,ref,COAX_TYPE)==true
 local f
 if not is_weapon then f=discovery_sample(session,ref) end
 if hull_sig(f) then
  bind_hull(ref,f,'avatar64.25_hull')
  return
 end
 local hid,hf=resolve_weapon_hull(session,ref)
 if hid then
  bind_hull(hid,hf,'avatar64.25_weapon')
  return
 end
 M.bind_retry=M.bind_retry+1
end

-- Only the coax type confirmed by the supplied in-game schema log is eligible.
local COAX_FIELD='BLKY2IrV'
local COAX_FIELDS={"49c250a6","31f86165","09d8bef4","50ac6619","ec64918b","d7a5d63e","4a893e74","e0a79052","9611c029","cc0b45e5","9d5d6cc7","c336a25c","3132608f","6f3ab277","4cbcc2a2","7030c54e","3ccffa7f"}
local coax_session,coax_declared,coax_retry
local function coax_schema(session)
 if coax_session~=session then coax_session=session;coax_declared=nil;coax_retry=0 end
 if coax_declared==true or (coax_declared==false and M.clock<(coax_retry or 0)) then return coax_declared end
 coax_retry=M.clock+5
 coax_declared=false
 local info=call(Net.object_info,COAX_TYPE)
 local fs=type(info)=='table' and info.fields
 if type(fs)=='table' and #fs==#COAX_FIELDS then
  coax_declared=true
  for i,expected in ipairs(COAX_FIELDS) do
   local d=fs[i]
   local h=type(d)=='table' and type(d.id)=='string' and d.id:lower():gsub('^0x','') or ''
   if #h<8 then h=string.rep('0',8-#h)..h end
   if h~=expected then coax_declared=false;break end
  end
 end
 log('COAX_SCHEMA declared='..tostring(coax_declared))
 return coax_declared
end
local function resolve_bound_weapon_ids(session,hid,hf,c)
 local refs=type(hf)=='table' and hf[56]
 local main_id,coax_id
 -- Prefer explicit current hull references over arithmetic adjacency.
 local checked=0
 if type(refs)=='table' then
  for _,ref in pairs(refs) do
   checked=checked+1;if checked>16 then break end
   if valid_goid(session,ref) then
    if not main_id and call(GS.game_object_is_type,session,ref,MAIN_BIND_TYPE)==true then main_id=ref end
    if not coax_id and call(GS.game_object_is_type,session,ref,COAX_TYPE)==true then coax_id=ref end
   end
  end
 end
 if not main_id and valid_goid(session,hid-2) and call(GS.game_object_is_type,session,hid-2,MAIN_BIND_TYPE)==true then main_id=hid-2 end
 if not coax_id and valid_goid(session,hid-1) and call(GS.game_object_is_type,session,hid-1,COAX_TYPE)==true then coax_id=hid-1 end
 -- Missing refs alone do not erase a still-live previously resolved weapon.
 if not main_id and valid_goid(session,c.main_id) and call(GS.game_object_is_type,session,c.main_id,MAIN_BIND_TYPE)==true then main_id=c.main_id end
 if not coax_id and valid_goid(session,c.coax_id) and call(GS.game_object_is_type,session,c.coax_id,COAX_TYPE)==true then coax_id=c.coax_id end
 if c.main_id~=main_id then c.ammo=nil;c.main_valid_at=nil;c.main_profile=nil;c.main_scan_done=nil;c.main_scan_index=nil;c.main_observed_count=nil;c.main_diag=nil end
 if c.coax_id~=coax_id then c.mg=nil;c.coax_valid_at=nil;c.coax_diag=nil end
 if c.main_id~=main_id or c.coax_id~=coax_id then log('WEAPON_IDS hull='..hid..' main='..tostring(main_id)..' coax='..tostring(coax_id)) end
 c.main_id=main_id;c.coax_id=coax_id
end
local function read_coax(session,cid,c)
 -- Caller has confirmed the bound hull's weapon reference and its 10 Hz budget.
 -- Recheck type on every read so a reused GOID cannot inherit getter eligibility.
 local matched=call(GS.game_object_is_type,session,cid,COAX_TYPE)==true
 local targeted=matched and coax_schema(session) and type(GS.game_object_field)=='function'
 local value
 if targeted then
  if call(GS.game_object_exists,session,cid)~=true then return end
  value=call(GS.game_object_field,session,cid,COAX_FIELD)
  -- Do not add a batch read on a transient missing/invalid targeted value.
 elseif matched then
  local cf=sample(session,cid)
  if coax_sig(cf) then value=cf[6] end
 end
 local mode=targeted and 'targeted' or 'batch'
 local d=c.coax_diag
 if not d or d.mode~=mode then
  d={mode=mode,start=M.clock,attempts=0,valid=0,changed=0};c.coax_diag=d
  log('COAX_PATH goid='..cid..' mode='..mode)
 end
 d.attempts=d.attempts+1
 if integer(value,2000) then
  d.valid=d.valid+1
  if c.mg~=nil and value~=c.mg then d.changed=d.changed+1 end
  c.mg=value;c.coax_seen=true;c.coax_valid_at=M.clock
 end
 if M.clock-d.start>=10 then
  log('COAX_READ goid='..cid..' mode='..mode..' seconds='..string.format('%.1f',M.clock-d.start)..' attempts='..d.attempts..' valid='..d.valid..' changed='..d.changed..' ammo='..tostring(c.mg))
  d.start=M.clock;d.attempts=0;d.valid=0;d.changed=0
 end
end


-- Main-gun discovery is declaration-first and session-local. Candidate rows only
-- keep the three fields the existing proven batch formula used (#5 + #6 + #11).
local MAIN_CANDIDATES={
{t="xlo1r28A",n=47,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="vrNKKeFq",n=27,h5="82830aed",h6="cad5b537",h11="09d8bef4",f5="N9x5u6Zj",f6="kxpUORmS",f11="QV5FvHIL"},
{t="aACY7h0e",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ACKHl9Xm",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="yK3X1Mh2",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="xbKbp8F4",n=24,h5="67526982",h6="31182caf",h11="c20428c6",f5="h76pxW38",f6="1e0RO6az",f11="YPS57cC4"},
{t="aYQGmjlX",n=20,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="De7tagkk",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="NmJstHF0",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="mVRZuV4X",n=19,h5="2d27198c",h6="3ccffa7f",h11="d7a5d63e",f5="T8Mr110g",f6="kUTNXZFj",f11="BLKY2IrV"},
{t="DkIBk3pW",n=12,h5="4a893e74",h6="c336a25c",h11="31f86165",f5="MDEpeNtZ",f6="E27zoa7X",f11="o2PUBIn9"},
{t="M2yoGCO3",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="AR62F1rI",n=22,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="4L2lAhHw",n=19,h5="09d8bef4",h6="6f3ab277",h11="ec64918b",f5="QV5FvHIL",f6="sC8CWlnR",f11="B9h6f9a4"},
{t="5HAXCmRy",n=24,h5="0565f571",h6="169d5ed7",h11="ec64918b",f5="iveGBMZF",f6="E9ARXHkz",f11="B9h6f9a4"},
{t="6ykLNGcD",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="LEbinxaq",n=39,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="zpVUjezE",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="lHL7eIoX",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="7U34wVsx",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="tmAFBgfS",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="rpZ2bCDz",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="W16lvntr",n=82,h5="83a70c01",h6="4f4d9f0d",h11="9bbb856e",f5="mpIxakPJ",f6="byRCOpAI",f11="HKp0lyah"},
{t="c7WEVAvf",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="R9u6Lz7a",n=22,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="DC4hjnLa",n=28,h5="09d8bef4",h6="078c5d3b",h11="d7a5d63e",f5="QV5FvHIL",f6="CQSBbdGK",f11="BLKY2IrV"},
{t="LbxcDJPg",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="MU4c5HHY",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="hsBS26F5",n=24,h5="67526982",h6="31182caf",h11="c20428c6",f5="h76pxW38",f6="1e0RO6az",f11="YPS57cC4"},
{t="6PbNW0d8",n=20,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="fZwFCDKT",n=17,h5="ec64918b",h6="d7a5d63e",h11="9d5d6cc7",f5="B9h6f9a4",f6="BLKY2IrV",f11="SiDCvled"},
{t="W4aoiPNm",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="SSvLXkYU",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="84ufSRap",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="kR8Wt84A",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="W39LbrUR",n=33,h5="09d8bef4",h6="078c5d3b",h11="d7a5d63e",f5="QV5FvHIL",f6="CQSBbdGK",f11="BLKY2IrV"},
{t="Z6VzY3yJ",n=42,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="Nf7cYA1Q",n=22,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="qciZDjGk",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="nNDrtLKN",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="aKXpM4z0",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="t9sxjuv8",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="DLL9rgyD",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="WIQvpJQb",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="901qiB7F",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="c7Zd0uXW",n=25,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="JxYAip3r",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="cEitkNtE",n=84,h5="83a70c01",h6="4f4d9f0d",h11="a1659a75",f5="mpIxakPJ",f6="byRCOpAI",f11="mXjKo3Oi"},
{t="SH3YTx0S",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="KzjuB86r",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="mzohJST2",n=11,h5="4cbcc2a2",h6="7030c54e",h11="3132608f",f5="pZboIHGF",f6="JCFA8O9q",f11="iTzoRYlr"},
{t="6kbD51Xx",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="jgnfGqrg",n=12,h5="d7a5d63e",h6="4a893e74",h11="4cbcc2a2",f5="BLKY2IrV",f6="MDEpeNtZ",f11="pZboIHGF"},
{t="kZQHPWOx",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="S8pAsI7Y",n=29,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ac2aYKwB",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="cvjBs8Wv",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="WNTBCq6O",n=19,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="PtE5eSAN",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="hth6MYPf",n=12,h5="d7a5d63e",h6="4a893e74",h11="4cbcc2a2",f5="BLKY2IrV",f6="MDEpeNtZ",f11="pZboIHGF"},
{t="MNoIdfUn",n=22,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="SItHVcrp",n=12,h5="31f86165",h6="09d8bef4",h11="d7a5d63e",f5="o2PUBIn9",f6="QV5FvHIL",f11="BLKY2IrV"},
{t="Y76HdQm1",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="qId6jM4R",n=43,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="CM1rGKnH",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="8Fod6jU1",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="EgVBinkV",n=42,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="MvmBshOn",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="PEqirql6",n=86,h5="83a70c01",h6="4f4d9f0d",h11="40ac6a69",f5="mpIxakPJ",f6="byRCOpAI",f11="cT4XMaZr"},
{t="DZ2VbIUK",n=46,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="1qrBea82",n=12,h5="4a893e74",h6="49c250a6",h11="4cbcc2a2",f5="MDEpeNtZ",f6="fmBtb1Dh",f11="pZboIHGF"},
{t="ou6xcKpr",n=37,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="OOeBKS07",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="fp1DwXPR",n=22,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="DklquRRt",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="8YG2we6r",n=21,h5="d7a5d63e",h6="4a893e74",h11="ac08fe53",f5="BLKY2IrV",f6="MDEpeNtZ",f11="uIrWoowi"},
{t="dvQBs8Il",n=23,h5="95c46304",h6="cd889dbc",h11="9611c029",f5="9WAL35qM",f6="L8h7VinJ",f11="VTNrxYhK"},
{t="IYWgKQf0",n=12,h5="4a893e74",h6="c336a25c",h11="31f86165",f5="MDEpeNtZ",f6="E27zoa7X",f11="o2PUBIn9"},
{t="LLeLDaOH",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ZOJBgY50",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="V7AINQtp",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="jSz7RdwQ",n=12,h5="ec64918b",h6="d7a5d63e",h11="31f86165",f5="B9h6f9a4",f6="BLKY2IrV",f11="o2PUBIn9"},
{t="Ea5lP5yv",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="EUZPM0P8",n=12,h5="d7a5d63e",h6="4a893e74",h11="4cbcc2a2",f5="BLKY2IrV",f6="MDEpeNtZ",f11="pZboIHGF"},
{t="iaykIw21",n=29,h5="60e13e87",h6="3132608f",h11="c336a25c",f5="NSybVjZW",f6="iTzoRYlr",f11="E27zoa7X"},
{t="Nm0TQY3i",n=12,h5="4a893e74",h6="c336a25c",h11="31f86165",f5="MDEpeNtZ",f6="E27zoa7X",f11="o2PUBIn9"},
{t="BNCyayV7",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="Z5YGpNGQ",n=12,h5="ec64918b",h6="d7a5d63e",h11="31f86165",f5="B9h6f9a4",f6="BLKY2IrV",f11="o2PUBIn9"},
{t="pdMG3nWj",n=23,h5="169d5ed7",h6="82830aed",h11="3132608f",f5="E9ARXHkz",f6="N9x5u6Zj",f11="iTzoRYlr"},
{t="MxiDo2VG",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="fvXnCLeO",n=37,h5="3ccffa7f",h6="d22b948c",h11="b897e2d8",f5="kUTNXZFj",f6="Mi1ttQ1V",f11="RQzW9tCw"},
{t="iBpMg1n2",n=82,h5="83a70c01",h6="4f4d9f0d",h11="ead4dd3f",f5="mpIxakPJ",f6="byRCOpAI",f11="gI7pAcYS"},
{t="kXGcIuIi",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="U2vlVWku",n=21,h5="b6347304",h6="95c46304",h11="c336a25c",f5="PDOsp7Rj",f6="9WAL35qM",f11="E27zoa7X"},
{t="IzGAzB11",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="BJDSwjuN",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="SoLWJ5Lg",n=86,h5="83a70c01",h6="4f4d9f0d",h11="40ac6a69",f5="mpIxakPJ",f6="byRCOpAI",f11="cT4XMaZr"},
{t="13NWb9b4",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="g18jjLob",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="qCrez3w1",n=87,h5="83a70c01",h6="4f4d9f0d",h11="7f6b358d",f5="mpIxakPJ",f6="byRCOpAI",f11="pIwOlUyg"},
{t="6hg2aAnG",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ipJX9Wyx",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="vbcZUKZk",n=11,h5="4cbcc2a2",h6="7030c54e",h11="3132608f",f5="pZboIHGF",f6="JCFA8O9q",f11="iTzoRYlr"},
{t="jTj5zCzv",n=18,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="OyPvwHVR",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="mfF0o0Gm",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="8hg8HAw6",n=20,h5="2d27198c",h6="6f3ab277",h11="4a893e74",f5="T8Mr110g",f6="sC8CWlnR",f11="MDEpeNtZ"},
{t="V92yZqGg",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="bsBMuIVZ",n=30,h5="95c46304",h6="cd889dbc",h11="9611c029",f5="9WAL35qM",f6="L8h7VinJ",f11="VTNrxYhK"},
{t="TmOKDKTK",n=19,h5="2d27198c",h6="3ccffa7f",h11="d7a5d63e",f5="T8Mr110g",f6="kUTNXZFj",f11="BLKY2IrV"},
{t="6dWX1t6T",n=35,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="giUpqlCN",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="eJk59LKi",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="82mm3kqJ",n=18,h5="67526982",h6="31182caf",h11="c20428c6",f5="h76pxW38",f6="1e0RO6az",f11="YPS57cC4"},
{t="uUQY4v8C",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="1Agpa5Go",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="a8VdruCJ",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="3JyWPMmp",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="RdHwBIxp",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="9P3hwtQV",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="fECZdbQv",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="JSy55q4b",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="JhJKzgIx",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="jGPtSa4Q",n=38,h5="3ccffa7f",h6="d22b948c",h11="b897e2d8",f5="kUTNXZFj",f6="Mi1ttQ1V",f11="RQzW9tCw"},
{t="IiVHF36Q",n=38,h5="3ccffa7f",h6="d22b948c",h11="b897e2d8",f5="kUTNXZFj",f6="Mi1ttQ1V",f11="RQzW9tCw"},
{t="0y7l0QeN",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="XZfcNh3y",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="rtrfrywL",n=82,h5="83a70c01",h6="4f4d9f0d",h11="9bbb856e",f5="mpIxakPJ",f6="byRCOpAI",f11="HKp0lyah"},
{t="t55cYrRU",n=42,h5="b897e2d8",h6="a1659a75",h11="9a9b14c4",f5="RQzW9tCw",f6="mXjKo3Oi",f11="ubzsdeZ9"},
{t="E7hdT1gf",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="CqC6onVU",n=23,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="Q8WPyCgN",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="37v4RANg",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="ZJ1b9Ahf",n=12,h5="4a893e74",h6="c336a25c",h11="31f86165",f5="MDEpeNtZ",f6="E27zoa7X",f11="o2PUBIn9"},
{t="RrqbQpz4",n=17,h5="4a893e74",h6="95c46304",h11="49c250a6",f5="MDEpeNtZ",f6="9WAL35qM",f11="fmBtb1Dh"},
{t="FlxCS9q5",n=29,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="pJtqnoTt",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="4bJq0jZR",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="sPQLfFt2",n=35,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="K9PDApjZ",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="59vM5uM3",n=87,h5="83a70c01",h6="4f4d9f0d",h11="7f6b358d",f5="mpIxakPJ",f6="byRCOpAI",f11="pIwOlUyg"},
{t="BD5QAD3e",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="XGR2nJo4",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="g6BcKTn2",n=34,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="oEM5Garr",n=12,h5="ec64918b",h6="d7a5d63e",h11="31f86165",f5="B9h6f9a4",f6="BLKY2IrV",f11="o2PUBIn9"},
{t="6ugE3vNs",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="nM6fk00C",n=22,h5="ec64918b",h6="d7a5d63e",h11="6f3ab277",f5="B9h6f9a4",f6="BLKY2IrV",f11="sC8CWlnR"},
{t="Imd1bdSH",n=11,h5="31f86165",h6="09d8bef4",h11="3132608f",f5="o2PUBIn9",f6="QV5FvHIL",f11="iTzoRYlr"},
{t="J4StVAdF",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="lkakIMiW",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="gEWqNbKK",n=27,h5="82830aed",h6="cad5b537",h11="09d8bef4",f5="N9x5u6Zj",f6="kxpUORmS",f11="QV5FvHIL"},
{t="UPciGtwi",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="DSABFuE0",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="1d8UAM8X",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="E44mEnzI",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="yo5XZ75S",n=37,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="k6sOS9E1",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="FzLfCXXL",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="l9182Xsq",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="Ya7auduJ",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="nkAn6ag9",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="Pr77BrvV",n=39,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="JmVdNJdW",n=15,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="rYIyZPzu",n=27,h5="49c250a6",h6="31f86165",h11="9d5d6cc7",f5="fmBtb1Dh",f6="o2PUBIn9",f11="SiDCvled"},
{t="L3nSxTaG",n=22,h5="ec64918b",h6="d7a5d63e",h11="6f3ab277",f5="B9h6f9a4",f6="BLKY2IrV",f11="sC8CWlnR"},
{t="6nCDJIIO",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="r9NkfOBC",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="uy0hfBmC",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="HvWv6fVc",n=15,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="zFFmTqVX",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="Ezb6IXvp",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="9WL7Rliv",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="CXpgv7AO",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="DO8EsVax",n=46,h5="268ac291",h6="0fab729a",h11="5ac80a00",f5="gNCU4IFV",f6="uf4MVqY8",f11="LYy5JbEb"},
{t="GsZftK5s",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="MIWyUoSq",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="A69xyHpk",n=15,h5="31f86165",h6="09d8bef4",h11="cd889dbc",f5="o2PUBIn9",f6="QV5FvHIL",f11="L8h7VinJ"},
{t="QoHgU161",n=33,h5="9611c029",h6="cc0b45e5",h11="b6347304",f5="VTNrxYhK",f6="eRW24wJv",f11="PDOsp7Rj"},
{t="AYtHsvgZ",n=87,h5="83a70c01",h6="4f4d9f0d",h11="7f6b358d",f5="mpIxakPJ",f6="byRCOpAI",f11="pIwOlUyg"},
{t="VIf1E2DR",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="XDeQy9oE",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="JKUKBAef",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="A2xzKGnq",n=39,h5="8bbeb160",h6="9a9b14c4",h11="09d8bef4",f5="h7m5n4Mf",f6="ubzsdeZ9",f11="QV5FvHIL"},
{t="ADbtkO2h",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="KYIz3wOe",n=32,h5="9611c029",h6="cc0b45e5",h11="b6347304",f5="VTNrxYhK",f6="eRW24wJv",f11="PDOsp7Rj"},
{t="iQ6EoFmm",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="PnuEPlQR",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="p8Pbgujj",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="zdmjNbiG",n=27,h5="49c250a6",h6="31f86165",h11="9d5d6cc7",f5="fmBtb1Dh",f6="o2PUBIn9",f11="SiDCvled"},
{t="ylnZPCUn",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="yIRNiJvL",n=19,h5="2d27198c",h6="3ccffa7f",h11="d7a5d63e",f5="T8Mr110g",f6="kUTNXZFj",f11="BLKY2IrV"},
{t="y9mcMPJg",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="D7JCO2Mf",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="o2akuixy",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="VSWTQQFi",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="qD9SMFSs",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="wkARpI1b",n=46,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="QTy2ToLH",n=12,h5="ec64918b",h6="d7a5d63e",h11="31f86165",f5="B9h6f9a4",f6="BLKY2IrV",f11="o2PUBIn9"},
{t="4vbuOeX6",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="xQExJF3F",n=11,h5="4cbcc2a2",h6="7030c54e",h11="3132608f",f5="pZboIHGF",f6="JCFA8O9q",f11="iTzoRYlr"},
{t="yK9rsnyk",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="U4dhYSWp",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="GBOzTDQv",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="zxLvnAU1",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="loNSFG2W",n=15,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="5q80wl2C",n=19,h5="d7a5d63e",h6="4a893e74",h11="4cbcc2a2",f5="BLKY2IrV",f6="MDEpeNtZ",f11="pZboIHGF"},
{t="yMuXzxfg",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="TvBHuMki",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="TEDfNjpT",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="BxrSiZJs",n=42,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="Um3MMe4L",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="nqHKoKUy",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ZRQCfaLJ",n=12,h5="4a893e74",h6="c336a25c",h11="31f86165",f5="MDEpeNtZ",f6="E27zoa7X",f11="o2PUBIn9"},
{t="M9lKJpkm",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="PuouxBx0",n=28,h5="82830aed",h6="cad5b537",h11="09d8bef4",f5="N9x5u6Zj",f6="kxpUORmS",f11="QV5FvHIL"},
{t="bw4G9tXw",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="M86b4LWW",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="6qEARSB5",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="YXCAELoC",n=34,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="D33t4Yq4",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="wlrNDnp6",n=27,h5="0565f571",h6="169d5ed7",h11="9a34c336",f5="iveGBMZF",f6="E9ARXHkz",f11="jCr15Dyv"},
{t="CZrBoIsc",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="33tTKuBx",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="ShYEl3p4",n=41,h5="a4c332a8",h6="9bbb856e",h11="e0a79052",f5="NETPpspy",f6="HKp0lyah",f11="4Chz2o0P"},
{t="cG7oY0ES",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="1WInU5zi",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="bkw6pFy9",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="bTJUrtuo",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="GrRkjKnK",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="mVdLxCvC",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="wSiN4FfF",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="2UaFstb9",n=21,h5="d7a5d63e",h6="4a893e74",h11="c336a25c",f5="BLKY2IrV",f6="MDEpeNtZ",f11="E27zoa7X"},
{t="oYrsgCxu",n=11,h5="49c250a6",h6="31f86165",h11="3132608f",f5="fmBtb1Dh",f6="o2PUBIn9",f11="iTzoRYlr"},
{t="1y3kV2RF",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="o3mPP8Yy",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="OUSpKVon",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="7E9RrAfA",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="JgyQjtSu",n=32,h5="9611c029",h6="cc0b45e5",h11="b6347304",f5="VTNrxYhK",f6="eRW24wJv",f11="PDOsp7Rj"},
{t="xvcR94QE",n=25,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="0XdGDIMr",n=29,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="Wxqxtfmp",n=92,h5="83a70c01",h6="4f4d9f0d",h11="b897e2d8",f5="mpIxakPJ",f6="byRCOpAI",f11="RQzW9tCw"},
{t="f0QhhXWF",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="FKuPsook",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="HXKv5Hto",n=29,h5="95c46304",h6="cd889dbc",h11="9611c029",f5="9WAL35qM",f6="L8h7VinJ",f11="VTNrxYhK"},
{t="6JJ2KEcW",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="PLWpyKhh",n=27,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="pihpFLlF",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"},
{t="O1utWERF",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="odBQRXe0",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="HlvPmSLK",n=29,h5="95c46304",h6="cd889dbc",h11="9611c029",f5="9WAL35qM",f6="L8h7VinJ",f11="VTNrxYhK"},
{t="HvmWGMdc",n=20,h5="4a893e74",h6="c336a25c",h11="60e13e87",f5="MDEpeNtZ",f6="E27zoa7X",f11="NSybVjZW"},
{t="onA35xQx",n=34,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="TxZKD7Jt",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="E8PdVbxY",n=98,h5="ea04d444",h6="d92082f9",h11="ec64918b",f5="9XOL6IVs",f6="qXzao97y",f11="B9h6f9a4"},
{t="ykO3xi59",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="ETvIjb00",n=39,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="vamGR36I",n=19,h5="2d27198c",h6="3ccffa7f",h11="d7a5d63e",f5="T8Mr110g",f6="kUTNXZFj",f11="BLKY2IrV"},
{t="z2t7zI8M",n=46,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="m8zZJCiw",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="bb14Em9T",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="dWMgnjBO",n=11,h5="4cbcc2a2",h6="7030c54e",h11="3132608f",f5="pZboIHGF",f6="JCFA8O9q",f11="iTzoRYlr"},
{t="OdO9IpMd",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="niOqavRX",n=41,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="BI234Nln",n=24,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="BEZhAo5V",n=32,h5="49c250a6",h6="31f86165",h11="9d5d6cc7",f5="fmBtb1Dh",f6="o2PUBIn9",f11="SiDCvled"},
{t="wWaJYoCx",n=31,h5="d8320b91",h6="364ba71a",h11="c336a25c",f5="yOziMCUW",f6="Vgr3qvXE",f11="E27zoa7X"},
{t="KQ4dnvxo",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="DngqTgmg",n=45,h5="82830aed",h6="cad5b537",h11="c336a25c",f5="N9x5u6Zj",f6="kxpUORmS",f11="E27zoa7X"},
{t="wNGBrVCG",n=21,h5="ec64918b",h6="d7a5d63e",h11="4cbcc2a2",f5="B9h6f9a4",f6="BLKY2IrV",f11="pZboIHGF"},
{t="rHVbvgIu",n=27,h5="ec64918b",h6="d7a5d63e",h11="9611c029",f5="B9h6f9a4",f6="BLKY2IrV",f11="VTNrxYhK"},
{t="fYPmjvKj",n=44,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="8Xb1bA4q",n=20,h5="49c250a6",h6="31f86165",h11="82830aed",f5="fmBtb1Dh",f6="o2PUBIn9",f11="N9x5u6Zj"},
{t="dpTn49Ym",n=11,h5="4a893e74",h6="c336a25c",h11="3ccffa7f",f5="MDEpeNtZ",f6="E27zoa7X",f11="kUTNXZFj"},
{t="iLpqaa4Q",n=12,h5="ec64918b",h6="d7a5d63e",h11="31f86165",f5="B9h6f9a4",f6="BLKY2IrV",f11="o2PUBIn9"},
{t="DR0qy4Oq",n=12,h5="4a893e74",h6="c336a25c",h11="4cbcc2a2",f5="MDEpeNtZ",f6="E27zoa7X",f11="pZboIHGF"},
{t="lD4ajClR",n=46,h5="e725d2d1",h6="83a70c01",h11="a1659a75",f5="LpvOeetG",f6="mpIxakPJ",f11="mXjKo3Oi"},
{t="GRdesBBX",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="incUXe4M",n=35,h5="e9bb563f",h6="09c56a96",h11="d7a5d63e",f5="xRhGae3u",f6="IIq9LOZH",f11="BLKY2IrV"},
{t="txXYboZT",n=28,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="1U4RO9x9",n=82,h5="83a70c01",h6="4f4d9f0d",h11="9bbb856e",f5="mpIxakPJ",f6="byRCOpAI",f11="HKp0lyah"},
{t="nv3XEPTG",n=35,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="CYpr25ch",n=82,h5="83a70c01",h6="4f4d9f0d",h11="9bbb856e",f5="mpIxakPJ",f6="byRCOpAI",f11="HKp0lyah"},
{t="syr4tkzd",n=12,h5="4cbcc2a2",h6="7030c54e",h11="d7a5d63e",f5="pZboIHGF",f6="JCFA8O9q",f11="BLKY2IrV"},
{t="BJ8HSBj6",n=26,h5="98b4aaf0",h6="c336a25c",h11="31f86165",f5="eohDtPWr",f6="E27zoa7X",f11="o2PUBIn9"},
{t="iuhtfy7R",n=13,h5="4a893e74",h6="8bbeb160",h11="31f86165",f5="MDEpeNtZ",f6="h7m5n4Mf",f11="o2PUBIn9"}
}
local MAIN_PREFERRED
for i,p in ipairs(MAIN_CANDIDATES) do
 if p.t==MAIN_BIND_TYPE then MAIN_PREFERRED=p;table.remove(MAIN_CANDIDATES,i);table.insert(MAIN_CANDIDATES,1,p);break end
end
local main_profile_session=nil
local known_main_profiles={}
local function hash_of_field(d)
 local h=type(d)=='table' and type(d.id)=='string' and d.id:lower():gsub('^0x','') or ''
 if #h<8 then h=string.rep('0',8-#h)..h end
 return h
end
local function main_schema_ok(p)
 if p.schema_session~=main_profile_session then p.schema_session=main_profile_session;p.schema_ok=nil;p.schema_retry=0 end
 if p.schema_ok==true or (p.schema_ok==false and M.clock<(p.schema_retry or 0)) then return p.schema_ok end
 p.schema_retry=M.clock+5
 p.schema_ok=false
 local info=call(Net.object_info,p.t)
 local fs=type(info)=='table' and info.fields
 if type(fs)=='table' and #fs==p.n then
  p.schema_ok=hash_of_field(fs[5])==p.h5 and hash_of_field(fs[6])==p.h6 and hash_of_field(fs[11])==p.h11
 end
 log('MAIN_SCHEMA type='..p.t..' ok='..tostring(p.schema_ok)..' count='..tostring(type(fs)=='table' and #fs or -1))
 return p.schema_ok
end
local function reset_main_profiles_for_session(session)
 if main_profile_session~=session then main_profile_session=session;known_main_profiles={} end
end
local function known_main_profile(session,mid)
 reset_main_profiles_for_session(session)
 for _,p in ipairs(known_main_profiles) do
  if call(GS.game_object_is_type,session,mid,p.t)==true and main_schema_ok(p) then return p end
 end
 return nil
end
local function discover_main_profile(session,mid,c)
 reset_main_profiles_for_session(session)
 if not valid_goid(session,mid) then return nil end
 if MAIN_PREFERRED and call(GS.game_object_is_type,session,mid,MAIN_BIND_TYPE)==true then
  if main_schema_ok(MAIN_PREFERRED) then c.main_profile=MAIN_PREFERRED;c.main_scan_done=true;return MAIN_PREFERRED end
  return nil
 end
 if c.main_scan_done then
  if M.clock<(c.main_retry or 0) then return nil end
  c.main_scan_done=false;c.main_scan_index=1;c.main_retry=M.clock+5
 end
 if c.main_profile and call(GS.game_object_is_type,session,mid,c.main_profile.t)==true and main_schema_ok(c.main_profile) then return c.main_profile end
 local known=known_main_profile(session,mid)
 if known then c.main_profile=known;c.main_scan_done=true;return known end
 local i=c.main_scan_index or 1
 -- Once one fallback batch reveals the dense field count, rows with other counts
 -- are skipped in Lua. At most one native type comparison is made per frame.
 while true do
  local p=MAIN_CANDIDATES[i]
  if not p then c.main_scan_done=true;c.main_retry=M.clock+5;log('MAIN_PROFILE_NO_MATCH goid='..tostring(mid)..' count='..tostring(c.main_observed_count));return nil end
  i=i+1;c.main_scan_index=i
  if c.main_observed_count==nil or p.n==c.main_observed_count then
   if call(GS.game_object_is_type,session,mid,p.t)==true then
    c.main_scan_done=true;c.main_retry=M.clock+5
    if main_schema_ok(p) then
     c.main_profile=p;known_main_profiles[#known_main_profiles+1]=p
     log('MAIN_PROFILE_MATCH goid='..tostring(mid)..' type='..p.t..' fields='..p.h5..','..p.h6..','..p.h11)
     return p
    end
    log('MAIN_PROFILE_SCHEMA_REJECT goid='..tostring(mid)..' type='..p.t)
   end
   return nil
  end
 end
end
local function bit01(v)
 if v==true then return 1 elseif v==false then return 0 elseif integer(v,1) then return v end
 return nil
end
local function dense_count(t)
 if type(t)~='table' then return nil end
 local n=0
 for k,v in pairs(t) do if type(k)=='number' and k==math.floor(k) and k>n then n=k end end
 return n>=11 and n or nil
end
local function read_main(session,mid,c)
 local p=c.main_profile
 if not p then p=discover_main_profile(session,mid,c) end
 local targeted=p and call(GS.game_object_is_type,session,mid,p.t)==true and main_schema_ok(p) and type(GS.game_object_field)=='function'
 local a,b,total
 if targeted then
  if call(GS.game_object_exists,session,mid)~=true then return end
  a=call(GS.game_object_field,session,mid,p.f5)
  b=call(GS.game_object_field,session,mid,p.f6)
  local b1=bit01(b)
  -- Bastion main gun is 30 in magazine + 1 chambered = 31 total.
  -- Field #11 remains part of declaration identity, but is not ammunition.
  if integer(a,30) and b1~=nil then
   local t=a+b1
   if integer(t,31) then total=t end
  end
 elseif call(GS.game_object_is_type,session,mid,MAIN_BIND_TYPE)==true then
  local mf=sample(session,mid)
  local observed=dense_count(mf)
  if observed and c.main_observed_count==nil then
   c.main_observed_count=observed
   log('MAIN_BATCH_SHAPE goid='..tostring(mid)..' count='..tostring(observed))
  end
  if main_sig(mf) then
   local t=mf[5]+mf[6]
   if integer(t,31) then total=t end
  end
 end
 local mode=targeted and 'targeted' or 'batch'
 local diag=c.main_diag
 if not diag or diag.mode~=mode then
  diag={mode=mode,start=M.clock,attempts=0,valid=0,changed=0};c.main_diag=diag
  log('MAIN_PATH goid='..tostring(mid)..' mode='..mode)
 end
 diag.attempts=diag.attempts+1
 if total~=nil then
  diag.valid=diag.valid+1
  if c.ammo~=nil and total~=c.ammo then diag.changed=diag.changed+1 end
  c.ammo=total;c.main_seen=true;c.main_valid_at=M.clock
 end
 if M.clock-diag.start>=10 then
  log('MAIN_READ goid='..tostring(mid)..' mode='..mode..' seconds='..string.format('%.1f',M.clock-diag.start)..' attempts='..diag.attempts..' valid='..diag.valid..' changed='..diag.changed..' ammo='..tostring(c.ammo))
  diag.start=M.clock;diag.attempts=0;diag.valid=0;diag.changed=0
 end
end

local function refresh_bound(session,owned_set)
 local hid=M.hull;if not hid then return end
 local c=cache_for(hid);local now=M.clock
 if call(GS.game_object_exists,session,hid)~=true then
  log('BASTION_LOST hull='..hid);M.hull=nil;M.cache={};clear_values();return
 end
 local function due(key,interval)
  if now<(c[key] or 0) then return false end
  c[key]=now+interval;return true
 end
 if due('next_hull',0.1) then
  local hf=sample(session,hid)
  if hull_sig(hf) then
   c.hp=hf[30];c.max=hf[15];c.hull_valid_at=now;remember_hull(hid,hf)
   if due('next_weapon_resolve',1) then resolve_bound_weapon_ids(session,hid,hf,c) end
  end
 end
 if now-(c.hull_valid_at or c.bound_at or now)>3 then
  log('BASTION_STALE hull='..hid);M.hull=nil;M.cache={};clear_values();return
 end
 local mid,cid=c.main_id,c.coax_id
 if due('next_main',0.1) and valid_goid(session,mid) then read_main(session,mid,c) end
 if due('next_coax',0.1) and valid_goid(session,cid) then read_coax(session,cid,c) end
 if c.main_valid_at and now-c.main_valid_at>3 then
  if c.ammo~=nil then log('MAIN_STALE goid='..tostring(mid)) end
  c.ammo=nil;c.next_weapon_resolve=0;c.main_profile=nil;c.main_scan_done=nil
 end
 if c.coax_valid_at and now-c.coax_valid_at>3 then
  if c.mg~=nil then log('COAX_STALE goid='..tostring(cid)) end
  c.mg=nil;c.next_weapon_resolve=0
 end
 M.hp,M.max,M.ammo,M.mg=c.hp,c.max,c.ammo,c.mg
end

-- Version-scoped, identity-keyed readers. Only the Win32 adapter reads memory.
-- Pure Lua byte decoding avoids rounding uint64 resource IDs through doubles.
local Native = (function()
 local N={version='r3-cc75948d',ready=false,next_check=0}
 N.roots={network=0x276F0C0,health=0x276C3B8,synced=0x276C9B0,seater=0x276CA88}
 N.pe={machine=0x8664,sections=16,timestamp=0x6A86132E,size=0x3A6B000,checksum=0xEE0D37}
 local function u32(s,o)
  local a,b,c,d=s:byte(o+1,o+4)
  if not d then error('short uint32',0) end
  return a+b*256+c*65536+d*16777216
 end
 local function i32(s,o) local v=u32(s,o);return v>=2147483648 and v-4294967296 or v end
 local function hex64(s,o) return string.format('%08x%08x',u32(s,o+4),u32(s,o)) end
 local function ptr(s,o)
  local lo,hi=u32(s,o),u32(s,o+4)
  if hi>=32768 then error('noncanonical pointer',0) end
  return hi*4294967296+lo
 end
 local function addr(p,n)
  if type(p)~='number' or p~=math.floor(p) or p<65536 or p>=140737488355328
   or type(n)~='number' or n<1 or n>4096 or n~=math.floor(n) or p+n>140737488355328 then error('read bounds',0) end
 end
 local function mul32(a,b)
  local al,ah=a%65536,math.floor(a/65536)
  local bl,bh=b%65536,math.floor(b/65536)
  return (al*bl+((ah*bl+al*bh)%65536)*65536)%4294967296
 end
 local function mod64hex(h,n)
  local hi,lo=tonumber(h:sub(1,8),16),tonumber(h:sub(9,16),16)
  return ((hi%n)*(4294967296%n)+lo%n)%n
 end
 N.u32=u32;N.i32=i32;N.hex64=hex64;N.ptr=ptr;N.mul32=mul32;N.mod64hex=mod64hex
 function N.q4(word)
  local out={};for i=0,3 do out[i+1]=math.floor(word/4^i)%4 end;return out
 end
 local G={};G.__index=G
 function N.graph(read,base)
  return setmetatable({raw=read,base=base,calls=0,bytes=0,watches={},seen={}},G)
 end
 function G:read(p,n)
  addr(p,n)
  if self.calls>=960 or self.bytes+n>65536 then error('native sample budget',0) end
  self.calls=self.calls+1;self.bytes=self.bytes+n
  local b=self.raw(p,n)
  if type(b)~='string' or #b~=n then error('incomplete native read',0) end
  return b
 end
 function G:watch(p,n)
  local key=string.format('%.0f:%d',p,n);local old=self.seen[key]
  if old then return old end
  local b=self:read(p,n);self.seen[key]=b;self.watches[#self.watches+1]={p,n,b};return b
 end
 function G:validate()
  for _,w in ipairs(self.watches) do if self:read(w[1],w[2])~=w[3] then error('identity changed during sample',0) end end
 end
 function G:root(name)
  local p=ptr(self:watch(self.base+N.roots[name],8),0)
  if p==0 then error(name..' manager not ready',0) end
  addr(p,1);return p
 end
 function G:table(p)
  local b=self:watch(p,20);local cap=u32(b,8)
  if cap>1048576 or (cap>0 and 2^math.floor(math.log(cap)/math.log(2)+0.5)~=cap) then error('invalid table capacity',0) end
  local t={p=p,entries=ptr(b,0),capacity=cap,empty=u32(b,12),multiplier=u32(b,16)}
  if cap>0 then addr(t.entries,1) end;return t
 end
 function G:lookup(t,key)
  if type(key)~='number' or key<0 or key>4294967295 or key~=math.floor(key) then error('invalid identity key',0) end
  if key==t.empty or t.capacity==0 then return nil end
  local first=mul32(key,t.multiplier)%t.capacity
  for step=0,math.min(t.capacity,64)-1 do
   local b=self:watch(t.entries+((first+step)%t.capacity)*8,8)
   local k,j=u32(b,0),u32(b,4)
   if k==key then
    if j==4294967295 then return nil end
    if j>=1048576 then error('invalid dense index',0) end
    return j
   end
   if k==t.empty then return nil end
  end
  error('identity lookup probe limit',0)
 end
 function G:descriptor(p)
  local b=self:watch(p,24)
  return {address=p,resource=hex64(b,0),entity=u32(b,8),unit=u32(b,12),goid=u32(b,16),flags=u32(b,20)}
 end
 local function same(a,b)
  return a and b and a.entity==b.entity and a.goid==b.goid and a.resource==b.resource and a.unit==b.unit
 end
 N.same=same
 function G:net(root,key,by_entity)
  if key==4294967295 or (not by_entity and key==32767) then return nil end
  local j=self:lookup(self:table(root+(by_entity and 0xF19A70 or 0xF21A88)),key)
  if j==nil then return nil end
  local d=self:descriptor(root+0xF31AD8+j*24)
  if (by_entity and d.entity or d.goid)~=key then error('network key mismatch',0) end
  return d
 end
 function G:roundtrip(root,d)
  local f=self:net(root,d.entity,true);local b=f and self:net(root,f.goid,false)
  if not same(d,f) or not same(d,b) then error('network roundtrip mismatch',0) end
 end
 function G:component(manager,entity,to,dp)
  local j=self:lookup(self:table(manager+to),entity)
  if j==nil then return nil end
  local array=ptr(self:watch(manager+dp,8),0)
  local d=self:descriptor(ptr(self:watch(array+j*8,8),0))
  if d.entity~=entity then error('component owner mismatch',0) end
  return j,d
 end
 function G:relation(avatar_goid)
  local net,seater=self:root('network'),self:root('seater')
  local av=self:net(net,avatar_goid,false)
  if not av then error('avatar not in native network table',0) end
  self:roundtrip(net,av)
  local j,ad=self:component(seater,av.entity,0x20,0x38)
  if j==nil then self:validate();return {status='NO_SEATER'} end
  if not same(av,ad) then error('Seater avatar mismatch',0) end
  local base=ptr(self:watch(seater+0x48,8),0)
  local e=u32(self:watch(base+j*0x40,4),0)
  if e==0 or e==4294967295 then self:validate();return {status='EMPTY'} end
  local d=self:net(net,e,true)
  if not d or d.goid<=0 or d.goid>=32767 then error('collection not network-linked',0) end
  self:roundtrip(net,d)
  local role=i32(self:read(base+j*0x40+0x1C,4),0)
  self:validate()
  return {status='VEHICLE',vehicle=d,avatar=av,role=role}
 end
 -- Resolve a SeatCollection/proxy descriptor to a FRV Hull without spatial or GOID heuristics.
 -- The only accepted edge is an exact shared native unit key, a known FRV resource,
 -- a Health component and a unique candidate. Table enumeration is limited to the
 -- typed Health entity index; this is not a process/address-space scan.
 function G:frv_hull_for_proxy(collection,known_resources)
  if not collection or type(collection.unit)~='number' or collection.unit<=0 or collection.unit==4294967295 then
   return nil,{reason='proxy has no usable unit key'}
  end
  local net,hm=self:root('network'),self:root('health')
  local live=self:net(net,collection.entity,true)
  if not same(live,collection) then error('proxy identity changed before resolve',0) end
  self:roundtrip(net,live)
  local t=self:table(hm+0x28)
  if t.capacity==0 then return nil,{reason='Health table empty',capacity=0,entries=0,candidates=0} end
  if t.capacity>4096 then error('Health table too large for proxy resolver',0) end
  local bytes=t.capacity*8;local raw={};local off=0
  while off<bytes do
   local n=math.min(4096,bytes-off)
   raw[#raw+1]=self:watch(t.entries+off,n);off=off+n
  end
  raw=table.concat(raw)
  local descs=ptr(self:watch(hm+0x40,8),0)
  local entries,candidates=0,{}
  for pos=0,#raw-8,8 do
   local entity,j=u32(raw,pos),u32(raw,pos+4)
   if entity~=t.empty and j~=4294967295 then
    entries=entries+1
    if j>=1048576 then error('Health dense index outside safety bound',0) end
    local dp=ptr(self:watch(descs+j*8,8),0)
    local d=self:descriptor(dp)
    if d.entity~=entity then error('Health table/descriptor owner mismatch',0) end
    if d.unit==collection.unit and d.entity~=collection.entity and known_resources[d.resource] then
     self:roundtrip(net,d);candidates[#candidates+1]=d
    end
   end
  end
  local meta={reason='no exact same-unit FRV Health owner',unit=collection.unit,capacity=t.capacity,entries=entries,candidates=#candidates}
  if #candidates==1 then meta.reason='unique_same_unit_health';return candidates[1],meta end
  if #candidates>1 then meta.reason='ambiguous same-unit FRV Health owners' end
  self:validate();return nil,meta
 end
 function G:configuration(net,hm,d,expected_zones)
  local j=self:lookup(self:table(hm+0x68),d.entity);local cfg
  if j~=nil then cfg=ptr(self:watch(hm+0xA8,8),0)+j*0x5650
  else
   local t=ptr(self:watch(net+0xF11738,8),0)
   local start=mod64hex(d.resource,984)
   for step=0,63 do
    local b=self:watch(t+((start+step)%984)*16,16);local key=hex64(b,0)
    if key==d.resource then
     local k=u32(b,8);if k>=984 then error('Health settings index',0) end
     cfg=t+0x3D80+k*0x5650;break
    elseif key=='0000000000000000' then break end
   end
  end
  if not cfg then error('no identity-linked Health configuration',0) end
  local max={}
  for i=0,3 do
   local zone=cfg+0x208+i*0x228
   local name=string.format('%08x',u32(self:watch(zone+96,4),0))
   if name~=expected_zones[i+1] then error('wheel zone identity mismatch',0) end
   local mx=i32(self:read(zone+232,4),0)
   if mx<=0 or mx>1000000 then error('invalid wheel maximum',0) end
   max[i+1]=mx
  end
  return max
 end
 function G:health(d,expected_zones)
  local net,hm=self:root('network'),self:root('health')
  self:roundtrip(net,d)
  local hi,hd=self:component(hm,d.entity,0x28,0x40)
  if hi==nil or not same(hd,d) then error('no matching Health component',0) end
  local hpbase=ptr(self:watch(hm+0x50,8),0)
  local record=hpbase+hi*0x1B8
  local data=self:read(record,0x1B8)
  local max=self:configuration(net,hm,hd,expected_zones)
  local hp,hp_valid={},{}
  for i=0,3 do
   local v=i32(data,0xF8+4*i);hp[i+1]=v
   -- Runtime HP can briefly leave [0,max] around a damage transition.  This is
   -- a per-zone data-quality issue, not grounds to discard the other wheels.
   -- Keep the raw value for diagnostics and let the UI fall back to q2 for
   -- this wheel only.  Destroyed state still wins independently in wheel_model.
   hp_valid[i+1]=(v>=0 and v<=max[i+1])
  end
  local out={hp=hp,hp_valid=hp_valid,max=max,body=i32(data,0x14),damage=N.q4(u32(data,0x20)),
   state_low=u32(data,0x20),health_index=hi,health_record=record,flags=hd.flags,precision='UNKNOWN'}
  -- SyncedHealth is ancillary: its absence must not manufacture values or
  -- suppress a valid Health damage state. A complete snapshot still rechecks IDs.
  local sm=ptr(self:watch(self.base+N.roots.synced,8),0)
  if sm~=0 then
   local si,sd=self:component(sm,d.entity,0x20,0x38)
   if si~=nil then
    if not same(hd,sd) then error('SyncedHealth owner mismatch',0) end
    local array=ptr(self:watch(sm+0x40,8),0);local rep=ptr(self:watch(sm+0x50,8),0)
    local cache=self:read(array+si*0xC0,16);local word=u32(self:read(rep+si*16+4,4),0)
    out.q=N.q4(word);out.cache={};out.synced_flags=sd.flags
    for i=0,3 do out.cache[i+1]=i32(cache,4*i) end
    if hd.flags%2==1 and sd.flags%2==1 then out.precision='LOCAL_RUNTIME'
    else out.precision='QUANTIZED_OR_UNKNOWN' end
   end
  end
  self:validate();out.bytes=self.bytes;out.calls=self.calls
  return out
 end
 N.guards={{0xd3e734,"4c8b1d8509a301448bc24c8bc981faff7f000075108b055d8ea4018901488bc1"},{0x634244,"4c8b1d4d88130245896f1041c7471cffffffff41893f3b3d002a1502"},{0x9171b7,"488b4d408bd8488b0cd9e87ab6beff4869cbb8010000488b5c243048034d50488b6c243848056802000039307426ff"},{0x6aaae8,"8b81f80000004189028b81fc000000418942048b8100010000418942088b81040100004189420c"},{0x6ac968,"488d144048c1e20641ffd18b0b33d2488943404c8d0449488bc849c1e006e855ba72"},{0x6ab270,"478b4cb4048d4bfc448b97d8fdffff418bc1d3e80f57c983e003f3480f2ac8f30f5eca4183fa"}}
 function N.check_module(read,base)
  local b=read(base,512)
  if not b or #b~=512 or b:sub(1,2)~='MZ' then return false,'module header unreadable' end
  local off=u32(b,0x3C)
  if off<64 or off>4096 then return false,'module PE offset' end
  local p=read(base+off,112)
  if not p or #p~=112 or p:sub(1,4)~='PE\0\0' then return false,'module PE signature' end
  local machine=p:byte(5)+256*p:byte(6);local sections=p:byte(7)+256*p:byte(8)
  if machine~=N.pe.machine or sections~=N.pe.sections or u32(p,8)~=N.pe.timestamp
   or u32(p,80)~=N.pe.size or u32(p,88)~=N.pe.checksum then return false,'unsupported game.dll PE identity' end
  for _,v in ipairs(N.guards) do
   local want=v[2]:gsub('..',function(h)return string.char(tonumber(h,16))end)
   if read(base+v[1],#want)~=want then return false,string.format('native code guard 0x%X',v[1]) end
  end
  return true,'PE+6 reviewed code guards'
 end
 function N.open_win32()
  local ok,ffi=pcall(require,'ffi')
  if not ok or not ffi or ffi.os~='Windows' or not ffi.abi('64bit') then return nil,'LuaJIT FFI / Windows x64 unavailable' end
  -- No game native calls; all pointed-to bytes go through RPM into owned buffers.
  local declarations={
   'void * __stdcall GetCurrentProcess(void);',
   'void * __stdcall GetModuleHandleA(const char *);',
   'int __stdcall ReadProcessMemory(void *, const void *, void *, size_t, size_t *);',
   'size_t __stdcall VirtualQuery(const void *, void *, size_t);'}
  for _,s in ipairs(declarations) do pcall(ffi.cdef,s) end
  local loaded,k=pcall(ffi.load,'kernel32');if not loaded then return nil,'kernel32 unavailable' end
  local h=k.GetCurrentProcess();local buffer=ffi.new('uint8_t[4096]')
  local got=ffi.new('size_t[1]');local mbi=ffi.new('uint8_t[48]')
  local w={}
  function w.base()
   local p=k.GetModuleHandleA('game.dll')
   if p==nil then return nil end
   return tonumber(ffi.cast('uintptr_t',p))
  end
  function w.read(p,n)
   addr(p,n)
   local at,finish=p,p+n
   for _=1,4 do
    if at>=finish then break end
    local z=tonumber(k.VirtualQuery(ffi.cast('const void *',at),ffi.cast('void *',mbi),48))
    if z~=48 then return nil end
    local b=ffi.string(mbi,48);local start=ptr(b,0);local extent=ptr(b,24)
    local state,protection=u32(b,32),u32(b,36);local kind=protection%256
    if state~=4096 or math.floor(protection/256)%2==1
     or not (kind==2 or kind==4 or kind==8 or kind==32 or kind==64 or kind==128)
     or start>at or extent==0 or start+extent<=at then return nil end
    at=math.min(finish,start+extent)
   end
   if at<finish then return nil end
   got[0]=0
   local success=k.ReadProcessMemory(h,ffi.cast('const void *',p),buffer,n,got)
   if success==0 or tonumber(got[0])~=n then return nil end
   return ffi.string(buffer,n)
  end
  return w
 end
 function N.ensure(now)
  if N.disabled then return false,N.reason end
  if now<N.next_check then return N.ready,N.reason end
  N.next_check=now+10
  if not N.win then
   local ok,w,why=pcall(N.open_win32)
   if not ok or not w then N.disabled=true;N.reason=why or tostring(w);return false,N.reason end
   N.win=w
  end
  local base=N.win.base()
  if not base then N.ready=false;N.next_check=now+1;N.reason='game.dll not yet loaded';return false,N.reason end
  local ok,valid,why=pcall(N.check_module,N.win.read,base)
  if not ok or not valid then
   N.ready=false;N.reason=why or tostring(valid)
   -- Retry loaded-code checks slowly (initialization), never use failed offsets.
   N.next_check=now+10;return false,N.reason
  end
  N.ready=true;N.base=base;N.reason=why;return true
 end
 function N.relation(avatar,now)
  local valid,why=N.ensure(now)
  if not valid then return nil,why end
  local ok,result=pcall(function()return N.graph(N.win.read,N.base):relation(avatar)end)
  if ok then return result end;return nil,tostring(result)
 end
 function N.resolve_proxy(collection,known_resources)
  if not N.ready then return nil,'native version not validated' end
  local ok,result,meta=pcall(function()
   local g=N.graph(N.win.read,N.base)
   local d,m=g:frv_hull_for_proxy(collection,known_resources)
   g:validate();return d,m
  end)
  if ok then return result,meta end
  return nil,tostring(result)
 end
 function N.health(vehicle,zones)
  if not N.ready then return nil,'native version not validated' end
  local ok,result=pcall(function()return N.graph(N.win.read,N.base):health(vehicle,zones)end)
  if ok then return result end;return nil,tostring(result)
 end
 return N
end)()

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

-- The vehicle resolver owns identity. Health failure never invokes a second resolver.
FRV = {next_poll=0}
FRV.profiles={["cc21c7ffd3ebefb9"]={name="hmg_frv",t="MJAkcNku",fields={"50ac6619","a09ccd0a","b19ad128","d7082cbf","dab52fe8","0565f571","169d5ed7","82830aed","cad5b537","9ddf0683","95417727","a5f83fa0","9256767e","7f6b358d","788b9753","99901914","1dd07f05","39d141d6","98b4aaf0","e144c5e3","6fa852e3","6d2d83f8","7d9563dd","d8819b3e","cb0453ea","9d550ad3","bbecde19","8fd2d63e","c336a25c","af4c7e8a","0d4e190d","308e0842","0c0bd772","d9810f60","3b5a954f","6396946a","791943f0","91f98cec","7615f45d","eeb1225e","cca43d10","5a8871e3","e00857ad","d648e3a3","4828beb2","8db8f9a4","13daabe6","b23ad39c","ad7ddda8","fafc1456","b8ba2a04","5b7d5691","da1ad977","256605bd","dba62235","da68ae40","42f493f9","69a28ffa","93699a9f","f4b46247","f299681b","6ed6cc5a","bd5b4583","3ccffa7f"}},["9b2140378640432e"]={name="supply_frv",t="3LHk6DNB",fields={"50ac6619","a09ccd0a","b19ad128","d7082cbf","dab52fe8","0565f571","169d5ed7","82830aed","cad5b537","9ddf0683","95417727","a5f83fa0","9256767e","7f6b358d","788b9753","99901914","1dd07f05","39d141d6","98b4aaf0","e144c5e3","6d2d83f8","7d9563dd","d8819b3e","cb0453ea","9d550ad3","bbecde19","8fd2d63e","c336a25c","af4c7e8a","0d4e190d","308e0842","0c0bd772","d9810f60","3b5a954f","6396946a","791943f0","91f98cec","7615f45d","eeb1225e","cca43d10","5a8871e3","e00857ad","d648e3a3","4828beb2","8db8f9a4","13daabe6","b23ad39c","ad7ddda8","fafc1456","b8ba2a04","5b7d5691","da1ad977","256605bd","dba62235","da68ae40","42f493f9","69a28ffa","93699a9f","f4b46247","f299681b","6ed6cc5a","bd5b4583","3ccffa7f","69889752","a5ae4500"}}}
FRV.profile_resources={['cc21c7ffd3ebefb9']=true,['9b2140378640432e']=true}
FRV.zone_hashes={'fed0a478','f3cb00ad','c6bf05a9','f12186b7'}
function FRV.schema(p,session)
 if p.session~=session then p.session=session;p.ok=nil;p.retry=0 end
 if p.ok==true then return true end
 if M.clock<(p.retry or 0) then return false end;p.retry=M.clock+5
 local info=call(Net.object_info,p.t);local fs=type(info)=='table' and info.fields
 if type(fs)~='table' then return false end
 local n=0;local valid=true
 for k in pairs(fs) do
  if type(k)~='number' or k~=math.floor(k) or k<1 or k>#p.fields then valid=false;break end;n=n+1
 end
 if n~=#p.fields then valid=false end
 if valid then for i,v in ipairs(p.fields) do if hash_of_field(fs[i])~=v then valid=false;break end end end
 if p.ok~=valid then log('FRV_SCHEMA type='..p.name..' ok='..tostring(valid)) end
 p.ok=valid;return valid
end
function FRV.invalidate(reason)
 if FRV.vehicle then log('FRV_LOST entity='..FRV.vehicle.entity..' goid='..FRV.vehicle.goid..' reason='..reason) end
 FRV.vehicle=nil;FRV.profile=nil;FRV.hp=nil;FRV.max=nil;FRV.data=nil;FRV.data_at=nil;FRV.log_key=nil
end
function FRV.reset()
 FRV.invalidate('context_reset');FRV.next_poll=0;FRV.mode=nil;FRV.identity_key=nil;FRV.block_legacy=false;FRV.native_seen=false;FRV.proxy_key=nil;FRV.proxy_vehicle=nil;FRV.proxy_retry=0;FRV.proxy_log=nil
end
function FRV.drop_tank()
 if M.hull then log('BASTION_CONTEXT_CLEAR hull='..M.hull) end
 M.hull=nil;M.cache={};M.pending_bind=nil;M.ownership=nil;M.seat_scan=nil;M.seat_hint=nil;clear_values()
end
function FRV.wheel_model(data,i)
 if not data then return {kind='unknown'} end
 local state=data.damage and data.damage[i]
 if state==2 then return {kind='hub',state=2} end
 local hp,mx=data.hp and data.hp[i],data.max and data.max[i]
 local hp_ok=(data.hp_valid==nil or data.hp_valid[i]~=false)
 if data.precision=='LOCAL_RUNTIME' and hp_ok and type(hp)=='number' and type(mx)=='number' and mx>0 then
  return {kind='tire',ratio=math.max(0,math.min(1,hp/mx)),state=state,precision='LOCAL_RUNTIME'}
 end
 local q=data.q and data.q[i]
 if q~=nil and q>=0 and q<=3 and q==math.floor(q) then
  return {kind='tire',ratio=q/3,upper=math.min(1,(q+1)/3),state=state,precision='QUANTIZED_OR_UNKNOWN'}
 end
 return {kind='unknown',state=state}
end
function FRV.color(ratio)
 if ratio==nil then return {148,155,157} end
 if ratio<=0.5 then return {255,96,83} elseif ratio<=0.75 then return {255,205,83} end
 return {240,244,239}
end
function FRV.read(session)
 local d,p=FRV.vehicle,FRV.profile
 if not d or not p then return end
 -- Lua getters are gated by exact supported resource, live GOID, type and schema.
 if not valid_goid(session,d.goid) or call(GS.game_object_is_type,session,d.goid,p.t)~=true or not FRV.schema(p,session) then
  FRV.invalidate('type_or_schema_mismatch');return
 end
 local hp=call(GS.game_object_field,session,d.goid,'sd7m7FWA')
 local mx=call(GS.game_object_field,session,d.goid,'nZ5Vxt8x')
 local data,why=Native.health(d,FRV.zone_hashes)
 if data then FRV.data=data;FRV.data_at=M.clock;FRV.read_error=nil
 else
  -- No indefinitely stale bars. Keep only a short last-good display for THIS ID.
  if not FRV.data_at or M.clock-FRV.data_at>0.25 then FRV.data=nil end
  if FRV.read_error~=why or M.clock>=(FRV.error_log_at or 0) then
   log('FRV_READ_REJECT entity='..d.entity..' reason='..tostring(why));FRV.read_error=why;FRV.error_log_at=M.clock+10
  end
 end
 if type(hp)~='number' and data then hp=data.body end
 if type(mx)=='number' and mx==math.floor(mx) and mx>0 and mx<=10000000
  and type(hp)=='number' and hp==math.floor(hp) and hp>=0 and hp<=mx then FRV.hp=hp;FRV.max=mx
 else FRV.hp=nil;FRV.max=nil end
 if data then
  local valid_bits={}
  for i=1,4 do valid_bits[i]=(not data.hp_valid or data.hp_valid[i]~=false) and '1' or '0' end
  local valid_text=table.concat(valid_bits,'')
  local key=table.concat({d.entity,d.goid,data.flags,tostring(data.synced_flags),data.precision,table.concat(data.hp,','),valid_text,table.concat(data.max,','),table.concat(data.q or {},','),table.concat(data.damage,','),tostring(FRV.hp)},'|')
  if key~=FRV.log_key and M.clock>=(FRV.log_at or 0) then
   log('FRV_STATE resource='..d.resource..' entity='..d.entity..' goid='..d.goid..' authority_bit0='..tostring(data.flags%2==1)
    ..' precision='..data.precision..' hp='..table.concat(data.hp,',')..' hp_valid='..valid_text..' max='..table.concat(data.max,',')
    ..' q2='..table.concat(data.q or {},',')..' damage='..table.concat(data.damage,',')..' body='..tostring(FRV.hp)
    ..' health_index='..data.health_index..' read_bytes='..data.bytes..' read_calls='..data.calls)
   FRV.log_key=key;FRV.log_at=M.clock+0.5
  end
 end
end
function FRV.poll(session,avatar)
 if M.clock<FRV.next_poll then return FRV.mode end
 FRV.next_poll=M.clock+0.1 -- Time based, no catch-up burst and no whole-world scan.
 local relation,why=Native.relation(avatar,M.clock)
 if not relation then
  if FRV.last_error~=why or M.clock>=(FRV.native_error_at or 0) then
   log('NATIVE_UNAVAILABLE reason='..tostring(why));FRV.last_error=why;FRV.native_error_at=M.clock+10
  end
  -- Once a native relation was in use, a missed read must NOT revive stale tank
  -- references/ownership hints. Only a verified relation or explicit exit resets it.
  if FRV.native_seen or FRV.block_legacy then
   FRV.invalidate('native_identity_unavailable');FRV.drop_tank();FRV.mode='NONE'
  else FRV.mode='LEGACY' end
  return FRV.mode
 end
 FRV.last_error=nil
 if relation.status=='NO_SEATER' then
  if FRV.native_seen then FRV.invalidate('seater_gone');FRV.drop_tank();FRV.mode='NONE'
  else FRV.mode='LEGACY' end
  return FRV.mode
 end
 FRV.native_seen=true
 if relation.status~='VEHICLE' then
  FRV.invalidate('collection_empty');FRV.drop_tank();FRV.identity_key=nil;FRV.mode='NONE';return FRV.mode
 end
 local collection=relation.vehicle
 local proxy_key=table.concat({avatar,relation.avatar.entity,collection.entity,collection.goid,collection.resource,collection.unit},':')
 if FRV.identity_key~=proxy_key then
  FRV.invalidate('identity_changed');FRV.drop_tank();FRV.identity_key=proxy_key
  FRV.proxy_key=nil;FRV.proxy_vehicle=nil;FRV.proxy_retry=0;FRV.proxy_log=nil
  log('NATIVE_VEHICLE avatar='..avatar..' avatar_entity='..relation.avatar.entity..' entity='..collection.entity..' goid='..collection.goid..' resource='..collection.resource..' unit='..tostring(collection.unit)..' role_raw='..relation.role)
 end
 local d=collection
 local p=FRV.profiles[d.resource]
 if not p then
  -- Some seats expose a networked SeatCollection/proxy rather than the Hull.
  -- Resolve only through a unique exact native unit-key match in the typed
  -- Health component table. Never use distance, object ordering or HP patterns.
  if FRV.proxy_key==proxy_key and FRV.proxy_vehicle then d=FRV.proxy_vehicle;p=FRV.profiles[d.resource]
  elseif M.clock>=(FRV.proxy_retry or 0) then
   FRV.proxy_retry=M.clock+0.5
   local resolved,meta=Native.resolve_proxy(collection,FRV.profile_resources)
   if resolved then
    d=resolved;p=FRV.profiles[d.resource];FRV.proxy_key=proxy_key;FRV.proxy_vehicle=d
    log('FRV_PROXY_RESOLVE proxy_entity='..collection.entity..' proxy_goid='..collection.goid..' proxy_resource='..collection.resource
     ..' unit='..tostring(collection.unit)..' hull_entity='..d.entity..' hull_goid='..d.goid..' hull_resource='..d.resource
     ..' evidence='..tostring(type(meta)=='table' and meta.reason or meta))
   else
    local detail=type(meta)=='table' and ('reason='..tostring(meta.reason)..' unit='..tostring(meta.unit)..' entries='..tostring(meta.entries)..' candidates='..tostring(meta.candidates)) or tostring(meta)
    if FRV.proxy_log~=detail or M.clock>=(FRV.proxy_log_at or 0) then
     log('FRV_PROXY_REJECT proxy_entity='..collection.entity..' proxy_goid='..collection.goid..' proxy_resource='..collection.resource..' '..detail)
     FRV.proxy_log=detail;FRV.proxy_log_at=M.clock+5
    end
   end
  end
 end
 if p then
  FRV.block_legacy=true;FRV.mode='FRV';FRV.drop_tank()
  FRV.vehicle=d;FRV.profile=p;FRV.read(session);return FRV.mode
 end
 local d=collection -- tank compatibility below must use the original collection relation.
 FRV.invalidate('not_frv');FRV.block_legacy=true;FRV.mode='PENDING'
 -- Tank HP/ammo readers below are retained from 1.2.1. Only identity acquisition
 -- gains this exact collection relation, including direct-to-gunner entry.
 local hf=sample(session,d.goid)
 if hull_sig(hf) then
  bind_hull(d.goid,hf,'native_seater');M.vehicle_ref=d.goid;FRV.mode='TANK';return FRV.mode
 end
 local hid,hull=resolve_weapon_hull(session,d.goid)
 if hid then bind_hull(hid,hull,'native_seater');M.vehicle_ref=d.goid;FRV.mode='TANK';return FRV.mode end
 -- A budget miss may retain only a tank already tied to this unchanged native ID.
 -- It never authorizes the old avatar reference to pick some other hull.
 if M.hull and (M.hull==d.goid or M.vehicle_ref==d.goid) then FRV.mode='TANK'
 else FRV.drop_tank();FRV.mode='NONE' end
 return FRV.mode
end

local material='mods/driver_hud/solid'
local function remember(kind,id) if id~=nil then M.ids[#M.ids+1]={kind,id} end end
local function tri(x1,y1,x2,y2,x3,y3,a)
 local uv=V2(0.5,0)
 remember('destroy_triangle',Gui.triangle(M.gui,V3(x1,0,y1),V3(x2,0,y2),V3(x3,0,y3),3,Color(math.floor(a*255),255,255,255),material,uv,uv,uv))
end
local function rect(x,y,w,h,a) if w<=0 or h<=0 then return end tri(x,y,x+w,y,x,y+h,a);tri(x+w,y,x+w,y+h,x,y+h,a) end
local function text(s,x,y,size,a) remember('destroy_text',Gui.text(M.gui,s,'core/performance_hud/debug',size,'core/performance_hud/debug',V2(x,y),Color(math.floor(a*255),255,255,255))) end
local function bullet(x,y,s,a) rect(x,y,4*s,11*s,a);tri(x,y+11*s,x+4*s,y+11*s,x+2*s,y+15*s,a);rect(x-s,y-s,6*s,s,a) end
local function disk(x,y,r,a)
 for i=0,23 do local t=i*math.pi/12;local u=(i+1)*math.pi/12;tri(x,y,x+math.cos(t)*r,y+math.sin(t)*r,x+math.cos(u)*r,y+math.sin(u)*r,a) end
end
-- FRV geometry only: no texture background, no numeric wheel labels.
function FRV.triangle(x1,y1,x2,y2,x3,y3,a,c)
 local uv=V2(0.5,0)
 remember('destroy_triangle',Gui.triangle(M.gui,V3(x1,0,y1),V3(x2,0,y2),V3(x3,0,y3),3,Color(math.floor(a*255),c[1],c[2],c[3]),material,uv,uv,uv))
end
function FRV.line(x1,y1,x2,y2,width,a,c)
 local dx,dy=x2-x1,y2-y1;local l=math.sqrt(dx*dx+dy*dy);if l<0.001 then return end
 local nx,ny=-dy/l*width*0.5,dx/l*width*0.5
 FRV.triangle(x1+nx,y1+ny,x1-nx,y1-ny,x2+nx,y2+ny,a,c)
 FRV.triangle(x1-nx,y1-ny,x2-nx,y2-ny,x2+nx,y2+ny,a,c)
end
function FRV.path(points,x,y,s,width,a,c,closed)
 if not closed then
  for i=1,#points-1 do
   local p,q=points[i],points[i+1]
   FRV.line(x+p[1]*s,y+p[2]*s,x+q[1]*s,y+q[2]*s,width*s,a,c)
  end
  return
 end
 -- Shared miter vertices form a continuous ring, including every corner.
 -- No detached edge rectangles and no overlapping translucent corner patches.
 local outer,inner={},{}
 for i,p in ipairs(points) do
  local prev,nextp=points[(i-2)%#points+1],points[i%#points+1]
  local ax,ay=p[1]-prev[1],p[2]-prev[2]
  local bx,by=nextp[1]-p[1],nextp[2]-p[2]
  local al,bl=math.sqrt(ax*ax+ay*ay),math.sqrt(bx*bx+by*by)
  if al==0 or bl==0 then return end
  local nx,ny=-ay/al,ax/al;local mx,my=-by/bl,bx/bl
  local denom=1+nx*mx+ny*my;if denom<0.001 then return end
  local dx,dy=(nx+mx)*width*0.5/denom,(ny+my)*width*0.5/denom
  outer[i]={x+(p[1]+dx)*s,y+(p[2]+dy)*s}
  inner[i]={x+(p[1]-dx)*s,y+(p[2]-dy)*s}
 end
 for i=1,#points do
  local j=i%#points+1;local p,q,r,t=outer[i],inner[i],outer[j],inner[j]
  FRV.triangle(p[1],p[2],q[1],q[2],r[1],r[2],a,c)
  FRV.triangle(q[1],q[2],t[1],t[2],r[1],r[2],a,c)
 end
end
function FRV.bar(x,y,w,h,a,c)
 if w<=0 or h<=0 then return end
 FRV.triangle(x,y,x+w,y,x,y+h,a,c);FRV.triangle(x+w,y,x+w,y+h,x,y+h,a,c)
end
function FRV.wheel(x,y,s,model,a)
 if model.kind=='hub' then
  local c=FRV.color(0)
  -- A narrow, bare rim. No rubber silhouette, life bar, axle or numeric label.
  FRV.path({{7,5},{13,5},{15,7},{15,27},{13,29},{7,29},{5,27},{5,7}},x,y,s,1.8,a,c,true)
  FRV.line(x+10*s,y+9*s,x+10*s,y+25*s,1.5*s,a*0.7,c)
  return
 end
 local c=FRV.color(model.ratio)
 FRV.path({{4,0},{16,0},{20,4},{20,30},{16,34},{4,34},{0,30},{0,4}},x,y,s,2,a,c,true)
 if model.kind=='unknown' then
  FRV.line(x+7*s,y+17*s,x+13*s,y+17*s,1.5*s,a*0.7,c);return
 end
 -- A single continuous track and fill; HP is never rendered as text.
 FRV.bar(x+5*s,y+5*s,10*s,24*s,a*0.10,c)
 if model.upper and model.upper>model.ratio then
  -- Remote/unknown precision: translucent tail is the coarse interval, not an
  -- invented precise measurement. The underlying tire remains at q2 == 0.
  FRV.bar(x+5*s,y+(5+24*model.ratio)*s,10*s,24*(model.upper-model.ratio)*s,a*0.23,c)
 end
 FRV.bar(x+5*s,y+5*s,10*s,24*model.ratio*s,a*0.78,c)
end
function FRV.layout(w,h)
 local ds=math.min(w/1920,h/1080);local s=ds*Position.scale
 local x=w*Position.x-64*s;local y=h*(1-Position.y)-62*s
 x=math.max(8*ds,math.min(w-128*s-8*ds,x))
 y=math.max(8*ds,math.min(h-124*s-8*ds,y))
 return x,y,s
end
function FRV.number_fallback(label,cx,cy,size,a,c)
 -- Last-resort geometric digits when the engine does not expose text extents.
 -- Their cell bounds are defined here, so centering is still exact, not guessed.
 local seg={{{0,1},{1,1}},{{1,1},{1,0.5}},{{1,0.5},{1,0}},{{0,0},{1,0}},{{0,0.5},{0,0}},{{0,1},{0,0.5}},{{0,0.5},{1,0.5}}}
 local map={['0']={1,2,3,4,5,6},['1']={2,3},['2']={1,2,7,5,4},['3']={1,2,7,3,4},['4']={6,7,2,3},['5']={1,6,7,3,4},['6']={1,6,7,5,3,4},['7']={1,2,3},['8']={1,2,3,4,5,6,7},['9']={1,2,3,4,6,7},['-']={7}}
 local cw,gap=size*0.43,size*0.2
 local minx,maxx=math.huge,-math.huge
 for i=1,#label do
  for _,j in ipairs(map[label:sub(i,i)] or map['-']) do
   for _,p in ipairs(seg[j]) do local x=(i-1)*(cw+gap)+p[1]*cw;minx=math.min(minx,x);maxx=math.max(maxx,x) end
  end
 end
 local left=cx-(minx+maxx)*0.5
 for i=1,#label do
  for _,j in ipairs(map[label:sub(i,i)] or map['-']) do
   local p,q=seg[j][1],seg[j][2];local x=left+(i-1)*(cw+gap);local y=cy-size/2
   FRV.line(x+p[1]*cw,y+p[2]*size,x+q[1]*cw,y+q[2]*size,size*0.085,a,c)
  end
 end
end
function FRV.centered_number(label,cx,cy,size,a,c)
 local font='core/performance_hud/debug'
 local low,high=call(Gui.text_extents,M.gui,label,font,size)
 if low and high then
  local function xy(v)
   -- Stingray's documented result is Vector2; use its accessors, not guessed
   -- userdata fields. A table/property fallback also supports older bindings.
   local ok,fx,fy=pcall(function()return V2.x,V2.y end)
   if ok and type(fx)=='function' and type(fy)=='function' then return fx(v),fy(v) end
   return v.x,v.y
  end
  local ok,lx,ly,hx,hy=pcall(function()
   local ax,ay=xy(low);local bx,by=xy(high);return ax,ay,bx,by
  end)
  if ok and type(lx)=='number' and type(ly)=='number' and type(hx)=='number' and type(hy)=='number'
   and lx==lx and ly==ly and hx==hx and hy==hy
   and hx>=lx and hy>=ly and hx-lx<size*20 and hy-ly<size*5
   and math.abs(lx)<size*20 and math.abs(ly)<size*20 then
   remember('destroy_text',Gui.text(M.gui,label,font,size,font,V2(cx-(lx+hx)/2,cy-(ly+hy)/2),Color(math.floor(a*255),c[1],c[2],c[3])))
   return
  end
 end
 FRV.number_fallback(label,cx,cy,size,a,c)
end
function FRV.draw(w,h)
 local d=FRV.data;local vehicle=FRV.vehicle
 if not vehicle then return end
 local key=table.concat({'frv',w,h,vehicle.entity,vehicle.goid,tostring(FRV.hp),tostring(FRV.max),Position.revision,
  d and table.concat(d.hp,',') or '?',d and table.concat(d.damage,',') or '?',d and table.concat(d.q or {},',') or '?',d and d.precision or '?'},':')
 if key==M.draw_key then return end
 clear()
 local x,y,s=FRV.layout(w,h);local a=math.min(1,C.alpha+0.12)
 local ratio=FRV.hp and FRV.max and FRV.hp/FRV.max or nil;local c=FRV.color(ratio)
 local body={{43,2},{85,2},{92,10},{92,92},{85,122},{43,122},{36,92},{36,10}}
 FRV.path(body,x,y,s,1.8,a*0.9,c,true)
 FRV.path({{43,94},{47,113},{81,113},{85,94}},x,y,s,1.5,a*0.70,c,true)
 FRV.line(x+44*s,y+14*s,x+84*s,y+14*s,1.3*s,a*0.55,c)
 local positions={{8,84},{100,84},{8,8},{100,8}}
 for i,p in ipairs(positions) do FRV.wheel(x+p[1]*s,y+p[2]*s,s,FRV.wheel_model(d,i),a) end
 local label=FRV.hp~=nil and tostring(math.floor(FRV.hp+0.5)) or '--'
 FRV.centered_number(label,x+64*s,y+62*s,17*s,a,c)
 M.draw_key=key
end

local function draw(w,h)
 local key=table.concat({w,h,tostring(M.hull),tostring(M.hp),tostring(M.max),tostring(M.ammo),tostring(M.mg)},':')
 if key==M.draw_key then return end
 clear()
 local s=math.min(w/1920,h/1080)*C.scale
 local x=w/2-150*s;local y=C.offset_y*s;local a=C.alpha
 rect(x,y,300*s,1.5*s,a);rect(x,y+14.5*s,300*s,1.5*s,a);rect(x,y,1.5*s,16*s,a);rect(x+298.5*s,y,1.5*s,16*s,a)
 rect(x+3*s,y+3*s,294*s,10*s,0.12)
 if M.hp and M.max then rect(x+3*s,y+3*s,294*s*M.hp/M.max,10*s,a*0.66) end
 local hp=M.hp and (tostring(math.floor(M.hp+0.5))..' / '..tostring(math.floor(M.max+0.5))) or '-- / --'
 text(hp,x,y+23*s,18*s,a)
 bullet(x+179*s,y+23*s,s,a);text(M.ammo and tostring(M.ammo) or '--',x+191*s,y+23*s,18*s,a)
 for i=0,2 do bullet(x+(228+i*5)*s,y+23*s,s*0.7,a) end
 text(M.mg and tostring(M.mg) or '--',x+247*s,y+23*s,18*s,a)
 local ds=math.min(w/1920,h/1080)
 disk(w/2,h/2,3.2*ds,0.10);disk(w/2,h/2,2.5*ds,0.18);disk(w/2,h/2,1.8*ds,0.35);disk(w/2,h/2,1.1*ds,0.5)
 M.draw_key=key
end
local function update(dt)
 M.frame=M.frame+1
 local step=type(dt)=='number' and dt or 0.016667
 if step~=step then step=0 elseif step<0 then step=0 elseif step>0.25 then step=0.25 end
 M.clock=M.clock+step;Position.reload(M.clock)
 local session=call(Net.game_session);local peer=call(Net.peer_id)
 local worlds=call(App.worlds) or {};local world=call(App.main_world)
 if session~=M.session or peer~=M.peer or world~=M.world then
  surface_reset(worlds);full_reset();M.player=nil;M.avatar=nil;M.avatar_valid_at=nil;M.cache={};M.known={};M.preseat_owned={};M.bg_owned_cursor=1
  M.session,M.peer,M.world=session,peer,world
 end
 if not session or not peer or not live(worlds,world) or call(GS.in_session,session)~=true then clear();full_reset();return end
 local owned=call(GS.objects_owned_by,session,peer)
 if type(owned)~='table' then clear();full_reset();return end
 local set,owned_ids={},{}
 for _,id in pairs(owned) do if integer(id,32766) then set[id]=true;owned_ids[#owned_ids+1]=id end end
 -- Player object 0 is legitimate in captured sessions. Vehicle/Avatar GOIDs keep
 -- the existing stricter checks; do not reuse valid_goid() for the player object.
 if M.player==nil or not set[M.player] or call(GS.game_object_is_type,session,M.player,'un6y1d')~=true then
  M.player=nil
  for id in pairs(set) do
   if call(GS.game_object_is_type,session,id,'un6y1d')==true then
    if M.player~=nil then clear();full_reset();return end
    M.player=id
   end
  end
 end
 if M.player==nil or call(GS.game_object_exists,session,M.player)~=true then
  clear();full_reset();M.avatar=nil;M.avatar_valid_at=nil;return
 end
 local avatar=call(GS.game_object_field,session,M.player,'baegche')
 if avatar==nil and M.avatar and M.clock-(M.avatar_valid_at or -100)<0.5 then avatar=M.avatar
 elseif avatar~=nil then M.avatar_valid_at=M.clock end
 if avatar~=M.avatar then full_reset();M.avatar=avatar end
 if not valid_goid(session,avatar) then clear();full_reset();return end
 local motion=call(GS.game_object_field,session,avatar,'motion_enabled')
 local rotation=call(GS.game_object_field,session,avatar,'rotation_enabled')
 local where=call(GS.game_object_field,session,avatar,'gls4w9b')
 local state=call(GS.game_object_field,session,avatar,'state')
 local explicit_exit=motion==true or rotation==true or where==30 or state==2
 local seated_now=motion==false and rotation==false and where~=30 and state~=2
 local missing=motion==nil or rotation==nil
 if not explicit_exit and missing and M.seated then
  M.seat_unknown_since=M.seat_unknown_since or M.clock;seated_now=M.clock-M.seat_unknown_since<0.5
 else M.seat_unknown_since=nil end
 if not seated_now then
  local was=M.seated
  if was then log('HUD_EXIT avatar='..avatar) end
  full_reset();refresh_known_masks(session,was);discover_owned_bastions(session,owned_ids);M.preseat_owned=set
  clear();return
 end
 if not M.seated then
  M.seated=true;M.hull=nil;M.vehicle_ref=nil;M.bind_retry=0;M.bind_weak=false;M.seat_enter_frame=M.frame;M.seat_enter_time=M.clock
  M.pending_bind=nil;M.seat_hint=nil;M.next_bind=0;M.ownership=nil;M.seat_scan=nil;M.entry_new_seen={};M.entry_owned_cursor=1
  FRV.reset();clear_values();log('HUD_ENTER avatar='..avatar)
 end
 local mode=FRV.poll(session,avatar)
 if mode=='LEGACY' then
  if M.clock>=(M.next_bind or 0) then M.next_bind=M.clock+(M.hull and 0.5 or 0.2);bind_current_vehicle(session,avatar,owned_ids) end
  refresh_bound(session,set)
 elseif mode=='TANK' then refresh_bound(session,set) end
 local show_frv=mode=='FRV' and FRV.vehicle~=nil
 if not show_frv and (not M.hull or M.hp==nil) then clear();return end
 if not M.gui or not live(worlds,M.gui_world) then
  surface_reset(worlds)
  for _,v in ipairs(worlds) do if v~=world then M.gui_world=v;break end end
  if M.gui_world then M.gui=call(World.create_screen_gui,M.gui_world,'scale',1,1) end
 end
 if not M.gui then return end
 if sr.Window and call(sr.Window.show_cursor)==true then clear();return end
 local w,h=call(Gui.resolution)
 if type(w)~='number' or type(h)~='number' or w<=0 or h<=0 then return end
 if show_frv then
  local ok,err=pcall(FRV.draw,w,h)
  if not ok then
   pcall(clear)
   if M.clock>=(FRV.draw_error_at or 0) then log('FRV_DRAW_ERROR '..tostring(err));FRV.draw_error_at=M.clock+10 end
  end
 else draw(w,h) end
end
local old=rawget(_G,'update');if type(old)~='function' then return {installed=false} end
rawset(_G,'__DRIVER_HUD_INSTALLED',true)
local retry_at=0
rawset(_G,'update',function(...)
 if M.clock>=retry_at then
  local ok,err=pcall(update,...)
  if not ok then
   pcall(clear);pcall(full_reset);retry_at=M.clock+1;log('HUD_RECOVERABLE_ERROR '..tostring(err))
  end
 else
  -- Keep the retry clock moving without running failed rendering/native work.
  local dt=select(1,...)
  M.clock=M.clock+(type(dt)=='number' and dt==dt and math.max(0,math.min(0.25,dt)) or 0.016667)
 end
 return old(...)
end)
local stop=rawget(_G,'shutdown')
rawset(_G,'shutdown',function(...)
 pcall(surface_reset,call(App.worlds) or {});pcall(full_reset)
 if type(stop)=='function' then return stop(...) end
end)
return {installed=true}
