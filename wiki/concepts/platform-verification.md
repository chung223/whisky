---
title: 平台實測紀錄
type: concept
tags: [macos-26, verification, notch, cgwindowlist, spikes]
sources:
  - app/Whisky/Scanning/WindowList.swift
  - app/Packages/WhiskyCore/Tests/WhiskyCoreTests/MenuBarGeometryTests.swift
  - ~/Library/Logs/Whisky/whisky.log（2026-10-18 的情境切換）
updated: 2026-10-18
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

### 2026-10-15：自我測試第 7–9 步（送走、menu mirroring、暫時放回再點）

- 【觀察】分隔項目展開時，「送到最左邊」一次到位（T4）；T3 在螢幕外時，`MenuMirror` 讀得到它的選單（Alpha、Beta）。
- 【觀察】**分隔項目緊貼 Whisky 圖示（選單列上一個項目都沒有）時，「放到 Whisky 左邊」連續三次失敗**：放開時 Whisky 圖示的位置比平常左移約 46 pt。
  改成這種情況下先收起分隔項目、放完再展開，之後一次到位。
- 【觀察】**對自己程序的 status item 做 AXPress，AppKit 會直接在呼叫的執行緒上執行按鈕動作**（不經主執行緒），在背景執行緒呼叫會因 UI 不在主執行緒而中止（Swift 6 的 isolation 檢查）。
  對別的 App 做 AXPress 則由對方的主執行緒處理。
- 【觀察】「暫時放回再點」把螢幕外的 T1 放回、AXPress 後 popover 打開（偵測到 1 個新視窗）。但這個測試用的 `NSPopover` 在 `close()` 與 `orderOut` 之後仍留在螢幕上（layer 25、226 × 66），
  三次都一樣，測試因此等不到關閉。【推論】popover 打開時選單列正在重新排版（分隔項目剛展開），按鈕所在的視窗被換掉，popover 成了沒人管的視窗。
  正式功能因此在放回後多等 600 ms 再點；第 9 步已從自我測試移除，改用真實 App 手動測。

### 2026-10-15：記住版面、偵測跑掉（只讀，沒有移動）

- 【觀察】連續 90 秒每秒讀一次選單列，畫出來的項目和順序完全沒變（iStat 的 CPU、記憶體項目寬度固定）。被瀏海擋住的項目一樣有 frame，依順序排在畫出來的項目左邊（例如 852 pt 那個沒畫，886 pt 起才畫）。
- 【觀察】**麥克風／相機使用中的指示（Control Center 的 `AudioVideoModule`）會自己出現在 Whisky 圖示左邊**，佔掉一格，最左邊的 LLM Wiki 因此被擠到瀏海後面；指示消失後 LLM Wiki 又回來。
  Now Playing、專注模式等模組也可以設成「啟用時才顯示」，同樣會自己出現、消失。
- 【推論】所以「版面跑掉」不能用「畫出來的有哪些」判斷：寬度變化與系統指示會讓最左邊的項目時有時無，那也不是排回去能解決的（沒有空間）。
  Whisky 改成比**順序**（畫不畫出來都算），而且不算 Control Center 的模組：沒有分隔項目時，取 Whisky 圖示左邊和記住的版面一樣多的項目來比；有分隔項目時，比分隔項目到 Whisky 圖示之間。
  同一個差異要隔 20 秒連續看到兩次才提醒，濾掉 App 啟動中的暫時狀態。
- 【觀察】Whisky 自己的視窗可以用 `NSView.cacheDisplay(in:to:)` 畫成 PNG，不需要螢幕錄製權限（`whisky://snapshot`）；Liquid Glass 的材質畫不出來，文字和控制項可以。用來在不打擾使用者的情況下檢查設定視窗與 Whisky Bar 的排版。

### 2026-10-15：瀏海面板、選單列隱藏、溢出的選單列

- 【觀察】這台的瀏海：`auxiliaryTopLeftArea`／`auxiliaryTopRightArea` 算出 x 663–848、高 32 pt（`safeAreaInsets.top`）。
  在 `.mainMenu + 3` 放一個無邊框 panel 蓋住瀏海，可以收到滑鼠進出（`NSTrackingArea` 用 `.activeAlways`，Whisky 不是前景 App 也收得到）。
