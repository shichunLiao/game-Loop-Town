# Demo 9 變更與視覺檢視報告

> 只讀檢視時間：2026-11-08（Asia/Shanghai）  
> 專案：`/Users/tsun/Projects/game-Loop-Town`  
> 分支：`demo-9`（未推送）  
> HEAD：`e401700fef10ba6fdcf44bc77139617318256c9c`（短碼 `e401700`）  
> 基準（Demo 9 之前）：`335c3f4`

---

## 1. 總覽

Demo 9 依《劇情 1.1》把五位劇情角色與美術館三張背景換成 Codex 新圖，並由 Claude Code 接進 Godot 腳本。結果在本機 `demo-9` 分支，尚未 push。

| 項目 | 內容 |
| --- | --- |
| 路徑 | `/Users/tsun/Projects/game-Loop-Town` |
| 分支 | `demo-9` |
| HEAD | `e401700` |
| 美術＋接線 | `c597449` — Demo 9: story 1.1 art via Codex + wiring |
| 報告文件 | `e401700` — Demo 9: add report |
| 驗證（新） | `validate_v9_art.gd` → **48 通過、0 失敗**；截圖 `docs/exploration-demo/v9-*.png` |
| 驗證（舊） | `validate_exploration.gd` → 23 通過、5 失敗（改動前 HEAD 同樣失敗；腳本仍按 Demo 8 路線斷言） |
| 中途 qa-report | `docs/exploration-demo/qa-report.json` 曾記 35 通過、0 失敗（房間 18） |

---

## 2. 兩筆 commit 各一句

- **`c597449`**：Codex（`gpt-6.1-sol`）繪製劇情 1.1 五位角色立繪與美術館三張背景，Claude Code 完成腳本接線、腳底對齊、人物圖鑑與 v9 美術 QA。
- **`e401700`**：新增 `docs/demo9-report.md` 總結改動、檔案清單與尚未處理項。

---

## 3. 變更／新增檔案一覽（相對 `335c3f4` → `e401700`）

共約 95 路徑（含 `.import`）。說明採一行掃讀。

### 3.1 角色立繪（新增，`assets/environments/exploration/actors/`）

| 路徑 | 說明 |
| --- | --- |
| `actors/may_idle.png`（+`.import`） | 梅·莫里站姿：右臉黑印、巨型美工刀 |
| `actors/may_windup.png`（+`.import`） | 梅蓄力姿勢 |
| `actors/may_slash.png`（+`.import`） | 梅揮砍姿勢 |
| `actors/may_summon.png`（+`.import`） | 梅召喚雕像替身姿勢 |
| `actors/may_brush.png`（+`.import`） | 梅第三階段持畫筆形態 |
| `actors/may_brush_strike.png`（+`.import`） | 梅揮畫筆攻擊（寬姿勢，2580×1300） |
| `actors/may_statue.png`（+`.import`） | 純白裂紋雕像替身 |
| `actors/void_idle.png`（+`.import`） | 沃伊德站姿：鈕扣眼、指尖紅線 |
| `actors/void_command.png`（+`.import`） | 沃伊德操控姿勢 |
| `actors/void_lash.png`（+`.import`） | 沃伊德甩紅線／鞭打（寬姿勢，2603×1300） |
| `actors/void_frenzy.png`（+`.import`） | 沃伊德暴走姿勢 |
| `actors/void_puppet.png`（+`.import`） | 座位殘缺人偶／斷線木偶敵人 |
| `actors/keeper_back.png`（+`.import`） | 守鐘人背身擰巨大發條／鑰匙 |
| `actors/keeper_hidden.png`（+`.import`） | 守鐘人轉身、五官仍隱藏 |
| `actors/keeper_unmasked.png`（+`.import`） | 守鐘人摘帽，臉似杰利 |
| `actors/fury_idle.png`（+`.import`） | 弗瑞站姿（霸凌者成年形象） |
| `actors/fury_lunge.png`（+`.import`） | 弗瑞突進 |
| `actors/fury_punch.png`（+`.import`） | 弗瑞揮拳（玩家操控時也用） |
| `actors/ling_giant.png`（+`.import`） | 玲泥漿藤蔓巨體 |
| `actors/ling_hand.png`（+`.import`） | 泥裡伸出的手 |
| `actors/ling_crouch.png`（+`.import`） | 擊敗後蹲角落、頭埋低的真玲 |

