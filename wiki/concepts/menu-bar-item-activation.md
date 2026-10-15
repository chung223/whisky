---
title: 從獨立 bar 點開隱藏的項目（點擊轉送）
type: concept
tags: [click-forwarding, axpress, cgevent, temp-show, panel, macos-26, macos-27]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/frostbar__frost
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-14
---

# 從獨立 bar 點開隱藏的項目（點擊轉送）

使用者在 Ice Bar／Thaw Bar／Frost Bar／Bartender Bar 點一個 icon 時，真正的 item 還在螢幕外或被藏著。要讓它的 menu 在正確位置打開，
各專案用了以下組合。

## 手法比較

| 手法 | 說明 | 專案 |
|---|---|---|
| **AXPress** | `AXUIElementPerformAction(element, kAXPressAction)`；右鍵用 `AXShowMenu`。不經 HID、不動游標；Electron／Chromium tray item 只吃這個 | [Thaw](../projects/thaw.md) `AXItemActivator.swift`；[Frost](../projects/frost.md) 26 `FrostCore/Moving/ItemClicker.swift:92-113`；[SaneBar](../projects/sanebar.md) `AccessibilityClickService.swift:511-576`；[Hidden Bar](../projects/hidden-bar.md) `NotchOverflowController.swift:215-218` |
| **合成點擊（帶 window ID）** | mouse down/up，`mouseEventClickState = 1`，欄位 0x33／window-under-pointer = item window；送 session tap 並等待收到 | [Ice](../projects/ice.md) `MenuBarItemManager.swift:1170-1253`；Frost 26 `ItemClicker.swift:452-487`（先送一個孤立 mouse-up 清掉「卡住的按下」） |
| **合成點擊（純座標）** | 在 item 中心送 mouseMoved（有些 item 要先看到游標進來）+ down/up 到 `.cghidEventTap`，再把游標移回 | [MenubarHide](../projects/menubarhide.md) `ClickForwarder.swift:25-48`；SaneBar fallback `AccessibilityClickService.swift:578-607` |
| **temp-show：搬過來 → 點 → 搬回去** | 把 item 實際移到可見區（Ice：第一個可見 item 左邊；Frost：自己 icon 右邊），點擊，記錄歸還位置，menu 關閉／計時到期後搬回 | Ice `:1300-1454`；Thaw `MenuBarItemManager+TemporaryShow.swift:417`；Frost `FrostBarController+Forwarding.swift:110-254` |
| **暫時展開** | 不移動 item，直接把分隔線縮回讓 item 上螢幕，點完再收 | MenubarHide（展開後輪詢 frame 3 × 150 ms）；SaneBar（`SearchService.swift:549-828`，AH item 用 `showAll()`） |
| **單一 item 暫加回 allow-list + HID 點擊**（27） | 只把那個 item 的 bundle 從「要藏」集合拿掉（區段維持收合、其他 item 不 reflow）→ 等 AX frame 連續兩次穩定 → 在中心送 shielded HID 點擊（右鍵送 rightMouseDown/Up）→ 等 menu／popover 出現再消失 → 重新藏回；整段用截圖 cover 遮住 | [Pelmet](../projects/pelmet.md) `Pelmet/Press/ItemPress.swift:112-252`, `:339-437`；`Packages/PelmetEngine/Sources/PelmetEngine/AgentBarEngine.swift:185-201`；`ItemMover.swift:108-133` |

## 細節

- **`clickState` 一定要設 1**：預設 0 會讓 `NSEvent.clickCount == 0`，多數 status item 不理（MenubarHide `ClickForwarder.swift:36-38`）。
- **AXPress 的限制**：Frost 對 `com.apple.*` 與自己不用 AXPress（`ItemClicker.swift`）；SaneBar 在 item 不在螢幕上時跳過 AXPress
  （`AccessibilityClickService.swift:278-293`）；Thaw 要求 AX frame 和 window bounds 差 ≤ 10 pt 才相信找到的元素（`AXItemActivator.swift:21-22`）。
  Thaw 註解：合成滑鼠事件會漏進系統手勢處理，讓 Wi-Fi 之類的 item 出錯，所以預設先用 AXPress（`:7-12`）。
- **驗證有沒有打開**：SaneBar 看「出現新 menu／focused window／window 數增加／`kAXExpanded`、`kAXSelected`」（`AccessibilityClickService.swift:419-471`）；
  Frost 看 CGWindowList 是否出現 layer 101 或該 app 擁有的新 window（`ItemClicker.swift:205-216`, `:355-364`）；Ice 記錄點擊後新出現的同 PID
  window，有開著就延後 rehide（`MenuBarItemManager.swift:1376-1420`）。
