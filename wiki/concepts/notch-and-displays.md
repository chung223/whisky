---
title: 瀏海、多螢幕、Spaces 與全螢幕
type: concept
tags: [notch, multi-display, spaces, fullscreen, nsscreen, nspanel]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/frostbar__frost
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/FelixKratz__SketchyBar
  - https://github.com/TheBoredTeam/boring.notch
  - https://github.com/Lakr233/NotchDrop
updated: 2026-10-14
---

# 瀏海、多螢幕、Spaces 與全螢幕

## 瀏海

### 偵測與幾何（全是公開 API，macOS 12+）

| 量 | API | 誰用 |
|---|---|---|
| 有沒有瀏海 | `NSScreen.safeAreaInsets.top > 0`，或 `auxiliaryTopLeftArea != nil` | [Frost](../projects/frost.md) `Frost/Support/Preferences.swift:73-77`；[Hidden Bar](../projects/hidden-bar.md) `NotchOverflowController.swift:37-59`；[SaneBar](../projects/sanebar.md) `MenuBarManager.swift:110-115`；[SketchyBar](../projects/sketchybar.md) `src/workspace.m:44-62` |
| 瀏海左／右可用區 | `auxiliaryTopLeftArea`、`auxiliaryTopRightArea` | [Ice](../projects/ice.md) `MenuBarItemManager.swift:1342-1349`；Hidden Bar；boring.notch |
| 瀏海寬 | `frame.width − leftArea.width − rightArea.width` | boring.notch `sizing/matters.swift`（見 [notch-apps](../projects/notch-apps.md)） |
| 瀏海高 | `safeAreaInsets.top` | boring.notch、SketchyBar |

### 問題：item 被瀏海吃掉

選單列太擠時，macOS **不會畫**落在瀏海後面的 item（[Frost](../projects/frost.md) README；[MenubarHide](../projects/menubarhide.md) README）；在 macOS 27 則改成系統自己的 `«` overflow。

| 專案 | 應對 |
|---|---|
| [Ice](../projects/ice.md)／[Thaw](../projects/thaw.md) | **Ice Bar／Thaw Bar**：在選單列下方的 `NSPanel` 顯示隱藏 item，點擊時 temp-show；Thaw 可設定只在有瀏海的螢幕用（`Profile.swift:39`） |
| [Thaw](../projects/thaw.md) | **Notch overflow rebalance**：計算瀏海右側到 Control Center 左緣的可用寬度（扣掉不能動的時鐘等），自動把放不下的 visible item 移到 hidden（`MenuBarItemManager+NotchOverflow.swift:13-107`） |
| [Hidden Bar](../projects/hidden-bar.md) | **Notch Overflow 選單**：`x < auxiliaryTopRightArea.minX` 的 item 列成 `NSMenu`，點擊用 AXPress（`NotchOverflowController.swift:63-80`, `:215-218`） |
| [Frost](../projects/frost.md) | **Frost Bar**（Automatic 模式只在瀏海螢幕用）；瀏海後的 item 在使用者閒置時一次一個移出、擷取、移回（`FrostBarController+ObscuredCapture.swift:136-275`） |
| [MenubarHide](../projects/menubarhide.md) | **Panel 模式**：把隱藏 icon 畫在選單列下方面板 |
| [SaneBar](../projects/sanebar.md) | **Second Menu Bar**；拒絕跨越瀏海的拖曳（WindowServer 會丟掉，`docs/NOTCH_MOVE_LIMITATION.md:19-25`） |

其他：Ice 的「空白區域」判定排除瀏海（`EventManager.swift:502-520`）；MenubarHide 在 27 上以瀏海右側區域 × 0.79 為 cliff（`CollapsedGeometry.swift:8-20`）。

### 獨立 bar 的 window 設定

