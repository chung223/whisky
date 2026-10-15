---
title: SketchyBar
type: project
tags: [open-source, c, objective-c, gpl-3.0, bar-replacement, private-api, skylight]
sources:
  - raw/github/repos/FelixKratz__SketchyBar
  - https://github.com/FelixKratz/SketchyBar
updated: 2026-10-12
---

# SketchyBar

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar) |
| 授權 | **GPL-3.0** |
| 語言 | C + Objective-C（無 `NSApplication`，Carbon run loop） |
| Stars | 約 12.5k |
| 活躍度 | v2.24.1（2026-10-09），持續維護 |
| 支援的 macOS | 建置目標 x86_64 10.13、arm64 11（`makefile:37-40`）；程式碼有 macOS 26、27 專屬分支 |
| macOS 26／27 | 主功能（自己的 bar）可用；alias 功能在 27 上【推論】失效（27 沒有 per-item window） |

SketchyBar 不是選單列「管理工具」，而是完全可腳本化的**狀態列替代品**：自己畫 bar、item、popup，用 shell 腳本設定。
和 Whisky 相關的是：(1) 它是**私有 SkyLight API 的百科全書**；(2) `alias` 功能能把其他 app 的選單列 item 鏡像到自己的 bar。

本頁 file:line 相對於 `raw/github/repos/FelixKratz__SketchyBar/`（commit `515046e`）。

## 架構

| 檔案 | 角色 |
|---|---|
| `src/sketchybar.c` | 啟動：連線、notify proc、lockfile、Carbon run loop |
| `src/bar_manager.c` | 全域狀態、1 Hz timer、事件分派、display／space 處理 |
| `src/bar.c` | 每個 display 一條 bar；frame 與瀏海計算、item 佈局、window 排序 |
| `src/window.c` | SkyLight window 包裝：建立、shape、移動、level、排序、sticky space、擷取 |
| `src/surface.c`、`src/layer.m` | SLS surface + `CAContext`／`CALayer` 繪製 |
| `src/alias.c` | 選單列 item 的發現與鏡像 |
| `src/workspace.m` | NSWorkspace 通知、瀏海、app icon |
| `src/misc/extern.h` | 私有 SPI 宣告 |

## 關鍵機制（附 file:line）

### Alias：鏡像別人的選單列 item

- 發現：公開的 `CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID)`（`src/alias.c:72`），只留
  `layer == MENUBAR_LAYER (0x19 = 25)`（`:109`；`src/alias.h:7`），排除 owner `"Window Server"`（`:113-116`），依 x 排序（`:41-59`）。
  任何 key 缺少就略過——沒有 Screen Recording 時 `kCGWindowName` 被隱藏，所以 alias 完全看不到東西（`:98-100`）。
- 比對：`"<Owner>[,<Name>]"`，owner 完全相符；name 可以是 `"<name>(<i+1>)"` 用全域排序索引區分（`:197-223`）。
- 擷取：私有 `SLSCaptureWindowsContentsToRectWithOptions(cid, &wid, true, CGRectNull, 1 << 8, &image)`，再用
  `SLSGetScreenRectForWindow` 重讀 bounds（`src/window.c:372-403`）。沒有用 `CGWindowListCreateImage` 或 ScreenCaptureKit。
- 更新頻率：1 Hz timer（`src/bar_manager.c:65-78`），像素相同就不重畫（`src/image.c:147-176`）。擷取失敗就重新查 window ID，
  可處理 app 重啟（`alias.c:232-237`）。
- 擷取暫停：SLS notify 事件 1322 暫停約 1.07 s、905 無限期暫停、904／1401／1508 恢復（`src/sketchybar.c:192-221`），原始碼沒說明
  這些編號的意義。
- **不轉送點擊**：點 alias 只會跑使用者的 `click_script`（`src/event.c:72-106`；`src/bar_item.c:201-258`）。要打開真正的 menu 得自己
  寫 AppleScript。

### 自己的 bar window