- 【設計】展開的面板做成「瓶頸」：頂端只有瀏海寬，到選單列下緣才往兩側展開，所以瀏海兩側的選單列圖示不會被蓋住（一開始做成整片變寬，蓋住了右邊三個圖示）。
- 【觀察】**全螢幕 App（或自動隱藏選單列）時，所有 status item 視窗都不在畫面上**，一陣子後連 frame 都移出選單列那一列（midY 不在 0–40）。
  這時讀到的「版面」是空的：Whisky 現在不在這時記版面、不比對、不移動（移動回報「選單列現在是隱藏的」），排列視窗顯示提示。
  ScreenCaptureKit 仍擷取得到這些項目的圖案。
- 【觀察】**沒有分隔項目、選單列塞滿時，最左邊的項目會部分在螢幕外**（Surge 84 pt 寬，minX = -69）。使用者按「排回來」時，Whisky 要把 OpenWiki 送到它左邊（放開點 x = -113），連續三次沒放進去。
  改成：沒有分隔項目時，送到「起點在螢幕上的最左邊項目」左邊；有分隔項目時照舊（自我測試驗證過放在螢幕外可以）。
- 【觀察】同一次的計畫是「送走 OpenWiki，再依序放回 9 個」。【推論】送走一個之後 macOS 會自己把下一個補進空位，剩下的步驟多半不必要。
  重排改成每移動一步就重新讀選單列、重算計畫（上限為第一次計畫的步數加 3）。
- 【觀察】`glassEffect` 裡的 template image 用 vibrancy 混色，`cacheDisplay` 截圖畫不出來（看起來像消失）。改成擷取時先做好白、黑兩個版本，依背景挑一個。

### 2026-10-15：酒杯只在搬移時出現（自我測試、只動 Whisky 自己的項目）

- 【觀察】**`NSStatusItem.isVisible = false` 會讓 AppKit 刪掉 `NSStatusItem Preferred Position <名稱>`**（只留下 `NSStatusItem VisibleCC`）；再設成 true，酒杯出現在最左邊（x = -74，瀏海後面）。
  改成移除 status item、把位置值寫回，再重新建立：回到原位（x 1231，Wi-Fi 與控制中心之間），其他項目也回到原位。重新啟動 Whisky 時位置值不存在，會用預設值 0（最右邊的第三方位置）放回去。
- 【觀察】自我測試兩種模式都 0 失敗：一般模式（酒杯常駐），以及「酒杯住在瀏海裡」（每次搬移前出現、搬完 0.3 秒後離開）。後者另外驗證酒杯離開後，分隔項目到 Whisky 之間的順序不變。
- 【觀察】期間發現重排的回歸：「每一步都重算計畫」遇到「釘到最右邊、但它本來就在最右邊」會原地重複，直到上限。改成只有送走之後才重算，釘的那幾步照計畫做完再檢查一次。
- 【觀察】**沒有分隔項目時，拿掉酒杯會讓 macOS 重排瀏海旁那一段的順序**：有酒杯時 `113*、164*、160（LLM Wiki）、134`，拿掉後變成 `160*、113、164、134`（* 為沒畫出來）。酒杯回來後恢復。
  【推論】瀏海邊界附近的項目不是單純往右移，而是依某種規則重新挑選放得下的項目。所以「酒杯住在瀏海裡」要搭配分隔項目，否則排好的版面會在每次酒杯離開時被打亂。
- 【觀察】iStat Menus（Setapp 版，`com.bjango.istatmenus-setapp.status`）的項目：AXPress 回 `-25200`（kAXErrorFailure），帶 `0x33` 指定視窗的點擊沒有反應，**真的把游標移過去的一般點擊才會打開下拉面板**。

### 2026-10-16：在使用者的選單列上打開分隔項目（兩次失敗、一次成功）

