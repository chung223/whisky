---
title: 隱藏選單列項目的手法
type: concept
tags: [hiding, nsstatusitem, separator, macos-26, macos-27, private-api]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/happy666End__MenuBarHider
  - raw/github/repos/frostbar__frost
  - raw/github/repos/frostbar__frost/docs/macos-behavior.md
  - raw/github/repos/fif7y__pelmet
  - https://github.com/Mortennn/Dozer
updated: 2026-10-14
---

# 隱藏選單列項目的手法

macOS 沒有讓一個 app 隱藏**別的 app** status item 的公開 API。開源專案用過四類手法，前兩類在 macOS 27 起大幅改變。
平台背景見 [macos-menu-bar-platform](macos-menu-bar-platform.md)。

## 1. 撐長自己的分隔線（≤ macOS 26 的主流）

**原理**：status item 由右往左排；在要藏的 item 右邊放一個自己的 `NSStatusItem`，把它的 `length` 設成極大值，左邊的 item
就被推出螢幕左緣（x 變成負值）。不需要任何權限。

| 專案 | 收合長度 | 展開長度 | file:line |
|---|---|---|---|
| [Dozer](../projects/dozer.md) | 10,000 | 顯示寬度 | `Dozer/StatusIconClasses/HelperStatusIcon.swift:12` |
| [Hidden Bar](../projects/hidden-bar.md) | `max(500, min(最寬螢幕 × 2, 10_000))` | 20 | `hidden/Features/StatusBar/Engine/LegacyLengthEngine.swift:16`, `:40-49` |
| [Ice](../projects/ice.md) | 10,000 | `variableLength` | `Ice/MenuBar/ControlItem/ControlItem.swift:24-28` |
| [Thaw](../projects/thaw.md) | 10,000 + 超寬螢幕額外 spacer | `variableLength` | `Thaw/MenuBar/ControlItem/ControlItem.swift:51-54`, `:695-741` |
| [SaneBar](../projects/sanebar.md) | 10,000 | 20 | `Core/Services/HidingService.swift:49-55` |
| [Frost](../projects/frost.md)（26） | 10,000 | 0（+ constraint hack） | `Frost/Sections/SectionController.swift:1288`, `:1380-1391` |
| [MenubarHide](../projects/menubarhide.md)（≤26） | 10,000 | — | `MenubarHide/CollapsedGeometry.swift:35` |

共同細節：

- **上限**：Hidden Bar 註解說 macOS 把 `length` 夾在 10,000；Tahoe 實際只產生約 **5,016 pt** 寬的 window
  （[Frost](../projects/frost.md) `docs/macos-behavior.md:86-89`、[MenubarHide](../projects/menubarhide.md) `CollapsedGeometry.swift:5-6`）。所以超寬螢幕要多放幾個
  看不見的 spacer 一起撐（Thaw：螢幕寬 > 5120 時，數量 ⌈(最寬 × 3 − 10000)/10000⌉）。
- **三區段**：再放第二條分隔線做「always hidden」。顯示 hidden 區時，第二條仍維持撐長（[SaneBar](../projects/sanebar.md) `HidingService.swift:170-235`；
  Ice、Thaw、Frost 同理）。
- **長度 0 仍佔約 16 pt**：Ice 發明的 hack——找出 status bar button 與 superview 之間的水平 constraint 停用，再把 window content size
  設成 1（[Ice](../projects/ice.md) `ControlItem.swift:106-123`；Frost 也用，但註明在 27 上不可用，因為會讓 AppKit 與 AX 的 frame 不一致）。
- **不要用 `isVisible = false` 隱藏自己的分隔線**：會刪掉系統記住的位置（[MenubarHide](../projects/menubarhide.md) `StatusBarController.swift:6-12`；
  SaneBar 引用 FB9052637）。`removeStatusItem` 也會刪，Ice 在 deinit 前先暫存 `NSStatusItem Preferred Position <autosaveName>` 再寫回
  （`ControlItem.swift:128-136`）。
- **位置種子**：建立 status item 之前先寫 `NSStatusItem Preferred Position <autosaveName>`，讓分隔線一開始就在正確位置（Ice `:88-99`；
  Frost `SectionController.swift:109-131`；MenubarHide 在 Tahoe 上每次啟動都寫，避免 item 被丟到 x ≈ −4220 並被「記住」
  `StatusBarController.swift:63-100`；SaneBar 遇到 WindowServer 快取損壞就把 autosave name 升版 `StatusBarController.swift:55-85`）。
