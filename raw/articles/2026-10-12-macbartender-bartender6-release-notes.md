來源：https://www.macbartender.com/Bartender6/release_notes/
標題：Bartender 6 Release Notes（官方，Stable Releases）
發佈日期：頁面無逐版日期（sitemap lastmod 2026-10-06）；NixOS PR #570750 於 2026-10-06 將套件 6.5.2 → 6.6.2
存取日期：2026-10-12

# 摘要筆記（逐版重點，新→舊）

- 頁面列出的版本：6.6.2、6.6.1、6.5.2、6.5.1、6.4.2、6.4.1、6.3.1、6.3.0、6.2.1、6.1.3、6.1.1、6.1.0、6.0.4、6.0.3、6.0.1、6.0.0（沒有 6.0.2、6.1.2）。

## 6.6.2 / 6.6.1
- 主軸：**live mode** 穩定性與整體效能；重做 layout page（修正圖片遺失、移動中/後項目消失）。
- 自稱「lowest memory & CPU usage」，但提到在 Tahoe 上管理選單列的工作量更大。
- triggers 開啟時長時間記憶體爬升已修；triggers 更新更可靠。
- live mode 下選單列 "settle" 更快、操作次數更少。
- 新設定 "lower power usage on battery"：省電但部分 live 更新延遲。
- 6.6.2 額外：修正點擊已在 Bartender Bar 中的項目時又顯示項目的問題。

## 6.5.2
- Pro onboarding 改進；Top Shelf 新增 AirPods 的 Connection Alerts、Low Battery Alerts（Status 區）。
- 修正超寬螢幕上的選單列殘影；Mega 升級可在 license 頁更換 key。

## 6.5.1
- 推出 **Top Shelf & Bartender Pro**（Mega Supporter 已含，於設定開啟）。
- Advanced 設定：**swap items to make room**（空間不足時 / 每次點擊 / 從不）— 自稱從 Bartender 4 帶回。
- Groups 的項目在 layout 畫面有獨立「Grouped Items」區，可點擊編輯/刪除 group。
- **on-demand layout**：移動項目後自動歸位、顯示 bar 是否已排好；大量錯位時才要求按 sort。
- indexing：修正記憶體壓力下停止；降低 indexing & sorting 資源用量；live mode 會忽略尚未 indexed 的項目直到身分確定（減少滑鼠點擊）。

## 6.4.2
- Option-click Bartender 選單列項目：只顯示 always hidden，或顯示全部隱藏項目。
- 空間不足時從 Bartender Bar 點擊多個項目：顯示在可見項目左側，滿了再擠掉最近顯示者（可關閉）。
- 原本顯示為「Menu Item」的項目能取得正確名稱。

## 6.4.1
- 未識別的項目不再被移到「new items appear here」區，直到識別或使用者移動。

## 6.3.1 / 6.3.0
- 瀏海附近項目不再 "jiggle"；同一 App 的多份副本不再互換位置。
- 6.3.0：Bartender Bar 放不下被點擊的項目時改顯示在 bar 另一側；**widgets 可改名、加描述**；**相容 Live Activities**（期間移動變慢）；防止 Figma 等 App 被移動時打開選單；"Any Change" image trigger 修正；移動次數更少；**電腦鎖定、切換 Space、進入全螢幕時中止移動**。

## 6.2.1
- 改變滑鼠處理：**使用者移動滑鼠時不執行任何動作**，閒置時才快速執行。
- 修正 Little Snitch 被標為「Menu Item」；同 App 多個無唯一標籤的項目跨重開機保持位置。

## 6.1.3
- 忽略會自行移動的「Games」火箭圖示；修正游標可能保持隱藏；觸發條件不再中斷 Bartender Bar 點擊。

## 6.1.1
- 針對 **Tahoe 系統 bug** 的 workaround（執行越久越嚴重）；長時間執行下 **WindowServer CPU** 不再爬升。

## 6.1.0
- 降低移動與 image capture 的 CPU / system pressure；為「無法完全上色選單列」的 Sequoia 使用者恢復舊 styling 系統。

## 6.0.4
- image triggers 恢復；battery trigger 正確移動/隱藏電池圖示；presets 設定所需移動次數減少；Tahoe 上 styles 更可靠；indexing 找到更多名稱、過濾無效 process。

## 6.0.3
- 修正移動項目時游標遲滯或跳動。

## 6.0.1
- license email 連結自動套用授權；item spacing 正確套用；notch / 左側選單溢出時正確 overflow 到 hidden bar；indexing 頻率降低、>100 項目更可靠；Settings 新增送出 debug log；刪除的 **sub-bars** 與 groups 會從 profile 移除。

## 6.0.0
- 「re-engineered from the ground up」為 Tahoe 的效能與相容性。
- 新玻璃外觀；移動更快、次數更少；**Widgets (beta)**；notch / 左側選單溢出自動 pop；Tahoe 新 styles（glass、classic bar）。

## 頁面未提及
- Accessibility / Screen Recording 權限、AppleScript、Shortcuts/App Intents、設定匯入匯出。
