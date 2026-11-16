# Demo 9 組員反饋美術改版結果

版本維持 **Demo 9**。已覆蓋遊戲原路徑、同步分享圖及分享壓縮包；未 commit、未 push。所有新美術均由內建 **image_gen** 繪製。Pillow 僅用於透明留白裁切、等比縮放、圖集排版及分享圖合成，沒有用程式代畫角色或場景。

## 角色結果

| 編號 | 覆蓋檔案（`assets/environments/exploration/actors/`） | 完成內容 |
|---|---|---|
| 1 | `may_brush.png`、`may_brush_strike.png` | 改為成年女性：女性臉型、低髮髻與側髮、女性身形；兩張沿用同一身份、綠外套、紅領巾、橙黃沾漆圍裙與大刷子。站立持刷、向左突刺兩個姿勢保持一致。 |
| 2 | `void_lash.png` | 保持男性；改為高挑長腿、較直立的踏步、後梳髮與高額角。酒紅背心／燕尾、量尺與細紅線鞭延續裁縫身份，與 May 的綠外套、裙狀漆痕及粗大刷頭形成區別。 |
| 4 | `fury_lunge.png` | 整齊側分、白襯衫、深棕整齊外套與背心，閉嘴、克制表情；保留爆發弓步及雙拳。原始朝左立繪的可見面為角色右側，右眼大圓單鏡及鏈條、同側斜向臉疤作識別錨點。 |
| 5 | `ling_giant.png` | 保留巨大藤木根部、空白木臉、雙馬尾與暗紅緞帶；改用高領舊亞麻、深棕合身衣身、古銅扣、長裙和舊袖口。以暗土色、灰褐木質與厚塗材質接近其餘角色的舊時代感。 |
| 3、6 | `keeper_unmasked.png`、`detective.png` | 本輪未更動遊戲資產。 |

上述 5 張角色 PNG 均為實際 RGBA 透明底，保留原畫布尺寸與檔名。圖像先檢查 alpha，再放到有色底檢查輪廓；生成預覽顯示的部分褐色暈染位於透明像素 RGB，沒有把它作為實底貼入遊戲。遊戲沿用原有朝向鏡像機制，右臉錨點以原始立繪方向定義。

並排檢視：[六人改版總覽](demo9-share/角色-合成/demo9-share-cast-overview.png)。

## 美術館結果

覆蓋：

- `assets/environments/exploration/backgrounds/museum.png`
- `assets/environments/exploration/midgrounds/museum_mid.png`
- `assets/environments/exploration/midgrounds/museum_depth.png`

背景改為低而寬的橫向展廳：水平牆板、畫作與連續地面承接左右行走，右後方一個窄門只作次要縱深入口；移除原本整張圖中央消失點長廊／高聳中殿的主導構圖。背景不再烘焙前景互動家具，展架、工作桌與畫框仍由原有中景／物件獨立擺放，因此不會把可互動物直接畫在遠處走廊地板上。

兩張中景圖重新繪製為較正面的平面拼貼，減弱厚頂面與外圍投影；各四格維持原有用途，重新裝入現有 `art-regions.json`／AtlasTexture 裁切範圍，沒有更改圖集索引。保留材質內部筆觸及明暗，不加外圍陰影圈。

新增 `assets/environments/exploration/terrain/museum_flat.png`：由 image_gen 畫出的正面薄石飾條，沒有可見立體頂面／側面與懸浮投影。`exploration_room.gd` 只對 `background == "museum"` 的房間啟用 `flat_gallery`；`exploration_platform.gd` 使用該貼圖並省去額外亮邊。其他房間的共用石平台不受此切換影響。平台、支撐牆、碰撞、機關、出口及人物座標均未改動。

檢視：[背景前後對照](demo9-share/場景-對比/demo9-share-compare-bg-museum.png)、[中景圖集](demo9-share/場景-對比/demo9-share-museum-mid.png)、[美術館實機畫面](demo9-share/場景-房間/demo9-share-scene-wax_museum.png)。

