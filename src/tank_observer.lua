-- Cold-discovery observations are independent of successful batch classification.
-- Exactly the five Hull references; no ownership edits, scans, RPCs or game writes.
Tank.resource_profiles={}
local function profiles()
 if Tank.profile_session~=M.session then Tank.profile_session=M.session;Tank.resource_profiles={} end
 return Tank.resource_profiles
end
local function resource(n)
 local r=n and n.descriptor and n.descriptor.resource
 return type(r)=='string' and #r==16 and r:match('^%x+$') and r or nil
end
function Tank.profile_for(n)
 local p=profiles()[resource(n) or ''];return p and not p.conflict and p or nil
end
function Tank.learn_profile(c,n)
 local r=resource(n);if not r or not c.cache_model or c.cache_rejected then return end
 local all=profiles();local p=all[r]
 if p and (p.shape~=c.shape or p.model~=c.cache_model) then
  p.conflict=true;return
 end
 if p and c.state_cache_ok then p.state_ok=true end
 if not p then
  local count=0;for _ in pairs(all)do count=count+1 end;if count>=16 then return end
  all[r]={shape=c.shape,model=c.cache_model,state_ok=c.state_cache_ok==true};log('TANK_RESOURCE_LEARNED resource='..r..' shape='..c.shape..' model='..c.cache_model)
 end
end
-- Narrow cold-start fallback for the two verified rocket pods. Evidence is
-- local to the current hull/reference set and never teaches a session profile.
local ROCKET_RESOURCE='8aff7f0793a5bced'
local function rocket_sample(a,q,id,exists,n,now)
 if a.kind~='new' then return end
 if a.rocket_ref_key~=a.ref_key then a.rocket_ref_key=a.ref_key;a.rack_unknown_since=now end
 if not a.rack_unknown_since then a.rack_unknown_since=now end
 local m=n and n.magazine;local d=n and n.descriptor
 if C.weapon_cache==false or exists==false or resource(n)~=ROCKET_RESOURCE
  or not m or not integer(m.current,10) or not d or d.goid~=id then q.rocket_evidence=nil;return end
 local old=q.rocket_evidence;local same=old and old.ref_key==a.ref_key and now-old.at<=1.2
  and old.descriptor.entity==d.entity and old.descriptor.unit==d.unit
  and old.descriptor.goid==d.goid and old.descriptor.resource==d.resource
 q.rocket_evidence={descriptor=d,current=m.current,at=now,ref_key=a.ref_key,
  samples=same and old.samples+1 or 1,
  decreased=same and (old.decreased or m.current<old.current) or false}
