-- 1.4.0: observed, resource-scoped batched telemetry. NO guessed field names,
-- type brute force, world scan, GOID adjacency binding or ammo prediction.
Tank={active=nil,history={},history_serial=0,MAX_HISTORY=8,KEEP_PROGRESS=120,STALE_AFTER=3,ANIMATION_GRACE=1}
Tank.NEW_RESOURCE='b0c9faf4af8903f9'
local function tank_copy(t) local o={};for k,v in pairs(t or {}) do o[k]=v end;return o end
function Tank.context_key()
 local d=FRV.last_relation and FRV.last_relation.vehicle
 return table.concat({tostring(M.session),tostring(M.peer),tostring(M.world),tostring(M.avatar),
  tostring(M.hull),d and tostring(d.entity) or '?',d and d.resource or 'legacy',d and tostring(d.unit) or '?'},':')
end
function Tank.is_new()
 local d=FRV.last_relation and FRV.last_relation.vehicle
 return FRV.mode=='TANK' and d and d.goid==M.hull and d.resource==Tank.NEW_RESOURCE
end
function Tank.new_reload(kind)
 return {kind=kind,phase='idle',elapsed=0,tick_at=M.clock,last_seen=nil,known_start=false,committed=false}
end
function Tank.advance(r,now)
 local dt=math.max(0,now-(r.tick_at or now));r.tick_at=now
 if r.phase=='running' or r.phase=='settling' then
  local usable=math.max(0,math.min(now,(r.last_seen or now)+Tank.ANIMATION_GRACE)-(now-dt))
  r.elapsed=math.min(3.95,r.elapsed+usable)
  if r.last_seen and now-r.last_seen>Tank.ANIMATION_GRACE then r.phase='uncertain' end
 end
end
function Tank.feed_reload(r,v,now)
 Tank.advance(r,now)
 if r.needs_reconcile then
  if r.reserve~=nil and v.reserve~=r.reserve then
   r.phase='idle';r.elapsed=0;r.known_start=false;r.committed=false;r.state=nil
  end
  r.needs_reconcile=nil
 end
 local previous_current,previous_reserve=r.current,r.reserve
 local in_cycle=r.phase~='idle'
 local commit=(previous_reserve~=nil and v.reserve<previous_reserve and v.current>0)
  or (r.kind=='old' and in_cycle and previous_current==0 and v.current==1)
 local was_state=r.state
 r.current,r.reserve,r.state=v.current,v.reserve,v.state
 if v.state==nil then if in_cycle then r.phase='uncertain' end;return end
 r.last_seen=now
 -- ammo remains usable without inventing a reload state
 local running=v.state==4 or v.state==5 or v.state==7
 if commit then
  if r.kind=='new' or v.state==0 then
   r.phase='idle';r.elapsed=0;r.known_start=false;r.committed=false;return
  end
  -- Old tank commits a round about one second before its final 4 -> 0.
  r.committed=true;r.phase='settling';r.elapsed=math.max(3,r.elapsed);r.known_start=true
 end
 if running then
  if r.phase=='idle' then
   r.elapsed=0;r.committed=false
   -- Joining an already-running reload has no recoverable exact progress.
   r.known_start=(was_state==0)
  elseif r.phase=='paused' or r.phase=='uncertain' then
   -- Keep an observed same-instance progress, never reset on another R press.
  end
  r.phase=r.committed and 'settling' or 'running'
 elseif v.state==1 then
  r.phase='paused'
 elseif v.state==0 then
  if r.committed or (in_cycle and v.current>0) then
   r.phase='idle';r.elapsed=0;r.known_start=false;r.committed=false
  elseif in_cycle then r.phase='paused' -- old interruption returns state 0, still empty
  else r.phase='idle';r.elapsed=0 end
 else r.phase='uncertain' end
end
function Tank.detach()
 local a=Tank.active;if not a then return end
 Tank.advance(a.reload,M.clock)
 if a.reload.phase~='idle' then
  local r=tank_copy(a.reload)
  if a.last_role~=1 and r.phase~='paused' then r.known_start=false;r.elapsed=0 end
  r.phase='paused';r.tick_at=M.clock;r.needs_reconcile=true
  Tank.history_serial=Tank.history_serial+1
  Tank.history[a.key]={reload=r,at=M.clock,serial=Tank.history_serial,ref_key=a.ref_key}
  local count,oldkey,serial=0,nil,math.huge
  for k,v in pairs(Tank.history) do count=count+1;if v.serial<serial then oldkey,serial=k,v.serial end end
  if count>Tank.MAX_HISTORY then Tank.history[oldkey]=nil end
 end
 Tank.active=nil