## 分享圖與來源

`docs/demo9-share/角色-立繪/` 的 5 張對應分享立繪與遊戲 PNG 完全一致；May、Void、Fury、Ling 的角色合成／姿勢圖、六人總覽、全角色圖，以及相關實機預覽已同步。美術館的背景、中景、縱深、前後對照、房間截圖與背景總覽亦已更新。原有 `docs/demo9-share.zip` 已重建，避免壓縮包保留舊圖。

- [完整更新清單（51 個輸出）](demo9-teammate-art-share-manifest.json)
- [實際採用的提示詞組](demo9-teammate-art-prompts.json)
- 分享圖重建工具：`python3 tools/dev/export_demo9_teammate_revision.py`
- 原始生成圖保留於本機 `~/.codex/generated_images/01a1c13d-cba5-7813-8837-a8d1c7e8db02/`，正式資產均已保存至專案。

## 驗證

以 Godot **4.6.2** 執行匯入與現有驗證工具：

- `validate_v9_art.gd`：**48 passed / 0 failed**；另以有視窗模式重跑並產生角色實機截圖。補充 May 持刷站姿與 Fury 弓步截圖，方便直接檢查本輪指定姿勢。
- `validate_v9_museum_mid.gd`：**8 格圖集、3 房間通過**（`wax_lane`、`wax_museum`、`wax_basement`），有視窗模式產生截圖。
- 5 張角色透明通道、8 格中景有效內容、遊戲／分享資產一致性檢查通過；角色與既有美術館畫布尺寸維持原值。
- `git diff --check` 通過。

驗證資料：[資產檢查](exploration-demo/demo9-teammate-art-validation.json)、[角色有視窗驗證紀錄](exploration-demo/demo9-teammate-characters-render-qa.log)、[美術館驗證紀錄](exploration-demo/demo9-teammate-museum-qa.log)。Headless 角色檢查在全部通過後有退出時的 ObjectDB／3 個資源仍被引用訊息；有視窗重跑同樣 48 項通過，紀錄沒有該訊息。

## 尚未變更與後續建議

本輪重繪範圍為指定的 May 兩張持刷姿勢、Void 鞭擊、Fury 弓步及 Ling 巨型態。May 其他階段、Fury 待機／出拳等仍為原設計，尚未延伸這次性別／單鏡身份到全部形態；角色姿勢總圖保留這些現況，沒有以分享圖掩蓋遊戲實際資產。

長廊入口目前是背景中的空間提示，沒有新增可進入傳送點。後續若實作「橫向展廳 → 入口 → 獨立長廊房間 → 橫向深入」，建議將窄門做成有提示的通行區，長廊使用獨立房間與對應返回口，再把鏡室入口及互動展品配置到各房間的同一地面基準。現有路線提示仍提及斜井／樓梯，應在實際改關卡時同步調整。這些屬於後續關卡流程，不在本輪改動，以保留現有可玩路線。


## 前後對比圖

補齊士淳要求的兩張前後對比（合成時間：**2026-11-10 01:21 Asia/Shanghai**）：

1. `docs/demo9-share/場景-對比/demo9-chars-before-after.png`  
   - 上排＝改前（`git HEAD` 遊戲立繪，對應組員反饋圖角色 1–6）  
   - 下排＝改後（本輪覆蓋之 May／Void／Keeper／Fury／Ling／Detective）  
   - 改前素材：`assets/environments/exploration/actors/` 於 HEAD 的 may_brush_strike、void_lash、keeper_unmasked、fury_lunge、ling_giant、detective  
   - 改後素材：同路徑目前工作區檔案（Keeper／Detective 未改，並排標示）

2. `docs/demo9-share/場景-對比/demo9-museum-before-after.png`  
   - 上排背景：改前純豎井長廊 vs 改後橫向展廳＋窄長廊入口（`museum.png` HEAD vs 現檔）  
   - 下排中景：改前平面物立體陰影 vs 改後平面拼貼去外圍陰影（`museum_mid.png` HEAD vs 現檔）
