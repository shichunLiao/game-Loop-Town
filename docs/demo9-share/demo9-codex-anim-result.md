# Demo 9：Keeper 修腳、人像追視、全角色 CG 幀動畫結果

完成日期：2026-11-12。版本維持 Demo 9；未 commit、未 push。保留開始時已有的修改；沒有修改論文內容或其他專案。

## 完成內容

- Keeper 原檔雙靴改成朝左的完整側面，平底、低跟、直踝；畫布仍為 **706 × 1280**。只替換半開區域 `(30,1111,203,1280)`、`(244,1111,427,1280)`；逐像素檢查確認其餘臉、頭髮、大衣、手、帽子與尺寸不變。
- 遊戲內 museum.png 的三個大畫框改為老婦、男子、年輕女子肖像；背景裡的虹膜已移除，六張透明虹膜在遊戲裡獨立移動。框外的大廳像素與本輪前完全相同。
- **50 張透明 sheet、77 段動畫，每段 8 個不同繪製幀，共 616 幀**。動作已接回原有狀態，沒有改傷害、AI、碰撞、關卡或攻擊判定。
- 角色／場景繪圖使用內建 image_gen。Python 僅作裁切、透明遮罩、素材合成、對齊、打包與驗證，沒有程式繪製角色或大廳。生成／去背提示詞見 [demo9-animation-prompts.json](demo9-animation-prompts.json)。

## 在本機觀看

正常開啟 `project.godot` 並執行 `scenes/exploration/ExplorationDemo.tscn`：主角站立、跑跳、攀爬、衝刺與攻擊會播放各自的圖像幀；NPC 呼吸，敵人移動、蓄力、出招、收招也會播放。

- 美術館 `wax_museum`：三幅肖像在原背景遠景層，平時看玩家。玩家正在攻擊時優先看玩家；否則場上有正在出招的敵人就看該敵人。沒有敵人出招時回看玩家。眼睛是背景 Sprite 的子節點，跟著同一視差／縮放，兩軸平滑追視並限制行程。
- 美術館 May：六種戰鬥姿勢與雕像分身；劇院 `back_stage`：Void 四姿勢與木偶；枯井 `dry_well`：Fury 站立、突進、玩家穿上 Fury 出拳、另一身體 Jerry 退步／倒下。
- 鐘樓與 `clock_top`：Keeper 背面、藏臉、露臉都有呼吸／衣髮幀，靠近時沿既有距離條件換姿；鐘樓地板抓手也已換成生成的 8 幀。
- 井底 `well_interior`：巨大玲、抓手與戰後蹲坐的玲都有圖像幀。

快速瀏覽所有 77 段（獨立審圖工具，不讀寫遊戲進度）：

```sh
/Users/tsun/.local/bin/godot --path . --script tools/dev/demo9_animation_gallery.gd
```

左右方向鍵或空白換頁，Esc 離開。普通遊戲不需要開此工具，動畫本來就會播放。

## 可直接打開的交付圖

- [Keeper 全身前後](demo9-keeper-feet-before-after.png)、[靴子細節前後](demo9-keeper-feet-detail.png)
- [美術館人像前後](demo9-museum-portraits-before-after.png)、[人像合成預覽](demo9-museum-portraits.png)、[獨立眼睛追視放大 GIF](demo9-museum-gaze-closeup.gif)
- [May 揮刀 8 幀條](demo9-anim-may_slash-strip.png)、[Void 鞭擊 8 幀條](demo9-anim-void_lash-strip.png)
- [May 動畫 GIF](demo9-anim-may_slash.gif)、[Void 動畫 GIF](demo9-anim-void_lash.gif)、[Keeper 呼吸 GIF](demo9-anim-keeper_unmasked.gif)、[主角跑步 GIF](demo9-anim-hero_run.gif)
- [遊戲內美術館實際截圖](exploration-demo/v9-museum-portraits.png)、[遊戲內 Keeper 實際截圖](exploration-demo/v9-keeper-unmasked.png)

GIF 眼神放大圖是相同虹膜資源的合成預覽；遊戲內兩軸與目標切換另由 Godot 實際場景測試。完整 77 段幀條在 `docs/demo9-share/角色-動畫幀條/`。分享目錄與 `docs/demo9-share.zip` 均已同步。

## 美術館像素座標

