---
title: 列舉其他 app 的選單列項目
type: concept
tags: [enumeration, cgwindowlist, accessibility, axextrasmenubar, private-api, macos-26, macos-27]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/frostbar__frost
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/happy666End__MenuBarHider
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/FelixKratz__SketchyBar
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-14
---

# 列舉其他 app 的選單列項目

要排列、搜尋、在獨立 bar 顯示別人的 item，第一步是知道「有哪些 item、各在哪、屬於誰」。macOS 沒有公開 API 專門做這件事，
開源專案用了三條路，而 macOS 26、27 先後讓前兩條路變形或失效。

## 三條路

### A. WindowServer window list（每個 item 一個 window，≤ macOS 26）

在 macOS 26 以前，每個 status item 是一個 layer 25（`kCGStatusWindowLevel`）的 window。

| 專案 | API | file:line |
|---|---|---|
| [Ice](../projects/ice.md) | 私有 `CGSGetProcessMenuBarWindowList` + `CGSGetOnScreenWindowList` + `CGSCopySpacesForWindows`；metadata 用公開 `CGWindowListCreateDescriptionFromArray` | `Ice/Bridging/Bridging.swift:125-237`；`Ice/Utilities/WindowInfo.swift:61-63`, `:109-119` |
| [Thaw](../projects/thaw.md) | 同 Ice（私有 CGS） | `Shared/Bridging/Shims.swift:100-155` |
| [SketchyBar](../projects/sketchybar.md) | 公開 `CGWindowListCopyWindowInfo(.optionAll)`，`layer == 0x19` | `src/alias.c:72-116` |
| [MenubarHide](../projects/menubarhide.md) | 公開 `CGWindowListCopyWindowInfo`，`layer == CGWindowLevelForKey(.statusWindow)` | `MenubarHide/MenuBarItemScanner.swift:76-92` |
| [Frost](../projects/frost.md)（26） | 公開 `CGWindowListCopyWindowInfo` layer 25 | `Packages/FrostCore/Sources/FrostCore/Scanning/StatusWindowParser.swift:20-44` |
| [SaneBar](../projects/sanebar.md)（fallback） | 公開，layer 24 或 25、尺寸過濾，不讀 window name | `Core/Services/AccessibilityMenuBarWindowFallbackPolicy.swift:17-25`, `:114-143` |

要點：

- `kCGWindowName` 是 item 的 autosave name（Ice 拿它當身分），但**沒有 Screen Recording 權限時會被隱藏**。Ice 甚至用「別人的 item 有沒有 title」
  來判斷是否已授權（`Ice/Utilities/ScreenCapture.swift:12-23`）；SketchyBar 因此缺權限就完全看不到 item（`src/alias.c:98-100`）。
- 私有 `CGSGetProcessMenuBarWindowList` 的好處：直接得到「選單列 item window」清單，不用掃全部 window。
- 即時 frame：私有 `CGSGetScreenRectForWindow`（Ice `Bridging.swift:58-66`）或 SketchyBar 的 `SLSGetScreenRectForWindow`。

### B. Accessibility：每個 app 的 `AXExtrasMenuBar`

`AXUIElementCreateApplication(pid)` → 屬性 `AXExtrasMenuBar`（`kAXExtrasMenuBarAttribute`）→ children（每個 status item 一個 AX 元素）→
position／size／identifier／title／description。

| 專案 | 用途 | file:line |
|---|---|---|
| [Thaw](../projects/thaw.md) | 在 XPC 裡把 window 對回真正擁有者（中心點 ≤ 1 pt） | `MenuBarItemService/SourcePIDCache.swift:506-567` |
| [Frost](../projects/frost.md) | 26：midX ±4 pt 配對 + 前後兩次快照一致；27：唯一來源 | `FrostCore/Scanning/AXItemMatcher.swift:33-66`；`AXMenuBarInventory.swift:47-73` |
| [SaneBar](../projects/sanebar.md) | 主要來源 | `Core/Services/AccessibilityMenuBarScanningService.swift:147-177`, `:416-536` |
| [Hidden Bar](../projects/hidden-bar.md) | 27 的 section 判定、Notch Overflow | `hidden/Features/StatusBar/Layout/AccessibilityMenuBarInventory.swift:36-83` |
| [MenuBarHider](../projects/menubarhider.md) | 27 的 section 判定（`concurrentPerform` 平行，約 100 ms） | `MenuBarHider/Services/MenuBarScanner.swift:31-77` |

要點：

