---
title: 私有 API 一覽
type: concept
tags: [private-api, skylight, cgs, menubarclientcore, cgevent, defaults]
sources:
  - raw/github/repos/jordanbaird__Ice/Ice/Bridging/Shims/Private.swift
  - raw/github/repos/thaw-app__Thaw/Shared/Bridging/Shims.swift
  - raw/github/repos/FelixKratz__SketchyBar/src/misc/extern.h
  - raw/github/repos/dwarvesf__hidden/hidden/Features/StatusBar/Engine/Native/HBNativeVisibilityShim.m
  - raw/github/repos/happy666End__MenuBarHider/MenuBarHider/Services
  - raw/github/repos/frostbar__frost/Packages/FrostCore/Sources/FrostCore/Moving/CursorConcealment.swift
  - https://github.com/thaw-app/Thaw/tree/feat/thaw-3
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-12
---

# 私有 API 一覽

開源選單列工具用到的未公開符號、事件欄位與 defaults key。「私有」= 沒有公開 header 或文件。使用私有 API 的 app **不能上 Mac App Store**，
且可能在任何系統更新後失效。

## 引用方式

| 方式 | 誰用 | 風險 |
|---|---|---|
| `@_silgen_name("CGSFoo")` 直接連結（CoreGraphics 有 export 的符號） | [Ice](../projects/ice.md)、[Thaw](../projects/thaw.md)、[Frost](../projects/frost.md) | 符號消失時 **app 啟動就 crash**（dyld 找不到符號） |
| `dlopen` + `dlsym` | Thaw（SkyLight）、[Hidden Bar](../projects/hidden-bar.md)、[MenuBarHider](../projects/menubarhider.md)、boring.notch | 找不到只是 nil，可優雅降級。Thaw 註解明說這是刻意選擇（`MenuBarModel/.../Shims.swift` 約 107-112 行 @ `feat/thaw-3`） |
| `NSClassFromString` + `respondsToSelector` + `objc_msgSend` | Hidden Bar、MenuBarHider | 同上；呼叫包 `@try` |
| C 宣告 `extern`（ObjC／C 專案） | [SketchyBar](../projects/sketchybar.md) | 同 `@_silgen_name` |

**建議 Whisky 一律用 `dlsym`／`NSClassFromString` 動態解析**，並把每個私有能力做成「可用／不可用」旗標。

[Pelmet](../projects/pelmet.md) 全部走動態解析：MenuBarClientCore 用 ObjC shim（`dlopen` + `NSClassFromString` + `@try`），CGS 符號用
`dlsym(RTLD_DEFAULT, …)`（不用 `@_silgen_name`），其他私有 framework 用 `dlopen` 路徑 + `dlsym`；作者自己整理的私有 API 清單在
`docs/ARCHITECTURE-REVIEW.md:185`。下表中標「Pelmet」的路徑相對於 `raw/github/repos/fif7y__pelmet/`。

## CoreGraphics Services（CGS*，Ice／Thaw）