end
function Tank.ensure(kind)
 local key=Tank.context_key()
 if Tank.active and (Tank.active.key~=key or Tank.active.kind~=kind) then Tank.detach() end
 if not Tank.active then
  local r=Tank.new_reload(kind);local saved=Tank.history[key]
  if saved and M.clock-saved.at<=Tank.KEEP_PROGRESS then
   r=tank_copy(saved.reload);r.phase='paused';r.tick_at=M.clock;r.last_seen=nil
  end
  Tank.history[key]=nil
  Tank.active={key=key,kind=kind,reload=r,refs={},ref_key='',children={},next_hull=0,next_weapon=M.clock+.04,
   cursor=1,phase=0,next_old=0,next_log=0,saved_ref_key=saved and saved.ref_key}
  log('TANK_VARIANT hull='..tostring(M.hull)..' variant='..kind..' telemetry=bounded_batch')
 end
 local a=Tank.active;local role=FRV.last_relation and FRV.last_relation.role
 if a.last_role==1 and role~=nil and role~=1 and a.reload.phase~='idle' then
  Tank.advance(a.reload,M.clock);a.reload.phase='paused'
 end
 a.last_role=role
 return a
end
function Tank.shape(f)
 if type(f)~='table' then return nil end
 local n=dense_count(f)
 -- Incomplete telemetry is not proof of a changed object type.
 local required=n==28 and {1,2,3,4,12,13,14,19,21} or (n==33 and {1,2,11,13,14,15,24,32})
 if required then for _,i in ipairs(required) do if f[i]==nil then return nil end end end
 if n==28 and f[1]==1 and f[2]==64 and f[3]==50 and type(f[4])=='boolean'
  and f[12]==1 and f[13]==35 and f[14]==25 and f[19]==2 and f[21]==10 then return 'gatling' end
 if n==33 and type(f[1])=='number' and f[1]>=0 and f[1]<=1.01 and type(f[2])=='number'
  and f[2]>=0 and f[2]<=1.01 and f[11]==16 and f[13]==2 and f[14]==64 and f[15]==50
  and f[24]==10 and f[32]==2 then return 'rack' end
 return 'other'
end
function Tank.decode(kind,f)
 if type(f)~='table' then return nil end
 if kind=='gatling' then
  if not integer(f[6],6) or not integer(f[7],300) then return nil end
  return {reserve=f[6],current=f[7],state=integer(f[28],7) and f[28] or nil}
 elseif kind=='rack' then if integer(f[18],10) then return {ammo=f[18]} end
 elseif kind=='old' then
  if integer(f[5],30) and integer(f[6],1) then
   return {reserve=f[5],current=f[6],state=integer(f[14],7) and f[14] or nil}
  end
 end
