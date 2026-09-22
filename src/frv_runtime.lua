-- The vehicle resolver owns identity. Health failure never invokes a second resolver.
local FRV = {next_poll=0}
FRV.profiles={["cc21c7ffd3ebefb9"]={name="hmg_frv",t="MJAkcNku",fields={"50ac6619","a09ccd0a","b19ad128","d7082cbf","dab52fe8","0565f571","169d5ed7","82830aed","cad5b537","9ddf0683","95417727","a5f83fa0","9256767e","7f6b358d","788b9753","99901914","1dd07f05","39d141d6","98b4aaf0","e144c5e3","6fa852e3","6d2d83f8","7d9563dd","d8819b3e","cb0453ea","9d550ad3","bbecde19","8fd2d63e","c336a25c","af4c7e8a","0d4e190d","308e0842","0c0bd772","d9810f60","3b5a954f","6396946a","791943f0","91f98cec","7615f45d","eeb1225e","cca43d10","5a8871e3","e00857ad","d648e3a3","4828beb2","8db8f9a4","13daabe6","b23ad39c","ad7ddda8","fafc1456","b8ba2a04","5b7d5691","da1ad977","256605bd","dba62235","da68ae40","42f493f9","69a28ffa","93699a9f","f4b46247","f299681b","6ed6cc5a","bd5b4583","3ccffa7f"}},["9b2140378640432e"]={name="supply_frv",t="3LHk6DNB",fields={"50ac6619","a09ccd0a","b19ad128","d7082cbf","dab52fe8","0565f571","169d5ed7","82830aed","cad5b537","9ddf0683","95417727","a5f83fa0","9256767e","7f6b358d","788b9753","99901914","1dd07f05","39d141d6","98b4aaf0","e144c5e3","6d2d83f8","7d9563dd","d8819b3e","cb0453ea","9d550ad3","bbecde19","8fd2d63e","c336a25c","af4c7e8a","0d4e190d","308e0842","0c0bd772","d9810f60","3b5a954f","6396946a","791943f0","91f98cec","7615f45d","eeb1225e","cca43d10","5a8871e3","e00857ad","d648e3a3","4828beb2","8db8f9a4","13daabe6","b23ad39c","ad7ddda8","fafc1456","b8ba2a04","5b7d5691","da1ad977","256605bd","dba62235","da68ae40","42f493f9","69a28ffa","93699a9f","f4b46247","f299681b","6ed6cc5a","bd5b4583","3ccffa7f","69889752","a5ae4500"}}}
FRV.profile_resources={['cc21c7ffd3ebefb9']=true,['9b2140378640432e']=true}
-- Only this already observed Bastion resource gets the early direct path.
FRV.tank_resources={['16474112801385b6']=true,['b0c9faf4af8903f9']=true}
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
 FRV.last_relation=nil;FRV.relation_at=nil;FRV.relation_session=nil;FRV.relation_avatar=nil;FRV.grace_until=nil
 FRV.invalidate('context_reset');FRV.next_poll=0;FRV.mode=nil;FRV.identity_key=nil;FRV.block_legacy=false;FRV.native_seen=false;FRV.proxy_key=nil;FRV.proxy_vehicle=nil;FRV.proxy_retry=0;FRV.proxy_log=nil
end
function FRV.drop_tank()
 if Tank then Tank.detach() end
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
function FRV.body_valid(hp,mx)
 return type(mx)=='number' and mx==math.floor(mx) and mx>0 and mx<=10000000
  and type(hp)=='number' and hp==math.floor(hp) and hp>=0 and hp<=mx
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
 if not FRV.body_valid(hp,mx) then hp=data and data.body end
 if FRV.body_valid(hp,mx) then FRV.hp=hp;FRV.max=mx else FRV.hp=nil;FRV.max=nil end
 if data then
  local valid_bits={}
  for i=1,4 do valid_bits[i]=(not data.hp_valid or data.hp_valid[i]~=false) and '1' or '0' end
  local valid_text=table.concat(valid_bits,'')
  local sync_status=data.sync_valid and 'OK' or tostring(data.sync_error or 'unavailable')
  local key=table.concat({d.entity,d.goid,data.flags,tostring(data.synced_flags),data.precision,sync_status,table.concat(data.hp,','),valid_text,table.concat(data.max,','),table.concat(data.q or {},','),table.concat(data.damage,','),tostring(FRV.hp)},'|')
  if key~=FRV.log_key and M.clock>=(FRV.log_at or 0) then
   log('FRV_STATE resource='..d.resource..' entity='..d.entity..' goid='..d.goid..' authority_bit0='..tostring(data.flags%2==1)
    ..' precision='..data.precision..' sync='..sync_status..' hp='..table.concat(data.hp,',')..' hp_valid='..valid_text..' max='..table.concat(data.max,',')
    ..' q2='..table.concat(data.q or {},',')..' damage='..table.concat(data.damage,',')..' body='..tostring(FRV.hp)
    ..' health_index='..data.health_index..' read_bytes='..data.bytes..' read_calls='..data.calls)
   FRV.log_key=key;FRV.log_at=M.clock+0.5
  end
 end
