---
title: MenubarHide
type: project
tags: [open-source, swift, appkit, mit, menu-bar-hider, macos-26, macos-27, screencapturekit]
sources:
  - raw/github/repos/junior-rj__menubar-hide
  - https://github.com/junior-rj/menubar-hide
updated: 2026-10-12
---

# MenubarHide（junior-rj/menubar-hide）

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [junior-rj/menubar-hide](https://github.com/junior-rj/menubar-hide) |
| 授權 | **MIT**（README 明言 Hidden Bar 與 Ice 只作研讀參考，程式碼全為原創） |
| 語言 | Swift 6 strict concurrency，XcodeGen，無 SPM 依賴 |
| Stars | 約 53（2026-07 建立） |
| 活躍度 | v1.6.1（2026-09-15），最新 commit 2026-10-04 |
| 支援的 macOS | 14.0 起（`project.yml:5`）；在 26 與 27 實測 |
| macOS 27 | 隱藏可用（改用「不超過 cliff 的分隔線 + 零寬 spacer」）；panel 與 arrangement 功能停用 |

兩種模式：**Sideways**（傳統分隔線）與 **Panel**（把隱藏的 icon 擷取後畫在選單列下方的浮動面板，瀏海機友善）。
README 的「How it works」與「macOS 26 Tahoe quirks」段落把 Tahoe 的坑寫得非常清楚。

本頁 file:line 相對於 `raw/github/repos/junior-rj__menubar-hide/`（commit `a4476bf`）。

## 架構

`StatusBarController`（item、幾何、輪詢、panel 流程、選單、login item）、`CollapsedGeometry`（27 的純函式尺寸計算）、
`MenuBarItemScanner`（CGWindowList 掃描）、`ItemCapturer`（擷取）、`HiddenItemsPanel`（`NSPanel` + SwiftUI）、
`ClickForwarder`（CGEvent 點擊）、`MenuBarArrangement`（CFPreferences 快照與還原）、`MenuBarSpacing`、`HotkeyManager`
（Carbon，固定 ⌃⌥H）。

## 關鍵機制（附 file:line）

### 隱藏

- **≤ 26**：分隔線 `CollapsedGeometry.legacyLength = 10_000`（`MenubarHide/CollapsedGeometry.swift:35`），macOS 26 會夾到約
  5,016 pt（`:5-6`）。註解警告不要用 `isVisible`，否則 autosave 位置會遺失（`MenubarHide/StatusBarController.swift:6-12`）。
- **Preferred Position 釘選**：Tahoe 上選單列太擠時新 item 會被丟到 x ≈ −4220 並「記住」這個壞位置。所以每次啟動、在建立
  item 之前，先把自己兩個 item 的 `NSStatusItem Preferred Position menubarhide_toggle／_separator` 寫回合理值
  （`StatusBarController.swift:63-100`；合理性檢查 `MenuBarArrangement.swift:36-38`）。
- **27**：一旦 item 長度達到某個「cliff」就被**丟棄**而不是夾住；cliff 在無瀏海螢幕約為螢幕寬的一半，有瀏海螢幕約為瀏海右側
  區域的 0.79（`CollapsedGeometry.swift:8-20`）。所以分隔線長度 = `max(200, floor(最低 cliff − 64))`，再用最多 6 個零寬 spacer
  一起撐開以覆蓋最寬的螢幕；被擠出去的 icon 進入系統自己的 `«` overflow 選單（`:36-64`；`StatusBarController.swift:111-147`）。
  27 上 autosave 名稱加 `_v27`（`:108-121`）。

### 列舉

`CGWindowListCopyWindowInfo(.optionAll)` 過濾 `layer == CGWindowLevelForKey(.statusWindow)`（25），讀 window number、bounds、
owner name（`MenubarHide/MenuBarItemScanner.swift:76-92`）。Tahoe 上擁有者全是 Control Center，所以**用形狀找自己的分隔線**：
寬度 ≥ 2500 的最右邊那個 status window（`:15-19`, `:28-48`）；隱藏的 item = 分隔線左邊連續的一串，遇到 > 50 pt 的空隙就停（`:34-63`）。
27 上 layer 25 是空的，只剩一個 MenuBarAgent 擁有、layer 24 的「Menubar」window。

### Arrangement 記憶（讀寫別人的 preferences）

- 掃 `~/Library/Preferences/*.plist` 與 `~/Library/Containers/<id>/Data/Library/Preferences/<id>.plist`（sandbox app 用絕對路徑當
  domain），用 `CFPreferencesCopyKeyList`／`CopyValue` 讀出所有 `NSStatusItem Preferred Position*` key（`MenubarHide/MenuBarArrangement.swift:31-64`, `:181-198`）。
- 還原時 `CFPreferencesSetValue` + `CFPreferencesAppSynchronize`（`:106-129`）。只在對方 app 下次啟動時生效。
- 這個方法的好處是完全不需要知道哪個 window 屬於哪個 app。27 上 per-app position key 已無作用，整個功能停用（`StatusBarController.swift:570-596`）。

### Panel：擷取 + flash-expand + 點擊轉送

- 擷取：先試 deprecated 的 `CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution])`，
  再退回 ScreenCaptureKit `SCContentFilter(desktopIndependentWindow:)` + `SCScreenshotManager.captureImage`（`MenubarHide/ItemCapturer.swift:27-78`）。
- 兩種 API 都**無法擷取螢幕外 window**（SCK 回 `-3811`，legacy 回 nil）。解法是「flash-expand」：展開 300 ms、擷取、再收合
  （`StatusBarController.swift:383-401`）。
- 點擊轉送：展開 → 輪詢 frame 3 次（150 ms）確認 item 在螢幕上且在隱藏側 → 在中心點送 `mouseMoved`、`leftMouseDown`、
  `leftMouseUp` 到 `.cghidEventTap`，`mouseEventClickState = 1`（預設 0 會讓 `NSEvent.clickCount == 0`，多數 status item 不理）→
  游標復位（`MenubarHide/ClickForwarder.swift:25-48`；`StatusBarController.swift:416-495`）。不用 AXPress、不針對 PID。

### Spacing

寫 `NSStatusItemSpacing` 與 `NSStatusItemSelectionPadding` 到 `kCFPreferencesAnyApplication`／CurrentUser／AnyHost，登出後生效
（`MenubarHide/MenuBarSpacing.swift:8-54`）。

## 權限

| 權限 | 何時 | 用途 |
|---|---|---|
| Screen Recording | 第一次開 panel | 擷取別人的 icon window（`ItemCapturer.swift:9-15`）；授權後需重開 app |
| Accessibility | 第一次在 panel 點 icon | 只用來送合成點擊（`ClickForwarder.swift:10-21`） |

Sideways 模式不需要任何權限。

## 已知問題

- 開機後先保持展開，等選單列穩定（最長約 2 分鐘）才收合（`README.md:65`；`StatusBarController.swift:157-195`）。
- 瀏海後面的 item 展開後仍不在螢幕上，無法點擊（`StatusBarController.swift:443-448`）。
- 子選單需要點第二次（`:526`）。
- 27：更新後要重新把 icon 拖到 `#` 左邊一次；panel 與 Icon Arrangement 停用；最多覆蓋最窄螢幕約 3.5 倍寬（`README.md:92-98`）。

## 對 Whisky 的參考價值

- README 與 `CollapsedGeometry` 的 27 cliff 實測（含瀏海機係數）可與 [Frost](frost.md) 的數據互相驗證。
- `NSStatusItem Preferred Position` 透過 `CFPreferences` 讀寫**其他 app** 的位置，是一個不需要事件模擬的「排列」手段（只對
  ≤ 26 有效）。
- flash-expand 擷取是「不用私有 SkyLight API 也能擷取隱藏 item」的公開 API 做法。

## 授權注意

MIT，可引用並保留聲明。repo 內的 `AGENTS.md`／`CLAUDE.md` 只當資料參考。
