"""Read alpha bounds to author AtlasTexture metadata; never rewrites image pixels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/"assets/environments/exploration"
regions={}
anchors={}
atlas_dir=ART/"atlases"
atlas_dir.mkdir(parents=True,exist_ok=True)
for folder in ("actors","midgrounds","terrain","architecture","interiors","weapons","interiors_props","gates","masonry"):
    for path in sorted((ART/folder).glob("*.png")):
        if folder=="terrain" and not path.stem.endswith("_variants"):
            continue
        with Image.open(path) as im:
            alpha=im.getchannel("A") if "A" in im.getbands() else Image.new("L",im.size,255)
            cells=[-1] if path.stem in ("hero","morris") or folder in ("architecture","interiors") else range(4)
            for cell in cells:
                box=(0,0,im.width,im.height) if cell==-1 else (cell%2*im.width//2,cell//2*im.height//2,(cell%2+1)*im.width//2,(cell//2+1)*im.height//2)
                # The selected well illustration has wider left-hand objects.
                # Author its four regions rather than cutting across a root.
                if path.stem=="well_mid":
                    box=[(0,0,860,537),(860,0,1536,537),(0,537,860,1024),(860,537,1536,1024)][cell]
                if path.stem=="town_depth_v7":
                    # The garden and laundry stop above y=470. The lower roof
                    # starts before y=512; equal quadrants included its tip in
                    # the upper assets and cut that tip off the lower assets.
                    box=[(0,0,780,470),(780,0,1536,470),(0,470,780,1024),(780,470,1536,1024)][cell]
                if path.stem in ("morris_actions_v2","morris_forms_v2"):
                    split=round(im.width*(.49 if path.stem=="morris_actions_v2" else .455))
                    box=(0 if cell%2==0 else split,cell//2*im.height//2,split if cell%2==0 else im.width,(cell//2+1)*im.height//2)
                bounds=alpha.crop(box).point(lambda x:255 if x>190 else 0).getbbox()
                if bounds:
                    x,y,x2,y2=bounds
                    regions[f"{path.stem}/{cell}"]=[x+box[0],y+box[1],x2-x,y2-y]
                    rx,ry,rw,rh=regions[f"{path.stem}/{cell}"]
                    if folder in ("midgrounds","architecture","interiors_props"):
                        body=alpha.crop((rx,ry,rx+rw,ry+rh))
                        foot=rh-1
                        # A broad opaque base, not an isolated root or fringe,
                        # supplies the grounding line. This is metadata only.
                        for row in range(rh-1,-1,-1):
                            hist=body.crop((0,row,rw,row+1)).histogram()
                            if sum(hist[191:])>=rw*.12:
                                foot=row+1
                                break
                        anchors[f"{path.stem}/{cell}"]={"foot_y":foot,"height":rh,"bottom_gap":rh-foot}
                    ref="res://"+path.relative_to(ROOT).as_posix()
                    resource=(f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                              f'[ext_resource type="Texture2D" path="{ref}" id="1"]\n\n'
                              f'[resource]\natlas = ExtResource("1")\nregion = Rect2({rx}, {ry}, {rw}, {rh})\nfilter_clip = true\n')
                    (atlas_dir/f"{path.stem}_{'full' if cell==-1 else cell}.tres").write_text(resource,encoding="utf-8")
            hist=alpha.histogram()
            print(path.stem,im.size,"alpha",alpha.getextrema(),"clear",round(sum(hist[:16])/(im.width*im.height),3))
(ROOT/"data/exploration/art-regions.json").write_text(json.dumps(regions,indent=2),encoding="utf-8")
(ROOT/"data/exploration/art-anchors.json").write_text(json.dumps(anchors,indent=2),encoding="utf-8")
