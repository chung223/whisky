---
title: Bartender 6 架構
type: bartender
tags: [reverse-engineering, menu-bar, swift, appkit, xpc]
sources:
  - raw/bartender/rea/notes-main-method.md
  - raw/bartender/rea/notes-main-hiding.md
  - raw/bartender/rea/notes-main-enumeration.md
  - raw/bartender/rea/notes-main-moving.md
  - raw/bartender/rea/notes-main-bar-clicking.md
  - raw/bartender/rea/notes-main-styling.md
  - raw/bartender/rea/notes-main-update-detection.md
  - raw/bartender/rea/notes-main-features.md
  - raw/bartender/rea/notes-xpc-service.md
  - raw/bartender/rea/main-swift-fieldmd.txt
updated: 2026-10-15
---

# Bartender 6 架構

對象是 Setapp 版 Bartender 6.6.2 主執行檔（Swift 模組名 `Bartender_6_Setapp`）的 arm64 slice。
逆向方法與限制見 [notes-main-method.md](../../raw/bartender/rea/notes-main-method.md)：REA(Ghidra) 對這個 15 MB
Swift binary 的自動分析在本輪未完成、所有查詢逾時，因此改用 `otool -tV` 反組譯加自寫的 Mach-O metadata 解析
（selref/objc_stubs/fieldmd/vtables/cfstrings）來定位函式與欄位。證據以「raw 路徑 + 函式位址」引用。

## 程序與套件結構

- 【觀察】單一主程式 + 一個 XPC service `Bartender Service.xpc`，bundle id `com.surteesstudios.Bartender.TahoeXPC`，
  LSMinimumSystemVersion 26.0，無 sandbox。見 [notes-xpc-service.md](../../raw/bartender/rea/notes-xpc-service.md)。
- 【觀察】主程式用 Swift `XPC` framework（`XPCSession`/`XPCListener`/`XPCPeerRequirement`）而非 `NSXPCConnection`
  連這個 helper，連線要求 `.isFromSameTeam(andMatchesSigningIdentifier:)`。（notes-main-enumeration.md E4；
  符號見 main-funcindex 的 `_$s3XPC…`）
- 【推論】只有在 macOS 26（Tahoe）才需要這個 helper：它在獨立程序裡做會阻塞的 AX 查詢，避免卡住主程式 UI。
- 【觀察】兩個文件 UTI 皆為目錄套件（LSTypeIsPackage）：`.BartenderPreferences`（偏好設定文件，
  `BartenderPreferencesDocument.readFromURL:ofType:` @0x10031911c）與 `.BartenderWidget`（匯出的 widget）。
  來源 `raw/bartender/bundle/Info.plist`。套件內部檔案格式【未知】。
- 【觀察】Sparkle 自動更新，appcast `https://downloads.macbartender.com/B2/updates/AppcastB6.xml`。
  （notes-main-features.md；strings）

## 核心子系統與對應類別

### 列舉與身分（Enumeration / Identity）
- 【觀察】`MenuItemManager`（欄位含 `menuItemsStorage, menuItemsMapStorage, hisItem/rhsItem/eItem/topShelfSpacerItem,
  controlCenterPID, a11yHelper, imageIndexer, windowChangeDetector, _indexing, _allItemsIndexed`；
  main-swift-fieldmd.txt @0x100b6e034）是列舉與配對的中樞。
- 【觀察】`WindowInfo`（@0x100b75104）封裝 CGWindowServer 的每個選單列視窗（windowID/frame/title/layer/ownerPID/
  ownerName/isBartender/isBentoBox…）；`BarItem`（@0x100b68fc8）是上層模型（bundleID/windowKeyName/pid/icon/isApple…）。
- 【觀察】Tahoe 專屬：`TahoeAccessibilityMatcherXPC`、`TahoeAccessibilityCache`、`TahoeImageIndexer`、`TahoeXPCConnection`、
  `WindowIDChangeDetector`、`WindowServerMonitorModel`、`WindowMap`（UserDefaults 持久化 key `com.bartender.windowmap.persistence`）。
  機制見 [mechanisms.md](mechanisms.md)。
