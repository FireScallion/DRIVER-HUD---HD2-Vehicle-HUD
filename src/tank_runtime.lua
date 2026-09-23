-- 1.4.3: staged reload and retained telemetry. Raw ammo values; no ammo prediction.
-- No type brute force, world scan, GOID adjacency binding or ammo prediction.
Tank={active=nil,history={},history_serial=0,MAX_HISTORY=8,KEEP_PROGRESS=120,STALE_AFTER=3,RELOAD_STALE_AFTER=1}
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
-- Observed stage durations/checkpoints, used only to animate the indicator.
Tank.stages={old={{4,1.256},{5,1.249},{7,.566},{4,.929}},new={{4,.06},{5,2.50},{7,1.43}}}
function Tank.new_reload(kind)
 return {kind=kind,phase='idle',elapsed=0,stage_elapsed=0,tick_at=M.clock,checkpoints={}}
end
local function tank_stage_start(r,stage)
 local t=0;for i=1,stage-1 do t=t+Tank.stages[r.kind][i][2] end;return t
end
function Tank.advance(r,now)
 local dt=math.max(0,now-(r.tick_at or now));r.tick_at=now
 if r.phase=='running' and r.stage then
  local duration=Tank.stages[r.kind][r.stage][2]
  r.stage_elapsed=math.min(duration*.985,(r.stage_elapsed or 0)+dt)
  r.elapsed=tank_stage_start(r,r.stage)+r.stage_elapsed
 end
end
function Tank.feed_reload(r,v,now)
 if r.last_sample and now-r.last_sample>.3 then r.stage_observed=false end
 Tank.advance(r,now)
 local prior_current,prior_reserve=r.current,r.reserve
 if v.current~=nil then r.current=v.current end
 if v.reserve~=nil then r.reserve=v.reserve end
 local committed=(prior_reserve~=nil and r.reserve~=nil and r.reserve<prior_reserve and (r.current or 0)>0)
 if r.kind=='old' and prior_current==0 and r.current==1 and r.phase~='idle' then committed=true end
 if committed then
  r.committed=true
  if r.kind=='old' then
   r.stage=4;r.stage_elapsed=0;r.elapsed=tank_stage_start(r,4);r.phase='running';r.known_start=true
  elseif v.state==nil or v.state==0 then
   r.phase='idle';r.elapsed=0;r.stage=nil;r.checkpoints={}
  end
 end
 local state=v.state
 if state==nil then return end
 local previous=r.state;r.state=state;r.last_seen=now
 if state==0 then
  r.last_sample=now;r.stage_observed=false
  -- Old initial-stage interruptions also return 0 while the chamber is empty.
  if r.kind=='old' and r.phase~='idle' and r.current==0 then
   r.phase='paused';r.restart_initial=true
  else r.phase='idle';r.stage=nil;r.elapsed=0;r.checkpoints={};r.committed=false end
  return
 end
 local paused=state==1 or state==3
 local stage=(state==5 or state==1) and 2 or ((state==7 or state==3) and 3 or nil)
 if state==4 then stage=(r.kind=='old' and (r.current==1 or r.committed)) and 4 or 1 end
 if not stage then r.phase='paused';return end
 if paused then
  if r.stage~=stage or r.phase=='idle' then
   r.stage=stage;r.stage_elapsed=0;r.elapsed=tank_stage_start(r,stage);r.known_start=false
  end
  -- Infer checkpoint ONLY from a locally observed stage start and recent samples.
  local cp=r.kind=='new' and (stage==2 and 1.15 or .30) or nil
  if cp and r.stage_observed and r.last_sample and now-r.last_sample<=.3 and r.stage_elapsed>=cp+.1 then r.checkpoints[stage]=cp end
  r.phase='paused';r.last_sample=now;return
 end
 if r.stage~=stage or r.phase=='idle' or r.restart_initial then
  r.stage_elapsed=0;r.stage_observed=(previous~=nil and previous~=state and r.last_sample~=nil and now-r.last_sample<=.3)
  r.known_start=r.stage_observed or (r.kind=='old' and committed) or false
 elseif r.phase=='paused' then
  r.stage_elapsed=r.checkpoints[stage] or 0;r.stage_observed=true;r.known_start=true
 end
 r.restart_initial=nil;r.stage=stage;r.phase='running'
 r.elapsed=tank_stage_start(r,stage)+r.stage_elapsed;r.last_sample=now;r.needs_reconcile=nil
