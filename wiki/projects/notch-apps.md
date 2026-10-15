---
title: 瀏海區 app（boring.notch、NotchDrop）
type: project
tags: [open-source, swift, notch, gpl-3.0, mit]
sources:
  - https://github.com/TheBoredTeam/boring.notch
  - https://github.com/Lakr233/NotchDrop
  - https://github.com/Lakr233/SkyLightWindow
updated: 2026-10-12
---

# 瀏海區 app（boring.notch、NotchDrop）

## 概要

Bartender 6 有「NotchBar」功能，所以這裡記錄把 MacBook 瀏海當 UI 區域的兩個開源 app。它們**不是**選單列管理工具，沒有 clone，
只用 `gh api` 讀了幾個關鍵檔（2026-10-12）。

| 專案 | 授權 | 語言 | Stars | 最後 push | 最低 macOS | 簡介 |
|---|---|---|---|---|---|---|
| [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) | **GPL-3.0** | Swift | 11.0k | 2026-10-12 | 14（README；Now Playing 需 15.6 + MediaRemoteAdapter） | 瀏海變成音樂控制、行事曆、檔案 shelf + AirDrop、HUD 替代 |
| [Lakr233/NotchDrop](https://github.com/Lakr233/NotchDrop) | **MIT** | Swift | 2.1k | 2026-05-18 | — | 瀏海當成像 Dynamic Island 的暫存區與 AirDrop |

## 架構與關鍵機制

### 瀏海幾何

boring.notch 的 `boringNotch/sizing/matters.swift`（`getClosedNotchSize`）：

- 瀏海寬 = `screen.frame.width − auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width`（+4 微調）。
- 瀏海高 = `screen.safeAreaInsets.top`（> 0 才代表有瀏海）。
- 沒有瀏海時用預設值（寬 185）。

這和 [Ice](ice.md)／[Thaw](thaw.md)／[Hidden Bar](hidden-bar.md)／[Frost](frost.md) 判斷瀏海的方式一致。詳見
[notch-and-displays](../concepts/notch-and-displays.md)。

### 蓋在瀏海上的 window

- NotchDrop `NotchDrop/NotchWindow.swift`：無邊框、透明、無陰影的 window，`level = .statusBar + 8`（註解自嘲「kills ibar lol」，
  也就是會蓋過 [Ice](ice.md) 的 Ice Bar），`collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]`，
  所以在所有 Space 與全螢幕 app 上都看得到。
- boring.notch `boringNotch/components/Notch/BoringNotchSkyLightWindow.swift`：`NSPanel`，`level = .mainMenu + 3`、`.canJoinAllSpaces`；
  另外可選擇用 [Lakr233/SkyLightWindow](https://github.com/Lakr233/SkyLightWindow)（MIT，「Display your UI on lock screen」）把 window
  「委派」到 SkyLight 的特殊 space，必要時以 `dlsym` 取得私有 `SLSRemoveWindowsFromSpaces` 撤銷。

## 權限

視功能而定（行事曆、媒體控制等）；瀏海 window 本身不需要任何 TCC 權限。

## 已知問題

- boring.notch 沒有 Apple Developer 帳號簽章，首次開啟會被 Gatekeeper 擋（README）。
- macOS 15.4 起 MediaRemote 被鎖，Now Playing 需要第三方 adapter。

## 對 Whisky 的參考價值

- 若 Whisky 要做類似 Bartender 6 NotchBar 的「瀏海旁顯示隱藏 item」，window level 要高於 `.mainMenu`（實務上 `.mainMenu + 1` ～
  `.statusBar + 8`），並注意和其他工具（Ice Bar、Thaw Bar）互相遮蓋。
- 瀏海尺寸的計算只需要公開的 `NSScreen.auxiliaryTopLeftArea`／`auxiliaryTopRightArea`／`safeAreaInsets`（macOS 12+）。

## 授權注意

boring.notch 是 GPL-3.0，不可複製；NotchDrop 與 SkyLightWindow 是 MIT，可引用並保留聲明。
