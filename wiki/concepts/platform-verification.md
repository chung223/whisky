---
title: 平台實測紀錄
type: concept
tags: [macos-26, verification, notch, cgwindowlist, spikes]
sources:
  - app/Whisky/Scanning/WindowList.swift
  - app/Packages/WhiskyCore/Tests/WhiskyCoreTests/MenuBarGeometryTests.swift
updated: 2026-10-15
---

# 平台實測紀錄

[路線圖](../synthesis/roadmap.md) M0 各個 spike 在真機上的結果。每筆都寫明機器、系統版本與量測方式。

## 2026-10-14：MacBook Pro 14"（Mac16,8，M4 Pro），macOS 26.7（25G229）

量測方式：從終端機跑一支 Swift 腳本，讀 `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements])` 裡 layer 25（`kCGStatusWindowLevel`）的視窗，以及 `NSScreen` 的瀏海資訊。
這些欄位不需要權限；`kCGWindowName` 有讀到值，但終端機當時有沒有 Screen Recording 權限沒確認。

**螢幕**：1512 × 982 pt，`safeAreaInsets.top` = 32，`auxiliaryTopLeftArea` = (0, 950, 663, 32)，`auxiliaryTopRightArea` = (848, 950, 664, 32)。
【觀察】主螢幕上這兩個 rect 是 global 座標（和 `NSScreen.frame` 同一個空間）。

**S2（擁有者）**：【觀察】選單列上每一個 status item 視窗的擁有者都是「控制中心」（Control Center，pid 906），包括第三方 App 的項目。
同一層還有：App 自己的零寬度視窗（iStat Menus Menubar 在 x = −300、WeatherMenu），以及較高的 popover 視窗（貼貼、Cloudflare WARP、FineTune，y > 0）。所以要用 `y == 0`、高度 ≤ 選單列高度來篩。

**`kCGWindowName`**：【觀察】值是項目的 autosave name 或識別字：`WhiskyIcon`、`WiFi`、`Clock`、`BentoBox-0`、`Siri`、`com.apple.menuextra.TimeMachine`、`com.bjango.istatmenus.cpu`；沒有設定的是 `Item-0`。

**有沒有畫出來**：【觀察】`kCGWindowIsOnscreen` 精確對應「有沒有被畫出來」：
- 31 個項目裡只有 11 個是 true，全部完整落在 x ≥ 848（瀏海右緣）。
- 跨在瀏海邊界上的項目（x 827，寬 44，右緣 871）是 false。
- 瀏海左邊的 20 個項目全部是 false，雖然它們的 x（111–827）仍在螢幕範圍內。
這和 [Mezzanine](../projects/mezzanine.md) 的規則一致（只畫完整落在 `auxiliaryTopRightArea` 內的項目），而且比幾何推算更直接。
[MenuTidy](../projects/menutidy.md) 說的 14–30 pt 死帶在這台沒有觀察到：x = 871 的項目（距瀏海 23 pt）有畫出來，但也沒有剛好落在 848–870 之間的項目可以驗證。

**Preferred Position = 0**：【觀察】Whisky 第一次啟動前寫 `NSStatusItem Preferred Position WhiskyIcon = 0`，圖示落在 Wi-Fi 和控制中心（`BentoBox-0`）之間（x = 1231），不是控制中心右邊。
原本最左邊可見的項目（iStat Menus 磁碟）因此被擠到瀏海後面。

### 2026-10-15：Whisky 取得 Accessibility 後的 AX 掃描（S8 前半）

量測方式：Whisky 0.1.0 收到 `kill -USR1` 後掃描所有程序的 `AXExtrasMenuBar`，對每個項目記錄 `AXUIElementCopyActionNames`，並對沒畫出來的項目讀 `AXMenu` 的內容（只讀，不按）。

- **AX 與視窗對得上**：第一次掃描得到 48 個項目、38 個「沒畫出來」，誤差來自三件事，修正後是 31 個項目、22 個沒畫出來，和 CGWindowList 一致：
  1. 【觀察】15 個 App（Claude、Telegram、LINE、Cloudflare WARP、AdGuard VPN、幾個銀行憑證元件等）的 status item 仍在 `AXExtrasMenuBar` 裡，但 AX frame 在螢幕左下角（x ≈ −1 或 7、y ≈ 981），也沒有對應的選單列視窗。
     【推論】這些是在系統設定「允許在選單列中顯示」關掉的 App（未向使用者確認）。所以「在不在選單列那一列」要另外判斷，不能只看有沒有畫出來。
  2. 【觀察】控制中心自己的 `AXExtrasMenuBar` 會再列一次某些第三方項目的外框（Surge、Lofi Garden），兩個 AX 元素對到同一個視窗；要以視窗去重、保留真正的擁有者。
  3. 【觀察】有些項目的 AX frame 比選單列高（Foresight：y = −24.5、高 82），對位要比中線，不能比上緣。
