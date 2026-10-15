---
title: Pelmet
type: project
tags: [open-source, swift, appkit, gpl-3.0, menu-bar-manager, macos-27, private-api, menubaragent, assessment-mode, accessibility]
sources:
  - raw/github/repos/fif7y__pelmet
  - https://github.com/fif7y/pelmet
  - https://github.com/fif7y/pelmet/issues
  - https://github.com/fif7y/pelmet/releases/tag/v0.3.2-beta.4
updated: 2026-10-12
---

# Pelmet

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [fif7y/pelmet](https://github.com/fif7y/pelmet)（作者 Gabriel Faucon） |
| 授權 | **GPL-3.0**（貢獻需簽 CLA，`CLA.md`） |
| 語言 | Swift 6（`SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`）＋一個 ObjC shim；XcodeGen `project.yml` |
| Stars | 840（2026-08-20 建立） |
| 活躍度 | 極活躍：v0.3.1（2026-10-05）；0.3.2-beta.4（2026-10-12，在 `panel` 分支，不在本次 clone） |
| 支援的 macOS | **只支援 macOS 27**：deployment target 27.0（`project.yml:4-5`），兩個 package 都是 `.macOS("27.0")`（`Packages/PelmetEngine/Package.swift:6`）；README `:159-160` 與 FAQ `:3-6` 明說 26 以前不支援 |
| 版本分支 | 執行期**不分版本**：只有一個實作 `AgentBarEngine`；`MenuBarEngine` protocol 是預留給 macOS 28 的接縫（`PE/MenuBarEngine.swift:1-3`） |
| macOS 27 隱藏 | 私有 MenuBarClientCore 的 `MBAssessmentModeAssertion` allow-list，**連系統 icon 一起管** |

Pelmet 是三區段（Visible／Hidden／Always Hidden）的 macOS 27 專用選單列管理工具：hover／點空白處／hotkey 顯示、
layout 編輯器（「編輯器是一張草圖」，按 Apply 才真的動 bar）、⌥⌘K 搜尋、per-display 行為、icon spacing，以及一組
「替身」item（媒體控制、AirDrop、相機／麥克風、Focus、Timer、快速使用者切換、Siri、Time Machine、App launcher）。
README 說它的 macOS 27 作法是建立在 Thaw 維護者於 [Thaw #687](https://github.com/thaw-app/Thaw/issues/687) 公開的研究上
（`README.md:211-215`）。

對 Whisky 最重要的三點：(1) 它是目前**唯一公開原始碼、把 allow-list 推到系統 icon（含 Control Center 與 Clock）**的專案；
(2) 它記錄了 allow-list 路線的新坑（新註冊 item 被 park、collateral extras、通知中心被鎖）與對策；(3) `docs/` 有大量帶日期的
27 實測結論（`CORE-SETS.md`、`ARCHITECTURE-REVIEW.md`、`HELPER-PROCESS-PLAN.md`、`FAQ.md`、`ISSUE-AUDIT-0.3.0.md`）。

本頁 file:line 相對於 `raw/github/repos/fif7y__pelmet/`（commit `3f757c9`，即 v0.3.1）。縮寫：
`PE/` = `Packages/PelmetEngine/Sources/PelmetEngine/`，`PC/` = `Packages/PelmetCore/Sources/PelmetCore/`。

## 架構

Core ← Engine ← App 三層，加兩個 helper process（`docs/ARCHITECTURE-REVIEW.md:7-14`）：

| Target | 角色 |
|---|---|
| `PelmetCore`（SwiftPM，純邏輯） | `SectionModel`／`Roster`（membership）、`MovePlan`（weighted LIS 求最少拖曳）、`RehideStateMachine`、`MenuBarPolicy`（bundle 分類表與 system item 對照）、`ItemID` grammar、`BarAdoption`（從 bar 讀回使用者的 ⌘-drag）、`SettingsStore`、`HelperProtocol`、`MessagePortLink`、Search |
| `PelmetEngine`（SwiftPM） | `AgentBarEngine` actor（唯一能改 hide state 的地方）、`ItemEnumerator` actor（MenuBarAgent 的 AX walk）、`ConvergePlan`（純函式算 allow-list）、`AssessmentMode` + ObjC `MBAssessmentShim`、`ItemMover`（shielded 合成 ⌘-drag）、`AgentPositionStore`；另有 `pelmet-probe` 實驗 CLI（`dump`／`positions`／`conceal`／`conceal-sys`／`ax`／`enum`／`engine-test`，`Packages/PelmetEngine/Sources/pelmet-probe/main.swift:1-8`, `:106-144`） |
| `Pelmet`（App） | `AppState`（@Observable 根物件，約 2.8k 行）、`TransitionCoordinator` + `ConcealGhostOverlay`（用截圖蓋住系統動畫）、`MenuBarBandMonitor`（hover／點擊觸發）、`ClockClickRelay`、`ApplyPass`／`OverflowToggle`（唯一的移動入口）、`ItemPress`（打開隱藏 item）、`Extras/*`（替身 item）、`CommandBar/*`（搜尋）、SwiftUI Settings、Sparkle |
| `PelmetItemsHidden`／`PelmetItemsAlwaysHidden` | 同一份 `PelmetItems/main.swift` 編成兩個 `LSUIElement` app，bundle ID `app.fif7y.Pelmet.items.hidden`／`.alwaysHidden`，嵌在 `Contents/Helpers`（`project.yml:62-73`, `:102-126`） |

- **為什麼要 helper process**：assertion 以 bundle 為單位，而主程式必須留在 allow-list 才看得到 chevron，所以 Pelmet 自己的
  separator、launcher、替身 item 原本無法跟著隱藏（只能靠 `isVisible`、寬度、alpha 手動模擬）。解法是每個可隱藏區段一個 helper，
  item 放在對應 helper，區段收合時把 helper 的 bundle ID 排除即可（`docs/HELPER-PROCESS-PLAN.md:5-27`；`PC/MenuBarPolicy.swift:22-39`）。
  - helper 必須用 `NSWorkspace.openApplication` 啟動，才會在 LaunchServices 註冊；未註冊的 bundle allow-list 認不到
    （`HELPER-PROCESS-PLAN.md:89-93`；`Pelmet/StatusItem/HelperHosts.swift:105-119`，以環境變數 `PELMET_PARENT_PID` 傳父程序）。
  - helper 只 host `NSStatusItem`：單一實例（`PelmetItems/main.swift:17-21`）、父程序結束就退出（`:47-62`）、用 `isVisible` KVO
    偵測使用者把 item ⌘-drag 出 bar 並回報（`:114-122`）。
  - 註：`HELPER-PROCESS-PLAN.md:3` 寫「planned, not started」，但 clone 內的 target 已存在，文件狀態過時。
- **IPC**：一對 `CFMessagePort`（port 名 = bundle ID，主程式是 `app.fif7y.Pelmet.link`），fire-and-forget，送到接收端 main run loop
  （`PC/MessagePortLink.swift:1-35`；`PC/MenuBarPolicy.swift:30-31`）。沒有 XPC service、沒有 launchd 設定。
- **設定**：一個 Codable JSON blob 存在 `UserDefaults` key `app.fif7y.Pelmet.settings.v1`（`PC/SettingsStore.swift:2`, `:511`），
  沒有 schema version（`ARCHITECTURE-REVIEW.md:178`）。四個真相來源刻意分開：membership（設定）、實體順序（MenuBarAgent 的 AX tree，
  從不儲存）、hide state（assertion）、截圖（`ARCHITECTURE-REVIEW.md:16-21`）。
- **核心設計「sets, not positions」**（`docs/CORE-SETS.md:7-24`）：隱藏只看 membership，與位置無關；合成拖曳只在使用者按 Apply
  時發生，從不在背景、hover、顯示／收合、開機或新 item 出現時移動任何東西。0.3.0 因此刪掉 2,345 行 placement 程式（`:66-84`）。
  理由：0.2.x 的大多數 bug 都來自「保持區段實體分組」而在背景觸發的合成拖曳（`:9`）。
- 依賴只有 Sparkle（`project.yml:12-14`）；hotkey 用 Carbon `RegisterEventHotKey`（`Pelmet/Events/HotkeyManager.swift:1-3`）。
- `docs/` 內容：`CORE-SETS.md`（核心設計與 27 實測）、`ARCHITECTURE-REVIEW.md`（自我審查、延遲量測、私有 API 清單）、
  `HELPER-PROCESS-PLAN.md`、`COMMAND-BAR.md`（搜尋設計）、`FAQ.md`、`ISSUE-AUDIT-0.3.0.md`、`BETA-CHANNEL-PLAN.md`、`RELEASE.md`、
  約 50 份 release notes。

## 關鍵機制（附 file:line）

### 隱藏：MenuBarAgent allow-list（唯一的隱藏方式）

- ObjC shim：`dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore")` + `NSClassFromString`
  取 `MBAssessmentModeConfiguration`／`MBAssessmentModeAssertion`（`Packages/PelmetEngine/Sources/PelmetEngineObjC/MBAssessmentShim.m:11-26`）；
  `initWithAllowedSystemItems:allowedBundleIdentifiers:` 先用 `instancesRespondToSelector:` 檢查（`:77-84`）；assertion 是一般 `-init`
  再呼叫 `activateWithConfiguration:completionHandler:`（註解：在 27.0 26A5416b 用 runtime introspection 驗證，`:98-109`）；
  `invalidate`（`:119-131`）；全部包在 `@try`。shim 另有用 `class_copyMethodList` 傾印 API 面的探測函式（`:46-69`）。
- **assertion 綁 process**：app 釋放或 crash 時 macOS 自動恢復選單列（`PE/AssessmentMode.swift:8-10`；FAQ `:118-126`）。
- `AgentBarEngine` 是唯一寫入者，每次 `converge()` = AX walk → `ConvergePlan.compute`（純函式）→ swap（`PE/AgentBarEngine.swift:326-407`）：
  - **allow-list = 所有 running app 的 bundle ID − 要藏的**，再加上觀察到的 item 的 bundle（`PE/ConvergePlan.swift:92-106`）。
    用全部 running app 的理由：沒有 status item 的 bundle 允許了也無害，而且之後才啟動的 app 不會被吞掉。
  - **先 activate 新 assertion、成功後才 invalidate 舊的**，避免整條 bar 閃現（`AgentBarEngine.swift:496-534`）；completion 最多等 3 s
    （`PE/EngineTiming.swift:29`），拿不到 handle 就保留舊 assertion（`:509-519`）。
  - **idempotent**：新 allow-list 是現有的子集且其他集合相同就 no-op，否則「converge → reflow → itemsChanged → converge」會無限循環（`:468-489`）。
  - **外部拆除偵測**：swap 後超過 3 s 仍看到應藏的 bundle，就視為 assertion 被系統拆掉並重新 swap（`:450-466`, `:490-493`）；
    swap 後背景輪詢 3 s 確認真的消失（`:603-626`）。每次 converge 帶 epoch，被新 converge 取代就中止（`:113-117`）。
  - 空的 AX walk（開機、鎖定畫面）不可信，不據此規劃，最多重試 6 次（`:409-425`；`EngineTiming.swift:23-24`）。
  - **steady extras**（預設開，`PC/SettingsStore.swift:338`）：即使沒東西要藏，也持有一個「允許全部 bundle」的 assertion，讓下文的
    collateral extras 穩定消失，bar 不會忽有忽無地 reflow（`AgentBarEngine.swift:91-95`；`ConvergePlan.swift:90`）。
- **粒度是 bundle**（`AgentBarEngine.swift:44-48`，`hideGranularity: .bundleID`）：model 以 `bundle:<id>` 為 key，只有 Pelmet 自己的 item
  與 MenuBarAgent 的系統 item 保留完整身分（`PC/SectionModel.swift:35-63`）。同一 app 的多個 icon 在編輯器顯示「moves together」（FAQ `:8-11`）。
- **【新坑】新註冊的 item 會被 park**：任何 assertion 生效期間，新註冊的 status item（app 重新啟動、新 item）會停在螢幕外、**不進
  MenuBarAgent 的 AX tree**（實測 Bitwarden 停超過 4 分鐘）；就算 allow-list 已包含它也一樣，因為 swap 是無縫的，從不出現「沒有任何
  assertion」的空檔。Pelmet 的對策是 **adoption window**：暫時解除 assertion、每 200 ms walk 一次直到那個 item 出現（最多 2.5 s）、
  再重新 converge，期間用截圖蓋住閃爍（`AgentBarEngine.swift:237-277`；`EngineTiming.swift:45-48`；`Pelmet/App/AppState.swift:404`, `:513`, `:1254`）。
  還沒被 agent adopt 的 item，AX frame 不在任何 display 上（例如 x=4800 y=−164，`PC/MenuBarPolicy.swift:240-247`）。

### 隱藏系統 icon

- `allowedSystemItems` 不再一律給 `0..<64`。`SystemItem` 對照：0 battery、1 bluetooth、2 clock、3 displays、4 keyboard、5 volume、
  6 wifi、7 screenMirroring、8 primaryBentoBox（Control Center）（`PC/MenuBarPolicy.swift:42-60`）。使用者把系統 icon 放進
  Hidden／Always Hidden，`ConvergePlan` 就把對應編號從 allow-list 拿掉（`PE/ConvergePlan.swift:79-88`）。
- 對照方式：AX identifier `com.apple.menuextra.{sound, battery, wifi, clock, bluetooth, display(s), textinput|keyboard, screen-mirroring,
  controlcenter}`；輸入法 icon 由 `com.apple.TextInputMenuAgent` host，視為 keyboard（`PC/MenuBarPolicy.swift:62-81`）。
- **Control Center 與 Clock 也能藏**：註解記錄 2026-09-22 實測——只允許 0…7 時 Control Center icon（連同定位箭頭）離開 bar，允許 0…8
  時留下；之前「CC 永遠不藏」的說法從未被測過（`PC/MenuBarPolicy.swift:54-58`）。FAQ：「Control Center and the clock hide like any
  system icon but never move」（`docs/FAQ.md:64-67`）。兩者固定在 bar 右端、不能移動（`isPinnedSystemItem`，`PC/MenuBarPolicy.swift:83-91`）；
  README 的「locked」指的是位置（`README.md:57-62`）。
- **SystemUIServer 的 legacy extras**（Siri、Time Machine、VPN…）只能整個 bundle 一起藏，位置也被系統釘住（`PC/MenuBarPolicy.swift:14-17`, `:187-194`）。
  要個別管理時，Pelmet 畫自己的 Siri／Time Machine 替身，並把 Apple 的那個在系統設定中關掉：Time Machine 用
  `SystemUIPlugin.framework` 的 `CoreMenuExtraGetMenuExtra`／`CoreMenuExtraAddMenuExtra`／`CoreMenuExtraRemoveMenuExtra`，Siri 用
  `SiriFoundation.framework` 的 `SRFUserDefaultsController`（`sharedUserDefaultsController`、`isStatusMenuVisible`、`setStatusMenuVisible:`）
  （`Pelmet/Extras/AppleMenuExtras.swift:1-11`, `:50-57`, `:75-115`）。註解說這和系統設定頁所做的呼叫相同（2026-09-16 追蹤），直接寫
  defaults key 則不會持久也不會即時生效。
- **Apple 其他 app 自己的 item**（Weather、Passwords、Kerberos）當成第三方 app：用 bundle allow-list 藏、真實 ⌘-drag 可移動
  （`PC/MenuBarPolicy.swift:167-185`）。位於 `/System/Library/CoreServices/` 的 process（MenuBarAgent、Control Center、TextInputMenuAgent、
  `com.apple.screencaptureui` 錄影膠囊、Siri、Wi-Fi／AirPlay agent…）是「系統 UI」，不當 app 管理，只能透過 system item 編號處理（`:116-165`）。
- **Collateral extras**：任何 assertion 生效時，macOS 會順便拿掉一些自己的 extras——Now Playing、相機／麥克風膠囊、AirDrop、Focus、
  Timer、快速使用者切換、Live Activities——無法個別豁免（FAQ `:13-24`；`AgentBarEngine.swift:91-95`）。`pelmet-probe conceal-sys` 是用來
  試 0…8 以外的編號能不能保住它們（`PE/AssessmentMode.swift:44-50`；`pelmet-probe/main.swift:106-128`）；從 FAQ 的結論看【推論】不能。
  所以 Pelmet 自己做替身：Focus 狀態跟讀 `donotdisturbd` 的 unified log（`log stream` 子程序，`Pelmet/Extras/FocusStatus.swift:1-9`, `:39-40`）；
  使用者切換用私有 `login.framework` 的 `SACSwitchToLoginWindow`／`SACLockScreenImmediate`／`SACSwitchToUser`（`Pelmet/Extras/UserSwitching.swift:1-6`, `:51-89`）；
  媒體與相機狀態用 CoreAudio HAL 與 CMIO（`HELPER-PROCESS-PLAN.md:62-66`）。

### 列舉與身分

- **走 MenuBarAgent 自己的 AX tree**，不是逐 app 讀 `AXExtrasMenuBar`：`AXUIElementCreateApplication(MenuBarAgent 的 pid)` → children
  （每個 display 一個 `AXWindow`）→ 每個 item 一個 group（`PE/ItemEnumerator.swift:1-5`, `:42-76`；messaging timeout 0.25 s，`:88-102`、`EngineTiming.swift:20`）。
  - 第三方 item：group 裡巢狀一個擁有者 app 的 `AXApplication` 節點，`AXUIElementGetPid` → bundle ID（`:112-128`）。
  - 系統 item：`AXGroup` → `AXMenuBarItem`，`AXIdentifier` = `com.apple.menuextra.*`，歸在 `com.apple.MenuBarAgent` 名下（`:129-142`）。
  - 普通 `NSStatusItem` button（含 Pelmet 自己的）是裸的 `AXButton`（`:143-147`）；其他形狀（Little Snitch 自繪 view）用任一 child 的 pid 歸屬（`:152-164`）。
  - frame 取 **agent group 的 `AXFrame`**；同一 item 每個 display 各出現一次，優先保留主螢幕那份（`:56-72`, `:78-84`）。
  - 註解：被 host 的 item，在 app 自己節點下的 frame 位於「app 自己的螢幕外空間」，不能用幾何在多個 item 間配對（`:256-259`）。
  - 擁有者沒有 LaunchServices bundle ID（嵌在別的 app 裡的 helper 執行檔）時，用 `proc_pidpath` 往上找最近的 `.app` 並標記
    `bundleless`（`:201-228`）；這種 item 的擁有 process 不在 allow-list 的比對範圍內（`PE/MenuBarEngine.swift:14-18`）。
- 身分 tag 與 MenuBarAgent plist 同格式 `status:<bundleID>::<title>`；title 取 extras bar（`kAXExtrasMenuBarAttribute`，沒有就取最窄的
  `AXMenuBar`）第一個非空 child title，否則 `Item-0`（`:260-285`）。Time Machine 沒有 AX title，從 `com.apple.systemuiserver` 的
  `menuExtras` defaults 補名字（`:287-291`）。
- 不用 CGWindowList 或 SkyLight 列舉。CGWindowList 只用來判斷點擊後是否出現 menu／popover（`Pelmet/Press/ItemPress.swift:397-437`），
  以及擷取時排除疊在 bar 上的別人 window（`Pelmet/StatusItem/ConcealGhostOverlay.swift:124-160`）。
- **系統 `«` overflow 按鈕**：MenuBarAgent 擁有的 `AXButton`，**不在任何 AX 階層裡**，只能對 agent 的 app element 做
  `AXUIElementCopyElementAtPosition`、每 3 pt 掃描找到（system-wide hit-test 會被前景 app 的選單列擋住）；展開與否用
  `MenuBarAgent.app/Contents/Resources/MenuBarCore.loctable` 裡的在地化字串比對 `AXDescription`（`Pelmet/App/OverflowToggle.swift:1-58`, `:69-99`）。
  被 « 收起的 item 會回報彼此重疊的 phantom frame，Pelmet 用「frame 重疊」排除它們（`Pelmet/App/ApplyPass.swift:45-61`）。

### 移動：只在 Apply 時，用真實 HID ⌘-drag

- **實測（2026-09-20）**：MenuBarAgent 儲存的位置表對 live item 無效；只有真正的 HID ⌘-drag 會啟動 agent 的 drag session，送給 pid、
  或在 session／annotated-session 層級送出的事件「會送達但不會重排」（`docs/CORE-SETS.md:13-16`）。
- `ItemMover.cmdDrag`（`PE/ItemMover.swift:34-101`）：`CGEventSource(.hidSystemState)`，`userData` 設為 `0x504C4D54`（"PLMT"）以標記
  自己的事件（`:35-38`, `:177-179`）；⌘ mouseDown → 3 × 60 ms → `min(24, max(6, 距離/40))` 個內插 `leftMouseDragged`、間隔 30 ms →
  120 ms → mouseUp，全部 `post(tap: .cghidEventTap)`（`:51-93`）；結束後 `CGWarpMouseCursorPosition` 回原位（`:95-100`）。註解：每步跳太遠
  （74 pt）時 agent 追不到 slot crossing，item 會彈回。
- **Drag shield**（`:158-322`）：先等滑鼠閒置 0.25 s（最多 1.5 s，`:148-155`；`EngineTiming.swift:36-42`）；
  `CGAssociateMouseAndMouseCursorPosition(0)` 讓實體滑鼠不再移動游標；在獨立 thread 上建立 **active HID event tap**
  （`.cghidEventTap` + `.defaultTap`），吞掉所有沒有 PLMT 標記的實體滑鼠事件；`CGDisplayHideCursor`，並在每個事件後重設——因為 ⌘-click
  會把前景交給目標 app，系統隨之重設游標可見性與 association（`:63-76`, `:242-247`, `:273-322`）。所以 Pelmet **會移動游標**，只是藏起來
  並鎖住實體輸入。
- `ApplyPass`：`MovePlan`（weighted longest increasing subsequence）算出最少的移動（`PC/MovePlan.swift:167`, `:191`）→ 每個移動一次
  拖曳 → 等 bar 靜止 → 用 AX 順序驗證；沒到位就重新瞄準再拖一次，兩次都彈回原處就記為 immovable（`Pelmet/App/ApplyPass.swift:409-457`）。
  目標在 « 後面時先用 HID 點擊展開 «、移動、再收合（`:353`；`OverflowToggle.swift:120-191`）。
- 使用者自己在 bar 上 ⌘-drag 越過 chevron：只更新 membership，Pelmet 不做任何修正移動（`PC/BarAdoption.swift:1-52`；`CORE-SETS.md:46`）。
- `AgentPositionStore` 會寫 `com.apple.MenuBarAgent`（any-host）的 `TrailingItemPreferredPositions` 字典，間距 100（`PE/AgentPositions.swift:1-11`；
  `PE/AgentPositionStore.swift:11-63`），但這張表只在 MenuBarAgent 重啟時讀取、只影響新註冊 item 的落點；寫入＋重啟 agent 也不會讓 live item 換位置，
  因為 live item 的順序存在各 client process 的註冊裡（`CORE-SETS.md:23`；`AgentBarEngine.swift:312-322`）。所以 Pelmet 只把它當「自己的 item
  重新註冊時的落點 hint」。

### 打開隱藏 item（ItemPress）

- **一律合成點擊，從不 AXPress**（clock 是唯一例外，見下節）：AXPress 會讓 SwiftUI `MenuBarExtra` 的按鈕卡在 highlight 狀態，系統
  host／module 收到也沒反應（`Pelmet/Press/ItemPress.swift:13-17`）。
- 隱藏中的 item：`engine.reveal(items:)` 只把**那一個 bundle** 從 concealable 拿掉，區段維持收合、其他 item 不 reflow
  （`PE/AgentBarEngine.swift:185-201`）→ walk 到 frame 連續兩次穩定 → `ItemMover.shieldedClick` 在 item 中心送 HID 點擊（右鍵送
  rightMouseDown/Up）→ 用 CGWindowList 等「新的 elevated window／該 app 的新 window／該 app 到前景」出現再消失 → 放回去
  （`ItemPress.swift:112-252`, `:339-437`；`PE/ItemMover.swift:108-133`）。整段用截圖 cover 遮住，點擊後立即撤 cover，讓使用者看到真正的
  icon 與從它掉下的 menu。
- 被 « 收起的 item：先展開 «（只有真實 HID 點擊有效，AXPress 被拒，`OverflowToggle.swift:9-10`）。
- Pelmet 自己的替身 item 不點擊，直接執行對應動作（`ItemPress.swift:254-301`）。⌥⌘K 搜尋（0.3.1）用同一個 press relay（`docs/COMMAND-BAR.md`）。

### 通知中心 workaround（ClockClickRelay）

只要有任何 visibility restriction，Control Center 的 clock module 就拒絕打開通知中心（2026-09-03 實測：任何 allow-list、任何點擊來源都
一樣）；通知中心的服務都要私有 entitlement，雙指滑動又是 process 內從 multitouch frame 辨識，無法模擬（`Pelmet/Events/ClockClickRelay.swift:1-16`；
`PE/AgentBarEngine.swift:666-690`）。作法：在 `.cgSessionEventTap` 建 active tap，吞掉 clock 上沒有 modifier 的左鍵（`ClockClickRelay.swift:111-113`, `:141-176`）
→ 解除 assertion（「blink」，`engine.beginClockBlink()`）→ 等實體按鍵放開後對 clock 的 AX 元素做 `AXPress`，最多兩次，並輪詢通知中心是否
打開（`Pelmet/App/AppState.swift:1091-1130`；`ClockClickRelay.swift:297-308`）→ 重新 converge；期間用空 bar 的截圖蓋住。在 AXPress 打不開
通知中心的 build（例如 27.0.1）上會記住這個 build，改在 `.cghidEventTap` 重播 `clickState = 1` 的 HID 點擊（`ClockClickRelay.swift:310-350`；
`docs/release-notes/v0.3.1-beta.5.md:19`）。⌥⌘N 快捷鍵走同一條路（`docs/ISSUE-AUDIT-0.3.0.md` #44）。

### 擷取（只為動畫 cover）

- layout 編輯器與搜尋**只用 app icon／SF Symbol**：曾用 ScreenCaptureKit 裁切共用的 "Menubar" window，但非作用中 display 的 bar 會褪色、
  瀏海遮擋、tag 對不上，2026-08-21 移除（`Pelmet/Editor/ItemImageCache.swift:1-7`, `:36-60`）。
- Screen Recording 只用在 `ConcealGhostOverlay`：MenuBarAgent 每次 swap 都有自己無法關閉的動畫（reveal 滑入、conceal 原地淡出），
  Pelmet 的 Instant／Smooth／Fade 是在它上面播放兩張選單列截圖（空 bar、有 icon 的 bar）（`ConcealGhostOverlay.swift:1-9`）。
  用 `SCStream` 取一幀（`SCContentFilter(display:excludingWindows:)`，排除疊在 bar 上的別人 window），因為 `SCScreenshotManager` 的
  靜態截圖缺少 key window 投到 bar 底部的陰影，蓋上去會有色差（`:394-438`）。沒有權限就直接看系統動畫。
- 0.3.2-beta 的 `panel` 分支（不在本次 clone）新增「把隱藏 icon 顯示在 bar 下方的 panel」與擷取 item 圖像的「Picture pass」；被 « 收起
  的 item 退回 app icon（GitHub release v0.3.2-beta.4）。

### 其他

- 顯示觸發：hover（0.1–0.5 s，只在「螢幕中線到 chevron」這一段有效）、點空白處、雙擊或 ⌥-click chevron 顯示 Always Hidden、
  hotkey ⌥⌘, ／⌃⌥⌘,（README `:64-72`；FAQ `:179-184`）。滑鼠用全域 `NSEvent` mouseMoved monitor（`Pelmet/Events/MenuBarBandMonitor.swift:116-125`）。
- Per-display 行為（always show／collapse），以游標所在 display 為準；layout 是全域的，因為 macOS 在每個 display 畫同一組 item（FAQ `:113-116`）。
- Icon spacing：寫 per-host 全域 `NSStatusItemSpacing`／`NSStatusItemSelectionPadding`（最小 1 pt），然後對 MenuBarAgent 送 `SIGTERM`
  讓系統 icon 立即套用（agent 約 1 s 內自動重生），再自我重啟；其他 app 要重開或登出（`Pelmet/App/IconSpacingApplier.swift:25-49`；`PC/IconSpacing.swift:9-36`）。
- Accessibility 授權卡住時執行 `/usr/bin/tccutil reset Accessibility <bundleID>`；偵測 App Translocation（`Pelmet/App/AccessibilityAccess.swift:73-78`, `:93-95`, `:103-117`）。
- 讀 `com.apple.symbolichotkeys` 的 `AppleSymbolicHotKeys`，警告使用者選了系統已占用的快捷鍵（`Pelmet/Settings/ShortcutRecorder.swift:214-219`）。

### 與其他頁面的差異（待實測）

1. **27 上的位置寫入**：[macos-menu-bar-platform](../concepts/macos-menu-bar-platform.md) §5 引社群說法，Thaw 以「preferred-position writes」
   取代合成拖曳。Pelmet 實測 `TrailingItemPreferredPositions` 對 live item 無效（`CORE-SETS.md:13-16`, `:23`）。
2. **27 上不動游標的移動**：[menu-bar-item-moving](../concepts/menu-bar-item-moving.md) 引 Thaw 3.0 的 protocol，說 ⌘-drag 送到 MenuBarAgent、
   不進全域 HID 流。Pelmet 實測送給 pid 或 session 層級「會送達但不會重排」（`CORE-SETS.md:15`）。可能只是 Pelmet 沒找到方法（Thaw、Bartender 閉源）。
3. **AX frame 的來源**：[Frost](frost.md)、[Hidden Bar](hidden-bar.md)、[MenuBarHider](menubarhider.md) 在 27 上用各 app 的 `AXExtrasMenuBar`
   children 位置；Pelmet 說那些 frame 在 app 自己的螢幕外空間，改用 agent group 的 `AXFrame`（`PE/ItemEnumerator.swift:256-259`）。【未知】需實測。
4. **系統 icon**：[Hidden Bar](hidden-bar.md)、[MenuBarHider](menubarhider.md) 都允許 `0..<64`（不藏系統 icon）；Pelmet 證實拿掉編號就能藏，
   包括 Control Center 與 Clock。
5. **沒有 bundle ID 的 item**：[MenuBarHider](menubarhider.md) README 說一律被藏；Pelmet 觀察到相反的兩種結果——bundle-less helper 的 icon
   **藏不掉**（`Pelmet/App/UnhideableTracker.swift:1-7`；同一個 helper 在主程式執行時又藏得掉），/Applications 以外的 app 的 icon 則**被銷毀**
   （`Pelmet/App/CollateralTracker.swift:5-13`）。所以 Pelmet 不靠結構推論，只依實際觀察到的 bar 行為給徽章。

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| Accessibility | **必要** | 讀 MenuBarAgent AX tree（位置、身分）、合成 ⌘-drag 與點擊、active event tap（drag shield、clock relay）（README `:162-166`；FAQ `:34-36`） |
| Screen Recording | 選用 | 只為 Instant／Smooth／Fade 動畫 cover；沒有就看系統動畫（README `:168-172`；FAQ `:45-53`）。點 clock 時的擷取會點亮錄影指示（#45） |
| Input Monitoring | 不需要 | hotkey 用 Carbon，滑鼠用 `NSEvent` monitor 與 event tap |

**assertion 本身不需要權限**，但沒有 Accessibility 就無法列舉、也就算不出 allow-list。不 sandbox、hardened runtime、notarized
（README `:174-176`）。必須從 /Applications 執行：從 DMG 或 Downloads（App Translocation）執行時 TCC 授權會跟著暫存路徑消失（FAQ `:38-43`）；
在 Xcode DerivedData 跑的 app 沒有穩定的 LaunchServices 註冊，Pelmet 開著時會一直被藏（FAQ `:186-192`）。

## 已知問題

- **私有 API**：MenuBarClientCore 隨時可能改；失敗時回報 hiding unavailable，選單列維持全顯示（FAQ `:118-130`）。
- **bundle-less helper 的 icon 藏不掉**（ChatGPT Classic、Little Snitch monitor、部分 iStat helper）：只能關掉原 icon、改用 Pelmet 的
  App launcher（FAQ `:78-92`）。
- **/Applications 以外的 app 的 icon 會被 MenuBarAgent 銷毀**：agent 解析不到 host（log：`Host or location not found for disallowing
  status item: nil`），nil 永遠不在 allow-list 裡，Pelmet 允許了也沒用；iStat Menus 7 的 helper 在 `~/Library/Application Support`，
  做一個 /Applications 的 symlink 就正常（issue #30；`Pelmet/App/CollateralTracker.swift:5-13`）。
- Collateral extras 在隱藏期間消失（FAQ `:13-24`；#41、#68、#72）。
- 隱藏期間點 clock／按 ⌥A 打不開通知中心，只能靠 blink workaround（#44、#46、#74，#81 的留言仍有回報）。
- 瀏海機 bar 太擠時，Pelmet 自己的 chevron 會被系統 « 收進去（#81，open）；Synology Drive icon 失效（#75，疑似 helper 問題）。
- System Settings › Menu Bar 會多出兩列 "Pelmet Items"；把不可移除的 helper item 拖出 bar 會讓系統 disallow 整個 helper
  （`HELPER-PROCESS-PLAN.md:188-193`）。
- 作者自我審查（`ARCHITECTURE-REVIEW.md:90-185`）：`AppState` 是 god object；每次轉換原本有兩次約 100 ms 的 AX walk（後改用 rest snapshot）；
  `OverflowToggle` 的 `as! AXValue` 在 agent 重啟時可能 crash；合成拖曳約 1 s／次，10 個移動會佔用游標約 20 s；`AgentBarEngine`、`ItemMover`
  沒有測試。
- 2026-10-12 的 open issues：#86 依 icon 狀態智慧隱藏、#85 相機替身、#83 Siri 打字模式、#81、#75、#69 用黑 bar 蓋瀏海、#26 bar 下方的 tray。

## 對 Whisky 的參考價值

- **系統 icon 可以藏**：`allowedSystemItems` 是可控的，Whisky 的 27 engine 應把 0…8 當成可個別隱藏的 item（Clock、Control Center 可藏
  不可移）。代價是 collateral extras；Pelmet 自畫替身是一條路，但成本很高（`MediaControls.swift` 1.8k 行）。
- **adoption window 是 allow-list 路線必須處理的坑**：無縫 swap 讓新註冊的 item 一直 park 在螢幕外。在 [Hidden Bar](hidden-bar.md)、
  [MenuBarHider](menubarhider.md) 的頁面裡沒有記錄對應處理【推論：它們可能也會遇到】，Whisky 要內建，並用截圖 cover 降低閃爍。
- **列舉走 MenuBarAgent 的 AX tree**：一次 walk 拿到所有 item（含系統 item、每個 display 的副本、bundle-less host），順序就是畫面順序。
  可和 Frost 的逐 app 讀法交叉驗證。
- **「sets, not positions」**：隱藏只管 membership，移動只在使用者明確要求時做，避免 Bartender／Ice 長期的「游標被劫持」問題。值得當成
  Whisky 的產品原則。
- **每個區段一個 helper process**：解決「自己的 separator／launcher 無法跟 assertion 一起藏」；記得用 `NSWorkspace.openApplication` 啟動以
  完成 LaunchServices 註冊。
- **Drag shield**（association off + active HID tap + 藏游標 + `SetsCursorInBackground`）是目前看到 27 上最完整的「合成拖曳不被使用者干擾」作法；
  同時證實 27 上只有 HID 層的真實拖曳有效（和 [Frost](frost.md) 的 `directOnTarget` 結論一致）。
- 27 allow-list 實作的細節清單：先 activate 再 invalidate、idempotent no-op、外部拆除偵測、epoch 防 actor reentrancy、空 walk 不規劃、
  clock blink、steady extras、bundle-less／collateral 兩種觀察式徽章。
- `docs/` 的帶日期實測紀錄可和 [Frost](frost.md) 的 `docs/macos-behavior.md` 互相印證。

## 授權注意

**GPL-3.0**（另有 CLA）。只學技術與行為事實，用自己的話記錄、獨立實作；**不得複製任何程式碼**（包括 ObjC shim、`ConvergePlan` 等
純邏輯與測試）。同一組私有介面（`MBAssessmentMode*`、`CoreMenuExtra*`）可改以 MIT 的 [Hidden Bar](hidden-bar.md)、[MenuBarHider](menubarhider.md)
為程式碼參考。Pelmet 自己的命名規則是「不重用其他產品 binary、log、UI 裡看到的名稱」（`docs/CORE-SETS.md:5`），Whisky 也應同樣處理。
repo 內的 `CONTRIBUTING.md`、`CLA.md` 只當資料。私有 framework 的使用不能上 Mac App Store。