- **擁有者就是被查詢的 pid**，不受 window 擁有權變動影響——這是它在 26／27 上成為主流的原因。
- AX 呼叫在目標 app 的 main thread 執行，卡住的 app 會拖住掃描：一定要 `AXUIElementSetMessagingTimeout`（Hidden 0.1 s、
  MenuBarHider 0.2 s、SaneBar 0.18 s），最好放背景或另一個 process（Thaw 的 `MenuBarItemService.xpc`），並對「沒有 extras bar 的 app」
  做 negative cache（Thaw `SourcePIDCache.swift:451-456`）。
- Control Center 與 SystemUIServer 的 extras 要展開：SaneBar 遞迴走 AX 樹，用 `AXIdentifier`（`com.apple.menuextra.*`）辨識
  （`Core/Services/AccessibilityMenuExtraService.swift:34-96`, `:162-295`）；macOS 27 上時鐘、Control Center 按鈕、overflow 箭頭屬於
  MenuBarAgent（Frost `FrostCore/Model/SystemItemRules.swift:18-46`；MenuBarHider `Services/SystemMenuItems.swift:41-59`）。
- macOS 27 的 AX 元素有時沒有 title／identifier（Hidden `MenuBarLayout.swift:26-27`），身分要用 identifier → description／help → index
  的降級順序（Frost `ItemIdentityKey`）。
- macOS 27 上被擠進 overflow 的 item 仍回報舊 frame，AX 幾何**不能**用來判斷是否可見（Frost `docs/macos-behavior.md`）。
- 【矛盾，待實測】[Pelmet](../projects/pelmet.md) 的註解說：macOS 27 上被 MenuBarAgent host 的 item，在 app 自己 AX 節點下的 frame 位於
  「app 自己的螢幕外空間」，不能用幾何在同一 app 的多個 item 間配對（`Packages/PelmetEngine/Sources/PelmetEngine/ItemEnumerator.swift:256-259`），
  所以 Pelmet 改用下面 D 的 agent group frame。這和 Frost、Hidden Bar、MenuBarHider 在 27 上直接用 `AXExtrasMenuBar` children 位置的作法不一致。

### C. System-wide AX hit-testing

`AXUIElementCreateSystemWide()` + `AXUIElementCopyElementAtPosition` 沿選單列逐點打，`AXUIElementGetPid` 取擁有者，只留 role
`AXMenuBarItem`、subrole `AXMenuExtra`（[SaneBar](../projects/sanebar.md) `Core/Services/AccessibilitySystemWideMenuBarScanner.swift:43-122`，每 6–8 px）。
Ice 用同一個 API 找 app menu 的範圍（`Ice/MenuBar/MenuBarManager.swift:292-320`），Frost 用它確認某點真的是目標 item
（`FrostCore/Scanning/AXExtrasReader.swift:118-132`）。

### D. MenuBarAgent 自己的 AX tree（macOS 27）

[Pelmet](../projects/pelmet.md) 不逐 app 讀 `AXExtrasMenuBar`，而是只 walk 一個 process：`AXUIElementCreateApplication(com.apple.MenuBarAgent 的 pid)`
→ children = 每個 display 一個 `AXWindow` → 每個 item 一個 group。file:line 相對於 `raw/github/repos/fif7y__pelmet/`，
`PE/` = `Packages/PelmetEngine/Sources/PelmetEngine/`：

- 第三方 item：group 下巢狀一個擁有者 app 的 `AXApplication` 節點，`AXUIElementGetPid` 取擁有者（`PE/ItemEnumerator.swift:112-128`）。
- 系統 item：`AXGroup` → `AXMenuBarItem`，`AXIdentifier` = `com.apple.menuextra.*`（`:129-142`）；普通 `NSStatusItem` 按鈕是裸 `AXButton`（`:143-147`）；
  其他形狀（Little Snitch 的自繪 view）用任一 child 的 pid 歸屬（`:152-164`）。
- frame 取 agent group 的 `AXFrame`；同一 item 在每個 display 各出現一次，保留主螢幕那份（`:56-84`）。agent 還沒 adopt 的 item frame 不在任何
  display 上（例如 x=4800 y=−164，`Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:240-247`）；被 assertion 藏起來的 item 直接從 tree 消失，
  所以 Pelmet 要自己「帶著」已隱藏的集合（`PE/AgentBarEngine.swift:722-737`）。