| 符號 | 用途 | 出處 |
|---|---|---|
| `CGSMainConnectionID`、`CGSDefaultConnectionForThread` | 取 WindowServer 連線 | Ice `Private.swift:36-37`；Thaw `Shims.swift:38-42` |
| `CGSCopyConnectionProperty`／`CGSSetConnectionProperty` | 設 `"SetsCursorInBackground"`，讓背景 app 能隱藏游標 | Ice `AppState.swift:80-81`；Thaw `AppDelegate.swift:73`；Frost `CursorConcealment.swift:4-31` |
| `CGSGetProcessMenuBarWindowList` | 列出所有選單列 item window | Ice `Private.swift:101-108`；Thaw `Shims.swift:132` |
| `CGSGetWindowList`、`CGSGetOnScreenWindowList`、`CGSGetWindowCount`、`CGSGetOnScreenWindowCount` | window list 與數量 | Ice `Private.swift:83-122` |
| `CGSGetScreenRectForWindow` | 即時 window frame | Ice `Private.swift:124-129`；Thaw `Shims.swift:141` |
| `CGSGetWindowLevel` | window level | Thaw `Shims.swift:148` |
| `CGSGetActiveSpace`、`CGSCopySpacesForWindows`、`CGSSpaceGetType`、`CGSManagedDisplayGetCurrentSpace`、`CGSCopyManagedDisplaySpaces` | Space 判斷、全螢幕 Space（type 4）、profile 綁 Space | Ice `Private.swift:65-79`；Thaw `Shims.swift:73-96` |
| `CGSCopyActiveMenuBarDisplayIdentifier` | 作用中選單列所在的 display UUID | Thaw `Shims.swift:54-55`；SketchyBar 的 SLS 版 |
| `CGSEventIsAppUnresponsive`、`CGSEventSetAppIsUnresponsiveNotificationTimeout` | 判斷目標 app 是否卡住，避免對它送事件 | Ice `Private.swift:57-61`；Thaw `Shims.swift:59-66` |
| `CGSMoveWindow`、`CGSGetConnectionIDForPSN` | （macOS 27 分支新增宣告） | Thaw `MenuBarModel/.../Shims.swift:288-309` @ `feat/thaw-3` |
| `GetProcessForPID`（已 deprecated 的 Carbon，非私有） | PID → PSN，給 `CGSEventIsAppUnresponsive` 用 | Ice `Bridging.swift:262` |
| `CGSMainConnectionID` + `CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground", true)`（以 `dlsym(RTLD_DEFAULT)` 解析） | 合成 ⌘-drag 時讓背景中的自己能藏游標（⌘-click 會把前景交給目標 app） | Pelmet `Packages/PelmetEngine/Sources/PelmetEngine/ItemMover.swift:189-215` |
| `CGCursorIsVisible`（deprecated 公開 API，用 `dlsym` 避開警告） | 拖曳中檢查游標是否真的藏住（診斷用） | Pelmet `ItemMover.swift:220-229` |

## SkyLight（SLS*／SL*）

| 符號 | 用途 | 出處 |
|---|---|---|
| `SLWindowListCreateImageFromArray` | 擷取螢幕外 window（取代 obsoleted 的 `CGWindowListCreateImageFromArray`）；**每次呼叫漏一個小 dictionary** | Thaw `Shims.swift:173-205`；`docs/ARCHITECTURE.md` |
| `SLSCaptureWindowsContentsToRectWithOptions`、`SLSGetScreenRectForWindow` | 擷取別人的 item（alias） | SketchyBar `src/window.c:372-403` |
| `SLSGetSpaceMenuBarReveal`、`SLSGetRevealedMenuBarBounds`、`SLSGetMenuBarAutohideEnabled`、`SLSIsMenuBarVisibleOnSpace` | 選單列自動隱藏的狀態與 reveal 比例（macOS 27，Thaw 稱不需 entitlement） | Thaw `MenuBarModel/.../Shims.swift:96-150` @ `feat/thaw-3`；SketchyBar `src/display.c:240-250` |
| `SLSGetDisplayMenubarHeight` | 選單列高度 | SketchyBar `src/display.c:256` |
| `SLSNewWindowWithOpaqueShapeAndContext`、`SLSSetWindowTags`、`SLSOrderWindow`、`SLSTransaction*`、`SLSSpaceCreate`、`SLSSpaceSetAbsoluteLevel`、`SLSShowSpaces`、`SLSSpaceAddWindowsAndRemoveFromSpaces`、`SLSAddTrackingRect`、`SLSRegisterNotifyProc`、`SLSRequestNotificationsForWindows`… | 自己畫 bar、讓 window 出現在所有 Space、hover 追蹤、WindowServer 事件 | SketchyBar `src/misc/extern.h`（約 70 個，詳見 [SketchyBar](../projects/sketchybar.md)） |
| `SLSRemoveWindowsFromSpaces` | 把 window 從 SkyLight 特殊 space 撤出 | boring.notch（見 [notch-apps](../projects/notch-apps.md)） |

## MenuBarAgent／Menu extras（macOS 27）

