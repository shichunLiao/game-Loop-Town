"""Package the runnable demo, reusable scene art, and a sanitized Godot source project.

Only explicit roots are included. No .env, user configuration, editor cache,
or Microsoft font is copied into the distribution archives.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/exploration-demo"
ART = ROOT / "assets/environments/exploration"
DIST = ROOT / "dist"


def archive(path: Path, entries: list[tuple[Path, str]]) -> None:
    names = set()
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as z:
        for source, dest in entries:
            if dest in names:
                continue
            assert ".env" not in Path(dest).name.lower(), dest
            assert not dest.endswith("chinese.ttf"), dest
            names.add(dest)
            z.write(source, dest)
    with zipfile.ZipFile(path) as z:
        error = z.testzip()
        assert error is None, (path, error)
    print(path.name, len(names), "files", round(path.stat().st_size / 1048576, 2), "MiB")


def main():
    DOCS.mkdir(parents=True, exist_ok=True)
    records = []
    regions = {"stone": [64,242,2040,244], "wood": [30,220,2100,281], "brass": [45,229,2080,279]}
    for path in sorted(ART.rglob("*.png")):
        with Image.open(path) as im:
            record = dict(path=path.relative_to(ROOT).as_posix(), width=im.width,
                          height=im.height, mode=im.mode, bytes=path.stat().st_size,
                          sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                          characters=path.parent.name=="actors")
            if "A" in im.getbands():
                alpha = im.getchannel("A")
                record["alpha_extrema"] = list(alpha.getextrema())
                record["opaque_bounds"] = alpha.point(lambda a: 255 if a > 200 else 0).getbbox()
            if path.parent.name == "terrain" and path.stem in regions:
                record["atlas_region"] = regions[path.stem]
                record["collision_top_in_atlas"] = 0
                record["canonical_display_height"] = 110
            records.append(record)
    world = json.loads((ROOT / "data/exploration/world.json").read_text(encoding="utf-8"))
    buildings=[b for r in world["rooms"].values() for b in r.get("buildings",[])]
    report = dict(schema=8, generated_with="built-in image_gen", assets=records,
                  png_count=len(records), rooms=len(world["rooms"]),
                  directed_exits=sum(len(r["exits"]) for r in world["rooms"].values()),
                  main_regions=18,physical_corridors=23,npc_types=8,npc_placements=sum(len(r.get("npcs",[])) for r in world["rooms"].values()),enemy_types=8,bosses=1,
                  boss_phases=3,boss_skills=6,safe_village_regions=sum(bool(r.get("safe_village")) for r in world["rooms"].values()),independent_interiors=28,main_quest_steps=10,resident_requests=8,gate_groups=14,weapon_stages=5,
                  fixed_structures=len(buildings),enterable_houses=sum(b["enterable"] for b in buildings),
                  unique_structure_visuals=len(set((b["asset"],b["cell"]) for b in buildings)),
                  vertical_rooms=sum(bool(r.get("vertical")) for r in world["rooms"].values()),
                  manual_return_lifts=sum(bool(r.get("route_layout",{}).get("lift")) for r in world["rooms"].values()),
                  shaft_investigations=sum(o.get("item","").startswith("shaft_note_") for r in world["rooms"].values() for o in r["objects"]),
                  grid_unit=64, collision="Gameplay bodies and combat areas; background art is non-colliding",
                  layers=["BG_04_Far (horizontal distant parallax; vertical world-fixed)", "WorldRearScenery (fixed)", "WorldArchitecture (fixed)", "WorldStreetDetails (fixed)", "Gameplay", "Actors", "Foreground"])
    (DOCS / "asset-manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    portable = DIST / "LoopTownDemo-v8"
    shutil.copy2(DOCS / "README-V8.md", portable / "README.md")
    for name in ["world-map.png","asset-manifest.json","v8-build-notes.md","v8-postoffice.png","v8-grounded-courtyard.png","v8-west-street.png","v8-town-door.png","v8-postoffice-roof.png","v8-east-street.png","v8-interior.png","v8-well.png","v8-portable-street.png","v8-route-layout.svg"]:
        shutil.copy2(DOCS / name, portable / name)
    archive(DIST / "LoopTownDemo-v8-Windows.zip", [(p, "LoopTownDemo-v8/"+p.name) for p in portable.iterdir() if p.is_file()])

    art_entries = [(p,p.relative_to(ROOT).as_posix()) for p in ART.rglob("*")
                   if p.is_file() and p.suffix in [".png", ".tres", ".gdshader"]]
    art_entries += [(ROOT/"assets/ui/exploration/chinese.tres", "assets/ui/exploration/chinese.tres")]
    art_entries += [(DOCS/name, "docs/"+name) for name in ["README-V8.md","ART_PROMPTS.md","v3-art-prompts.json","v4-art-prompts.json","v5-art-prompts.json","v5-extra-art-prompts.json","v6-art-prompts.json","v6-art-refinement-prompts.json","v7-art-prompts.json","v3-well-refinement.txt","asset-manifest.json","world-map.png","v8-route-layout.svg"]]
    art_entries += [(ROOT/"data/exploration"/name,"data/exploration/"+name) for name in ["art-regions.json","art-anchors.json","actors.json","world.json","quests.json","weapons.json"]]
    archive(DIST / "LoopTown-v8-art-assets.zip", art_entries)

    source_entries = []
    for directory in ["scripts","autoload","data","scenes","assets"]:
        for path in (ROOT/directory).rglob("*"):
            if not path.is_file() or path.suffix == ".import" or path.name == "chinese.ttf":
                continue
            relative = path.relative_to(ROOT).as_posix()
            if relative.startswith("assets/concepts/"):
                continue
            source_entries.append((path,relative))
    for path in DOCS.glob("*"):
        if path.name in ["README-V8.md","ART_PROMPTS.md","v3-art-prompts.json","v4-art-prompts.json","v5-art-prompts.json","v5-extra-art-prompts.json","v6-art-prompts.json","v6-art-refinement-prompts.json","v7-art-prompts.json","v3-well-refinement.txt","asset-manifest.json","world-map.png","v8-build-notes.md","v8-route-layout.svg"] or (path.name.startswith("v8-") and path.suffix==".png"):
            source_entries.append((path,"docs/exploration-demo/"+path.name))
    for name in ["build_exploration_world.py", "build_exploration_upgrade.py", "build_exploration_architecture.py", "build_exploration_v5.py", "build_exploration_v6.py", "build_exploration_v7.py", "build_exploration_v8.py", "render_exploration_routes.py", "build_exploration_pack.gd", "catalog_exploration_art.py", "package_exploration_demo.py", "LoopTownLauncher.cs"]:
        source_entries.append((ROOT/"tools/dev"/name,"tools/dev/"+name))
    source_entries += [(DOCS/"portable-project-v8.godot","project.godot"), (ROOT/"icon.svg","icon.svg"),
                      (DOCS/"README-V8.md","README.md"), (portable/"GODOT_LICENSE.txt","GODOT_LICENSE.txt")]
    archive(DIST / "LoopTownDemo-v8-Godot-source.zip",source_entries)
    print("Asset manifest:",len(records),"PNG files;",report["rooms"],"rooms;",report["directed_exits"],"directed exits")


if __name__ == "__main__":
    main()