背景尺寸 **1672 × 941**，下表原點是整張背景左上角，未縮放的背景像素。left／right 指畫面上的左右眼。每張 iris PNG 為 **7 × 7 RGBA**，中心左右可移動 **±2.2 px**，上下 **±0.8 px**。背景已用 image_gen 產出的無瞳孔眼白替換原眼部，沒有留下第二個烤死的瞳孔。

三個畫作內部替換區域（半開）：`(58,407,297,550)`、`(644,407,866,551)`、`(1380,408,1615,550)`。`museum_mid.png`、`museum_depth.png`、`terrain/museum_flat.png` 沿用本輪開始時的檔案與對齊，沒有移動平台或畫框。

| 肖像／眼睛 | 中心 x, y | 透明層路徑 | 眼白替換區域 |
|---|---|---|---|
| portrait_1_left_iris | 165.5, 471.5 | `assets/environments/exploration/portraits/portrait_1_left_iris.png` | `[159, 468, 172, 475]` |
| portrait_1_right_iris | 201.5, 471.5 | `assets/environments/exploration/portraits/portrait_1_right_iris.png` | `[195, 468, 208, 475]` |
| portrait_2_left_iris | 738.5, 463.5 | `assets/environments/exploration/portraits/portrait_2_left_iris.png` | `[732, 460, 745, 467]` |
| portrait_2_right_iris | 776.5, 463.5 | `assets/environments/exploration/portraits/portrait_2_right_iris.png` | `[770, 460, 783, 467]` |
| portrait_3_left_iris | 1485.5, 471.5 | `assets/environments/exploration/portraits/portrait_3_left_iris.png` | `[1479, 468, 1492, 475]` |
| portrait_3_right_iris | 1521.5, 471.5 | `assets/environments/exploration/portraits/portrait_3_right_iris.png` | `[1515, 468, 1528, 475]` |

完整機器可讀座標：[museum-eyes.json](../data/exploration/museum-eyes.json)。追視程式：[exploration_museum_gaze.gd](../scripts/exploration/exploration_museum_gaze.gd)。

## 動作與素材清單

盤點依據為 `scripts/exploration/` 與 `data/exploration/actors.json` 的實際載入；原 `morris*.png` 是舊素材，Demo 9 的 Morris／May 戰鬥已使用 `may_*`，分身使用 `may_statue`，因此沒有另創一個不會出場的 Morris。

NPC 對應：`npcs_a_0..3` 為點燈人、鄰居、提水老人、縫衣匠；`npcs_b_0..3` 為舊書商、檢票人、修錶匠、站務員。敵人 `enemies_a_0/1/3` 為蠟像、噴墨畫像、飛蛾；`enemies_b_0..3` 為黑泥爬行者、井底回聲、發條哨兵、餘燼居民；另有木偶與 May 雕像分身的四階段。

全部路徑相對專案根目錄。單動作 sheet 為 4 欄 × 2 列；`*_actions.png` 為 8 欄 × 4 列，四列依序為移動、蓄力、出招、收招，各 8 幀。offset 是 sheet 中起始格，從 0 起算。