| 符號 | 用途 | 出處 |
|---|---|---|
| `MenuBarClientCore.framework`：`MBAssessmentModeConfiguration -initWithAllowedSystemItems:allowedBundleIdentifiers:`、`MBAssessmentModeAssertion -activateWithConfiguration:completionHandler:`／`-invalidate` | 讓 MenuBarAgent 只顯示 allow-list 內的 app（真正隱藏） | Hidden `HBNativeVisibilityShim.m:23-80`；MenuBarHider `MenuBarAgentBridge.swift:38-114`。詳見 [menubar-agent-allow-list](menubar-agent-allow-list.md) |
| `MBSystemItemIdentifier`（0 battery … 8 primaryBentoBox） | allow-list 的系統 item 編號 | MenuBarHider `SystemItems.swift:3-7` |
| ApplicationServices：`CoreMenuExtraGetMenuExtra`、`CoreMenuExtraAddMenuExtra`、`CoreMenuExtraRemoveMenuExtra` | 卸載／重新載入 SystemUIServer 的 menu extra | MenuBarHider `SystemUIServerExtras.swift:11-78` |
| （未知）Bartender 27 版與 Thaw PlatformRuntimeKit 用來「不動游標移動 item」的 MenuBarAgent 介面 | 【未知】 | SaneBar `docs/NOTCH_MOVE_LIMITATION.md:77-82`；[Thaw](../projects/thaw.md) |
| 同上 `MBAssessmentMode*`，**縮小 `allowedSystemItems`** | 藏個別系統 icon（含 Control Center、Clock） | Pelmet `Packages/PelmetEngine/Sources/PelmetEngineObjC/MBAssessmentShim.m:11-131`；`Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:42-60`；`Packages/PelmetEngine/Sources/PelmetEngine/ConvergePlan.swift:79-88` |
| SystemUIPlugin.framework：`CoreMenuExtraGetMenuExtra`、`CoreMenuExtraAddMenuExtra`、`CoreMenuExtraRemoveMenuExtra` | 同上一組符號，Pelmet 從 `/System/Library/PrivateFrameworks/SystemUIPlugin.framework` 解析（MenuBarHider 從 ApplicationServices）；用來關掉 Apple 的 Time Machine icon、換成自己的替身 | Pelmet `Pelmet/Extras/AppleMenuExtras.swift:50-86` |
| SiriFoundation.framework：`SRFUserDefaultsController` `+sharedUserDefaultsController`、`-isStatusMenuVisible`、`-setStatusMenuVisible:` | 讀／切換系統設定裡的 Siri 選單列 icon（註解：與設定頁同一個呼叫；直接寫 defaults key 無效） | Pelmet `AppleMenuExtras.swift:88-115` |
| login.framework：`SACSwitchToLoginWindow`、`SACLockScreenImmediate`、`SACSwitchToUser(CFString)` | 自製快速使用者切換選單（系統的那個在 assertion 生效時被拿掉） | Pelmet `Pelmet/Extras/UserSwitching.swift:49-89` |
| MenuBarAgent 的 `«` overflow 按鈕：`AXButton`，description 取自 `MenuBarAgent.app/Contents/Resources/MenuBarCore.loctable` 的 `menuBar.showOverflowItemsAccessibilityLabel`／`menuBar.hideOverflowItemsAccessibilityLabel` | 找到並判斷 « 是否展開（只能用 HID 點擊切換） | Pelmet `Pelmet/App/OverflowToggle.swift:18-58` |

## CGEvent 未公開欄位

| 欄位 | 用途 | 出處 |
|---|---|---|
| `CGEventField(rawValue: 0x33)` | 事件的目標 window ID；WindowServer 依此路由 ⌘-drag 與點擊（≤ 26 有效，27 無效） | Ice `MenuBarItemManager.swift:1552`；Frost `ItemMover.swift:681-683`；SketchyBar 讀取 `src/misc/helpers.h:557-559` |

搭配使用的公開欄位：`mouseEventWindowUnderMousePointer`、`mouseEventWindowUnderMousePointerThatCanHandleThisEvent`、`eventTargetUnixProcessID`、
`eventSourceUserData`、`mouseEventClickState`。詳見 [menu-bar-item-moving](menu-bar-item-moving.md)。

[Pelmet](../projects/pelmet.md)（只支援 27）完全不用未公開事件欄位；只用公開的 `eventSourceUserData` 標記自己的合成事件（固定值 "PLMT"），讓自己的
active event tap 放行、吞掉實體輸入（`Packages/PelmetEngine/Sources/PelmetEngine/ItemMover.swift:177-179`, `:290-293`）。

## 未公開的 defaults key 與通知

