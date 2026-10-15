---
title: Thaw
type: project
tags: [open-source, swift, appkit, gpl-3.0, menu-bar-manager, ice-fork, private-api, macos-26, macos-27]
sources:
  - raw/github/repos/thaw-app__Thaw
  - https://github.com/thaw-app/Thaw
  - https://github.com/thaw-app/Thaw/tree/feat/thaw-3
  - https://github.com/thaw-app/prk-bin
  - https://github.com/thaw-app/Thaw/releases/tag/3.0.0-alpha.8
updated: 2026-10-12
---

# Thaw

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [thaw-app/Thaw](https://github.com/thaw-app/Thaw)（預設分支 `development`） |
| 授權 | **GPL-3.0**；macOS 27 分支另加 GPL §7 linking exception，連結閉源的 PlatformRuntimeKit |
| 語言 | Swift（AppKit + SwiftUI），約 8 萬行 |
| Stars | 約 12.0k（2026-10-12；2026-01-29 才建立） |
| 活躍度 | 非常活躍：2026-10-12 仍有 commit；3.0.0-beta.2（10-07）、3.0.0-alpha.8（10-11，僅 macOS 27） |
| 支援的 macOS | Deployment target 26.0（`Thaw.xcodeproj/project.pbxproj:618`）；README 宣稱支援 26 與 27 |
| macOS 26 Tahoe | 是主要目標，本 clone 的 `development` 分支就是 Tahoe 實作 |
| macOS 27 | 在 `feat/thaw-3` 分支（3.0.0-alpha），隱藏核心是**閉源 binary** |

Thaw 是 [Ice](ice.md) 的維護版 fork（`docs/ARCHITECTURE.md:9-10`；檔頭仍保留「Copyright (Ice) © 2023–2025 Jordan Baird」）。
README 說原專案看似停擺，Thaw 要延續它並跟上新版 macOS。功能遠超 Ice：groups、spacer、profiles（綁 display／Space／Focus）、
triggers（電量、Wi-Fi、Focus、腳本…）、zen mode、`thaw://` URL scheme、Raycast 擴充、20 種語言、OpenSSF 等供應鏈認證。

本頁 file:line 相對於 `raw/github/repos/thaw-app__Thaw/`（commit `a4cd824`，`development` 分支）；macOS 27 部分引用
GitHub 上 `feat/thaw-3` 分支 commit `96d59a2`（未 clone，只用 `gh api` 讀了幾個檔）。

## 架構

`docs/ARCHITECTURE.md` 的元件圖：

| 元件 | 角色 |
|---|---|
| `Thaw/`（主程式） | MenuBar（ItemManager、layout、Thaw Bar）、Events／Hotkeys、Triggers、Settings + `thaw://`、Permissions、Sparkle |
| `MenuBarItemService.xpc` | **另一個 process** 做 AX 掃描，把每個 item window 對回真正建立它的 app PID（Accessibility 呼叫會 block，放 XPC 才不卡 UI） |
| `MenuBarCaptureService.xpc` | **可回收的 process** 跑 SkyLight 螢幕外擷取；每次呼叫會漏一點記憶體，擷取次數到預算就自殺重開 |
| `Shared/` | 主程式與 XPC 共用的 bridging、WindowInfo、AX helper |
| `ThawCtl/` | 小型 CLI |

`MenuBarItemManager` 被拆成 28 個 extension 檔（`Thaw/MenuBar/MenuBarItems/MenuBarItemManager/`），包含 move
transaction、circuit breaker、notch overflow、profile apply、saved layout apply、triggers 等。

SPM 依賴：Sparkle、AXSwift（後改 fork AXSwift6）、CompactSlider、Ifrit、LaunchAtLogin-Modern（`docs/ARCHITECTURE.md`）；
macOS 27 分支再加 swift-async-algorithms、swift-collections、swift-subprocess 與 `prk-bin`（閉源）。

## 關鍵機制（附 file:line）

### 隱藏（macOS 26）：沿用 10,000 pt 分隔線，再補 spacer

- 長度只有 `variableLength` 與 `10000`（`Thaw/MenuBar/ControlItem/ControlItem.swift:31-54`）。
- 新建 status item 先給長度 1，強迫 AppKit 產生有 `CGWindowID` 的 window，再設成目標長度（`:56-58`）。
- 超寬螢幕（> 5120 pt）時，額外建立看不見的 spacer status item（autosave name `<id>.Spacer.<n>`，按鈕 alpha 0），
  每個也是 10,000 pt，數量 = ⌈(最寬螢幕 × 3 − 10000) / 10000⌉（`:695-741`）。原因：Tahoe 會把 10,000 夾到約 5,016 pt
  （見 [MenubarHide](menubarhide.md) 與 [Frost](frost.md) 的實測）。

### 列舉與「真正擁有者」解析（Tahoe 的關鍵修正）

- window list 仍用私有 `CGSGetProcessMenuBarWindowList` 等（宣告在 `Shared/Bridging/Shims.swift:100-155`）。
- **macOS 26 起所有 item window 的 `kCGWindowOwnerPID` 都是 Control Center**，所以 Thaw 在 XPC 裡建 `SourcePIDCache`
  （`MenuBarItemService/SourcePIDCache.swift:14-19` 的註解寫得很清楚）：
  1. 對每個 running app 取 `AXExtrasMenuBar`（`Shared/Utilities/AXHelpers.swift:26-28`），列出 children 的 AX frame。
  2. 和 menu bar item window 的中心點比對，距離 ≤ 1 pt 就認定是那個 app（`SourcePIDCache.swift:506-567`）。
  3. 若 window title 剛好等於某個 running app 的 bundle ID，直接歸給它（`:569-600`）。
  4. 有些 widget（例如 Little Snitch）在 AX 層被 Control Center 代管、沒有 `AXExtrasMenuBar`；它們會另外發一個
     「title 是 bundle ID、寬度和圖示相同」的 marker window，`MarkerPairResolver` 用寬度一對一配對來還原 PID
     （`Shared/Utilities/MarkerPairResolver.swift:13-60`）。
  5. 找不到的 window 進 negative cache，避免一直重掃（`SourcePIDCache.swift:451-456`）。
- AX 掃描會被慢的 app 拖住，所以有 per-app messaging timeout 與「慢 probe」紀錄（`:514-525`）。

詳見 [menu-bar-item-enumeration](../concepts/menu-bar-item-enumeration.md)。

### 移動

- 仍是合成 ⌘-drag，但策略變多：`teleport`、`faithfulDrag`（真的送出內插的 `leftMouseDragged`）、`parkedTeleport`、
  `crossNotchTeleport`、`sourceAnchoredTeleport`（`MenuBarItemManager+MoveGeometry.swift:82-99`；faithfulDrag 的步驟產生在
  `MenuBarItemManager+MoveEvents.swift:33-49`）。
- 事件要送給誰：Tahoe 上要送給 **window 擁有者（Control Center）**，不是建立 item 的 app，否則拖不動
  （`MenuBarItemManager+EventHelpers.swift:387-400`；開關在 `MenuBarItem.swift:55-62`）。
- 防呆：目標 PID 已死（`kill(pid,0)` 回 `ESRCH`）就不送，否則 tap 會建出無效 port 白等 3.5 秒；目標 app 卡住
  （`CGSEventIsAppUnresponsive`）也跳過（`MenuBarItemManager+MoveEvents.swift:166-181`）。
- 游標：只在目標點在螢幕上時 warp，因為 `CGWarpMouseCursorPosition` 會把螢幕外座標夾到 Apple menu 下面，造成誤點（`:212-240`）。
- 有 `MoveCircuitBreaker`、`MenuBarItemFailureLedger` 之類的保護，避免某個 item 連續失敗拖垮整個 layout 套用。

詳見 [menu-bar-item-moving](../concepts/menu-bar-item-moving.md)。

### 點擊：先 AXPress，再合成事件

`AXItemActivator` 用 `AXPress` 開 item 的 menu，因為合成滑鼠事件會漏進系統手勢處理、讓 Wi-Fi 之類的 item 出錯
（`Thaw/MenuBar/MenuBarItems/AXItemActivator.swift:7-12`）；AX frame 和 window bounds 差超過 10 pt 就不信任（`:21-22`），
失敗才退回合成點擊（`MenuBarItemManager+Click.swift:224-285`）。Electron／Chromium 的 tray item 只吃 AXPress
（`Shared/Utilities/AXHelpers.swift:72-83`）。Thaw Bar 的點擊同 Ice，走 `temporarilyShow`（搬到可見區再點，之後搬回）
（`MenuBarItemManager+TemporaryShow.swift:417`）。

### 擷取：可見用 ScreenCaptureKit，隱藏用 SkyLight

- `CGWindowListCreateImageFromArray` 在 deployment target 26 已不可用，改用 `dlsym` 取 SkyLight 的
  `SLWindowListCreateImageFromArray`（`Shared/Bridging/Shims.swift:173-205`；`Bridging.swift:516-561`），用來擷取
  螢幕外（Hidden／Always Hidden）的 item。
- 這個私有函式每次成功都會在呼叫端漏一個小 dictionary，所以放進 `MenuBarCaptureService` XPC，跑到預算就結束
  process 回收記憶體；Always Hidden 限 1 fps（`docs/ARCHITECTURE.md` 的 MenuBarCaptureService 段）。
- 可見區 item 用 ScreenCaptureKit（`Bridging.swift:655-700`，`SCShareableContent` 快照 150 ms 快取）。
- 沒有 Screen Recording 時，改畫擁有 app 的 icon（README「Transparency」段）。

詳見 [menu-bar-item-imaging](../concepts/menu-bar-item-imaging.md)。

### 瀏海與多螢幕

- `rebalanceNotchOverflowIfNeeded` 計算瀏海右側到 Control Center 左緣之間的可用寬度，扣掉不能動的 item（時鐘、
  BentoBox）與暫時性指示器，決定把哪些 visible item 移到 hidden，避免被瀏海吃掉
  （`MenuBarItemManager+NotchOverflow.swift:13-107`）。
- Thaw Bar 面板 level `.mainMenu + 1`，`[.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace, .stationary]`
  （`Thaw/MenuBar/IceBar/IceBar.swift:56-57`）；可設定只在有瀏海的螢幕用 Thaw Bar（`Thaw/Settings/Models/Profile.swift:39`）。
- 作用中選單列所在的 display 用 `CGSCopyActiveMenuBarDisplayIdentifier`（`Shims.swift:54-55`）。

詳見 [notch-and-displays](../concepts/notch-and-displays.md)。

### Profiles、triggers、hotkey

- Profile 可綁 display UUID、Space key（`CGSSpaceID` 會在登出後重新編號，所以另存持久 key）、Focus filter
  （`Thaw/Settings/Models/Profile.swift:18-27`；`Shared/Bridging/Bridging.swift:233-237`）。
- Trigger 條件：前景 app、網路、VPN、Wi-Fi、藍牙、音訊輸出、外接螢幕、時間表、位置、Focus、Energy Mode、熱壓力、
  相機／麥克風使用中、腳本結果、圖示變化或閃爍（README；`Thaw/Settings/Models/MenuBarItemTrigger.swift`）。
- Hotkey：Carbon `InstallEventHandler` + `RegisterEventHotKey`（`Thaw/Hotkeys/HotkeyRegistry.swift:110`, `:179`）。
- 啟動時設 `SetsCursorInBackground`（`Thaw/Main/AppDelegate.swift:73`）。

### macOS 27（`feat/thaw-3` 分支，未 clone）

- 新增 `MenuBarModel` SPM package，`MenuBarBackend` protocol 的註解說唯一實作是 `RuntimeMenuBarBackend`，
  「uses assertion-backed visibility and assignment-based cache reconstruction」，並且要把 app 和
  **PlatformRuntimeKit** 的具體型別隔開（`MenuBarModel/Sources/MenuBarModel/MenuBarBackend.swift:10-17` @ `96d59a2`）。
- **PlatformRuntimeKit 是閉源 binary**（`thaw-app/prk-bin`，`binaryTarget`，platforms `.macOS(.v27)`）。其 README 寫明它是
  「the closed component that hides menu bar items on macOS 27」，授權條款**禁止逆向工程與在 Thaw 以外重用**，每個版本
  發布一年後才轉為 GPL-3.0。Thaw repo 為此加了 `LICENSE-EXCEPTION`（GPL §7 額外許可）。
- 分支內公開可見的部分：
  - 用 `dlsym` 讀 SkyLight 的 `SLSGetSpaceMenuBarReveal`、`SLSGetRevealedMenuBarBounds`、`SLSGetMenuBarAutohideEnabled`、
    `SLSIsMenuBarVisibleOnSpace`（`MenuBarModel/Sources/MenuBarModel/Shims.swift` 約 96-150 行）。註解說這些是
    「disassembling SkyLight on macOS 27」得到的簽名，而且不需要 entitlement；同一段註解另稱「MenuBarAgent's menu-bar
    services … all require an unobtainable com.apple.private.* entitlement」——這和 [Hidden Bar](hidden-bar.md)、
    [MenuBarHider](menubarhider.md) 直接呼叫 `MBAssessmentModeAssertion` 成功的事實相矛盾，【推論】指的是其他服務。
  - `MenuBarItemPressing`：用 AX 元素 press，失敗才退回「process-targeted click」，不進全域 HID 流
    （`MenuBarItemPressing.swift`）。
  - `MenuBarItemDragging`：⌘-drag 改為送給「hosting the menu bar 的 process」（也就是 MenuBarAgent），不移動使用者游標
    （`MenuBarItemDragging.swift`）。
  - `MenuBarSectionControlling` 提到「a held assertion suppresses Notification Center activation」，所以有「Clock activation
    bridge」暫時解除限制讓點時鐘能開通知中心（`MenuBarSectionControlling.swift:10-20`）——和 MenuBarHider 遇到的副作用相同，
    【推論】Thaw 的 assertion 就是 assessment mode 的 allow-list。
- 3.0.0-alpha.8 release notes：Layout 有「Hiding method」選擇 Native／Standard／Everything；Native 保留 Live Activities、
  相機指示器與 Apple 自家 item；Everything 連 Clock、Control Center、Siri 都藏。

## 權限

| 權限 | 必要 | 用途（`Thaw/Permissions/Permission.swift`） |
|---|---|---|
| Accessibility | 是（`:123-146`） | 偵測 item 與位置、移動、代替使用者點擊；XPC 也要（`SourcePIDCache.swift:477-481`） |
| Screen Recording | 否（`:153-174`） | 即時 item 預覽、取樣選單列顏色做 tint、搜尋時的圖像 |

3.0.0-alpha.8 另有實驗功能「Continue without Accessibility」：只能整個 app 為單位隱藏。詳見 [permissions](../concepts/permissions.md)。

## 已知問題

- `FREQUENT_ISSUES.md:244-250`：iStats 會連帶被藏；時間／溫度這類 live-text item 會落在附近而非精確位置；Flux 完全看不到。
- `FREQUENT_ISSUES.md:199-234`：Screen Recording 重開機後一直重新要求（#683）；Mission Control／切 Space 造成 layout
  風暴與閃爍（#718）；iPhone 鏡像的 Live Activities 干擾 layout（#722, #556）。
- 選單列設為自動隱藏時無法排列（`FREQUENT_ISSUES.md:79`）。
- macOS 27 版仍是 alpha，功能凍結修 bug 中；核心不開源。

## 對 Whisky 的參考價值

- **Tahoe 的正確做法教科書**：owner PID 必須用 AX `AXExtrasMenuBar` 反查、事件要送給 window owner、擷取要分可見／
  隱藏兩條路、AX 呼叫要隔離在別的 process 並有 timeout 與 negative cache。這些是「行為與 API」層級的知識，可以用自己的
  程式碼重寫。
- **功能清單參考**：profiles 綁 display／Space／Focus、triggers、搜尋、URL scheme——和 Bartender 6 的功能集最接近。
- **macOS 27 不能參考**：核心在閉源 PlatformRuntimeKit，授權明文禁止逆向。Whisky 要自己從 Apple 的行為與公開專案
  （[MenuBarHider](menubarhider.md)、[Hidden Bar](hidden-bar.md)、[Frost](frost.md)）推導。

## 授權注意

- 主程式 GPL-3.0，而且大量檔案是 Ice 的衍生作品——不可複製。
- PlatformRuntimeKit：PlatformRuntimeKit License 1.0，**禁止逆向工程與在 Thaw 外重用**一年。Whisky 不得拆解
  `prk-bin` 的 xcframework，也不要依它的行為做 clean-room 以外的模仿；乾淨室規則同樣適用。