- 全部是原生 SkyLight window，不是 `NSWindow`：`SLSNewWindowWithOpaqueShapeAndContext`（`window.c:53-120`），設 tag
  `kCGSExposeFadeTagBit | kCGSPreventsActivationTagBit`（`src/window.h:4-5`），用 SLS surface + `CAContext +contextWithCGSConnection:`
  畫圖（`src/surface.c:14-75`；`src/layer.m:5-24`）。
- Level：預設 `kCGBackstopMenuLevel`（在原生選單列之下）；`topmost=on` 用 `kCGStatusWindowLevel`（`bar_manager.c:37`, `:293-307`）。
- 不隱藏原生選單列：只讀 autohide 設定（`SLSGetMenuBarAutohideEnabled`，`src/display.c:240-244`），並在選單列可見時往下讓位
  （`src/bar.c:471-494`）。`SLSSetMenuBarVisibilityOverrideOnDisplay` 等只宣告未使用。
- Spaces：建立私有 space（absolute level 0）並把 bar window 都放進去，達成「所有 Space 都看得到」（`window.c:95-119`）；全螢幕 space
  （type 4）預設隱藏（`bar_manager.c:960`）。
- 多螢幕：`CGDisplayRegisterReconfigurationCallback` 觸發全部重建（`display.c:24-44`；`bar_manager.c:774-785`）；作用中 display 用
  `SLSCopyActiveMenuBarDisplayIdentifier`（`display.c:158`）。
- 瀏海：`NSScreen.safeAreaInsets.top`（`src/workspace.m:44-62`），`notch_width` 預設 200 把中央位置分成兩半（`bar.c:212-233`）。
- 選單列高度：`NSScreen.frame − visibleFrame` 再減 1 px（Tahoe 修正，`src/display_nsscreen.m:11-20`），失敗才用
  `SLSGetDisplayMenubarHeight`（`display.c:256-260`）。
- `window.c:318-324` 註解：macOS 27 上即使設了 PreventsActivation，點擊仍會把 window 提到前面。

### 事件

滑鼠用 Carbon `InstallEventHandler`（只收自己 window 的事件，無 event tap）（`src/mouse.c:4-38`），window ID 讀自 CGEvent
未公開欄位 `0x33`（`src/misc/helpers.h:557-559`）；hover 用 `SLSAddTrackingRect`。系統事件：NSWorkspace（前景 app、Space、
display、睡眠）、IOPS（電源）、SCDynamicStore + CoreWLAN（Wi-Fi）、CoreAudio（音量）、DisplayServices（亮度）、MediaRemote（`src/media.m`，
註解說 15.3 起被鎖）。

## 權限

只有 alias 需要 **Screen Recording**（`CGRequestScreenCaptureAccess`，`alias.c:168-172`）：讀 `kCGWindowName` 與擷取別人的 window。
不需要 Accessibility（沒有 AX 呼叫、沒有 event tap、沒有合成事件）。

## 已知問題

- Alias 依賴 owner／name 字串與寫死的 layer 25、1 Hz 輪詢、私有擷取旗標 `1<<8`，而且不能點擊轉送；瀏海後的 item 沒有處理。
- macOS 26 起 owner 全是 Control Center，`"<Owner>,<Name>"` 的 owner 比對【推論】需要改用 Control Center 名稱；macOS 27 沒有
  per-item window，alias 【推論】完全失效。
- `message.c:238-249` 有一段永遠跑不到的重複分支。

## 對 Whisky 的參考價值

- **私有 API 字典**：`src/misc/extern.h` 列出約 70 個 SLS 函式與其用法（詳見 [private-apis](../concepts/private-apis.md)）；Whisky 若要
  自己畫第二條 bar 並在所有 Space／全螢幕上顯示，可以參考它的 sticky space 與 window tag 作法（但要評估私有 API 風險）。
- Alias 的擷取路線（`SLSCaptureWindowsContentsToRectWithOptions`）是 Ice／Thaw 之外的另一種私有擷取 API。
- 事件來源清單（Wi-Fi、電源、音量、Focus…）可作為 Whisky triggers 的實作索引。

## 授權注意

GPL-3.0。不可複製程式碼。私有 API 的「名稱與用途」屬於事實資訊，可以記錄並獨立實作。
