# Demo 9 組員反饋：放大角色／修正腳朝向結果

版本仍為 **Demo 9**。已覆蓋遊戲原 PNG、同步分享立繪／總覽／相關姿勢圖／實機預覽與 `docs/demo9-share.zip`。**未 commit、未 push**。

## 改動

遊戲資產目錄：`assets/environments/exploration/actors/`。

| 檔案 | 畫布／模式 | bytes | 本輪內容 |
|---|---|---:|---|
| `may_brush_strike.png` | 2580×1300 RGBA | 2753942 | image_gen 重繪較高的前傾突刺姿勢，放大角色本體，減少上方留白；保留同一女性臉型、低髮髻、綠外套、紅領巾、沾漆圍裙與大刷子。 |
| `void_lash.png` | 2603×1300 RGBA | 2309496 | image_gen 重繪較展開的踏步鞭擊構圖，增加臉、軀幹、手部及服裝的可讀尺寸；保持男性、細長四肢、後梳髮、酒紅裁縫服、量尺與細紅線鞭。 |
| `keeper_unmasked.png` | 706×1280 RGBA | 1188304 | 僅以 image_gen 新畫的右靴／必要踝部替換原圖對應區域。右側腳尖改朝左，與身體朝向一致；左靴維持原圖。 |
| `may_brush.png` | 970×1300 RGBA | 1635273 | 原圖可見內容已達 910×1260、接近滿版，故保留原圖；與新版突刺維持同一女性身份及服裝，分享立繪亦同步核對。 |

以上畫布尺寸、檔名皆未改。May 突刺的可見剪影高度由 **870 → 1260 px（+44.8%）**，非透明像素數增加 **48.3%**。Void 原本已接近畫布全高，因此透過重繪放大臉／軀幹與展開姿勢提高佔幅，剪影寬度由 **983 → 2504 px**、非透明像素數增加 **181.2%**；並非把舊圖放大貼回。這些是畫布佔幅指標，不代表角色世界觀身高或碰撞尺寸改變。

Keeper 變更侷限在 `(252,1111)–(464,1260)` 的靴子／踝部區域；**y < 1111 的全部原圖像素逐位元組一致**，臉、頭髮、大衣、手與帽子都保留原樣。新靴由內建 image_gen 生成，程式僅透明裁切、等比縮放及裝回原畫布，沒有用程式畫角色。

已以任務開始時 SHA-256 核對：遊戲資產只有上述三張 PNG 改變；May 站姿、Fury、Ling、Detective 與美術館相關資產保持本輪開始時內容。未改遊戲腳本、碰撞或美術館。

## 分享圖與前後對比

- 必交對比圖：[`demo9-chars-scale-feet-before-after.png`](demo9-share/場景-對比/demo9-chars-scale-feet-before-after.png)
  - 完整路徑：`docs/demo9-share/場景-對比/demo9-chars-scale-feet-before-after.png`
  - 尺寸 **2100×1500**，大小 **905793 bytes**，可正常開啟。
  - 內容為 1 May strike／2 Void／3 Keeper，上排「改前」、下排「改後」。
  - 改前來自 `/tmp/demo9-scale-feet-before/`，已確認與本輪修改前工作區逐檔相同；改後來自覆蓋後遊戲 PNG。
  - 每組前後均使用完整原畫布與同一縮放比例，不裁掉改前留白；另附同一裁切範圍的 Keeper 腳部近照。
- `docs/demo9-share/角色-立繪/` 四張對應立繪與遊戲 PNG 位元組一致。
- [`demo9-share-cast-overview.png`](demo9-share/角色-合成/demo9-share-cast-overview.png) 已重建為三欄兩列，增加閱讀空間；May／Void／Keeper 合成、姿勢圖、全角色圖及 `docs/demo9-compare-*` 對應圖同步。
- 三張相關角色實機預覽及 `docs/demo9-compare-v9-previews.png` 已同步；`docs/exploration-demo/v9-cast.png` 亦由 Godot 更新。
- `docs/demo9-share.zip` 已重建，包含新立繪、總覽及本輪前後對比。
- 重建工具：`python3 tools/dev/export_demo9_scale_feet.py`；完整輸出清單與指標：[`demo9-scale-feet-validation.json`](demo9-scale-feet-validation.json)。

## 驗證

- `file`：三張覆蓋 PNG 均為原尺寸、8-bit RGBA；Pillow 完整解碼成功，alpha 最小值 0、最大值 255，透明底保留，沒有實色背景。
- Godot **4.6.2** 完成資產重新匯入，並執行現有 `tools/dev/validate_v9_art.gd` 相同檢查流程：**48 passed / 0 failed**。
- 驗證使用 `tmp/demo9-scale-feet/validate_scale_feet.gd` 副本，僅限制截圖輸出為本輪 May／Void／Keeper 與 cast，原驗證工具未改。實機驗證紀錄：[`demo9-scale-feet-godot-qa.log`](exploration-demo/demo9-scale-feet-godot-qa.log)。
- 已人工檢視透明立繪、總覽、同尺度對比與 Void 實機截圖；PNG／分享立繪一致性、指定範圍外資產雜湊與 `git diff --check` 通過。
- 所有新角色內容使用內建 **image_gen**；Pillow 僅處理透明裁切、等比裝版與合成。採用的完整提示詞與來源原圖記於 [`demo9-scale-feet-prompts.md`](demo9-scale-feet-prompts.md)。

結束時間：**2026-11-10 01:43:21 Asia/Shanghai**。未 commit／未 push。
