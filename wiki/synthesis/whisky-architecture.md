---
title: Whisky 架構提案
type: synthesis
tags: [whisky, architecture, swift, appkit, macos-26, macos-27, proposal]
sources:
  - wiki/projects/long-tail.md
  - wiki/comparisons/feature-ideas.md
  - wiki/bartender/architecture.md
  - wiki/bartender/mechanisms.md
  - wiki/bartender/features-from-resources.md
  - wiki/bartender/history.md
  - wiki/concepts/macos-menu-bar-platform.md
  - wiki/concepts/menubar-agent-allow-list.md
  - wiki/concepts/status-item-hiding.md
  - wiki/concepts/menu-bar-item-enumeration.md
  - wiki/concepts/menu-bar-item-moving.md
  - wiki/comparisons/open-source-menu-bar-managers.md
  - wiki/projects/frost.md
  - wiki/projects/pelmet.md
  - wiki/projects/supporting-libraries.md
updated: 2026-10-14
---

# Whisky 架構提案（v0.1）

狀態：**提案，尚未定案**。第 10 節的決定事項需要使用者拍板。開發順序見 [路線圖](roadmap.md)。

## 0. 一句話

Whisky 把選單列項目分成 **Shown / Hidden / Always Hidden** 三區，需要時顯示隱藏區，並提供自己的 bar 與搜尋來點擊被藏的項目。
**平台層依 macOS 版本分成兩個後端**（26 Tahoe、27 Golden Gate），資料模型、UI、熱鍵、觸發條件全部共用。

## 1. 前提與範圍（建議）

| 項目 | 建議 | 理由 |
|---|---|---|
| 支援的 macOS | **26 與 27**，部署目標 26.0 | 開發機是 macOS 26.7；27 已在 2026-09-14 發佈。14/15 會多出兩套行為，Thaw、Frost、IceMelt 也只支援 26 以上（[比較](../comparisons/open-source-menu-bar-managers.md)） |
| CPU | 只做 arm64 | 27 不支援 Intel；開發機是 M4 Pro。之後若要支援 Intel 上的 26，改成 Universal 的成本很低 |
| 工具鏈 | Xcode 27 / macOS 27 SDK，Swift 6 語言模式（strict concurrency） | 已安裝；27 的 `NSStatusItem` expanded interface API 需要 27 SDK |
| 發佈 | Developer ID + notarization + Sparkle，不上 App Store | 必須非 sandbox（27 的 allow-list 與 AX 都需要），也用到私有 API（[allow-list](../concepts/menubar-agent-allow-list.md) 限制 6） |
| 安裝位置 | 必須在 `/Applications` | 27 的 allow-list 只認得 /Applications 下的 App，連 Whisky 自己的圖示都會被藏（同上，限制 2） |
| 權限 | Accessibility **必要**；Screen Recording **選用** | 預設用 App icon，不擷取畫面；這是 Bartender 7、Thaw 的方向（[平台](../concepts/macos-menu-bar-platform.md) §7-2） |

## 2. 設計原則（從研究歸納）

1. **用「區段」描述意圖，不用「位置」**（sets, not positions）。
   改變可見性要即時、不碰游標；真的去搬動項目只在使用者按「套用」時才做。預設採 On-Demand，Live 是選項。
   - 依據：Bartender 6 在 Tahoe 上最大的抱怨是 Live 模式會定期移動使用者的滑鼠（[歷史](../bartender/history.md)）。
   - Bartender 自己也提供 On-Demand 模式（[資源檔](../bartender/features-from-resources.md)），Pelmet 也採同樣的產品原則（[Pelmet](../projects/pelmet.md)）。
2. **用 Accessibility 辨識項目**，不用 window ID 或 owner PID。
   26 上所有項目視窗都歸 Control Center 所有，27 上根本沒有個別視窗（[列舉](../concepts/menu-bar-item-enumeration.md)）。window ID 只在 26 上拿來輔助移動與擷取。
