---
title: Chest
type: project
tags: [open-source, swift, appkit, mit, menu-bar-manager, macos-27, system-settings, accessibility, no-private-api]
sources:
  - raw/github/repos/boringbar__chest
  - https://github.com/boringbar/chest
updated: 2026-10-14
---

# Chest

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [boringbar/chest](https://github.com/boringbar/chest)（BORINGBAR, LLC） |
| 授權 | **MIT** |
| 語言 | Swift（AppKit），SwiftPM（`Package.swift`），約 3,300 行；`ChestCore` 是純邏輯 package |
| Stars | 0（2026-10-14；2026-10-05 建立，2 commits） |
| 支援的 macOS | **只支援 27**（`Package.swift:6`、`Resources/Info.plist:25-26`），arm64 |
| 隱藏機制 | 改寫系統「System Settings › Menu Bar › Allow in the Menu Bar」的清單，**不用任何私有符號** |

macOS 27 的選單列管理工具：⌘ 拖曳圖示到一個「圓點」左邊就平時隱藏、展開時回到原位；拖到圓點下方的寶箱就收進「抽屜」。
它刻意不用 assessment mode（`MBAssessmentModeAssertion`），改用 Apple 自己的 per-app 開關，避開 allow-list 的副作用。
最有價值的是 `docs/APPROACH.md`：作者在 27.0.1 上的實測紀錄。

本頁 file:line 相對於 `raw/github/repos/boringbar__chest/`（commit `4bc62a5`）。
【文】＝作者在 `docs/APPROACH.md` 寫的實測（27.0.1），程式碼無法驗證。

## 架構

| 模組 | 內容 |
|---|---|
| `ChestCore` | 純邏輯：`AllowList`（解析與修改清單）、`PreferredPositions`（位置計算）、`SystemItems`（13 個系統項目）、`MenuBarGeometry`、`MoveBudget` |
| `Chest` | `ChestController`（1,208 行，主流程）、`MenuBarSwitches`（寫系統設定）、`MenuBarItems`（AX 列舉）、`MenuBarLayoutObserver`、`DrawerPanel`、`FileAccess`（檔案授權）、`Updater`（Sparkle） |

## 關鍵機制（附 file:line）

### 1. 兩個系統檔案

| 用途 | 路徑 | key |
|---|---|---|
| 「Allow in the Menu Bar」清單 | `~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist`（`Sources/Chest/FileAccess.swift:18`） | `trackedApplications` |
| 選單列版面 | `~/Library/Group Containers/com.apple.MenuBar/Library/Preferences/com.apple.MenuBar.plist`（`FileAccess.swift:20`） | `TrailingItemPreferredPositions` |

- **寫入方式**：CFPreferences，domain 填「去掉 `.plist` 的絕對路徑」，這樣讀寫的就是那個檔案，而且仍經過 cfprefsd，MenuBarAgent 會收到變更（`Sources/Chest/MenuBarSwitches.swift:20-24`）。
  用 `UserDefaults(suiteName: "group.com.apple.controlcenter")` 不行，沒有 Apple 的 app-group entitlement 會讀寫到別的檔案【文】（`docs/APPROACH.md:52`）。
- **`trackedApplications` 的格式**：值是 `Data`，裡面包一層 binary plist；結構是 key 與 entry 交替的陣列
  `[{bundle:{_0:"<id>"}}, {isAllowed, location, menuItemLocations}, …]`（`Sources/ChestCore/AllowList.swift:5-28`；`APPROACH.md:39-47`）。
  【推論】這是 Swift `Codable` 把 `[Location: Entry]` 編碼後的樣子。
  - `isAllowed` 為 false 就隱藏，欄位不存在視為 true（`AllowList.swift:26`）。
  - **只改既有 entry 的 `isAllowed`，不新增 entry**：MenuBarAgent 會忽略並取代自己寫的 entry（`AllowList.swift:12-14`；`APPROACH.md:53`）。
  - 每次讀之前都 `CFPreferencesSynchronize`，因為 MenuBarAgent 會在 Chest 執行期間新增 entry，用舊副本寫回會把它們蓋掉（`MenuBarSwitches.swift:183-197`）。【推論】讀到寫之間仍有 race。
- **生效時間**：MenuBarAgent 在 1 秒內套用【文】（`APPROACH.md:52`）；Chest 在 1.5 s 後用 AX 確認項目真的消失（`ChestController.swift:329-346`）。
- **位置表**：`TrailingItemPreferredPositions` 是 dictionary，`"status:<bundleID>::<autosaveName>"` 對應 App 的 item，`"module:<key>"` 對應 MenuBarAgent 自己的項目（例如 `module:Clock`）；
  值是距離選單列右端的距離，越大越靠左（`Sources/ChestCore/PreferredPositions.swift:3-20`；`APPROACH.md:95-104`）。
  【觀察】這和 [Pelmet](pelmet.md) 記載的位置（`com.apple.MenuBarAgent` domain、key `<bid>:Item-0`）不同，見 [移動項目](../concepts/menu-bar-item-moving.md) §3。

### 2. 用開關排序，不合成拖曳

- 【文】被重新允許的項目會落到它的 preferred position。所以 Chest 在項目還關著時先寫好位置，再打開開關（`APPROACH.md:106`）。
  從抽屜拖回選單列時，取左右鄰居位置的中點（`ChestController.swift:741-765`；`PreferredPositions.swift:65-74`）。
- **完全不合成 ⌘ 拖曳**（「Nothing is dragged on the user's behalf」，`APPROACH.md:106`）。使用者自己的 ⌘ 拖曳只用 global `NSEvent` monitor 觀察（`ChestController.swift:580-627`）。
  抽屜裡的拖曳也不用 dragging session，因為拖到螢幕頂端會打開 Mission Control（`DrawerPanel.swift:237-239`）。
- **圓點固定在左端**：用 `AXObserver` 監看 MenuBarAgent **application element** 的 `kAXLayoutChangedNotification`（掛在個別 window 上收不到，`MenuBarLayoutObserver.swift:3-8`, `:44-59`）；
  圓點左邊出現不該有的項目時，重新算位置、寫入，等 0.5 s，把 Chest **自己的** entry 關掉 1.5 s 再打開，讓圓點重新落位（`ChestController.swift:516-576`）。
- `MoveBudget`：同一個 App 每 10 分鐘最多讓圓點讓位 3 次，避免某些反覆出現消失的 App 讓圓點一直閃（`Sources/ChestCore/MoveBudget.swift:3-30`）。

### 3. 抽屜：不讓圖示回來就能打開它的選單

【文】開關關掉的 App，自己的 `AXExtrasMenuBar`（問 App，不是問 MenuBarAgent）仍然有那個 item 和它的選單（`APPROACH.md:125-129`）：

- 讀選單的 children 會讓 App 更新選單（`menuNeedsUpdate` 會執行），所以內容是最新的。
- 對關著的選單項目做 `AXPress` 會執行它，子選單也一樣。
- 對 item 本身做 `AXPress`，會在它**最後一次被畫出的位置**打開真正的選單或 popover，item 不會回來；位置無法改，popover 也不是 AX window。

Chest 的做法：自建一份 NSMenu 複本（標題、enabled、勾選、快捷鍵、子選單），掛在抽屜圖示下方；選了就對真正的 `AXMenuItem` 做 `AXPress`（`ChestController.swift:948-979`；`DrawerPanel.swift:115-123`）。
沒有選單的 item（popover）就直接 `AXPress` item；為了讓 popover 出現在合理的位置，放進抽屜前先把它的位置寫成圓點右邊（`ChestController.swift:941-944`, `:1048-1062`）。
App 在開關關掉時不提供 extra 的話，退回暫時重新允許、`AXPress`，350 ms 內沒有 UI 就送 HID 點擊再 warp 游標回原位（`:1005-1133`）。

### 4. 系統項目（Menu Bar Controls）

- **10 個 MenuBarAgent 自己畫的項目**：寫 `com.apple.controlcenter`（current host）的 key：Wi-Fi `WiFi`、Bluetooth、AirDrop、Focus `FocusModes`、Screen Mirroring、Display、Sound、Now Playing、Fast User Switching `UserSwitcher`、Timer。
  值 8 = 隱藏、2 = 顯示（或「啟用時顯示」）、18 = 一律顯示，key 不存在 = 預設；立即生效，不需要檔案授權（`Sources/ChestCore/SystemItems.swift:6-46`；`APPROACH.md:64`）。
  隱藏前把原值存起來，crash 後也能還原（`SystemItems.swift:60-81`）。
- **另外 3 個**：Spotlight（`com.apple.Spotlight` 的 `MenuItemHidden`）、Text Input（`com.apple.TextInputMenu` 的 `visible`）、
  Weather（只寫 key 沒用，要 `launchctl bootout gui/<uid>/com.apple.weather.menu`，重新登入後會回來）（`MenuBarSwitches.swift:39-118`）。
- **做不到**：Clock、Control Center、Control Gallery 加的控制項；Time Machine、VPN、Battery 還沒對應（`SystemItems.swift:32-34`；`APPROACH.md:81`）。

### 5. 重啟 MenuBarAgent

- 「Refresh Menu Bar」用 `kill(pid, SIGTERM)` 結束 MenuBarAgent，launchd 立刻重啟，選單列閃一下；重啟後 MenuBarAgent 會把每個有 item 的執行中 App 列進清單（`ChestController.swift:357-363`；`APPROACH.md:54`）。
- NSWorkspace 不會通知 MenuBarAgent 的結束與啟動，所以用 `DispatchSource.makeProcessSource(.exit)` 監看（`MenuBarLayoutObserver.swift:62-94`）。
- 自動重啟（每 30 s 最多一次）的情況：關掉後項目還在、有項目的 entry 不見了、圓點關掉後沒消失。
  【文】MenuBarAgent 有時會停止套用變更，作者在約 70 個 App 時遇到過，觸發條件不明（`APPROACH.md:60`；`ChestController.swift:318-321`）。

### 6. 列舉

- 走 **MenuBarAgent 的 AX**：`AXWindows`（每條選單列、每個 Space 各一個）→ slot（帶 frame）→ 第一個子元素；
  是 `AXApplication` 就用 pid 換 bundle ID，是 MenuBarAgent 自己的 hosting view 就讀 `AXIdentifier`（`com.apple.menuextra.<name>`）（`MenuBarItems.swift:155-178`）。
- 被藏的項目讀 App 自己的 `AXExtrasMenuBar`（`:86-99`）。messaging timeout 1 s，全部在 main thread 以外。
- 判斷「選單開著」用 CGWindowList：popUpMenu level、頂邊貼著選單列（`MenuBarItems.swift:231-251`；`MenuBarGeometry.swift:8-18`）。

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| 兩個系統檔案的存取 | 必要 | `NSOpenPanel` 開在檔案所在資料夾，只讓那個檔案可選（按鈕叫「Allow」），存 `.withSecurityScope` bookmark，啟動時 `startAccessingSecurityScopedResource()` 並持有到結束（`FileAccess.swift:64-128`）。【文】選取後 macOS 允許讀寫那一個檔案（含 CFPreferences），立即生效、重開後仍在（`APPROACH.md:147`）。有 Full Disk Access 就不用選 |
| Accessibility | 必要 | MenuBarAgent 的 AX、`AXObserver`、`AXPress`、合成點擊（`Permissions.swift:15-25`） |

- 判斷有沒有檔案權限只看 `open(path, O_RDONLY)` 是否成功（`FileAccess.swift:56-62`）。
- 不是 sandbox（會執行 `launchctl`、對系統程序送 SIGTERM、寫其他 App 的 preferences）。
- 【文】授權綁在簽章的 designated requirement 上，ad-hoc 建置要固定 requirement，否則每次重建都掉授權（`APPROACH.md:148`）。

## 已知問題

- **fail-closed**：crash 或被強制結束時，項目停在關閉狀態，直到 Chest 再次執行或使用者自己到系統設定打開（`main.swift:29-31`；`APPROACH.md:154`）。
  重新啟動後 Chest 會**繼續藏**，不是恢復顯示（`ChestController.swift:129-131`）。沒有 watchdog 或 helper。
  【推論】檔案授權遺失時，正常結束也無法把項目打開（`restoreAll` 的寫入結果被忽略，`:146`）。`brew --zap` 只刪 Chest 自己的設定，系統開關仍維持關閉（`Casks/chest.rb:25-29`）。
- **寫入錯誤幾乎不處理**：`CFPreferencesSetValue`、`Synchronize` 的回傳值都沒檢查（`MenuBarSwitches.swift:193-194`）。
- **以 App 為單位**；新 App 要等 MenuBarAgent 把它列進清單；系統設定的 Menu Bar 頁一打開，會刪掉放在暫存資料夾的 App 的 entry（`APPROACH.md:58`）。
- 文件與程式不一致：README 說不連網，但內建 Sparkle（`Updater.swift:4-18`）；Cask 還寫著需要 Full Disk Access（`Casks/chest.rb:30-33`）；
  APPROACH 說 `SystemItems`、`dotPlacement`、`MoveBudget` 有測試，這個 commit 沒有。

## 對 Whisky 的參考價值

- **27 上唯一不靠私有 API、又不動游標的隱藏與排序方法**：開關關掉＝真正不畫（不是收進 «），重開機仍保留；排序靠「關著時寫位置再打開」。
  allow-list 的副作用（Focus、相機／麥克風指示、時鐘、/Applications 以外的 App）都沒有（【文】`APPROACH.md:28`）。
- **代價**：格式沒有文件、要求使用者在 Open panel 裡選兩個隱藏檔案、會殺 MenuBarAgent、fail-closed。
  若 Whisky 採用，必須自己做 journal（記下關了哪些、原值是什麼），啟動時對帳，並在 UI 清楚說明「Whisky 沒有正常結束時圖示會保持隱藏」。
- 這條路線和 [MenuTidy](menutidy.md) 的 holder 行程、[Pelmet](pelmet.md) 的 allow-list 互補：Clock、Control Center 只有 allow-list 能藏。兩者能不能混用要實測。
- APPROACH 對 assessment mode 的補充（XPC 的 `origin` 欄位、相機／麥克風指示器需要 Apple 專屬 entitlement）已寫進 [allow-list](../concepts/menubar-agent-allow-list.md)。
- 驗證項目見 [路線圖](../synthesis/roadmap.md) M0 的 S6。

## 授權注意

MIT，引用或複製程式碼要保留版權聲明。依乾淨室規則，wiki 只描述行為。