- **兩條分隔線不能同時可見**：SaneBar 的「shield」順序（`HidingService.swift:306-379`）避免位置被寫壞。
- **新 item 出現在最左邊**：macOS 把新 status item 放最左，也就是 always-hidden 區，所以 Ice／Hidden Bar 都有「新 app 被藏起來」的 issue。

## 2. macOS 27：分隔線被丟出選單列

macOS 27 把整條選單列改成 MenuBarAgent 畫的單一 window（[Frost](../projects/frost.md) `docs/macos-behavior.md:555-581`；[MenubarHide](../projects/menubarhide.md)
README）。撐長分隔線的後果：

- 約 450 pt 以內：照舊把 item 往左推。
- 達到「cliff」（無瀏海螢幕約螢幕寬的一半；有瀏海螢幕約瀏海右側區域的 0.79）：**整個 status item 被丟出選單列**，而不是被夾住；
  縮回來時會出現在別的位置，周圍 item 也被打亂（MenubarHide `CollapsedGeometry.swift:8-20`；Frost 表格「A wide separator」）。
- 被擠出去的 item 進入系統新的 `«` overflow 選單，**仍可點擊**——所以這只算「收進 overflow」，不是真正隱藏。
- 被擠出去的 item 仍回報舊 frame，`NSStatusItem.occlusionState` 也不可靠（FB23349447），**app 無法確認哪些 icon 實際被畫出**。

兩種「仍用公開 API」的應對：

| 專案 | 作法 |
|---|---|
| [Frost](../projects/frost.md) | 有界寬度的分隔線對：`min(600, 螢幕寬/2 − 32)`，< 200 就不用（`Packages/FrostCore/Sources/FrostCore/Layout/BoundedDivider.swift:21-35`）；每個邊界兩個 item；section 以使用者安排為準，不靠幾何判斷 |
| [MenubarHide](../projects/menubarhide.md) | 分隔線 `max(200, floor(最低 cliff − 64))`，加最多 6 個零寬 spacer 一起撐開覆蓋最寬螢幕（`CollapsedGeometry.swift:36-64`） |

## 3. macOS 27：MenuBarAgent allow-list（私有 API）

[Hidden Bar](../projects/hidden-bar.md)（直接下載版）、[MenuBarHider](../projects/menubarhider.md) 呼叫私有 `MenuBarClientCore.framework` 的
`MBAssessmentModeAssertion`，讓 MenuBarAgent 只顯示 allow-list 內的 bundle ID。這是**真正的隱藏**（item 不畫、不進 overflow），但粒度是
整個 app、系統 item 另計、只對 /Applications 的 app 有效、會擋住通知中心。[Thaw](../projects/thaw.md) 3.0 的閉源 PlatformRuntimeKit
「assertion-backed visibility」【推論】也是同一套。細節見 [menubar-agent-allow-list](menubar-agent-allow-list.md)。

[Pelmet](../projects/pelmet.md)（GPL-3.0，只支援 27）是第三個公開原始碼的使用者，並補上三點：

- **系統 icon 也能藏**：把 battery、Wi-Fi、音量、Clock、Control Center 等的 `MBSystemItemIdentifier` 從 `allowedSystemItems` 拿掉即可；
  Clock 與 Control Center 可藏、不能移動（`Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:42-91`；
  `Packages/PelmetEngine/Sources/PelmetEngine/ConvergePlan.swift:79-88`）。上段「系統 item 另計」指的是 Hidden Bar／MenuBarHider 的選擇，不是限制。
- **新註冊的 item 會被 park**：任何 assertion 生效時，新註冊的 status item 停在螢幕外、不進 MenuBarAgent 的 AX tree，要短暫解除 assertion
  （adoption window）才會被收下（`Packages/PelmetEngine/Sources/PelmetEngine/AgentBarEngine.swift:237-277`）。
- **自己的 item 也要跟著藏**：每個可隱藏區段放一個 helper process（各有 bundle ID），讓 Pelmet 的 separator／launcher 跟著 bundle allow-list 隱藏
  （`project.yml:102-126`；`docs/HELPER-PROCESS-PLAN.md`）。

## 4. 卸載 Apple 的 menu extra