- 【觀察】系統項目特例由 `SystemUIServerNamesHelper`、`BundleIdHelper`、`LilSnitchMatcher`、`MultipleSameAppHelper` 處理。

### 隱藏與控制項目（Hiding）
- 【觀察】`BartenderManager` 持有三個自有 NSStatusItem 當分隔線：HISItem、RHSItem、EItem（欄位
  `hiddenItemSeperatorStatusItem/reallyHideSeperatorStatusItem/endStatusItem`，@0x100b707f4；建立於 0x1004717f4）。
- 【觀察】自有項目識別字前綴 `com.surteesstudios.Bartender-setapp-{statusItem,HISItem,RHSItem,THSItem,EItem,SFUItem,…}`、
  `-special.{GapItem,SubItem}`（strings）。
- 【推論】隱藏靠調整分隔線 `length`（見 mechanisms.md），不是搬移別人的項目。

### 移動與排列（Moving / Arranging）
- 【觀察】兩套引擎並存：舊 `MoveHelper`（@vtable 0x1003c3c80…；欄位 @0x100b6ea78 含多個 event tap、semaphore、失敗清單）
  與新 `MoveHelperTwo → StandardMoveCoordinator → MoveOperationQueue(actor) → MoveEventDeliveryMonitor / MoveEventTap /
  MoveEventTapThread / ClickSuppressionController`（fieldmd）。
- 【觀察】排列策略層 `MenuItemPositionManager`（`runArrangement(profile:cause:)` @0x1005474e4）；
  型別 `MoveDestination/MoveError/MoveResult/MovementMetrics/MoveStep`（@0x100b6ed40…）。
- 【觀察】`CursorVisibilityManager`（hideDepth 巢狀計數）、`UserInputMonitor`、`MenuTrackingHelper` 協同。

### Bartender Bar、擷取、點擊（Bar / Capture / Clicking）
- 【觀察】`BartenderBarPanel`(NSPanel) + `BartenderBarViewController/ViewModel` + `BartenderBarMenuItemViewHelper`(NSCollectionView
  datasource) + `MenuItemCollectionViewItem` + `BartenderBarMenuItemView`。
- 【觀察】擷取：`WindowCaptureManager`、`WindowCapture`(ObjC `+imageFromWindowID:screenBounds:imageOption:`)、
  `MenuBarImageCache`、`MenuBarItemImageHelper`；`WindowStreamer`(持有 `SCStream` 欄位但無建立 SCStream 的符號)。
- 【觀察】點擊轉送：`MenuItemClicker`（0x100381398 起）。細節見 mechanisms.md。

### 外觀（Styling）
- 【觀察】`MenuBarColoringManager`(+`SpaceSettings`,`AppSpecificColor`)、`MenuBarCoverWindow`、`MenuBarRoundingManager`、
  `TahoeMenuBarView`(+`DesktopCoverView`,`MaterialViewModel`)、`RoundedMenuBarView`、`pillLayoutManager`、`StyleHelper`。

### 更新偵測（Show For Updates）
- 【觀察】`SFUItem`(@0x100b6da1c)、`ItemSettings`(@0x100b740c4)、`MenuBarItemImageComparison`(@0x100b752a4)、
  `ShowForUpdatesHelper`、`UpdateStatusItem`(假佔位項目，@0x100b748ac)。

### 自動化與輸入（Triggers / Autohide / Hotkeys）
- 【觀察】`TriggerManager`(@0x100b6f1c4：Timer/Location/WiFi/Script/Image/Focus 觸發器)、`ProfilesHelper`、
  `MenuBarLayoutModel`(四區：shown/hidden/alwaysHidden/grouped)、`AutohideMonitor`、`MouseInMenuBarView`、
  `CustomHotKeyManager`(DDHotKey/Carbon) + KeyboardShortcuts 套件、`SpaceObserver`、`TopShelfMenuBarCoordinator`。

### Widgets
- 【觀察】`WidgetManager`/`WidgetActor`(SwiftData)/`WidgetWorker`/`VariableManager`(+Canvas)，節點型 UI 以
  `*NodeWorker`+`*NodeView`+`Connection`(socket 連線) 組成（型別清單見 notes-main-features.md）。

