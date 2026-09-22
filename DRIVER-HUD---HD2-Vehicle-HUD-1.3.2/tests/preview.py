"""Render real emitted triangle commands, with a substitute preview font."""
from pathlib import Path
import json, html
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
cases=json.loads((ROOT/'evidence/ui_draw_commands.json').read_text())
S=4; W,H=252,300
canvas=Image.new('RGB',(W*4,H),(23,27,34));cards=[]
labels=['HEALTHY','BODY 75%','BODY 50%','LF + RR DESTROYED']
fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
for c,title in zip(cases,labels):
 im=Image.new('RGBA',(W*S,H*S),(23,27,34,255))
 scale=1.55*S; ox,oy=c['origin_x'],c['origin_y']
 left=(W*S-128*scale)/2;top=57*S
 def point(v):return (left+(v[0]-ox)*scale,top+(124-(v[2]-oy))*scale)
 # Merge same-color adjacent triangles into a single coverage mask. GPU triangle
 # rasterization does not blend their shared diagonal twice (Pillow would).
 groups=[]
 for command in c['commands']:
  a=command['args']
  if command['kind']=='triangle':
   color=tuple(a[5][1:4]+[a[5][0]])
   if not groups or groups[-1][0]!='tri' or groups[-1][1]!=color:groups.append(['tri',color,[]])
   groups[-1][2].append([point(v) for v in a[1:4]])
  else:groups.append(['text',a])
 for g in groups:
  layer=Image.new('RGBA',im.size,(0,0,0,0));d=ImageDraw.Draw(layer)
  if g[0]=='tri':
   for poly in g[2]:d.polygon(poly,fill=g[1])
  else:
   a=g[1];col=a[6];size=round(a[3]*scale);font=ImageFont.truetype(fontpath,size)
   d.text((left+64*scale,top+62*scale),a[1],font=font,anchor='mm',fill=tuple(col[1:4]+[col[0]]))
  im=Image.alpha_composite(im,layer)
 d=ImageDraw.Draw(im);d.text((W*S/2,22*S),title,font=ImageFont.truetype(fontpath,11*S),anchor='mm',fill=(216,226,234))
 im=im.convert('RGB').resize((W,H),Image.Resampling.LANCZOS);cards.append(im)
for j,im in enumerate(cards):canvas.paste(im,(W*j,0))
canvas.save(ROOT/'evidence/frv_ui_preview.png')
text='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>DRIVER HUD 1.3.0 离线UI预览</title><style>body{background:#171b22;color:#dde3ea;font:16px system-ui;margin:40px}img{max-width:100%;height:auto}p{max-width:1000px;line-height:1.8}</style><h1>DRIVER HUD 1.3.0 · FRV</h1><img src="frv_ui_preview.png"><p>从正式 Lua 绘制函数输出的三角形生成。此图为离线检查，不是游戏截图；数字使用预览字体，游戏实际使用自身 debug 字体与 text_extents 居中。</p><p>顺序：健康；车体 50%（黄色）；车体 25%（红色，低耐久轮胎仍存在）；左前/右后轮彻底摧毁（对应轮毂）。没有轮胎数值标签、三段式分隔或车体数字背景块。</p></html>'''
(ROOT/'evidence/UI_PREVIEW.html').write_text(text,encoding='utf-8')
