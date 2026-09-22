-- Tank variant presentation: static HUD and a separately cached reload overlay.
-- No 144-Hz recreation of the reticle/health/numbers while the ring advances.
Tank.ring_ids={}
function Tank.clear_ring()
 if Tank.ring_gui==M.gui and M.gui then
  for _,p in ipairs(Tank.ring_ids) do call(Gui[p[1]],M.gui,p[2]) end
 end
 Tank.ring_ids={};Tank.ring_key=nil;Tank.ring_gui=nil
end
local function tank_outline(x,y,w,h,a,s)
 rect(x,y,w,s,a);rect(x,y+h-s,w,s,a);rect(x,y,s,h,a);rect(x+w-s,y,s,h,a)
end
function Tank.draw_new(w,h)
 local a=Tank.active;if not a then return end
 local gat=a.gatling and a.children[a.gatling];local g=not a.ambiguous and gat and gat.value
 local ra=a.racks and a.racks[1] and a.children[a.racks[1]]
 local rb=a.racks and a.racks[2] and a.children[a.racks[2]]
 local missiles=not a.ambiguous and ra and rb and ra.value and rb.value and (ra.value.ammo+rb.value.ammo)
 local stale_g=g and M.clock-(gat.at or 0)>Tank.STALE_AFTER or false
 local stale_m=missiles and (M.clock-(ra.at or 0)>Tank.STALE_AFTER or M.clock-(rb.at or 0)>Tank.STALE_AFTER) or false
 local key=table.concat({'new_tank',w,h,a.key,tostring(M.hp),tostring(M.max),g and g.current or '?',
  g and g.reserve or '?',tostring(missiles),tostring(stale_g),tostring(stale_m)},':')
 if key==M.draw_key then return end
 clear()
 local s=math.min(w/1920,h/1080)*C.scale;local x=w/2-180*s;local y=C.offset_y*s;local alpha=C.alpha
 tank_outline(x,y,360*s,16*s,alpha,1.5*s)
 rect(x+3*s,y+3*s,354*s,10*s,.12)
 if M.hp and M.max and M.max>0 then rect(x+3*s,y+3*s,354*s*math.max(0,math.min(1,M.hp/M.max)),10*s,alpha*.66) end
 text(M.hp and (tostring(M.hp)..' / '..tostring(M.max)) or '-- / --',x,y+23*s,18*s,alpha)
 local ga=alpha*(stale_g and .45 or 1)
 for i=0,2 do bullet(x+(168+i*5)*s,y+26*s,.7*s,ga) end
 -- Current belt above; SIX reserve indicators below, never seven.
 local bx=x+190*s;local bw=104*s
 tank_outline(bx,y+34*s,bw,8*s,ga,s)
 if g then rect(bx+2*s,y+36*s,(bw-4*s)*g.current/300,4*s,ga*.82)
 else rect(bx+bw/2-3*s,y+37*s,6*s,s,ga*.6) end
 tank_outline(bx,y+22*s,bw,8*s,ga,s)
 local gap=2*s;local cell=(bw-4*s-gap*5)/6
 for i=0,5 do
  local cx=bx+2*s+i*(cell+gap)
  rect(cx,y+24*s,cell,4*s,ga*(g and i<g.reserve and .82 or .12))
 end
 if not g then rect(bx+bw/2-3*s,y+25*s,6*s,s,ga*.65) end
 -- A short dotted underline denotes last-known, NOT freshly sampled, telemetry.
 if stale_g then for i=0,7 do rect(bx+i*13*s,y+19*s,4*s,s,alpha*.45) end end
 local ma=alpha*(stale_m and .45 or 1)
 bullet(x+314*s,y+25*s,s,ma);text(missiles and tostring(missiles) or '--',x+329*s,y+23*s,18*s,ma)
 if stale_m then for i=0,2 do rect(x+(329+i*7)*s,y+20*s,3*s,s,alpha*.45) end end
 local ds=math.min(w/1920,h/1080)
 disk(w/2,h/2,3.2*ds,.10);disk(w/2,h/2,2.5*ds,.18);disk(w/2,h/2,1.8*ds,.35);disk(w/2,h/2,1.1*ds,.5)
 M.draw_key=key
end
function Tank.draw_ring(w,h)
 local a=Tank.active;local r=a and a.reload
 if not r or r.phase=='idle' then Tank.clear_ring();return end
 local suspended=FRV.grace_until~=nil
 -- Rendering may continue in native display-grace, but state must not advance.
 local progress=r.known_start and math.max(0,math.min(.985,r.elapsed/4)) or nil
 local steps=progress and math.floor(progress*48+.0001) or -1
 local key=table.concat({a.key,w,h,steps,r.phase,tostring(suspended),tostring(M.gui)},':')
 if key==Tank.ring_key then return end
 Tank.clear_ring()
 local saved=M.ids;M.ids={}
 local ok,err=pcall(function()
  local s=math.min(w/1920,h/1080)*C.scale
  -- Standalone reload ring sits LEFT of the reloadable weapon icon/group.
  -- Old main-cannon icon is centered near +31 px; new Gatling group near -5 px.
  -- Keep a visible gap so the ring never crowds the icon or ammo text/bars.
  local cx=w/2+(a.kind=='new' and -25 or 14)*s;local cy=(C.offset_y+31)*s
  local radius=(a.kind=='new' and 8.5 or 8.0)*s
  local alpha=C.alpha*((r.phase=='paused' or r.phase=='uncertain' or suspended) and .5 or .9)
  for i=0,47 do
   local from=math.pi*.5-i*math.pi/24;local to=math.pi*.5-(i+.86)*math.pi/24
   local bright=steps>=0 and i<steps
   -- Unknown initial progress uses a static dotted ring, never a fake percentage.
   if steps>=0 or i%3==0 then
    FRV.line(cx+math.cos(from)*radius,cy+math.sin(from)*radius,
     cx+math.cos(to)*radius,cy+math.sin(to)*radius,1.3*s,bright and alpha or alpha*.2,{255,255,255})
   end
  end
 end)
 Tank.ring_ids=M.ids;M.ids=saved;Tank.ring_gui=M.gui
 if not ok then Tank.clear_ring();error(err,0) end
 Tank.ring_key=key
end
function Tank.draw(w,h)
 if Tank.active and Tank.active.kind=='new' then Tank.draw_new(w,h) else draw(w,h) end
 local ok,err=pcall(Tank.draw_ring,w,h)
 if not ok then
  pcall(Tank.clear_ring)
  if M.clock>=(Tank.ring_error_at or 0) then log('TANK_RING_ERROR '..tostring(err));Tank.ring_error_at=M.clock+10 end
 end
end
