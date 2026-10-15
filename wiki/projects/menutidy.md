---
title: MenuTidy
type: project
tags: [open-source, swift, appkit, unlicense, menu-bar-manager, macos-26, macos-27, allow-list, accessibility]
sources:
  - raw/github/repos/PerpetualBeta__MenuTidy
  - https://github.com/PerpetualBeta/MenuTidy
updated: 2026-10-14
---

# MenuTidy

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [PerpetualBeta/MenuTidy](https://github.com/PerpetualBeta/MenuTidy)（Jorvik Software） |
| 授權 | **Unlicense**（public domain） |
| 語言 | Swift（AppKit），沒有 Xcode 專案，用 `Makefile` 編譯；約 4,000 行（`main.swift` 2,820 行） |
| Stars | 5（2026-10-14；2026-03 建立，86 commits） |
| 支援的 macOS | 14 起；**14–26** 用隱形 spacer 撐開，**27** 用私有 MenuBarClientCore 的 visibility restriction |
| 權限 | 14–26 不需權限；27 需要 Accessibility（`main.swift:680-695`） |

chevron 式的選單列整理工具：點 chevron 收起或展開，沒有區段編輯器，也沒有第二條 bar。
它對 Whisky 的價值在 27 路徑的工程細節：作者在註解裡寫下大量帶日期的實測，而且授權是 public domain，可以直接複製。

本頁 file:line 相對於 `raw/github/repos/PerpetualBeta__MenuTidy/`（commit `b518455`）。repo 內 `Info.plist` 的版號（2.0.4）是 release 流程才寫入的，不能當作實際版本（`Makefile:54-55`）。

## 架構

| 檔案 | 內容 |
|---|---|
| `main.swift` | 整個 App：chevron 與 spacer、collapse／expand、時鐘轉送、選單列已滿警示、14–26 的 Reveal panel、holder 行程入口（`:2810-2814`） |
| `MenuBarRestriction.swift` | 27 的 restriction：dlopen、`objc_msgSend` 呼叫、holder 行程的啟動與替換 |
| `MenuBarInventory.swift` | 並行 AX walk、快照、chevron 定位、左右判定、系統 « 偵測 |
| `NotchWarning.swift` | 從瀏海垂下的提示 pill |
| `JorvikKit/` | 共用元件：設定視窗、權限監看（`JorvikPermissionWatcher`）、選單列 pill |

依賴只有內嵌的 Sparkle（EdDSA，每天檢查，`Info.plist:23-30`）。登入啟動用 `SMAppService.mainApp`（`JorvikKit/JorvikSettingsView.swift:19`）。

## 關鍵機制（附 file:line）

### 1. macOS 27：restriction 放在獨立的 holder 行程

- **API 和其他專案相同**（[allow-list](../concepts/menubar-agent-allow-list.md)）：dlopen `MenuBarClientCore.framework`（`MenuBarRestriction.swift:58-61`），
  `MBAssessmentModeConfiguration` 的 `initWithAllowedSystemItems:allowedBundleIdentifiers:`（兩個參數都是 `NSArray`）加上
  `MBAssessmentModeAssertion` 的 `activateWithConfiguration:completionHandler:`（`:63-71`, `:355-364`, `:188-208`）。
  不用 bridging header，從 `dlsym` 取 `objc_msgSend` 再轉型呼叫（`:82-104`）；completion block 必須是 `@escaping`，否則捕捉值時會 abort（`:93-103`）。
- **【觀察】作者的實驗：`invalidate()` 解除不了 assessment mode 對通知中心的抑制**（`main.swift:2789-2809`）。
  2026-09-20 在 27.0（26A428）上：從沒 restrict 過的行程，通知中心正常；collapse 再 expand 一次之後，即使已經沒有限制，
  通知中心在那個行程的生命週期內都打不開，只有行程結束才恢復。Wi-Fi、Control Center 不受影響。
  `dyld_info -exports` 顯示 `MBAssessmentModeAssertion` 只有 `activate(completionHandler:)`、`activate(with:completionHandler:)`、`invalidate()` 三個方法。
- **holder 行程**：collapse 時用 `Process` 帶 `--hold-menu-bar-restriction <bundleIDs…>` 再啟動自己的執行檔（`MenuBarRestriction.swift:230-247`）。
  holder 不建 NSApplication、不走 LaunchServices，activate 後只跑 run loop，從不呼叫 `invalidate`（`:166-176`, `:218-221`）。
  解除就是 SIGTERM 殺掉 holder（`:249-255`）。主程式本身從不建立私有物件，所以私有 API 崩潰只會讓 holder 死掉，等於全部顯示。
- **fail-open**：holder 每 2 s 檢查 `getppid() == 1`（父行程死掉後被 launchd 收養），是就 `exit(0)`（`:209-216`）。正常結束時 `applicationWillTerminate` 會先 expand（`main.swift:333-335`）。
- **替換順序**：先啟動新 holder 再殺舊的（`MenuBarRestriction.swift:224-244`），但**沒有等新 holder 回報 activate 成功**。【推論】可能有空窗或兩個 assertion 重疊。
  activate 失敗時 holder 只寫 log、不退出（`:193-196`），主程式會以為還在限制中。
- **永遠允許的 bundle**：`com.apple.MenuBarAgent`、`com.apple.controlcenter`、`com.apple.systemuiserver`（`:132-136`）。
  【觀察】bundle 清單少了 `com.apple.MenuBarAgent` 時，時鐘畫得出來但點了沒反應，作者說和 Hidden Bar #421 同一個問題（`:116-131`）。
  兩份清單互相獨立：把 `com.apple.controlcenter` 放進 bundle 清單留不住時鐘和 Control Center，要靠 `allowedSystemItems`（`:33-38`）。
- `allowedSystemItems` 傳 `0..<64`，驗證過能留住時鐘和 Control Center；放寬到 255 沒有幫助（`:138-145`）。

### 2. 27 上判斷哪些 App 要留

- **AX 來源**：逐 App 讀 `AXExtrasMenuBar` 的 children（不是 MenuBarAgent 的 tree），用 `concurrentPerform` 並行、messaging timeout 0.25 s（`MenuBarInventory.swift:590-598`, `:606-671`）。
  `kAXErrorCannotComplete` 視為「暫時聯絡不到」而不是「沒有 item」（`:184-187`）；空結果不覆蓋舊快照（`:178-183`）；行程集合改變或滿 60 s 才做 full sweep（`:550-588`）。
- **只在展開時拍快照**，因為受限的 bar 會少報；expand 後 1 s 再拍一次穩定讀數（`:48-54`；`main.swift:1411-1435`）。
- **chevron 位置用 AX，不用 NSWindow frame**：作者量到 NSWindow 說 x=361，AX 和實際畫面都是 896（`MenuBarInventory.swift:200-214`）。
- **判定規則**：`item.maxX > chevron 中點` 就保留；同一 App 只要有一個 item 在右邊就整個保留（`:479-481`, `:529-536`）。
  用中點是因為相鄰 item 會重疊 1–2 pt（`:501-508`）。
- **死區**：【觀察】27 藏掉 item 時不收回它的矩形。實例：Ballast 佔 870–1074、chevron 在 1046，藏掉 Ballast 後 800–1090 之間點 13 個位置全部落空（`:482-499`）。所以跨在 chevron 上的 item 一律保留。
- **collapse 後的監看**：每 1 s 讀自己圖示的位置，連續兩次相同才算停定；新的 allow-list 要連續兩次一致才套用；**只會多藏，不會解除隱藏**；來回擺盪就停（`main.swift:776-874`, `:983-1046`）。
- **無法保留的 App**：keep 清單裡的 App，其 bundle 的上一層目錄不是 `/Applications`、`/System` 或 `/System/*` 就判定無法保留，所以 `/Applications/Setapp/` 也會被列出（`main.swift:1172-1239`）。
  每次執行只提示一次（「X cannot be kept」）。依據是 Pelmet 的 symlink 實驗（`:1185-1210`）。
- **限制**：27 路徑沒有監看新啟動的 App，collapse 期間新開 App 的圖示會一直被藏到下次 expand。

### 3. 時鐘點擊轉送

- 被動的 `NSEvent.addGlobalMonitorForEvents([.leftMouseUp, .rightMouseUp])`，不是 event tap，原始點擊不會被吞掉（`main.swift:1513-1535`）。
- 條件：holder 存活、通知中心沒開（CGWindowList 裡有沒有 `com.apple.notificationcenterui` 的 on-screen 視窗，只讀 PID 不需 Screen Recording，`MenuBarInventory.swift:410-430`）、點擊落在時鐘上
  （MenuBarAgent 的 `AXExtrasMenuBar` 往下最多 3 層找 `AXIdentifier == "com.apple.menuextra.clock"`，`:287-369`）。
- 動作：殺掉 holder → 對時鐘 **AXPress** → 用同一份 allow-list 啟動新 holder（`MenuBarRestriction.swift:298-351`）。重新套用限制不會把通知中心關掉（`:312-315`）。
  限制中對時鐘 AXPress 會回報成功但沒有作用（`:303-306`）。只轉送左鍵。

### 4. 「選單列已滿」偵測

- **系統 «**：MenuBarAgent 的 `AXExtrasMenuBar` 直接 children 裡出現 `AXRole == AXButton` 就代表 macOS 正在自己藏圖示（平常只有 Control Center、時鐘兩個 AXGroup）；
  量到 x=890、w=18，description 是「Show Hidden Menu Bar Items」。比 role 不比 description，避開在地化（`MenuBarInventory.swift:371-408`）。
- **占用率**：所有 item 寬度總和 ÷ `NSScreen.main.frame.width`，預設門檻 0.8（`MenuBarInventory.swift:265-283`；`main.swift:1661-1672`）。
  用寬度總和而不用最左到最右的跨度，因為被藏的 item 會回報假位置（跨度量到 98%，實際 59%）。
  程式註解記的是 59% 正常、約 82% 開始丟（`main.swift:1665-1668`）；README 的「67%」只是經驗談。
- **NotchWarning**：從瀏海垂下的黑色 pill，level `popUpMenuWindow + 1`、不接收滑鼠、停留 5 s；鎖定畫面時不顯示（`CGSessionCopyCurrentDictionary` 的 `CGSSessionScreenIsLocked`）（`NotchWarning.swift:26-145`）。

### 5. macOS 14–26 路徑

- spacer 平常 length 0，collapse 時 10,000；chevron 用 `variableLength`；第一次啟動預寫 Preferred Position（chevron 150、spacer 300）（`main.swift:344-367`, `:1352`）。
- 沒有特別處理 26 的約 5,016 pt 上限；collapse 後 0.15 s 檢查 chevron 是否被推出螢幕，是就 expand（`:1355-1383`）。
  註解提到 spacer 撐到 10,000 時 Control Center 的 AX frame 會變成 5,016 寬，被推出去的 item 停在約 x = −4,000（`:2315-2321`, `:1994`）。
- **Reveal Hidden Icons**（只在有瀏海且非 27 時）：被瀏海擋住的圖示列在 panel 裡。
  左鍵：warp 游標到圖示中心再 AXPress，遇到 `kAXErrorCannotComplete` 最多重試 4 次、間隔 120 ms（26 上 AX 通道「冷啟動」的問題）（`:2657-2701`）。
  右鍵：warp 後在 `.cghidEventTap` 送合成點擊（`:2703-2715`）。
- **`notchDrawInset`**（預設 22）：`auxiliaryTopRightArea.minX` 右邊還有一段死帶，item 回報的位置正常但不會畫出來。
  作者在同一台 Mac 上兩次觀察到可畫邊界落在 inset 14–30 之間，取中間值（`main.swift:2213-2238`）。只用在 Reveal panel、只看 `NSScreen.main`。

### 6. 自動收回

- 指標離開選單列帶才開始計時，預設關、延遲 2 s（`main.swift:518-639`）。
- **判斷有沒有選單開著**：CGWindowList 裡有沒有 layer **剛好等於** `popUpMenuWindow`（101）的 on-screen 視窗。用「等於」是因為某些 App（Displaperture）一直有 999 層的視窗（`:570-591`）。
- 沒有 hover 展開。

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| Accessibility | 27 必要 | 讀 item 位置；沒有就拒絕 collapse（`main.swift:680-695`）。沒有快照或找不到 chevron 也拒絕（`:697-712`） |
| Screen Recording | 不需要 | CGWindowList 只讀 layer 與 owner PID |

- **權限監看**（`JorvikKit/JorvikPermissionWatcher.swift:18-147`）：observe `com.apple.accessibility.api` 要用 `.deliverImmediately`，否則 App 不在前景時通知會被壓住；
  `AXIsProcessTrusted()` 有行程內快取，收到通知立刻讀會讀到舊值，所以先等 1.5 s 再讀，另外每 1 s 輪詢。
- 不是 sandbox；entitlements 空白（hardened runtime）（`MenuTidy.entitlements:3-18`）。
- 本機建置強制用 Developer ID 簽章：ad-hoc 簽章會讓 TCC 授權默默失效，`codesign --verify` 也查不出來（`Makefile:40-52`）。

## 已知問題

- 有瀏海的判斷、死帶、占用率都只看 `NSScreen.main`，外接螢幕是主螢幕時會判斷錯誤。
- 選單列帶高度用 `NSStatusBar.system.thickness`，有瀏海的螢幕應改用 `safeAreaInsets.top`。
- holder 替換沒有等新 holder 確認生效；activate 失敗時 holder 不退出。
- 27 上 collapse 期間新開的 App 會一直被藏（沒有 adoption window，對照 [Pelmet](pelmet.md)）。

## 對 Whisky 的參考價值

- **holder 行程模式**直接解決三件事：通知中心殘留（待驗證）、私有 API 崩潰被隔離、主程式崩潰後限制自動解除。
  建議 Whisky 的 27 後端採用，並補上：新 holder 透過 pipe 回報成功後才殺舊的；activate 失敗就 `exit(1)`。
  這也比 [架構](../synthesis/whisky-architecture.md) 原本「AX 放 XPC 服務」更進一步：私有 API 也該放在可以被殺掉的子行程裡。
- **AX 快照的處理規則**（並行、timeout、`cannotComplete` 與空結果分開、只在展開時拍、連續兩次一致才採用）可整套採用。
- **系統 « 的 AXButton 偵測**和 `/Applications` 檢查可直接用於 [路線圖](../synthesis/roadmap.md) M5 的「選單列已滿」與「無法保留」提示。
- **權限監看的兩個坑**（`.deliverImmediately`、`AXIsProcessTrusted` 快取）在 M2 的 onboarding 就會碰到。
- 需要在 27 上驗證的矛盾見 [allow-list](../concepts/menubar-agent-allow-list.md) 第 21–23 點。

## 授權注意

Unlicense（public domain），可以直接複製程式碼，不需保留聲明。仍依乾淨室規則：程式碼只進 `app/`，wiki 只描述行為。