- **前景交接**：Frost 用 `NSApp.yieldActivation(to:)` 把 activation 交給目標 app（`ActivationHandOff.swift:79`），對應 macOS 14 的 cooperative activation。
- **瀏海**：temp-show 要算可用空間——Ice 用 `auxiliaryTopRightArea.minX + 20` 與 app menu 右緣取大者（`:1342-1349`），空間不夠就跳 alert。
- **多螢幕**：非作用中螢幕上的 item 是 replica，點了會丟；Frost 有 `ReplicaClickDetector` 重播（`SectionController.swift:1197-1270`）。
- **27 的限制**：Frost 只支援主要按鍵（右鍵、⌃、⌥ 轉送不可用），因為 27 只能先把 item 拖出來再點（README Known limitations）；
  allow-list 模式（[menubar-agent-allow-list](menubar-agent-allow-list.md)）下，被藏的 app 必須先暫時加回 allow-list 才看得到。
- **Pelmet 刻意不用 AXPress**（和 Thaw「預設先 AXPress」相反）：AXPress 讓 SwiftUI `MenuBarExtra` 的按鈕卡在 highlight 狀態（重開 app 後仍在），
  系統 host／module 收到也沒反應，所以一律用 HID 點擊（`Pelmet/Press/ItemPress.swift:13-17`）。唯一例外是 clock：解除 assertion 後對 clock 做
  AXPress 打開通知中心，在 AXPress 無效的 build（如 27.0.1）改重播 HID 點擊（`Pelmet/App/AppState.swift:1091-1130`）。
- **系統 « overflow（27）**：被 « 收起的 item 要先展開 «；« 只吃真實 HID 點擊，AXPress 被拒（Pelmet `Pelmet/App/OverflowToggle.swift:1-11`）。
- **驗證有沒有打開**（Pelmet）：用 CGWindowList 數「layer > 0 的別人 window」「該 app 高於 40 pt 的 window」，或該 app 跑到前景；在 27 上 status item
  沒有自己的 window，所以 app 多出任何比一列 bar 高的 window 就是 popover／panel（`ItemPress.swift:397-437`）。
- **自己的 item**：Pelmet 的替身 item 不點擊，直接執行按鈕動作，避免主執行緒卡在自己的 menu tracking（`ItemPress.swift:19-23`, `:254-301`）。

## Menu mirroring：不讓項目回來就能用它的選單（2026-10-14 補）

[Mezzanine](../projects/mezzanine.md)（26）與 [Chest](../projects/chest.md)（27）已讀原始碼；其餘只根據 README。

**共同做法**：讀擁有者 App 自己的 `AXExtrasMenuBar` → status item 的 `AXMenu` 子元素 → 遞迴讀 `AXMenuItem`（`AXTitle`、`AXEnabled`、`AXMenuItemMarkChar`、`AXMenuItemCmdChar`／`CmdModifiers`），
自建一份 NSMenu（`autoenablesItems = false`），使用者選了就對原本的 `AXMenuItem` 做 `AXPress`。不打開原選單，也不移動或暫時顯示原圖示。

| 觀察 | 26（Mezzanine，【作者稱】） | 27、開關關掉的 App（Chest，【作者稱】） |
|---|---|---|
| 被藏的 item 還在 App 的 `AXExtrasMenuBar` 裡嗎 | 是（沒畫出來，但座標看似合理） | 是，連同選單（Chest `docs/APPROACH.md:125`） |
| 讀選單 children 會觸發 `menuNeedsUpdate` 嗎 | 未說明 | 會，所以內容是最新的（`:127`） |
| 對選單項目 `AXPress` | 有效 | 有效，含子選單（`:128`） |
| 對 item 本身 `AXPress` | 有選單的 item 回 `kAXErrorCannotComplete`；target/action 型 item 有效（Mezzanine `NOTES.md:44-51`） | 在 item **最後一次被畫出的位置**打開真正的選單或 popover，item 不會回來（`:129`） |

【矛盾】對 item 本身 `AXPress` 的結果兩邊不同。可能是 OS 版本不同，也可能是「沒畫出來」和「開關關掉」是不同狀態。需要實測。