end
function Tank.try_rocket_fallback(a,now)
 if C.weapon_cache==false or a.kind~='new' or not Tank.is_new() or a.ambiguous or #a.refs~=5 then return end
 local complete=#(a.racks or {})==2
 if complete then
  for _,id in ipairs(a.racks)do local c=a.children[id];complete=complete and c and c.value and c.value.ammo~=nil end
 end
 if complete then a.rack_unknown_since=nil;return end
 a.rack_unknown_since=a.rack_unknown_since or now
 local candidates={};local decreased=false
 for _,id in ipairs(a.refs)do
  local q=a.observed and a.observed[id]
  if q and resource(q.native)==ROCKET_RESOURCE then
   local e=q.rocket_evidence;local c=a.children[id]
   if not e or e.ref_key~=a.ref_key or e.samples<2 or now-e.at>1.2 or q.exists==false
    or (c and (c.shape~='rack' or c.cache_rejected)) then return end
   candidates[#candidates+1]={id=id,e=e};decreased=decreased or e.decreased
  end
 end
 if #candidates~=2 or (not decreased and now-a.rack_unknown_since<2) then return end
 local allowed={};for _,v in ipairs(candidates)do allowed[v.id]=true end
 for _,id in ipairs(a.racks or {})do if not allowed[id] then return end end
 for _,v in ipairs(candidates)do
  local c=a.children[v.id]
  -- A healthy channel keeps its existing calibration and sampling schedule.
  if not c or not c.value or c.value.ammo==nil then
   if not Tank.bind_shape(a,v.id,'rack') then return end
   c=a.children[v.id];c.native_descriptor=v.e.descriptor;c.cache_model='magazine_current'
   c.value={ammo=v.e.current};c.at=v.e.at;c.cache_live=true
   log('TANK_ROCKET_FALLBACK hull='..M.hull..' id='..v.id..' reason='..(decreased and 'observed_decrease' or 'unknown_timeout'))
  end
 end
end
local function scalar(x)
 if x==nil then return 'nil' end
 if type(x)=='number' or type(x)=='boolean' then return tostring(x) end
 if type(x)=='table' then return 'table' end
 if type(x)=='string' then return 'str:'..x:gsub('[%s=,;]','_'):sub(1,32) end
 return type(x)
end
local function batch_key(f)
 if type(f)~='table' then return 'nil' end
 local out={};for i=1,33 do out[#out+1]=i..':'..scalar(f[i]) end;return table.concat(out,',')
end
local function native_ammo(n)
 if not n or (not n.magazine and not n.rounds) then return 'nil' end
 local m,r=n.magazine or {},n.rounds or {}
 return table.concat({scalar(m.reserve),scalar(m.current),scalar(r.reserve),scalar(r.rounds_0),scalar(r.rounds_1)},'/')
end
local function batch_ammo(f,shape)
 local v=Tank.decode(shape,f);if not v then return 'nil' end
 return v.ammo and ('rack:'..v.ammo) or (tostring(v.reserve)..'/'..tostring(v.current))
end
function Tank.observe(a,id,exists,f,reason,n,why,batch_attempt,native_attempt)
 a.observed=a.observed or {};local q=a.observed[id] or {};a.observed[id]=q;local now=M.clock
 q.exists=exists;q.role=a.last_role
 if batch_attempt then
  q.batch_attempts=(q.batch_attempts or 0)+1;q.batch_at=now;q.batch_count=dense_count(f);q.batch=nil
  if type(f)=='table' then q.batch_success_at=now;q.batch={};for i=1,33 do q.batch[i]=f[i] end end;q.batch_reason=reason
  q.batch_shape=Tank.shape(f);local key=batch_ammo(f,q.batch_shape)
  if key~='nil' then
   if q.batch_value and q.batch_value~=key then q.batch_change_at=now;q.batch_changes=(q.batch_changes or 0)+1 end
   q.batch_value=key
  end
 end
 if native_attempt then
  rocket_sample(a,q,id,exists,n,now)
  q.native_attempts=(q.native_attempts or 0)+1;q.native_at=now;q.native=n;q.native_reason=why
  if n then q.native_success_at=now end
  local key=native_ammo(n)
  if key~='nil' then
   if q.native_value and q.native_value~=key then q.native_change_at=now;q.native_changes=(q.native_changes or 0)+1 end
   q.native_value=key
  end
 end
 if not C.debug or now<(q.next_log or 0) then return end;q.next_log=now+1
 local d=q.native and q.native.descriptor or {};local m=q.native and q.native.magazine or {};local r=q.native and q.native.rounds or {}
 local c=a.children[id] or {};local bind=(a.gatling and 'gatling' or '-')..'/'..#(a.racks or {})
 local function age(at)return at and string.format('%.2f',now-at) or 'never' end
 local fingerprint=table.concat({scalar(q.exists),scalar(q.role),scalar(q.batch_shape),scalar(q.batch_reason),batch_key(q.batch),
  native_ammo(q.native),scalar(q.native and q.native.state),scalar(d.flags),scalar(q.native_reason),scalar(c.cache_model),scalar(c.shape)},'|')
 if q.last_log==fingerprint and now<(q.heartbeat or 0) then return end
 q.last_log=fingerprint;q.heartbeat=now+5
 local utc=call(os.date,'!%Y-%m-%dT%H:%M:%SZ') or 'unavailable'
 log('TANK_OBSERVE utc='..utc..' t='..string.format('%.3f',now)..' avatar='..tostring(M.avatar)..' hull='..tostring(M.hull)..' role='..tostring(a.last_role)..' id='..id..
  ' bind='..bind..' exists='..scalar(q.exists)..' batch='..scalar(q.batch_reason)..' count='..scalar(q.batch_count)..' shape='..scalar(q.batch_shape)..
  ' batch_attempts='..(q.batch_attempts or 0)..' batch_attempt_age='..age(q.batch_at)..' batch_read_age='..age(q.batch_success_at)..' batch_change_age='..age(q.batch_change_at)..' batch_changes='..(q.batch_changes or 0)..
  ' native='..(q.native and 'ok' or scalar(q.native_reason))..' native_attempts='..(q.native_attempts or 0)..' native_attempt_age='..age(q.native_at)..' native_read_age='..age(q.native_success_at)..
  ' native_change_age='..age(q.native_change_at)..' native_changes='..(q.native_changes or 0)..' resource='..scalar(d.resource)..' entity='..scalar(d.entity)..
  ' unit='..scalar(d.unit)..' flags='..scalar(d.flags)..' magazine='..scalar(m.reserve)..'/'..scalar(m.current)..' rounds='..scalar(r.reserve)..'/'..scalar(r.rounds_0)..'/'..scalar(r.rounds_1)..
  ' state='..scalar(q.native and q.native.state)..' model='..scalar(c.cache_model)..' current_shape='..scalar(c.shape)..' fields='..batch_key(q.batch))
end
function Tank.sync_uncertain(a,id)
 if not a then return false end
 local c=a.children[id];if c and c.cache_rejected then return true end
 if a.last_role==1 then return false end
 local q=a.observed and a.observed[id]
 local changed=q and math.max(q.native_change_at or -1e9,q.batch_change_at or -1e9) or -1e9
 return M.clock-changed>3 -- No recent change is uncertainty, not proof of stale data.
end
function Tank.discover_child(session,a,id,now)
 a.observed=a.observed or {};local q=a.observed[id] or {};a.observed[id]=q
 if now<(q.next_discovery or 0) then return end
 local exists=call(GS.game_object_exists,session,id)
 local f,reason=sample(session,id);local shape=Tank.shape(f)
 -- Read native even when Lua reports absent/nil or batch classification fails.
 -- Contradictory exists=false is logged, never used to bind a HUD channel.
 local n,why,native_attempt
 if C.weapon_cache~=false then n,why=Native.weapon(id);native_attempt=true
 else q.native=nil;q.native_reason='disabled' end
 Tank.observe(a,id,exists,f,reason,n,why,true,native_attempt)
 local count=dense_count(f)
 q.next_discovery=now+((shape=='other' and count~=28 and count~=33) and 5 or .45)
 if exists==false then return end
 if shape=='gatling' or shape=='rack' then
  Tank.accept(a,id,f,now)
  local c=a.children[id]
  if c and n then
   c.native_descriptor=n.descriptor;Tank.cache_pair(c,c.shape,n,Tank.decode(c.shape,f) or {})
   Tank.learn_profile(c,n)
  end
 else
  local p=Tank.profile_for(n)
  if p and Tank.bind_shape(a,id,p.shape) then
   local c=a.children[id];c.native_descriptor=n.descriptor;c.cache_model=p.model;c.state_cache_ok=p.state_ok
   -- Mapping evidence is reusable. Ammo/reload state is always read afresh.
   local v=Tank.cache_candidates(c.shape,n)[c.cache_model]
   if v then c.value=v;c.at=now;c.cache_live=true end
   log('TANK_NATIVE_DISCOVERY hull='..M.hull..' id='..id..' resource='..n.descriptor.resource..' shape='..c.shape..' source=session_resource_profile')
  end
 end
 Tank.try_rocket_fallback(a,now)
end
