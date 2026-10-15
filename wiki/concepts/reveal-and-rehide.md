---
title: 顯示觸發、自動收回、hotkey、profiles 與 triggers
type: concept
tags: [hover, rehide, hotkeys, profiles, triggers, event-monitor]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/frostbar__frost
  - raw/github/repos/happy666End__MenuBarHider
  - raw/github/repos/FelixKratz__SketchyBar
updated: 2026-10-14
---

# 顯示觸發、自動收回、hotkey、profiles 與 triggers

## 顯示觸發

| 觸發 | 實作 | 專案 |
|---|---|---|
| 點自己的圖示 | `NSStatusBarButton` action；⌥-click 連 always-hidden 一起顯示 | 全部 |
| 點選單列空白處 | 全域 `NSEvent` monitor；「空白」= 在選單列內、不在 app menu（AX 取範圍）、不在任何 item、不在瀏海 | [Ice](../projects/ice.md) `EventManager.swift:148`, `:515-520`；[Thaw](../projects/thaw.md)（另有 show-on-click guard event tap，`HIDEventManager.swift:360`）；SaneBar |
| hover | 全域 `.mouseMoved` monitor + dwell（Ice 可設延遲；Hidden 0.5 s；SaneBar 2 s，帶 24 px 偵測帶與 200 px 離開閾值） | Ice `:348-399`；[Hidden Bar](../projects/hidden-bar.md) `StatusBarController.swift:96-118`；[SaneBar](../projects/sanebar.md) `HoverService.swift:121-293` |
| scroll／swipe | `.scrollWheel` monitor | Ice `:401`；Thaw；SaneBar `:295-318` |
| ⌘-drag 時全部顯示 | 偵測使用者開始 ⌘-drag，展開所有 section 方便排列 | Ice `:316`；Thaw `showAllSectionsOnUserDrag`；SaneBar `:331-364` |
| 全域 hotkey | 見下 | |
| URL scheme／AppleScript／Shortcuts | `thaw://toggle-hidden`；SaneBar 約 30 個 AppleScript 指令與 App Intents | Thaw `docs/URI_SCHEMES.md`；SaneBar `Resources/SaneBar.sdef` |

全域 `NSEvent.addGlobalMonitorForEvents` 監看滑鼠**不需要** Input Monitoring 權限。Ice 在移動 item 時暫停所有 monitor（`MenuBarItemManager.swift:1102-1105`），
避免自己的合成事件觸發顯示。

## 自動收回（rehide）

| 專案 | 策略 | 細節 |
|---|---|---|
| [Ice](../projects/ice.md)／[Thaw](../projects/thaw.md) | smart（點別處就收）、timed、focusedApp（切換前景 app 時收） | `MenuBarManager.swift:118-125`；`EventManager.swift:180-210`；`MenuBarSection.swift:242-298` |
| [SaneBar](../projects/sanebar.md) | 預設 5 s；搜尋點開的 item 15 s；切換 app 也收 | 觸發時檢查：正在移動、瀏覽面板開著、menu 開著、游標在選單列內就延後（`MenuBarVisibilityWorkflow.swift:16-60`） |
| [Hidden Bar](../projects/hidden-bar.md) | 預設 10 s（5／10／15／30／60） | 游標在選單列或設定視窗開著時重新計時（`StatusBarController.swift:302-323`） |
| [Frost](../projects/frost.md) | 預設 15 s | menu 開著或游標在選單列時延後；點外面立即收（`SectionController.swift:928-970`） |
| [MenuBarHider](../projects/menubarhider.md) | 預設 10 s（0／5／10／30／60） | |

共通經驗：**item 的 menu 開著時不能收**——Ice 記錄點擊後新出現的同 PID window（`MenuBarItemManager.swift:1376-1420`），Frost 偵測 layer 101 window。

## Hotkey

| 專案 | 實作 |
|---|---|
| [Ice](../projects/ice.md)、[Thaw](../projects/thaw.md)、[MenubarHide](../projects/menubarhide.md) | 自己寫 Carbon `InstallEventHandler` + `RegisterEventHotKey` |
| [Hidden Bar](../projects/hidden-bar.md) | soffes/HotKey |
| [SaneBar](../projects/sanebar.md) | sindresorhus/KeyboardShortcuts（含 per-icon hotkey） |
| [Frost](../projects/frost.md)、[MenuBarHider](../projects/menubarhider.md) | 無 |

Thaw 的 hotkey 動作：切換各 section、搜尋面板、Thaw Bar、分隔線圖示、app menu、自動收回、zen mode、打開特定 item 的 menu、切換 profile（README）。
建議 Whisky 直接用 KeyboardShortcuts（見 [supporting-libraries](../projects/supporting-libraries.md)）。

## Profiles

