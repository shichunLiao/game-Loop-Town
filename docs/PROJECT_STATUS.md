# 回環鎮（game-Loop-Town）與畢業論文 專案狀態（唯一主檔）

> **這是回環鎮與畢業論文進度的唯一主檔。** 群組「回環鎮」只貼變動或連到這裡。
> 最後核對：2026-11-16 14:50（Asia/Shanghai），由「創作」只讀 GitHub 核對（`main` @ `05168ca`；`demo-9` @ `d696df3`）。
> **本檔放在預設分支 `main`**；Demo 9 的交付證據都在 `demo-9` 分支，下文一律用明確的分支／commit 連結引用。
> **論文狀態未核實**：`thesis/` 已被 `.gitignore` 排除，遠端沒有論文檔；本檔不收錄論文內容。Mac 本機狀態未核對。
> 時間一律為 Asia/Shanghai 絕對日期。

## 打勾規則
- `[x]` 只用於**士淳已驗收**。寫完、headless 測試過或已 push 但士淳沒試玩／沒看過 → `[ ]`「待驗收」。

## 專案目標與里程碑
- 作品：畢業設計遊戲 game-Loop-Town（工作分支 `demo-9`）。
- 論文：《剧情驱动与动作解密：解离性创伤叙事类游戏的核心机制》，導師叶蓬。
- 分工（士淳已定）：場景、立繪、UI、icon、動畫一律 Codex 繪製；Claude Code 只做邏輯、腳本、場景結構。
- 里程碑與截止日：論文截稿日、答辯日、中期考核日 **均未記錄，待士淳確認**。

## 版本差異說明（main 與 demo-9）
- `main`（預設分支）＝本主檔所在處，**不含** Demo 9 遊戲內容；`demo-9` 領先 `main` 15 個 commit（2026-11-16 14:50 核對）。
- 本檔只新增文件，沒有把 `demo-9` 的任何遊戲內容帶進 `main`；`demo-9` 是否、何時併回 `main` 見「待士淳決策」。
- 下文引用的 `DEMO9-REPORT.md`、`validate_v9_art.gd`、`docs/demo9-*.md` 都在 `demo-9` 分支，`main` 上可能沒有。

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
| LT-1 | Demo 9 美術與邏輯接入 | 已核准 | Codex（美術）＋Claude Code（邏輯） | 待驗收 | 未記錄 | 無承諾 | — | `demo-9` 分支內容、`DEMO9-REPORT.md`（demo-9） | 士淳在 Mac 試玩第一章；`validate_v9_art.gd` 0 失敗 | `demo-9` [d696df3](https://github.com/shichunLiao/game-Loop-Town/commit/d696df38dec2352676d600ec88f8ae112c1f689a)（2026-11-15 11:17）、[DEMO9-REPORT.md @ d696df3](https://github.com/shichunLiao/game-Loop-Town/blob/d696df38dec2352676d600ec88f8ae112c1f689a/DEMO9-REPORT.md) |
| LT-2 | 論文質檢後定稿 | 已核准 | 創作寫任務→Mac 上 Claude Code；士淳定稿 | 待查證 | 未記錄 | 待確認（截稿日無紀錄） | Mac 本機查證 | 論文 `.docx` | 無空泛套話；引用可查；內容貼合回環鎮與 Demo 9；不用降重工具；士淳確認定稿 | 遠端無檔（thesis 被忽略）；「四輪自查、約 3.95 萬字、未定稿」僅來自創作記憶，**未核實** |
| LT-3 | 中期考核 Keynote 補【待填】 | 已核准 | 士淳提供資料；創作補填 | 受阻 | 未記錄 | 待確認（考核日無紀錄） | 士淳提供學號、日期、時程 | `thesis/中期考核_剧情驱动与动作解密.key` | 檔內無任何【待填】 | 遠端無檔；據記錄只在 Neo 那台 Mac，**未核實** |
| LT-4 | 論文備份方式 | **待提案** | 士淳決定 | 未開始 | — | 2026-12-13 前（建議） | — | 備份位置 | Mac 以外有一份最新副本，且能開啟 | — |
| LT-5 | Demo 9 收尾：Windows 包、真人全程手玩、舊探索驗證 5 失敗 | 待提案 | 創作→Claude Code；士淳手玩 | 未開始 | — | 待確認 | LT-1 | Windows 包、手玩紀錄 | Windows 包可啟動；士淳全程手玩一次無阻斷 | 來源：[DEMO9-REPORT.md @ d696df3](https://github.com/shichunLiao/game-Loop-Town/blob/d696df38dec2352676d600ec88f8ae112c1f689a/DEMO9-REPORT.md) §5～§6 |

## 待士淳決策
1. 論文截稿日、中期考核日、答辯日。
2. LT-4 備份方式（thesis 不進 git）。
3. LT-5 是否列為正式工作。
4. `demo-9` 何時、以何方式併回 `main`（本檔已放 `main`；併回時保留本檔，勿在 `demo-9` 另建一份）。

## 其他文件用途
- `README.md`：開發說明；其「當前進度」段為 Demo 8 前後的史料，進度以本檔為準。
- `DEMO9-REPORT.md`（在 `demo-9`）：Demo 9 變更與檢視報告（2026-11-08，史料）。
- `docs/demo9-*.md`（在 `demo-9`）：單次 Codex 任務說明與結果。

## 變更紀錄
- 2026-11-16 14:50 創作：依士淳 14:43 指示，主檔改放預設分支 `main`（取代原本 target `demo-9` 的 PR #1）；Demo 9 證據改用 demo-9 分支／commit 絕對連結；新增版本差異說明。
- 2026-11-16 14:35 創作：建立本檔，整合三群清單草案 LT-1～LT-4，新增 LT-5（來源 DEMO9-REPORT §6）；論文僅記狀態不記內容。