- 擁有者沒有 LaunchServices bundle ID 時，用 `proc_pidpath` 往上找最近的 `.app`（`PE/ItemEnumerator.swift:201-228`）。
- 好處：一次 walk 就拿到所有 item（含系統 item），順序就是畫面順序；messaging timeout 只要設在 agent 上（0.25 s，`:88-102`）。代價：title 仍要
  進各 app 讀 extras bar（每個 app 3–4 次 IPC，是 walk 的主要成本，約 100 ms，`docs/ARCHITECTURE-REVIEW.md:113-114`）。
- 系統的 `«` overflow 按鈕不在任何 AX 階層裡，只能對 MenuBarAgent 的 app element 做 `AXUIElementCopyElementAtPosition` 逐點（3 pt）找到；
  system-wide hit-test 會被前景 app 的選單列擋住（`Pelmet/App/OverflowToggle.swift:1-11`, `:69-99`）。
  被 « 收起的 item 回報彼此重疊的 phantom frame（`Pelmet/App/ApplyPass.swift:45-61`）。

## macOS 版本差異

| | ≤ macOS 15 | macOS 26 Tahoe | macOS 27 |
|---|---|---|---|
| 每個 item 有自己的 window？ | 是（layer 25） | 是（layer 25） | **否**：整條選單列是 MenuBarAgent 擁有的一個 layer 24 window（MenubarHide `AGENTS.md:39`；Frost `docs/macos-behavior.md:567`） |
| `kCGWindowOwnerPID` | 建立 item 的 app | **全部是 Control Center** | 不適用 |
| 正確的擁有者來源 | window owner | AX `AXExtrasMenuBar` 反查（Thaw、Frost），或 bundle-ID marker window（Thaw `MarkerPairResolver.swift:13-60`） | 只有 AX |
| ScreenCaptureKit 看得到 item window？ | 是 | 是（但螢幕外會 `-3811`） | **否** |

其他 Tahoe 細節：

- 有些 widget（Little Snitch）在 AX 層被 Control Center 代管、沒有自己的 `AXExtrasMenuBar`；它會另外發一個 title 為 bundle ID、寬度相同的
  marker window，可以拿來配對（Thaw `Shared/Utilities/MarkerPairResolver.swift:13-60`）。
- `_AXUIElementGetWindow` 對 status item 回 −25201（SaneBar `docs/NOTCH_MOVE_LIMITATION.md:35-45`）。
- 自己的 status item：`NSWindow.windowNumber` 不一定等於 CG window ID，Frost 改用 frame 比對（`FrostCore/Scanning/FrostControlLocator.swift:5-49`）；
  Thaw 先給長度 1 才會生出有 CG ID 的 window（`ControlItem.swift:56-58`）。
- 多螢幕：每個螢幕的選單列都有一份 item window；只有作用中選單列上的是「真的」，其他是 replica（Frost `MenuBarDisplayResolver`、
  `SectionController.swift:146-167`）。

## item 身分（持久化用的 key）

| 專案 | 身分 |
|---|---|
| [Ice](../projects/ice.md) | `bundleID:kCGWindowName`（`MenuBarItemInfo.swift:20-22`） |
| [Thaw](../projects/thaw.md) | `MenuBarItemTag`（namespace:title 為基礎，另處理 CC 代管 item） |
| [SaneBar](../projects/sanebar.md) | `bundleId::axid:<id>` 或 `bundleId::statusItem:<index>` 或 `com.apple.menuextra.*`（`Core/Models/RunningApp.swift:163-176`） |
| [Frost](../projects/frost.md) | AX identifier → description／help → index；27 另合成 FNV-1a window ID（`AXMenuBarInventory.swift:91-111`） |
| [MenuBarHider](../projects/menubarhider.md)、[Hidden Bar](../projects/hidden-bar.md)（27） | 只用 bundle ID |
| [Pelmet](../projects/pelmet.md)（27） | 觀察用 `status:<bundleID>::<title>`（與 MenuBarAgent plist 的 tag 同格式）；持久化的 model 收斂成 `bundle:<id>`，只有自己的 item 與 MenuBarAgent 的系統 item（`com.apple.menuextra.*`）保留完整身分，因為 AX title 會變（`Packages/PelmetCore/Sources/PelmetCore/SectionModel.swift:9-63`） |

## 其他專案的列舉做法（2026-10-14 補）

- **零權限找出被丟掉的項目**：status item 是 layer 25 的視窗，`CGWindowListCopyWindowInfo(.optionAll)` 回傳的 owner、bounds、on-screen 旗標不受 TCC 限制（只有視窗標題受限）。
  被系統丟掉的項目仍在清單裡，幾何也正確，只是沒畫出來（[overhang](../../raw/github/readmes/nicglazkov__overhang.md) `:93`）。【未知】26 上 owner 都是 Control Center，要配合 AX 才知道是誰。
