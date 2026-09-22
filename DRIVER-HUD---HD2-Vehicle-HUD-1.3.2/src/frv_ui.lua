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
