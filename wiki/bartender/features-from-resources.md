---
title: Bartender 6 功能盤點（從 App 資源檔）
type: bartender
tags: [bartender, reverse-engineering, resources, features]
sources:
  - raw/bartender/bundle/Info.plist
  - raw/bartender/bundle/entitlements-main.plist
  - raw/bartender/bundle/xpc-Info.plist
  - raw/bartender/bundle/Bartender6.sdef
  - raw/bartender/bundle/Localizable.en.json
  - raw/bartender/bundle/Strings.en.json
  - raw/bartender/bundle/Acknowledgements.txt
  - raw/bartender/bundle/Metadata.appintents
  - raw/bartender/bundle/file-list.txt
  - raw/bartender/rea/dylibs.txt
  - raw/bartender/rea/imports-key.txt
  - raw/bartender/rea/swift-classes.txt
updated: 2026-10-12
---

# Bartender 6 功能盤點（從 App 資源檔）

分析對象：`/Applications/Setapp/Bartender.app`，**6.6.2（build 662000）Setapp 版**。
這頁只用 bundle 內的 plist、字串表、sdef、致謝清單與連結的 framework 推得，沒有看程式邏輯。
程式邏輯見 [架構](architecture.md) 與 [機制](mechanisms.md)；官網公開的功能清單見 [公開功能](public-features.md)。

## 基本身分

| 項目 | 值 | 證據 |
|---|---|---|
| Bundle ID | `com.surteesstudios.Bartender-setapp` | 【觀察】Info.plist |
| 簽章 | Developer ID「Bartender App LLC (24J875RH8J)」，hardened runtime | 【觀察】`raw/bartender/bundle/codesign.txt` |
| 最低系統 | macOS 14.0；用 macOS 26.5 SDK、Xcode 26.5 建置 | 【觀察】Info.plist |
| 架構 | Universal（x86_64 + arm64），主程式 31 MB | 【觀察】`lipo -info` |
| App 型態 | `LSUIElement = 1`（無 Dock 圖示的選單列 App）；`NSPrincipalClass = EventCatcherApplication`（自訂 NSApplication 子類別） | 【觀察】Info.plist |
| Sandbox | **沒有** App Sandbox entitlement | 【觀察】entitlements-main.plist |
| 語言 | Swift 為主，混 Objective-C（ShortcutRecorder、DDHotKey 等舊元件） | 【觀察】swift-classes.txt、Acknowledgements |

## 程序結構

- **主程式** `Bartender 6 Setapp`。
- **XPC 服務** `Bartender Service.xpc`（`com.surteesstudios.Bartender.TahoeXPC`），最低 macOS 26.0，`ServiceType = Application`、`JoinExistingSession = true`，沒有 entitlement。
  【觀察】它只匯入 5 個 Accessibility 函式，作用是對指定 pid 讀取第二個 `AXMenuBar`（選單列額外項目）的每個子項目的位置與大小，
  回傳 `MenuBarItemInfo { bundleID, appName, items[{frame, isEnabled, index}], pids, hasExtrasMenuBar }`。
  （`raw/bartender/rea/notes-xpc-service.md`，Evidence `ev_c9ba9de4…`）
  【推論】macOS 26 Tahoe 的選單列項目改由系統程序代管視窗，無法再單靠視窗擁有者判斷項目屬於哪個 App，所以 Bartender 用 AX 回報的 frame 去對應視窗；
  放到獨立程序是為了避免 AX 呼叫被無回應的 App 卡住主程式。細節待 [機制](mechanisms.md) 確認。

## 需要的權限與系統能力

| 權限 / 能力 | 用途（依 usage string 或 UI 字串） | 證據 |
|---|---|---|
| Accessibility | 移動選單列項目、讀取項目位置；字串「Bartender is unable to use Accessibility features to move menu bar items」 | 【觀察】Localizable |
| Screen Recording | Bartender Bar、Layout 設定畫面顯示項目圖片、Notch bar；「Whilst screen recording is disabled, you cannot interact with the Bartender Layout preferences」 | 【觀察】strings-main.txt、Strings |
| Apple Events（Music、Spotify） | 音樂 widget 控制播放 | 【觀察】entitlement `scripting-targets` |
| Calendars | 顯示接下來的行程（widget） | 【觀察】Info.plist |
| Location | 天氣 widget、Wi-Fi 名稱、位置觸發條件 | 【觀察】Info.plist、Localizable |
| Bluetooth | 顯示 AirPods / Beats 電量 | 【觀察】Info.plist |
| WeatherKit | 天氣 widget | 【觀察】entitlement、連結 WeatherKit.framework |
| Contacts | 回報問題時選擇 email | 【觀察】Info.plist |
| App Group | `24J875RH8J.com.surteesstudios.Bartender` | 【觀察】entitlement |