### 3.2 背景（覆蓋原檔，`assets/environments/exploration/backgrounds/`）

| 路徑 | 說明 |
| --- | --- |
| `backgrounds/museum.png` | 重畫為「美術館 · 無盡走廊」（原蠟像熔爐大廳） |
| `backgrounds/basement.png` | 重畫為「七鏡畫室」（地下室／檔案室共用） |
| `backgrounds/wax.png` | 重畫為「美術館前街」街景（原蠟像館街景） |

### 3.3 資料／腳本／工具

| 路徑 | 說明 |
| --- | --- |
| `data/exploration/actors.json` | `puppet` 的 `atlas` 改為 `void_puppet`（不再用 `enemies_a` cell 2） |
| `scripts/exploration/exploration_art.gd` | 新增 `foot_center`／`foot_shift`，寬姿勢腳底對齊 |
| `scripts/exploration/exploration_boss.gd` | 梅依階段／招式換姿勢與高度；不再用 morris 圖集 |
| `scripts/exploration/exploration_morris_double.gd` | 替身改 `may_statue`，去掉蠟殼著色器 |
| `scripts/exploration/exploration_void_boss.gd` | 沃伊德依招式換姿勢；剪線時右側布片仍疊加 |
| `scripts/exploration/exploration_keeper_figure.gd` | 改用新立繪；依距離切換背身→轉身→摘帽 |
| `scripts/exploration/exploration_fury_body.gd` | 弗瑞新立繪，去掉壓暗 |
| `scripts/exploration/exploration_fury_scene.gd` | 弗瑞場景接線微調 |
| `scripts/exploration/exploration_player.gd` | `wear` 支援弗瑞出拳與朝左繪製 |
| `scripts/exploration/exploration_ling_boss.gd` | 玲巨體改貼圖 |
| `scripts/exploration/exploration_ling_figure.gd` | 真玲改貼圖 |
| `scripts/exploration/exploration_ling_hand.gd` | 泥手改貼圖 |
| `scripts/exploration/exploration_hud.gd` | 人物圖鑑底排改六人（杰利／梅／沃伊德／守鐘人／弗瑞／玲） |
| `tools/dev/build_exploration_v9.py` | 新增 `art_v9` 同步 puppet 等 |
| `tools/dev/validate_v9_art.gd`（+`.uid`） | 新增 v9 美術驗證腳本（48/0） |

### 3.4 文件與 QA 截圖

| 路徑 | 說明 |
| --- | --- |
| `docs/demo9-brief.md` | Demo 9 任務說明 |
| `docs/demo9-report.md` | 正式報告（e401700 新增） |
| `docs/story-1.1.txt` | 《劇情 1.1》全文納入倉庫 |
| `docs/exploration-demo/README-V9.md` | Demo 9 說明與「尚未改動」 |
| `docs/exploration-demo/v9-build-notes.md` | 構建記錄 |
| `docs/exploration-demo/v9-art-prompts-*.json` | 五批 Codex 提示詞（may／void／keeper-fury／ling／backgrounds） |
| `docs/exploration-demo/v9-*.png`（11 張＋`.import`） | 遊戲內 QA 截圖（非繪製素材） |
| `README.md` | 註明劇情以 1.1 為準、world 版本 9 |
| `CLAUDE.md` | 協作說明新增 |

---

## 4. Codex 新美術：目錄、模型、用途

- **模型**：`gpt-6.1-sol`（經 `codex@openai-codex` companion `task --write`，內建 image_gen）
- **角色目錄**：`assets/environments/exploration/actors/`（透明 RGBA PNG；多數約 1300 高；朝左、腳底貼齊）
- **背景目錄**：`assets/environments/exploration/backgrounds/`（1672×941，覆蓋原檔；RGB）
- **提示詞**：`docs/exploration-demo/v9-art-prompts-{may,void,keeper-fury,ling,backgrounds}.json`

