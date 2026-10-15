---
title: Bartender 6 機制
type: bartender
tags: [reverse-engineering, menu-bar, cgs, cgevent, screencapture, tahoe]
sources:
  - raw/bartender/rea/notes-main-hiding.md
  - raw/bartender/rea/notes-main-enumeration.md
  - raw/bartender/rea/notes-main-moving.md
  - raw/bartender/rea/notes-main-bar-clicking.md
  - raw/bartender/rea/notes-main-styling.md
  - raw/bartender/rea/notes-main-update-detection.md
  - raw/bartender/rea/notes-main-features.md
  - raw/bartender/rea/notes-xpc-service.md
updated: 2026-10-12
---

# Bartender 6 機制

逐一描述 6.6.2 的行為與用到的 API。方法與證據規則見
[notes-main-method.md](../../raw/bartender/rea/notes-main-method.md)。位址為 arm64 slice VM 位址（base 0x100000000）。

## 1. 隱藏（HIDING）

- 【觀察】Bartender 建立三個**自己的 NSStatusItem 當分隔線**：HISItem（hidden）、RHSItem（really/always-hidden）、
  EItem（end），autosaveName 分別為 `HISItem`/`RHSItem`/`EItem`，建立在初始化函式 0x1004717f4。
  （notes-main-hiding.md H1）
- 【觀察】隱藏/顯示切換在 0x100478410：對這三個項目呼叫 `setLength:`。隱藏時把 HIS 與 RHS 的長度設成 **10000.0**
  （常數 0x40C3880000000000），把它們左邊的所有項目推出螢幕左緣；顯示時改回 **-1（variable）/ 0 / 1 / 0.001**。
  EItem 在尾端用來量測。（notes-main-hiding.md H2）→ 這是 Ice/Dozer 同類的「展開分隔項目」手法
  （見 [concepts/status-item-hiding.md](../concepts/status-item-hiding.md)），但 Bartender 用三個控制項目切出
  shown / hidden / always-hidden 三段。
- 【觀察】項目的左右順序靠私有鍵 `NSStatusItem Preferred Position <autosaveName>`（擴充函式 0x1005121f4 以
  `setDouble:forKey:` 寫入）：HIS≈20000.5、RHS≈30000.5、EItem=60000（值越大越靠左）。（notes-main-hiding.md H1）
- 【觀察】「非作用中螢幕全部隱藏」另走 0x100476ff8：用私有 `+[NSStatusBar _statusItemWithLength:withPriority:]`/
  `_itemInStatusBar:withLength:withPriority:systemInsertOrder:`（priority 0x7FFFFFFE）建立 length 10000、
  autosaveName `hideSecondaryMonitorItems`、Preferred Position -100 的超長項目。（notes-main-hiding.md H3）
- 【推論】螢幕夠寬時（設定 `IfScreenIsBiggerThanDontHide`）改用 -1/0.001 讓項目全顯示，否則 10000 隱藏。
- 【觀察】`Item-0`…`Item-19`（`NSStatusItem Preferred Position Item-N`）**不是** Bartender 自己的項目，而是 AppKit 給
  未設 autosaveName 的項目的預設名；Bartender 只在啟動時清掉全域網域中這些殘留鍵（0x10060d158 以私有
  `CFPreferencesSetAppValue(..., kCFPreferencesAnyApplication)`）。（notes-main-hiding.md H5）
- 【觀察】其他空白/間隔項目：Top Shelf 的 `TS-SPACER`（0x10024ad1c）、`Bartender Gap Item`（0x10042bf00）、
  Sub-bar 群組項目、SFU 假佔位（UpdateStatusItem）。（notes-main-hiding.md H4）
- 【未知】`THSItem` 的用途；[+0x250]/[+0x1c0] 旗標語意。

## 2. 列舉與擁有者辨識（ENUMERATION）

- 【觀察】視窗來源：私有 `CGSGetProcessMenuBarWindowList(connection, pid=0, max, buf, &count)` 取所有程序的選單列視窗 ID，
  配 `CGSGetOnScreenWindowList`/`CGSGetOnScreenWindowCount` 判斷在不在畫面上（Swift 包裝 0x1005ce9b4），
  `CGWindowListCreateDescriptionFromArray` 取描述，`CGSGetScreenRectForWindow` 取 frame。（notes-main-enumeration.md E1/E2）
- 【觀察】舊/退路 `GetMenuBarWindowInfos`（0x1001fbae8）過濾 `kCGWindowLayer == 25`（kCGStatusWindowLevel），
  排除空標題與標題 "System Status Item Clone"；owner 為 "Focus" 的 layer-101 視窗也收。nil 時退回
  `CGWindowListCopyWindowInfo(kCGWindowListOptionAll)`。（notes-main-enumeration.md E2）
