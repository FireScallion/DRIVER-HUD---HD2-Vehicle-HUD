-- HD2-Addon: mods/driverhud/driver_hud
-- DRIVER HUD 1.2.1. Multi-Bastion binding hotfix; main gun is 30+1 (31 total); debug logging enabled by default.
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
local function log(s)
 if not C.debug or not dir or not io or not io.open then return end
 local f=io.open(dir..'/Arrowhead/Helldivers2/driver_hud.log','a')
 if f then f:write(tostring(s),'\n');f:close() end
end
log('DRIVER_HUD 1.2.1 START')
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
 if why~='avatar64.25_hull' and why~='avatar64.25_weapon' and why~='local_gunner_owned_weapon' then return false end
 if M.hull==hid then
  if why=='avatar64.25_hull' or why=='avatar64.25_weapon' then M.bind_weak=false end
  return
 end
 local pending=M.pending_bind
 if not pending or pending.hid~=hid or M.clock-pending.last>5 then
  M.pending_bind={hid=hid,last=M.clock,frame=M.frame}
  log('BASTION_CONFIRM_PENDING hull='..hid..' evidence='..why)
  return false
 end
 -- The discovery scheduler provides separate observations; no fixed UI delay.
 if pending.frame==M.frame then return false end
 M.pending_bind=nil;M.seat_hint=nil
 M.hull=hid;M.bind_retry=0;M.seat_scan=nil;M.ownership=nil
 M.bind_weak=not (why=='avatar64.25_hull' or why=='avatar64.25_weapon')
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
 local step=type(dt)=='number' and dt or 0.016667;if step<0 then step=0 elseif step>0.25 then step=0.25 end;M.clock=M.clock+step
 local session=call(Net.game_session);local peer=call(Net.peer_id);local worlds=call(App.worlds) or {};local world=call(App.main_world)
 if session~=M.session or peer~=M.peer or world~=M.world then surface_reset(worlds);full_reset();M.player=nil;M.avatar=nil;M.cache={};M.known={};M.preseat_owned={};M.bg_owned_cursor=1;M.session,M.peer,M.world=session,peer,world end
 if not session or not peer or not live(worlds,world) or call(GS.in_session,session)==false then clear();return end
 local owned=call(GS.objects_owned_by,session,peer)
 if type(owned)~='table' then clear();full_reset();return end
 local set,owned_ids={},{};for _,id in pairs(owned) do if type(id)=='number' then set[id]=true;owned_ids[#owned_ids+1]=id end end
 if not M.player or not set[M.player] or call(GS.game_object_is_type,session,M.player,'un6y1d')~=true then
  M.player=nil
  for id in pairs(set) do if call(GS.game_object_is_type,session,id,'un6y1d')==true then if M.player then clear();full_reset();return end;M.player=id end end
 end
 local avatar=M.player and call(GS.game_object_field,session,M.player,'baegche')
 if avatar==nil and M.avatar and M.clock-(M.avatar_valid_at or -100)<0.5 then avatar=M.avatar
 elseif avatar~=nil then M.avatar_valid_at=M.clock end
 if avatar~=M.avatar then full_reset();M.avatar=avatar end
 local motion,rotation,where,state
 if type(avatar)=='number' and avatar~=32767 then
  motion=call(GS.game_object_field,session,avatar,'motion_enabled')
  rotation=call(GS.game_object_field,session,avatar,'rotation_enabled')
  where=call(GS.game_object_field,session,avatar,'gls4w9b')
  state=call(GS.game_object_field,session,avatar,'state')
 end
 local seated_now=motion==false and rotation==false and                               where~=30 and state~=2
 local missing=motion==nil or rotation==nil                            
 local explicit_exit=motion==true or rotation==true or where==30 or state==2
 if not explicit_exit and missing and M.seated then
  M.seat_unknown_since=M.seat_unknown_since or M.clock
  seated_now=M.clock-M.seat_unknown_since<0.5
 else M.seat_unknown_since=nil end
 if not seated_now then
  local was_seated=M.seated
  M.cache={};M.pending_bind=nil;M.seat_hint=nil;M.ownership=nil;M.seat_scan=nil;M.seat_unknown_since=nil
  M.seated=false;M.hull=nil;M.vehicle_ref=nil;M.bind_retry=0;M.bind_weak=false;M.seat_enter_frame=0;clear_values()
  refresh_known_masks(session,was_seated)
  discover_owned_bastions(session,owned_ids)
  M.preseat_owned=set
  clear();return
 end
 if not M.seated then
  M.seated=true;M.hull=nil;M.vehicle_ref=nil;M.bind_retry=0;M.bind_weak=false;M.seat_enter_frame=M.frame;M.seat_enter_time=M.clock;M.pending_bind=nil;M.seat_hint=nil;M.next_bind=0;M.ownership=nil;M.seat_scan=nil;M.entry_new_seen={};M.entry_owned_cursor=1;clear_values()
 end
 if M.clock>=(M.next_bind or 0) then
  M.next_bind=M.clock+(M.hull and 0.5 or 0.2)
  bind_current_vehicle(session,avatar,owned_ids)
 end
 refresh_bound(session,set)
 if not M.hull or not M.hp then clear();return end
 if not M.gui or not live(worlds,M.gui_world) then
  surface_reset(worlds);for _,v in ipairs(worlds) do if v~=world then M.gui_world=v;break end end
  if M.gui_world then M.gui=call(World.create_screen_gui,M.gui_world,'scale',1,1) end
 end
 if not M.gui then return end
 if sr.Window and call(sr.Window.show_cursor)==true then clear();return end
 local w,h=call(Gui.resolution);if type(w)=='number' and type(h)=='number' and w>0 and h>0 then draw(w,h) end
end
local old=rawget(_G,'update');if type(old)~='function' then return {installed=false} end
rawset(_G,'__DRIVER_HUD_INSTALLED',true)
local failed=false
rawset(_G,'update',function(...) if not failed then local ok,err=pcall(update,...);if not ok then failed=true;pcall(clear);log('ERROR '..tostring(err)) end end return old(...) end)
local stop=rawget(_G,'shutdown');rawset(_G,'shutdown',function(...) pcall(surface_reset,call(App.worlds) or {});if type(stop)=='function' then return stop(...) end end)
return {installed=true}