| 專案 | level | collectionBehavior |
|---|---|---|
| [Ice](../projects/ice.md) Ice Bar | `.mainMenu + 1` | `.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace`（`IceBar.swift:36-37`） |
| [Thaw](../projects/thaw.md) Thaw Bar | `.mainMenu + 1` | 同上 + `.stationary`（`Thaw/MenuBar/IceBar/IceBar.swift:56-57`） |
| [SaneBar](../projects/sanebar.md) Second Menu Bar | `.floating` | `.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary`（`SearchWindowController.swift:20-22`） |
| [MenubarHide](../projects/menubarhide.md) Panel | `.statusBar`，`.nonactivatingPanel` | `.canJoinAllSpaces, .transient`（`HiddenItemsPanel.swift:3-100`） |
| [Frost](../projects/frost.md) Frost Bar | 非 activating 無邊框 `NSPanel` | `canJoinAllSpaces, fullScreenAuxiliary`（`FrostBarPanel.swift:16-33`） |
| NotchDrop | `.statusBar + 8` | `.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle` |

注意 NotchDrop 的 level 會蓋過 Ice Bar（原始碼註解「kills ibar」）；Whisky 的 bar 要考慮與其他工具並存。

## 多螢幕

- **每個螢幕都有一份選單列**。≤ 26 時每個 item 在每個螢幕都有 window，只有「作用中選單列」那份是真的，其他是 replica；點 replica 會遺失點擊
  （Frost `SectionController.swift:146-167`, `:1197-1270`）。macOS 27 只有一條合成的 bar（Frost `MenuBarItemScanner.swift:267-269`）。
- 作用中選單列的 display：私有 `CGSCopyActiveMenuBarDisplayIdentifier`（Thaw `Shims.swift:54-55`；SketchyBar `display.c:158`）。
- 列舉時用 `CGDisplayBounds` 過濾 item（Ice `MenuBarItem.swift:187-195`）；AX 對非作用中螢幕會回傳作用中螢幕的 menu bar，Ice 有特別修正
  （`MenuBarManager.swift:311-320`）。
- 分隔線長度要以**最寬螢幕**計算（Hidden Bar `LegacyLengthEngine.swift:40-49`；Thaw 超寬螢幕 spacer），27 的 cliff 則要以**最窄螢幕**計算
  （MenubarHide `CollapsedGeometry.swift:52-55`）。
- 設定：Thaw 的 profile 可綁 display UUID（`Profile.swift:18-21`）；SaneBar 可選「外接螢幕不隱藏」、位置備份以螢幕寬為 key
  （`StatusBarPositionDefaultsStore.swift:101-120`）。
- 螢幕組態變更：`NSApplication.didChangeScreenParametersNotification`（Hidden Bar）或 `CGDisplayRegisterReconfigurationCallback`（SketchyBar）後重算。
- 選單列高度用 `screen.frame.maxY − visibleFrame.maxY`，不要用 `NSStatusBar.thickness`（Frost `MenuBarItemScanner.swift:381-386`；SketchyBar 在 Tahoe 再減 1 px）。

## Spaces 與全螢幕

- 全螢幕 Space 判斷：私有 `CGSSpaceGetType(cid, CGSGetActiveSpace(cid)) == 4`（Ice `Bridging.swift:243-246`）。
- 選單列被系統隱藏：`NSApp.currentSystemPresentationOptions` 含 `.hideMenuBar`／`.autoHideMenuBar`，或全域 default `_HIHideMenuBar`
  （Ice `MenuBarManager.swift:87-116`）；macOS 27 的私有 `SLSGetSpaceMenuBarReveal` 可得 reveal 比例（Thaw 3）。這時「滑鼠在選單列內」要改用
  menu bar window 的 frame 判斷（Ice `EventManager.swift:448-466`）。
- Space 切換：`NSWorkspace.activeSpaceDidChangeNotification`；Mission Control／切 Space 會觸發大量 layout 變動（Thaw #718），Frost 在切 Space 時關閉
  Frost Bar（`FrostBarController.swift:117-143`）。