| Key／通知 | 用途 | 出處 |
|---|---|---|
| `NSStatusItem Preferred Position <autosaveName>`（app domain；SaneBar 另寫 ByHost `.GlobalPreferences`） | status item 的位置；≤ 26 決定新 item 落點；27 無效 | Ice `StatusItemDefaults.swift:44-57`；MenubarHide `MenuBarArrangement.swift`；SaneBar `StatusBarPositionDefaultsStore.swift:26-46` |
| `NSStatusItem Visible <autosaveName>`、`NSStatusItem VisibleCC <autosaveName>`（macOS 26 新增） | 使用者是否移除了該 item | Ice `StatusItemDefaults.swift:55-57`；SaneBar 每次啟動清除（`StatusBarController.swift:100-102`） |
| `NSStatusItemSpacing`、`NSStatusItemSelectionPadding`（全域） | item 間距；需重啟 app／登出生效 | Ice `MenuBarItemSpacingManager.swift:14-20`；MenubarHide `MenuBarSpacing.swift`；SaneBar `MenuBarSpacingService.swift:24-37` |
| `_HIHideMenuBar`（全域） | 使用者是否設定自動隱藏選單列 | Ice `MenuBarManager.swift:109` |
| Distributed notification `com.apple.accessibility.api` | Accessibility 授權變更時即時得知 | Frost `PermissionsService.swift:52-62`；SaneBar `AccessibilityService.swift:32` |
| `AppleInterfaceMenuBarHidingChangedNotification` | 選單列自動隱藏設定改變 | SketchyBar `src/workspace.m:141-144` |
| `_AXUIElementGetWindow` | AX 元素 → window ID；對 status item 回 −25201（Tahoe） | SaneBar `docs/NOTCH_MOVE_LIMITATION.md:35-45` |
| `com.apple.MenuBarAgent`（any-host）`TrailingItemPreferredPositions`（tag → 位置值的字典） | macOS 27 的 trailing item 順序表；只在 agent 重啟時讀、只影響新註冊 item，對 live item 無效 | Pelmet `Packages/PelmetEngine/Sources/PelmetEngine/AgentPositions.swift:1-26`；`AgentPositionStore.swift:52-63`；`docs/CORE-SETS.md:23` |
| `com.apple.systemuiserver` 的 `menuExtras`（已載入的 `.menu` 路徑陣列） | 幫沒有 AX title 的 SystemUIServer extra（Time Machine）命名 | Pelmet `ItemEnumerator.swift:287-291` |
| `NSStatusItemSpacing`／`NSStatusItemSelectionPadding`（**current host**，`kCFPreferencesAnyApplication`）＋ 對 MenuBarAgent 送 `SIGTERM` | 27 上改間距後讓 Clock、Control Center 等系統 icon 立即套用（agent 約 1 s 內自動重生） | Pelmet `Pelmet/App/IconSpacingApplier.swift:17-49` |
| `com.apple.symbolichotkeys` 的 `AppleSymbolicHotKeys` | 偵測使用者選的快捷鍵是否已被系統占用 | Pelmet `Pelmet/Settings/ShortcutRecorder.swift:214-219` |
| unified log：`process == "donotdisturbd"` 的狀態訊息（`log stream` 子程序） | 讀目前的 Focus 模式（沒有公開 API；DB 要 Full Disk Access） | Pelmet `Pelmet/Extras/FocusStatus.swift:1-9`, `:39-40` |

注意：`kAXExtrasMenuBarAttribute`（`"AXExtrasMenuBar"`）是**公開**常數（`AXAttributeConstants.h`），不是私有 API。

## 對 Whisky 的建議

- 把私有能力集中在一個 `PlatformCapabilities` 模組，每項有探測函式與降級策略；啟動時記錄可用性到診斷 log。
- 優先序：公開 API（AX、`CGWindowListCopyWindowInfo`、SCK、`NSScreen`）→ 私有但只讀（SLS menu bar 狀態）→ 私有且改變系統狀態
  （allow-list、CoreMenuExtra）。後者要有保底的「全部恢復」。
- Bartender 的逆向只用來理解「用了哪些機制」，依本 repo 的乾淨室規則；Thaw 的 PlatformRuntimeKit 授權明文禁止逆向，完全不碰。
