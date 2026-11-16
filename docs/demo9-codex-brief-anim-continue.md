# Demo 9 Codex 續做：從卡住處收尾，不要重做已完成項目

上一輪 session（thread `01a1cb32-5101-7641-b0fb-ad61f4ab7e88`）在約 2026-11-12 00:10（Asia/Shanghai）說完「接著做完整動畫驗證與分享圖同步」之後，因網路斷線卡住，之後沒有新的實質進度。現在網路已恢復。請從剩餘工作繼續，做到完成標準。不要 commit、不要 push。版本仍為 Demo 9。用內建 image_gen（不要用程式畫角色或場景）。不要改論文或其他專案。

## 已完成，不要重做（除非驗收失敗必須修）

- Keeper 側面腳已套回 `assets/environments/exploration/actors/keeper_unmasked.png`（mtime 23:23）。
- 動作精靈已打包：`data/exploration/animations.json` 現有 77 段、每段 8 幀（共 616 幀），約 50 張 sheet 在 `assets/environments/exploration/actors/anim/`。含 May／Void／Fury／Ling／Keeper、detective、hero 各動作、8 個 NPC、敵人階段、`keeper_limb`、statue／puppet 階段。
- 播放層已接入現有狀態切換（`scripts/exploration/exploration_pose_animation.gd` 等）。
- `tools/dev/validate_v9_art.gd` 已跑過，48 項通過。
- 已有工具：`tools/dev/pack_demo9_animation.py`、`tools/dev/validate_v9_animation.gd`、`tools/dev/demo9_animation_gallery.gd`、`scripts/exploration/exploration_museum_gaze.gd`、`tmp/demo9-anim/pack_museum.py`。
- 人像生成圖與眼睛分層草稿在 `tmp/demo9-anim/`（`eyes-left/center/right.png`）以及 `~/.codex/generated_images/01a1cb32-5101-7641-b0fb-ad61f4ab7e88/`（例如 `exec-20f592b0-f197-4d90-9053-c4e658d8685e.png`）。

## 還沒做完，必須做完

1. 美術館人像還沒寫進遊戲背景。`assets/environments/exploration/backgrounds/museum.png` 仍是 2026-11-10 的舊檔；`assets/environments/exploration/portraits/`、`data/exploration/museum-eyes.json`、`docs/demo9-museum-portraits.png` 都不存在。請把已生成的人像與可獨立移動的眼睛層真正套進遊戲資源，接上眼神跟隨（平時看玩家，出招時看正在打架的角色），並驗證兩軸追視與目標切換。不要重做整個大廳。
2. 跑完整動畫驗證：每個動作檢查 8 個不同幀會前進；主角穿上 Fury 後出拳播放正確；腳底與原有高度對齊。修好驗證失敗項。必要時才補畫／去背，不要整套重畫。
3. 同步分享圖／預覽。
4. 寫 `docs/demo9-codex-anim-result.md`：改了哪些檔、每段精靈幀數與路徑、美術館人像與眼睛層像素位置、Keeper 腳怎麼改、如何在遊戲裡看到動畫、已知限制。並交可直接打開的對比／樣張（修腳前後、美術館人像、至少兩個角色的動作幀條）。

完成標準與上一輪相同：士淳在本機打開 Demo 9 後，能看到 Keeper 側面腳已修正、美術館人像在戰鬥中眼睛會跟隨，以及每個角色的既有動作都以精靈動畫播放，而不再是單張跳切。
