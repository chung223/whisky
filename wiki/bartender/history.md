---
title: Bartender 產品歷史、所有權與使用者評價
type: bartender
tags: [bartender, history, applause, pricing, trust, public-sources]
sources:
  - raw/articles/2026-10-12-macbartender-history-posts.md
  - raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md
  - raw/articles/2026-10-12-macbartender-lets-try-this-again.md
  - raw/articles/2026-10-12-tidbits-bartender-quiet-acquisition.md
  - raw/articles/2026-10-12-macbartender-meet-bartender-6.md
  - raw/articles/2026-10-12-mjtsai-bartender-6.md
  - raw/articles/2026-10-12-community-threads-bartender6.md
  - raw/articles/2026-10-12-9to5mac-decade-with-bartender.md
  - raw/articles/2026-10-12-macbartender-bartender-pro.md
  - raw/articles/2026-10-12-macbartender-meet-bartender-7.md
  - raw/articles/2026-10-12-macbartender-bartender7-release-notes.md
  - raw/articles/2026-10-12-macbartender-support-page.md
  - raw/articles/2026-10-12-github-ice-releases.md
  - raw/articles/2026-10-12-github-ice-issue-954-macos27.md
  - raw/articles/2026-10-12-setapp-bartender-listing.md
  - https://tidbits.com/2024/06/05/bartender-developer-explains-and-apologizes-for-quiet-acquisition/
  - https://www.macbartender.com/B5blog/Lets-Try-This-Again/
updated: 2026-10-12
---

# Bartender 產品歷史、所有權與使用者評價

> **【公開資料】** 本頁整理官方部落格、新聞與社群討論，不是逆向結果。
> 功能清單見 [Bartender 6 公開功能清單](public-features.md)；平台變化見 [macOS 選單列平台變化](../concepts/macos-menu-bar-platform.md)。

## 一句話總結

Bartender 是 2012 年起由獨立開發者 Ben Surtees（Surtees Studios）做的選單列管理工具，
**幾乎每個大版本都是為了追上 macOS 選單列內部變化而重寫**。2024 年未公告就賣給紐約的 Applause Group，
憑證更換與 Amplitude 分析引發信任危機；2025 年 Bartender 6 在 Tahoe 上又因搶滑鼠、吃資源而口碑下滑，
大量使用者轉向開源的 Ice 及其 fork。2026 年 Applause 推出 Bartender Pro 訂閱與只支援 macOS 27 的 Bartender 7。

## 版本時間線

