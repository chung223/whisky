---
title: 移動與重新排列選單列項目
type: concept
tags: [moving, cgevent, cmd-drag, event-tap, preferred-position, macos-26, macos-27]
sources:
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/frostbar__frost
  - raw/github/repos/frostbar__frost/docs/macos-behavior.md
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/junior-rj__menubar-hide
  - https://github.com/thaw-app/Thaw/tree/feat/thaw-3
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-14
---

# 移動與重新排列選單列項目

macOS 只允許**使用者**用 ⌘-drag 重排 status item，沒有 API 讓 app 移動別人的 item。所有能「排列」的開源專案都在**模擬 ⌘-drag**；
唯一例外是直接改別人 preferences 裡的位置值。

## 手法比較

### 1. Window-ID 路由的「瞬移」⌘-drag（Ice 系，≤ 26）

[Ice](../projects/ice.md) 首創、[Thaw](../projects/thaw.md) 與 [Frost](../projects/frost.md)（26）沿用：

- 事件來源 `CGEventSource(stateID: .hidSystemState)`。
- mouse-down 帶 `.maskCommand`，位置**不在 item 上**：Ice 放在 `(20000, 20000)`（`Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift:998`）；
  Frost 放在自己 icon 的中心（`Packages/FrostCore/Sources/FrostCore/Moving/ItemMover.swift:223`）。
- 關鍵是事件欄位：未公開的 **`CGEventField(rawValue: 0x33)` = 目標 window ID**，加上 `mouseEventWindowUnderMousePointer`、
  `mouseEventWindowUnderMousePointerThatCanHandleThisEvent`、`eventTargetUnixProcessID`（Ice `:1550-1561`, `:1638-1663`；Frost `ItemMover.swift:681-683`, `:769-775`）。
  WindowServer 依 window ID 把拖曳交給那個 item，而不看座標。
- mouse-up 放在目標 item 的左緣或右緣（Ice `:597-610`；Frost `:613-618` 用 minX+1／maxX−1）。
- 不送 `leftMouseDragged`（Frost 26 `:785`, `:806`）；Thaw 另有送內插 drag 的 `faithfulDrag` 策略（`MenuBarItemManager+MoveEvents.swift:33-49`）。
- 投遞與確認：Ice 的「scrombleEvent」先送 null event 到目標 PID 的 tap、收到後再送真事件進 session tap，並用 listen-only tap 確認流過（`:761-859`）；
  Frost 每 10 ms 輪詢直到看到 item 被拎起再送 mouse-up（`:787-803`）。
- 防止系統把合成事件期間的使用者輸入吃掉：`setLocalEventsFilterDuringSuppressionState(.permitAllEvents…)` + `localEventsSuppressionInterval = 0`
  （Ice `:920-933`；Frost `:748-755`）。
- **Tahoe 要點**：事件要送給 **window 擁有者（Control Center）** 的 PID，而不是建立 item 的 app（Thaw `MenuBarItemManager+EventHelpers.swift:387-400`）。
- 驗證：比對 frame（Ice `:638-654`、最多 5 次重試 `:1114-1134`）；Frost 用 CGWindowList 依 minX 排序、3 次相同快照才算穩定（`:567-575`, `:661-677`）。
- 游標：移動前隱藏、結束後 warp 回原位（Ice `:1107-1112`）；但 `CGWarpMouseCursorPosition` 會把螢幕外座標夾到 Apple menu 底下造成誤點，
  Thaw 只在目標在螢幕上時 warp（`MenuBarItemManager+MoveEvents.swift:212-240`）。私有 `SetsCursorInBackground` 讓背景 app 能隱藏游標
  （Ice `AppState.swift:80-81`；Thaw `AppDelegate.swift:73`；Frost `FrostCore/Moving/CursorConcealment.swift:4-31`）。
- 防呆（Thaw）：目標 PID 已死就不送（tap 會建出無效 port、白等 3.5 s）、目標 app 被 `CGSEventIsAppUnresponsive` 判定卡住就跳過
  （`:166-181`）；有 circuit breaker 與失敗帳本。

