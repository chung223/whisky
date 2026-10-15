---
title: Mezzanine
type: project
tags: [open-source, swift, appkit, mit, notch, overflow, macos-26, accessibility, menu-mirroring, screencapturekit]
sources:
  - raw/github/repos/brianmpollack__Mezzanine
  - https://github.com/brianmpollack/Mezzanine
updated: 2026-10-14
---

# Mezzanine

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [brianmpollack/Mezzanine](https://github.com/brianmpollack/Mezzanine)（Brian Pollack） |
| 授權 | **MIT** |
| 語言 | Swift 6（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`），Xcode 專案，約 1,100 行 |
| Stars | 0（2026-10-14；2026-07-30 建立，1 commit，可能 squash 過） |
| 支援的 macOS | 26.0 起（`project.pbxproj:184`）；下限只是因為 `isolated deinit` 需要 runtime 支援，AX 與 ScreenCaptureKit 的做法本身不依賴 26（`NOTES.md:129-135`）。**完全沒提到 macOS 27** |
| 定位 | 不負責隱藏：找出 macOS 因瀏海或空間不足**沒畫出來**的 status item，顯示在選單列下方的 strip，點了用 **menu mirroring** 打開 |

程式不大，價值在 `NOTES.md`（462 行）的平台觀察，以及 menu mirroring 的實作。

本頁 file:line 相對於 `raw/github/repos/brianmpollack__Mezzanine/`（commit `e3f4c10`）。
【作者稱】＝只在 README、NOTES 或註解裡出現的執行期觀察，程式碼無法驗證。

## 架構

| 檔案 | 內容 |
|---|---|
| `MenuBarItemScanner.swift` | 逐 App 讀 AX `AXExtrasMenuBar`、判斷有沒有畫出來、負快取 |
| `MirroredMenu.swift` | 從 AX 讀出選單、重建 NSMenu、把選擇轉送回原 App |
| `GlyphCapture.swift` | 用 ScreenCaptureKit 擷取沒畫出來的 item 圖像 |
| `OverflowPanel.swift`、`OverflowStripView.swift` | 選單列下方的 panel 與 strip |
| `AppDelegate.swift` | chevron status item、2 s 掃描計時器、徽章 |

## 關鍵機制（附 file:line）

### 1. 列舉與掃描最佳化

- 來源是 `NSWorkspace.shared.runningApplications`，跳過 `activationPolicy == .prohibited` 和自己（`MenuBarItemScanner.swift:131-134`）。【作者稱】沒有任何 status item 的擁有者是 `.prohibited`（`NOTES.md:100-101`）。
- 每個 App：`AXUIElementCreateApplication` → messaging timeout 0.1 s → 讀 `AXExtrasMenuBar` 的 children → 每個 child 讀 `AXPosition`、`AXSize`（`:144-148`, `:230-240`）。
  只有判定為隱藏的 item 才讀 tooltip（`AXHelp`，沒有再讀 `AXDescription`）（`:172-177`）。item 身分只是 `pid.index`，不能持久化（`:201`）。
- **負快取**：沒有 status item 的 App 記一個計數器，**隨機**設成 0–14，每次掃描加 1，到 15 才重查，讓重查分散開（`:100-109`, `:139-155`）。
  【推論】timeout 或錯誤也走同一條路，所以暫時卡住的 App 可能消失最多約 30 s。
- Control Center 保留一批 zero-size placeholder（代表使用者關掉的模組），它的隱藏 item 一律略過（`:157-164`）。
- 每 2 s 輪詢一次，工作放在 `.utility` 序列 queue（`AppDelegate.swift:22-28`, `:190-213`）；沒有接 NSWorkspace 的啟動或結束通知。
- 【作者稱】原本在主執行緒掃描一次要 2,143 ms：132 個 App 裡 121 個沒有 status item，佔 1,991 ms，其中兩個不回應的程序各耗掉 500 ms timeout。
  改成上述四項措施後穩定狀態約 20 ms（`NOTES.md:94-102`）。repo 裡沒有計時程式碼，各措施的貢獻無法拆分。

### 2. 判斷「沒畫出來」

- 每個 `NSScreen` 各算一個可繪區：瀏海螢幕是 `auxiliaryTopRightArea.minX` 到螢幕右緣，其他螢幕是整個寬度；選單列高度優先用 `safeAreaInsets.top`（`MenuBarItemScanner.swift:263-301`）。
- 隱藏的條件：寬或高 ≤ 0、不在任何螢幕上，或沒有**整個**落在可繪區內（`:303-319`）。
- 【作者稱】溢出後 macOS 會繼續指派越來越小的 x，一路延伸到 App 選單那半邊，但只畫完整落在瀏海右側的那一段，所以座標本身看起來合理、不能拿來判斷（`NOTES.md:37-42`）。
- 【作者稱】多螢幕：選單列會跟著使用者工作的螢幕走，主螢幕左邊的螢幕 x 是負的；早期只算一個螢幕，接上第二台後所有 icon 都被算成隱藏（`NOTES.md:79-87`）。上下堆疊的排列沒測過。
- 【推論】漏洞：非瀏海螢幕上被前景 App 選單擠掉的 item 偵測不到；沒有考慮 [MenuTidy](menutidy.md) 量到的瀏海右側死帶。

### 3. Menu mirroring

- 【作者稱】沒畫出來的 item 用 AppKit 開 NSMenu 時沒有螢幕上的錨點，對它做 `AXPress` 會回傳 `kAXErrorCannotComplete`；
  但它的 AXMenu 和所有 AXMenuItem 仍然可以列舉，個別項目也能直接按。走 target/action 的 item（Bitwarden、Claude）隱藏時仍可正常按下（`NOTES.md:44-51`；`README.md:44-49`）。
  程式碼本身沒有檢查這個錯誤碼。
- **讀取**：讀 status item 的 children，取第一個 role 是 `AXMenu` 的子元素，再遞迴讀它的 `AXMenuItem`；**不打開**原選單，也不用 `AXShowMenu`（`MirroredMenu.swift:37-77`）。
- **重建 NSMenu**：`autoenablesItems = false`（照抄對方 App 決定的狀態，否則 AppKit 會把無法驗證 action 的項目變灰，`:26-29`）；
  標題用 `AXTitle`，**空標題當分隔線**；enabled 用 `AXEnabled`；勾選用 `AXMenuItemMarkChar`；快捷鍵用 `AXMenuItemCmdChar` 加 `AXMenuItemCmdModifiers`（`:47-91`）。
  不處理 `CmdVirtualKey`／`CmdGlyph`（F 鍵、方向鍵會遺失）、圖片（【作者稱】AX 不提供任何圖像）、alternate 項目、自訂 view。
- **轉送**：每個鏡像項目保存原本 `AXMenuItem` 的參照，選了就設 1 s timeout 做 `AXPress`；**回傳值被忽略**（`:104-128`）。
- **每次點擊都重建**，然後在滑鼠位置 `popUp`（`AppDelegate.swift:168-180`）。
- **退路**：沒有 AXMenu 子元素 → 對 status item 做 `AXPress` → 失敗就把擁有者 App 帶到前景（`MenuBarItemScanner.swift:49-70`）。
- 【觀察】bug：先加了 App 名稱標題列和分隔線，才判斷選單是否為空，所以空選單永遠不會退回 press（`MirroredMenu.swift:30-32`）。
- 【推論】沒涵蓋：「點擊時才掛上 menu 再 `performClick`」的 item 平常沒有 AXMenu，`AXPress` 會回傳成功卻什麼都沒打開；popover 型 item 也類似。
- 不支援右鍵（【作者稱】status item 只提供 `AXPress`，`NOTES.md:433-435`）。這和 wiki 記載 Thaw、Frost 用 `AXShowMenu` 做右鍵矛盾，見 [點擊隱藏項目](../concepts/menu-bar-item-activation.md)。

### 4. 擷取沒畫出來的 item 圖像

- 【作者稱】沒畫出來的 item 仍有活的 window backing store，即使 `onscreen = false`，ScreenCaptureKit 照樣能擷取；AX 元素和 window 的中心 x 完全對齊（`NOTES.md:56-59`）。
- 用 `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements])` 找 layer 等於 `.statusWindow` 的視窗（讀 bounds 不需要錄影權限），以 AX `midX` 配對、誤差 4 pt 以內（`GlyphCapture.swift:57-86`）。
- `SCScreenshotManager.captureImage` 搭配 `SCContentFilter(desktopIndependentWindow:)`，**不用 stream**（`:39-102`）；以 alpha > 8 裁切（`:117-151`）。
- 只在 panel 打開時擷取，打開期間每 1 s 重拍；不常駐是因為連續擷取會讓錄影指示一直亮（`AppDelegate.swift:132-166`；`NOTES.md:436-437`）。
- 退路：App icon，再來是 SF Symbol `app.dashed`（`OverflowStripView.swift:96-115`）。
- 【作者稱】App 內附的圖檔不能代替擷取：Docker 有 13 張狀態圖、Bitwarden 的圖在 `app.asar` 裡、「鯨魚加更新徽章」是繪製時才合成的（`NOTES.md:61-65`）。這是 [MBAR](long-tail.md) 靜態抽取路線的限制。

### 5. 自己的 status item 擺放

【作者稱】（`NOTES.md:67-73`）：

- Preferred Position 是從右端往左量的距離，0 是最右邊。Mezzanine 在建立 item 之前先寫 `NSStatusItem Preferred Position MezzanineControl = 0`（`AppDelegate.swift:59-69`）。
- 位置在 **item 建立時**就決定：以隱藏狀態建立的 item 會落在最左邊，之後把 `isVisible` 改成 true 也不會移動。
- AppKit 在移除 item 時會把實際位置寫回 autosave key，和你在重建前寫入的值互相競爭。

### 6. 放棄的做法：移動別人的 item

【作者稱】`mover-wip` 分支（`NOTES.md:441-462`）：事件設 `mouseEventWindowUnderMousePointer`、`eventTargetUnixProcessID` 和 field 51，
送到 **session tap**（HID tap 會拉動游標），約 65 ms 就能移動別人的 item，**連沒畫出來的也移得動**。
但組合成目標排列時約一半失敗、成功的也常落錯位置，無法收斂；讀了 Ice 才知道 Ice 每次只移動自己的分隔線，temp-show 也只移動一個 item。

### 7. Panel 與 strip

- `NSPanel`（borderless、nonactivating），level `.popUpMenu`，註解說和 Bartender 的 bar 相同（`OverflowPanel.swift:16-37`）。
  【推論】[Bartender 機制](../bartender/mechanisms.md) 觀察到的視窗層級包含 101（即 `.popUpMenu`），和這個說法相符。
- 置中對齊自己的 status item，位在選單列下方 5 pt；strip 高 33 pt、每格 38 pt、glyph 高 18 pt，註解說這些尺寸是量 Bartender Bar 得到的（`OverflowStripView.swift:23-31`；`OverflowPanel.swift:69-94`）。
- 背景用黑色 0.22 疊 `.ultraThinMaterial`，因為 `.bar` material 會變淺、讓白色 glyph 看不見（`OverflowStripView.swift:55-68`）。
- chevron 上的徽章顯示被藏的數量（`AppDelegate.swift:215-225`）。

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| Accessibility | 必要 | 列舉、menu mirroring、`AXPress` |
| Screen Recording | 選用 | 第一次打開 panel 時才要求；拒絕就用 App icon（`GlyphCapture.swift:22-28`） |

- 【作者稱】sandbox 實驗：同一個 bundle 有、無 sandbox 各簽一次，無 sandbox 讀到 12 個 App 的 extras，有 sandbox 是 0 個；
  `AXIsProcessTrusted()` 照樣回 true，查詢只是靜默回傳空值（`README.md:160-173`；`NOTES.md:166-184`）。沒寫是哪個 macOS 版本。
- 目前 `ENABLE_APP_SANDBOX = NO`、hardened runtime（`project.pbxproj:258-259`）；`release.sh` 送公證前會確認沒有 `app-sandbox`（`scripts/release.sh:269-274`）。
- 【作者稱】TCC 授權綁簽章身分：從 development 換成 Developer ID 要重新授權；notarization 不改簽章（`NOTES.md:384-391`）。
- 【作者稱】`LSUIElement` App 沒有 icon 的話，在 Screen Recording 設定頁會顯示空白圖示，看起來像惡意程式（`NOTES.md:157-162`）。

## 已知問題

- 完全沒處理 macOS 27：27 沒有每個 item 一個的視窗，擷取會整個退回 App icon；幾何判斷在 27 上也不可靠（被收進系統 « 的 item 回報的 frame 不可信）。
- 不支援右鍵、⌥ 替代項目、選單圖示；鏡像選單是快照，可能過時。
- 選單讀取在主執行緒，每個屬性最多 0.2 s，深層選單可能卡住 UI。
- strip 裡的項目依 App 名稱排序，不是選單列上的順序。

## 對 Whisky 的參考價值

- **Menu mirroring 是 [路線圖](../synthesis/roadmap.md) M4 點擊轉送的首選**，但要補上 Mezzanine 沒做的：
  讀取放到 `WhiskyAXService` 背景執行並設總預算；檢查 `AXPress` 回傳碼；元素失效時用「標題路徑加 index」重新解析；
  空標題不一定是分隔線；`AXPress` 回傳成功但沒有出現選單或視窗時，退回暫時顯示再點擊（M3 的單一 item temp-show）。
- **掃描最佳化**（跳過 `.prohibited`、0.1 s timeout、隨機錯開的負快取）可直接用在 M2，但 timeout 要和「真的沒有 item」分開記錄，並接上 NSWorkspace 的啟動、結束通知。
- **重要區分**：Mezzanine 能擷取的是「座標仍在螢幕內、只是沒被畫出」的瀏海溢出 item。Whisky 26 後端的 Hidden 區段是被分隔線推到**螢幕外**，
  wiki 記載 ScreenCaptureKit 擷取螢幕外視窗會回 `-3811`（[擷取項目圖片](../concepts/menu-bar-item-imaging.md)），所以這招不能直接套用。
- **自己的 item 擺放怪癖**（建立時就決定位置、移除時寫回 autosave 的競爭）直接影響 M1。
- 在 26.7 與 27 上要驗證的事見 [點擊隱藏項目](../concepts/menu-bar-item-activation.md) 的「待實測」。

## 授權注意

MIT，引用或複製程式碼要保留版權聲明。依乾淨室規則，wiki 只描述行為。