- 只在某些 Space 生效：Thaw 的 profile 綁 Space，`CGSSpaceID` 登出後會重新編號，要另存持久 key（`Bridging.swift:233-237`）。
- 外觀 overlay 在全螢幕、Mission Control 時要隱藏（SaneBar `MenuBarAppearanceSuppressionPolicy.swift:30-111`）。

## 瀏海幾何補充（2026-10-14）

- **瀏海右側的死帶**：`auxiliaryTopRightArea` 右邊還有約 14–30 pt，圖示回報的位置正常，實際上不會畫出來。MenuTidy 用 `notchDrawInset`（預設 22）校正（[MenuTidy](../../raw/github/readmes/PerpetualBeta__MenuTidy.md)）。
- **沒畫出來的項目座標仍看似合理**：只能用「是否落在可繪區」判斷，不能用座標本身（[Mezzanine](../../raw/github/readmes/brianmpollack__Mezzanine.md)）。
- **macOS 只畫完全落在瀏海右側的項目**：所以撐寬的線永遠看不見，控制用的把手必須是另一個項目（[Barn](../../raw/github/readmes/nicholaspsmith__menubar-barn.md)）。
- **瀏海機的 status 區寬度**：overhang 說只有約 790 pt（[overhang](../../raw/github/readmes/nicglazkov__overhang.md)）。
- **預寫 Preferred Position**：在建立項目之前先寫 `NSStatusItem Preferred Position`，新項目就不會落進 26 的瀏海死區（[BigMenu](../../raw/github/readmes/roeezolantz__BigMenu.md)），也能讓自己的圖示貼緊 Control Center（overhang；值從右邊算起，越小越靠右）。
- **「選單列已滿」的訊號**：系統 « 出現才可靠；作者的 Mac 在寬度 67% 時就已經開始丟圖示（MenuTidy `:165`）。
- **依選單列寬度切換設定**：以選單列寬度當 key 存不同的隱藏設定，接上或拔掉外接螢幕時自動切換（[Tuck](../../raw/github/readmes/beaugunderson__tuck.md)）。

以上出自 README；以下已讀原始碼：

- **可繪區判斷**（[Mezzanine](../projects/mezzanine.md) `MenuBarItemScanner.swift:263-319`）：逐螢幕計算，瀏海螢幕的可繪區是 `auxiliaryTopRightArea.minX` 到右緣；item 沒有**整個**落在可繪區內就算沒畫出來。
  選單列高度優先用 `safeAreaInsets.top`，沒有才用 `NSStatusBar.system.thickness`。Cocoa 與 AX 座標以主螢幕 `maxY` 翻轉。主螢幕左邊的螢幕 x 是負的。
- **死帶**（[MenuTidy](../projects/menutidy.md) `main.swift:2213-2238`）：同一台 Mac 兩次觀察到可畫邊界在 `auxiliaryTopRightArea.minX` 右邊 14–30 pt，預設取 22；只看 `NSScreen.main`，沒有逐螢幕。
- **bar 的視窗層級**：Mezzanine 用 `.popUpMenu`，註解說和 Bartender 的 bar 相同；Chest 的抽屜也用 pop-up menu level。【推論】[Bartender 機制](../bartender/mechanisms.md) 觀察到的層級包含 101（`.popUpMenu`），說法相符。
  Mezzanine 的 strip 尺寸（高 33 pt、每格 38 pt、在選單列下方 5 pt）註解說是量 Bartender Bar 得到的。

## 對 Whisky 的建議

- 瀏海機預設開啟「獨立 bar」（Bartender 6 的 NotchBar 對應）；level `.mainMenu + 1` 起跳，`canJoinAllSpaces + fullScreenAuxiliary`。
- 實作 Thaw 式的 notch overflow 自動平衡，避免使用者以為 item 消失。
- 多螢幕：明確區分「作用中選單列」與 replica；所有幾何都以 display ID 為範圍。