3. **出錯就全部顯示**（fail-open）。
   Whisky 當掉、拋錯或權限被撤銷時，所有項目都要回到可見。27 的 assertion 綁在程序上，程序結束系統就會自動恢復（[allow-list](../concepts/menubar-agent-allow-list.md)）。
   26 的分隔項目在 Whisky 結束時也會消失，項目自然回到可見。
4. **私有 API 集中在一個模組**。
   啟動時逐一探測能力（`dlopen`、`NSClassFromString`、`instancesRespondToSelector:`），不可用就自動降級，絕不 crash。
   （2026-10-14 補）27 的 assertion 不在主程式裡建立，而是放在可以被殺掉的 **holder 子程序**：私有 API 崩潰只會讓子程序死掉（等於全部顯示），主程式崩潰時子程序偵測到父程序消失就自己結束；作者實測同一個程序 `invalidate()` 後通知中心仍打不開，只有程序結束才恢復（[MenuTidy](../projects/menutidy.md)、[allow-list](../concepts/menubar-agent-allow-list.md) 第 21 點，待驗證）。
5. **AX 查詢放在 XPC 服務裡跑**，每次都設 timeout，並記錄負快取。
   遇到無回應的 App，AX 呼叫會卡住，所以不能在主程式裡做。Bartender 為 26 專門寫了 `TahoeXPC`（[機制](../bartender/mechanisms.md) §2），Thaw 也是同樣做法。
6. **Screen Recording 是選配**。
   沒有這個權限時一律顯示 App icon；有的話只用 ScreenCaptureKit（`CGWindowListCreateImage` 已不能用）。
   不要像 Bartender 那樣直接改寫 `ScreenCaptureApprovals.plist`（[架構](../bartender/architecture.md)「權限」）。
7. **乾淨室**。
   不從 Bartender 的偽代碼轉寫程式；GPL 專案（Ice、Thaw、Pelmet、SketchyBar）只學機制，不複製程式碼（除非第 10 節決定改用 GPL）。
8. **不連網、不收集資料**。
   只有 Sparkle 會連網取 appcast。Bartender 2024 年的信任風波（Amplitude、所有權變更）就是教訓（[歷史](../bartender/history.md)）。

## 3. 程序與模組

```
┌──────────────────────── Whisky.app（LSUIElement，非 sandbox）────────────────────────┐
│ App 層（AppKit + SwiftUI）                                                            │
│   ControlItems  RevealController  WhiskyBar  QuickSearch  Settings  Onboarding        │
│   Hotkeys(KeyboardShortcuts)  Automation(URL scheme / App Intents)  Updater(Sparkle)  │
│                                   │                                                   │
│ Engine 層        LayoutEngine（比對快照、算出計畫） ─── MenuBarBackend（protocol）    │
│                                   │                 ┌──────────┴───────────┐          │
│                                   │           TahoeBackend(26)   GoldenGateBackend(27)│
│ 基礎模組   WhiskyModel  WhiskyEvents  WhiskyCapture  WhiskyPrivate  WhiskyAXClient   │
└───────────────────────────────────────┬───────────────────────────────────────────────┘
                                        │ XPC（Swift XPC framework，同 team 簽章驗證）
┌───────────────────────────────────────┴──────────────┐
│ WhiskyAXService.xpc：AX 列舉（各 App 的 AXExtrasMenuBar、│
│ 27 的 MenuBarAgent AX tree），timeout、負快取、慢 App 記錄 │
└──────────────────────────────────────────────────────┘
```