| 動作 | 幀數 | 路徑 | offset | 循環 |
|---|---:|---|---:|---|
| `may_idle` | 8 | `assets/environments/exploration/actors/anim/may_idle.png` | 0 | 是 |
| `may_windup` | 8 | `assets/environments/exploration/actors/anim/may_windup.png` | 0 | 播完停末幀 |
| `may_slash` | 8 | `assets/environments/exploration/actors/anim/may_slash.png` | 0 | 播完停末幀 |
| `may_summon` | 8 | `assets/environments/exploration/actors/anim/may_summon.png` | 0 | 播完停末幀 |
| `may_brush` | 8 | `assets/environments/exploration/actors/anim/may_brush.png` | 0 | 是 |
| `may_brush_strike` | 8 | `assets/environments/exploration/actors/anim/may_brush_strike.png` | 0 | 播完停末幀 |
| `may_statue` | 8 | `assets/environments/exploration/actors/anim/may_statue.png` | 0 | 是 |
| `void_idle` | 8 | `assets/environments/exploration/actors/anim/void_idle.png` | 0 | 是 |
| `void_command` | 8 | `assets/environments/exploration/actors/anim/void_command.png` | 0 | 播完停末幀 |
| `void_frenzy` | 8 | `assets/environments/exploration/actors/anim/void_frenzy.png` | 0 | 是 |
| `void_lash` | 8 | `assets/environments/exploration/actors/anim/void_lash.png` | 0 | 播完停末幀 |
| `void_puppet` | 8 | `assets/environments/exploration/actors/anim/void_puppet.png` | 0 | 是 |
| `keeper_back` | 8 | `assets/environments/exploration/actors/anim/keeper_back.png` | 0 | 是 |
| `keeper_hidden` | 8 | `assets/environments/exploration/actors/anim/keeper_hidden.png` | 0 | 是 |
| `keeper_unmasked` | 8 | `assets/environments/exploration/actors/anim/keeper_unmasked.png` | 0 | 是 |
| `ling_crouch` | 8 | `assets/environments/exploration/actors/anim/ling_crouch.png` | 0 | 是 |
| `ling_giant` | 8 | `assets/environments/exploration/actors/anim/ling_giant.png` | 0 | 是 |
| `ling_hand` | 8 | `assets/environments/exploration/actors/anim/ling_hand.png` | 0 | 是 |
| `fury_idle` | 8 | `assets/environments/exploration/actors/anim/fury_idle.png` | 0 | 是 |
| `fury_lunge` | 8 | `assets/environments/exploration/actors/anim/fury_lunge.png` | 0 | 播完停末幀 |
| `fury_punch` | 8 | `assets/environments/exploration/actors/anim/fury_punch.png` | 0 | 播完停末幀 |
| `detective` | 8 | `assets/environments/exploration/actors/anim/detective.png` | 0 | 是 |
| `hero_idle` | 8 | `assets/environments/exploration/actors/anim/hero_idle.png` | 0 | 是 |
| `hero_run` | 8 | `assets/environments/exploration/actors/anim/hero_run.png` | 0 | 是 |
| `hero_jump` | 8 | `assets/environments/exploration/actors/anim/hero_jump.png` | 0 | 播完停末幀 |
| `hero_fall` | 8 | `assets/environments/exploration/actors/anim/hero_fall.png` | 0 | 播完停末幀 |
| `hero_climb` | 8 | `assets/environments/exploration/actors/anim/hero_climb.png` | 0 | 是 |
| `hero_dash` | 8 | `assets/environments/exploration/actors/anim/hero_dash.png` | 0 | 播完停末幀 |
| `hero_death` | 8 | `assets/environments/exploration/actors/anim/hero_death.png` | 0 | 播完停末幀 |
| `hero_windup` | 8 | `assets/environments/exploration/actors/anim/hero_windup.png` | 0 | 播完停末幀 |
| `hero_active` | 8 | `assets/environments/exploration/actors/anim/hero_active.png` | 0 | 播完停末幀 |
| `hero_recover` | 8 | `assets/environments/exploration/actors/anim/hero_recover.png` | 0 | 播完停末幀 |
| `npcs_a_0` | 8 | `assets/environments/exploration/actors/anim/npcs_a_0.png` | 0 | 是 |
| `npcs_a_1` | 8 | `assets/environments/exploration/actors/anim/npcs_a_1.png` | 0 | 是 |
| `npcs_a_2` | 8 | `assets/environments/exploration/actors/anim/npcs_a_2.png` | 0 | 是 |
| `npcs_a_3` | 8 | `assets/environments/exploration/actors/anim/npcs_a_3.png` | 0 | 是 |
| `npcs_b_0` | 8 | `assets/environments/exploration/actors/anim/npcs_b_0.png` | 0 | 是 |
| `npcs_b_1` | 8 | `assets/environments/exploration/actors/anim/npcs_b_1.png` | 0 | 是 |
| `npcs_b_2` | 8 | `assets/environments/exploration/actors/anim/npcs_b_2.png` | 0 | 是 |
| `npcs_b_3` | 8 | `assets/environments/exploration/actors/anim/npcs_b_3.png` | 0 | 是 |
| `keeper_limb` | 8 | `assets/environments/exploration/actors/anim/keeper_limb.png` | 0 | 是 |
| `enemies_a_0_move` | 8 | `assets/environments/exploration/actors/anim/enemies_a_0_actions.png` | 0 | 是 |
| `enemies_a_0_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_a_0_actions.png` | 8 | 播完停末幀 |
| `enemies_a_0_active` | 8 | `assets/environments/exploration/actors/anim/enemies_a_0_actions.png` | 16 | 播完停末幀 |
| `enemies_a_0_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_a_0_actions.png` | 24 | 播完停末幀 |
| `enemies_a_1_move` | 8 | `assets/environments/exploration/actors/anim/enemies_a_1_actions.png` | 0 | 是 |
| `enemies_a_1_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_a_1_actions.png` | 8 | 播完停末幀 |
| `enemies_a_1_active` | 8 | `assets/environments/exploration/actors/anim/enemies_a_1_actions.png` | 16 | 播完停末幀 |
| `enemies_a_1_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_a_1_actions.png` | 24 | 播完停末幀 |
| `enemies_a_3_move` | 8 | `assets/environments/exploration/actors/anim/enemies_a_3_actions.png` | 0 | 是 |
| `enemies_a_3_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_a_3_actions.png` | 8 | 播完停末幀 |
| `enemies_a_3_active` | 8 | `assets/environments/exploration/actors/anim/enemies_a_3_actions.png` | 16 | 播完停末幀 |
| `enemies_a_3_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_a_3_actions.png` | 24 | 播完停末幀 |
| `enemies_b_0_move` | 8 | `assets/environments/exploration/actors/anim/enemies_b_0_actions.png` | 0 | 是 |
| `enemies_b_0_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_b_0_actions.png` | 8 | 播完停末幀 |
| `enemies_b_0_active` | 8 | `assets/environments/exploration/actors/anim/enemies_b_0_actions.png` | 16 | 播完停末幀 |
| `enemies_b_0_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_b_0_actions.png` | 24 | 播完停末幀 |
| `enemies_b_1_move` | 8 | `assets/environments/exploration/actors/anim/enemies_b_1_actions.png` | 0 | 是 |
| `enemies_b_1_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_b_1_actions.png` | 8 | 播完停末幀 |
| `enemies_b_1_active` | 8 | `assets/environments/exploration/actors/anim/enemies_b_1_actions.png` | 16 | 播完停末幀 |
| `enemies_b_1_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_b_1_actions.png` | 24 | 播完停末幀 |
| `enemies_b_2_move` | 8 | `assets/environments/exploration/actors/anim/enemies_b_2_actions.png` | 0 | 是 |
| `enemies_b_2_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_b_2_actions.png` | 8 | 播完停末幀 |
| `enemies_b_2_active` | 8 | `assets/environments/exploration/actors/anim/enemies_b_2_actions.png` | 16 | 播完停末幀 |
| `enemies_b_2_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_b_2_actions.png` | 24 | 播完停末幀 |
| `enemies_b_3_move` | 8 | `assets/environments/exploration/actors/anim/enemies_b_3_actions.png` | 0 | 是 |
| `enemies_b_3_windup` | 8 | `assets/environments/exploration/actors/anim/enemies_b_3_actions.png` | 8 | 播完停末幀 |
| `enemies_b_3_active` | 8 | `assets/environments/exploration/actors/anim/enemies_b_3_actions.png` | 16 | 播完停末幀 |
| `enemies_b_3_recover` | 8 | `assets/environments/exploration/actors/anim/enemies_b_3_actions.png` | 24 | 播完停末幀 |
| `void_puppet_move` | 8 | `assets/environments/exploration/actors/anim/void_puppet_actions.png` | 0 | 是 |
| `void_puppet_windup` | 8 | `assets/environments/exploration/actors/anim/void_puppet_actions.png` | 8 | 播完停末幀 |
| `void_puppet_active` | 8 | `assets/environments/exploration/actors/anim/void_puppet_actions.png` | 16 | 播完停末幀 |
| `void_puppet_recover` | 8 | `assets/environments/exploration/actors/anim/void_puppet_actions.png` | 24 | 播完停末幀 |
| `may_statue_move` | 8 | `assets/environments/exploration/actors/anim/may_statue_actions.png` | 0 | 是 |
| `may_statue_windup` | 8 | `assets/environments/exploration/actors/anim/may_statue_actions.png` | 8 | 播完停末幀 |
| `may_statue_active` | 8 | `assets/environments/exploration/actors/anim/may_statue_actions.png` | 16 | 播完停末幀 |
| `may_statue_recover` | 8 | `assets/environments/exploration/actors/anim/may_statue_actions.png` | 24 | 播完停末幀 |