使用者同意後，在真實選單列打開分隔項目（再讓酒杯住進瀏海）。
- 【觀察】**第一次**（舊流程：先放 1 pt 的分隔項目，再把 9 個圖示依序釘回）：10 步都成功，但最後檢查時，分隔項目和酒杯之間多了 4 個本來藏著的項目。
  Whisky 開始把它們送走，送了 3 個就碰到步數上限，失敗後移除分隔項目（fail-open）。之後瀏海邊界又重新挑過一次：LLM Wiki 看不到了，換成另一個項目。
- 【觀察】**第二次**（改成照記住的版面排、上限改看進度）：同樣 10 步後，分隔項目落到很左邊，中間夾了將近 30 個藏著的項目。Whisky 一個個送走，直到 40 步上限才停；fail-open 之後，LLM Wiki 和 Plaud 看不到了，換成另一個項目。
  被送走的都是本來就在瀏海後面的項目，看起來沒差，但順序和 preferred position 都變了。
- 【推論】9 個項目釘完之後，1 pt 的分隔項目被推到瀏海邊界的死區，macOS 在那裡重新挑位置，分隔項目就不在原處了。自我測試只用 2 個小項目，分隔項目從沒到過邊界，所以沒抓到。
- 【觀察】**新流程**：先把分隔項目釘到酒杯旁（還是 1 pt，在空曠處），立刻展開，把其他項目推到螢幕外，再從螢幕外依序釘回要留的項目（只釘，不送走別的）。
  自我測試第 2 步改成走這個流程，0 失敗；接著在使用者的選單列上 10 步完成，結果和使用者排的完全一樣。
- 【觀察】接著讓酒杯離開選單列：9 個項目整排右移 38 pt，順序不變，LLM Wiki 還在（有分隔項目時沒有發生邊界重挑）。
- 【教訓】要在真實選單列上做的流程，自我測試必須把分隔項目擠到瀏海邊界的情況也涵蓋進去（測試項目要多到塞滿可用寬度）。
- 【觀察】**瀏海面板一直沒收到滑鼠**：`NSPanel.isFloatingPanel = true` 會把 level 改回 `.floating`（3），而它是在設定 `.mainMenu + 3` 之後才設的，所以面板一直在選單列（Window Server 第 24 層）底下。使用者之前都是點酒杯或用快捷鍵打開；酒杯一拿掉，點瀏海就沒反應。
  改成先設 `isFloatingPanel` 再設 level，啟動時記下 level（現在是 27）。【教訓】用 `cacheDisplay` 截圖只畫得出自己的視窗，看不出它被別的視窗蓋住；層級要用 CGWindowList 查。

### 2026-10-16：藏起來的圖示有變化時從瀏海提醒

- 【觀察】分隔項目展開時，被推到螢幕外的項目大多仍擷取得到真實圖案（`desktopIndependentWindow`）；24 個裡只有 1 個一直失敗（「音訊/影片擷取失敗」）。README 原本說「截不到」不正確，已改。
- 【觀察】每 30 秒擷取 24 個藏著的項目一次，一輪約 0.31–0.35 秒；Whisky 閒置時 CPU 0%、RSS 約 100 MB。
- 【設計】每個項目存一個 16 × 16 的灰階縮圖（`GlyphAnalysis.fingerprint`），差異超過 3.5% 才算變了；要先安靜 5 輪（約 2.5 分鐘）才會提醒，所以一直在變的即時數值不會觸發（`ChangeTracker`）。

### 2026-10-16：重新啟動後的分隔項目

- 【觀察】Whisky 重新啟動時，AppKit 依 autosave 位置把分隔項目放回去，但寬度是建立時的 1 pt。放回的位置不一定是排好的那一段左邊：這次在 x = 844（瀏海邊界的死區），右邊多了「天氣」，LLM Wiki 被擠到瀏海後面。
  【推論】每次釘選都把項目放在同一點（酒杯左邊），它們的 preferred position 可能很接近，重新啟動時的排序因此不可靠。