### 持久化（Persistence）
- 【觀察】一般設定 → UserDefaults（Setapp 版自訂 suite，有一次性遷移）；`DefaultsHelper`、`PrefsHelper`。
- 【觀察】Widgets → SwiftData `ModelContainer`（`Persistence` 類別 0x100290f60，建於 Application Support，
  毀損時重建、再失敗退回 in-memory）。

- 【觀察】（2026-10-15，使用者機器上的 `~/Library/Preferences/com.surteesstudios.Bartender-setapp.plist`，Bartender 6 Setapp 版，非逆向）
  版面存在 `ProfileSettings.activeProfile`：`Show`、`Hide`、`AlwaysHide` 三個陣列，元素是 `<bundleID>-<autosave name>` 字串
  （例如 `ru.keepcoder.Telegram-Item-0`、`com.apple.controlcenter-WiFi`、`com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.cpu`）；
  `special.AllOtherItems` 是「其他所有項目」的佔位；有些項目以 UUID 代替 bundle ID。其他 key：`GapItemLabels`、`GapItemWidths`（spacer）、
  `subItemItems`／`subItemTitles`／`subItemIcons`（groups）、`leaveAlwaysHiddenItems`。自己的分隔項目位置在 `NSStatusItem Preferred Position HISItem`、`RHSItem`、`THSItem`、`EItem`。
  → 這足以做「匯入 Bartender 版面」（[路線圖](../synthesis/roadmap.md) M7）。
- 【觀察】同一台機器上 Bartender 沒在執行時，`Hide`／`AlwaysHide` 裡的 15 個 App 的 status item 仍不在選單列上：AX frame 在螢幕左下角、沒有選單列視窗
  （[平台實測](../concepts/platform-verification.md)）。這些 App 自己的 defaults 裡沒有 `NSStatusItem Visible … = 0`。【未知】Bartender 6 在 macOS 26 上用什麼方式讓它們離開選單列，而且在 Bartender 結束後仍然有效（猜測是系統「允許在選單列中顯示」開關，未驗證）。

## 資料流（高階）

1. 【推論】`MenuItemManager` 以私有 CGS 取得所有程序的選單列視窗清單 → 建 `WindowInfo` → 配對擁有者
   （Tahoe 走 XPC+AX+影像索引）→ 依使用者在四區的配置與控制項目的視窗位置，算出每個項目該在哪一區。
2. 【推論】需要改變可見性時，`BartenderManager` 調整 HIS/RHS/EItem 的 `length`（即時隱藏/顯示）；
   需要永久重排時，`MenuItemPositionManager` 透過 Move 引擎對目標項目合成 ⌘-拖曳。
3. 【推論】Bar 顯示隱藏項目的截圖；在 Bar 點擊 → `ShowItem` 先把真項目移進畫面 → `MenuItemClicker` 合成點擊。
4. 【觀察】`TriggerManager`/快捷鍵/hover/scroll/click 都走 `BartenderManager` 的顯示切換與 profile 套用。

## 權限

- 【觀察】Accessibility（AX；`AXIsProcessTrusted`、Tahoe 的 AX 查詢、移動用的事件）與 Screen Recording
  （截圖 Bar/比較圖；`CGRequestScreenCaptureAccess` 0x1005ce728）。權限說明字串："Screen Recording … Required to capture
  and display menu bar items"、"Accessibility … Required to manage your menu bar items"（strings）。
- 【觀察】曾寫入 `ScreenCaptureApprovals.plist`（group.com.apple.replayd）以減少重複的螢幕錄製授權彈窗。

## 引用索引（raw）

- 反組譯與 metadata：`raw/bartender/rea/main-funcindex.tsv`、`main-swift-fieldmd.txt`、`main-objc-methods.txt`、
  `main-swift-vtables.txt`、`main-objc-msgsend-stubs.txt`、`main-cfstrings.txt`、`scripts-otool/`。
- `evidence-main.json` 為空（REA 未完成分析、無 Evidence 記錄）；函式位址可在 Ghidra 分析完成後複查。