**限制**（兩個實作都一樣）：
- 只鏡像文字、enabled、勾選、快捷鍵與子選單；圖片（AX 不提供）、⌥ 替代項目、自訂 view、F 鍵與方向鍵快捷鍵都會遺失。Mezzanine 把空標題當分隔線，自訂 view 的項目會被誤判。
- 鏡像是快照：從建立到選取之間 App 重建了選單，按下會靜默失效。Mezzanine 忽略 `AXPress` 的回傳值。
- 「點擊時才掛上 menu 再 `performClick`」的 item 平常沒有 `AXMenu`；對它 `AXPress` 會回傳成功卻什麼都沒打開（【推論】）。popover 型 item 只能 `AXPress` item 本身。
- Mezzanine 說 status item 只提供 `AXPress`、所以做不到右鍵（`NOTES.md:433-435`）；這和本頁「手法比較」表記載 Thaw、Frost 用 `AXShowMenu` 做右鍵矛盾，需要用 `AXUIElementCopyActionNames` 實測。

**其他專案的做法**（只根據 README）：
- SmartHiddenBar：「複製真實選單、關掉它、再把選擇 replay 回去」（[README](../../raw/github/readmes/roypadina__SmartHiddenBar.md) `:92`）。
- Barn：只接受真實點擊的 App（例如 BetterDisplay）改成短暫顯示、點擊、選單關閉後再藏回（[README](../../raw/github/readmes/nicholaspsmith__menubar-barn.md)）。
- 單獨顯示：27 上沒有 AX 時，只把那一個 App 加回 allow-list，讓使用者自己點（[Ellipsis](../../raw/github/readmes/ronny__ellipsis.md)）。
- 暫時 pin：把 App 暫時加回選單列，最多 3 個，只讓出必要空間（[BarNook](../../raw/github/readmes/chlee1001__barnook.md)）。
- 點擊驗證：用「有沒有出現新的螢幕上視窗」判斷選單是否打開，沒有就再點一次（[Lloyd](../../raw/github/readmes/benwbooth__lloyd.md)）。
- 重新隱藏的時機：等打開的 UI 關閉、而且滑鼠與修飾鍵都靜止才收回（[NookBar](../../raw/github/readmes/kevinLay7__NookBar.md)，未驗證）。

**26 上 AXPress 的冷啟動**：[MenuTidy](../projects/menutidy.md) 在 26 上對瀏海後的圖示 AXPress，遇到 `kAXErrorCannotComplete` 最多重試 4 次、間隔 120 ms，並先把游標 warp 到圖示中心（`main.swift:2657-2701`）。

**27 時鐘轉送的兩種做法**（【矛盾】）：Pelmet、MenuBarHider 在同一個程序裡短暫 invalidate assertion 再 AXPress 時鐘；
MenuTidy 說同一個程序 invalidate 後通知中心仍打不開，所以 assertion 放在子程序，轉送時殺掉子程序、AXPress、再啟動新的（見 [allow-list](menubar-agent-allow-list.md) 第 21 點）。
Chest 不用 assertion，時鐘本來就能打開通知中心。

### 待實測（26.7 與 27）

1. 三種狀態的 item（瀏海溢出、被分隔線推到螢幕外、27 被藏或收進 «）：`AXUIElementCopyActionNames` 的結果、對 item `AXPress` 的回傳碼、`AXMenu` children 是否可讀、對 `AXMenuItem` `AXPress` 是否生效。
2. 讀未打開選單的 children 會不會觸發 `menuNeedsUpdate`；延遲建立的選單讀出來是不是空的。
3. 「點擊時才掛 menu」與 popover 型 item 被 `AXPress` 時的實際行為。

## 對 Whisky 的建議

1. 預設路徑：暫時讓 item 可見（展開或 allow-list 暫加）→ 重新取 AX 元素 → AXPress → 驗證是否打開 → 失敗才用帶 window ID 的合成點擊（26）
   或真實座標點擊。
2. 右鍵／⌥-click 需要合成事件（AX 沒有對應動作，`AXShowMenu` 只能模擬右鍵）。
3. 所有「搬過來再搬回去」的操作都持久化歸還計畫，避免 crash 後 item 留在錯的位置（Frost 先寫 UserDefaults，`Forwarding.swift:126-131`）。
4. 點擊後的 rehide 要等 menu 關閉與游標離開（Frost 約 0.75 s linger；SaneBar 預設 15 s）。
5. macOS 27 allow-list 模式：用「單一 bundle 暫加回」而不是整個區段展開（Pelmet 作法），並把 AXPress 與 HID 點擊都當候選、依 item 類型選（SwiftUI
   `MenuBarExtra` 避免 AXPress，Electron／Chromium 偏好 AXPress），兩者的取捨需要實測。