機器可讀載入表：[animations.json](../data/exploration/animations.json)。原單張 PNG 皆保留；原 Keeper／原 museum 另備份於 [demo9-animation-before/](demo9-animation-before/)。

## 播放與對齊實作

`ExplorationArt.sprite()` 讀取原角色 ID 對應的首幀；`ExplorationPoseAnimation` 在視覺層依原有狀態逐幀替換 AtlasTexture，等價於 SpriteFrames 播放，支援原圖回退。May／Void／Keeper／Fury 的既有姿勢選擇、各 `POSE_HEIGHT` 常數與碰撞都維持。Ling 的自繪入口改讀動畫幀，地板抓手沿用原判定時鐘。

每格高 384 px，寬度沿用各原姿勢的畫布比例；整段使用共同縮放，底部錨點對齊。沿用原 `foot_shift`，主角穿戴造型改用來源 ID 查腳位，避免 AtlasTexture 的空 resource_path 導致腳位錯誤。沒有為修靴子改碰撞或腳本接觸點。

攻擊幀配合原狀態剩餘時間；Fury 突進配合原 .36 秒、主角衝刺配合原 .16 秒、玲抓手配合原 .45 秒。只是調整顯示速度，不改戰鬥時長。共同圖像幀在緩時期間同步降速。

