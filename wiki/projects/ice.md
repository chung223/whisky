---
title: Ice
type: project
tags: [open-source, swift, appkit, gpl-3.0, menu-bar-manager, private-api]
sources:
  - raw/github/repos/jordanbaird__Ice
  - https://github.com/jordanbaird/Ice
  - https://github.com/jordanbaird/Ice/issues/954
  - https://github.com/jordanbaird/Ice/issues/711
  - https://github.com/jordanbaird/Ice/issues/665
updated: 2026-10-12
---

# Ice

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [jordanbaird/Ice](https://github.com/jordanbaird/Ice) |
| 授權 | **GPL-3.0** |
| 語言 | Swift（AppKit + SwiftUI） |
| Stars | 約 29.8k（2026-10-12） |
| 最後一次 commit（main） | 2025-09-20（只改 issue template）；最後正式版 0.11.12 是 2024-10-29 |
| 最後預覽版 | 0.11.13-dev.2（2025-09-16），來自未合併的 `macos-26` 分支（比 main 多 77 個 commit） |
| 支援的 macOS | Deployment target 14.0（`Ice.xcodeproj/project.pbxproj:236`） |
| macOS 26 Tahoe | 0.11.12 在 Tahoe 上大量回報壞掉；dev 版部分可用 |
| macOS 27 | 完全失效（[#954](https://github.com/jordanbaird/Ice/issues/954)） |

Ice 是目前最多人參考的開源 Bartender 替代品，功能涵蓋隱藏、always-hidden 區段、hover／click／scroll 顯示、自動 rehide、
獨立的 Ice Bar（給瀏海機）、拖拉排列、搜尋、選單列外觀（tint、shape、border、shadow）與 item spacing。
作者自 2025 年後幾乎停止維護，社群因此出現 [Thaw](thaw.md)、IceMelt 等 fork。

本頁的 file:line 都相對於 `raw/github/repos/jordanbaird__Ice/`（commit `11edd39`）。

## 架構

| 型別 | 角色 |
|---|---|
| `AppState`（`Ice/Main/AppState.swift`） | 全域狀態；全螢幕 Space 偵測（`:13`, `:108`）、`SetsCursorInBackground`（`:80-81`） |
| `MenuBarManager`（`Ice/MenuBar/MenuBarManager.swift`） | 管三個 section、偵測系統隱藏選單列、隱藏 app menu |
| `MenuBarSection`（`Ice/MenuBar/MenuBarSection.swift`） | show／hide／toggle 與 rehide timer（`:131-298`） |
| `ControlItem`（`Ice/MenuBar/ControlItem/ControlItem.swift`） | Ice 自己的三個 `NSStatusItem`（分隔線） |
| `MenuBarItemManager`（`Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift`，1671 行） | 列舉、快取、分區、移動、點擊、temp-show |
| `MenuBarItemImageCache` | 擷取其他 app 的 item 圖片 |
| `IceBarPanel`（`Ice/UI/IceBar/IceBar.swift`） | 選單列下方的獨立面板 |
| `EventManager`（`Ice/Events/EventManager.swift`） | 全域 mouse monitor：hover／click／scroll 顯示、smart rehide |
| `MenuBarOverlayPanel`（`Ice/MenuBar/Appearance/MenuBarOverlayPanel.swift`） | 疊在選單列上的外觀層 |
| `HotkeyRegistry`（`Ice/Hotkeys/HotkeyRegistry.swift`） | Carbon `RegisterEventHotKey` |
| `Bridging`（`Ice/Bridging/Bridging.swift` + `Shims/Private.swift`） | 私有 CGS 函式的 Swift 包裝 |

SPM 依賴（`project.pbxproj:393-428`）：Sparkle ≥ 2.5.2、LaunchAtLogin-Modern、AXSwift、CompactSlider、Ifrit。

## 關鍵機制（附 file:line）

### 隱藏：10,000 pt 的分隔線

- 三個 control item 的 autosave name 是 `SItem`（Ice 圖示）、`HItem`（hidden 分隔線）、`AHItem`（always-hidden 分隔線）
  （`ControlItem.swift:14-16`）。
- 長度只有兩種：`NSStatusItem.variableLength` 與 `10_000`（`ControlItem.swift:24-28`）。hidden／always-hidden 分隔線在
  `.hideItems` 狀態被設成 10,000，把左邊所有 item 推出螢幕左緣（`:148-175`）。
- 第一次啟動時寫入 `NSStatusItem Preferred Position SItem = 0`、`HItem = 1`，讓圖示落在最右邊（`:88-99`）。
  key 格式是 `"NSStatusItem \(key) \(autosaveName)"`（`Ice/Utilities/StatusItemDefaults.swift:44-57`）。
- `removeStatusItem` 會順便刪掉 preferred position，所以 deinit 前先暫存再寫回（`ControlItem.swift:128-136`, `:552-562`）。
- 想讓分隔線「看不見但仍佔位當分界」時，用了一個 hack：找出 status bar button 的水平 constraint 並停用，再把 window
  content size 設成寬 1（`ControlItem.swift:106-123`, `:166-173`）。作者自己在註解寫「could break in a new macOS release」。

詳見 [status-item-hiding](../concepts/status-item-hiding.md)。

### 列舉其他 app 的 item

- 用私有 `CGSGetProcessMenuBarWindowList(cid, 0, count, list, &outCount)` 取得所有選單列 item 的 window ID
  （宣告 `Ice/Bridging/Shims/Private.swift:101-108`，包裝 `Bridging.swift:125-141`）；`.onScreen` 選項再和
  `CGSGetOnScreenWindowList` 取交集（`Bridging.swift:143-146`）；`.activeSpace` 用 `CGSCopySpacesForWindows` 過濾
  （`:215-237`）。
- 每個 window ID 用公開的 `CGWindowListCreateDescriptionFromArray` 取 metadata（`Ice/Utilities/WindowInfo.swift:109-119`）。
  判斷是不是 menu bar item 只看 `layer == kCGStatusWindowLevel`（25）（`WindowInfo.swift:61-63`）。
- 擁有者：直接用 `kCGWindowOwnerPID` → `NSRunningApplication`（`WindowInfo.swift:55-57`, `:85`）。**這在 macOS 26
  失效**，因為所有 item window 都歸 Control Center 所有（見 [Thaw](thaw.md) 的修正）。
- item 身分 `MenuBarItemInfo` = `namespace`（bundle ID）+ `title`（`kCGWindowName`，也就是對方 status item 的 autosave
  name）（`MenuBar/MenuBarItems/MenuBarItem.swift:228-239`；`MenuBarItemInfo.swift:20-22`）。系統 item 用固定名稱，例如
  Control Center 的 `BentoBox`、`Clock`、`WiFi`（`MenuBarItem.swift:85-108`）。
- 不能移動的 item：Clock、Siri、Control Center（`MenuBarItemInfo.swift:33-34`）；能移動但不能隱藏：錄影指示器、
  FaceTime、Music Recognition（`:36-37`）。
- 即時 frame 用私有 `CGSGetScreenRectForWindow`（`Bridging.swift:58-66`）。

詳見 [menu-bar-item-enumeration](../concepts/menu-bar-item-enumeration.md)。

### 分區（section）判定

`cacheItemsIfNeeded()` 每次重新列舉，用 hidden／always-hidden 分隔線的 x 座標把 item 切成三段
（`MenuBarItemManager.swift:242-311`, `:315-365`；判斷式在 `Ice/Utilities/Predicates.swift:111-117`）。
如果使用者把 always-hidden 分隔線拖到 hidden 分隔線右邊，`enforceControlItemOrder` 會自動搬回來（`:1475-1488`）。

### 移動：合成 ⌘-drag CGEvent

這是 Ice 最關鍵、也最被後繼者沿用的技巧（`MenuBarItemManager.swift`）：

1. 事件來源 `CGEventSource(stateID: .hidSystemState)`（`:994`）。
2. mouse-down 位置刻意放在 `(20_000, 20_000)`（`:998`）——不在任何螢幕上，靠事件欄位指定目標，而不是靠座標。
3. 每個事件都設：`eventTargetUnixProcessID`、`eventSourceUserData`（唯一值，用來辨識自己的事件）、
   `mouseEventWindowUnderMousePointer`、`mouseEventWindowUnderMousePointerThatCanHandleThisEvent`，以及未公開欄位
   **`0x33`（window ID）**（`:1550-1561`, `:1638-1663`）。mouse-down 帶 `.maskCommand`（`:1531-1535`）。
4. mouse-up 放在目標 item 的左緣或右緣（`getEndPoint`，`:597-610`）。
5. 投遞方式「scrombleEvent」：先送一個 null event 到目標 PID 的 event tap，tap 收到後再把真正事件送進 session tap，
   並用第二個 listen-only tap 確認真正事件確實流過（`:761-859`）。每一步 50 ms timeout。
6. 投遞前用 `setLocalEventsFilterDuringSuppressionState(.permitAllEvents…)` 並把 `localEventsSuppressionInterval` 設 0，
   避免系統在合成事件期間吃掉使用者輸入（`:920-933`, `:1029-1037`）。
7. 移動前等使用者放開 modifier 與滑鼠停止（`:1082-1088`），隱藏游標，結束後 warp 回原位（`:1107-1112`）。
8. 驗證：比對 frame 是否改變，失敗最多重試 5 次，中間用一次假點擊「喚醒」item（`:936-977`, `:1114-1134`）。

詳見 [menu-bar-item-moving](../concepts/menu-bar-item-moving.md)。

### 點擊與 Ice Bar

- 點擊用相同的事件建構方式，加 `mouseEventClickState = 1`，送進 session tap 並等待收到（`:1170-1253`）。
- Ice Bar 是 `NSPanel`，level `.mainMenu + 1`，`collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle,
  .moveToActiveSpace]`（`Ice/UI/IceBar/IceBar.swift:11-37`）。
- 在 Ice Bar 點一個 item 時，**不是把點擊轉送到螢幕外的 window**，而是 `tempShowItem`：先把該 item 實際搬到可見區
  （必要時考慮 `auxiliaryTopRightArea` 也就是瀏海右側，`MenuBarItemManager.swift:1342-1349`），再點它，並記錄原位置；
  計時器到期後搬回去（`:1300-1395`, `:1401-1454`）。若 item 開了自己的視窗，延後 rehide（`:1416-1420`）。

詳見 [menu-bar-item-activation](../concepts/menu-bar-item-activation.md)。

### 圖像擷取

- 用已 deprecated 的 `CGImage(windowListFromArrayScreenBounds:…)`（即 `CGWindowListCreateImageFromArray`），透過一個
  protocol 繞過 deprecation 警告（`Ice/Utilities/ScreenCapture.swift:63-99`）。註解寫明：ScreenCaptureKit 不支援擷取
  螢幕外 menu bar item 的合成圖（`:85-88`）。
- 先整排合成擷取再按 frame 裁切；寬度不符就逐個擷取（`MenuBarItemImageCache.swift:102-190`），選項
  `[.boundsIgnoreFraming, .bestResolution]`（`:112`）。

詳見 [menu-bar-item-imaging](../concepts/menu-bar-item-imaging.md)。

### 顯示觸發、rehide、全螢幕

- hover／click 空白處／scroll 顯示：`EventManager.swift:148`, `:348-399`, `:401`。「滑鼠在選單列內」用
  `screen.visibleFrame.maxY` 判斷；選單列被系統隱藏或全螢幕時改用 menu bar window frame（`:448-466`）。
- 空白區 = 在選單列內、不在 app menu、不在 item、不在瀏海（`:515-520`）；app menu 範圍用 Accessibility
  `AXUIElementCopyElementAtPosition` 找 role 為 menuBar 的元素再合併子項 frame（`MenuBarManager.swift:292-320`）。
- rehide 策略：smart（點別處就收）、timed、focusedApp（`MenuBarManager.swift:118-125`；`EventManager.swift:180-210`）。
- 全螢幕：`CGSSpaceGetType == fullscreen`（`Bridging.swift:243-246`）；系統自動隱藏選單列：
  `NSApp.currentSystemPresentationOptions` 與全域 default `_HIHideMenuBar`（`MenuBarManager.swift:87-116`）。
- 「Hide application menus」：可見 item 和 app menu 重疊時把 Ice 自己 activate，讓前景 app 的 menu 消失
  （`MenuBarManager.swift:160-215`）。

### 外觀、spacing、hotkey

- 外觀層是 `NSPanel`，level `.statusBar`、`ignoresMouseEvents = true`（`MenuBarOverlayPanel.swift:91-96`）；為了畫出
  「選單列底下的桌布」，會擷取 wallpaper window 在選單列範圍的圖（`:296-303`），所以需要 Screen Recording。
- spacing：寫全域 `NSStatusItemSpacing`／`NSStatusItemSelectionPadding`，再重啟各 app 讓它們讀到新值
  （`Ice/MenuBar/Spacing/MenuBarItemSpacingManager.swift:14-20`, `:79-126`）。
- hotkey：Carbon `InstallEventHandler`／`RegisterEventHotKey`，沒有用 KeyboardShortcuts（`HotkeyRegistry.swift:6`, `:99`）。
- 其他私有 API：`CGSSetConnectionProperty("SetsCursorInBackground")` 讓背景 app 能隱藏游標（`AppState.swift:80-81`）；
  `CGSEventIsAppUnresponsive` 判斷 app 是否卡住（`Bridging.swift:260-271`）。

## 權限

| 權限 | 必要 | 用途（`Ice/Permissions/Permission.swift`） |
|---|---|---|
| Accessibility | 是（`:118-136`） | 「Get real-time information about the menu bar」「Arrange menu bar items」；app menu frame；合成事件 |
| Screen Recording | 否（`:140-157`） | 外觀編輯器（擷取桌布）、顯示 item 圖片；另外 `kCGWindowName` 沒有這個權限會是 nil |

Screen Recording 的檢查方式很特別：看其他 app 的 item window 有沒有 title，有就代表已授權
（`ScreenCapture.swift:12-23`）；macOS 15 上 `CGRequestScreenCaptureAccess()` 壞掉，改呼叫 `SCShareableContent` 觸發
系統提示（`:47-55`）。詳見 [permissions](../concepts/permissions.md)。

## 已知問題

- [#344](https://github.com/jordanbaird/Ice/issues/344)：item 自己跑到 hidden／always-hidden 區段（macOS 把新 item 放最左邊，
  而那正是 always-hidden 區；`FREQUENT_ISSUES.md` 也有說明）。
- Tahoe：[#711](https://github.com/jordanbaird/Ice/issues/711)、[#679](https://github.com/jordanbaird/Ice/issues/679)
  「Unable to display menu bar items」、[#744](https://github.com/jordanbaird/Ice/issues/744) Layout 設定頁空白、
  [#665](https://github.com/jordanbaird/Ice/issues/665) Ice Bar 看不見、[#786](https://github.com/jordanbaird/Ice/issues/786)
  開 Ice Bar 會 crash。根因是 Tahoe 把 item window 改成 Control Center 擁有、`CGWindowListCreateImage` 不能用。
- macOS 27：[#954](https://github.com/jordanbaird/Ice/issues/954)，整條選單列變成單一 window，Ice 所有機制失效。
- 選單列設成「自動隱藏」時無法排列（`FREQUENT_ISSUES.md`）。
- 不會記住 item 順序（同上，issue #26）。

## 對 Whisky 的參考價值

- **技術地圖**：Ice 把「私有 window list → 分隔線分區 → ⌘-drag 移動 → temp-show 點擊 → CG 擷取」整條鏈路講得最清楚，
  是理解這一代（macOS 14–15）做法的最佳教材。
- **不能照搬**：GPL-3.0；而且 Tahoe／macOS 27 讓它的列舉、擷取、移動三大支柱都失效。對 Whisky 來說它是「歷史基線」，
  實作應參考 [Thaw](thaw.md)（26）與 [Frost](frost.md)、[MenuBarHider](menubarhider.md)（27）的修正後做法。
- 值得借鑑的設計：item 身分用 `bundleID:autosaveName`、preferred position 的保存與寫回、事件投遞後等待確認而非固定 sleep。

## 授權注意

GPL-3.0。直接複製任何程式碼都會讓 Whisky 必須以 GPL 發布。只能閱讀後用自己的話描述行為與 API，再獨立實作。
Thaw、IceMelt、Hoarfrost、icey 等 fork 同樣是 GPL-3.0。