SystemUIServer 裡的 extras（Time Machine、VPN…）共用同一個 bundle ID，allow-list 無法單獨藏。[MenuBarHider](../projects/menubarhider.md) 用
ApplicationServices 的私有 `CoreMenuExtraRemoveMenuExtra`／`CoreMenuExtraAddMenuExtra` 在收合時卸載、展開時從
`/System/Library/CoreServices/Menu Extras/*.menu` 重新載入（`MenuBarHider/Services/SystemUIServerExtras.swift:11-78`）。副作用：系統設定裡顯示為關閉。

[Pelmet](../projects/pelmet.md) 用同一組 `CoreMenuExtra*` 符號，但從 `SystemUIPlugin.framework` 解析，用途也不同：不是收合時卸載，而是使用者
開啟 Pelmet 自己的 Time Machine 替身時，把 Apple 的那個在系統設定中關掉（Siri 則用 `SiriFoundation` 的 `SRFUserDefaultsController`），讓兩者
能分別放在不同區段（`Pelmet/Extras/AppleMenuExtras.swift:1-11`, `:50-115`）。

## 5. macOS 27 的其他路線（2026-10-14 補，只根據 README）

來源是 [其他同類專案](../projects/long-tail.md) 的 README，都是作者的說法，沒有實測過。

### 5.1 改系統的「Allow in the Menu Bar」開關

System Settings › Menu Bar 有每個 App 的開關，關掉就移除圖示，執行中的 App 立即生效，所有螢幕一致，重開機也記得（[Champ-KTP/Tuck](../../raw/github/readmes/Champ-KTP__Tuck.md)）。
三個專案用它取代 allow-list：

| 專案 | 寫法 | 權限 |
|---|---|---|
| [Chest](../../raw/github/readmes/boringbar__chest.md) | 直接寫系統的清單檔，加上選單列版面檔（用來固定自己的圖示並把項目放回原處） | 兩個檔案受保護：用 Open panel 讓使用者選取授權；有 Full Disk Access 就免 |
| [Tuck（usetuck）](../../raw/github/readmes/beaugunderson__tuck.md) | 寫 Control Center 設定檔裡的清單 | Full Disk Access |
| [Champ-KTP/Tuck](../../raw/github/readmes/Champ-KTP__Tuck.md) | 在背景開著 System Settings 的 Menu Bar 頁，用 AX 按開關（peek 約 50–100 ms） | Accessibility |

- **優點**：沒有 allow-list 的副作用（Focus、相機／麥克風指示消失，時鐘打不開通知中心，/Applications 以外的 App 被藏；Chest README `:32-34`）。
- **缺點**：仍以 App 為單位；新 App 要等系統自己把它列進清單，Chest 的對策是重啟選單列（畫面會閃）；
  Champ-KTP/Tuck peek 時圖示會插回最左邊，不在原位。
- **不是 fail-open**：寫進系統設定的狀態在程式 crash 後仍然有效，Chest crash 後圖示會一直藏著；重新啟動時 Chest 會**繼續藏**，要它正常結束才會全部回來（[Chest](../projects/chest.md)「已知問題」）。這和 [架構](../synthesis/whisky-architecture.md) 原則 3 衝突。
- **已讀 Chest 原始碼**（[Chest](../projects/chest.md)）：清單在 `~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist` 的 `trackedApplications`，每個 App 一個 entry，`isAllowed = false` 就隱藏；只能改 MenuBarAgent 自己建的 entry，自己寫的會被忽略。用 CFPreferences 以檔案絕對路徑寫入，經 cfprefsd 通知 MenuBarAgent，【作者稱】1 秒內生效。
  檔案受 group container 保護：使用者在 Open panel 選取那個檔案後就能讀寫（或給 Full Disk Access）。
- **排序也能靠開關**：在 App 關著時寫 `com.apple.MenuBar` group container 的 `TrailingItemPreferredPositions`，再打開開關，項目就落在那個位置，完全不合成拖曳（[移動項目](menu-bar-item-moving.md) §3）。
- **系統項目**：Wi-Fi、Bluetooth、Focus 等 10 個 MenuBarAgent 項目改 `com.apple.controlcenter`（current host）的 key 就能藏，不需檔案授權；Clock、Control Center 藏不了。
- **風險**：格式沒有文件（看起來是 Swift `Codable` 的輸出）；和 MenuBarAgent 之間有讀改寫的 race；新 App 要等 MenuBarAgent 列進清單，Chest 的對策是 SIGTERM 重啟 MenuBarAgent；【作者稱】約 70 個 App 時 MenuBarAgent 曾停止套用變更。