| 專案 | 內容 | 自動切換 |
|---|---|---|
| [Thaw](../projects/thaw.md) | 整份設定 + layout；可匯入匯出；前後置腳本 hook（匯入的腳本預設停用） | 綁 display UUID、Space、Focus filter（`Thaw/Settings/Models/Profile.swift:18-27`） |
| [SaneBar](../projects/sanebar.md) | 設定 + layout 快照 + 自訂圖示，最多 50 個 | 由 triggers 切換（`Core/Models/SaneBarProfile.swift:213-233`） |
| Ice | 有 `profiles` 分支（2024-10 停在那裡），未發布 | — |

## Triggers（條件觸發顯示／隱藏某個 item）

| 條件 | Thaw | SaneBar | 實作提示 |
|---|---|---|---|
| 前景 app／app 啟動 | ✓ | ✓ | `NSWorkspace` 通知 |
| 電量／電源 | ✓ | ✓ | IOPS（`IOPSNotificationCreateRunLoopSource`） |
| Wi-Fi 網路 | ✓ | ✓ | CoreWLAN SSID（SaneBar 不要 Location，`NetworkTriggerService.swift:30-54`） |
| Focus／勿擾 | ✓ | ✓ | SaneBar 讀 `~/Library/DoNotDisturb/DB/*.json` + `com.apple.donotdisturb.stateChanged`（`FocusModeService.swift:29-66`）；Thaw 用 Focus filter intent |
| 排程 | ✓ | ✓ | Timer |
| 腳本結束碼 | ✓ | ✓ | `Process`（SaneBar `ScriptTriggerService.swift:29-88`） |
| 網路／VPN／藍牙／音訊輸出／外接螢幕／位置／Energy Mode／熱壓力／相機麥克風使用中 | ✓ | — | 多數預設關閉、在 Developer 設定逐一開啟（Thaw README） |
| item 圖示變化或閃爍 | ✓ | — | 需要 Screen Recording（比對擷取影像） |

[SketchyBar](../projects/sketchybar.md) 的事件來源（SCDynamicStore、CoreAudio、DisplayServices、MediaRemote…）也可當 trigger 實作索引。

## 其他專案的觸發條件與收回時機（2026-10-14 補）

| 點子 | 出處 |
|---|---|
| Presentation mode：偵測到螢幕鏡像、macOS Screen Sharing 或 Zoom 會議時只留必要圖示（瀏覽器、Teams、FaceTime 的分享偵測不到） | [Stash](../../raw/github/readmes/brentc22__stash.md) |
| 這個 App 在前景時顯示它的圖示；Wi-Fi 只在斷線時出現（Bartender 的 App、Wi-Fi trigger 已有同類） | Stash |
| 麥克風開啟時觸發規則；Zen 一鍵清空所有 App 圖示；向下滑動或點選單列空白處展開 | [Meno](../../raw/github/readmes/whrss9527__meno.md) |
| 切換 App 時自動收回 | [Bouncer](../../raw/github/readmes/fstermann__bouncer.md) |
| 喚醒、解鎖、換顯示器後自動重新折疊並重試；顯示器變動時先全部展開 | [FoldBar](../../raw/github/readmes/william-jin-cmu__FoldBar.md) |
| 睡眠或鎖定時放開隱藏，喚醒或解鎖時恢復 | [NookBar](../../raw/github/readmes/kevinLay7__NookBar.md) |
| 選單開著或指標在選單列上時不收回 | [Blinds](../../raw/github/readmes/massimodascola__blinds.md)、[overfold](../../raw/github/readmes/howells__overfold.md)、MenuTidy |
| 在 chevron 上捲動：一個方向顯示、反方向隱藏 | [BarManager](../../raw/github/readmes/nick318__bar-manager.md) |
| 內建螢幕和外接螢幕各自的點擊模式 | [SmartHiddenBar](../../raw/github/readmes/roypadina__SmartHiddenBar.md) |

上表出自 README。**判斷「有沒有選單開著」**的兩種實作（已讀原始碼）：

- [MenuTidy](../projects/menutidy.md)：CGWindowList 裡有沒有 layer **剛好等於** `CGWindowLevelForKey(.popUpMenuWindow)`（101）的 on-screen 視窗；用「等於」是因為某些 App 一直有 999 層的視窗（`main.swift:570-591`）。
- [Chest](../projects/chest.md)：pop-up menu level，而且頂邊在選單列下方 12 pt 以內（`MenuBarItems.swift:231-251`；`MenuBarGeometry.swift:8-18`）。
- 兩者都只讀 layer、bounds、owner PID，不需要 Screen Recording。

## 對 Whisky 的建議

- 事件層：一個集中式的 global event monitor（滑鼠移動、點擊、scroll、flagsChanged），移動 item 時暫停。
- rehide 用「可取消的 generation task」（SaneBar `HidingService.swift:383-428`），每次觸發前檢查 menu 是否開著、游標是否在選單列。
- Profiles／triggers 的資料模型可參考 Thaw（綁 display／Space／Focus）與 SaneBar（triggers 切 profile），兩者都對應 Bartender 的 Triggers 功能。