| 日期 | 事件 | macOS 背景 | 來源 |
|---|---|---|---|
| 2011 | Ben 自述開始開發 | — | 【公開】[歷史文](../../raw/articles/2026-10-12-macbartender-history-posts.md) |
| 2012-04-12 | 第一個 public beta（beta 期免費） | Lion / Mountain Lion | 同上 |
| 2012-10-23 | Bartender 1.0 | — | 同上 |
| 2015-09-28 | Bartender 2：配合 El Capitan 的 SIP 重寫內部（Bartender 1 控制系統項目需暫關 SIP） | El Capitan | 同上、[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 2017-09-15 | Bartender 3：Bartender Bar 從選單列下方改到選單列「內」（為了相容 High Sierra） | High Sierra | [歷史文](../../raw/articles/2026-10-12-macbartender-history-posts.md) |
| 2019 | Catalina 新增 Screen Recording 權限，Bartender 3 開始需要它拍選單列 | Catalina | [權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 2020-10-12 / 2021-04-19 | Bartender 4 beta / 正式版：Bartender Bar 回到下方、間距調整、Spacers、image/script triggers、熱鍵、fuzzy search | Big Sur（加大項目間距） | [歷史文](../../raw/articles/2026-10-12-macbartender-history-posts.md) |
| 2023-09-19 / 26 | Bartender 5（只支援 Sonoma，「completely redeveloped」）：groups、新 triggers、menu bar styling | Sonoma | [B5 頁與 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| 約 2024-03 | Ben 把 Bartender 賣給 Applause（Ben 在 6 月說「三個月前」） | — | [TidBITS](../../raw/articles/2026-10-12-tidbits-bartender-quiet-acquisition.md) |
| 2024-05 | 5.0.52：一次性憑證變更 + 加入 Amplitude；交接期在 5 月底結束 | — | [B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、[道歉文](../../raw/articles/2026-10-12-macbartender-lets-try-this-again.md) |
| 2024-06-04~10 | MacUpdater 警告、媒體報導、Ben 道歉（6/5 TidBITS）、Applause 道歉文（6/10）；5.0.53 移除 Amplitude | — | 同上 |
| 2024-09 | Bartender 5 for Sequoia：重建 Bartender Bar、遷移系統項目 | Sequoia（每月 screen recording 提示） | [B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md) |
| 2024（5.3.4） | Screen Recording 變成可選（失去許多功能） | — | 同上 |
| 2025-09-13 | Meet Bartender 6：ground-up rebuild、新移動系統（回移植到 B5）、在地化 | Tahoe（2025-09-15 發佈） | [Meet B6](../../raw/articles/2026-10-12-macbartender-meet-bartender-6.md) |
| 2025-09~2026-10 | 6.0.1 → 6.6.2：大量修正 Tahoe 上的滑鼠、indexing、CPU、WindowServer 問題 | Tahoe 26.x | [B6 notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md) |
| 2026-05-12 | Bartender Pro（$15/年）+ Top Shelf | — | [Pro](../../raw/articles/2026-10-12-macbartender-bartender-pro.md) |
| 2026-06-08 起 | Bartender for Golden Gate 預覽版（免費） | macOS 27 beta：選單列架構大改，所有管理工具一度失效 | [B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |
| 2026-09-14 | Bartender 7（只支援 macOS 27）：mouse-free、Screen Recording 可選、Command Bar、App Intents | macOS 27 正式版同日 | [Meet B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |
| 2026-10 | 最新 B6 = 6.6.2，B7 = 7.0.5 | — | 同上 |

規律：**Big Sur → B4、Sonoma → B5、Tahoe → B6、Golden Gate → B7**，每次都是付費大版本，且新版往往只支援最新 macOS。
這說明選單列管理工具的核心機制依賴未文件化的系統行為，Apple 一改就得重寫。【推論】

## 所有權

| 期間 | 擁有者 | 證據 |
|---|---|---|
| 2012–2024 初 | Ben Surtees / Surtees Studios（bundle id 前綴 `com.surteesstudios`，至今未改） | 【公開】[歷史文](../../raw/articles/2026-10-12-macbartender-history-posts.md)、[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 2024 起 | **Applause Group, Inc.**（自稱紐約的 indie 開發團隊；官網頁尾版權）；隱私權政策的法律實體為 **Bartender App LLC**（亦為現行簽章的 Developer ID 名稱，見 [資源檔盤點](features-from-resources.md)） | 【公開】[道歉文](../../raw/articles/2026-10-12-macbartender-lets-try-this-again.md)、[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |

- 社群留言提到 Applause 也收購了密碼管理器 Strongbox。【公開】[mjtsai](../../raw/articles/2026-10-12-mjtsai-bartender-6.md)
- 部分報導把買家和 2007 年成立的眾測公司 Applause 混為一談；官方自介是紐約 indie 團隊，兩者關係【未知】。

## 2024 信任危機

經過（依 [TidBITS](../../raw/articles/2026-10-12-tidbits-bartender-quiet-acquisition.md) 與 [Applause 道歉文](../../raw/articles/2026-10-12-macbartender-lets-try-this-again.md)）：

1. 賣出後未公告。Applause 在 Reddit 以未改名的帳號回應。
2. 5.0.52 更換簽章憑證（官方說是一次性、預期中的變更），macOS 因此不認得既有權限，跳出權限畫面。
3. 同版加入 **Amplitude** 產品分析，用來計算多少人遇到權限問題；**MacUpdater** 把 5.0.52 以後的版本標為可疑。
4. 使用者擔心的核心：Bartender 有 **Accessibility**（可操控整台 Mac）與 **Screen Recording**（可看到整個螢幕），而且**不在 sandbox 內**——未公告的易主等於把這兩個權限交給陌生人。
5. 2024-06-05 Ben 道歉；06-10 Applause 道歉；**5.0.53 移除 Amplitude**；5.0.54 在偵測到權限問題時自動在背景執行 `tccutil reset All`。
6. TidBITS 的結論：屬於公關失誤而非惡意，但信任要靠透明度補。

後續修補信任的動作：

- 5.3.4：Screen Recording 可選（犧牲功能）。【公開】[B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)
- B6：截圖只在記憶體、減少擷取次數、locked-down mode。【公開】[Meet B6](../../raw/articles/2026-10-12-macbartender-meet-bartender-6.md)
- B7：Screen Recording 完全可選，以 App icon 代替截圖。【公開】[Meet B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md)

## Bartender 6 在 Tahoe 上的口碑

官方 release notes 與 support 頁本身就承認了多數問題（【公開】[B6 notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)、[support](../../raw/articles/2026-10-12-macbartender-support-page.md)）：

| 問題 | 使用者描述 | 官方對應 |
|---|---|---|
| 搶滑鼠 | 游標被劫持、ghost clicks、移動觸控板時在拖曳項目（[9to5Mac](../../raw/articles/2026-10-12-9to5mac-decade-with-bartender.md)） | support：B6 在 Tahoe 會**定期移動滑鼠**維持排列，改 on-demand mode 可避免；6.0.3、6.2.1（只在滑鼠閒置時動作）、6.3.0（鎖定/切 Space/全螢幕時中止） |
| 無止盡 re-index、拖慢整台 Mac | TidBITS Talk、mjtsai 讀者（[社群串](../../raw/articles/2026-10-12-community-threads-bartender6.md)、[mjtsai](../../raw/articles/2026-10-12-mjtsai-bartender-6.md)） | 6.0.1、6.0.4、6.5.1 降低 indexing 頻率與資源 |
| 高耗電 / CPU / WindowServer | mjtsai 讀者、TidBITS 串 | 6.1.0、6.1.1（WindowServer CPU 爬升）、6.6.x（最低 CPU/記憶體、省電模式） |
| layout 被遺忘、重開機後要重排 | mjtsai 讀者、TidBITS 串 | support：開 item indexing |
| Menu Bar Style 在 Tahoe 無效 | TidBITS 串 | 6.0.4「Styles on Tahoe should now apply more reliably」 |
| 紫色/藍色 capture 指示器干擾 | TidBITS 串（2026-09） | B6 減少擷取；B7 可不用 Screen Recording |

2026-05 之後的評測（Six Colors、Brett Terpstra）轉為正面，認為 6.5.x 起穩定許多。【公開】[Six Colors](../../raw/articles/2026-10-12-sixcolors-top-shelf.md)、[Terpstra](../../raw/articles/2026-10-12-brettterpstra-bartender-pro-review.md)

## 價格沿革

| 時間 | 方案 | 價格 | 來源 |
|---|---|---|---|
| B5（2023） | 新購 / 升級 | $16 / $8 | 【公開】[mjtsai](../../raw/articles/2026-10-12-mjtsai-bartender-6.md) |
| B6（2025-09） | 新購 / 升級 | **$20 / $12**；2025 年買 B5 者免費 | 【公開】[mjtsai](../../raw/articles/2026-10-12-mjtsai-bartender-6.md)、[Meet B6](../../raw/articles/2026-10-12-macbartender-meet-bartender-6.md) |
| B6（2025-09） | Mega Supporter（終身）新購 / 升級 | $60 / $48 | 【公開】[MPU 串](../../raw/articles/2026-10-12-community-threads-bartender6.md) |
| 2026-05 | Bartender Pro（含 B6 + Top Shelf） | **$15/年**；B6 仍 $20 買斷 | 【公開】[Pro](../../raw/articles/2026-10-12-macbartender-bartender-pro.md) |
| 2026-09 | Bartender 7 買斷 / Pro | **$24.99 / $19.99**（Pro 為年費） | 【公開】[Meet B7](../../raw/articles/2026-10-12-macbartender-meet-bartender-7.md) |
| 2026-10 | Setapp | 會員 $14.99/月起；單買 Bartender $19.99/年 | 【公開】[Setapp](../../raw/articles/2026-10-12-setapp-bartender-listing.md) |

- 一個 license 可用於本人所有 Mac；4 週試用。【公開】[support](../../raw/articles/2026-10-12-macbartender-support-page.md)
- 趨勢：一次性價格從 $16 → $20 → $24.99，並在 2026 年加入訂閱。社群一直擔心轉訂閱（MPU 2025-09 的討論串標題就是在猜）。【公開】[MPU 串](../../raw/articles/2026-10-12-community-threads-bartender6.md)

## 為什麼使用者離開、去了哪裡

| 去處 | 理由 / 現況 | 來源 |
|---|---|---|
| **Ice**（jordanbaird，開源 GPL-3.0，免費） | 2024 收購事件後最常被推薦；「順、資源少」。但最後正式版 0.11.12（2024-10），Tahoe 只有 0.11.13-dev 預覽版，**macOS 27 完全不能用**且維護者無回應；社群稱已停止維護 | 【公開】[mjtsai](../../raw/articles/2026-10-12-mjtsai-bartender-6.md)、[Ice releases](../../raw/articles/2026-10-12-github-ice-releases.md)、[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md) |
| **Thaw**（Ice 的 fork） | 接手 Ice 的 Tahoe 支援，macOS 27 預覽版最早可用；但 macOS 27 版程式碼一度轉私有，引發授權爭議 | 【公開】[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)、[Thaw #687](../../raw/articles/2026-10-12-github-thaw-issue-687-macos27.md) |
| **Barbee** | TidBITS 串多人改用（終身約 $13） | 【公開】[社群串](../../raw/articles/2026-10-12-community-threads-bartender6.md) |
| Hidden Bar、Vanilla、BetterTouchTool | 輕量替代；9to5Mac 2024 推薦 Hidden Bar | 【公開】[TidBITS](../../raw/articles/2026-10-12-tidbits-bartender-quiet-acquisition.md)、[9to5Mac 2026](../../raw/articles/2026-10-12-9to5mac-decade-with-bartender.md) |
| 不用管理工具 | Tahoe 的 System Settings > Menu Bar 可關掉個別 App 的項目、⌘-drag 移除；有人覺得夠用 | 【公開】[社群串](../../raw/articles/2026-10-12-community-threads-bartender6.md)、[9to5Mac 2026](../../raw/articles/2026-10-12-9to5mac-decade-with-bartender.md) |
| 留在舊版 | 不升 Tahoe 就能繼續用 B5（B4 在 Sequoia 仍可用） | 【公開】[MPU 串](../../raw/articles/2026-10-12-community-threads-bartender6.md) |

各專案的技術細節由 `wiki/projects/` 各頁負責，本頁只記使用者遷移的脈絡。

注意：macOS 27 空窗期出現冒充 Ice fork 的惡意 repo（安裝腳本內含 `curl | bash`），已被檢舉下架。【公開】[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)
這類「需要高權限、使用者急著找替代品」的工具特別容易被冒充。

## 對 Whisky 的啟示

1. **信任是功能**：Accessibility + Screen Recording + 不在 sandbox，使用者會非常在意誰在維護、有沒有連網。Whisky 應該：不含任何分析 SDK、預設不連網、Screen Recording 可選、原始碼公開或至少可審計。
2. **最大痛點是「搶滑鼠」與資源消耗**，不是功能不夠。Bartender 7 與 Thaw 都把「不碰滑鼠」當賣點。
3. **每個 macOS 大版本都可能整個重寫平台層**。架構上要把「平台後端」與「設定/UI/觸發條件」分開，見 [macOS 選單列平台變化](../concepts/macos-menu-bar-platform.md)。
4. **macOS 27 是重新洗牌的時機**：Ice 已停滯、Thaw 有授權爭議、Bartender 漲價加訂閱。一個乾淨、可信、支援 14–27 的工具有空間。【推論】
5. Ice 是 GPL-3.0，Thaw 的 macOS 27 程式碼曾轉私有——參考時要特別注意授權（CLAUDE.md 乾淨室規則）。

## 未知 / 待查

- 【未知】實際成交日期與金額；Applause Group 與眾測公司 Applause 的關係。
- 【未知】Setapp 版是否包含 Bartender Pro；Setapp 版與直購版功能差異。
- 【未知】Bartender 6 正式版確切發佈日（部落格 2025-09-13，mjtsai 2025-10-06 才報導；6.0.3 推文約 2025-09-20）。