### 5.2 有界寬度，讓系統把項目收進 «

27 會把放不下的項目連同它左邊所有項目移進系統的 « overflow（[Blinds](../../raw/github/readmes/massimodascola__blinds.md) `:96`），但寬度達到螢幕一半的項目會直接被丟掉：

- [CleanMenuBar](../../raw/github/readmes/atilac__CleanMenuBar.md) 在 1512 pt 螢幕上量到 756 pt 的斷崖：長度 10000 只畫成 5016 pt 寬、鄰居不動；730 自己不畫但左邊的圖示消失；500 會畫出來、左邊溢入 «。
- [Stash](../../raw/github/readmes/brentc22__stash.md) 在 1728 pt 螢幕上：848 pt 會藏、849 pt 不會（848 + 16 pt chrome = 864 = 半寬）。
- Blinds 用最窄螢幕寬度的 44%（1800 pt 螢幕上 792 pt）；850 pt 會進 «，950 pt 會被丟掉。
- [IconCloak](../../raw/github/readmes/LarsAtassi__icon-cloak.md) 依前景 App 的選單寬度動態填滿瀏海兩側的空間，並自己畫一個 « 蓋掉系統的；[IceMelt](../../raw/github/readmes/pnikolaidis__icemelt.md) 用 divider 加 spacer。
- 限制：寬的外接螢幕可能推不乾淨，因為上限是最窄螢幕的一半（Blinds、CleanMenuBar）。

這比 [Frost](../projects/frost.md) 的 ≤ 600 pt 設定更有依據：寬度跟著螢幕走，而且被藏的項目仍能從系統 « 叫出來。

### 5.3 其他

- **遮蓋**（[Tidy](../../raw/github/readmes/Itzhaik07__Tidy.md)）：在選單列上方疊三層 `NSVisualEffectView` 模糊掉圖示，不需 Screen Recording；只是視覺上遮住，不會騰出空間。
- **混合粒度**（[NookBar](../../raw/github/readmes/kevinLay7__NookBar.md)）：宣稱 allow-list 加有界 divider 能做到單一圖示的粒度，README 自己標著還沒實機驗證。

### 5.4 【矛盾】需要實測

- 27 上撐寬還推不推得動：CleanMenuBar、Blinds、IconCloak 說小於半寬就推得動；Tidy 說推不動；LineBar 說 length 推擠在 27.0 可用；
  Barn 說 MenuBarAgent 會和它衝突。可能是各自測的寬度不同。
- 26 會不會丟掉超寬項目：Champ-KTP/Tuck（`:25-28`）說 26 起放不下的項目會被丟掉並出現 «，連撐寬的隱形項目本身也會被丟；
  但本頁 §1 與 Frost 量到 26 是夾到約 5,016 pt，CleanMenuBar、Persiana、shelf 也說 26 上 separator 仍可用。可能和 26 的小版本有關。
- 兩題都併入 [路線圖](../synthesis/roadmap.md) M0 的 S1（26.7）與 27 虛擬機的 spike。

## 其他相關：把 item 搬到螢幕外

Ice／Thaw 的「隱藏」本身仍是分隔線；但 temp-show、排列等功能會把 item 真的搬來搬去，見 [menu-bar-item-moving](menu-bar-item-moving.md)。

## 對 Whisky 的建議

1. 隱藏引擎做成 protocol + 依 OS 選實作（[Hidden Bar](../projects/hidden-bar.md) 的 `MenuBarEngineFactory`、[Frost](../projects/frost.md) 的 `PlatformSupport.backend`）。
2. macOS 26：10,000 pt 分隔線 + 超寬螢幕 spacer + Preferred Position 種子；避免 `isVisible`。
3. macOS 27：預設走 allow-list（真正隱藏），偵測不到私有類別時退回 Frost 式有界分隔線（只能「推進 overflow」）。UI 措辭要誠實。
4. 不論哪條路，都要有「解除隱藏」的保底（crash、權限被撤銷、私有 API 錯誤時一律回到全部顯示）。
5. macOS 27 的 allow-list 實作還要處理：系統 icon（編號 0…8）、collateral extras（assertion 生效時系統自己拿掉的 Now Playing、AirDrop、
   Focus…）、新 item 的 adoption window（見 [Pelmet](../projects/pelmet.md)）。