### 新／改視覺長什麼樣（檢視摘要）

**角色**

- **梅·莫里**：退休美術老師＋瘋狂氣息；右臉黑色印記、黃框圓眼鏡、沾漆圍裙；一～二階段持巨型美工刀（`may_idle`），三階段改巨大滴漆畫筆橫掃（`may_brush_strike`）；替身是全白裂紋雕像（`may_statue`）。
- **沃伊德**：瘦高縫合裁縫／操控者；一側鈕扣眼、指尖垂紅線；站姿（`void_idle`）與甩線攻擊（`void_lash`）反差大；另有人偶 `void_puppet`。
- **守鐘人**：寬簷帽背影擰巨大金鑰匙（`keeper_back`）；摘帽後露出年輕、似杰利的臉（`keeper_unmasked`）。
- **弗瑞**：壯碩成年霸凌者，軍綠外套、握拳站姿（`fury_idle`），另有突進／揮拳。
- **玲**：泥漿＋帶刺藤蔓、雙馬尾白衫藍裙、臉無五官的巨體（`ling_giant`）；真身蹲角落埋頭（`ling_crouch`）。

**場景**

- **museum**：哥德式無盡畫廊走廊，霧氣與歪斜／滴溶畫框。
- **basement**：七面金框鏡＋畫室桌椅顏料（七鏡畫室）。
- **wax**：美術館前街，暮色霧中哥德立面與櫥窗畫框／石雕。

**遊戲內截圖所見（接線正常）**

- `v9-may-brush_strike.png`／`v9-may-statue.png`：美術館走廊 Boss 戰，梅新立繪與血條／階段 UI 正常。
- `v9-void-lash.png`：後台絲線階段，紅線與人偶可見。
- `v9-cast.png`：人物圖鑑底排已是六人劇情卡司。
- `v9-fury.png`／`v9-ling-giant.png`：枯井／倒懸之井場景有弗瑞與玲戰 UI。

---

## 5. 檢視後發現的問題

**新立繪／新背景本身：沒有看到破圖、缺檔或透明通道錯誤。**

- 抽查的立繪皆為 **RGBA 且具 alpha**；三張背景為完整 RGB 全幅。
- 報告列出的 21 張角色圖＋3 張背景檔皆存在於磁碟。
- `validate_v9_art.gd` 結果 **48 通過、0 失敗**；腳本引用的新圖路徑可對上實體檔。

**在「新增／改動處」仍可見的視覺／一致性問題（非缺檔）：**

1. **美術館中景 — 已完成（Demo 9 follow-up item 1）**
   - 內建 Codex image_gen 新繪 `museum_mid.png`、`museum_depth.png`（1536×1024 RGBA，2×2），替換三個美術館房間 buildings / rear_scenery 的舊兩套中景引用。
   - 新內容為畫廊牆、遮布畫架／空基座、七鏡、修復工作桌、拱廊與維修架；舊 wax 圖集保留供其他主題使用。
   - 殘留例外：`wax_shop` / `wax_workshop` 建築、其他 props / terrain 不在本次兩套中景範圍內。Godot headless 驗證八個切片與三個房間載入通過；視窗執行在本環境崩潰，未產生新遊戲截圖。

2. **雕像替身在畫面中極白**  
   - 源檔 `may_statue.png` 是刻意的純白裂紋雕像，不是缺貼圖。  
   - 疊在彩色蠟像中景上會像「線稿／未上色」，易被誤認為破圖；屬風格對比，不是檔案損壞。

3. **命名殘留（功能無阻）**  
   - `actors.json` 的 boss `id` 仍為 `"morris"`（美術已接梅）；僅命名未改。

4. **舊探索驗證 5 失敗**  
   - 與本次美術無關；腳本仍斷言 Demo 8 路線。

**未在新立繪上看到**：粉紅缺圖、透明黑塊、明顯腳浮空（寬姿勢已做腳底對齊）、或腳本指向不存在的 PNG。

---

## 6. 未完成項（報告／README／build-notes 彙整）