## 功能清單

### 選單列項目管理（核心）

- **三個區段**：Shown（一律顯示）、Hidden（點 Bartender 圖示才顯示）、Always Hidden（永不顯示，只在 Bartender Bar 或搜尋中出現）。
  【觀察】Strings「These items are always shown in your menu bar.」「These items are never shown.」「Always Hidden」
- **拖曳排序**：Layout 設定畫面在三個區段之間拖曳；按 **Sort My Bar** 才實際重排。
- **兩種排列模式**：**Live**（「Always organized — Whenever an item is added or removed, we'll re-order your bar」）與
  **On-Demand**（「Bartender only moves your items when you tell it to」）。On-Demand 下 Presets 不能用。【觀察】Strings
- **移動方式是模擬 ⌘ 拖曳**：「%@ menu bar item is not movable by Bartender, this is often caused by ⌘+dragging being disabled」。
  移動時會暫時擋住點擊（「Suppress Clicks during moves」），可能短暫中斷滑鼠（「Automatic mode may cause a temporary mouse interruption」）。【觀察】Localizable、Strings
- **不可移動的項目**：Clock、Control Center、Siri（macOS 本身禁止）；Now Playing 另有提示。【觀察】Localizable
- **macOS 縮放（Zoom）衝突**：開啟 Accessibility Zoom 時無法移動項目，或 ⌘⌥- 縮小後 AX 失效。【觀察】Localizable
- **App 無回應偵測**：某 App 無回應時無法顯示/隱藏它與其他項目，提供 Force Quit。【觀察】Localizable；匯入 `CGSEventIsAppUnresponsive`
- **⌘ 拖曳時顯示所有區段**、**分隔符號（❮）**顯示於 Shown 與 Hidden 之間。【觀察】Strings
- **Overflow / Unmovable Items** 區段；空間不足時改用 Bartender Bar 顯示。【觀察】Strings「The hidden section cannot be expanded as there isn't room…」

### 顯示隱藏項目

- 點 Bartender 圖示、**option-click** 顯示特定項目、hover（「Hover delay before activating」）、點選單列空白處（「Click on empty menu bar space」）。
- **自動再隱藏**（「Automatically rehide」「Delay before hiding temporarily shown menu bar items」）。
- **顯示時隱藏左側 App 選單**以騰出空間（「Hide left application menu when needed」）。此時 Bartender 必須出現 Dock 圖示（macOS 限制）。【觀察】Localizable
- **Hide Shown items to make room** 與「Hide items to the left of Bartender's menu item when showing hidden items」。
- **大螢幕顯示全部**：「Show all menu bar items when active screen is above a set size」。
- **非作用中的選單列（其他螢幕）隱藏全部項目**。【觀察】Strings

### Bartender Bar

- 在選單列下方的面板顯示隱藏項目的圖片，點擊會轉發給真實項目。「Show your hidden menu bar items in the Bartender Bar beneath the menu bar.」
- 版面選項：Leading / Trailing、Separate Pills、Bar Shape、Border、Shadow、Opacity。【觀察】Strings

### 項目群組（SubBar / Menu Bar Item Group）

- 把多個項目收進一個自訂選單列項目，點它才展開。「Adding a menu bar item group」「Click to Setup Group」。【觀察】Localizable；類別 `SubBarManager`

### Spacer（間隔）

- 拖進任一區段加入固定寬度的空白，可設寬度與標籤。【觀察】Localizable；類別 `GapManager`

### 選單列間距

- 全域調整 status item 間距（No Spacing / Tiny / Default…），需登出才生效，試用期結束後不能改。
  【觀察】Localizable；字串 `NSStatusItemSpacing`、`NSStatusItemSelectionPadding`（系統全域 defaults 鍵）