## 驗收

使用 `/Users/tsun/.local/bin/godot`，版本 **4.6.2.stable.official.71f334935** 重新匯入。

```sh
/Users/tsun/.local/bin/godot --headless --editor --path . --import
/Users/tsun/.local/bin/godot --path . --script tools/dev/validate_v9_art.gd
/Users/tsun/.local/bin/godot --headless --path . --script tools/dev/validate_v9_animation.gd
python3 tools/dev/validate_demo9_animation_pixels.py
```

- 既有美術驗證：**48 passed, 0 failed**，以視窗模式產出遊戲內截圖。
- 完整動畫／追視驗證：**828 passed, 0 failed**。包括 616 格載入、77 段全八幀前進、真實玩家與敵人狀態路由、Fury 穿戴出拳、短動作末幀、六眼兩軸限制與出招目標切換。
- 像素驗證：77 段各有 **8 個不同圖像幀**，透明底；Keeper 靴子外像素一致；museum 畫作外像素一致。
- 腳底對齊：以 alpha > 128 計算接觸點，在原有顯示高度下最大漂移 **1.5625 遊戲像素**；未改高度常數或碰撞。詳見 [接觸點驗證](demo9-animation-contact-validation.json) 與 [逐幀像素驗證](demo9-animation-pixel-validation.json)。
- 美術館中景驗證：**8 atlas cells and 3 rooms passed**，保留原圖集區域，重新產出三房預覽。
- 瀏覽工具 headless 啟動檢查通過；最終紀錄在 `docs/demo9-animation-qa.log`、`docs/demo9-art-qa.log`、`docs/demo9-animation-import.log`。

## 改動檔案範圍與限制

遊戲素材：`actors/keeper_unmasked.png`、`actors/anim/*.png`（50 張）、`backgrounds/museum.png`、`portraits/*_iris.png`（6 張）。資料：`data/exploration/animations.json`、`museum-eyes.json`。

程式：`exploration_art.gd`、`exploration_pose_animation.gd`、`exploration_backdrop.gd`、`exploration_museum_gaze.gd`、`exploration_player.gd`、`exploration_ling_boss.gd`、`exploration_ling_hand.gd`、`exploration_ling_figure.gd`、`exploration_keeper_limb.gd`、`exploration_push_cover.gd`。工具：`pack_demo9_animation.py`、`pack_demo9_museum.py`、`export_demo9_animation.py`、`validate_demo9_animation_pixels.py`、`validate_v9_animation.gd`、`demo9_animation_gallery.gd`，以及既有 `validate_v9_art.gd` 的動畫來源辨識與美術館截圖。

本輪開始前已有 `exploration_platform.gd`、`exploration_room.gd` 等修改，保留原狀，不把它們算成本輪的新功能。

已知限制：圖像幀是生成的 CG 素材，衣褶、髮絲和細節有輕微幀間差異；遊戲以固定 8 幀配合原時序播放，極短動作或低幀率時可能略過部分中間幀。人物畫作的眼睛刻意維持小幅移動，遠距離較含蓄，可用放大 GIF 直接確認。沒有新增原遊戲不存在的戰鬥招式；程序化粒子、紅線、藤蔓等環境／特效仍沿用既有實作。