- 【觀察】識別字 windowKeyName = `<bundleID>-<視窗標題>`，視窗標題即 NSStatusItem autosaveName（無則 `Item-N`）。
  系統項目例：`com.apple.controlcenter-WiFi`、`com.apple.controlcenter-BentoBox`、`com.apple.Spotlight-Item-0`、
  `com.apple.systemuiserver-Siri`、`com.apple.dock-Menubar`（strings；notes-main-enumeration.md E3）。
- 【觀察】macOS 26（Tahoe）身分配對（`TahoeAccessibilityMatcherXPC`，runMatchingLoop 0x10056bd38）：
  透過 XPC 向 helper 要 `fetchMenuBarSnapshots(pids)`，helper 逐 PID 讀第 2 個 AXMenuBar（extras）子元素的 frame
  （見 [notes-xpc-service.md](../../raw/bartender/rea/notes-xpc-service.md)），主程式把穩定後的視窗 frame
  （`getStableBounds` 0x100578230 反覆 `CGSGetScreenRectForWindow` 直到 `CGRectEqualToRect`）對應到 PID。
  有慢配對延遲、per-window 失敗計數、circuit breaker（"Circuit breaker tripped after %d failures"）。（E4）
- 【觀察】`TahoeImageIndexer`（0x1004bb310/0x1004bde18）：把項目圖示用 `CGBitmapContextCreate`(8bpc, DeviceGray) +
  `CGContextSetInterpolationQuality(high)` 縮成小灰階位圖 → 感知雜湊，存 UserDefaults，供重開機後找回身分
  （"found an image based match for an item"）。不開 indexing 時所有非 Apple 項目都叫 "Menu Item"。（E5）
- 【觀察】`CGSEventIsAppUnresponsive`（0x1001fb004）跳過無回應 App。
- 【未知】Tahoe 上 `kCGWindowOwnerPID` 實際回傳哪個程序、frame 比對容差。

## 3. 移動（MOVING）

- 【觀察】移動 = 合成 **⌘+左鍵按下（在項目上）→ 放開（在目的地）** 的 CGEvent，flags = 0x100000（command），
  並在事件填 window-under-pointer 欄位（91/92）與未公開欄位 51 = 目標視窗 ID，`sourceUserData`(42) 填魔術標記
  （如 0x414C4558 'ALEX'、0x539、0x53C）。事件來源 `CGEventSourceCreate` 後設
  `CGEventSourceSetLocalEventsFilterDuringSuppressionState` 與 `…SuppressionInterval`（舊引擎用 0.08s，新引擎 0）。
  （notes-main-moving.md M1/M2）
- 【觀察】投遞用 `CGEventPost(kCGSessionEventTap)` 或 `CGEventPostToPid(pid)`。新引擎可「post 後用 listen-only tap 確認」
  （`post(_:via:confirmVia:timeout:)` 0x1004094f0；`CGEventTapCreate`/`CGEventTapCreateForPid` with options=1 listenOnly）。
- 【觀察】舊 `MoveHelper` 的 scrombleEvent（0x1003c7ca8）：先用 `CGEventCreate(NULL)` 造 null 事件、
  `CGEventTapCreateForPid` + `CGEventTapCreate`（listen-only），`CGEventPostToPid` 送 null，待 PID tap 收到後才送真事件，
  再由 session tap 確認「同一視窗」收到（否則重試，最後 "posting directly"）。
- 【觀察】期間阻擋使用者輸入：session 層 **active** event tap（0x1003c6e08/0x10040c0f8/0x1004075b0）丟掉使用者的
  點擊/滾輪/移動（"prevent"/"throw away" tap），可由設定 `supressClicksDuringMoves` 控制；`ClickSuppressionController`
  以 refCount 管理。被系統停用時重新啟用。
- 【觀察】游標：`CGDisplayHideCursor` → 移動 → `CGWarpMouseCursorPosition` 回原位 → `CGDisplayShowCursor`；
  `CursorVisibilityManager.hideDepth` 支援巢狀。
- 【觀察】前置條件檢查：滑鼠按著、螢幕 Zoom、Mission Control/Space 切換/Launchpad/Spotlight（0x1003ca908 用
  `CGWindowListCopyWindowInfo` 偵測）、視窗在失敗清單時不移動。特例 App：1Password、Bitwarden、Witch、Little Snitch。