（2026-10-15）Whisky 0.2.0 在使用者的 MacBook Pro 14"（macOS 26.7）上照這個做法實作，兩個方向都一次到位，見 [平台實測](platform-verification.md) S3。

### 2. 真實的 ⌘-drag（從 item 本身開始）

- [SaneBar](../projects/sanebar.md)：完全公開 API，`CGEvent(mouseEventSource: nil, …)` 送 `.cghidEventTap`：mouseMoved → 60 ms → 隱藏游標 → ⌘ mouseDown →
  80 ms → 10–14 個 ⌘ `leftMouseDragged`（15 ms 間隔）→ ⌘ mouseUp → 140 ms（`Core/Services/AccessibilityMenuBarDragService.swift:445-623`）。
  失敗改用 `.cgSessionEventTap` 重試（`MenuBarStandardIconMoveWorkflow.swift:259-308`）。前後都用 AX 位置驗證。
- [Frost](../projects/frost.md) 27（`directOnTarget`）：**macOS 27 上 0x33 路由完全無效**，只有從 item 中心開始的真實拖曳會動：⌘ mouseMoved + mouseDown →
  80 ms → +2 pt 拎起 → 20 個內插 drag（10 ms）→ 120 ms → mouseUp（`ItemMover.swift:466-509`）。事前把所有 section 展開並用
  `AXUIElementCopyElementAtPosition` 確認該點真的是目標（`AXExtrasReader.swift:118-132`），事後重讀 AX 順序最多 10 次。
  實測：放開後 item 會落在 mouse-up 點略左；拖進空白區會被解析到 Frost 自己的分隔線（`docs/macos-behavior.md` 表格「Where a dropped icon lands」）。
- [Thaw](../projects/thaw.md) 3.0（macOS 27，閉源核心）：公開的 protocol 說 ⌘-drag 「delivered to the menu bar's owning process」（MenuBarAgent），不進全域 HID 流、
  不移動使用者游標（`MenuBarModel/Sources/MenuBarModel/MenuBarItemDragging.swift` @ `feat/thaw-3`）。具體作法在 PlatformRuntimeKit 中，不可參考。
  SaneBar 的文件也提到 Bartender 的 27 版「without touching your mouse」移動 item，靠的是未公開的 MenuBarAgent API（`docs/NOTCH_MOVE_LIMITATION.md:77-82`）。
- [Pelmet](../projects/pelmet.md)（macOS 27，GPL-3.0；路徑相對於 `raw/github/repos/fif7y__pelmet/`，`PE/` = `Packages/PelmetEngine/Sources/PelmetEngine/`）：
  - 實測（2026-09-20）：只有 HID 層的真實 ⌘-drag 會啟動 MenuBarAgent 的 drag session；送給 pid、或在 session／annotated-session 層級送出的事件
    「會送達但不會重排」（`docs/CORE-SETS.md:13-16`）。和 Frost 的 `directOnTarget` 結論一致。
  - `ItemMover.cmdDrag`：source `.hidSystemState`，`eventSourceUserData` 設成固定標記以分辨自己的事件；⌘ mouseDown 在 item 中心 → 3 × 60 ms →
    `min(24, max(6, 距離/40))` 個內插 drag（30 ms 間隔）→ 120 ms → mouseUp，全部送 `.cghidEventTap`；結束後 warp 回原位（`PE/ItemMover.swift:34-101`）。
    每步跳太遠（74 pt）時 agent 追不到 slot crossing，item 會彈回（`:78-81`）。
  - **drag shield**：先等滑鼠閒置 0.25 s（最多 1.5 s）；`CGAssociateMouseAndMouseCursorPosition(0)`；獨立 thread 上的 active HID event tap 吞掉所有沒
    標記的實體滑鼠事件；`CGDisplayHideCursor` 並在每個事件後重設，因為 ⌘-click 會把前景交給目標 app，系統隨之重設游標可見性與 association；
    背景隱藏游標靠 `SetsCursorInBackground`（`PE/ItemMover.swift:148-322`）。
  - **只在使用者按 Apply 時移動**（「sets, not positions」）：隱藏只看 membership，背景、hover、顯示／收合、開機、新 item 都不觸發拖曳
    （`docs/CORE-SETS.md:18-24`）。`MovePlan` 用 weighted LIS 算最少移動，每次拖完用 AX 順序驗證，失敗重瞄一次，兩次都彈回就記為 immovable
    （`Pelmet/App/ApplyPass.swift:409-457`）。目標在系統 « 後面時，先用 HID 點擊展開 «（AXPress 被拒）、移動、再收合（`Pelmet/App/OverflowToggle.swift:1-11`, `:120-191`）。
  - 【矛盾】上一條 Thaw 3.0「送到 MenuBarAgent、不進 HID 流」的說法與 Pelmet 的實測不合；可能只是 Pelmet 沒找到方法，Thaw／Bartender 的作法閉源，仍列【未知】。

