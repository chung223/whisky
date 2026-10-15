---
title: MenuBarHider
type: project
tags: [open-source, swift, appkit, mit, menu-bar-hider, private-api, macos-27]
sources:
  - raw/github/repos/happy666End__MenuBarHider
  - https://github.com/happy666End/MenuBarHider
updated: 2026-10-12
---

# MenuBarHider

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [happy666End/MenuBarHider](https://github.com/happy666End/MenuBarHider) |
| 授權 | **MIT** |
| 語言 | Swift（AppKit），XcodeGen，無外部依賴 |
| Stars | 約 178（2026-09-18 建立） |
| 活躍度 | v0.1.0–v0.1.2（2026-09-21 ～ 10-02） |
| 支援的 macOS | 只支援 macOS 27（README）；`LSMinimumSystemVersion` 寫 26.0（`MenuBarHider/Resources/Info.plist:23-24`） |
| macOS 26 | 不支援 |
| macOS 27 | 是唯一目標 |

小而專注：兩條分隔線 `|` 與 `»`，中間的東西會被藏起來；點 `»` 顯示，逾時自動收回。README 自稱「talks to MenuBarAgent
directly, the same way the paid managers that survived do」。不需要 Screen Recording，只需要 Accessibility。

本頁 file:line 相對於 `raw/github/repos/happy666End__MenuBarHider/`（commit `2d63513`）。

## 架構

| 型別 | 角色 |
|---|---|
| `StatusItemController` | 兩條分隔線與選單 |
| `HidingController` | 狀態機：算出要送的 allow-list、管理系統 extras 的卸載／重載 |
| `MenuBarAgentBridge`（`HidingEngine`） | 私有 assertion |
| `SystemUIServerExtras`（`MenuExtraHost`） | 私有 `CoreMenuExtra*` 呼叫 |
| `MenuBarScanner`（`MenuBarItemSource`） | AX 掃描 |
| `SystemMenuItems` + `ClockHoverMonitor` | 時鐘 hover 例外 |
| `HiddenSet`／`MenuExtras`／`Settings` | 純 model，有 XCTest 搭配 fake |

## 關鍵機制（附 file:line）

### 隱藏：`MBAssessmentModeAssertion` allow-list

- 分隔線不撐長，只當位置標記：`»` 用 `squareLength`，`|` 12 pt（`MenuBarHider/App/StatusItemController.swift:20-21`），位置取
  `button.window.frame.minX`（`:38-43`）。
- `MenuBarHider/Services/MenuBarAgentBridge.swift`：
  - `dlopen(".../PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW)`（`:38-39`, `:49`）。
  - `NSClassFromString("MBAssessmentModeAssertion")`／`("MBAssessmentModeConfiguration")`（`:50-51`），檢查三個 selector
    都存在才算可用（`:52-58`）。
  - Configuration：`initWithAllowedSystemItems:` 傳 `NSNumber` 0..<64，`allowedBundleIdentifiers:` 傳 bundle ID 陣列（`:109-114`）。
  - Assertion 生命週期：新 assertion 啟用成功後才 invalidate 舊的，避免閃爍；失敗就保留舊的（`:84-93`）；`release()` 全部
    invalidate（`:99-106`）。
- system item 編號（macOS 27.0 build 26A428 的 `MBSystemItemIdentifier`）：0 battery、1 bluetooth、2 clock、3 displays、
  4 keyboard、5 volume、6 wifi、7 screenMirroring、8 primaryBentoBox（`Services/SystemItems.swift:3-7`）。
- allow-list = （running bundle IDs − 要藏的）∪ 永遠允許的系統 agent（Control Center、MenuBarAgent、SystemUIServer、
  TextInputMenuAgent、Siri、Spotlight…）（`Models/HiddenSet.swift:20-22`；`SystemItems.swift:13-26`）。
- 只有內容改變才重送；app 啟動／結束用 KVO 監看 `runningApplications`，debounce 1 秒（`Services/HidingController.swift:146-192`）。
- **必須在 /Applications**：MenuBarAgent 只對 /Applications 底下的 app 尊重 allow-list（`Services/AppLocation.swift:3`），所以
  app 會提議把自己搬過去（`App/ApplicationsMover.swift`）。

### 藏 Apple 自己的 menu extra：`CoreMenuExtra*`

SystemUIServer 裡的 extras（Time Machine、VPN…）在 MenuBarAgent 眼中都是同一個 bundle ID，allow-list 沒辦法單獨藏。
所以改為卸載：`dlopen` ApplicationServices，`dlsym` 取 `CoreMenuExtraGetMenuExtra`、`CoreMenuExtraAddMenuExtra`、
`CoreMenuExtraRemoveMenuExtra`（`Services/SystemUIServerExtras.swift:11-41`）；收合時 remove，展開時從
`/System/Library/CoreServices/Menu Extras/*.menu` 重新 add（`:48-78`）。被卸載的 ID 會存起來以便 crash 後復原
（`Models/Settings.swift:30-33`；`HidingController.swift:87-88`, `:153-161`, `:194-204`）。

### 列舉

只用 AX：每個非 `com.apple.*` 的 running app，`AXUIElementCreateApplication` + 0.2 s timeout → `kAXExtrasMenuBarAttribute` →
children → `kAXPositionAttribute.x`，用 `concurrentPerform` 平行掃，約 100 ms（`Services/MenuBarScanner.swift:31-77`）。
`leftSepX ≤ x < sepX` 的 app 判定為隱藏（`Models/HiddenSet.swift:11-18`）。時鐘從 MenuBarAgent 的 AX 樹裡用
`AXIdentifier == "com.apple.menuextra.clock"` 找（`Services/SystemMenuItems.swift:41-59`）。

### 副作用：通知中心

assessment mode 會擋住通知中心，所以滑鼠移到時鐘附近（40 pt 帶狀區）就暫時解除限制，離開後 0.5 s 再套回
（`App/ClockHoverMonitor.swift:18-36`；`HidingController.swift:29`, `:219-229`）。[Thaw](thaw.md) 的 macOS 27 版也有同樣的
「Clock activation bridge」。

## 權限

只要 Accessibility（`AXIsProcessTrusted`，`MenuBarScanner.swift:20-25`），每 2 秒輪詢直到授權（`HidingController.swift:231-241`）。
不 sandbox、ad-hoc 簽章、無 hardened runtime（`project.yml:9-17`）。

## 已知問題

- 私有 API，Apple 任何 27.x 更新都可能關掉（`README.md:130-131`）。
- 沒有 bundle ID 的 item、或不在 /Applications 的 app（包括 `~/Applications`）收合時一律被藏（`:132-134`）。
- 被卸載的 Apple extras 在系統設定裡顯示為「關閉」（`:135-138`）。
- 多螢幕未測試（`:139`）；沒有 hotkey、沒有移動、沒有 panel。

## 對 Whisky 的參考價值

- 和 [Hidden Bar](hidden-bar.md) 互相印證：同一組 selector、同樣需要 /Applications、同樣以 app 為粒度——這讓 allow-list 機制
  的可信度很高。
- 補足了 Hidden Bar 沒處理的兩件事：系統 extras 的卸載（`CoreMenuExtra*`）與通知中心的時鐘例外。
- 程式碼小、有測試、MIT，適合當 Whisky macOS 27 hiding engine 的參考起點。

## 授權注意

MIT，可引用並保留聲明。所用的 `MenuBarClientCore` 與 `CoreMenuExtra*` 都是 Apple 私有 API：無法上 App Store，且隨時可能失效。
詳見 [menubar-agent-allow-list](../concepts/menubar-agent-allow-list.md) 與 [private-apis](../concepts/private-apis.md)。
