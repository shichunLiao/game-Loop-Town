# Demo 9 Codex 任務：修腳、美術館人像眼神、全角色動作精靈動畫

工作目錄：`/Users/tsun/Projects/game-Loop-Town`。用內建 image_gen（不要用程式畫角色或場景）。不要 commit、不要 push。版本仍為 Demo 9。

士淳剛提出三件事，全部都要做完，不要只做其中一項。

## 1. 修正 Keeper 的腳

參考圖（士淳手繪批註）：`docs/demo9-feedback-keeper-feet.jpg`（若檔案不在，用 `assets/environments/exploration/actors/keeper_unmasked.png` 與分享立繪）。

問題：現在的腳看起來像崴了，還有透視。要求：兩隻腳都改成**完全側面**，不要透視；側面剪影接近參考圖上的白色勾線。只改靴子／踝／腳，其餘（臉、頭髮、大衣、手、帽子、畫布尺寸、檔名）保持不變。套用到遊戲原檔 `keeper_unmasked.png`，並同步分享立繪／相關預覽（與既有 Demo9 分享流程一致）。不要改碰撞或腳本邏輯（除非為對齊腳底接觸點所必需的極小調整，需寫進結果檔）。

## 2. 美術館畫作改人像，打架時眼睛會跟著看

對象是遊戲內美術館場景，不是另做一張獨立插圖。主要檔案：
- `assets/environments/exploration/backgrounds/museum.png`
- 以及需要對齊的 `midgrounds/museum_mid.png`、`museum_depth.png`、`terrain/museum_flat.png`

士淳要求：畫框裡改放一些**人像**（肖像畫）。打架時，這些人像的**眼睛要跟著動**、看向場上的人。

做法要求：
- 保留大廳構圖、牆面、燈、畫框位置與整體色調，不要重做整個房間。
- 把部分現有風景／靜物畫換成有臉的人像，風格仍與現有油畫／舊館氣質一致。
- 眼睛必須能獨立動畫：為每幅人像提供透明疊層（例如眼白＋虹膜／瞳孔分層，或整眼透明層），並在結果檔寫下每隻眼睛相對背景的像素位置與可移動範圍。不要把眼睛完全烤死在一張不能拆的背景裡，否則遊戲無法跟隨。
- 在美術館相關戰鬥／探索場景接上簡單的眼神跟隨（看向玩家或正在打架的角色）。不要改數值、關卡流程或攻擊判定。
- 同步分享圖／預覽裡對應的美術館畫面。

## 3. 為遊戲內每個角色的所有動作補上精靈圖，做成 CG 式幀動畫

現況：角色動作幾乎都是單張關鍵姿切換（例如 May 的 idle／windup／slash／summon／brush／brush_strike，Void、Fury、Ling 同理），所以看起來不順，沒有精靈圖序列。

要求：**遊戲裡每個會演出的角色、每一個已有動作，都要補精靈圖並真正接到遊戲裡播放**，不要只出樣張、不要只做一個角色。

先從程式與 `assets/environments/exploration/actors/` 盤點實際用到的角色與動作（至少包括）：
- May：`may_idle` `may_windup` `may_slash` `may_summon` `may_brush` `may_brush_strike` `may_statue`
- Void：`void_idle` `void_command` `void_frenzy` `void_lash` `void_puppet`
- Fury：`void` 戰場上的 `fury_idle` `fury_lunge` `fury_punch`（玩家亦會穿上 fury 相關姿）
- Ling：`ling_crouch` `ling_giant` `ling_hand`
- Keeper：`keeper_back` `keeper_hidden` `keeper_unmasked`（狀態切換也要有過渡或呼吸幀；unmasked 的腳須符合第 1 點）
- 還有遊戲中會出場、目前只有單張或動作不順的角色（如 detective、hero，以及 Demo 9 實際用到的 Morris／敵人／NPC 若有攻擊或移動動作）：一併盤點並補齊，不要漏。

動畫規格：
- 每個動作一張（或一組）精靈圖，透明底，幀與幀之間身份、服裝、比例、腳底接觸穩定。
- 現有單張關鍵姿可作為該動作的極幀／代表幀，不要換人、不要改角色設計。
- idle 建議 6–8 幀循環（輕微呼吸即可）；攻擊／特殊動作建議 8–12 幀，過程要能連上現有關鍵姿，避免突然跳切。
- 側面站立或走路時，腳也盡量用側面、避免奇怪透視（與第 1 點同一原則）。
- 用 Godot 4.6 既有專案接上：在現有狀態切換處改播 SpriteFrames／AnimatedSprite2D（或等價方案），讓動作真正動起來。不要重寫戰鬥數值、AI 或關卡。
- 畫布與縮放要讓現有高度常數（如 `POSE_HEIGHT`、foot_shift）仍大致可用；若必須微調，寫進結果檔。
- 原單張 PNG 不要刪成遊戲無法回退；新精靈圖放在清晰的目錄（例如 `assets/environments/exploration/actors/anim/`），並更新載入邏輯。

## 驗收與交付

- 用 Godot 4.6.2（`/Users/tsun/.local/bin/godot`）重新匯入，跑既有 `tools/dev/validate_v9_art.gd`（或必要的最小延伸），修復因新圖引起的失敗。
- 寫 `docs/demo9-codex-anim-result.md`：改了哪些檔、每張精靈圖幀數與路徑、美術館人像與眼睛層位置、Keeper 腳怎麼改、如何在遊戲裡看到動畫、已知限制。
- 交幾張可直接打開的對比／樣張（修腳前後、美術館人像、至少兩個角色的動作幀條）。
- 不要 commit、不要 push，不要改論文或其它專案。

完成標準：士淳在本機打開 Demo 9 後，能看到 Keeper 側面腳已修正、美術館人像在戰鬥中眼睛會跟隨，以及每個角色的既有動作都以精靈動畫播放，而不再是單張跳切。
