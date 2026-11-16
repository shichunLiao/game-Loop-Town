# 回環鎮（game-Loop-Town）與畢業論文 專案狀態（唯一主檔）

> **這是回環鎮與畢業論文進度的唯一主檔。** 群組「回環鎮」只貼變動或連到這裡。
> 最後核對：2026-11-16 15:40（Asia/Shanghai），由「創作」核對 GitHub：`main` @ `0b4ef28`（PR #3 合併 commit）；遠端只剩 `main` 一個分支。
> **Demo 9 已經由 [PR #3](https://github.com/shichunLiao/game-Loop-Town/pull/3) 併入 `main`**（2026-11-16 15:06）；`demo-9` 遠端分支已刪除，不再是開發分支。下文證據一律用固定 commit 連結，不依賴已刪分支。
> **論文狀態未核實**：`thesis/` 已被 `.gitignore` 排除，遠端沒有論文檔；本檔不收錄論文內容。Mac 本機狀態未核對。
> 時間一律為 Asia/Shanghai 絕對日期。

## 打勾規則
- `[x]` 只用於**士淳已驗收**。寫完、headless 測試過或已 push 但士淳沒試玩／沒看過 → `[ ]`「待驗收」。

## 專案目標與里程碑
- 作品：畢業設計遊戲 game-Loop-Town（開發分支 `main`）。
- 論文：《剧情驱动与动作解密：解离性创伤叙事类游戏的核心机制》，導師叶蓬。
- 分工（士淳已定）：場景、立繪、UI、icon、動畫一律 Codex 繪製；Claude Code 只做邏輯、腳本、場景結構。
- 里程碑與截止日：論文截稿日、答辯日、中期考核日 **均未記錄，待士淳確認**。

## 版本與分支（2026-11-16 15:40 核對）
- `main` @ [0b4ef28](https://github.com/shichunLiao/game-Loop-Town/commit/0b4ef2888dd8ec45005b80029c1c3d9a311da708)：PR #3「Merge Demo 9 into main」的合併 commit，父 commit 為 `812ecd8`（PR #2，主檔）與 `d696df3`（原 `demo-9` 頂端）。
- 遠端分支只剩 `main`；`demo-9` 已刪除，Demo 9 內容（`DEMO9-REPORT.md`、`tools/dev/validate_v9_*.gd`、`docs/demo9-*.md`）現在都在 `main`。
- GitHub 上**沒有 CI**（repo 無 `.github/workflows`，`main` 的 check runs 為 0）。下方煙霧測試是手動跑的，不能當 CI 通過。

## 整合後煙霧測試（main @ 0b4ef28，2026-11-16 15:20～15:35）
- 環境：共用電腦 Linux x86_64，Godot **4.6.3** stable 官方版，`--headless`；全新 clone，**沒有碰士淳 Mac 上的程序**。
- 指令：先 `godot --headless --path . --import`，再逐一跑 `godot --headless --path . --script res://tools/dev/<腳本>.gd`（涵蓋 `tools/dev/run_all_tests.ps1` 的 5 項，另加 Demo 9 的驗證腳本）。

| 腳本 | 退出碼 | 結果 |
|---|---|---|
| import | 0 | 匯入完成 |
| validate_project | 0 | 138 個腳本，0 失敗 |
| validate_assets | 0 | 31 項，0 失敗 |
| validate_runtime | 0 | 通過 |
| validate_gameplay | 0 | 17 項，0 失敗 |
| validate_transition | 0 | 通過 |
| validate_v9_art | 0 | 48 項，0 失敗 |
| validate_v9_animation | 0 | 828 項，0 失敗 |
| validate_v9_museum_mid | 0 | 8 個 atlas 格與 3 個房間通過 |
| validate_v9_item3／4／5 | 0／0／0 | 通過 |
| validate_v9_item6 | 0 | 32 項，0 失敗 |
| **validate_exploration** | **1** | **22 通過、8 失敗**（`DEMO9-REPORT.md` 記錄為 23／5；腳本仍按 Demo 8 路線斷言；log 另有 `_flood_y` SCRIPT ERROR） |

- 非阻斷警告：多個腳本有 `[StateMachine] 初始状态不存在: idle` 與「resources still in use at exit」，未影響退出碼。
- **沒測到**：視窗模式實際遊玩、Mac（Metal）與 Windows 執行、真人手感，這些都要等士淳試玩（LT-1、LT-5）。

## 編號說明
本 repo 原本沒有任務編號，自 2026-11-16 起用 `LT-n`。README「當前進度」與 `DEMO9-REPORT.md` §6 的未完成項是史料，對應見下表「來源」。

## 打勾清單
- [ ] LT-1 Demo 9：Codex 角色動畫、立繪、博物館地形 — 待驗收
- [ ] LT-2 畢業論文質檢並定稿 .docx — 待查證
- [ ] LT-3 中期考核 Keynote 補填學號／日期／時程 — 受阻
- [ ] LT-4 論文 Mac 以外備份方式 — 待提案
- [ ] LT-5 Demo 9 未完成項（Windows 包、真人全程手玩）— 未開始

## 明細表
| ID | 工作 | 核准 | 負責 | 狀態 | 開始日 | 期限（性質） | 依賴 | 交付物 | 驗收條件（可驗證） | 證據／來源 |
|---|---|---|---|---|---|---|---|---|---|---|
| LT-1 | Demo 9 美術與邏輯接入 | 已核准 | Codex（美術）＋Claude Code（邏輯） | 待驗收 | 未記錄 | 無承諾 | — | `main` 上的 Demo 9 內容、`DEMO9-REPORT.md` | 士淳在 Mac 試玩第一章；`validate_v9_art.gd` 0 失敗（2026-11-16 main@0b4ef28 實測 48／0） | 合併 [PR #3](https://github.com/shichunLiao/game-Loop-Town/pull/3) → `main` [0b4ef28](https://github.com/shichunLiao/game-Loop-Town/commit/0b4ef2888dd8ec45005b80029c1c3d9a311da708)；原 Demo 9 頂端 [d696df3](https://github.com/shichunLiao/game-Loop-Town/commit/d696df38dec2352676d600ec88f8ae112c1f689a)（2026-11-15 11:17）、[DEMO9-REPORT.md @ d696df3](https://github.com/shichunLiao/game-Loop-Town/blob/d696df38dec2352676d600ec88f8ae112c1f689a/DEMO9-REPORT.md) |
| LT-2 | 論文質檢後定稿 | 已核准 | 創作寫任務→Mac 上 Claude Code；士淳定稿 | 待查證 | 未記錄 | 待確認（截稿日無紀錄） | Mac 本機查證 | 論文 `.docx` | 無空泛套話；引用可查；內容貼合回環鎮與 Demo 9；不用降重工具；士淳確認定稿 | 遠端無檔（thesis 被忽略）；「四輪自查、約 3.95 萬字、未定稿」僅來自創作記憶，**未核實** |
| LT-3 | 中期考核 Keynote 補【待填】 | 已核准 | 士淳提供資料；創作補填 | 受阻 | 未記錄 | 待確認（考核日無紀錄） | 士淳提供學號、日期、時程 | `thesis/中期考核_剧情驱动与动作解密.key` | 檔內無任何【待填】 | 遠端無檔；據記錄只在 Neo 那台 Mac，**未核實** |
| LT-4 | 論文備份方式 | **待提案** | 士淳決定 | 未開始 | — | 2026-12-13 前（建議） | — | 備份位置 | Mac 以外有一份最新副本，且能開啟 | — |
| LT-5 | Demo 9 收尾：Windows 包、真人全程手玩、舊探索驗證失敗（報告記 5 項；2026-11-16 main 實測 8 項） | 待提案 | 創作→Claude Code；士淳手玩 | 未開始 | — | 待確認 | LT-1 | Windows 包、手玩紀錄 | Windows 包可啟動；士淳全程手玩一次無阻斷 | 來源：[DEMO9-REPORT.md @ d696df3](https://github.com/shichunLiao/game-Loop-Town/blob/d696df38dec2352676d600ec88f8ae112c1f689a/DEMO9-REPORT.md) §5～§6 |

## 待士淳決策
1. 論文截稿日、中期考核日、答辯日。
2. LT-4 備份方式（thesis 不進 git）。
3. LT-5 是否列為正式工作。
4. `validate_exploration.gd` 的 8 項失敗：改腳本（改成 Demo 9 路線）、修遊戲，或先擱置（歸 LT-5）。

## 其他文件用途
- `README.md`：開發說明；其「當前進度」段為 Demo 8 前後的史料，進度以本檔為準。
- `DEMO9-REPORT.md`：Demo 9 變更與檢視報告（2026-11-08，史料）。
- `docs/demo9-*.md`：單次 Codex 任務說明與結果。

## 變更紀錄
- 2026-11-16 15:40 創作：Demo 9 已由 PR #3 併入 `main`（0b4ef28），`demo-9` 遠端分支已刪；移除過時的「尚未合入 main／分支差異」說明，證據改用固定 commit；新增整合後煙霧測試結果；原決策 4（何時併回）已完成，改為 `validate_exploration` 失敗的處理決策。
- 2026-11-16 14:50 創作：依士淳 14:43 指示，主檔改放預設分支 `main`（取代原本 target `demo-9` 的 PR #1）；Demo 9 證據改用 demo-9 分支／commit 絕對連結；新增版本差異說明。
- 2026-11-16 14:35 創作：建立本檔，整合三群清單草案 LT-1～LT-4，新增 LT-5（來源 DEMO9-REPORT §6）；論文僅記狀態不記內容。