end
function FRV.poll_tank(session,d)
 -- poll() has just validated the same native relation and clears M.hull on
 -- identity change. refresh_bound owns ongoing HP/weapon sampling and expiry.
 if FRV.mode=='TANK' and M.hull and M.vehicle_ref==d.goid and valid_goid(session,M.hull) then
  return 'TANK'
 end
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
function FRV.clear_identity(reason)
 FRV.grace_until=nil;FRV.last_relation=nil;FRV.relation_at=nil;FRV.identity_key=nil
 FRV.proxy_key=nil;FRV.proxy_vehicle=nil;FRV.proxy_retry=0;FRV.proxy_log=nil
 FRV.invalidate(reason);FRV.drop_tank();FRV.mode='NONE'
end
function FRV.can_hold(session,avatar)
 if FRV.relation_session~=session or FRV.relation_avatar~=avatar then return false end
 if not FRV.last_relation or not valid_goid(session,FRV.last_relation.vehicle.goid) then return false end
 if FRV.mode=='FRV' then
  return FRV.vehicle~=nil and valid_goid(session,FRV.vehicle.goid)
 elseif FRV.mode=='TANK' then return valid_goid(session,M.hull) end
 return false
end
function FRV.poll(session,avatar)
 -- Check expiry every frame, not just at 10 Hz: a stalled poll cannot extend grace.
 if FRV.grace_until and (M.clock>=FRV.grace_until or not FRV.can_hold(session,avatar)) then
  FRV.clear_identity('native_read_grace_expired')
 end
 if M.clock<FRV.next_poll then return FRV.mode end
 FRV.next_poll=M.clock+0.1 -- Time based, no catch-up burst and no whole-world scan.
 local relation,why,kind=Native.relation(avatar,M.clock,FRV.last_relation)
 if not relation then
  if FRV.last_error~=why or M.clock>=(FRV.native_error_at or 0) then
   log('NATIVE_UNAVAILABLE kind='..tostring(kind)..' reason='..tostring(why));FRV.last_error=why;FRV.native_error_at=M.clock+10
  end
  if kind=='TRANSIENT_READ' and FRV.last_relation and FRV.relation_at
   and M.clock<FRV.relation_at+0.3 and FRV.can_hold(session,avatar) then
   if not FRV.grace_until then log('NATIVE_READ_GRACE seconds=0.3 mode='..FRV.mode) end
   FRV.grace_until=FRV.relation_at+0.3
   return FRV.mode -- Display only: no Health refresh or alternative vehicle search.
  end
  -- Once a native relation was in use, a missed read must NOT revive stale tank
  -- references/ownership hints. Only a verified relation or explicit exit resets it.
  if FRV.native_seen or FRV.block_legacy then
   FRV.clear_identity('native_identity_unavailable')
  else FRV.mode='LEGACY' end
  return FRV.mode
 end
 FRV.last_error=nil;FRV.grace_until=nil
 if relation.status=='NO_SEATER' then
  FRV.last_relation=nil;FRV.relation_at=nil
  if FRV.native_seen then FRV.clear_identity('seater_gone')
  else FRV.mode='LEGACY' end
  return FRV.mode
 end
 FRV.native_seen=true
 if relation.status~='VEHICLE' then
  FRV.clear_identity('collection_empty');FRV.identity_key=nil;return FRV.mode
 end
 FRV.last_relation=relation;FRV.relation_at=M.clock;FRV.relation_session=session;FRV.relation_avatar=avatar
 local collection=relation.vehicle
 local proxy_key=table.concat({avatar,relation.avatar.entity,collection.entity,collection.goid,collection.resource,collection.unit},':')
 if FRV.identity_key~=proxy_key then
  FRV.invalidate('identity_changed');FRV.drop_tank();FRV.identity_key=proxy_key
  FRV.proxy_key=nil;FRV.proxy_vehicle=nil;FRV.proxy_retry=0;FRV.proxy_log=nil
  log('NATIVE_VEHICLE avatar='..avatar..' avatar_entity='..relation.avatar.entity..' entity='..collection.entity..' goid='..collection.goid..' resource='..collection.resource..' unit='..tostring(collection.unit)..' role_raw='..relation.role)
 end
 local d=collection
 local p=FRV.profiles[d.resource]
 if not p and (FRV.tank_resources[collection.resource]
  or call(GS.game_object_is_type,session,collection.goid,'rHVbvgIu')==true
  or call(GS.game_object_is_type,session,collection.goid,'fZwFCDKT')==true) then
  return FRV.poll_tank(session,collection)
 end
 if not p then
  -- Unknown resources still keep proxy-first precedence; a weak tank-shaped
  -- sample must not steal a successfully resolvable FRV proxy.
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
 return FRV.poll_tank(session,collection)
end
