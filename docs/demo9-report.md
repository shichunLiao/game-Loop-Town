# Demo 9 報告（劇情 1.1）

## 1) 相對《劇情 1.1》的改動要點

- **美術全面對齊劇本角色**：五位劇情角色不再借用舊素材。
  - **梅·莫里**：退休美術老師形象，右臉黑色印記、巨型美工刀；第二階段召喚純白「雕像替身」，第三階段「入畫」改持滴落顏料的巨型畫筆。不再使用蠟匠莫里斯的圖。
  - **沃伊德**：右半臉為縫合布偶布料、嘴角誇張上揚，指尖延伸紅線；有操控、鞭打、暴走三種姿勢。座位上的殘缺人偶也有新圖。
  - **守鐘人**：寬簷帽、看不清五官。鐘樓追逐中背對杰利擰巨大發條；在鐘樓頂，杰利走近時他會轉身，再靠近就摘下帽子，露出和杰利一樣的臉。
  - **弗瑞**：霸凌者成年後的形象，有站姿、突進兩種姿勢。畫面一閃、視角切換後，玩家操控的就是弗瑞，出拳時會換成揮拳姿勢。
  - **玲**：井底由泥漿與帶刺藤蔓組成的巨大身體，雙馬尾、白襯衫、藍裙子，臉是模糊的一團；泥裡伸出的手；擊敗後蹲在角落、頭埋得很低的真正的玲。
- **美術館不再是蠟像館氛圍**：三張背景重畫——美術館 · 無盡走廊、七鏡畫室（地下室與檔案室共用）、美術館前街。
- **接線**：上述角色的腳本改用新圖，並移除壓暗色調、代碼畫的佔位身體與發條。寬姿勢依貼圖底部的不透明像素自動對齊腳底位置，並更新人物圖鑑底排。座位人偶的資料同步寫進 `build_exploration_v9.py`。
- **文件**：README-V9 標題改為 Demo 9；根 README 註明劇情以 1.1 為準、世界版本 9；新增 `docs/exploration-demo/v9-build-notes.md`。
- **驗證**：新增 `tools/dev/validate_v9_art.gd`，帶視窗執行結果為 48 通過、0 失敗，遊戲內截圖存為 `docs/exploration-demo/v9-*.png`。既有的 `validate_exploration.gd` 為 23 通過、5 失敗；這 5 項在本輪改動前的 HEAD 上同樣失敗，原因是該腳本仍按 Demo 8 路線斷言。
- **尚未處理**：
  - 美術館房間的中景道具（熔蠟大缸、燭台）仍是 Demo 8 的蠟像圖集。
  - 豐收祭之夜背景、井口、警戒線、紅線與藤蔓仍沿用舊素材或代碼繪製；音效未換。
  - 梅戰的撕碎與雕塑化結局、畫作化、可推倒掩體，鐘樓瓦解演出，以及刑警登場，都還沒實作。
  - 未匯出 Windows 包，也未手動完整通關。

## 2) Codex 繪製的檔案（完整路徑）

模型：`gpt-6.1-sol`，經 `codex@openai-codex` companion `task --write` 以內建 image_gen 繪製。逐張提示詞見 `docs/exploration-demo/v9-art-prompts-{may,void,keeper-fury,ling,backgrounds}.json`。

角色（透明 PNG，各附 Godot `.import`）：
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_idle.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_windup.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_slash.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_summon.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_brush.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_brush_strike.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/may_statue.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/void_idle.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/void_command.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/void_lash.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/void_frenzy.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/void_puppet.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/keeper_back.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/keeper_hidden.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/keeper_unmasked.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/fury_idle.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/fury_lunge.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/fury_punch.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/ling_giant.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/ling_hand.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/actors/ling_crouch.png

背景（1672×941，覆蓋原檔）：
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/backgrounds/museum.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/backgrounds/basement.png
- /Users/tsun/Projects/game-Loop-Town/assets/environments/exploration/backgrounds/wax.png

（`docs/exploration-demo/v9-*.png` 為遊戲內截圖，不是繪製的素材。）

## 3) 分支與提交

- 分支：`demo-9`
- 美術與接線提交：`c5974491bd9dff03051e8b059e95a2ea6ee36eea`（Demo 9: story 1.1 art via Codex + wiring）
- 本報告另以後續提交加入；最終 HEAD 以 `git rev-parse HEAD` 為準。未 push。
