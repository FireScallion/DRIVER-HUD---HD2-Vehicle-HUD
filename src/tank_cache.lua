-- Bounded cache evaluation tied to the already bound child. Paired observations
-- choose a channel; a later disagreement revokes it without hiding the HUD.
function Tank.cache_candidates(kind,n)
 local out={};local m=n and n.magazine;local r=n and n.rounds
 if kind=='gatling' then
  if m and integer(m.reserve,6) and integer(m.current,300) then out.magazine={reserve=m.reserve,current=m.current} end
 else
  if m then
   if integer(m.current,10) then out.magazine_current={ammo=m.current} end
   if integer(m.reserve,10) then out.magazine_reserve={ammo=m.reserve} end
  end
  if r then
   if integer(r.reserve,10) then out.rounds_reserve={ammo=r.reserve} end
   if integer(r.rounds_0,10) then out.rounds_0={ammo=r.rounds_0} end
   if integer(r.rounds_1,10) then out.rounds_1={ammo=r.rounds_1} end
  end
 end
 return out
end
local function equivalent(a,b,kind)
 return a and b and (kind=='gatling' and a.current==b.current and a.reserve==b.reserve or kind=='rack' and a.ammo==b.ammo)
end
function Tank.cache_pair(c,kind,n,v)
 if c.cache_rejected then return end
 local choices=Tank.cache_candidates(kind,n)
 if c.cache_model and not equivalent(choices[c.cache_model],v,kind) then
  log('TANK_CACHE_REVOKED reason=batch_disagreement model='..c.cache_model)
  c.cache_model=nil;c.cache_live=false;c.cache_rejected=true;c.state_cache_ok=false;return
 end
 local remaining={};local count,name=0,nil
 for k,x in pairs(choices) do
  if equivalent(x,v,kind) and (not c.cache_choices or c.cache_choices[k]) then remaining[k]=true;count=count+1;name=k end
 end
 c.cache_choices=remaining;c.cache_pairs=(c.cache_pairs or 0)+1
 if count==1 and c.cache_pairs>=2 and not c.cache_model then c.cache_model=name;log('TANK_CACHE_BOUND model='..name..' paired='..c.cache_pairs) end
 if kind=='gatling' and v.state~=nil and n.state~=nil then
  -- These are separate reads of independently updated stores. Once the field
  -- mapping is validated, a transition mismatch cannot invalidate that mapping.
  -- The native reader still validates owner identity, component and state range.
  if n.state~=v.state then
   c.state_pairs=0
   if not c.state_disagreement then log('TANK_RELOAD_PAIR_GAP native='..n.state..' batch='..v.state..' validated='..tostring(c.state_cache_ok==true)) end
   c.state_disagreement=true
  else
   c.state_disagreement=nil;c.state_pairs=(c.state_pairs or 0)+1
   if c.state_pairs>=2 then c.state_cache_ok=true end
  end
 end
end
function Tank.sample_child(session,a,id,name,now)
 if not id then return end
 local c=a.children[id];if not c then return end
 local exists=call(GS.game_object_exists,session,id)
 if exists==false then
  a.children[id]=nil;if a.gatling==id then a.gatling=nil;a.reload=Tank.new_reload('new') end
  local racks={};for _,v in ipairs(a.racks or {}) do if v~=id then racks[#racks+1]=v end end;a.racks=racks
  log('TANK_CHANNEL_LOST channel='..name..' goid='..id);return
 end
 -- An unavailable Lua exists() result does not block an independently validated native read.
 if C.weapon_cache==false then c.cache_live=false end
 local n,why,native_attempt
 if C.weapon_cache~=false and (not c.cache_rejected or C.debug) and now>=(c.next_cache or 0) then
  native_attempt=true;c.next_cache=now+(c.cache_rejected and 1 or .1)
  n,why=Native.weapon(id,c.native_descriptor)
  if n then c.native_descriptor=n.descriptor end
  c.cache_live=not c.cache_rejected and n~=nil and c.cache_model~=nil and Tank.cache_candidates(c.shape,n)[c.cache_model]~=nil
  if why and (c.cache_error~=why or now>=(c.cache_log_at or 0)) then
   log('TANK_CACHE_GAP channel='..name..' reason='..tostring(why));c.cache_error=why;c.cache_log_at=now+10
  end
 end
 local v,source,f,reason,batch_attempt
 if C.weapon_cache==false or not c.cache_live or now>=(c.next_compare or 0) then
  c.next_compare=now+1
  batch_attempt=true;f,reason=sample(session,id)
  v=Tank.shape(f)==c.shape and Tank.decode(c.shape,f) or nil
  if v then
   -- Select one source before feeding the reload machine. Feeding the batch
   -- here could reset an active native reload with a delayed idle value.
   source='batch'
   if n then Tank.cache_pair(c,c.shape,n,v);Tank.learn_profile(c,n) end
  end
 end
 if n and c.cache_model and not c.cache_rejected then
  local x=Tank.cache_candidates(c.shape,n)[c.cache_model]
  if x then
   local batch_state=v and v.state
   v=x;source='component_cache';c.cache_live=true
   if c.shape=='gatling' then
    local p=Tank.profile_for(n)
    if p and p.shape==c.shape and p.model==c.cache_model and p.state_ok then c.state_cache_ok=true end
    if c.state_cache_ok and n.state~=nil then v.state=n.state
    else v.state=batch_state end
   end
  end
 end
 Tank.observe(a,id,exists,f,reason,n,why,batch_attempt,native_attempt)
 local d=a.diag[name] or {attempts=0,valid=0,gaps=0};a.diag[name]=d
 d.attempts=d.attempts+1
 if v then
  local value_key=v.ammo and tostring(v.ammo) or (tostring(v.current)..'/'..tostring(v.reserve))
  if d.value_key and d.value_key~=value_key then d.changes=(d.changes or 0)+1 end;d.value_key=value_key
  d.valid=d.valid+1;d.last_at=now;d.last=source..':'..(v.ammo and ('ammo='..v.ammo) or ('cur='..v.current..',res='..v.reserve..',state='..tostring(v.state)))
  c.value=v;c.at=now
  if c.shape=='gatling' then
   Tank.feed_reload(a.reload,v,now)
   if v.state~=nil and a.last_reload_log~=v.state then
    log('TANK_TELEM_STATE channel=gatling role='..tostring(a.last_role)..' new='..v.state..' source='..source);a.last_reload_log=v.state
   end
  end
 else d.gaps=d.gaps+1 end
end