- 【觀察】排列層（0x1005474e4）記錄 "Arranging %@ with %d moves"，先正規化控制項目順序，逐項 "Moving %@ to %@ section,
  right of %@"，失敗計數到上限標記 unmovable（"marked unmovable after %d failures"）；阻擋原因字串見 notes-main-moving.md M3。
- 【觀察】錯誤型別 `MoveError`：appleMenu/notchObscured/invalidEventSource/eventCreationFailed/invalidTarget/moveFailed/
  timeout/mouseDownActive/itemUnmovable。
- 【推論】新舊引擎由設定 `eventTapMoves`/`UseEventTapMoves` 切換。

## 4. Bartender Bar、擷取與點擊（BAR / CAPTURE / CLICKING）

- 【觀察】Bar = `BartenderBarPanel`(NSPanel) + NSCollectionView；每格顯示被隱藏項目視窗的**截圖**。
  （notes-main-bar-clicking.md B1）
- 【觀察】擷取用 `CGWindowListCreateImageFromArray(rect, [windowID], option)` 或 `CGWindowListCreateImage`
  （option 1 或 9 = BoundsIgnoreFraming|BestResolution），`CGImageCreateWithImageInRect` 裁切；Space 切換中不截。
  結果快取在 `MenuBarImageCache`/`CachedImageData`，由 `MenuItemImageHelper` 背景更新、cell 計時器刷新。
- 【觀察】`WindowStreamer` 類別持有 `SCStream` 欄位，但二進位沒有建立 SCStream 的符號（只匯入 `SCShareableContent`
  與 `SCStreamFrameInfo*` 常數）。【推論】6.6.2 實際擷取走 CGWindowList；SCStream 疑為未啟用。
- 【觀察】`CGRequestScreenCaptureAccess`（0x1005ce728）觸發螢幕錄製授權。
- 【觀察】在 Bar 點擊 → `ShowItem`（0x100483634）：先確保真項目在作用中螢幕（必要時用分隔線長度/Move 把它移進可見區），
  輪詢 `CGSGetScreenRectForWindow` 確認到位（"Window %@ says its on screen to just clicking it"），再用 `MenuItemClicker`
  （0x100381398）合成點擊：`CGEventCreateMouseEvent` down/up + `CGEventSetFlags`，`CGEventPost(session)` 或
  `CGEventPostToPid`，點前 `CGDisplayHideCursor`、點後 `CGWarpMouseCursorPosition`+`CGDisplayShowCursor`。
  Zoom 開啟時不顯示。失敗記 "MenuItemClicker failed for %@"。（notes-main-bar-clicking.md B2/B3）
- 【觀察】未見用 `AXUIElementPerformAction`(AXPress) 點選單列項目（AX 的 perform action 只出現在別處 0x1006eb6b0）。
- 【未知】SCStream 是否在 live hover preview 等情境啟用；session tap 點擊如何保證落在正確項目。

## 5. 外觀（STYLING）

- 【觀察】不改系統選單列，而是放自己的無邊框視窗畫色彩/漸層/玻璃/圓角/邊框：`MenuBarCoverWindow`、
  `MenuBarRoundingManager`（log "menuBarCoverWindow level=%d"、"desktopCoverWindow created frame=%@ level=%d"）、
  `TahoeMenuBarView`(+`DesktopCoverView`,`MaterialViewModel`)。（notes-main-styling.md S1/S2）
- 【觀察】視窗層級用 25/26/1/3/17/101；排列時以一個 level 26 的 cover window 蓋住選單列避免閃爍
  （"PerformWithCoverWindow"，設定 `Bartender4.dontUseCoverWindow` 可關）。
- 【觀察】`CGSSetWindowTags`/`CGSClearWindowTags`（0x1001fcef4）只用於一個 "DesktopWallpaperHelperWindow"：
  設 tag bit 1（64-bit tag 空間）。bit 語意【未知】。
- 【觀察】桌布截圖（0x10053bc8c，找桌布視窗後 `CGWindowListCreateImageFromArray` 取選單列高度那條）供圓角延伸；
  選單列取色 `ModernColorSampler`/`LegacyColorSampler`，存 `com.surteesstudios.Bartender4Color`。
- 【觀察】每 Space/螢幕設定 `MenuBarColoringManager.SpaceSettings`（鍵前綴 "Default-Space-Display-"），
  以 `CGSCopySpacesForWindows`/`CGSGetActiveSpace`/`CGSCopyManagedDisplaySpaces` 判斷所屬 Space。
