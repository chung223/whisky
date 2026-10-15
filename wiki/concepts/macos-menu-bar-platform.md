---
title: macOS 選單列平台變化（macOS 14–27）與對選單列管理工具的影響
type: concept
tags: [macos, menu-bar, nsstatusitem, screencapturekit, accessibility, tcc, sonoma, sequoia, tahoe, golden-gate, platform]
sources:
  - raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md
  - raw/articles/2026-10-12-apple-enterprise-macos-27.md
  - raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md
  - raw/articles/2026-10-12-apple-menu-bar-settings-help.md
  - raw/articles/2026-10-12-9to5mac-sequoia-screen-recording-prompts.md
  - raw/articles/2026-10-12-wikipedia-macos-tahoe.md
  - raw/articles/2026-10-12-wikipedia-macos-golden-gate.md
  - raw/articles/2026-10-12-github-ice-releases.md
  - raw/articles/2026-10-12-github-ice-issue-954-macos27.md
  - raw/articles/2026-10-12-github-thaw-issue-687-macos27.md
  - raw/articles/2026-10-12-folivora-btt-macos27-menubar.md
  - raw/articles/2026-10-12-usetuck-macos27-compat.md
  - raw/articles/2026-10-12-macbartender-bartender6-release-notes.md
  - raw/articles/2026-10-12-macbartender-bartender7-release-notes.md
  - raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md
  - raw/articles/2026-10-12-macbartender-permission-docs.md
  - raw/articles/2026-10-12-macbartender-support-page.md
  - https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes
  - https://support.apple.com/en-us/148830
  - https://developer.apple.com/documentation/appkit/nsstatusitem
  - https://github.com/jordanbaird/Ice/issues/954
  - https://github.com/thaw-app/Thaw/issues/687
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-12
---

# macOS 選單列平台變化（macOS 14–27）

選單列管理工具（Bartender、Ice、Thaw…）幾乎全部建立在**未文件化的系統行為**上，
所以每個 macOS 大版本都可能讓它們整個失效。這頁按版本整理「改了什麼、對工具有什麼影響、Whisky 要怎麼應對」。

相關頁面：[Bartender 6 公開功能清單](../bartender/public-features.md)、[Bartender 歷史](../bartender/history.md)、
[Bartender 6 功能盤點（資源檔）](../bartender/features-from-resources.md)。

**證據標記**：
**【Apple】** Apple 官方文件或 release notes ·
**【廠商】** Bartender 等廠商的官方說法 ·
**【社群】** GitHub issue、論壇中開發者的觀察（未經 Apple 證實）·
**【觀察】** 本專案對 Bartender bundle 的逆向觀察（見 `wiki/bartender/`）·
**【推論】** 由上述推得 ·
**【未知】** 尚未查證。

## 0. 背景：傳統手法依賴的系統行為

Apple **沒有**任何公開 API 可以列舉、移動或隱藏「別的 App」的選單列項目。`NSStatusBar` / `NSStatusItem` 只能管自己的項目。
因此工具們拼湊出下面這套手法（到 macOS 26 為止）：

