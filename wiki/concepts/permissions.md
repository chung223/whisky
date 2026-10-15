---
title: 選單列管理工具需要的權限
type: concept
tags: [permissions, tcc, accessibility, screen-recording, sandbox]
sources:
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice/Ice/Permissions/Permission.swift
  - raw/github/repos/thaw-app__Thaw/Thaw/Permissions/Permission.swift
  - raw/github/repos/frostbar__frost
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/happy666End__MenuBarHider
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/FelixKratz__SketchyBar
  - raw/articles/2026-10-12-macbartender-permission-docs.md
  - raw/articles/2026-10-12-9to5mac-sequoia-screen-recording-prompts.md
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-14
---

# 選單列管理工具需要的權限

## 總表

| 專案 | Accessibility | Screen Recording | 其他 | 不給權限時還能做什麼 |
|---|---|---|---|---|
| [Ice](../projects/ice.md) | **必要** | 選用 | — | 無法啟動主功能 |
| [Thaw](../projects/thaw.md) | **必要**（主程式 + XPC） | 選用 | 27 alpha 有實驗性「無 Accessibility」模式 | 27：以 app 為單位隱藏 |
| [SaneBar](../projects/sanebar.md) | **必要** | **刻意不用** | Apple Events（AppleScript）、LocalAuthentication（Touch ID） | — |
| [Frost](../projects/frost.md) | Frost Bar／Layout 需要 | 選用 | Post Event（27 點擊前 `CGPreflightPostEventAccess`） | 隱藏／顯示完全不需權限 |
| [Hidden Bar](../projects/hidden-bar.md) | 27 與 Notch Overflow 需要 | 不用 | — | ≤ 26 分隔線不需權限 |
| [MenuBarHider](../projects/menubarhider.md) | **必要** | 不用 | — | 什麼都不能做 |
| [MenubarHide](../projects/menubarhide.md) | 只在 panel 點擊時 | 只在 panel 擷取時 | — | Sideways 模式不需權限 |
| [SketchyBar](../projects/sketchybar.md) | 不用 | 只有 alias 需要 | — | 自己的 bar 照常運作 |
| [Pelmet](../projects/pelmet.md)（27） | **必要**（讀 MenuBarAgent AX tree、合成拖曳與點擊、active event tap） | 選用，**只為動畫 cover**（拍整條選單列兩張圖疊在系統動畫上） | — | assertion 本身不需權限，但沒有 Accessibility 就無法列舉、算不出 allow-list |

## Accessibility：為什麼需要

1. **讀別人的 item**：`AXExtrasMenuBar` 的 children、位置、identifier（見 [menu-bar-item-enumeration](menu-bar-item-enumeration.md)）。在 macOS 26 上
   還要用它把 window 對回真正擁有者，在 27 上它是唯一來源。
2. **送合成事件**：⌘-drag 移動、點擊轉送（`CGEvent.post` 對其他 app 生效需要 Accessibility／post-event 權限）。
3. **AXPress** 打開 item 的 menu。
4. **找 app menu 範圍**（Ice「Hide application menus」）。

Ice 的說明文字：「Get real-time information about the menu bar」「Arrange menu bar items」（`Ice/Permissions/Permission.swift:118-136`）；
Thaw：偵測 item 與位置、移動、代替使用者點擊（`Thaw/Permissions/Permission.swift:123-146`）。

檢查與請求：`AXIsProcessTrusted()`／`AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`；深層連結
`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`。授權後即時生效的偵測：監聽 distributed notification
`com.apple.accessibility.api`（Frost `PermissionsService.swift:52-62`；SaneBar `AccessibilityService.swift:189-202`）並輔以輪詢
（MenuBarHider 每 2 s；SaneBar 0.5 s → 2 s，最多 5 分鐘）。XPC helper 也要各自被授權（Thaw `SourcePIDCache.swift:477-481`）。

## Screen Recording：為什麼需要

1. **擷取 item 圖像**給獨立 bar、layout 編輯器、搜尋（見 [menu-bar-item-imaging](menu-bar-item-imaging.md)）。
2. **讀 `kCGWindowName`**：沒有權限時別人 window 的 name 被隱藏；Ice 用 item 的 autosave name 當身分，所以 Ice 甚至用「有沒有 title」反推權限
   （`Ice/Utilities/ScreenCapture.swift:12-23`）；SketchyBar 的 alias 因此完全失效（`src/alias.c:98-100`）。
3. **外觀**：擷取桌布在選單列範圍的影像畫 tint／形狀（Ice `MenuBarOverlayPanel.swift:296-303`）、取主色做 adaptive tint（Thaw）。

坑：

- macOS 15 上 `CGRequestScreenCaptureAccess()` 壞掉，Ice 改呼叫 `SCShareableContent.getWithCompletionHandler` 觸發提示（`ScreenCapture.swift:47-55`）。
- `CGPreflightScreenCaptureAccess()` 只反映啟動時的值；授權後通常要**重開 app**（MenubarHide、Frost 都提供 Relaunch 按鈕）。
- 重開機後一直重新要求（Thaw #683）；換簽章（Debug／Release）會讓 TCC 授權失效（MenubarHide README `:134`）。
- macOS 15 起週期性的「仍在錄製螢幕」提示（見 `raw/articles/2026-10-12-9to5mac-sequoia-screen-recording-prompts.md`），使用 deprecated 擷取 API
  的 app 提示更多——這是 SaneBar 與 Frost 把 Screen Recording 做成選用的主要原因。

