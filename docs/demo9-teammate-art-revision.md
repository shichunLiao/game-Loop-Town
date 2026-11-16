# Demo 9 美術改版（組員反饋）— Codex 任務

版本名仍叫 **Demo 9**（不要改成 demo10）。不要問用戶。完成後寫 `docs/demo9-teammate-art-revision-result.md`，並把替換後的遊戲內圖更新到對應路徑；分享圖 `docs/demo9-share/` 同步更新同名角色／美術館相關圖。不 push。

## 對照圖
`docs/demo9-teammate-feedback-chars.png`（紅字標 1–6）

| # | 檔名（遊戲內） | 路徑 |
|---|---|---|
| 1 | may_brush / may_brush_strike | `assets/environments/exploration/actors/may_brush.png`、`may_brush_strike.png` |
| 2 | void_lash | `…/actors/void_lash.png` |
| 3 | keeper_unmasked | `…/actors/keeper_unmasked.png`（本次可不改，風格維持） |
| 4 | fury_lunge | `…/actors/fury_lunge.png` |
| 5 | ling_giant | `…/actors/ling_giant.png` |
| 6 | detective | `…/actors/detective.png`（本次可不改） |

美術館：
- 背景 `assets/environments/exploration/backgrounds/museum.png`
- 中景 `assets/environments/exploration/midgrounds/museum_mid.png`
- 相關分享圖 `docs/demo9-share/場景-*/*museum*`

硬性規則：所有新圖由 Codex／內建 image_gen 繪製；透明底角色立繪；風格延續圖中「厚塗、灰暗、泥土色」一體感；覆蓋原檔檔名（Demo 9 同路徑）。

## 角色改動（必須）

### 1 與 2（May／Void）— 其一改女性、拉開辨識
- **把 1（May／may_brush＋may_brush_strike）改成女角色**：仍是刷子／油漆攻擊者，綠外套＋沾橙黃漆的圍裙可保留，但髮型、臉、身形明顯女性；站姿／攻擊姿兩張都要一致。
- **2（void_lash）保持男性**，但拉開與 May 的重複：不要兩個「矮蹲瘦削男」。調整身高比例、髮型、服裝色塊或武器剪影，讓並排一眼能分。
- 組員原話：风格很好；1跟2里能不能有一个换成女角色；更好区分形象。

### 4（fury_lunge）— 斯文外表＋右側臉錨點，反差暴力
- **不要**凶神惡煞／街頭混混臉。
- 改成**表面斯文**（整齊短髮或側分、襯衫或整齊外套、克制表情），但攻擊姿仍有爆發力，形成反差。
- 右側臉（與主角同側）加錨點，二選一或組合（優先可讀）：
  - **一大條傷疤**；或
  - **單塊圓鏡／單片眼鏡（monocle）** 在右眼。
- 組員原話：脸上加一大条伤疤或别的；锚定右侧；不一定凶神恶煞；表面比较斯文；锚点可换成单块圆镜；后面动手反差大。

### 5（ling_giant／小玲）— 時代／畫風對齊
- 保留「巨大／藤蔓木質下半＋空白臉＋雙馬尾紅緞」可識別特徵。
- 調整服裝、材質、上色與光影，讓她與 1–4、6 **像同一個時代、同一套美術**，不要偏現代卡通或脫節的少女感。
- 組員原話：5小玲外形感觉和他们有点不太像一个时代的。

### 3、6
- 可微調以統一色溫，但不是本輪重點；時間緊時可不動。

## 美術館場景（必須）
組員反饋：
1. 背景**過於縱向**，看起來怪。
2. 前景互動物邏輯上不該擺在那種縱向空間位置。
3. 若要保留縱深感：寧可「先橫向走進來 → 走到可進入的縱向長廊入口 → 進入後在長廊裡再橫向深入」的空間閱讀；美術上背景／中景要支援這種閱讀（例如先橫向展廳，遠處有窄長廊入口），不要整張圖一眼全是豎井。
4. 前景平台類內容加了一圈**立體陰影**，平面 2D 裡很突兀 → **去掉**這些立體陰影，保持平面拼貼感。

請重繪 `museum.png`、`museum_mid.png`（及分享對照圖），符合上述；若場景裡還有 museum 相關帶陰影的平台／前景貼圖，一併去掉陰影或重繪。

場景腳本／碰撞若需大改走廊進出邏輯：本輪以**美術資產**為主；在結果檔註明建議的關卡邏輯改動，不要破壞現有可玩，除非改圖後必須微調座標才能對上。

## 交付
1. 覆蓋遊戲內 png（同檔名）。
2. 更新 `docs/demo9-share/角色-立繪/` 對應 share 圖與美術館相關 share 圖。
3. `docs/demo9-teammate-art-revision-result.md`：改了哪些檔、1 女／4 斯文＋右臉錨點怎麼做的、美術館怎麼處理縱向與陰影、還剩什麼。
4. 版本仍稱 Demo 9。

成功標準：並排 1–5 一眼能看出 May 女、Void 男且不撞臉；Fury 斯文＋右臉疤或單鏡；Ling 時代感對齊；museum 不再「純豎井＋錯位互動物＋平面物帶重陰影」。

## 追加交付（士淳 00:59 要求）
改完後必須產出前後對比圖（給用戶看）：
1. `docs/demo9-share/場景-對比/demo9-chars-before-after.png`：角色 1–6 與對照圖同布局；上排或左為改前、下排或右為改後（含未大改的 3、6 也可並列標「未改／微調」）。
2. `docs/demo9-share/場景-對比/demo9-museum-before-after.png`：美術館背景／中景「純豎井＋平面物立體陰影」改前 vs「橫向展廳＋可進入長廊閱讀、去立體陰影」改後。

對比圖可用現有前後 png 合成（ImageMagick／PIL），不必再手繪一版。結果檔裡寫明這兩張路徑。