- 【觀察】Tahoe 限制：若系統開「顯示選單列背景/減少透明度」（`__AXInterfaceGetReduceTransparencyEnabled` 0x1001fc07c）
  或啟用自動隱藏選單列，自訂樣式停用。

## 6. 更新偵測（SHOW FOR UPDATES）

- 【觀察】每個監看項目有基準圖（`SFUItem.comparisonImage`）；差異計算 0x1005d093c：兩圖都縮到**高度 14px**（保持比例，
  `NSBitmapImageRep` 重繪），逐像素比 R/G/B/A 得差異百分比，和使用者門檻 `ImageComparisionPercentage`（夾在 0–100；
  未設時預設 25.5）比較，超過即「有更新」。另有 bytes 完全相等比較與 CIColorInvert（深淺色）處理。（notes-main-update-detection.md U1）
- 【觀察】比較模式 `SFUMatchComparisonType`："until they match" / "until it does not match"；也支援週期腳本（逾時 10s）。
- 【觀察】取到新圖時 `MenuItemImageHelper` post `NewImageForMenuBarItem`，`TriggerManager` 的影像觸發器接收並比對
  （"images different"）；命中後 `UpdateStatusItem` 以 hideTimer 暫時顯示，選單追蹤中不隱藏。
- 【推論】主檢查計時器：AC 2 秒、電池且開 `ReduceUpdateCheckFrequencyWhenOnBattery` 時 4 秒（0x100477b5c）。
- 【未知】差異是像素計數比還是色差總和、單像素容差。

## 7. Tahoe 專屬路徑小結

- 【觀察】macOS 26 上視窗資訊拿不到真正擁有者（連自家控制項目都以 `com.apple.controlcenter-*` 出現，strings 111408 附近），
  所以身分改走 XPC+AX+影像雜湊索引；要開 indexing 才有 Hotkeys/Presets/Triggers，否則項目只叫 "Menu Item" 且重開機後失去位置。
  （notes-main-enumeration.md E4/E5、notes-main-features.md）
- 【觀察】偵測 WindowServer 尖峰時暫停（`WindowServerMonitorModel`；"Bartender is temporarily pausing to prevent system lag on Tahoe"）。

## 8. Triggers / Profiles / Autohide / Hotkeys / Spaces / Notch / Widgets / Persistence

細節見 [notes-main-features.md](../../raw/bartender/rea/notes-main-features.md)。要點：
- 【觀察】Triggers：Timer/Location/WiFi/Script/Image/Battery/Focus 條件 → 套 Preset 或顯示項目（`TriggerManager`）。
- 【觀察】Profiles/Presets：四區配置（`MenuBarLayoutModel`），`LastKnownProfile` 記於 UserDefaults；Manual 與 Live 兩種佈局模式。
- 【觀察】顯示/再隱藏：hover(`MouseInMenuBarView`)/click/scroll + 一堆 defaults；監看 HIToolbox 選單追蹤通知；
  `CGEventSourceSecondsSinceLastEventType` 量空閒。
- 【觀察】熱鍵：`CustomHotKeyManager` 用 DDHotKey(Carbon `RegisterEventHotKey`)，另連 KeyboardShortcuts 套件。
- 【觀察】Spaces/全螢幕：`CGSSpaceGetType`(type 4/1 視為全螢幕，0x1001fb740)、`SpaceObserver`。
- 【觀察】瀏海：`TopShelfMenuBarCoordinator` 的 `TS-SPACER` 把被遮項目往左推；`NSScreen.auxiliaryTopRightArea`；
  設定 `showToRightWithNoRoom`、`BartenderBarOnlyOnNotchScreens`。
- 【觀察】Widgets：node-graph（`WidgetWorker`+各 `*NodeWorker`），用 SwiftData 存（`Persistence`/`WidgetActor`）。
- 【觀察】持久化：一般設定 UserDefaults（自訂 suite）、Widgets SwiftData、身分快取 `WindowMap`、文件 `.BartenderPreferences`(套件)。

## 對 Whisky 的設計意涵（摘要）

- 【推論】隱藏核心沿用「展開分隔項目」即可，但 Tahoe 的 5016pt 長度上限與移除過寬項目行為（見
  [concepts/status-item-hiding.md](../concepts/status-item-hiding.md)）表示 Whisky 不能只靠 length=10000。
- 【推論】Tahoe 身分配對必須有獨立 XPC helper 做 AX（避免主程式被無回應 App 卡死）+ 影像雜湊持久化，是最大工程量。
- 【推論】移動要能選擇「post 後 tap 確認」以提高可靠度，並在移動期間用 active event tap 擋使用者輸入 + 隱藏/warp 游標。
