#!/usr/bin/env python3
"""Refresh Demo 9 teammate revision shares from the final in-game assets.

Run after validate_v9_art.gd and validate_v9_museum_mid.gd with a display.
This script only copies, resizes and lays out existing image_gen artwork.
"""
from pathlib import Path
import json
import shutil
import zipfile
from PIL import Image, ImageDraw
from export_demo9_share import ROOT, ACTORS, MID, BG, SETS, sheet, side_by_side

SHARE = ROOT / 'docs/demo9-share'
PREVIEW = ROOT / 'docs/exploration-demo'
CHANGED = ['may_brush','may_brush_strike','void_lash','fury_lunge','ling_giant']
written = []

def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, 'PNG', optimize=True)
    written.append(str(path.relative_to(ROOT)))

def copy(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
    written.append(str(dest.relative_to(ROOT)))

def panels(paths, labels, columns=2, cell=(768,432)):
    rows = (len(paths)+columns-1)//columns
    canvas = Image.new('RGB',(columns*cell[0],rows*(cell[1]+36)),(18,22,28))
    draw = ImageDraw.Draw(canvas)
    for i,(path,label) in enumerate(zip(paths,labels)):
        im = Image.open(path).convert('RGBA')
        im.thumbnail(cell,Image.Resampling.LANCZOS)
        x,y=(i%columns)*cell[0],(i//columns)*(cell[1]+36)
        canvas.paste(im,(x+(cell[0]-im.width)//2,y),im)
        draw.text((x+12,y+cell[1]+8),label,fill=(230,210,170))
    return canvas

def main():
    for name in CHANGED:
        copy(ACTORS/(name+'.png'),SHARE/'角色-立繪'/('demo9-share-'+name+'.png'))
    overview=['may_brush_strike.png','void_lash.png','keeper_unmasked.png',
              'fury_lunge.png','ling_giant.png','detective.png']
    save(sheet(overview,cell=(300,420),cols=6,title='Demo 9 · teammate art revision'),
         SHARE/'角色-合成/demo9-share-cast-overview.png')
    all_poses=[]
    for group in ['may','void','fury','ling']:
        names=SETS['demo9-share-cast-'+group+'.png']
        all_poses.extend(names)
        im=sheet(names,title='Demo 9 · '+group.upper())
        save(im,SHARE/'角色-合成'/('demo9-share-cast-'+group+'.png'))
        save(im,SHARE/'角色-姿勢'/('demo9-share-'+group+'-poses.png'))
        save(im,ROOT/'docs'/('demo9-compare-'+group+'-poses.png'))
        save(im,ROOT/'docs'/('demo9-compare-'+group+'.png'))
    all_poses += SETS['demo9-share-cast-keeper.png']+['detective.png']
    save(sheet(all_poses,title='Demo 9 · complete cast'),SHARE/'角色-合成/demo9-share-cast-full.png')
    save(sheet(overview,cell=(300,420),cols=6,title='Demo 9 · teammate art revision'),ROOT/'docs/demo9-compare-cast.png')

    copy(BG/'museum.png',SHARE/'場景-背景/demo9-share-bg-museum.png')
    for name in ['museum_mid','museum_depth']:
        copy(MID/(name+'.png'),SHARE/'場景-中景'/('demo9-share-mid-'+name+'.png'))
    copy(ROOT/'assets/environments/exploration/terrain/museum_flat.png',
         SHARE/'場景-中景/demo9-share-museum-flat-platform.png')
    atlas=side_by_side([MID/'museum_mid.png',MID/'museum_depth.png'],['Demo 9 museum_mid','Demo 9 museum_depth'],640)
    save(atlas,SHARE/'場景-對比/demo9-share-museum-mid.png')
    before=ROOT/'tmp/demo9-art-revision/before/backgrounds/museum.png'
    if before.exists():
        compare=panels([before,BG/'museum.png'],['Demo 9 before revision','Demo 9 revised horizontal gallery'])
        save(compare,SHARE/'場景-對比/demo9-share-compare-bg-museum.png')
        save(compare,ROOT/'docs/demo9-compare-bg-museum.png')
    backgrounds=sorted(BG.glob('*.png'))
    bg_overview=panels(backgrounds,[p.stem for p in backgrounds],3,(512,288))
    save(bg_overview,SHARE/'場景-對比/demo9-share-backgrounds-overview.png')
    save(bg_overview,ROOT/'docs/demo9-compare-backgrounds.png')
    rooms=[PREVIEW/('v9-museum-mid-'+name+'.png') for name in ['wax_lane','wax_museum','wax_basement']]
    if all(p.exists() for p in rooms):
        room_grid=panels(rooms,['Demo 9 '+name for name in ['wax_lane','wax_museum','wax_basement']],1,(1280,720))
        save(room_grid,SHARE/'場景-對比/demo9-share-preview-museum-mid.png')
        save(room_grid,PREVIEW/'v9-museum-mid-preview.png')
        copy(rooms[1],SHARE/'場景-房間/demo9-share-scene-wax_museum.png')
        copy(rooms[1],PREVIEW/'wax_museum.png')
        copy(rooms[2],SHARE/'場景-房間/demo9-share-scene-wax_basement.png')
    for source in ['may-idle','may-statue','may-brush','may-brush_strike',
                   'void-idle','void-lash','fury-lunge','ling-giant','ling-crouch',
                   'keeper-back','keeper-unmasked']:
        path=PREVIEW/('v9-'+source+'.png')
        if path.exists():
            copy(path,SHARE/'角色-預覽'/('demo9-share-preview-'+source+'.png'))
            if source=='fury-lunge': copy(path,SHARE/'角色-預覽/demo9-share-preview-fury.png')
    current_previews=[PREVIEW/('v9-'+name+'.png') for name in
                      ['may-brush','may-brush_strike','void-lash','fury-lunge','ling-giant']]
    if all(p.exists() for p in current_previews):
        save(panels(current_previews,[p.stem for p in current_previews],2,(960,540)),
             ROOT/'docs/demo9-compare-v9-previews.png')
    (ROOT/'docs/demo9-teammate-art-share-manifest.json').write_text(
        json.dumps({'version':'Demo 9','updated':written},ensure_ascii=False,indent=2)+'\n')
    # The existing handoff archive must not keep stale revisions.
    with zipfile.ZipFile(ROOT/'docs/demo9-share.zip','w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(SHARE.rglob('*')):
            if path.is_file() and path.suffix!='.import' and path.name!='.DS_Store':
                z.write(path,path.relative_to(SHARE.parent))
    print('Demo 9 revision shares:',len(written),'files; archive refreshed')

if __name__=='__main__': main()