| 模組 | 內容 | 依賴 |
|---|---|---|
| `WhiskyModel` | `ItemIdentity`、`MenuBarItem`、`Section`、`Layout`、`Preset`、`Trigger`、設定；全部 `Codable`、`Sendable` | 無（純 Swift，可完整單元測試） |
| `WhiskyPlatform` | `MenuBarBackend` protocol、`BackendCapabilities`、`MenuBarSnapshot`、`VisibilityPlan`、`ArrangePlan`；兩個後端實作 | Model、AXClient、Events、Capture、Private |
| `WhiskyAXClient` / `WhiskyAXService` | AX 薄包裝（`AXUIElementSetMessagingTimeout`、背景執行）；XPC 介面 `snapshot(pids:)` | ApplicationServices |
| `WhiskyEvents` | CGEvent ⌘-drag 與點擊合成、`InputShield`（移動中用 active event tap 擋住使用者輸入）、`CursorConcealment` | CoreGraphics |
| `WhiskyCapture` | `SCScreenshotManager` 擷取指定矩形、圖片快取、App icon 退路 | ScreenCaptureKit |
| `WhiskyPrivate` | ObjC shim：`MenuBarClientCore`（`MBAssessmentMode*`）、`SetsCursorInBackground`、`CoreMenuExtra*`、事件欄位 `0x33`；每項都有能力探測 | Foundation（`dlopen`） |

外部依賴只有兩個，都是 MIT：**KeyboardShortcuts**（Bartender 6 自己也內含）與 **Sparkle 2**。
登入啟動直接呼叫 `SMAppService.mainApp`（[函式庫](../projects/supporting-libraries.md)）。

## 4. 平台後端

```swift
protocol MenuBarBackend: Actor {
    var capabilities: BackendCapabilities { get }
    func snapshot() async throws -> MenuBarSnapshot                  // 項目、順序、frame、所在螢幕
    func apply(_ plan: VisibilityPlan) async throws                  // 即時、不碰游標
    func arrange(_ plan: ArrangePlan, shield: InputShield) async throws -> ArrangeReport  // 會動游標，只在「套用」時
    func activate(_ item: ItemIdentity, click: ClickKind) async throws
}

struct BackendCapabilities {
    var visibilityGranularity: Granularity   // .item（26）或 .bundle（27）
    var canHideSystemItems: Bool             // 27 allow-list 可以；26 分隔項目做不到（系統項目在最右側）
    var canRevealInPlace: Bool               // 在選單列原地展開隱藏區
    var canCaptureItemImages: Bool           // 需 Screen Recording；27 被藏的項目擷取不到
    var canArrange: Bool
}
```

UI 與 `LayoutEngine` 只看 `capabilities`，不直接判斷 OS 版本。這和 Frost「啟動時選一次 backend」的做法相同（[Frost](../projects/frost.md)）。

| 能力 | TahoeBackend（macOS 26） | GoldenGateBackend（macOS 27） |
|---|---|---|
| 列舉 | XPC 讀各 App 的 `AXExtrasMenuBar` frame，對應 `CGWindowListCopyWindowInfo` layer 25 的視窗（midX 容差，前後快照一致才算穩定） | 走 MenuBarAgent 的 AX tree，並和逐 App 的 `AXExtrasMenuBar` 交叉驗證；兩者在 27 上是否一致要先實測 |
| 隱藏 | 兩個自有分隔項目（Hidden、Always Hidden）把 `length` 撐開，系統會夾到約 5,016 pt，把左側推出螢幕 | 私有 `MBAssessmentModeAssertion` allow-list，**以 bundle 為單位**，系統項目用編號 0–8；不可用時退回有界分隔項目（寬度低於螢幕一半，靠系統 «；[隱藏手法](../concepts/status-item-hiding.md) §5.2） |
| 顯示 | 縮回分隔項目（原地顯示），或開 Whisky Bar | 換一份 allow-list（先啟用新的、成功後再作廢舊的），或開 Whisky Bar |
| 排序 | ⌘-drag，事件欄位 `0x33` 填目標 window ID，送給 Control Center PID；失敗退回從項目本身開始的真實拖曳 | 只有從項目本身開始的 HID 真實 ⌘-drag 有效；先展開所有區段，用 `AXUIElementCopyElementAtPosition` 確認目標 |
| 點擊 | 暫時顯示 → 合成點擊，或 `AXPress` | 暫時把該 bundle 加回 allow-list → HID 點擊或 `AXPress` |
| 擷取 | `SCScreenshotManager` 擷取項目矩形（選用） | 被藏的項目擷取不到 → 用快取圖或 App icon |
| 特殊處理 | WindowServer CPU 尖峰時暫停（Bartender 的做法）；Live Activities | 新項目被擱置（adoption window）；collateral extras；點時鐘開通知中心要轉送；只認 /Applications；沒有 bundle ID 的 helper |