end
function Tank.set_refs(a,hf)
 local refs=type(hf)=='table' and hf[56]
 if refs==nil then return nil end -- unavailable is not an explicitly changed reference set
 if type(refs)~='table' then return false end
 local ids,seen={},{}
 for k,id in pairs(refs) do
  if not integer(k,16) or k<1 or not integer(id,32766) or id==0 or id==M.hull or seen[id] then return false end
  seen[id]=true;ids[#ids+1]=id
 end
 -- The captured variant has exactly five explicitly referenced children.
 if #ids~=5 then return false end
 a.refs_at=M.clock
 table.sort(ids);local key=table.concat(ids,',')
 if key~=a.ref_key then
  local changed=a.ref_key~='' or (a.saved_ref_key and a.saved_ref_key~=key)
  a.refs=ids;a.ref_key=key;a.children={};a.gatling=nil;a.racks={};a.cursor=1;a.ambiguous=false
  -- A changed weapon set is NOT a continuation of the previous reload.
  if changed then a.reload=Tank.new_reload('new') end
  log('TANK_CHILDREN hull='..M.hull..' refs='..key)
 end
 return true
end
function Tank.accept(a,id,f,now)
 local c=a.children[id]
 local n=dense_count(f)
 if c and (not n or (c.shape=='gatling' and n<28) or (c.shape=='rack' and n<33)) then return end
 local shape=Tank.shape(f)
 if not shape then return end
 if c and c.shape~=shape then
  -- Wrong-shaped reused child: discard only this channel, not HP or all weapons.
  a.children[id]=nil;if a.gatling==id then a.gatling=nil;a.reload=Tank.new_reload('new') end
  local racks={};for _,v in ipairs(a.racks or {}) do if v~=id then racks[#racks+1]=v end end;a.racks=racks
  return
 end
 if not c then c={shape=shape};a.children[id]=c end
 if shape=='gatling' then
  if a.gatling and a.gatling~=id then a.ambiguous=true;return end
  a.gatling=id
 elseif shape=='rack' then
  local found=false;for _,v in ipairs(a.racks or {}) do if v==id then found=true end end
  if not found then a.racks=a.racks or {};a.racks[#a.racks+1]=id;table.sort(a.racks) end
  if #a.racks>2 then a.ambiguous=true;return end
 else return end
 local value=Tank.decode(shape,f)
 if value then
  c.value=value;c.at=now
  if shape=='gatling' then Tank.feed_reload(a.reload,value,now) end
 end
end
function Tank.refresh_new(session)
 local a=Tank.ensure('new');local now=M.clock;local hid=M.hull
 if not valid_goid(session,hid) then Tank.detach();FRV.drop_tank();return end
 local c=cache_for(hid)
 if now>=a.next_hull then
  a.next_hull=now+.2
  local hf=sample(session,hid)
  if hull_sig(hf) then
   c.hp,c.max,c.hull_valid_at=hf[30],hf[15],now
   if Tank.set_refs(a,hf)==false then
    -- Explicit malformed/changed references revoke old weapon samples immediately.
    a.refs={};a.children={};a.racks={};a.gatling=nil;a.ref_key='';a.reload=Tank.new_reload('new')
   end
  end
 end
 if now-(c.hull_valid_at or c.bound_at or now)>3 then FRV.drop_tank();return end
 if now>=a.next_weapon and #a.refs>0 and now-(a.refs_at or -100)<=.6 then
  a.next_weapon=now+.1 -- ONE combined weapon query per 100 ms; no catch-up loops.
  local id
  local complete=a.gatling and a.racks and #a.racks==2 and not a.ambiguous
  if complete then
   a.phase=a.phase%4+1
   id=(a.phase==1 or a.phase==3) and a.gatling or a.racks[a.phase==2 and 1 or 2]
  else
   -- At most five explicit current-Hull children, not a spatial/GOID/world scan.
   id=a.refs[a.cursor];a.cursor=a.cursor%#a.refs+1
  end
  if id then
   local exists=call(GS.game_object_exists,session,id)
   if exists==true then
    local f=sample(session,id);if f then Tank.accept(a,id,f,now) end
   elseif exists==false then
    a.children[id]=nil
    if a.gatling==id then a.gatling=nil;a.reload=Tank.new_reload('new') end
    local racks={};for _,v in ipairs(a.racks or {}) do if v~=id then racks[#racks+1]=v end end;a.racks=racks
   end
  end
 end
 Tank.advance(a.reload,now)
 M.hp,M.max=c.hp,c.max
 -- Never pass new rack objects into the old main/coax readers.
 M.ammo=nil;M.mg=nil
end
function Tank.refresh_old(session)
 if not M.hull then Tank.detach();return end
 local a=Tank.ensure('old');local c=M.cache[M.hull];if not c then return end
 local id=c.main_id
 if a.old_id and a.old_id~=id then a.reload=Tank.new_reload('old') end
 a.old_id=id
 if M.clock>=a.next_old then
  a.next_old=M.clock+.2
  if valid_goid(session,id) and call(GS.game_object_is_type,session,id,MAIN_BIND_TYPE)==true then
   local f=sample(session,id);local v=Tank.decode('old',f)
   if v then Tank.feed_reload(a.reload,v,M.clock) end
  end
 end
 Tank.advance(a.reload,M.clock)
end
local tank_legacy_refresh=refresh_bound
refresh_bound=function(session,owned_set)
 if Tank.is_new() then Tank.refresh_new(session)
 else tank_legacy_refresh(session,owned_set);Tank.refresh_old(session) end
end