## 其他

- **Sandbox**：所有能管理別人 item 的專案都不 sandbox。Hidden Bar 的 App Store 版有 sandbox，在 27 上因擋住 `com.apple.axserver` 而無法隱藏
  （`AccessibilityMenuBarInventory.swift:13-15`）。私有 API 也不能上 App Store。
- **Hardened runtime + Developer ID + notarization**：Thaw、Frost、MenubarHide、IceMelt 都這樣發布；MenuBarHider 只 ad-hoc 簽章。
- **/Applications**：macOS 27 的 allow-list 只認 /Applications 底下的 app（見 [menubar-agent-allow-list](menubar-agent-allow-list.md)）。
- **Input Monitoring**：本次研究的專案都沒有要求（全域 `NSEvent` monitor 監看滑鼠移動不需要它；監看按鍵才需要）。
- Bartender 自己的權限說明見 `raw/articles/2026-10-12-macbartender-permission-docs.md`（由另一個 agent 整理）。
- **[Pelmet](../projects/pelmet.md) 的權限細節**（路徑相對於 `raw/github/repos/fif7y__pelmet/`）：
  - Active event tap（`.cghidEventTap` 吞掉拖曳中的實體滑鼠事件、`.cgSessionEventTap` 攔截 clock 點擊）只靠 Accessibility，沒有要求 Input Monitoring；
    hotkey 用 Carbon `RegisterEventHotKey`（`Packages/PelmetEngine/Sources/PelmetEngine/ItemMover.swift:273-322`；`Pelmet/Events/ClockClickRelay.swift:106-139`；
    `Pelmet/Events/HotkeyManager.swift:1-3`）。
  - App Translocation：從 DMG 或隔離中的 Downloads 執行時，TCC 記在暫存路徑上，搬走就失效；Pelmet 偵測 `/AppTranslocation/` 並提示搬到 /Applications，
    授權列卡住時執行 `/usr/bin/tccutil reset Accessibility <bundleID>` 重來（`Pelmet/App/AccessibilityAccess.swift:73-78`, `:93-95`, `:103-117`；`docs/FAQ.md:38-43`）。
  - Screen Recording 只在第一次需要 cover 時問一次；使用者拒絕後不再自動打開系統設定（issue #11，`AccessibilityAccess.swift:120-142`）。每次擷取都會點亮錄影指示，
    clock 點擊的 blink 也會（#45）。
  - Xcode DerivedData 裡跑的 app 沒有穩定的 LaunchServices 註冊，allow-list 認不到，Pelmet 開著時會一直被藏（`docs/FAQ.md:186-192`）。

## 權限實作的坑（2026-10-14 補，[MenuTidy](../projects/menutidy.md)、[Mezzanine](../projects/mezzanine.md)、[Chest](../projects/chest.md)）

- **偵測 Accessibility 授權變化**：observe distributed notification `com.apple.accessibility.api` 時要用 `.deliverImmediately`，否則 App 不在前景時通知會被壓住；
  `AXIsProcessTrusted()` 有程序內快取，收到通知立刻讀會讀到舊值，MenuTidy 先等 1.5 s 再讀，另外每 1 s 輪詢（`JorvikKit/JorvikPermissionWatcher.swift:18-147`）。
- **TCC 授權綁簽章的 designated requirement**：ad-hoc 簽章的 requirement 是 binary hash，每次重建都會掉授權，而且 `codesign --verify` 查不出來（MenuTidy `Makefile:40-52`）；
  Chest 給 ad-hoc 建置固定 `designated => identifier "app.boringbar.chest"`（`docs/APPROACH.md:148`）；從 development 簽章換成 Developer ID 也要重新授權（Mezzanine `NOTES.md:384-391`）。
  → Whisky 在 M0 就要用固定的簽章身分建置。
- **sandbox 會讓 AX 靜默失效**：Mezzanine 實驗中開 sandbox 後讀不到任何 App 的 extras，但 `AXIsProcessTrusted()` 仍回 true（`NOTES.md:166-184`）。
- **App icon 一定要有**：`LSUIElement` App 沒有 icon 時，在 Screen Recording 設定頁會顯示空白圖示，看起來像惡意程式（Mezzanine `NOTES.md:157-162`）。
- **受保護的系統檔案**：Chest 讓使用者在 `NSOpenPanel` 選取 `~/Library/Group Containers/` 下的單一 plist，存 security-scoped bookmark，就能讀寫那個檔案（含 CFPreferences），不需要 Full Disk Access（`FileAccess.swift:64-128`）。
  判斷有沒有權限只看 `open(path, O_RDONLY)` 是否成功。

## 對 Whisky 的建議

- 權限分級：**零權限**＝隱藏／顯示（26 分隔線；27 有界分隔線）；**Accessibility**＝排列、點擊、27 allow-list、搜尋；**Screen Recording**＝真實圖像與外觀取色。
- 每個功能在 UI 上標出需要的權限，沒有時優雅降級（Frost 的 `PermissionCapabilities` 是好範本）。
- 偵測 App Translocation 並引導搬到 /Applications（27 的 allow-list 與 TCC 都依賴穩定路徑，見 [Pelmet](../projects/pelmet.md)）。
