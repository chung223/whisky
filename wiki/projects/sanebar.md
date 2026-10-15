---
title: SaneBar
type: project
tags: [open-source, swift, appkit, mit, menu-bar-manager, accessibility, no-private-api, sunset]
sources:
  - raw/github/repos/sane-apps__SaneBar
  - https://github.com/sane-apps/SaneBar
  - https://github.com/sane-apps/SaneBar/releases/tag/sunset
updated: 2026-10-12
---

# SaneBar

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [sane-apps/SaneBar](https://github.com/sane-apps/SaneBar) |
| 授權 | **MIT**（目前）。歷史：MIT → GPL-3.0 → PolyForm Shield 1.0.0 → 2026-06 改回 MIT（`CHANGELOG.md:31`, `:639-641`） |
| 語言 | Swift（AppKit + SwiftUI），XcodeGen |
| Stars | 約 324 |
| 活躍度 | 最新 commit 2026-09-20、v2.1.90（2026-08-22）；**已宣告 sunset**，轉為社群維護 |
| 支援的 macOS | 14.0 起（`project.yml:5`），release 只出 arm64 |
| macOS 26 Tahoe | 支援（有多個 Tahoe 專屬修正） |
| macOS 27 | **不支援**，作者因 macOS 27 而停止開發（`README.md:9-13`） |

SaneBar 原本是付費 app（也上過 Setapp），2026-06 起完全免費開源。功能很接近 Bartender：三區段、第二選單列／icon panel、
搜尋、profiles、triggers（app 啟動、電量、Wi-Fi、Focus、排程、腳本）、per-icon hotkey、AppleScript（約 30 個指令）、
Touch ID 鎖定隱藏區、外觀 overlay（Liquid Glass）、Bartender／Ice 設定匯入。特點是**完全不用私有 CGS／SkyLight API，
也不需要 Screen Recording**。

本頁 file:line 相對於 `raw/github/repos/sane-apps__SaneBar/`（commit `2311b23`，v2.1.91）。

## 架構

- `MenuBarManager`（`Core/MenuBarManager.swift`）：singleton，擁有 service 與 status item，lazy 建約 16 個 workflow 物件（`:159-175`）。
- `StatusBarController`：主圖示、分隔線、AH 分隔線、spacer；autosave 名稱版本化。
- `HidingService`：長度切換、「shield」順序、rehide 計時。
- `AccessibilityService` 與一整組 `Accessibility*Service`：掃描、Apple extras 展開、system-wide fallback、點擊、⌘-drag、幾何策略。
- Move pipeline：`MenuBarStandardIconMoveWorkflow` 等十多個 workflow；recovery：`MenuBarStatusItemRecoveryWorkflow`、
  `MenuBarVisibilityFlapDetector`、`MenuBarAutomaticMoveGate`。
- 依賴：KeyboardShortcuts 2.4.0、Sparkle 2.9.1、Setapp-framework（已退役）、自家 SaneUI（`project.yml:16-28`）。

## 關鍵機制（附 file:line）

### 隱藏

- 分隔線長度：展開 20、收合 10,000（`Core/Services/HidingService.swift:49-55`），藏起來的 item 被推到 x ≈ −3349（`ARCHITECTURE.md:326`）。
- 三區：Always-Hidden ｜AH 分隔線｜ Hidden ｜主分隔線｜ Visible；AH 分隔線平常 14 pt，顯示 hidden 區時設 10,000 讓 AH 區仍藏著
  （`HidingService.swift:90`, `:170-189`, `:228-235`）。
- 「shield」順序：主分隔線先變 10,000 → 改 AH → 主分隔線變 20，避免兩條分隔線同時可見而**弄壞系統記住的位置**
  （`:306-379`）。
- 位置種子：在 app domain 與 ByHost `.GlobalPreferences` 讀寫 `NSStatusItem Preferred Position <autosaveName>`
  （`Core/Services/StatusBarPositionDefaultsStore.swift:26-46`, `:204-230`）；autosave 名稱帶版本（`SaneBar_Main_v7`），遇到
  WindowServer 快取損壞就「升版」換名字逃離（`Core/Controllers/StatusBarController.swift:55-85`, `:206-357`）；每次啟動清掉
  `NSStatusItem Visible*` 與 macOS 26 新的 `VisibleCC*` key（`:100-102`）。
- 關掉使用者 ⌘-drag 移除 item 的能力：拿掉 `.removalAllowed`、`.terminationOnRemoval`（`:92-95`）。
- `main.swift:23-27` 在 `app.run()` 前設 `.accessory` activation policy；macOS ≥ 26 延遲 0.35 s 才建 status item（`Core/MenuBarManager.swift:204-214`）。

### 列舉（三層）

1. **主要**：每個 running app `AXUIElementCreateApplication` → `"AXExtrasMenuBar"` → children，讀 identifier、title、description、
   position、size（`Core/Services/AccessibilityMenuBarScanningService.swift:147-177`, `:416-536`）。
2. **Fallback 1**：公開 `CGWindowListCopyWindowInfo`，layer 24 或 25、alpha > 0、高 ≤ 60、寬 ≤ 500，依 owner PID 分組；不讀 window name，
   所以不需要 Screen Recording（`Core/Services/AccessibilityMenuBarWindowFallbackPolicy.swift:17-25`, `:114-143`）。
3. **Fallback 2**：`AXUIElementCreateSystemWide` + `AXUIElementCopyElementAtPosition` 沿著選單列每 6–8 px 打點，用
   `AXUIElementGetPid` 取擁有者，只留 role `AXMenuBarItem`／subrole `AXMenuExtra`（`Core/Services/AccessibilitySystemWideMenuBarScanner.swift:43-122`）。

Control Center 與 SystemUIServer 會被展開成每個 extra 一筆（深度優先、限深 12／512 節點），身分用 `AXIdentifier`
（`com.apple.menuextra.*`）（`Core/Services/AccessibilityMenuExtraService.swift:34-96`, `:162-295`）。item 身分格式
`bundleId::axid:<id>` 或 `bundleId::statusItem:<index>`（`Core/Models/RunningApp.swift:163-176`）。作者記錄：Tahoe 上真正擁有者
app 在 CGWindowList 裡查不到任何 window，`_AXUIElementGetWindow` 對 status item 回 −25201（`docs/NOTCH_MOVE_LIMITATION.md:35-45`）。

### 移動：只用公開 CGEvent 的 ⌘-drag

`Core/Services/AccessibilityMenuBarDragService.swift:445-623`：`CGEvent(mouseEventSource: nil, …)`、預設 `.cghidEventTap`。
mouseMoved → 60 ms → 隱藏游標 → ⌘ mouseDown → 80 ms → 10–14 個 ⌘ `leftMouseDragged`（每 15 ms；步數 = ⌈距離/22⌉）→ ⌘ mouseUp →
140 ms → 游標復位。事前輪詢 AX 直到 icon 在螢幕上（30 × 100 ms），用瀏海安全的起點；事後輪詢 AX 位置（20 × 50 ms）驗證落在
分隔線正確一側（`:154-376`）。第一次失敗會改用 `.cgSessionEventTap` 重試（`Core/Services/MenuBarStandardIconMoveWorkflow.swift:259-308`）。
自動（喚醒後復原）拖曳有同意閘門：每分鐘最多 6 次（`Core/Services/MenuBarAutomaticMoveGate.swift:11-93`）。

### 第二選單列與點擊

- 兩種模式：Icon Panel 與 Second Menu Bar；後者是 `.floating` level 的 `NSPanel`，`[.canJoinAllSpaces, .fullScreenAuxiliary,
  .ignoresCycle, .stationary]`，貼在選單列下方 4 pt（`UI/SearchWindow/SearchWindowController.swift:9-22`, `:600-711`）。
- **不擷取圖像**：tile 畫 `NSRunningApplication.icon`，Apple extras 用對應的 SF Symbol（`RunningApp.swift:194-221`, `:486-505`）。
- 點擊（`Core/Services/SearchService.swift:549-828`）：先展開（AH item 用 `showAll()`）→ 等 item 上螢幕 → 重新取 AX 元素 →
  `AXPress`（右鍵用 `AXShowMenu`）→ 失敗才送 `.combinedSessionState` 的硬體點擊（`Core/Services/AccessibilityClickService.swift:138-319`, `:511-607`）→
  用「出現新 menu／focused window／window 數增加／`kAXExpanded`」驗證 → 再失敗就 `NSRunningApplication.activate` → 15 s 後重新藏。

### 其他

- Hotkey：sindresorhus/KeyboardShortcuts（`KeyboardShortcutsService.swift:1-24`），支援 per-icon hotkey。
- Hover：全域 `NSEvent` monitor，dwell 預設 2 s；scroll、click、⌘-drag 也能顯示（`HoverService.swift:121-364`）。
- 外觀 overlay：click-through `NSPanel`，level `.statusBar − 1` 或 `.statusBar`；macOS 26 用 `.glassEffect`；全螢幕或 Mission
  Control 時隱藏（`MenuBarAppearanceService.swift:516-592`；`MenuBarAppearanceSuppressionPolicy.swift:30-111`）。
- 多螢幕：可選「外接螢幕不隱藏」；位置備份以螢幕寬為 key（`StatusBarPositionDefaultsStore.swift:101-120`）。
- 瀏海：拒絕跨越瀏海的拖曳，因為 WindowServer 會默默丟掉路徑穿過瀏海的 drag（`docs/NOTCH_MOVE_LIMITATION.md:19-25`）。

## 權限

| 權限 | 狀態 | 說明 |
|---|---|---|
| Accessibility | 必要 | `AXIsProcessTrusted`；監聽 `com.apple.accessibility.api` distributed notification 並輪詢（`AccessibilityService.swift:32`, `:189-274`） |
| Apple Events | AppleScript 用 | entitlement `com.apple.security.automation.apple-events` |
| Screen Recording | **刻意不用** | onboarding 標榜「No screen recording」（`UI/Onboarding/WelcomePermissionPage.swift:28`） |

不 sandbox（App Store 版從未出貨，`ARCHITECTURE.md:250`）。

## 已知問題

1. macOS 27：拖曳會觸發 Mission Control、右鍵 menu 失效（`.github/workflows/sunset-auto-close-issues.yml:38-42`）。
2. 瀏海左邊／後面的 icon 在 macOS 26 無法移動（#170, #155, #156；`docs/NOTCH_MOVE_LIMITATION.md:13-56`）。
3. macOS 26.4.1 每約 200 ms 翻轉一次 `NSStatusItem` visibility（BetterDisplay #5314、SaneBar #152）；FB9052637：切換 visibility
   會毀掉保存的位置；FB8732253：順序不保留（`docs/GEOMETRY_TRUST_REVIEW_2026-06-10.md:22-34`）。因此有「4 次翻轉／10 秒就休眠
   5 分鐘」的 flap detector（`MenuBarVisibilityFlapDetector.swift:3-39`）。
4. Tahoe status item 不可見、FrontBoard scene 迴圈（#107, #133）；macOS 27 overlay 蓋住 Mission Control（#158）。
5. 文件與程式碼有落差（`ARCHITECTURE.md` 提到不存在的檔案；註解說「no CGEvent simulation」但實際有）。

## 對 Whisky 的參考價值

- **「零私有 API、零 Screen Recording」路線的完整實作**：證明 AX + 公開 CGEvent 足以做出 Bartender 級的功能集（在 ≤ 26）。
  Whisky 若想降低審查／相容風險，可以把它當「安全模式」的藍本。
- 大量 Tahoe 實戰經驗（visibility flap、位置損壞、autosave 升版）記錄在 `docs/`，是很好的 regression 清單。
- 功能與 Bartender 最像（triggers、profiles、AppleScript、Touch ID），可對照 `wiki/bartender/` 的逆向結果規劃。

## 授權注意

目前 MIT，可引用。但**授權史曾經是 GPL-3.0 與 PolyForm Shield**，shallow clone 無法稽核歷史；`docs/NOTCH_MOVE_LIMITATION.md:28`
誤稱 Ice 是 MIT，且提到一個仿 Ice／Thaw「teleport」的 spike 分支 `fix/170-cross-notch-teleport`。保守做法：只參考概念與實測結論，
不要逐字搬運大段程式碼；避開該分支。