### 3. 改寫別人的 `NSStatusItem Preferred Position`（不模擬事件）

[MenubarHide](../projects/menubarhide.md)：用 `CFPreferencesCopyKeyList`／`CopyValue` 讀所有 app（含 sandbox container 的 plist 路徑）的
`NSStatusItem Preferred Position *` key 存成快照，之後用 `CFPreferencesSetValue` 寫回（`MenubarHide/MenuBarArrangement.swift:31-142`）。
只在該 app **下次啟動**時生效。macOS 27 上這個表格歸 MenuBarAgent、放在受 TCC 保護的 container，per-app key 不再決定位置
（MenubarHide `AGENTS.md:42`；Frost 表格「Saved positions」），功能失效。

macOS 27 的對應表：MenuBarAgent 把 trailing item 的順序存在 `com.apple.MenuBarAgent`（any-host）的 `TrailingItemPreferredPositions` 字典，key 像
`com.apple.MenuBarAgent:com.apple.menuextra.wifi`、`<bundleID>:Item-0`（[Pelmet](../projects/pelmet.md) `Packages/PelmetEngine/Sources/PelmetEngine/AgentPositions.swift:1-26`）。
Pelmet 實測：寫入的值對 live item 一律無效（不管隱藏／重新允許、值在不在範圍內）；寫入＋重啟 agent＋隱藏／顯示循環都不會讓 live item 換位置，
因為 live item 的順序存在各 client process 自己的註冊裡；這張表只在 agent 重啟時讀取，且只影響**新註冊**（app 重新啟動、全新 item）的落點。
真實 ⌘-drag 的結果即使沒有寫到磁碟也能撐過 agent 重啟（`docs/CORE-SETS.md:13-14`, `:23`；`AgentBarEngine.swift:312-322`）。所以 Pelmet 只把它當
「自己的 item 重新註冊時的落點 hint」（`AgentPositionStore.swift:11-63`）。【矛盾】[macos-menu-bar-platform](macos-menu-bar-platform.md) §5 引社群說
Thaw 在 27 上以「preferred-position writes」取代合成拖曳；兩者不合，待實測（例如 Thaw 是否搭配讓 app 重新註冊 item）。

### 4. 用「Allow in the Menu Bar」開關重新落位（27，2026-10-14 補）

[Chest](../projects/chest.md) 不合成任何拖曳：在 App 的開關關著時寫好位置，再打開開關，項目就落到那個位置【作者稱】（Chest `docs/APPROACH.md:106`）。
自己的圖示要移位時，也是寫位置後把自己的 entry 關掉 1.5 s 再打開（`ChestController.swift:516-576`）。

位置表（Chest `docs/APPROACH.md:95-104`）：

```
~/Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist
TrailingItemPreferredPositions（dictionary）
  "status:<bundle ID>::<autosave name>" → 距離右端的距離（越大越靠左）
  "module:Clock" → MenuBarAgent 自己的項目
```