- **動作**：【觀察】31 個項目（畫出來的和沒畫出來的都一樣）只提供 `AXPress`，部分多一個 `AXCancel`；**沒有任何項目列出 `AXShowMenu`**。
  這支持 [Mezzanine](../projects/mezzanine.md) 的說法，和 [點擊隱藏項目](menu-bar-item-activation.md) 記載的「Thaw、Frost 用 `AXShowMenu` 做右鍵」矛盾（未列出不代表執行一定失敗，待測）。
- **選單讀取**：【觀察】22 個沒畫出來的項目中，13 個讀得到 `AXMenu`（例如 Presence 12 項、Mosaic 35 項、Keysmith 9 項），可以 mirroring；
  9 個沒有選單：iStat Menus ×3、天氣（WeatherMenu）、FineTune、SpyderUtility、Plaud、SystemUIServer ×2（Time Machine、Siri）、MenuBarUSB。這些是 popover 或自訂下拉視窗，只能靠 `AXPress`。
- **還沒驗證**：對沒畫出來的項目 `AXPress` 會不會打開它的 UI、出現在哪裡（S8 後半，要實際點）；S1、S3。

### 2026-10-15：以 `0x33` 指定視窗的 ⌘ 拖曳（S3）

量測方式：Whisky 0.2.0 透過 `whisky://pin`／`whisky://unpin` 觸發，記錄在 `~/Library/Logs/Whisky/whisky.log`。做法照 [Frost](../projects/frost.md) 在 26.6.2 上的實測：
mouse-down 落在 Whisky 自己的圖示中心、帶 ⌘ 與欄位 `0x33`（被拖項目的視窗 ID）、送到 `.cgSessionEventTap`；輪詢 CGWindowList，等項目被拎起（視窗離開原位）再送 mouse-up 到目標旁邊；游標全程隱藏（`SetsCursorInBackground`）後放回原位。

- 【觀察】**把瀏海後面的項目放到 Whisky 圖示左邊**（iStat Menus 磁碟，視窗 316 → 16968 左邊）：拎起 120 ms、放開 591 ms（目標會滑動，等選單列靜止），第一次就到位。最左邊可見的項目（iStat 記憶體）因空間不足被擠到瀏海後面。
- 【觀察】**把可見項目送到最左邊**（同一個項目 → 最左邊項目 16497 的左邊，x = 68）：拎起 45 ms、放開 84 ms，第一次就到位；被擠掉的記憶體自動回到可見區。
- 【觀察】`NSStatusItem.button.window.windowNumber` 在 26.7 上超出 `UInt32` 範圍（不是 CGWindowList 裡的 ID）；Whisky 的圖示在 CGWindowList 裡是另一個 ID（16968，擁有者是控制中心）。要用按鈕的螢幕位置去對位。直接 `UInt32(windowNumber)` 會當掉。
- 【觀察】沒有 Screen Recording 時讀不到 `kCGWindowName`（終端機讀得到，Whisky 讀不到），所以 Whisky 的項目識別字退回 `bundleID-Item-<序號>`，和 Bartender 的 `bundleID-<autosave name>` 對不上。
- 【觀察】Whisky 當掉、自己的圖示消失時，iStat Menus 會自己重排它的幾個項目（磁碟從 Surge 左邊換到右邊）；重開 Whisky 後圖示回到 autosave 的位置。

### 2026-10-15：排列（多步套用）與 Bartender 版面對照

- 【觀察】`whisky://apply` 連續兩次對調、還原 AlDente 與 One Switch：各 1 步、第一次就到位，拎起 40–95 ms、放開 410–575 ms。
- 【觀察】**Cloudflare WARP 一直開著一個 20 × 1 pt、layer 101（`popUpMenuWindow`）的視窗**（螢幕左下角）；Typeless（layer 1001）與 MonitorControl（layer 1000）各有一個 1 × 1 的視窗。
  只看 layer 判斷「有選單開著」會永遠為真，讓每一步多等 3 秒；改成同時要求寬 ≥ 40、高 ≥ 20 後，每步約 1 秒。（[MenuTidy](../projects/menutidy.md) 用「layer 剛好等於 101」排除了高層級視窗，但擋不住這種同層的小視窗。）
- 【觀察】iStat Menus 的 defaults 有 5 個 `NSStatusItem Preferred Position com.bjango.istatmenus.<名稱>`（cpu 428、memory 496、sensors 1005、weather 1195、disks 1411），依數值由大到小正好是 5 個項目由左到右的順序；
  Whisky 用這個在沒有 Screen Recording 時推回 autosave 名稱，Bartender「顯示」清單因此能對上 iStat 的磁碟、記憶體、CPU。
- 【觀察】Bartender「顯示」清單 16 筆對上 10 個執行中的項目；其餘是沒在執行的 App，以及 bundle ID 不同的同一個 App（清單記 `com.chung.pastee.mac`，執行中的是 `com.chung.pastee.ios`）。
  控制中心的 Wi-Fi 靠 AX 標題（「Wi‑Fi，已連接，3格」）對上 `com.apple.controlcenter-WiFi`。

### 2026-10-15：分隔項目（spacer）測試失敗與瀏海邊界行為

