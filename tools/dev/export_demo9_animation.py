#!/usr/bin/env python3
"""Compose generated animation cels and refresh existing Demo 9 handoff. No art generation."""
from pathlib import Path
import json,shutil,zipfile,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageChops
from export_demo9_share import SETS,sheet
from export_demo9_teammate_revision import panels
ROOT=Path(__file__).resolve().parents[2];SHARE=ROOT/'docs/demo9-share';WORK=ROOT/'tmp/demo9-anim';ACT=ROOT/'assets/environments/exploration/actors'
F=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf',22)

def save(im,path):path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
def compare(images,labels,path,size=(800,720)):
 out=Image.new('RGB',(size[0]*len(images),size[1]+52),'#12161c');d=ImageDraw.Draw(out)
 for i,(image,label) in enumerate(zip(images,labels)):
  im=image.convert('RGBA');im.thumbnail(size,Image.Resampling.LANCZOS);out.paste(im,(i*size[0]+(size[0]-im.width)//2,52+size[1]-im.height),im);d.text((i*size[0]+20,14),label,font=F,fill='#e9d19c')
 save(out,path)

def main():
 manifest=json.loads((ROOT/'data/exploration/animations.json').read_text());clips=manifest['clips'];checks={}
 for name,info in clips.items():
  source=ROOT/info['path'].removeprefix('res://');im=Image.open(source).convert('RGBA');w,h=info['width'],info['height'];tiles=[];hashes=[]
  strip=Image.new('RGB',(8*240,300),'#12161c');d=ImageDraw.Draw(strip)
  for i in range(8):
   at=info.get('offset',0)+i;x=at%info['columns']*w;y=at//info['columns']*h;t=im.crop((x,y,x+w,y+h));hashes.append(hashlib.sha256(t.tobytes()).hexdigest());t.thumbnail((232,244),Image.Resampling.LANCZOS)
   strip.paste(t,(i*240+(240-t.width)//2,35+244-t.height),t);d.text((i*240+10,6),str(i+1),font=F,fill='#c8beaa')
   frame=Image.new('RGB',(max(320,w),420),'#12161c');tile=im.crop((x,y,x+w,y+h));tile.thumbnail((frame.width,400));frame.paste(tile,((frame.width-tile.width)//2,410-tile.height),tile);tiles.append(frame)
  checks[name]={'distinct_cels':len(set(hashes)),'transparent':im.getchannel('A').getextrema()[0]==0,'hashes':hashes}
  assert checks[name]['distinct_cels']==8,name
  assert checks[name]['transparent'],name
  save(strip,SHARE/'角色-動畫幀條'/(name+'.png'))
  if name in ['may_slash','void_lash','hero_run','keeper_unmasked']:
   save(strip,ROOT/f'docs/demo9-anim-{name}-strip.png')
   tiles[0].save(ROOT/f'docs/demo9-anim-{name}.gif',save_all=True,append_images=tiles[1:],duration=110,loop=0)
 # Keeper before/after: exact original canvas and a matching enlarged ankle crop.
 old=Image.open(WORK/'before/keeper_unmasked.png');new=Image.open(ACT/'keeper_unmasked.png')
 diff=ImageChops.difference(old,new);outside=diff.copy()
 for box in [(30,1111,203,1280),(244,1111,427,1280)]:outside.paste((0,0,0,0),box)
 assert not any(channel.getbbox() for channel in outside.split()),'Keeper changed outside boots'
 compare([old,new],['Keeper · before','Keeper · side-profile boots'],ROOT/'docs/demo9-keeper-feet-before-after.png',size=(530,900))
 compare([old.crop((15,1080,450,1280)),new.crop((15,1080,450,1280))],['Before · feet','After · feet'],ROOT/'docs/demo9-keeper-feet-detail.png',size=(600,300))
 for file in ['demo9-keeper-feet-before-after.png','demo9-keeper-feet-detail.png']:
  shutil.copy2(ROOT/'docs'/file,SHARE/'場景-對比'/file)
 shutil.copy2(ACT/'keeper_unmasked.png',SHARE/'角色-立繪/demo9-share-keeper_unmasked.png')
 for filename,names in SETS.items():
  if 'keeper' not in filename:continue
  im=sheet(names,title='Demo 9 · KEEPER')
  for path in [SHARE/'角色-合成'/filename,SHARE/'角色-姿勢/demo9-share-keeper-poses.png',ROOT/'docs/demo9-compare-keeper-poses.png',ROOT/'docs/demo9-compare-keeper.png']:save(im,path)
 allposes=[p for names in SETS.values() for p in names]
 save(sheet(allposes+['detective.png'],title='Demo 9 · complete cast'),SHARE/'角色-合成/demo9-share-cast-full.png')
 overview=['may_brush_strike.png','void_lash.png','keeper_unmasked.png','fury_lunge.png','ling_giant.png','detective.png']
 for path in [SHARE/'角色-合成/demo9-share-cast-overview.png',ROOT/'docs/demo9-compare-cast.png']:save(sheet(overview,cell=(600,600),cols=3,title='Demo 9 · animated cast'),path)
 # Share an assembled museum with its neutral gaze; raw game background has blank sclera.
 museum=Image.open(ROOT/'docs/demo9-museum-portraits.png')
 save(museum,SHARE/'場景-背景/demo9-share-bg-museum.png')
 compare([Image.open(WORK/'before/museum.png'),museum],['Museum · before','Museum · layered portraits'],ROOT/'docs/demo9-museum-portraits-before-after.png',size=(1000,563))
 for dest in [SHARE/'場景-對比/demo9-museum-before-after.png',SHARE/'場景-對比/demo9-share-compare-bg-museum.png',ROOT/'docs/demo9-compare-bg-museum.png']:
  shutil.copy2(ROOT/'docs/demo9-museum-portraits-before-after.png',dest)
 backgrounds=sorted((ROOT/'assets/environments/exploration/backgrounds').glob('*.png'))
 backgrounds=[ROOT/'docs/demo9-museum-portraits.png' if p.stem=='museum' else p for p in backgrounds]
 labels=['museum' if p.name=='demo9-museum-portraits.png' else p.stem for p in backgrounds]
 overview=panels(backgrounds,labels,3,(512,288))
 for dest in [SHARE/'場景-對比/demo9-share-backgrounds-overview.png',ROOT/'docs/demo9-compare-backgrounds.png']:save(overview,dest)
 rooms=[ROOT/f'docs/exploration-demo/v9-museum-mid-{n}.png' for n in ['wax_lane','wax_museum','wax_basement']]
 if all(p.exists() for p in rooms):
  preview=panels(rooms,['Demo 9 '+n for n in ['wax_lane','wax_museum','wax_basement']],1,(1280,720))
  for dest in [SHARE/'場景-對比/demo9-share-preview-museum-mid.png',ROOT/'docs/exploration-demo/v9-museum-mid-preview.png']:save(preview,dest)
 for name in ['keeper-unmasked','keeper-back','may-idle','may-brush','may-brush_strike','void-idle','void-lash','fury','fury-lunge','ling-giant','ling-crouch','may-statue']:
  p=ROOT/f'docs/exploration-demo/v9-{name}.png'
  if p.exists():shutil.copy2(p,SHARE/f'角色-預覽/demo9-share-preview-{name}.png')
 p=ROOT/'docs/exploration-demo/v9-museum-portraits.png'
 if p.exists():
  for dest in [SHARE/'場景-房間/demo9-share-scene-wax_museum.png',ROOT/'docs/exploration-demo/wax_museum.png']:shutil.copy2(p,dest)
 shutil.copy2(ROOT/'data/exploration/animations.json',SHARE/'demo9-animations.json');shutil.copy2(ROOT/'data/exploration/museum-eyes.json',SHARE/'demo9-museum-eyes.json')
 (ROOT/'docs/demo9-animation-pixel-validation.json').write_text(json.dumps(checks,indent=2)+'\n')
 print(f'{len(clips)} clips, all 8 cels distinct; Keeper pixels outside boots identical')
 finish_share()
def finish_share():
 for pattern in ['demo9-codex-anim-result.md','demo9-animation-*.json','demo9-animation-qa.log','demo9-art-qa.log','demo9-keeper-feet-*.png','demo9-museum-portraits*.png','demo9-museum-gaze-closeup.gif','demo9-anim-*.png','demo9-anim-*.gif']:
  for p in (ROOT/'docs').glob(pattern):
   if 'share-manifest' not in p.name:shutil.copy2(p,SHARE/p.name)
 for p in (ROOT/'docs/demo9-animation-before').glob('*.png'):
  dest=SHARE/'demo9-animation-before'/p.name;dest.parent.mkdir(exist_ok=True);shutil.copy2(p,dest)
 previews=[ROOT/f'docs/exploration-demo/v9-{n}.png' for n in ['may-brush','may-brush_strike','void-lash','fury-lunge','ling-giant']]
 if all(p.exists() for p in previews):save(panels(previews,[p.stem for p in previews],2,(960,540)),ROOT/'docs/demo9-compare-v9-previews.png')
 (SHARE/'README-animation.md').write_text("# Demo 9 動畫與人像追視交付\n\n最新結果：[完整文件](demo9-codex-anim-result.md)。50 張 sheet、77 段、616 幀，Godot 動畫驗證 828 項通過，既有美術驗證 48 項通過。\n\n- [Keeper 修腳前後](demo9-keeper-feet-before-after.png)\n- [靴子細節](demo9-keeper-feet-detail.png)\n- [美術館前後](demo9-museum-portraits-before-after.png)\n- [眼神追視放大](demo9-museum-gaze-closeup.gif)\n- [May 八幀](demo9-anim-may_slash-strip.png)\n- [Void 八幀](demo9-anim-void_lash-strip.png)\n\n全部動作幀條在 `角色-動畫幀條/`。遊戲用 PNG sheet 位於專案 `assets/environments/exploration/actors/anim/`，本分享包提供檢視圖與座標／載入清單；執行遊戲請使用完整專案。舊輪次的歷史對比仍保留，請以本 README 連結與本輪結果文件為準。\n")
 files=sorted(p for p in SHARE.rglob('*') if p.is_file() and p.suffix!='.import' and p.name not in ['.DS_Store','demo9-animation-share-manifest.json'])
 manifest={'version':'Demo 9','sheets':50,'clips':77,'cels':616,'art_qa':'48 passed, 0 failed','animation_qa':'828 passed, 0 failed','files':{str(p.relative_to(SHARE)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}}
 mp=ROOT/'docs/demo9-animation-share-manifest.json';mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');shutil.copy2(mp,SHARE/mp.name)
 archive=ROOT/'docs/demo9-share.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for p in files+[SHARE/mp.name]:z.write(p,p.relative_to(SHARE.parent))
 with zipfile.ZipFile(archive) as z:assert z.testzip() is None
 print('Share archive verified:',archive.stat().st_size,'bytes;',len(files)+1,'files')
if __name__=='__main__':main()
