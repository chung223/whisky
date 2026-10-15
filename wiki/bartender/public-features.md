---
title: Bartender 6 公開功能清單
type: bartender
tags: [bartender, public-sources, features, bartender-pro, top-shelf]
sources:
  - raw/github/readmes
  - raw/articles/2026-10-12-macbartender-bartender6-product-page.md
  - raw/articles/2026-10-12-macbartender-bartender6-release-notes.md
  - raw/articles/2026-10-12-macbartender-support-page.md
  - raw/articles/2026-10-12-macbartender-permission-docs.md
  - raw/articles/2026-10-12-macbartender-meet-bartender-6.md
  - raw/articles/2026-10-12-macbartender-bartender-pro.md
  - raw/articles/2026-10-12-macbartender-meet-bartender-7.md
  - raw/articles/2026-10-12-macbartender-bartender7-release-notes.md
  - raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md
  - raw/articles/2026-10-12-sixcolors-top-shelf.md
  - raw/articles/2026-10-12-thesweetbits-bartender-review.md
  - raw/articles/2026-10-12-brettterpstra-bartender-pro-review.md
  - raw/articles/2026-10-12-setapp-bartender-listing.md
  - https://www.macbartender.com/Bartender6/
  - https://www.macbartender.com/Bartender6/release_notes/
  - https://www.macbartender.com/Bartender6/support/
  - https://www.macbartender.com/pro/
updated: 2026-10-14
---

# Bartender 6 公開功能清單

> **【公開資料】本頁只整理官網、release notes、Setapp 與第三方評測等公開來源，不是逆向結果。**
> 逆向（bundle 資源檔）得到的功能清單見 [Bartender 6 功能盤點（從 App 資源檔）](features-from-resources.md)；
> 兩頁可以互相對照：公開資料講「宣稱做什麼」，資源檔講「實際帶了什麼」。
> 產品沿革與爭議見 [Bartender 歷史](history.md)；每個 macOS 版本對選單列工具的影響見 [macOS 選單列平台變化](../concepts/macos-menu-bar-platform.md)。

標記：每條功能後面的來源連到 `raw/articles/` 的摘要檔或原始網址。
**【公開】** = 官方或第三方公開描述；**【推論】** = 從公開資料推得；**【未知】** = 公開資料沒有交代。

## 版本與定位

