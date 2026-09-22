-- Numeric HUD glyphs use the SAME triangle/material/GUI path as the surrounding
-- shapes. This compatibility path does not depend on the debug-font material
-- transform. HUD Curve still requires live-game visual verification; no HUD
-- setting is written, and no game font data is copied.
local HudNumber = (function()
 local H={};local WHITE={255,255,255}
 local segments={{{0,1},{1,1}},{{1,1},{1,.5}},{{1,.5},{1,0}},{{0,0},{1,0}},{{0,.5},{0,0}},{{0,1},{0,.5}},{{0,.5},{1,.5}},{{0,0},{1,1}}}
 local glyphs={['0']={1,2,3,4,5,6},['1']={2,3},['2']={1,2,7,5,4},['3']={1,2,7,3,4},['4']={6,7,2,3},['5']={1,6,7,3,4},['6']={1,6,7,5,3,4},['7']={1,2,3},['8']={1,2,3,4,5,6,7},['9']={1,2,3,4,6,7},['-']={7},['/']={8},[' ']={}}
 -- Cache only small, normalized glyph geometry. No engine IDs or transient
 -- Vector userdata is cached here, and bounds include actual stroke width.
 local font={};local thickness=.085;local cw=.43;local advance=.63
 for ch,indices in pairs(glyphs) do
  local g={quads={},xmin=math.huge,ymin=math.huge,xmax=-math.huge,ymax=-math.huge,advance=ch==' ' and .32 or advance}
  for _,i in ipairs(indices) do
   local p,q=segments[i][1],segments[i][2]
   local x1,y1,x2,y2=p[1]*cw,p[2],q[1]*cw,q[2]
   local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
   local nx,ny=-dy/length*thickness/2,dx/length*thickness/2
   local quad={{x1+nx,y1+ny},{x1-nx,y1-ny},{x2+nx,y2+ny},{x2-nx,y2-ny}}
   g.quads[#g.quads+1]=quad
   for _,v in ipairs(quad) do g.xmin=math.min(g.xmin,v[1]);g.xmax=math.max(g.xmax,v[1]);g.ymin=math.min(g.ymin,v[2]);g.ymax=math.max(g.ymax,v[2]) end
  end
  font[ch]=g
 end
 function H.bounds(label,size)
  if type(label)~='string' or #label>32 or type(size)~='number' or size~=size or size<=0 or size>10000 then return nil end
  local at,xmin,ymin,xmax,ymax=0,math.huge,math.huge,-math.huge,-math.huge
  for i=1,#label do
   local g=font[label:sub(i,i)];if not g then return nil end
   if #g.quads>0 then xmin=math.min(xmin,at+g.xmin);xmax=math.max(xmax,at+g.xmax);ymin=math.min(ymin,g.ymin);ymax=math.max(ymax,g.ymax) end
   at=at+g.advance
  end
  if xmin==math.huge then return nil end
  return xmin*size,ymin*size,xmax*size,ymax*size
 end
 function H.draw(label,x,y,size,a,c,anchor)
  local xmin,ymin,xmax,ymax=H.bounds(label,size);if xmin==nil then return false end
  local ox,oy=x-xmin,y
  if anchor=='center' then ox=x-(xmin+xmax)/2;oy=y-(ymin+ymax)/2 end
  c=c or WHITE
  local color=Color(math.floor(a*255),c[1],c[2],c[3]);local at=0
  local function emit(p,q,r)
   local uv=V2(.5,0)
   remember('destroy_triangle',Gui.triangle(M.gui,V3(ox+(at+p[1])*size,0,oy+p[2]*size),V3(ox+(at+q[1])*size,0,oy+q[2]*size),V3(ox+(at+r[1])*size,0,oy+r[2]*size),3,color,material,uv,uv,uv))
  end
  for i=1,#label do
   local g=font[label:sub(i,i)]
   for _,q in ipairs(g.quads) do emit(q[1],q[2],q[3]);emit(q[2],q[4],q[3]) end
   at=at+g.advance
  end
  return true
 end
 return H
end)()