- 【設計】啟動時比對分隔項目右邊的順序和記住的版面：一致才展開；不一致就不展開、酒杯留在選單列、顯示版面提醒。按「排回來」時走可靠流程（分隔項目先放到酒杯旁、展開，再釘回）。
- 【觀察】重新啟動四次，每次分隔項目右邊都多一個「它左邊緊鄰的藏著的項目」（天氣、Binky、Foresight、…），即使那些項目的 preferred position（5638 以上）遠比分隔項目（622）靠左。
  【推論】跟啟用時的失敗是同一件事：1 pt 的分隔項目在瀏海邊界，macOS 重挑時跟鄰居對調。所以每次重新啟動都需要排回一次；Whisky 等使用者閒置 3 秒後自動做（使用者選的），約 8 秒。
- 【觀察】有一次自動排回時，iStat 的兩個項目剛好不在掃描結果裡（啟動後 4 秒，可能回應慢），Whisky 只釘回 7 個，還把這 7 個記成新的版面。
  修正：記住版面時保留暫時不在的項目（`LayoutDrift.merge`）；排回之前，找不到的項目最多再掃描 5 次。
- 【觀察】讀其他 App 的 `NSStatusItem Preferred Position <名稱>`：被送到最左邊過的項目數值都在 5600 以上；從沒拖過的「不在選單列上」項目，數值還停在以前看得到的位置（212–606）。

### 2026-10-16：重新啟動不用排回；自我測試第 9 步

- 【觀察】**重新啟動時直接用展開的長度（10000 pt）建立分隔項目，排好的一段就會回到原位**：連續三次重新啟動，比對都一致、0 次移動。
  1 pt 建立時，每次都會和左邊的鄰居對調。有一次建立後 1 秒內，鄰居暫時在錯的一邊，2 秒後才排好，所以啟動時等 1.5 秒才比對，不一致再看一次。現在是預設做法（`spacerCreatedExpanded`，設成 false 可回到舊做法）。
- 【觀察】**排好的一段放不下時（418 pt，空間約 368 pt），瀏海邊界的順序會自己變**：測試項目 T3、T4 釘好後又對調。Whisky 判定「沒有進展」後停手。排列視窗本來就會提示「放不下」。
- 【未知】放得下（348 pt）時，測試項目 T2、T3 也會在依序釘好之後對調，重釘還是一樣。同一套流程在使用者的 9 個真實項目上成功了 5 次。
  【推論】測試項目都屬於 Whisky 同一個程序，AppKit 可能自己維持同一個 App 內 status item 的順序。這一步改成只有 `whisky://spike?wide=1` 才跑，待查。
- 【觀察】自動排回期間出現的「使用者在忙」，有些是 Whisky 自己放回游標產生的 HID 輸入。現在會忽略 Whisky 自己拖曳結束後 0.5 秒內的輸入。
- 【觀察】自我測試第 1–8 步在一般模式與「酒杯住在瀏海裡」模式都通過，兩輪測完後使用者的選單列和測試前一樣。

### 2026-10-18：情境版面被自動排回越改越少

- 【觀察】使用者一個上午插拔外接螢幕約十次。每次切換、排回之後，Whisky 會重讀選單列並把結果寫回該情境；「平常」從 9 個項目變成 1 個（只剩沒在掃描結果裡的貼貼），之後每次切回「平常」都把其他圖示送到瀏海後面，看起來像「上面的功能全部不見」。
- 【觀察】少掉項目的幾次，重讀都剛好碰上選單列在動：酒杯剛離開選單列（03:04、07:28，最靠酒杯的 One Switch、AlDente 不見，20 秒後又被報成「跑到選單列上」）；外接螢幕正在接上（04:40，整段都不見）。
  【推論】掃描先拍一次視窗清單，再逐個 App 讀 AX 位置，靠位置配對視窗；中途項目一滑動，後面讀到的項目就配不到視窗，排列時讀不到它們。
- 【觀察】iStat Menus 的項目這天都配不到視窗（沒有 windowID），排回時沒辦法移動，排回後就從情境裡消失。
- 修正：重讀前後選單列的視窗位置要一樣才採用，不然等 0.4 秒重讀（最多 8 次），一直在動就保留原本記住的版面；配不到視窗的項目不算「不見」，也不會從版面刪掉；自動排回之後情境的內容一律不改，只有使用者自己排列或按「保留」才會改。