證據：[Bartender 機制](../bartender/mechanisms.md)、[隱藏](../concepts/status-item-hiding.md)、[列舉](../concepts/menu-bar-item-enumeration.md)、
[移動](../concepts/menu-bar-item-moving.md)、[allow-list](../concepts/menubar-agent-allow-list.md)。

## 5. 資料模型

- **`ItemIdentity`**：`bundleID` 加上 `identityKey`。
  - `identityKey` 依序取 `AXIdentifier` → description/title → 同一 App 內的序號。
  - 系統項目用 `com.apple.menuextra.*`；Whisky 自己的項目另有一種 kind。
  - 26 上另外記 window ID 與圖示的感知雜湊，當重開機後的輔助比對（Bartender 的 `TahoeImageIndexer`、`WindowMap` 也是這樣做，[機制](../bartender/mechanisms.md) §2）。
- **`Layout`**：三個區段，每區是有序的 `ItemIdentity` 清單，另有一條「新項目預設放哪一區」的規則。
- **27 的限制**：同一個 bundle 的項目必須在同一區。這條由 `LayoutValidator` 檢查，UI 依 `visibilityGranularity` 把項目按 App 分組；26 上不需要這條限制。
- **`Preset`**：有名字的 `Layout` 加上顯示行為設定。**`Trigger`**：條件 → 動作（套用 preset，或暫時顯示某些項目）。
- **儲存**：`~/Library/Application Support/Whisky/` 下的 JSON（`layout.json`、`presets.json`）；簡單的偏好放 UserDefaults。
  匯出成單一 `.whisky` 檔。核心資料不用 SwiftData，保持可攜、可 diff、可測。

## 6. 主要流程

1. **啟動**：
   1. 檢查權限，沒有就進入 onboarding。
   2. 探測能力並選擇後端。
   3. 建立自有項目。
   4. 取快照，和儲存的 Layout 比對。
   5. 套用可見性。
2. **顯示隱藏區**：
   1. 點擊、hover、捲動或熱鍵觸發後，`backend.apply(reveal)`。
   2. 啟動自動收回計時器。使用者正在操作選單時不收回（Bartender 監看 HIToolbox 的選單追蹤通知）。
3. **新項目出現**：
   1. 偵測：NSWorkspace 的啟動通知、AX observer，加上定期重掃。
   2. 依規則放進某個區段，再套用。
   3. 27 上要開 adoption window：短暫作廢 assertion，等項目出現再重新套用。
4. **套用排列**：
   1. 算出最少步數的 `ArrangePlan`。
   2. 開啟 `InputShield`、隱藏游標。
   3. 一次移動一個項目，每步都驗證。
   4. 失敗超過 N 次就標成「無法移動」並在 UI 顯示，不無限重試（Thaw 曾因此讓游標亂跳）。
5. **在 Whisky Bar 點擊**：`backend.activate`。有選單的項目優先用 menu mirroring（AX 讀出選單、在 Whisky 的位置重建、選了再 `AXPress` 原項目），不需要暫時顯示；沒有選單或 `AXPress` 後沒出現 UI 才退回暫時顯示再點擊（[點擊隱藏項目](../concepts/menu-bar-item-activation.md)）。

## 7. 權限與安全

- **Accessibility**：用 `AXIsProcessTrusted` 檢查，onboarding 引導使用者開啟。
  macOS Zoom 開啟時不能移動項目，要偵測並提示（Bartender 也有這個提示）。
