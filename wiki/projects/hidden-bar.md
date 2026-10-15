---
title: Hidden Bar
type: project
tags: [open-source, swift, appkit, mit, menu-bar-hider, private-api, macos-27]
sources:
  - raw/github/repos/dwarvesf__hidden
  - https://github.com/dwarvesf/hidden
  - https://github.com/dwarvesf/hidden/pull/420
updated: 2026-10-12
---

# Hidden Bar

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [dwarvesf/hidden](https://github.com/dwarvesf/hidden)（預設分支 `develop`） |
| 授權 | **MIT** |
| 語言 | Swift（AppKit，storyboard） |
| Stars | 約 15.2k |
| 活躍度 | 2022–2026 停擺後復活：v1.10（2026-03）、v1.11.1（2026-09-18）；最新 commit 2026-09-19 加入 Notch Overflow（#420） |
| 支援的 macOS | Deployment target 13.0（`Hidden Bar.xcodeproj/project.pbxproj:646`） |
| macOS 26 Tahoe | 用傳統分隔線可用 |
| macOS 27 | **只有直接下載版**可用（私有 MenuBarClientCore）；App Store 版（sandbox）不能藏 |

Hidden Bar 是最簡單、最多人用的「分隔線」型隱藏工具：一個箭頭 + 一條分隔線，點箭頭就展開／收合。沒有排列、沒有獨立 bar、
不擷取圖像。2026 年的重點是：(1) macOS 27 改用 Apple 私有的 assessment-mode allow-list 隱藏；(2) 新增 Notch Overflow 選單。

本頁 file:line 相對於 `raw/github/repos/dwarvesf__hidden/`（commit `47937b9`）。

## 架構

| 型別 | 角色 |
|---|---|
| `AppDelegate` | 單一實例、HotKey、login item |
| `StatusBarController`（`hidden/Features/StatusBar/StatusBarController.swift`） | 擁有 status item、menu、計時器、hover |
| `MenuBarEngine` protocol + `LegacyLengthEngine`／`NativeVisibilityEngine` | 依 macOS 版本選擇隱藏機制（`Engine/MenuBarEngineFactory.swift:10-23`） |
| `HBNativeVisibilityShim.m` | Objective-C shim，呼叫私有 MenuBarClientCore |
| `AccessibilityMenuBarInventory` + `MenuBarLayoutResolver` | 用 AX 把 item 分到各 section |
| `NotchOverflowController` | 瀏海溢出選單 |

唯一 SPM 依賴：soffes/HotKey 0.1.3（Carbon hotkey 包裝）。

## 關鍵機制（附 file:line）

### 隱藏（macOS ≤ 26）：可變長度分隔線

- 箭頭 `variableLength`、分隔線長度 1（`StatusBarController.swift:18-19`），autosave name `hiddenbar_expandcollapse`／
  `hiddenbar_separate`（`:157-158`）。
- `LegacyLengthEngine`：展開時 20 pt；收合時 `max(500, min(最寬螢幕寬 × 2, 10_000))`，註解說 macOS 把
  `NSStatusItem.length` 上限夾在 10,000（`Engine/LegacyLengthEngine.swift:16`, `:40-49`）。螢幕參數改變就重算（`:81-84`）。
- 第三個「always hidden」項目 `hiddenbar_terminate`，長度 0／20／收合長度（`StatusBarController.swift:378-397`；
  `LegacyLengthEngine.swift:61-69`）。
- 排列是否有效：比較兩個 status item `button.window.frame.origin.x`，RTL 語系反向（`Engine/MenuBarEngine.swift:47-56`）；
  分隔線不在箭頭左邊就不收合（`StatusBarController.swift:249`）。

### 隱藏（macOS 27）：MenuBarAgent 的 assessment-mode allow-list

- 只在編譯旗標 `HIDDENBAR_NATIVE_VISIBILITY`（Direct 組態，`project.pbxproj:906-957`）且 `majorVersion >= 27` 時啟用
  （`Engine/MenuBarEngineFactory.swift:13-21`）。註解：macOS 27 會把撐大的分隔線踢出選單列（#360）；App Store 版因 sandbox
  擋住 AX 讀取而無法使用。
- `HBNativeVisibilityShim.m:23-75`：
  - `dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore")`（`:27`, `:36`）。
  - 類別 `MBAssessmentModeConfiguration`、`MBAssessmentModeAssertion`（`:28-29`）。
  - selector：`initWithAllowedSystemItems:allowedBundleIdentifiers:`、`activateWithConfiguration:completionHandler:`、
    `invalidate`（`:31-33`）。先 `instancesRespondToSelector:` 檢查，缺一個就回報不可用（`:35-45`）。
  - 用 `objc_msgSend` 呼叫，包在 `@try`；兩個參數都必須是 `NSArray`（`:57-74`）。
  - 註解：MenuBarClientCore 是 macOS 27「assessment（考試鎖定）模式」背後的私有 framework，可把選單列限制在 allow-list。
- allow-list 內容：system items `0..<64` 全允許（`NativeVisibilityEngine.swift:35-37`），bundle ID = 自己 + visible 區的 app
  （`:189-212`）；任何錯誤就解除限制，不讓東西卡在隱藏狀態（`:205-209`）。分隔線改為 `isVisible = false`，只剩箭頭當邊界
  （`:73`, `:214-218`）。
- 粒度是**整個 app**：同一 app 的多個 item 一起藏（`hidden/Features/StatusBar/Layout/MenuBarLayout.swift:71-74`）；macOS 27 的
  AX 不給 item title／identifier（`:26-27`）。系統 item 永遠可見（CHANGELOG `:18`）。
- 必須從 /Applications 執行，否則連自己的箭頭都會被藏（`docs/MANUAL.md:28-29`）。

詳見 [menubar-agent-allow-list](../concepts/menubar-agent-allow-list.md)。

### 列舉

不用 CGWindowList，只用 AX：`NSWorkspace.runningApplications` → `AXUIElementCreateApplication` → `"AXExtrasMenuBar"` →
children → position／size，messaging timeout 0.1 s，背景執行（`hidden/Features/StatusBar/Layout/AccessibilityMenuBarInventory.swift:36-83`）。
擁有者就是被查詢的 app，不受 Control Center 代管影響。27 上略過 `com.apple.MenuBarAgent`、`com.apple.controlcenter`、
`com.apple.systemuiserver`（`MenuBarLayout.swift:52-55`）。

### Notch Overflow

- 右鍵選單「Show Notch Items」（`StatusBarController.swift:331-337`）。
- 判斷被瀏海吃掉：item `position.x < screen.auxiliaryTopRightArea.minX`（`hidden/Features/NotchOverflow/NotchOverflowController.swift:63-80`）。
  瀏海偵測用 `safeAreaInsets.top > 0`（`:37-59`），只看 `NSScreen.main`，多螢幕時可能挑錯。
- 不擷取圖像：用 `NSRunningApplication.icon` 縮成 18×18 列成 `NSMenu`（`:188-213`）。
- 點擊用 `AXUIElementPerformAction(element, kAXPressAction)`（`:215-218`）。

### 其他

- 不支援移動別人的 item（`docs/MANUAL.md:93-97`）。
- 自動收合：預設 10 秒，滑鼠在選單列或設定視窗開著時延後（`StatusBarController.swift:302-323`）；可選 hover 展開（0.5 s dwell，
  `:96-118`）。
- Login item：`SMAppService.mainApp`（`hidden/Common/AutoStart.swift:21-40`）。

## 權限

只需 Accessibility（`AXIsProcessTrusted` + `kAXTrustedCheckOptionPrompt`，`NotchOverflowController.swift:222-227`；
`AccessibilityMenuBarInventory.swift:21-32`）。macOS ≤ 26 的分隔線模式不需要任何權限。App Store 版有 sandbox
（`hidden/Hidden.entitlements`），sandbox 會擋 `com.apple.axserver` lookup（`AccessibilityMenuBarInventory.swift:13-15`）。

## 已知問題

- App Store 版在 macOS 27 無法隱藏（CHANGELOG `:32`，#360）。
- 新 app 的圖示會出現在左邊（被藏起來）（CHANGELOG `:33`）。
- 外接螢幕 + 26.4 的問題 #351 未驗證（`docs/BACKLOG.md:30-32`）；瀏海、圖示漂移、always-hidden 相關 issue 群（`:67-73`）。
- v1.11 誤把 sandbox 版當 GitHub 版發布（`docs/RUNBOOK.md:57-66`）。
- 文件部分過時（`docs/ARCHITECTURE.md` 仍說永遠用 length engine）。

## 對 Whisky 的參考價值

- **macOS 27 隱藏的最小可行範例**：MIT 授權、程式碼短，清楚示範如何安全地 `dlopen` + `NSClassFromString` +
  `respondsToSelector` 探測私有 API，失敗就退回「不隱藏」。
- **雙引擎設計**：`MenuBarEngine` protocol + factory 依 OS 選實作，是 Whisky 應採用的結構（也見 [Frost](frost.md) 的
  backend 選擇）。
- 限制要記住：allow-list 粒度是 app，不是 item；系統 item 不能藏；需 /Applications 與非 sandbox。

## 授權注意

MIT。可以引用程式碼，但需保留著作權聲明與授權文字。HotKey 也是 MIT。私有 framework 的使用無法上 Mac App Store。