【矛盾】§3 引用 Pelmet 的位置表是 `com.apple.MenuBarAgent` domain、key 格式 `<bid>:Item-0`，而且寫入對執行中的 item 無效。
【推論】兩者可能都對：開關 off／on 等於讓 item 重新註冊，正好符合「只影響新註冊的 item」；domain 與 key 格式的差異可能來自版本（Pelmet 記的是 27.0 beta，Chest 是 27.0.1）。需要實測。

### 5. 送到 session tap 的定址事件（26，放棄的實驗）

[Mezzanine](../projects/mezzanine.md) 的 `mover-wip` 分支【作者稱】：事件設 `mouseEventWindowUnderMousePointer`、`eventTargetUnixProcessID` 和 field 51，送到 **session tap**（HID tap 會拉動游標），
約 65 ms 就能移動別人的 item，連沒畫出來的也移得動；但組合成目標排列時約一半失敗，無法收斂（`NOTES.md:441-462`）。
這也印證了 Ice 的做法：每次只移動自己的分隔線，temp-show 只移動一個 item。

## 共同的坑

| 坑 | 出處 |
|---|---|
| 拖曳路徑穿過瀏海會被 WindowServer 默默丟掉 | [SaneBar](../projects/sanebar.md) `docs/NOTCH_MOVE_LIMITATION.md:19-25`；Thaw 有 `crossNotchTeleport` 策略 |
| 選單列設為自動隱藏時無法排列 | [Ice](../projects/ice.md)／[Thaw](../projects/thaw.md) `FREQUENT_ISSUES.md` |
| 使用者按著 modifier 或正在移動滑鼠時不要開始 | Ice `:1082-1088` |
| live-text item（時鐘、溫度）會落在附近而非精確位置 | Thaw `FREQUENT_ISSUES.md:244-250` |
| 自動移動（例如喚醒後復原）要節流，否則會「劫持」游標 | SaneBar `MenuBarAutomaticMoveGate.swift:11-93`（每分鐘 ≤ 6 次） |
| 27 上拖曳可能觸發 Mission Control | SaneBar `.github/workflows/sunset-auto-close-issues.yml:38-42` |
| 27 上新 item 落在 trailing area 第一個空位；新 autosave name 一律落在最左 | Frost `docs/macos-behavior.md`；MenubarHide `AGENTS.md:42` |
| 27 上被系統 « 收起的 item 回報彼此重疊的 phantom frame，拖它會「彈回」 | [Pelmet](../projects/pelmet.md) `Pelmet/App/ApplyPass.swift:45-61` |
| ⌘-click 會把前景交給目標 app，系統隨之重設游標隱藏與 mouse association，要在每個事件後重設 | Pelmet `Packages/PelmetEngine/Sources/PelmetEngine/ItemMover.swift:63-76` |
| 拖自己 process 的 item 時，事件不能從 main actor 送（會和 AppKit 的 drag tracking 交錯，放下後還原） | Pelmet `ItemMover.swift:26-31` |
| Clock、Control Center、SystemUIServer extras（Siri、Time Machine）在 27 上位置固定，拖不動 | Pelmet `Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:83-91`, `:187-194` |

## 對 Whisky 的建議

- macOS 26：沿用 window-ID 路由（`0x33`）+ 送給 Control Center PID，搭配確認式投遞與 frame 驗證；或走 SaneBar 的純公開真實拖曳當備援。
- macOS 27：目前公開可行的只有 Frost 的「從 item 本身開始的真實 ⌘-drag」+ AX 驗證；會短暫展開所有 section、需要隱藏游標。
  「不動游標、直接對 MenuBarAgent 下指令」的作法目前只存在於閉源產品（Bartender、Thaw PlatformRuntimeKit），列為【未知】待研究。
- 所有移動都包成 transaction：記錄歸還計畫、可中斷、可在 crash 後復原（Frost `RestorePlan`、Thaw move transaction）。
- 27 上可再參考 [Pelmet](../projects/pelmet.md) 的 drag shield 與「只在使用者明確要求時移動」原則；隱藏走 allow-list 時，位置與隱藏無關，背景移動可以完全不做。