| 項目 | 內容 | 來源 |
|---|---|---|
| 目前版本 | 6.6.2（Setapp 也上架 6.6.2；需求 macOS 14.0+） | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)、[Setapp](../../raw/articles/2026-10-12-setapp-bartender-listing.md) |
| 定位 | 「Redesigned ground-up for macOS Tahoe」，Liquid Glass 外觀 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| 支援系統 | 產品頁卡片寫 Tahoe、Sequoia、Sonoma；同頁 FAQ 與 support 頁寫「Tahoe & Sequoia」，Sonoma 使用者被導去 Bartender 5。**官方說法互相矛盾**；bundle 最低系統是 14.0 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[support](../../raw/articles/2026-10-12-macbartender-support-page.md) |
| 後繼版本 | Bartender 7 只支援 macOS 27 Golden Gate（2026-09-14）；Tahoe 使用者仍用 6 | 【公開】[Meet Bartender 7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |

## 1. 隱藏與分區

| 功能 | 說明 | 首見 | 來源 |
|---|---|---|---|
| 三個區段 | Shown / Hidden / Always Hidden，拖放分區；可管理第三方與 macOS 系統項目 | B4 起（layout 畫面） | 【公開】[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md)、[B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| 新項目出現位置 | 「new items appear here」區：新出現的項目預設放哪一區；6.4.1 起未識別項目不放進去 | B4 | 【公開】[B5/B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[6.4.1](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Option-click | Option-click Bartender 圖示：只看 Always Hidden，或看全部隱藏項目 | 6.4.2 | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Swap items to make room | 空間不足時把顯示中的項目換成隱藏項目；設定：需要時 / 每次點擊 / 從不（官方說從 B4 帶回） | B4、6.5.1 回歸 | 【公開】[6.5.1](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Live mode vs on-demand layout | Live：持續維持排列；On-demand：只在使用者要求時排列（6.5.1 起移動後自動歸位、顯示是否已排好） | 6.x | 【公開】[6.5.1、6.6.x](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)、[support](../../raw/articles/2026-10-12-macbartender-support-page.md) |
| Item indexing | Advanced 設定；記錄項目身分，重開機後保持順序；6.0.x–6.5.1 多次改善 | 6.x | 【公開】[support](../../raw/articles/2026-10-12-macbartender-support-page.md)、[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Lower power usage on battery | 用電池時降低 live 更新頻率 | 6.6.1 | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |

## 2. 顯示隱藏項目（Quick Reveal）

| 功能 | 說明 | 來源 |
|---|---|---|
| Speed（舊名 Quick Reveal） | 在選單列 **swipe、scroll、click、hover** 立即顯示隱藏項目。「Quick Reveal」是 B4 的名稱（滑鼠移到選單列或點擊） | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| 點 Bartender 圖示 | 點自己的選單列項目展開 Hidden 區 | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)、[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| 圖示變化時暫時顯示（Show for Updates） | 依 any change、icon/image matching、script 暫時顯示某項目；B6 的 image triggers 於 6.0.4 恢復 | 【公開】[B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[6.0.4、6.3.0](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 滑鼠移動中不動作 | 6.2.1 起：使用者移動滑鼠時不執行排列，閒置後才做；6.3.0 起鎖定、切換 Space、全螢幕時中止移動 | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |

【推論】「自動再隱藏」「hover 延遲」等細項在公開頁面沒有逐條列出，但資源檔有，見 [資源檔盤點](features-from-resources.md)。

## 3. Bartender Bar

| 功能 | 說明 | 來源 |
|---|---|---|
| Bartender Bar | 在選單列**下方**另開一條 bar 放隱藏項目；顯示的是項目的**截圖**，因此會觸發 macOS 紫色 screen capture 指示器 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 點擊轉發 | 在 Bartender Bar 點項目會把真實項目顯示出來；放不下時顯示在 bar 另一側（6.3.0）、多個時排在可見項目左側並擠掉最近者（6.4.2，可關） | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 外觀 | 隨選單列 style；B7 起可獨立設定 style | 【公開】[Meet Bartender 7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |

## 4. 瀏海（notch）處理

| 功能 | 說明 | 來源 |
|---|---|---|
| Full access | 被瀏海遮住的項目：暫時隱藏目前顯示中的項目，騰出空間給要顯示的隱藏項目 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| Overflow 自動 pop | 6.0.0：超出瀏海或左側 App 選單的項目自動移入 hidden bar；6.3.1：瀏海附近項目不再抖動 | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Top Shelf（Pro） | 把瀏海變成類 Dynamic Island 的工具區（見第 11 節）；Bartender 展開 bar 時讓開 | 【公開】[Bartender Pro](../../raw/articles/2026-10-12-macbartender-bartender-pro.md) |

【推論】資源檔的「Notch Bar」（`NotchBar_NotchBar.bundle`）很可能就是 Top Shelf 的內部名稱或其前身；公開資料沒有「NotchBar」這個名字。

## 5. 搜尋與熱鍵

| 功能 | 說明 | 來源 |
|---|---|---|
| Quick Search | 鍵盤搜尋、顯示並啟用任一選單列項目；使用時可能出現 screen capture 指示器 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| 任一項目的熱鍵 | 指定熱鍵即顯示並啟用該項目（B4 起） | 【公開】[B4/B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| 全域熱鍵 | 切換 Bartender、開搜尋（Brett Terpstra 用熱鍵搜尋） | 【公開】[Terpstra](../../raw/articles/2026-10-12-brettterpstra-bartender-pro-review.md) |
| Spotlight 搜尋 | B4 有「用 Spotlight 以 "Bartender " 開頭搜尋項目」；B6 公開資料未再提 | 【公開】[B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)；B6【未知】 |

## 6. Groups（子選單列）

| 功能 | 說明 | 來源 |
|---|---|---|
| Menu Bar Item Groups | 多個項目合併為一個可自訂的項目，點擊或 hover 展開（官方範例：雲端硬碟、Wi-Fi+VPN、媒體）；B5 引入 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[groups 文](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| Grouped Items 區 | 6.5.1：layout 畫面有獨立「Grouped Items」區，點 group 可編輯/刪除 | 【公開】[6.5.1](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Sub-bars | 6.0.1 release notes 用「sub-bars & groups」一詞（刪除後會從 profile 移除） | 【公開】[6.0.1](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 只在特定 preset 出現的 group | — | 【公開】[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |

## 7. Spacers 與 Spacing

| 功能 | 說明 | 來源 |
|---|---|---|
| Menu bar Spacers | 在項目之間插入空白、文字、emoji，用於視覺分組（B4 起；B7 加 SF Symbol、per-profile） | 【公開】[B4/B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |
| Spacing | 縮小所有項目間距，在瀏海前放下更多項目（B4 起；6.0.1 修正套用） | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| 間距需登出 | B7 Beta Three：spacing 改變要登出再登入，所有 App 才會套用 | 【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |

## 8. Presets（Profiles）

| 功能 | 說明 | 來源 |
|---|---|---|
| Presets | 不限數量的整條選單列配置；例：錄影/分享螢幕時只顯示 macOS 預設項目、工作 vs 在家 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| 由 Focus 套用 | B5 起 presets 可由 macOS Focus modes 套用 | 【公開】[B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| On-demand 限制 | 公開資料只說 6.0.4 減少設定 presets 需要的移動次數；資源檔字串（逆向【觀察】）說 On-Demand 下 presets 不能用 | [資源檔盤點](features-from-resources.md) |
| 依螢幕切換 | B7 才公開宣告（presets 與螢幕組合同步） | 【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |

## 9. Triggers

| 條件 | 說明 | 來源 |
|---|---|---|
| Battery | 用電池/充電/特定電量（6.0.4 修正電池圖示的移動與隱藏） | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| Wi-Fi | 連線/未連線/特定網路 | 同上 |
| Location | 在特定位置 | 同上 |
| Time / Date | 排程 | 同上 |
| App | 某 App 在前景/執行中 | 【公開】[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| Script | 自訂腳本（例：VPN、AirPods 連線） | 【公開】[B5 開發者文](../../raw/articles/2026-10-12-macbartender-history-posts.md)、[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| Image / Any Change | 圖示變化（6.3.0 修正「Any Change」） | 【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Time Machine | 備份中顯示（B4 內建） | 【公開】[B4 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |

- 動作：套用 preset，或顯示一組項目；條件可組合。【公開】[B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)
- 6.6.x 修正 triggers 長時間記憶體爬升。【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)

## 10. 選單列外觀（Styling）

| 功能 | 說明 | 來源 |
|---|---|---|
| Tint | 純色或漸層 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| 形狀 | rounded、pill（可左右分離 pills） | 【公開】同上、[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| Border / Shadow / 圓角螢幕 | 可設顏色、粗細 | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md) |
| Per-menu-bar / per-space | style 套用在個別選單列，用來辨識目前 Space | 【公開】同上 |
| Tahoe styles | Standard、Solid Color、Gradient、Material、Glass、Classic Bar（類 Sequoia） | 【公開】[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md)、[6.0.0](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| Sequoia 舊 styling | 6.1.0 為「無法完全上色選單列」的 Sequoia 使用者恢復舊系統 | 【公開】[6.1.0](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 新螢幕套預設 style | B5 5.2.x 設定 | 【公開】[B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |

## 11. Bartender Pro 與 Top Shelf（2026-05 起）

Top Shelf 是 Bartender Pro 訂閱的第一個工具，放在瀏海（無瀏海螢幕則為選單列中央的膠囊）。

| 元件 | 說明 | 來源 |
|---|---|---|
| 觸發 | 游標移到瀏海 hover 展開；熱鍵可叫出或跳到指定面板 | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)、[Terpstra](../../raw/articles/2026-10-12-brettterpstra-bartender-pro-review.md) |
| Widgets | Weather（home/away、降雨提醒）、Music / Vinyl（Apple Music、Spotify）、Calendar（會議 join）；同時只顯示 2 個 | 同上、[Pro](../../raw/articles/2026-10-12-macbartender-bartender-pro.md) |
| Files & AirDrop | 最多 6 個檔案暫存、可 AirDrop、保留時間可設（最多一週） | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)、[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| Clipboard | 歷史、搜尋、過濾密碼、忽略特定 App、最多 100 筆 | 同上 |
| Status / Live activities | 音量、亮度、電量 banner；AirPods 連線與低電量（6.5.2）；Claude Code / Codex agent 狀態；會議提醒 | 【公開】[Pro](../../raw/articles/2026-10-12-macbartender-bartender-pro.md)、[6.5.2](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 多螢幕 | 可選顯示在哪個螢幕（含只在有瀏海的螢幕） | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md) |
| Agent 狀態 HTTP bridge | 第三方 plugin herdr-bartender 說 Top Shelf 有「NotchBar AI Agent HTTP bridge」（本機 HTTP），狀態分 Working／Waiting／Done／Idle／Ended；Bartender 在 `~/Library/Application Support/Bartender/NotchBar/AgentStatus/hooks` 放了 Claude Code 與 Codex 的 hooks | 【第三方】[herdr-bartender README](../../raw/github/readmes/voodootikigod__herdr-bartender.md)（2026-10-14 補） |

【推論】Calendar、Location、Bluetooth 的 usage string（資源檔可見）對應 Top Shelf / widgets 的行事曆、天氣與 AirPods 功能，以及 location trigger；官方公開頁面沒有說明這些權限。

## 12. Widgets（beta，自訂選單列項目）

| 項目 | 說明 | 來源 |
|---|---|---|
| 定位 | 「create your own menu bar items」，觸發幾乎任何動作，no code；6.0.0 推出 beta | 【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)、[6.0.0](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 編輯器 | 類似 Shortcuts 混 Yahoo Pipes 的節點式編輯；分類 Actions、Music、Logic、Utility、Input、Triggers；選項含 image、text、left/right click、activate、show、hide | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)、[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md) |
| 命名 | 6.3.0 起可改名、加描述 | 【公開】[6.3.0](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 評價 | Six Colors：「underbaked」，連 CPU widget 都難做出 | 【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md) |
| 文件格式 | `.BartenderWidget` 文件：公開資料**未提**；資源檔有此 document type | 【未知】公開；見 [資源檔盤點](features-from-resources.md) |
| 起源 | Applause 2024-06 承諾的第一個新功能（WYSIWYG 編輯器，原本在 Ben 的 roadmap） | 【公開】[Let's Try This Again](../../raw/articles/2026-10-12-macbartender-lets-try-this-again.md) |

## 13. 自動化介面

| 介面 | Bartender 6 的公開狀態 | 來源 |
|---|---|---|
| AppleScript | B4、B5 產品頁明列「Use Apple Script to show and activate menu bar items」；B6 產品頁未提，但 B7 說「updated AppleScript」 | 【公開】[B4/B5 頁](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md)；B6 的 sdef 見 [資源檔盤點](features-from-resources.md) |
| App Intents / Shortcuts | 官方只在 **Bartender 7** 宣告新增（get items、show/click、切 profile、toggle bar）；B6 公開資料無 | 【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md)；【推論】資源檔顯示 6.6.2 只有一個 Focus Filter intent |
| URL actions | B7 Automations 才提 | 【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |
| Raycast | B7 官方 extension「即將推出」 | 【公開】[B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |

## 14. 多螢幕

- Styles 套用在個別選單列（每個螢幕/Space 可不同）。【公開】[產品頁](../../raw/articles/2026-10-12-macbartender-bartender6-product-page.md)
- 多螢幕行為可設定。【公開】[TheSweetBits](../../raw/articles/2026-10-12-thesweetbits-bartender-review.md)
- 6.5.2 修正超寬螢幕殘影；B5 有多次「multimonitor」crash 修正。【公開】[release notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)、[B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)
- 【未知】B6 在非作用中螢幕的選單列如何處理隱藏項目，公開資料沒交代（資源檔有相關字串）。

## 15. 設定匯入匯出

- B5 → B6：設定**不會**轉移（Six Colors）。官網 FAQ 有此題但答案為動態載入，未取得。【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)
- B6 → B7：Beta Two 起有實驗性「Settings Imports」匯入 profiles（非破壞性）；support 頁說「may be able to import your profiles」。【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md)、[support](../../raw/articles/2026-10-12-macbartender-support-page.md)
- `.BartenderPreferences` 匯出文件：**公開資料完全沒有**；只在資源檔看到。【未知】

## 16. 權限（官方說法）

| 權限 | 官方給的理由 | 來源 |
|---|---|---|
| Accessibility | 「to move your menu bar items」以排列項目 | 【公開】[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| Screen Recording | 讀取選單列項目以顯示正確圖片，用於 Settings（layout）、Bartender Bar、Search；只讀選單列區域 | 同上 |
| 紫色指示器 | 每次擷取後 macOS 顯示約 20 秒，Bartender 無法隱藏；少用 Bartender Bar 可減少 | 同上 |
| Screen Recording 可選 | B5 5.3.4 起可關（但失去許多功能）；B6：先排好再關，進入 locked-down mode；B7：完全可選，以 App icon 代替截圖 | 【公開】[B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[Meet B6](../../raw/articles/2026-10-12-macbartender-meet-bartender-6.md)、[Meet B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |

- 移動機制的公開線索：官方說無法移動的項目是因為擁有它的 App 擋掉 **⌘+drag**（覆寫 `sendEvent:`）。【推論】Bartender（至少到 B6）是用模擬 ⌘-drag 事件移動項目，所以需要 Accessibility。[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md)
- Tahoe 上 B6 在 live mode 會「定期移動你的滑鼠」以維持排列；on-demand mode 只在要求時移動。【公開】[support](../../raw/articles/2026-10-12-macbartender-support-page.md)

## 17. 隱私聲明

- App 不傳任何資料；截圖只在記憶體、不持久化（B6）。B7 改為**快取在磁碟**但宣稱不離開裝置。【公開】[Meet B6](../../raw/articles/2026-10-12-macbartender-meet-bartender-6.md)、[Meet B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md)
- 隱私權政策：App 不傳資料給開發者；網站用 Google Analytics、Mixpanel。【公開】[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md)
- 背景：2024 年 5.0.52 曾短暫加入 Amplitude，見 [歷史](history.md)。

## 18. 對照：Bartender 7 新增（2026-09，macOS 27）

給 Whisky 定位參考，非 B6 功能：Command Bar（搜尋 + 剪貼簿 + presets + automations）、mouse-free 移動、Screen Recording 完全可選、Focus Mode 熱鍵（一鍵藏全部）、可隱藏 clock / Control Center、App Intents、Automations（排程、URL）、presets 依螢幕組合。【公開】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md)

## 對 Whisky 的意義

- **核心功能面**（必做）：三區段隱藏、hover/click/scroll/swipe 顯示、Bartender Bar 類的下拉 bar、搜尋、單項目熱鍵、spacers、groups、presets + triggers、瀏海處理。
- **可延後**：styling、widgets、Top Shelf（Pro 等級的附加價值，與選單列管理本身無關）。
- **差異化機會**：公開評價的主要痛點是 Tahoe 上**搶滑鼠、ghost clicks、re-index 吃 CPU**，以及 Screen Recording 的信任問題（見 [歷史](history.md)）。Whisky 應從第一天就做到「不動滑鼠、Screen Recording 可選」。
- 平台限制（macOS 27 同一 App 的項目一起隱藏、系統項目不可移等）會直接限制功能設計，見 [macOS 選單列平台變化](../concepts/macos-menu-bar-platform.md)。

## 未知 / 待查

- 【未知】B6 的 AppleScript 字典是否就是公開說的「show and activate」那組指令（資源檔盤點已列 sdef 指令，需與 B7 對照）。
- 【未知】`.BartenderPreferences` 的內容格式與能否被 B7 匯入。（2026-10-15：UserDefaults 裡的版面格式已知，見 [架構](architecture.md)「持久化」。）
- 【未知】官網 FAQ「Can I get Bartender 6 on Setapp?」等答案（client-side 載入未取得）；Setapp 會員是否含 Pro。
- 【未知】Widgets 的 script 節點是否能當 data source（B7 宣稱 custom scripts，B6 公開資料未證實）。