在使用者的真實選單列上測 Whisky 0.4 的分隔項目，造成版面被打亂，之後花了 9 次移動才大致還原（最後 MenuBarUSB 換成 Lofi Garden 可見、Surge 移到右端）。教訓與觀察：

- 【觀察】**用按鈕的螢幕位置找分隔項目的 CG 視窗不可靠**：分隔項目在瀏海後面、而且一直在改長度時，AppKit 端的 button frame 對到了別的項目，
  2 秒一次的自動調整因此進入回饋迴圈（長度 109 → 148 → 216 → … → 429），把可見的圖示一個個推到瀏海後面。Whisky 的圖示（畫得出來、長度固定）用同樣方法則一直對得上。
  → 自己的項目要在建立時用「建立前後的視窗清單差集」記住視窗 ID，或用 AX 讀自己程序的 `AXExtrasMenuBar`；自動調整要有上限與擺盪偵測。
- 【觀察】**往「看得到的第一個圖示」的左緣放東西，會落到緊鄰的那群沒畫出來的項目左邊**：分隔項目放「Surge 左邊」三次都落在輸入法（跨在瀏海邊緣、沒畫出來）的左邊；放「輸入法右邊」也失敗。
- 【觀察】**瀏海邊界附近的移動有連帶效果**：把 X 放到跨在邊界上的 Surge 左邊（驗證通過），原本在 Surge 左邊的 Y 會跳到 Surge 右邊，等於 X、Y 互換；
  從 Surge 右邊移走項目後，左邊較窄的項目會越過 Surge 補進空位，而不是讓 Surge 往右移。【推論】macOS 26 會讓「放得下的」較窄項目先補進邊界的空位（Surge 寬 84 pt）。
- 【觀察】**SystemUIServer 的舊式項目（Siri、Time Machine）會依自己記住的位置歸位**：Siri 被拖到邊界附近後記下 `NSStatusItem Preferred Position Siri = 641`（≈ 邊界），
  之後每次重排都回到那裡；送到最左邊後就穩定了。
- 【觀察】**拎起隱藏區的寬項目時，整排會大幅滑動**：拎起 Surge（84 pt，在瀏海後面）時，目標 MenuBarUSB 從 957 滑到 835，Whisky 等它靜止後在 836 放開，結果放進了隱藏區。
  反之，**放到 Whisky 圖示左邊**（系統預留的空位就在那裡）今天 3/3 成功，**送到最左邊** 6/6 成功。
- 【教訓】驗證只檢查「被移動的項目是否在目標旁邊」抓不到連帶變動；每次移動前後應比對整排順序，有非預期的變化就停止。邊界行為要先用 Whisky 自己的測試項目（Frost 式 spike）研究，不要在使用者的真實圖示上試。

### 2026-10-15：分隔項目自我測試（只移動 Whisky 自己的項目）

做法：`whisky://spike` 建立 4 個測試項目（T1–T4，寬 30／44／60／84）與分隔項目，視窗 ID 都在建立時以「建立前後的視窗清單差集」取得；
所有排列都只用「放到 Whisky 圖示左邊」，並有硬性保險：計畫裡出現非 Whisky 項目就整個拒絕。結束時移除測試項目與分隔項目，比對使用者看得到的項目。

- 【觀察】**排版模型（推論，符合今天所有觀察）**：macOS 26 由右往左排，放不下的項目被跳過，再往左找放得下的較窄項目補進空位；能畫的起點在 `auxiliaryTopRightArea.minX` 右邊約 20–26 pt，
  而且會隨相鄰項目寬度差 1 pt 而改變結果（AlDente 的電量文字少 1 pt，Surge 就從可見換成 Plaud）。
- 【觀察】**「剛好填滿空隙」的分隔項目不穩定**：分隔項目一變長，CGWindowList 會短暫回報右邊的項目（甚至 Whisky 圖示）沒畫出來，依此調整會越調越錯；長的分隔項目也讓移動測試項目失敗。已放棄。
- 【觀察】**固定 10000 pt 的分隔項目（Ice、Bartender、Frost 的做法）穩定**：6 個步驟全部通過、0 次重試——
  [分隔項目, T1, T2] 建好後只有 T1、T2 被畫出來；T2 變寬到 84 pt 沒有別的項目混進來；重排、隱藏、從螢幕外放回都一次到位。這也回答了 S1：26.7 上 length 10000 會把左邊的項目整排推出螢幕。
- 【觀察】**展開的分隔項目本身拖不動**（三次都放到 x = −37）；要移動它時先縮回 1 pt，移完再展開。
- 【觀察】自我測試結束後，使用者看得到的項目與順序和測試前完全相同（兩次）。
- 【教訓】排列計畫的「保留開頭、送走其他」最佳化，在分隔項目剛建立（落在最左邊）時會把使用者所有看得到的圖示都送走；第一版自我測試因此搬動了 9 個真實圖示（已用「放到 Whisky 左邊」依原順序放回）。
  現在有分隔項目時改成「只重放想要的項目」與「送走」兩種計畫取步數少的；自我測試強制只用前者並加硬性保險。