### 快速搜尋（Quick Search）

- 搜尋所有選單列項目並點擊。macOS 26 上需要先開「indexing」。「Searching items on macOS tahoe requires indexing to be enabled」。【觀察】Localizable；類別 `TahoeImageIndexer`、`IndexingHelper`、`SearchWindow`
- 鍵盤導覽（「Keyboard Navigate」）。

### 熱鍵

- 全域熱鍵：切換 Bartender、搜尋、針對單一項目「show & click it in the bar」。macOS 26 上單一項目熱鍵也需要 indexing。【觀察】Strings
- 使用的函式庫：KeyboardShortcuts（bundle 內有 `KeyboardShortcuts_KeyboardShortcuts.bundle`）、ShortcutRecorder、DDHotKey。【觀察】file-list、Acknowledgements

### 觸發條件（Triggers）

- 依條件顯示特定項目，例如：電池（「Show Battery when battery condition met」）、Wi-Fi（「Show Wi-Fi when not connected」）、位置、Time Machine 備份中、腳本、圖片比對（Show For Updates）。【觀察】Localizable
- Bartender 4 的「Show for updates」腳本會轉換成 trigger。【觀察】Localizable「SFU Converted Trigger…」
- 相關框架：IOKit 電源（`IOPS*`）、CoreWLAN、CoreLocation。【觀察】dylibs.txt、imports-key.txt

### 圖示變化偵測（Show For Updates）

- 比對項目圖片，有變化時暫時顯示該項目。「Select the menu bar items you want compare the image of」。【觀察】Localizable；類別 `MenuBarItemImageComparison`、`ImageComparisonPercentageIndicator`

### Presets（舊稱 Profiles）

- 不同版面配置（例如工作/家裡），可在啟動時套用；內建「Default macOS」preset（只顯示乾淨系統的預設項目，適合錄影截圖）。【觀察】Localizable、Strings
- **Focus Filter**：App Intents 只有一個 `BartenderFocusFilter4`「Apply a Preset or turn off Triggers」，參數 `profile`、`turnOffTriggers`。【觀察】Metadata.appintents

### 選單列外觀（Menu Bar Style）

- 選單列顏色/漸層、邊框、陰影、圓角（「Rounded corners under menu bar」）、Glass 材質（「Glass effect provides a translucent appearance」）、Hue/Saturation。
- 依桌面桌布計算外觀；桌布是資料夾輪播或檔案遺失時無法套用。【觀察】Localizable
- 可複製顏色為 SwiftUI Color / NSColor / CSS RGB / Hex。【觀察】Strings
- 類別：`MenuBarColoringManager`、`MenuBarCoverWindow`、`MenuBarRoundingManager`、`TahoeMenuBarView`、`GradientPicker`。

### Notch Bar

- 在有瀏海的螢幕用 Notch bar 取代原選單列，點瀏海切換；需要 Screen Recording。「Prevents clicked items from being hidden behind the notch by placing them after your always-shown items.」【觀察】Strings
- 資源：`NotchBar_NotchBar.bundle`（含 `default.metallib`，Metal shader）、`NotchBar_BartenderMusic.bundle`。

### Widgets（Bartender 6 新功能）

- 內建：天氣（WeatherKit，溫度、體感、濕度、UV、氣壓、降雨機率、月相、10 日預報）、行事曆、音樂（Apple Music / Spotify）、AirPods 電量、剪貼簿（Clipboard Helper、Snippets）。【觀察】Strings、Info.plist
- **自訂 widget 是節點圖（node graph）**：類別有 Script、Timer、Delay、Logic On/Off、Logic Switch、Variable、Random Number、Open URL、Open File、Perform HotKey、Menu、Music、CPU Usage、Memory Usage、Network Data、Graph、Menu Item Image 等 NodeView/NodeWorker。【觀察】swift-classes.txt
- Widget 可存成 `.BartenderWidget` 文件分享。【觀察】Info.plist `CFBundleDocumentTypes`
- 音樂資訊經 **mediaremote-adapter**（BSD-3，ungive/mediaremote-adapter）取得，內含 `mediaremote-adapter.pl` 與 `MediaRemoteAdapter.framework`。
  【推論】這是 macOS 15.4 之後一般 App 不能直接讀 MediaRemote 的繞道做法（透過系統 perl 載入 framework）。