- **Screen Recording**：只用 `CGPreflightScreenCaptureAccess`、`CGRequestScreenCaptureAccess`；27 起不能讀 TCC.db。
- **使用者在系統設定「Allow in the Menu Bar」關掉的 App**：標成 Disabled，不要嘗試管理它。
- **XPC**：服務只接受同 team、同簽章的連線（Bartender 用 `XPCPeerRequirement.isFromSameTeam`）。
- **保護措施**：watchdog 偵測到主執行緒卡住時，作廢 assertion、讓分隔項目縮回。

## 8. 專案結構（`app/`）

```
app/
  project.yml                 XcodeGen 設定（xcodegen 已安裝）
  Whisky/                     App target
    App/  ControlItems/  Reveal/  Bar/  Search/  Settings/  Onboarding/  Automation/
  WhiskyAXService/            XPC service target
  Packages/
    WhiskyModel/              純模型 + Swift Testing
    WhiskyPlatform/           protocol + TahoeBackend + GoldenGateBackend
    WhiskyAXClient/
    WhiskyEvents/
    WhiskyCapture/
    WhiskyPrivate/            ObjC shim + Swift 包裝
  Spikes/                     驗證平台行為的小程式；結果寫回 wiki
```

## 9. 驗證策略

- **單元測試**：`WhiskyModel` 與 `LayoutEngine` 用 Swift Testing，涵蓋：
  - 快照與 Layout 的比對
  - 計畫計算
  - 27 的 bundle 限制
  - 新項目規則
- **Spike 先行**：每個平台行為先寫一支只動自己項目的小程式在真機上驗證，結果寫回 wiki，再開發功能（Frost 的 `docs/macos-behavior.md` 就是這樣來的）。
  第一批要驗的問題列在 [路線圖](roadmap.md) M0。
- **macOS 27 測試環境**：開發機是 26.7，需要 macOS 27 的虛擬機（Apple silicon 可以用 Virtualization.framework，例如 UTM 或 Tart）或第二台 Mac。
- **fail-open 測試**：在移動、assertion 生效等狀態下 `kill -9`，確認所有項目都回到可見。

## 10. 待決定事項

| # | 問題 | 選項 | 建議 |
|---|---|---|---|
| 1 | 支援範圍 | 26 + 27 ／ 也支援 14–15 | **26 + 27** |
| 2 | Whisky 的授權 | 私有或 MIT（GPL 專案只學不抄）／ GPL-3.0（可以直接使用 Ice、Thaw、Pelmet 的程式碼，但 Whisky 整個必須以 GPL 開源） | 先決定是否公開；只自用的話兩者差別不大，要公開就要早點定 |
| 3 | 發佈方式 | 只自用 ／ 公開發佈 | 若在 chung223 下建 GitHub repo，名稱與 description 會出現在個人首頁；`raw/bartender/` 已在 `.gitignore` |
| 4 | 名稱 | 保留「Whisky」／ 改名 | macOS 上已有知名的開源 Wine 包裝工具也叫 Whisky（已停止維護）；只自用沒問題，要公開建議改名 |
| 5 | 27 的隱藏機制 | 私有 `MBAssessmentModeAssertion` allow-list ／ 只用公開 API 的有界分隔項目（效果較弱）／（2026-10-14 新增）改寫系統「Allow in the Menu Bar」清單（[Chest](../projects/chest.md)：沒有 allow-list 的副作用、可以不合成拖曳就排序；但格式沒有文件、要使用者在 Open panel 授權兩個系統檔案、會重啟 MenuBarAgent、crash 後保持隱藏） | **先不定案**：原本建議用私有 allow-list；新路線要等 M0 的 S6 結果再比較（[隱藏手法](../concepts/status-item-hiding.md) §5） |
| 6 | 預設排列模式 | On-Demand ／ Live | **On-Demand** |

## 11. 刻意延後的功能

Widgets（node graph）、天氣、剪貼簿、Notch bar、選單列著色與圓角、AppleScript、`.BartenderPreferences` 匯入。
這些在 Bartender 都是附加功能（[資源檔](../bartender/features-from-resources.md)「對 Whisky 的意義」）。核心穩定之後再評估。
