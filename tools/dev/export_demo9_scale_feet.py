#!/usr/bin/env python3
"""Demo 9 scale/feet shares; compose existing artwork only, never redraw it."""
from pathlib import Path
import hashlib,json,shutil,zipfile
from PIL import Image,ImageDraw,ImageFont,ImageChops
from export_demo9_share import ROOT,ACTORS,SETS,sheet as base_sheet
from export_demo9_teammate_revision import panels
SHARE=ROOT/'docs/demo9-share'
BEFORE=Path('/tmp/demo9-scale-feet-before')
NAMES=['may_brush_strike','void_lash','keeper_unmasked']
written=[]
def sheet(names,cell=(280,420),cols=4,title=''):
 im=base_sheet(names,cell=cell,cols=cols,title=title);d=ImageDraw.Draw(im)
 font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',18)
 heading=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',28)
 if title:
  d.rectangle((0,0,im.width,66),fill=(18,22,28));d.text((24,24),title,font=heading,fill='#e9d19c')
 for i,n in enumerate(names):
  x=24+(i%cols)*(cell[0]+24);y=24+(48 if title else 0)+(i//cols)*(cell[1]+60)+cell[1]
  d.rectangle((x,y,x+cell[0],y+35),fill=(18,22,28));d.text((x,y+6),n.removesuffix('.png'),font=font,fill='#c8beaa')
 return im
def save(im,p):
 p.parent.mkdir(parents=True,exist_ok=True);im.save(p,optimize=True);written.append(str(p.relative_to(ROOT)))
def main():
 for n in NAMES+['may_brush']:
  p=SHARE/'角色-立繪'/f'demo9-share-{n}.png';shutil.copy2(ACTORS/f'{n}.png',p);written.append(str(p.relative_to(ROOT)))
 overview=['may_brush_strike.png','void_lash.png','keeper_unmasked.png','fury_lunge.png','ling_giant.png','detective.png']
 im=sheet(overview,cell=(600,600),cols=3,title='Demo 9 · scale / feet revision')
 save(im,SHARE/'角色-合成/demo9-share-cast-overview.png');save(im,ROOT/'docs/demo9-compare-cast.png')
 all_poses=[]
 for group in ['may','void','fury','ling','keeper']:
  names=SETS[f'demo9-share-cast-{group}.png'];all_poses.extend(names)
  if group not in ['may','void','keeper']:continue
  im=sheet(names,title='Demo 9 · '+group.upper())
  for p in [SHARE/f'角色-合成/demo9-share-cast-{group}.png',SHARE/f'角色-姿勢/demo9-share-{group}-poses.png',ROOT/f'docs/demo9-compare-{group}-poses.png',ROOT/f'docs/demo9-compare-{group}.png']:save(im,p)
 save(sheet(all_poses+['detective.png'],title='Demo 9 · complete cast'),SHARE/'角色-合成/demo9-share-cast-full.png')
 for n in ['may-brush_strike','void-lash','keeper-unmasked']:
  src=ROOT/f'docs/exploration-demo/v9-{n}.png'
  dest=SHARE/f'角色-預覽/demo9-share-preview-{n}.png'
  shutil.copy2(src,dest);written.append(str(dest.relative_to(ROOT)))
 previews=[ROOT/f'docs/exploration-demo/v9-{n}.png' for n in ['may-brush','may-brush_strike','void-lash','fury-lunge','ling-giant']]
 save(panels(previews,[p.stem for p in previews],2,(960,540)),ROOT/'docs/demo9-compare-v9-previews.png')
 # Full original canvases at IDENTICAL scale per before/after pair: no per-image crop/fit.
 font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',28)
 small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',20)
 canvas=Image.new('RGB',(2100,1500),(18,22,28));d=ImageDraw.Draw(canvas)
 d.text((32,15),'Demo 9 · 角色放大／腳朝向修正',font=font,fill='#e9d19c')
 d.text((32,56),'改前／改後使用同一完整畫布與相同比例；來源：本輪開始前備份 vs 遊戲現檔',font=small,fill='#bdb8aa')
 for col,n in enumerate(NAMES):
  x=col*700;d.text((x+24,100),f'{col+1}  {n}',font=font,fill='#e9d19c')
  for row,folder in enumerate([BEFORE,ACTORS]):
   im=Image.open(folder/f'{n}.png').convert('RGBA');s=min(650/im.width,500/im.height)
   tile=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS)
   y=148+row*635;d.text((x+24,y),'改前' if row==0 else '改後',font=font,fill='#f1e7cf')
   canvas.paste(tile,(x+(700-tile.width)//2,y+55+500-tile.height),tile)
   d.rectangle((x+16,y+48,x+684,y+558),outline='#404955',width=1)
  if n=='keeper_unmasked':
   # Foot detail shares the same crop rectangle and scale in both rows.
   for row,folder in enumerate([BEFORE,ACTORS]):
    im=Image.open(folder/f'{n}.png').convert('RGBA').crop((15,1050,485,1270));im.thumbnail((300,150),Image.Resampling.LANCZOS)
    xx=x+380;yy=148+row*635+398
    d.rectangle((xx-5,yy-28,x+680,yy+151),fill='#202630',outline='#77715f')
    d.text((xx,yy-26),'腳部細節',font=small,fill='#e9d19c');canvas.paste(im,(xx,yy),im)
 p=SHARE/'場景-對比/demo9-chars-scale-feet-before-after.png';save(canvas,p)
 # Preserve all other handoff contents, refresh archive after adding comparison.
 with zipfile.ZipFile(ROOT/'docs/demo9-share.zip','w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(SHARE.rglob('*')):
   if p.is_file() and p.suffix!='.import' and p.name!='.DS_Store':z.write(p,p.relative_to(SHARE.parent))
 report={}
 for n in NAMES+['may_brush']:
  p=ACTORS/f'{n}.png';im=Image.open(p);im.load();old=Image.open(BEFORE/f'{n}.png');a=im.getchannel('A');box=a.getbbox()
  assert im.mode=='RGBA' and im.size==old.size and a.getextrema()==(0,255)
  assert p.read_bytes()==(SHARE/f'角色-立繪/demo9-share-{n}.png').read_bytes()
  report[n]={'size':im.size,'mode':im.mode,'bytes':p.stat().st_size,'alpha_bbox_before':old.getchannel('A').getbbox(),'alpha_bbox_after':box,'alpha_covered_pixels_before':sum(v>0 for v in old.getchannel('A').getdata()),'alpha_covered_pixels_after':sum(v>0 for v in a.getdata())}
 old=Image.open(BEFORE/'keeper_unmasked.png');new=Image.open(ACTORS/'keeper_unmasked.png');diff=ImageChops.difference(old,new)
 report['keeper_changed_bbox']=diff.convert('RGB').getbbox();assert not diff.crop((0,0,706,1111)).getbbox()
 initial=json.loads(Path('/tmp/demo9-scale-feet-start-hashes.json').read_text());changed=[]
 for p,h in initial.items():
  if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h:changed.append(p)
 assert set(changed)=={f'assets/environments/exploration/actors/{n}.png' for n in NAMES},changed
 report['changed_assets']=changed;report['untouched_assets_verified']=len(initial)-len(changed)
 report['comparison']={'path':str((SHARE/'場景-對比/demo9-chars-scale-feet-before-after.png').relative_to(ROOT)),'bytes':(SHARE/'場景-對比/demo9-chars-scale-feet-before-after.png').stat().st_size}
 report['updated_shares']=written
 (ROOT/'docs/demo9-scale-feet-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