### 自動化

- **AppleScript**（`Bartender6.sdef`）：`toggle bartender`、`quick search [with text]`、`list menu bar items`、`activate <MIID>`、`show <MIID> [and click type]`，
  click type 有 left / right / option-left / option-right click。【觀察】sdef
- 【推論】menu bar item ID 的格式是 `<bundle id>-<項目名稱>`，例如 `com.apple.controlcenter-WiFi`、`com.apple.systemuiserver-TimeMachine`。【觀察】strings-main.txt 中的系統項目 ID 清單
- URL scheme：`bartender2sendfeedback`。

### 設定與其他

- 設定可匯出成 `.BartenderPreferences` 文件（package）。【觀察】Info.plist
- 「Reset All Settings」會清除偏好並重設 Accessibility 與 Screen Recording 權限（TCC）。【觀察】Strings
- **macOS 26 特有**：「Bartender periodically pauses to avoid system lag in Tahoe」「Disable Pausing」；
  「Bartender has been disabled in macOS system settings … Toggle Bartender on in the Menu Bar settings pane」（Tahoe 的系統設定可關閉 App 的選單列項目）。【觀察】Strings
- Log viewer（`LogViewer.storyboardc`）、權限引導（`Authorization.storyboardc`）、Welcome / UpdateWelcome。
- 授權：CocoaFob（授權碼）、Setapp framework；更新：自製 `UpdateChecker`（解析 Sparkle appcast）。【觀察】Acknowledgements、swift-classes.txt

## 設定視窗分頁（nib 名稱）

General、Menu Bar Layout（Menu Bar Items）、Menu Items、Triggers、Hotkeys、Appearance、Menu Bar Appearance（Style）、Widgets、Presets（ProfilesPreferences2）、
Show For Updates（ShowForUpdatesPreferences3）、Advanced、Updates、License、About。【觀察】file-list.txt

## 第三方元件（Acknowledgements.pdf）

| 元件 | 用途 | 授權 |
|---|---|---|
| CCNPreferencesWindowController | 設定視窗 | — |
| ShortcutRecorder、DDHotKey | 熱鍵錄製與註冊 | BSD 類 |
| KeyboardShortcuts（sindresorhus） | 熱鍵（bundle 有其資源） | MIT |
| LetsMove | 提示移到 /Applications | Public domain |
| CocoaFob | 授權碼 | BSD |
| FRFeedbackReporter | 回報問題 | Apache-2.0 |
| StartAtLoginController | 登入時啟動 | MIT |
| SimplyCoreAudio | 音訊裝置 | MIT |
| MediaRemote Adapter | Now Playing 資訊 | BSD-3 |

## 連結的系統框架（重點）

ScreenCaptureKit、ApplicationServices（AX）、CoreGraphics（含私有 `CGS*`）、Carbon（熱鍵）、ServiceManagement（登入項目）、
SwiftUI、SwiftData、AppIntents、WeatherKit、MapKit、EventKit、CoreBluetooth、CoreWLAN、CoreLocation、IOKit、Vision、CoreSpotlight、ScriptingBridge。
另以 `dlopen` 載入私有 `MediaRemote.framework` 與 `DisplayServices.framework`。【觀察】dylibs.txt、strings-main.txt

【未知】Vision 與 CoreSpotlight 的用途（推測 Vision 用於圖片比對或 OCR 辨識項目，CoreSpotlight 用於搜尋索引），待確認。

## 對 Whisky 的意義

- 核心只有「隱藏 / 顯示 / 排序 / Bartender Bar / 搜尋 / 熱鍵」；Widgets、天氣、剪貼簿、Notch bar 都是附加功能，可延後。
- 必須同時處理 Accessibility 與 Screen Recording 兩種權限，並為 macOS 26 準備獨立的 AX 查詢路徑（Bartender 為此做了 XPC 服務）。
- 不使用 sandbox，因此無法上架 Mac App Store（與 Bartender 相同，走 Developer ID 公證發佈）。
