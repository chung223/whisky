---
title: Frost
type: project
tags: [open-source, swift, appkit, mit, menu-bar-manager, macos-26, macos-27, accessibility]
sources:
  - raw/github/repos/frostbar__frost
  - https://github.com/frostbar/frost
updated: 2026-10-12
---

# Frost

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [frostbar/frost](https://github.com/frostbar/frost) |
| 授權 | **MIT** |
| 語言 | Swift 6（strict concurrency），App + 本地 SPM package `FrostCore` |
| Stars | 約 27（2026-10-01 建立） |
| 活躍度 | 極活躍：v0.4.1（2026-10-10），一週內多個 release |
| 支援的 macOS | 只支援 26 與 27（`Packages/FrostCore/Sources/FrostCore/Model/PlatformSupport.swift:30-45`）；28+ 只顯示「不支援」 |
| macOS 26 | `.windowList` backend |
| macOS 27 | `.accessibility` backend（不用任何 MenuBarAgent 私有 API） |

Frost 是 Hidden／Always Hidden／Visible 三區段的選單列管理工具，有 Frost Bar（瀏海機下拉玻璃面板）與 Layout 編輯器，
UI 用 Liquid Glass。對 Whisky 最有價值的不是功能，而是它的 **`docs/macos-behavior.md`（649 行）**：作者在 VM 裡逐項實測
macOS 26 與 27 的選單列行為，並寫下每個結論對程式碼的影響。

本頁 file:line 相對於 `raw/github/repos/frostbar__frost/`（commit `e6d9fd2`）。`FrostCore` 路徑縮寫為
`FC/` = `Packages/FrostCore/Sources/FrostCore/`。

## 架構

- `AppModel`（`Frost/App/AppModel.swift:74-114`）組裝一切；backend 只在啟動時依 OS major version 選一次
  （`FC/Model/PlatformSupport.swift:37-45`）。
- `FrostCore`：
  - Scanning：`MenuBarItemScanner`、`AXExtrasReader`、`AXMenuBarInventory`、`StatusWindowParser`、`AXItemMatcher`、`MenuBarDisplayResolver`
  - Moving：`ItemMover`、`ItemClicker`、`DragRelease`、`LandingDetector`、`CursorConcealment`、`RestorePlan`
  - Capture：`ItemImageCapturer`、`StripGlyphExtraction`、磁碟快取
  - Layout：`SectionAssigner`、`ArrangedLayout`、`BoundedDivider`、`ItemMemoryStore`
- App 層：`SectionController`（status item 狀態機）、`FrostBarController`（+Forwarding、+LiveRefresh、+ObscuredCapture）、
  `MenuBarFreezeFrame`、`FrostBarPanel`。
- 依賴：Sparkle 2.10.0（exact pin）；`FrostCore` 無外部依賴。
- `Spikes/MenuBarSpike/main.swift`：8 步驟實驗程式（只碰自己的 item，有 180 s watchdog），結果寫在 `docs/macos-behavior.md`。

## 關鍵機制（附 file:line）

### 隱藏

**macOS 26**：分隔線 `length = 10_000`（`Frost/Sections/SectionController.swift:1288`），系統夾到 5,016 pt 的 window，把左邊
全部推出螢幕（`docs/macos-behavior.md:86-89`）。四種狀態 collapsed／expanded／expandedAll／editing（`:789-806`）。長度 0 仍佔
16 pt，所以沿用「Ice 的 trick」停用 button superview constraint 再把 content size 設 1（`:1380-1391`），並在每秒 resize 超過
10 次時放棄（`:1400-1416`）。只在缺值時寫入 preferred position 種子：`FrostIcon=0`、`FrostHiddenSeparator=1`、
`FrostAlwaysHiddenSeparator=10000`（`:109-131`）。

**macOS 27：有界寬度的分隔線對（public API）**——這是和 [Hidden Bar](hidden-bar.md)／[MenuBarHider](menubarhider.md)
完全不同的路線：

- 實測：分隔線約 450 pt 以內會照舊把 item 往左推；從約 500 pt 起（或達到半個螢幕寬）**整個 item 被丟出選單列**，縮回來
  時位置會亂掉（`docs/macos-behavior.md:567-575`）。
- 因此 `BoundedDivider.collapseWidth = min(600, displayWidth/2 − 32)`，小於 200 pt 就不用（`FC/Layout/BoundedDivider.swift:1-40`）。
  原理：trailing area 靠右對齊，自己的寬 item 吃掉空間，放不下的別人 item 就被擠出選單列（系統可能提供 `«` overflow）。
- 每個邊界用一對 item（`<name>` + `<name>.Pair`），autosave 名稱 `Frost27.HiddenDivider`／`Frost27.AlwaysHiddenDivider`，
  不繼承 26 的位置（`SectionController.swift:92-93`, `:1323-1326`）。
- 27 上新 item 會落在 trailing area 的**第一個空位**，與 26 相反，所以建立順序反過來（`:134-143`）。
- 【重要】27 上**無法得知哪些 icon 真的被畫出來**：被擠出去的 icon 仍回報舊 frame，`NSStatusItem.occlusionState` 也不再可靠
  （FB23349447）。所以 section 一律以「使用者安排的順序」為準，而不是幾何判斷（`docs/macos-behavior.md` 表格「Which icons the
  bar draws」；`Frost/App/AppModel.swift:127-138`）。

### 列舉

- **26**：`CGWindowListCopyWindowInfo([.optionAll])` 取 layer 25 的 window（`FC/Scanning/StatusWindowParser.swift:20-44`）。擁有者
  一律是 Control Center，所以從各 app 的 `kAXExtrasMenuBarAttribute` children 用 midX ±4 pt 配對，且要求 AX 讀取前後兩次
  window 快照一致（`FC/Scanning/AXItemMatcher.swift:33-66`；`AXExtrasReader.swift:40-71`；`MenuBarItemScanner.swift:285-313`）。
  多螢幕時區分真 window 與 replica（`MenuBarItemScanner.swift:350-377`）。每 3 秒重掃（`:81`, `:118-129`）。
- **27**：CGWindowList 和 ScreenCaptureKit 都看不到任何 per-item window，只剩 AX（`FC/Scanning/AXMenuBarInventory.swift:47-73`）。
  每個 item 用 FNV-1a（bundleID + identity key + pid）合成一個假的 window ID，讓上層程式不用改（`:91-111`）。時鐘、Control
  Center 按鈕、overflow 箭頭屬於 MenuBarAgent（`FC/Model/SystemItemRules.swift:18-46`）。
- 唯一用到的私有 API：`CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground", true)` 隱藏游標
  （`FC/Moving/CursorConcealment.swift:4-31`）。

### 移動

- **26（`windowIDRouting`）**：mouse-down 放在 **Frost 自己的 icon 中心**，每個事件設 `CGEventField(rawValue: 0x33)` = 目標
  window ID 並帶 `.maskCommand`，source `.hidSystemState`，送進 `.cgSessionEventTap`，不送 drag 事件
  （`FC/Moving/ItemMover.swift:223`, `:681-683`, `:769-775`）。每 10 ms 輪詢直到看到 item 被「拎起」，再在目標 frame 邊緣送
  mouse-up（`:613-618`, `:787-803`）。驗證：CGWindowList 依 minX 排序，3 次相同快照才算穩定（`:567-575`, `:661-677`）。
- **27（`directOnTarget`）**：`0x33` 路由完全無效；只有「從 item 本身開始的真正 ⌘-drag」才會動：⌘ mouseMoved + mouseDown 在
  item 中心 → 80 ms → +2 pt 拎起 → 20 個內插 `leftMouseDragged`（間隔 10 ms）→ 120 ms → mouseUp（`ItemMover.swift:466-509`）。
  事先把所有 section 展開、用 `AXUIElementCopyElementAtPosition` 確認該點真的是目標元素（`AXExtrasReader.swift:118-132`），
  事後重讀 AX 順序最多 10 次驗證（`ItemMover.swift:379-390`）。

### Frost Bar（擷取與點擊）

- **26 擷取**：`SCScreenshotManager.captureImage` + `SCContentFilter(display:including:)`，背景透明（`FC/Capture/ItemImageCapturer.swift:532-560`）。
  螢幕外 item 會失敗（SCK `-3811`），所以先拍一張選單列的「freeze frame」蓋在 level 26 的 click-through window 上，底下偷偷展開、
  擷取、再收合（`Frost/FrostBar/MenuBarFreezeFrame.swift:54`, `:110-128`）。
- **瀏海後的 item（26）**：使用者閒置時一次一個，把 item 移到 Frost icon 右邊、蓋 level 501 的全選單列 freeze frame、擷取、
  移回原位，並先持久化「歸還計畫」以防 crash（`Frost/FrostBar/FrostBarController+ObscuredCapture.swift:136-275`；
  policy：啟動後 20 s、間隔 2 s、需 1 s 無輸入，`ObscuredCapturePolicy.swift:26-44`）。
- **27 擷取**：MenuBarAgent 的 window 不可分享，只能擷取整個 display 的選單列條帶，再對每個 item 的範圍做「逐欄背景減法」
  把 glyph 摳出來（`ItemImageCapturer.swift:470-516`；`StripGlyphExtraction.swift:20-26`）。
- **26 點擊**：先把 item 移到 Frost icon 右邊，再 `AXPress`（0.25 s timeout）；`com.apple.*` 與自己跳過 AXPress，改送 HID
  事件（先送一個孤立 mouse-up 清掉卡住的按下狀態，再 down/up，`clickState=1`、`0x33`）（`FC/Moving/ItemClicker.swift:92-113`, `:452-487`）。
  用 `NSApp.yieldActivation(to:)` 把前景交給目標 app（`ActivationHandOff.swift:79`）。
- **27 點擊**：暫時把 item 拖到 snowflake 旁邊、點擊、等 menu 關閉與游標離開約 0.75 s、再拖回原位（`Frost/FrostBar/FrostBarController+Forwarding.swift:110-154`, `:501-541`）。
  只支援左鍵。

### 瀏海、多螢幕、其他

- 瀏海：`NSScreen.safeAreaInsets.top > 0`（`Frost/Support/Preferences.swift:73-77`）；Automatic 模式在有瀏海的螢幕用 Frost Bar。
- 選單列高度用 `frame.maxY − visibleFrame.maxY`，不用 `NSStatusBar.thickness`（`MenuBarItemScanner.swift:381-386`）。
- 26 多螢幕：作用中的選單列 = 擁有 icon 真 window 的那個螢幕；其他螢幕上的是 replica，點 replica 會遺失點擊，所以有
  `ReplicaClickDetector` 重播（`SectionController.swift:146-167`, `:1197-1270`）。27 只有一條合成的 bar，沒有 replica。
- 自動 rehide 預設 15 s，menu 開著或游標在選單列時延後（`Preferences.swift:52-53`；`SectionController.swift:928-970`）。
- 沒有 hotkey、hover、scroll、外觀、搜尋（README）。

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| Accessibility | Frost Bar 與 Layout 需要 | 擁有者、身分、移動、點擊；授權即時生效靠 distributed notification `com.apple.accessibility.api`（`FC/Permissions/PermissionsService.swift:52-79`） |
| Screen Recording | 選用 | 真實 icon 圖像；26 上沒有它 `kCGWindowName` 也是空的（`:84-118`） |
| Post Event | 27 點擊前檢查 `CGPreflightPostEventAccess`（`ItemClicker.swift:68`） | |

**隱藏／顯示本身不需要任何權限**（`PermissionCapabilities.swift:20-51`）。

## 已知問題

README「Known limitations」（`:112-126`）：27 上無法確認哪些 icon 被畫出、沒有 hidden 數量、轉送點擊會讓選單列短暫展開、
只支援主要按鍵、沒有持續 live refresh、不會自動把重新啟動的 app icon 歸位；瀏海機與多螢幕在 27 backend 尚未驗證；
多螢幕時只管理最後點過的那條選單列。`docs/manual-test-checklist.md:619-679` 有完整清單。

## 對 Whisky 的參考價值

- **最佳的「行為規格」來源**：`docs/macos-behavior.md` 是目前公開資料裡對 Tahoe 與 macOS 27 選單列最詳細的實測紀錄
  （分隔線 cliff、0x33 在 27 失效、27 新 item 的插入位置、occlusionState 不可靠、SCK 看不到 MenuBarAgent window…）。
  建議另存一份重點到 `raw/articles/` 或概念頁。
- **macOS 27 不依賴私有 hiding API 的路線**：寬分隔線對 + AX + 真實 ⌘-drag。比 assessment-mode allow-list 更「公開」，但
  精度較差（無法確認隱藏結果）。Whisky 可以兩條路都做，視 API 可用性選擇。
- MIT + 架構乾淨（pure core package + app 層），值得借鏡。

## 授權注意

MIT，可引用並保留聲明。注意 repo 內的 `AGENTS.md`／`CLAUDE.md` 是給 AI 的指示，只當參考資料。