### 美術／場景

- 美術館房間 **中景道具**：follow-up item 1 已用 `museum_mid`／`museum_depth` 替換三房間 buildings／rear_scenery；殘留例外為 `wax_shop`／`wax_workshop` 建築與其他 props。
- **豐收祭之夜**遠景已於 follow-up item 2 以內建 Codex image_gen 重繪為祭典之夜／火災記憶（`fire.png`，1672×941 RGB）；fire 中景仍保留。
- **井口、警戒線、藤蔓、紅線、地上的手**已於 follow-up item 3 使用內建 image_gen 透明 PNG 替換並接線（props/well_mouth、caution_tape、vine、red_thread、ground_hand）；保留 combat ling_hand 與藤結光點／聲波和階段環等特效。
- **音效未換**（玲的哭喊暫用倒放童謠等）。

### 劇情機制（尚未實作）

- 梅戰：**撕碎／雕塑化結局**、**入畫後的畫作化**、**可推倒掩體**。
- **鐘樓瓦解**演出（守鐘人消散後）。
- **刑警登場**（目前只在文字／任務裡出現）。
- 梅戰前後部分過場尚未做成演出。

### 發布／手感

- **未匯出 Windows 包**。
- **未手動完整通關**；沃伊德／守鐘人追逐／弗瑞過場／玲等以腳本走查為主，難度與手感未真人長測。

---

## 7. 本次實際看過的檔名清單

**報告／說明**

- `docs/demo9-report.md`
- `docs/exploration-demo/v9-build-notes.md`
- `docs/exploration-demo/README-V9.md`（掃「尚未改動」）
- `docs/exploration-demo/qa-report.json`

**Codex 立繪（開圖）**

- `actors/may_brush_strike.png`、`may_idle.png`、`may_statue.png`
- `actors/void_idle.png`、`void_lash.png`
- `actors/keeper_back.png`、`keeper_unmasked.png`
- `actors/fury_idle.png`
- `actors/ling_giant.png`、`ling_crouch.png`

**背景（開圖）**

- `backgrounds/museum.png`、`basement.png`、`wax.png`

**中景（開圖，對照舊道具）**

- `midgrounds/wax_mid.png`

**遊戲內 QA 截圖（開圖）**

- `docs/exploration-demo/v9-cast.png`
- `v9-may-brush_strike.png`、`v9-may-statue.png`
- `v9-void-lash.png`
- `v9-keeper-unmasked.png`
- `v9-ling-giant.png`
- `v9-fury.png`

**另以檔案存在性核對（未逐張開圖）的立繪**

- `may_windup`、`may_slash`、`may_summon`、`may_brush`
- `void_command`、`void_frenzy`、`void_puppet`
- `keeper_hidden`
- `fury_lunge`、`fury_punch`
- `ling_hand`

---

## 8. 語音可用三點摘要

1. **視覺**：五位劇情角色與美術館三張背景已換成 Codex 新圖並接進遊戲；follow-up 已補美術館中景、豐收祭之夜遠景 `fire.png`、以及井口／警戒線／藤蔓／紅線／地上手印道具；代表圖含 `may_brush_strike`（揮畫筆）、`void_lash`（甩紅線）、`keeper_unmasked`（摘帽似杰利）、`ling_giant`／`ling_crouch`、以及無盡走廊／七鏡畫室／美術館前街／祭典夜火街。
2. **問題**：新 PNG 本身沒看到破圖或缺檔（v9 美術 QA 48/0）。美術館中景主衝突（熔蠟大缸／蠟像櫥窗）已於 follow-up item 1 以 `museum_mid`／`museum_depth` 替換；殘留 `wax_shop`／`wax_workshop` 建築。
3. **未完成**：音效（井口／警戒線／藤蔓／紅線／地上手印已於 item 3 替換）；以及梅的撕紙／雕像結局、入畫、可推倒掩體、鐘樓瓦解、刑警登場等機制；未導出 Windows、未完整手玩通關。

---

*本檔為只讀檢視後寫入的掃讀報告，未改動遊戲程式／美術／腳本。*
