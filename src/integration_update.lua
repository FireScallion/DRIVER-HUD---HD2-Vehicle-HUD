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