- **AX 掃描最佳化**：跳過 `.prohibited` 的程序、messaging timeout 設 0.1 s、快取「沒有 status item 的 App」並錯開重查，掃描從 2143 ms 降到約 20 ms（[Mezzanine](../../raw/github/readmes/brianmpollack__Mezzanine.md)）。
- **sandbox 會讓 AX 讀不到 extras**：開 sandbox 後可讀的 extras 從 12 個 App 變成 0，但 `AXIsProcessTrusted()` 照樣回 true（Mezzanine）。和 [Hidden Bar](../projects/hidden-bar.md) App Store 版的問題一致。
- **27 的系統項目**：所有 Apple 項目的擁有程序都是 MenuBarAgent，只能靠 AX description 分辨（[Tidy](../../raw/github/readmes/Itzhaik07__Tidy.md)）；
  可用 `MBSystemItemIdentifier.allCases` 加 `Menu Extras/*.menu` 在執行期發現（[MenuBarCompact](../../raw/github/readmes/iamwrm__MenuBarCompact.md)）。
- **只列有選單列圖示的 App**：用 `AXExtrasMenuBar` 判斷（[Stash](../../raw/github/readmes/brentc22__stash.md)、[Ellipsis](../../raw/github/readmes/ronny__ellipsis.md)）。

以上五點出自 README；以下已讀原始碼：

- **27 上走 MenuBarAgent 的 AX tree**（[Chest](../projects/chest.md) `MenuBarItems.swift:155-178`）：MenuBarAgent 的 `AXWindows`（每條選單列、每個 Space 各一個）→ slot（帶 frame）→ 第一個子元素。
  子元素是 `AXApplication` 就用 pid 換 bundle ID；是 MenuBarAgent 自己的 hosting view 就讀 `AXIdentifier`（`com.apple.menuextra.<name>`）。用 `bundleID@minX` 去重。
- **版面變化通知**：對 MenuBarAgent 的 **application element** 註冊 `kAXLayoutChangedNotification`；掛在個別 window 上收不到（Chest `MenuBarLayoutObserver.swift:3-8`）。
  MenuBarAgent 被重啟時 NSWorkspace 不會通知，要用 `DispatchSource.makeProcessSource(.exit)` 監看（`:62-94`）。
- **逐 App 讀 `AXExtrasMenuBar` 的處理規則**（[MenuTidy](../projects/menutidy.md) `MenuBarInventory.swift`）：`concurrentPerform` 並行、timeout 0.25 s；
  `kAXErrorCannotComplete` 視為暫時聯絡不到，不等於沒有 item；空結果不覆蓋舊快照；行程集合改變或滿 60 s 才做 full sweep；27 上只在展開時拍快照（受限的 bar 會少報）。
  【觀察】27 上自己圖示的位置要用 AX 讀，NSWindow frame 不準（作者量到 361 vs 實際 896，`:200-214`）。
- **掃描最佳化**（[Mezzanine](../projects/mezzanine.md) `MenuBarItemScanner.swift`）：跳過 `.prohibited`、timeout 0.1 s、沒有 item 的 App 用隨機錯開的負快取（約 15 次掃描重查一次）。
  Control Center 有一批 zero-size placeholder 代表使用者關掉的模組，要略過。
- **被藏的 item 仍在擁有者 App 的 `AXExtrasMenuBar` 裡**：26 的瀏海溢出（Mezzanine）與 27 開關關掉的 App（Chest【作者稱】）都是如此，可用來做 [menu mirroring](menu-bar-item-activation.md)。

## 對 Whisky 的建議

- 以 AX `AXExtrasMenuBar` 為主幹（26、27 都可用），WindowServer list 只當 26 上的輔助（取 window ID 供擷取與事件路由）。
- AX 掃描放在獨立的 actor／XPC，設定 messaging timeout、負快取、慢 app 記錄；掃描結果用「前後快照一致」判穩定。
- 身分 key 用 `bundleID + AXIdentifier`，退而求其次用 description／help，再退用同 app 內的 index；系統 extras 用 `com.apple.menuextra.*`。
- macOS 27：把 [Pelmet](../projects/pelmet.md) 的「walk MenuBarAgent 的 AX tree」（D）當成順序與 frame 的主來源，和逐 app 的 `AXExtrasMenuBar`（B）
  交叉驗證，並實測上面那條「app 節點下的 frame 在螢幕外」的矛盾。