| 需求 | 傳統做法 | 需要的權限 | 證據 |
|---|---|---|---|
| 找出所有項目 | 每個 status item 是一個獨立視窗，用 `CGWindowListCopyWindowInfo` 列舉 | 無（視窗標題等細節需 Screen Recording） | 【社群】[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)、[BTT](../../raw/articles/2026-10-12-folivora-btt-macos27-menubar.md) |
| 認出項目屬於哪個 App | 視窗 owner PID；或 AX 的 `AXExtrasMenuBar`（App 的選單列額外項目）子元素 frame 對應 | Accessibility | 【社群】[Thaw #687](../../raw/articles/2026-10-12-github-thaw-issue-687-macos27.md)；【推論】[資源檔盤點](../bartender/features-from-resources.md) 的 XPC 服務 |
| 取得項目圖片（Bartender Bar、設定畫面、搜尋） | 對項目視窗截圖：舊 `CGWindowListCreateImage`，新 ScreenCaptureKit | Screen Recording | 【廠商】[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 移動 / 重排 | 模擬使用者 **⌘-drag**（合成滑鼠事件） | Accessibility | 【廠商】Bartender：App 擋 ⌘+drag（覆寫 `sendEvent:`）就無法被移動，[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md) |
| 隱藏 | 放一個自己的分隔 status item，把它撐到很寬，把左邊的項目推出螢幕 | — | 【社群】[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)（"shove them off screen"） |
| 開啟隱藏項目 | 暫時移回可見處再點，或對 AX 子元素送 `AXPress` | Accessibility | 【社群】[Thaw #687](../../raw/articles/2026-10-12-github-thaw-issue-687-macos27.md) |
| 調整項目間距 | 寫全域 defaults `NSStatusItemSpacing` / `NSStatusItemSelectionPadding`，各 App 重新啟動（或登出）才生效 | — | 【推論】[資源檔盤點](../bartender/features-from-resources.md)；【社群】[Ice releases](../../raw/articles/2026-10-12-github-ice-releases.md)；【廠商】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md) |

## 1. 版本總覽

| macOS | 發佈 | 對選單列工具最重要的變化 | 衝擊程度 |
|---|---|---|---|
| 14 Sonoma | 2023-09 | `CGWindowListCreateImage` deprecated、ScreenCaptureKit 截圖 API、紫色 screen capture 指示器；Bartender 4 不支援，B5 重寫 | 中（需重寫擷取） |
| 15 Sequoia | 2024-09 | **Screen Recording 每月重新確認**；`CGWindowListCreateImage` 在 15 SDK **obsoleted**；用舊擷取 API 會跳警示 | 中（權限體驗變差） |
| 26 Tahoe | 2025-09-15 | 透明選單列、System Settings 新 **Menu Bar** 頁（per-app「Allow in the Menu Bar」）、第三方 Control Center controls、Live Activities 進選單列；項目改由 Control Center 代管（身分辨識變難）；移動變慢易失敗 | 高（Bartender 6、Ice 大量問題） |
| 27 Golden Gate | 2026-09-14 | 選單列改成**單一視窗**＋系統 **MenuBarAgent**；**內建 overflow**；同一 App 的項目**一起**隱藏/顯示；不支援的 status item 被過濾；**只支援 Apple silicon** | 極高（所有工具在 beta 1 全部失效） |

## 2. macOS 14 Sonoma（2023）

- **擷取 API**：`CGWindowListCreateImage` 於 14 deprecated，建議改用 ScreenCaptureKit；`SCScreenshotManager` 自 14.0 起提供單張截圖。【Apple】[API 文件](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)
- **紫色指示器**：Bartender 2023-09 發文說明每次擷取項目圖片 macOS 都會顯示紫色 screen capture 項目約 20 秒，無法隱藏。【廠商】[權限頁](../../raw/articles/2026-10-12-macbartender-permission-docs.md)
- **Bartender 5「completely redeveloped for macOS Sonoma」**，Bartender 4 不建議用於 Sonoma；B5 FAQ 說「因 macOS 內部變更」只能支援最新版。B5 release notes 另提「Sonoma 處理被移除選單列項目的方式改變」。【廠商】[B5 notes](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)
  【推論】主因是擷取 API 換代（社群轉述 Ben 曾說 Sonoma deprecated 的 API 之替代品當時缺功能）；確切的內部變更【未知】。
- **App activation**：`activate(ignoringOtherApps:)` deprecated，activation 變成「請求」不保證成功；選單列 App 開設定視窗時要用新的 `activate()` / `yield(to:)`。【Apple】[AppKit 14 notes](../../raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md)
- 14.4：`com.apple.developer.persistent-content-capture` entitlement（只給 VNC 類 App、需申請）。【Apple】[API 文件](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)

## 3. macOS 15 Sequoia（2024）

- **Screen Recording 週期性重新確認**：早期 beta 每週 + 每次重開機；15.0 beta 6 起改為**每月**（「Allow For One Month」）、不再每次重開機問。9to5Mac 點名 Bartender 受影響。【社群/媒體】[9to5Mac](../../raw/articles/2026-10-12-9to5mac-sequoia-screen-recording-prompts.md)
- 15.0 release notes：用 `CGDisplayStream`、`CGWindowListCreateImage` 等 deprecated 擷取 API 可能觸發系統警示，應改 ScreenCaptureKit / `SCContentSharingPicker`。【Apple】[release notes](../../raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md)
- 15.1：已接受風險、常用的 App 對話框變少；MDM key `forceBypassScreenCaptureAlert`。【Apple】同上
- **`CGWindowListCreateImage` 在 macOS 15 SDK 標為 obsoleted**：用 Xcode 16+ 編譯直接報錯「unavailable: obsoleted in macOS 15.0」。【社群】WebKit bug 277564，見 [API 文件摘要](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)
  【推論】要用它只能以較舊 SDK 建置或執行期動態查找符號；Whisky 應直接用 ScreenCaptureKit。
- `SCScreenshotManager.captureImage(in:)`（以螢幕座標矩形截圖）15.2 起可用。【Apple】
- 工具端的對應：Bartender 5 為 Sequoia 重建 Bartender Bar（效能）、手動遷移未正確轉移的系統項目（如 Time Machine）、配合動態桌布調整刷新頻率；Ice 0.11.3 修 Sequoia 的 screen capture 權限問題。【廠商】[B5](../../raw/articles/2026-10-12-macbartender-bartender5-and-earlier.md)、【社群】[Ice releases](../../raw/articles/2026-10-12-github-ice-releases.md)

## 4. macOS 26 Tahoe（2025-09-15）

### 使用者可見的變化
- **透明選單列**（預設），System Settings > Menu Bar > **Show menu bar background** 可恢復背景。【Apple】[Menu Bar 設定說明](../../raw/articles/2026-10-12-apple-menu-bar-settings-help.md)、[Wikipedia](../../raw/articles/2026-10-12-wikipedia-macos-tahoe.md)
  → 自訂選單列外觀（tint、形狀）的工具要處理兩種背景；Ice 的已知問題是透明模式下亮度不一致。【社群】[Ice releases](../../raw/articles/2026-10-12-github-ice-releases.md)
- **新的 Menu Bar 設定頁**：Menu Bar Controls（系統項目）與 **Allow in the Menu Bar**（逐一允許第三方 App 顯示項目）。【Apple】[Menu Bar 設定說明](../../raw/articles/2026-10-12-apple-menu-bar-settings-help.md)
  → 使用者可以在系統層級關掉某 App 的項目；Bartender 6 有字串提示「Bartender has been disabled in macOS system settings」。【觀察】[資源檔盤點](../bartender/features-from-resources.md)
- **第三方 Control Center controls**：`ControlWidget` 從 macOS 26.0 開放；controls 可拖進選單列。既有選單列項目不能直接轉成 control。【Apple】[API 文件](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)、[9to5Mac](../../raw/articles/2026-10-12-apple-menu-bar-settings-help.md)
- **Live Activities**（來自 iPhone）出現在 Mac；Bartender 6.3.0 才「works around Live Activities」，期間移動變慢。【Apple】[Wikipedia](../../raw/articles/2026-10-12-wikipedia-macos-tahoe.md)、【廠商】[B6 notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)
- macOS 26 是**最後支援 Intel** 的版本。【Apple/Wikipedia】[Wikipedia](../../raw/articles/2026-10-12-wikipedia-macos-tahoe.md)

### 對管理工具的內部衝擊
- Ice：「Apple made significant changes to the menu bar that require new solutions」；Tahoe beta 1 上移動項目變慢、間歇失敗，`killall ControlCenter` 可暫解；搜尋與 hover 顯示**錯誤的名稱與 App icon**；第三方項目的間距要**登出**才生效。【社群】[Ice releases](../../raw/articles/2026-10-12-github-ice-releases.md)
- 項目視窗改由系統代管：Thaw 維護者說 macOS 26 上 Little Snitch 常以「Control Center 代管的項目」出現、沒有穩定的 source PID。【社群】[Thaw #687](../../raw/articles/2026-10-12-github-thaw-issue-687-macos27.md)
  Bartender 6 為此新增一個 macOS 26 專用的 XPC 服務，用 AX 讀各 App `AXExtrasMenuBar` 子元素的 frame 來對應項目。【推論】[資源檔盤點](../bartender/features-from-resources.md)
  → **視窗 owner PID 不再可靠，項目身分要靠 AX + bundle ID + 標題/順序。**
- Bartender 6 在 Tahoe：「larger workload required to manage the bar on Tahoe」；6.1.1 為 Tahoe 系統 bug（越跑越嚴重）與 **WindowServer CPU 爬升**做 workaround；live mode 會**定期移動使用者的滑鼠**維持排列；Quick Search 與單項目熱鍵在 Tahoe 上需要先開 indexing。【廠商】[B6 notes](../../raw/articles/2026-10-12-macbartender-bartender6-release-notes.md)、[support](../../raw/articles/2026-10-12-macbartender-support-page.md)；【觀察】[資源檔盤點](../bartender/features-from-resources.md)
- 新 API：`SCScreenshotManager.captureScreenshot(rect:configuration:)` 26.0 起。【Apple】[API 文件](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)
- 開發者 release notes 對 NSStatusItem **沒有任何條目**——這些變化都沒有被文件化。【Apple】[release notes](../../raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md)

## 5. macOS 27 Golden Gate（2026-06-08 發表，2026-09-14 發佈）

### Apple 官方明文
- **內建 overflow**：空間不夠時選單列自動把項目藏起，以精簡的 overflow indicator 取代，按下顯示被藏的項目。使用者無法選擇藏哪些。【Apple】[企業版 notes](../../raw/articles/2026-10-12-apple-enterprise-macos-27.md)
- **NSStatusItem 新 API（27.0）**：`expandedInterfaceDelegate`、`expandedInterfaceSession`、`NSStatusItemExpandedInterfaceDelegate`（`statusItem(_:didBegin:)`、`statusItemDidEndExpandedInterfaceSession(_:animated:)`）。有 `NSMenu` 的項目由系統自動處理；沒有 menu 的項目要在 didBegin 時自己顯示展開介面（例如項目下方的視窗）。【Apple】[API 文件](../../raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md)
  【推論】系統現在掌控項目「何時被展開」（含從 overflow 中展開），這是 Whisky 自己的 status item 應該採用的介面。
- `NSStatusItem.isVisible` 在項目因空間不足被暫時隱藏時**仍回傳 true**（文件既有說明），App 無法自知被擠掉。【Apple】同上
- 選單項目圖片預設隱藏（`NSMenuItem.preferredImageVisibility`）。【Apple】[release notes](../../raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md)
- **Automatic Assessment Configuration** 新增 Dock、**Menu Bar**、accessibility 設定的控制。【Apple】同上
- **App 不能再直接讀本機 TCC 資料庫**；企業版新增 `tccutil list`。【Apple】同上、[企業版 notes](../../raw/articles/2026-10-12-apple-enterprise-macos-27.md)
- **只支援 Apple silicon**。【Wikipedia】[Golden Gate](../../raw/articles/2026-10-12-wikipedia-macos-golden-gate.md)

### 廠商（Bartender 7 release notes）描述的行為
【廠商】[B7 notes](../../raw/articles/2026-10-12-macbartender-bartender7-release-notes.md)
- **同一 App 的多個項目：可分別排序，但隱藏/顯示一個就全部一起**；一個 App 只能屬於一個區段。
- **使用者在 Control Center / Menu Bar 設定中隱藏的項目，管理工具無法顯示或隱藏**（B7 另列為「Disabled Items」）。
- 部分系統項目（尤其 Control Center widgets 類）可移不可藏；clock、Control Center 可被隱藏但不能在顯示區內移動，且隱藏某些系統項目會讓音量等系統 UI 失效。
- 有些 App（iStat Menus、Setapp）在別的項目被隱藏時會把自己也藏起來；B7 說 App 端做「Golden Gate updates」很快就能修。
- native overflow 在重排時會閃爍；建議把放不下的項目自動移進 Hidden。
- 間距（Default/Small/Tiny/No Spacing）要**登出再登入**才會被所有 App 套用。
- 新版不再動滑鼠移動項目；可完全不用 Screen Recording（以 App icon 代替）。
- beta 期間移動多次後選單列可能停止回應（提供「Restart Menu Bar」）；7.0.4 仍有「選單列卡住」的自動 refresh。
- Shortcuts 的項目被標為「Control Center」。

### 社群技術觀察
【社群】[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)、[Thaw #687](../../raw/articles/2026-10-12-github-thaw-issue-687-macos27.md)、[BTT 論壇](../../raw/articles/2026-10-12-folivora-btt-macos27-menubar.md)
- 整條選單列由**一個視窗**繪製，不再是一個項目一個視窗 → `CGWindowList` 列舉失效。BTT 開發者與多位開發者獨立證實。
- 新系統程序 **`MenuBarAgent`**；log 中出現「Filtering out unsupported status item: com.jordanbaird.Ice」→ 有白名單/過濾機制，**撐寬 spacer 的隱藏法失效**（寬度達螢幕一半的項目直接被丟棄而不是推出畫面）。
- 可行的新做法（皆未文件化）：
  - Thaw：改用「**preferred-position writes**」取代合成拖曳，不再碰游標；隱藏是 **per bundle**。
    - 【矛盾】[Pelmet](../projects/pelmet.md)（開源，GPL-3.0）實測 MenuBarAgent 的順序表（`com.apple.MenuBarAgent` 的 `TrailingItemPreferredPositions`）
      對 live item 無效：寫入＋重啟 agent 也不會換位置，只影響新註冊 item 的落點；只有 HID 層的真實 ⌘-drag 會重排
      （`raw/github/repos/fif7y__pelmet/docs/CORE-SETS.md:13-16`, `:23`）。Thaw 的實際作法閉源，兩者如何並存【未知】。
  - brentc22：用私有的 assessment mode allowlist（`MBAssessmentModeConfiguration`，dlopen）決定哪些 bundle 可顯示。
  - BTT：「Load Menu Bar Layout」action，開發者自承非官方、可能被封。
- 有些 App 需要發出 `AXExtrasMenuBar` 才能被選單列/工具看見；從工具的 bar 開啟項目需要可 `AXPress` 的 AX 子元素。
- 系統 overflow 的 chevron 本身看起來像一個 status item，需排除；它也會「污染」截圖。
- macOS 27 上 Screen Recording 權限的行為與 26 不同（Bartender 6 與 Ice 都受影響），細節【未知】。
- 空窗期出現冒充 Ice fork 的惡意 repo。
- 【社群】[Pelmet](../projects/pelmet.md) 的原始碼與文件（路徑相對於 `raw/github/repos/fif7y__pelmet/`）記錄的 27 行為：
  - assessment allow-list 也能藏**系統 icon**，包括 Control Center 與 Clock（可藏不可移）（`Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:42-91`）。
  - 任何 assertion 生效時，系統會順便拿掉 Now Playing、相機／麥克風膠囊、AirDrop、Focus、Timer、快速使用者切換、Live Activities，點 clock 或按 ⌥A
    也打不開通知中心（`docs/FAQ.md:13-32`）。
  - 新註冊的 status item 在 assertion 生效時被 park 在螢幕外、不進 AX tree，要短暫解除 assertion 才會被收下
    （`Packages/PelmetEngine/Sources/PelmetEngine/AgentBarEngine.swift:237-277`）。
  - /Applications 以外、MenuBarAgent 解析不到 host 的 app，item 被當成違規直接銷毀（log `Host or location not found for disallowing status item: nil`，
    `Pelmet/App/CollateralTracker.swift:5-13`）。
  - 系統 `«` 是 MenuBarAgent 擁有、不在任何 AX 階層裡的 `AXButton`，只吃真實 HID 點擊（`Pelmet/App/OverflowToggle.swift:1-11`）。

### 結果
- macOS 27 beta 1 當天，Bartender、Ice、Thaw、Hidden Bar、Barbee、Sane Bar、Glow 全部失效。Bartender 以全新 Bartender 7 因應（7.0.0 與 27.0 同日）；Thaw 以重寫的預覽版因應；**Ice 至今不能用**。【社群】[Tuck 彙整](../../raw/articles/2026-10-12-usetuck-macos27-compat.md)、[Ice #954](../../raw/articles/2026-10-12-github-ice-issue-954-macos27.md)

## 6. 相關 API 現況

| API | 可用性 | Whisky 用途 | 備註 |
|---|---|---|---|
| `NSStatusBar.system` / `NSStatusItem` | 全版本 | 自己的圖示、分隔用 control item | 只能管自己的項目；`autosaveName` 持久化位置與可見性；27 新增 expanded interface API |
| SwiftUI `MenuBarExtra` | 13.0+ | 自己的選單或面板 | 無法控制 length，做 control item 仍需 AppKit【推論】 |
| `ControlWidget` | 26.0+ | 可選：提供「切換隱藏」的 Control Center control | 【Apple】 |
| `CGWindowListCopyWindowInfo` | 未 deprecated | ≤26：列舉項目視窗 | 27 看不到個別項目【社群】 |
| `CGWindowListCreateImage` | 14 deprecated；15 SDK obsoleted | 不用 | 【Apple】【社群】 |
| ScreenCaptureKit（`SCShareableContent`、`SCScreenshotManager`） | 12.3 / 14.0；`captureImage(in:)` 15.2；`captureScreenshot(rect:)` 26.0 | 項目圖片（可選功能） | 需 Screen Recording；15 起每月確認 |
| `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess` | 10.15+ | 檢查權限 | 27 不能讀 TCC.db，只能用這類 API【Apple】 |
| Accessibility（`AXIsProcessTrusted`、`AXUIElement`、`AXExtrasMenuBar`、`AXPress`） | 全版本 | 辨識項目、開啟項目、≤26 移動 | 核心權限；AX 呼叫可能被無回應 App 卡住 → 放獨立程序【推論】 |
| `CGEvent` 合成 ⌘-drag | 全版本（需 Accessibility） | ≤26 移動項目 | 會搶滑鼠；27 上已不需要【廠商】【社群】 |
| 私有 CGS/SkyLight、MenuBarAgent 相關 | 未文件化 | 視需要 | 隨時可能壞；不能上 App Store |
| Automatic Assessment Configuration | 公開框架；27 起有 Menu Bar 控制 | 【未知】能否用於非考試 App | 【推論】需特殊 entitlement |
| Persistent Content Capture entitlement | 14.4+ | 不適用 | 只給 VNC 類 App |

註（2026-10-12，Pelmet ingest）：上表「`CGEvent` 合成 ⌘-drag … 27 上已不需要」是廠商與社群對閉源產品（Bartender 7、Thaw 3）的描述；**公開原始碼的 27
管理工具仍然用 HID 層的真實 ⌘-drag 移動**（[Frost](../projects/frost.md) `directOnTarget`、[Pelmet](../projects/pelmet.md) `ItemMover`），Pelmet 實測送給 pid 或
session 層級的事件不會重排（`raw/github/repos/fif7y__pelmet/docs/CORE-SETS.md:15`）。「不碰游標的移動」目前只能當【未知】。

## 7. Whisky 在 macOS 14–27 必須處理的事

1. **兩套平台後端**：`LegacyWindowBackend`（14–26：視窗列舉 + 合成拖曳 + 撐寬分隔項目）與 `MenuBarAgentBackend`（27+：單一視窗、系統 overflow、per-bundle 可見性）。設定、觸發條件、UI 共用，平台層用 protocol 隔開。【推論】
   - 若決定只支援 26/27 以上，可大幅縮小範圍；Thaw 新版已只支援 26+。
2. **Screen Recording 必須可選**：預設用 App icon 代替截圖（B7、Thaw 都這樣做）；開啟時只擷取選單列區域、能少則少、說明紫色指示器與 Sequoia 每月確認。只用 ScreenCaptureKit。【廠商】【Apple】
3. **Accessibility 是唯一必要權限**：用 AX 辨識（bundle ID + 標題 + 同 App 內序號，不用 window ID 或 owner PID）、用 `AXPress` 開啟。AX 查詢放到獨立 XPC/執行緒，避免被無回應 App 卡死。【推論】
4. **不要搶滑鼠**：≤26 不得不合成拖曳時，只在使用者閒置時做、鎖定/切 Space/全螢幕時中止、移動中暫時擋點擊、失敗重試要有上限（Thaw 曾因重試不可能的移動造成游標 thrash）。27 起改用不碰游標的方式。【廠商】【社群】
5. **尊重系統設定**：被 System Settings「Allow in the Menu Bar」關掉的 App 不能管理，要偵測並在 UI 中標成「Disabled」；clock、Control Center 等系統項目是固定錨點。【Apple】【廠商】
6. **macOS 27 的資料模型**：可見性以 **App（bundle）為單位**，排序才以項目為單位；同 App 的項目必須同一區段。整個設定模型要能表達這個限制（在 ≤26 上可以放寬）。【廠商】
7. **與系統 overflow 共存**：27 上把放不下的項目主動移進 Hidden，避免 overflow 閃爍；把系統的 overflow chevron 排除在項目清單外。【廠商】【社群】
8. **瀏海**：≤26 自行偵測（`NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea`【推論】）並把超出的項目移到隱藏區；27 交給系統 overflow + 自己的 bar。
9. **間距**：寫 `NSStatusItemSpacing` 類全域 defaults 後需提示使用者登出或重啟 App；不要假裝能即時生效。【推論】【廠商】
10. **外觀**：處理 Tahoe 的透明選單列與「Show menu bar background」兩種狀態；styling 是可延後的功能。【Apple】
11. **自己的 status item**：用 `autosaveName`，採用 27 的 expanded interface API，假設自己隨時可能被系統 overflow 或使用者在系統設定關掉（`isVisible` 不可信）。【Apple】
12. **權限檢查**：只用 `AXIsProcessTrusted`、`CGPreflightScreenCaptureAccess` 等 API；27 起不能讀 TCC.db。【Apple】
13. **建置與發佈**：無法 sandbox、可能用私有 API → Developer ID + notarization，不上 App Store；27 只需 arm64，14–26 若要支援 Intel 需 Universal。【推論】
14. **Live Activities、Control Center controls 與系統項目**：都會出現在選單列，但不一定能移動或隱藏；要能「跳過並標示」而不是一直重試。【廠商】【社群】

## 8. 未知 / 待查

- 【未知】macOS 27 上「preferred-position writes」的確切機制（推測是寫各 App 的 `NSStatusItem Preferred Position` defaults），以及隱藏究竟靠什麼（MenuBarAgent XPC？assessment allowlist？）。可查 Thaw 3（部分私有）、Pelmet、brentc22/stash，並對 Bartender 7 做 RE。
- 【未知】Automatic Assessment Configuration 的 Menu Bar 控制能否被非考試 App 合法使用。
- 【未知】macOS 27 的 Screen Recording 行為改了什麼（社群只說「不一樣了」）。
- 【未知】Sonoma 讓 Bartender 4 失效的確切內部變更。
- 【未知】macOS 26 上 status item 視窗的擁有者是否全部變成 Control Center（社群說法不一，需實測 `CGWindowListCopyWindowInfo`）。
- 【未知】Apple 是否會在 27.x 公開「第三方選單列管理」API；目前只有內建 overflow 與系統設定的 per-app 開關。
- （2026-10-12 補）第一條的部分答案：隱藏靠 assessment allowlist（見 [menubar-agent-allow-list](menubar-agent-allow-list.md)，[Pelmet](../projects/pelmet.md) 已 clone 確認）；
  27 的位置表是 `com.apple.MenuBarAgent` 的 `TrailingItemPreferredPositions`，不是各 App 的 `NSStatusItem Preferred Position`，且 Pelmet 實測它對 live item 無效
  （見 §5 的【矛盾】）。Thaw 的「preferred-position writes」具體怎麼生效仍【未知】。
- （2026-10-12 補）§7 第 9 點的補充：Pelmet 寫完 `NSStatusItemSpacing`／`NSStatusItemSelectionPadding`（current host）後對 MenuBarAgent 送 `SIGTERM`，
  Clock、Control Center 等系統 icon 立即套用（agent 約 1 s 內重生）；第三方 App 仍要重開或登出（`raw/github/repos/fif7y__pelmet/Pelmet/App/IconSpacingApplier.swift:25-49`）。