end
function Tank.detach()
 local a=Tank.active;if not a then return end
 Tank.advance(a.reload,M.clock)
 if a.reload.phase~='idle' then
  local r=tank_copy(a.reload)
  r.stage_observed=false -- Detached history cannot establish an unobserved checkpoint.
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
   next_gatling=M.clock+.04,next_rack_a=M.clock+.04,next_rack_b=M.clock+.04,
   cursor=1,phase=0,next_old=0,next_log=M.clock+5,diag={},saved_ref_key=saved and saved.ref_key}
  log('TANK_VARIANT hull='..tostring(M.hull)..' variant='..kind..' telemetry=cache_candidate_plus_bounded_batch')
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
function Tank.bind_shape(a,id,shape)
 if shape~='gatling' and shape~='rack' then return false end
 local c=a.children[id]
 if c and c.shape~=shape then
  a.children[id]=nil;if a.gatling==id then a.gatling=nil;a.reload=Tank.new_reload('new') end
  local keep={};for _,v in ipairs(a.racks or {})do if v~=id then keep[#keep+1]=v end end;a.racks=keep;c=nil
 end
 if not c then c={shape=shape};a.children[id]=c end
 if shape=='gatling' then
  if a.gatling and a.gatling~=id then a.ambiguous=true;return false end;a.gatling=id
 else
  local found=false;for _,v in ipairs(a.racks or {})do if v==id then found=true end end
  if not found then a.racks=a.racks or {};a.racks[#a.racks+1]=id;table.sort(a.racks)end
  if #a.racks>2 then a.ambiguous=true;return false end
 end
 return true
end
function Tank.accept(a,id,f,now)
 local shape=Tank.shape(f)
 if not Tank.bind_shape(a,id,shape) then return end
 local c=a.children[id];local value=Tank.decode(shape,f)
 if value then c.value=value;c.at=now;if shape=='gatling' then Tank.feed_reload(a.reload,value,now) end end
end
local function tank_diag_hit(a,name,ok,value)
 local d=a.diag[name] or {attempts=0,valid=0,gaps=0};a.diag[name]=d
 d.attempts=d.attempts+1
 if ok then d.valid=d.valid+1;d.last=value;d.last_at=M.clock else d.gaps=d.gaps+1 end
end
local function tank_diag_state(a,name,state)
 local k='state_'..name
 if a[k]~=state then
  log('TANK_TELEM_STATE channel='..name..' hull='..tostring(M.hull)..' role='..tostring(a.last_role)..' old='..tostring(a[k])..' new='..tostring(state))
  a[k]=state
 end
end
local function tank_diag_log(a)
 if M.clock<(a.next_log or 0) then return end
 a.next_log=M.clock+5
 local function part(name)
  local d=a.diag[name] or {attempts=0,valid=0,gaps=0}
  local age=d.last_at and string.format('%.2f',M.clock-d.last_at) or 'nil'
  local out=name..'='..d.valid..'/'..d.attempts..' gaps='..d.gaps..' changes='..(d.changes or 0)..' age='..age..' last='..tostring(d.last)
  d.attempts,d.valid,d.gaps,d.changes=0,0,0,0
  return out
 end
 if a.kind=='new' then
  log('TANK_NEW_READ hull='..tostring(M.hull)..' role='..tostring(a.last_role)..' '..part('gatling')..' '..part('rack_a')..' '..part('rack_b'))
 else
  log('TANK_OLD_RELOAD_READ hull='..tostring(M.hull)..' role='..tostring(a.last_role)..' '..part('old_reload'))
 end
end
function Tank.refresh_new(session)
 local a=Tank.ensure('new');local now=M.clock;local hid=M.hull
 if call(GS.game_object_exists,session,hid)==false then Tank.detach();FRV.drop_tank();return end
 local c=cache_for(hid)
 if now>=a.next_hull then
  a.next_hull=now+.2
  local hf=sample(session,hid)
  if hull_sig(hf) then
   c.hp,c.max,c.hull_valid_at=hf[30],hf[15],now
   Tank.set_refs(a,hf) -- Malformed/partial children are gaps; valid replacements reset channels.
  end
 end

 if #a.refs>0 then
  -- Each identified weapon advances independently. An unreadable rack cannot
  -- prevent Gatling or the other rack from being sampled.
  if a.gatling and now>=a.next_gatling then
   Tank.sample_child(session,a,a.gatling,'gatling',now)
   local c=a.children[a.gatling];a.next_gatling=now+(c and c.cache_live and .1 or .05)
  end
  if a.racks and a.racks[1] and now>=a.next_rack_a then a.next_rack_a=now+.2;Tank.sample_child(session,a,a.racks[1],'rack_a',now) end
  if a.racks and a.racks[2] and now>=a.next_rack_b then a.next_rack_b=now+.2;Tank.sample_child(session,a,a.racks[2],'rack_b',now) end
  if now>=a.next_weapon then
   a.next_weapon=now+.1
   local id=a.refs[a.cursor];a.cursor=a.cursor%#a.refs+1
   local c=id and a.children[id]
   if id and not (c and (c.shape=='gatling' or c.shape=='rack')) then Tank.discover_child(session,a,id,now) end
  end
 end
 tank_diag_log(a)
 Tank.advance(a.reload,now)
 M.hp,M.max=c.hp,c.max
 -- Never pass new rack objects into the old main/coax readers.
 M.ammo=nil;M.mg=nil
end
function Tank.refresh_old(session)
 if not M.hull then Tank.detach();return end
 local a=Tank.ensure('old');local c=M.cache[M.hull];if not c then return end
 local id=c.main_id
 if a.old_id and a.old_id~=id then a.reload=Tank.new_reload('old');a.old_schema=nil end
 a.old_id=id
 if M.clock>=a.next_old then
  a.next_old=M.clock+.1
  local v,source
  if valid_goid(session,id) and call(GS.game_object_is_type,session,id,MAIN_BIND_TYPE)==true then
   if not a.old_schema and M.clock>=(a.schema_retry or 0) then
    a.schema_retry=M.clock+5
    local info=call(Net.object_info,MAIN_BIND_TYPE);local fs=type(info)=='table' and info.fields
    a.old_schema=type(fs)=='table' and #fs==27 and hash_of_field(fs[14])=='cd889dbc'
     and hash_of_field(fs[5])=='ec64918b' and hash_of_field(fs[6])=='d7a5d63e' or nil
   end
   if a.old_schema then
    local state=call(GS.game_object_field,session,id,'L8h7VinJ')
    if integer(state,7) then v={current=c.main_current,reserve=c.main_reserve,state=state};source='targeted' end
   end
   if not v then v=Tank.decode('old',sample(session,id));source='batch' end
   tank_diag_hit(a,'old_reload',v~=nil,v and ('state='..tostring(v.state)..',source='..source))
   if v then tank_diag_state(a,'old_reload',v.state);Tank.feed_reload(a.reload,v,M.clock) end
  else tank_diag_hit(a,'old_reload',false,'invalid') end
 end
 tank_diag_log(a);Tank.advance(a.reload,M.clock)
end
-- The old ammo path remains intact. Only the stale-display policy changes in build.py.
local tank_legacy_refresh=refresh_bound
refresh_bound=function(session,owned_set)
 if Tank.is_new() then Tank.refresh_new(session)
 else tank_legacy_refresh(session,owned_set);Tank.refresh_old(session) end
end
