---
title: macOS 27 MenuBarAgent allow-list（MBAssessmentModeAssertion）
type: concept
tags: [macos-27, private-api, menubaragent, hiding, assessment-mode]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/dwarvesf__hidden/hidden/Features/StatusBar/Engine/Native/HBNativeVisibilityShim.m
  - raw/github/repos/happy666End__MenuBarHider/MenuBarHider/Services/MenuBarAgentBridge.swift
  - raw/github/repos/happy666End__MenuBarHider/MenuBarHider/Services/SystemItems.swift
  - https://github.com/thaw-app/prk-bin
  - raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-14
---

# macOS 27 MenuBarAgent allow-list（`MBAssessmentModeAssertion`）

macOS 27 起選單列由 `com.apple.MenuBarAgent` 統一繪製（見 [macos-menu-bar-platform](macos-menu-bar-platform.md)）。兩個 MIT 專案
（[Hidden Bar](../projects/hidden-bar.md)、[MenuBarHider](../projects/menubarhider.md)）獨立地找到同一個私有介面，可以讓 MenuBarAgent **只顯示指定 app 的
item**。這是目前公開程式碼中唯一能在 macOS 27「真正隱藏」第三方 item 的方法。

已知使用者：[Hidden Bar](../projects/hidden-bar.md)（直接下載版）、[MenuBarHider](../projects/menubarhider.md)、
[fif7y/pelmet](https://github.com/fif7y/pelmet)（GPL-3.0，840 stars，README 明言用 `MenuBarClientCore`）、[brentc22/stash](https://github.com/brentc22/stash)（MIT），
以及【推論】[Thaw](../projects/thaw.md) 3.0 的閉源 PlatformRuntimeKit。另一個 agent 的平台頁
[macos-menu-bar-platform](macos-menu-bar-platform.md) §8 把「27 的隱藏靠什麼」列為未知，本頁即為答案。

（2026-10-12 補：Pelmet 已 clone 研究，見 [Pelmet](../projects/pelmet.md)。下文標「Pelmet」的 file:line 相對於 `raw/github/repos/fif7y__pelmet/`，
`PE/` = `Packages/PelmetEngine/Sources/PelmetEngine/`，`PC/` = `Packages/PelmetCore/Sources/PelmetCore/`。Pelmet 是 GPL-3.0，只學行為，不抄程式碼。）

## 來源與用途

- 私有 framework：`/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore`。
- Hidden Bar 註解：它是 macOS 27「assessment（考試鎖定）模式」背後的 framework，可把選單列限制在 allow-list
  （`HBNativeVisibilityShim.m:23-26`）。
- Apple 的 macOS 27 release notes 有一條相關的**公開**功能：Automatic Assessment Configuration 可以控制 Dock 與 Menu Bar
  （158132137，見 `raw/articles/2026-10-12-apple-macos-release-notes-menu-bar.md`）。【推論】私有類別就是那個公開功能的底層 client。
- MenuBarHider 稱這是「the one service there that requires no entitlement」（README）。

## 介面（兩個專案一致）

| 項目 | 值 | 出處 |
|---|---|---|
| Configuration 類別 | `MBAssessmentModeConfiguration` | Hidden `HBNativeVisibilityShim.m:28`；MenuBarHider `MenuBarAgentBridge.swift:50-51` |
| Assertion 類別 | `MBAssessmentModeAssertion` | 同上 |
| 建立設定 | `-initWithAllowedSystemItems:(NSArray<NSNumber*>*) allowedBundleIdentifiers:(NSArray<NSString*>*)` | Hidden `:31`；MenuBarHider `:40`, `:109-114` |
| 啟用 | `-activateWithConfiguration:completionHandler:(void(^)(NSError*))` | Hidden `:32`, `:68-71` |
| 解除 | `-invalidate` | Hidden `:33`, `:77-80` |
| Assertion 建立 | 普通 `-init` | Hidden `:63`；MenuBarHider `:77` |

注意事項：

- 參數必須是 `NSArray`，傳 `NSSet` 會因 `-objectAtIndex:` crash（Hidden `:58-59`）。
- 先 `dlopen` + `NSClassFromString` + `instancesRespondToSelector:` 三重確認，缺任何一個就視為不可用（Hidden `:35-45`；MenuBarHider `:52-58`）。
- 呼叫包在 `@try`（Hidden `:57-74`）。
- 換新設定時，**先啟用新 assertion，成功後才 invalidate 舊的**，避免閃爍；失敗保留舊的（MenuBarHider `:84-93`）。
- 任何錯誤 → 解除限制（全部顯示），絕不讓 item 卡在隱藏（Hidden `NativeVisibilityEngine.swift:205-209`）。
- Pelmet 用同一組類別與 selector，註解說 activate 的形式是在 27.0（26A5416b）用 runtime introspection 驗證的
  （`Packages/PelmetEngine/Sources/PelmetEngineObjC/MBAssessmentShim.m:11-26`, `:77-131`）；也是「先 activate 新的、再 invalidate 舊的」，
  completion 最多等 3 s，拿不到 handle 就保留舊 assertion（`PE/AgentBarEngine.swift:496-534`）。
- **assertion 綁 process**：app crash 或釋放時 macOS 自動恢復選單列（Pelmet `PE/AssessmentMode.swift:8-10`；`docs/FAQ.md:118-126`）。
- **idempotent 很重要**：assertion swap 會讓 bar reflow → item 變化 → 又觸發 converge；Pelmet 在 allow-list 與 concealable 集合沒變時直接 no-op，
  並帶 epoch 讓過時的 converge 中止（`PE/AgentBarEngine.swift:113-117`, `:468-489`）。
- **外部拆除**：swap 3 s 後仍看到應藏的 bundle，就當作 assertion 被系統拆掉並重送（Pelmet `PE/AgentBarEngine.swift:450-466`）。

## System item 編號

`allowedSystemItems` 是 `MBSystemItemIdentifier` 的 raw value。MenuBarHider 在 macOS 27.0（26A428）記錄到：
0 battery、1 bluetooth、2 clock、3 displays、4 keyboard、5 volume、6 wifi、7 screenMirroring、8 primaryBentoBox（Control Center）
（`MenuBarHider/Services/SystemItems.swift:3-4`）。兩個專案都直接允許 `0..<64`，也就是不藏任何系統 item。
【推論】[Thaw](../projects/thaw.md) 3.0 的「Hiding method: Everything」能藏 Clock／Control Center／Siri，就是縮小這個清單。

**Pelmet 證實系統 item 可以個別藏**（上面的【推論】因此有了公開原始碼佐證）：

- 對照表相同（0 battery … 8 primaryBentoBox，`PC/MenuBarPolicy.swift:42-60`）；使用者把系統 icon 放進隱藏區段，就把對應編號從
  `allowedSystemItems` 拿掉（`PE/ConvergePlan.swift:79-88`）。AX identifier 對照：`com.apple.menuextra.{sound, battery, wifi, clock, bluetooth,
  display(s), textinput|keyboard, screen-mirroring, controlcenter}`，輸入法 icon（`com.apple.TextInputMenuAgent`）算 keyboard（`PC/MenuBarPolicy.swift:62-81`）。
- **Control Center 與 Clock 也藏得掉**：2026-09-22 實測只允許 0…7 時 Control Center icon 離開 bar（`PC/MenuBarPolicy.swift:54-58`）；
  兩者可藏、不能移動（`:83-91`；`docs/FAQ.md:64-67`）。
- Siri／Time Machine 等 SystemUIServer extras 仍是同一個 bundle，Pelmet 改畫自己的替身並把 Apple 的關掉（見 [status-item-hiding](status-item-hiding.md) §4）。
- `pelmet-probe conceal-sys` 用來試 8 以上的編號能否保住 Now Playing 等 extras（`PE/AssessmentMode.swift:44-50`）；FAQ 說這些 extras
  無法個別豁免（`docs/FAQ.md:13-17`），【推論】8 以上的編號無效。

## allow-list 的組成

- MenuBarHider：`(running bundle IDs − 要藏的) ∪ 永遠允許`；永遠允許包含 Control Center、MenuBarAgent、SystemUIServer、TextInputMenuAgent、
  Siri、Spotlight、WiFiAgent、ScreenTimeAgent、AirPlayUIAgent、UserNotificationCenter、notificationcenterui、loginwindow
  （`Models/HiddenSet.swift:20-22`；`Services/SystemItems.swift:13-26`）。
- Hidden Bar：自己 + visible 區的 app（`NativeVisibilityEngine.swift:189-212`）。
- 所以這是**白名單**：新啟動、還沒被加進清單的 app 會被藏；兩者都監看 `NSWorkspace.runningApplications` 並重送（MenuBarHider debounce 1 s）。
- Pelmet：`(所有 running bundle IDs ∪ 觀察到的 item bundle) − 要藏的`，不另列永遠允許的系統 agent（系統 agent 的 item 由 system item 編號控制）
  （`PE/ConvergePlan.swift:92-106`）。自己的 separator／launcher 放在每個區段一個的 helper app（`app.fif7y.Pelmet.items.hidden`／`.alwaysHidden`），
  這樣它們也能跟著 bundle 規則隱藏（`PC/MenuBarPolicy.swift:22-39`）。預設開啟「steady extras」：沒有東西要藏時也持有一個全允許的 assertion，
  讓 collateral extras 穩定消失（`PE/AgentBarEngine.swift:91-95`）。

## 限制與副作用

1. **粒度是 bundle ID**：同一 app 的多個 item 一起顯示或隱藏（Hidden `MenuBarLayout.swift:71-74`）。
2. **只對 /Applications 底下的 app 有效**：其他位置（包含 `~/Applications`）的 app 在 allow-list 生效時一律被藏，連自己的控制圖示也會
   消失；兩個專案都要求自己裝在 /Applications（MenuBarHider `Services/AppLocation.swift:3`；Hidden `docs/MANUAL.md:28-29`）。
3. **沒有 bundle ID 的 item** 一律被藏（MenuBarHider README `:132-134`）。
4. **SystemUIServer extras 無法個別控制**（都歸 SystemUIServer），要另外用 `CoreMenuExtra*` 卸載（見 [status-item-hiding](status-item-hiding.md) §4）。
5. **通知中心被擋**：assertion 生效時點時鐘打不開通知中心；MenuBarHider 在游標靠近時鐘時暫時解除（`App/ClockHoverMonitor.swift:18-36`）；
   Thaw 3.0 有對應的「Clock activation bridge」（`MenuBarSectionControlling.swift:10-20` @ `feat/thaw-3`）。
6. **需要非 sandbox**：Hidden Bar 的 App Store 版在 27 上無法隱藏（sandbox 擋住讀 AX 的 `com.apple.axserver` lookup，`AccessibilityMenuBarInventory.swift:13-15`）。
   列舉 item 位置仍需要 Accessibility。
7. **私有 API，隨時可能被關**（MenuBarHider README `:130-131`）。

[Pelmet](../projects/pelmet.md) 補充的限制與細節：

8. **新註冊的 item 會被 park**：任何 assertion 生效時，新註冊的 status item（app 重新啟動、新 item）停在螢幕外、不進 MenuBarAgent 的
   AX tree（實測 Bitwarden 超過 4 分鐘），即使 allow-list 已包含它；因為無縫 swap 從不留下沒有 assertion 的空檔。對策是 adoption window：
   暫時 invalidate、輪詢到 item 出現（≤ 2.5 s）再重送，並用截圖蓋住閃爍（`PE/AgentBarEngine.swift:237-277`）。
9. **collateral extras**：任何 assertion 生效時，系統會順便拿掉 Now Playing、相機／麥克風膠囊、AirDrop、Focus、Timer、快速使用者切換、
   Live Activities，無法個別豁免（`docs/FAQ.md:13-24`）。
10. **通知中心（第 5 點）**：Pelmet 實測任何 visibility restriction 下 clock 都打不開通知中心，⌥A 等快捷鍵也一樣；作法是用 event tap 吞掉
    clock 的點擊、短暫 invalidate、對 clock 做 AXPress（不行就重播 HID 點擊）、再重送（`Pelmet/Events/ClockClickRelay.swift:1-16`；
    `Pelmet/App/AppState.swift:1091-1130`）。
11. **第 2、3 點的補充與矛盾**：Pelmet 觀察到 /Applications 以外的 app，MenuBarAgent 解析不到 host（log：`Host or location not found
    for disallowing status item: nil`），item 被**銷毀**，放一個 /Applications 的 symlink 就恢復（`Pelmet/App/CollateralTracker.swift:5-13`）；
    Xcode DerivedData 裡的 app 也一直被藏（`docs/FAQ.md:186-192`）。但**沒有 LaunchServices bundle ID 的 helper**（ChatGPT Classic、
    Little Snitch monitor）的 icon 在 Pelmet 的觀察是**藏不掉**，和第 3 點「一律被藏」相反；同一個 helper 在主程式執行時又藏得掉
    （`Pelmet/App/UnhideableTracker.swift:1-7`；`docs/FAQ.md:78-92`）。【未知】結果可能取決於 helper 的父 app 是否在跑，需實測。

## 其他專案補充的觀察（2026-10-14，只根據 README）

12. **副作用的獨立確認**：Chest、Ellipsis、BarNook、Stow 都說只要有 restriction 生效，Focus 和相機／麥克風指示就會被藏（Stow：橘色隱私點會保留），
    和第 9 點一致（[Ellipsis](../../raw/github/readmes/ronny__ellipsis.md)、[Stow](../../raw/github/readmes/saturdaysort__stow.md)）。
    Cornice 也說 AirDrop 和快速使用者切換即使在 divider 右邊也會被藏（[Cornice](../../raw/github/readmes/SnowDrit__Cornice.md) `:64`）。
13. **寬度門檻**：寬度達到螢幕一半的 item 會被丟掉（[Stash](../../raw/github/readmes/brentc22__stash.md) `:35`；詳見 [隱藏手法](status-item-hiding.md) §5.2）。
14. **參數陷阱**：該傳 `NSArray` 的地方傳 `NSSet` 會 throw；`allowedSystemItems` 給 `0...63` 會讓螢幕鏡像失效（Stash `:76`）。和 Pelmet 不再一律給 `0..<64` 的改動一致。
15. **列舉**：Stash 說 MenuBarClientCore 的列舉 API 需要 Apple 專屬的 entitlement，所以列舉仍要靠 AX 的 `AXExtrasMenuBar`。Stash 也用讀 MenuBarAgent 自己的 log 來驗證行為。
16. **被丟掉的圖示留下死區**：在 27 上被丟掉的圖示仍佔著原本的矩形，形成點不到的區域；跨在 chevron 上的圖示一律保留，以免 chevron 被死區蓋住（[MenuTidy](../../raw/github/readmes/PerpetualBeta__MenuTidy.md)）。
    時鐘點擊轉送時解除限制約 0.2–0.4 s，看得到閃一下（同上）。
17. **同一個 App 跨區**：只要有一個圖示在可見區，整個 App 都保持可見（Cornice、Flux）。
18. **iStat Menus**：27 上 iStat Menus 7.30 的 Combined item 即使列入 allow-list 仍會消失。
    [MenuBarCompact](../../raw/github/readmes/iamwrm__MenuBarCompact.md) 把 helper 複製到 /Applications 並改 LaunchAgent 的 `Program` 欄位；原因推測是第 2 點的 /Applications 限制。
19. **系統項目的執行期發現**：從 `MBSystemItemIdentifier.allCases` 加上掃描 `/System/Library/CoreServices/Menu Extras/*.menu`，不寫死編號（MenuBarCompact）。
20. 【矛盾】**27 上的合成 ⌘ 拖曳**：Cornice 說 macOS 27 會把合成的 ⌘ 拖曳交給 Mission Control（`:162-163`）；
    IconCloak 卻在 27 上用模擬 ⌘ 拖曳把自己的 » 移回最左（[IconCloak](../../raw/github/readmes/LarsAtassi__icon-cloak.md) `:82`）。Pelmet 用的是從 item 本身開始的 HID 真實拖曳。需要實測。

## 原始碼補充（2026-10-14，[MenuTidy](../projects/menutidy.md)、[Chest](../projects/chest.md)）

21. 【矛盾】**`invalidate()` 不能完全解除**：MenuTidy 作者 2026-09-20 在 27.0（26A428）上的對照實驗：一個程序只要 activate 過一次，之後即使 invalidate、已經沒有限制，
    通知中心在那個程序的生命週期內都打不開，只有程序結束才恢復；`dyld_info -exports` 顯示 `MBAssessmentModeAssertion` 只有 `activate(completionHandler:)`、`activate(with:completionHandler:)`、`invalidate()`（MenuTidy `main.swift:2789-2809`）。
    所以 MenuTidy 把 assertion 放在**子程序**（holder）裡，解除就是殺掉它；holder 每 2 s 檢查 `getppid() == 1`，父程序死了就自己結束（`MenuBarRestriction.swift:209-255`）。
    這和本頁「在程序內先啟用新的再 invalidate 舊的」以及 Pelmet、MenuBarHider「短暫 invalidate 再 AXPress 時鐘」的做法矛盾。需要在 27 上實測。
22. **時鐘要能點，bundle 清單必須有 `com.apple.MenuBarAgent`**：只靠 `allowedSystemItems` 留住時鐘，時鐘畫得出來但點了沒反應（作者說和 Hidden Bar #421 同一個問題）；
    反過來，把 `com.apple.controlcenter` 放進 bundle 清單留不住時鐘和 Control Center（MenuTidy `MenuBarRestriction.swift:33-38`, `:116-136`）。
    MenuTidy 永遠允許 `com.apple.MenuBarAgent`、`com.apple.controlcenter`、`com.apple.systemuiserver`。
23. **XPC 層的觀察**（Chest `docs/APPROACH.md:13-20`，【作者稱】）：MenuBarAgent 透過 XPC 提供 exam mode 的選單列部分；訊息帶 `origin` 欄位，1 是 assessment，0 會被接受但什麼都不藏，2 以上被拒絕。
    系統項目以名稱表示（`battery`、`bluetooth`、`clock`…），清單裡沒有相機／麥克風指示器；處理指示器的 `HideAttachedAVModule`、`AVModuleProvider` 需要 Apple 專屬的 entitlement，所以這個副作用避不掉。
24. **系統 « 的偵測**：MenuBarAgent 的 `AXExtrasMenuBar` 直接 children 裡出現 `AXRole == AXButton` 就代表 macOS 正在自己收圖示（平常只有 Control Center、時鐘兩個 `AXGroup`）；用 role 判斷避開在地化（MenuTidy `MenuBarInventory.swift:371-408`）。

## Whisky 的使用方式（建議）

- 包成一個 `MenuBarAgentVisibilityEngine`，啟動時探測可用性；不可用時退回 [Frost](../projects/frost.md) 式有界分隔線。
- 以「section → bundle ID 集合」計算 allow-list；UI 上明確告知「同一 app 的 item 會一起隱藏」。
- 管理 assertion 的生命週期：app 結束、crash 復原、權限撤銷時必定 `invalidate`。
- 不要逆向 Thaw 的 PlatformRuntimeKit（授權禁止）；只依 Hidden Bar／MenuBarHider 的公開 MIT 程式碼與 Apple 的行為推導。
- 系統 icon 做成可個別隱藏的 item（0…8；Clock、Control Center 只能藏不能移）；內建 adoption window、外部拆除偵測與 idempotent no-op；
  bundle-less 與 collateral 兩種失敗都以「實際觀察到的 bar」判定並在 UI 標示（參考 [Pelmet](../projects/pelmet.md) 的行為，不抄 GPL 程式碼）。

相關：[private-apis](private-apis.md)、[permissions](permissions.md)。
