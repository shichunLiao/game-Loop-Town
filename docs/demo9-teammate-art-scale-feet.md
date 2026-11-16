# Demo 9 組員反饋美術改版（放大 1／2＋修正 3 的腳）— Codex 任務

版本名仍叫 **Demo 9**（不要改成 demo10）。不要問用戶。不要 commit、不要 push。
完成後寫 `docs/demo9-teammate-art-scale-feet-result.md`，覆蓋遊戲內原檔，並同步相關分享圖。

## 對照圖（必看）
`docs/demo9-teammate-feedback-scale-feet.png`
- 紅框標出 **1 may_brush_strike**、**2 void_lash**、**3 keeper_unmasked 下半／腳**。
- 組員原話（士淳）：「1跟2能不能放大一点，图片里看不清楚，再来就是3的脚，脚的方向反了。改完之后一样给我一个前后对比图」

| # | 檔名 | 遊戲內路徑 | 本輪要求 |
|---|---|---|---|
| 1 | may_brush_strike（必要時 may_brush 同套） | `assets/environments/exploration/actors/may_brush_strike.png`、`may_brush.png` | **在畫布內明顯放大**角色本體，線條細節可辨；不是只在分享拼圖裡 scale up 變糊 |
| 2 | void_lash | `…/actors/void_lash.png` | 同上，角色本體放大、看清楚；維持與 May 拉開辨識的男性高挑裁縫形象 |
| 3 | keeper_unmasked | `…/actors/keeper_unmasked.png` | **只修腳／必要踝部銜接**：腳朝向反了（靴子朝向／解剖與站姿不符）；其餘儘量不變 |

**不要改** fury_lunge、ling_giant、detective（除非讀取做對比拼圖）。不要動美術館。

## 現況參考
- 上一輪結果：`docs/demo9-teammate-art-revision-result.md`
- 現檔尺寸（保持畫布尺寸與檔名不變，只改內容構圖／比例）：
  - may_brush.png：970×1300 RGBA
  - may_brush_strike.png：2580×1300 RGBA
  - void_lash.png：2603×1300 RGBA
  - keeper_unmasked.png：706×1280 RGBA
- 改前備份（對比用）：`/tmp/demo9-scale-feet-before/`（與任務啟動時工作區現檔一致）

## 硬性規則
1. 所有新圖由 Codex／內建 **image_gen** 繪製；Pillow／ImageMagick 只做透明裁切、等比縮放進原畫布、分享圖／前後對比合成——**禁止用程式生成角色美術代替重繪**。
2. 透明底角色立繪；風格延續現有厚塗、灰暗、泥土色；覆蓋同檔名。
3. **放大的正確做法**：重繪時讓角色剪影在畫布內佔更大比例（更少透明留白、更高可讀身高），再裝回原畫布尺寸。禁止「整張 PNG 雙線性放大再糊糊貼回」當唯一手段。
4. May 站姿 `may_brush` 若與 strike 同套明顯偏小，一併放大並保持同一女性身份／服裝一致。
5. Keeper：以現檔為底修腳；腳應與身體朝向／重心一致（不要腳尖整體朝反方向）；踝與靴筒銜接自然；帽、大衣、臉、手儘量不變。
6. 版本仍稱 Demo 9。

## 交付（必須）
1. 覆蓋遊戲內 png：
   - `assets/environments/exploration/actors/may_brush_strike.png`（必）
   - `assets/environments/exploration/actors/may_brush.png`（若同套偏小則必）
   - `assets/environments/exploration/actors/void_lash.png`（必）
   - `assets/environments/exploration/actors/keeper_unmasked.png`（必）
2. 同步分享圖至少：
   - `docs/demo9-share/角色-立繪/` 對應檔
   - `docs/demo9-share/角色-合成/demo9-share-cast-overview.png`（及 may／void／keeper 相關合成／姿勢圖若存在）
   - 可用既有 `python3 tools/dev/export_demo9_teammate_revision.py` 或同等合成；不要留下過期 overview。
3. **前後對比圖（用戶明確要求）**：
   - 路徑：`docs/demo9-share/場景-對比/demo9-chars-scale-feet-before-after.png`
   - 內容：角色 **1／2／3**（May strike、Void、Keeper）**改前 vs 改後**
   - 改前：`/tmp/demo9-scale-feet-before/` 內對應 png（本輪啟動前工作區）
   - 改後：覆蓋後的遊戲內現檔
   - 標清楚「改前／改後」；可用 PIL／ImageMagick 拼，不必再手繪一版
4. 結果檔：`docs/demo9-teammate-art-scale-feet-result.md`
   - 改了什麼、路徑、尺寸、驗證、對比圖路徑與 bytes、結束時間（Asia/Shanghai）、未 commit／未 push
5. 驗證：
   - 若方便跑 `tools/dev/validate_v9_art.gd`（Godot）就跑；至少確認 PNG 可開、RGBA、尺寸與原畫布一致、透明底仍在
   - `file`／`sips` 檢查即可作最低門檻

## 成功標準
- may_brush_strike（必要時 may_brush）、void_lash 在畫布內明顯更大、更清楚
- keeper_unmasked 腳朝向正確
- `demo9-chars-scale-feet-before-after.png` 存在且非空
- 結果檔寫好
- 未 commit／未 push
