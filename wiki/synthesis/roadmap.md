---
title: Whisky 開發路線圖
type: synthesis
tags: [whisky, roadmap, milestones, spikes]
sources:
  - wiki/projects/long-tail.md
  - wiki/comparisons/feature-ideas.md
  - wiki/synthesis/whisky-architecture.md
  - wiki/concepts/macos-menu-bar-platform.md
  - wiki/concepts/menubar-agent-allow-list.md
  - wiki/comparisons/open-source-menu-bar-managers.md
updated: 2026-10-15
---

# Whisky 開發路線圖

依據 [架構提案](whisky-architecture.md)。

**2026-10-14 調整**：使用者的主力機是有瀏海的 14 吋 MacBook Pro，31 個選單列項目只畫出 11 個（[實測](../concepts/platform-verification.md)），在這台上 M1 的「點一下顯示隱藏區」沒有用（顯示出來還是被瀏海擋住）。所以先做 **v0.1：Whisky Bar 加 menu mirroring**（原 M4 的一部分，不用私有 API、不移動項目），再做移動項目（M3）與分隔項目隱藏（M1）。macOS 27 的工作延後。

**進度（2026-10-15）**：v0.1 Whisky Bar + menu mirroring、v0.2 單一項目移動（S3 驗證）、v0.3 排列視窗（拖曳編輯、從 Bartender 匯入、逐步驗證的套用）都已裝在使用者的 Mac 上。v0.5 分隔項目（固定 10000 pt，用假圖示自我測試通過；預設關閉，由使用者打開）與倒酒動畫圖示。v0.6 沒有選單的被藏項目「暫時放回再點」、⌃⌥⌘W、Whisky Bar 搜尋。v0.7 設定視窗、快捷鍵自訂、Apple 系統項目用 SF Symbols、記住版面並在跑掉時提醒（使用者按了才排回去，[觀察](../concepts/platform-verification.md)）。v0.8 Whisky Bar 從瀏海倒出來（滑過提示數量、點了展開；沒有瀏海時用酒杯下方的玻璃面板）、排列視窗改成選單列預覽、介面全面整理；處理選單列隱藏與溢出的選單列。之後：Whisky Bar「常用」、單一圖示的快捷鍵、酒杯住在瀏海裡（搭配分隔項目；自我測試通過）、藏起來的圖示有變化時從瀏海提醒。已做：情境版面（外接螢幕、電池、手動）、開場教學、重新啟動直接放對。還沒做：被推到螢幕外的項目的真實圖示（需要暫時展開再擷取）、Wi-Fi 與專注模式的觸發、暫時放回再點的實測樣本還少（iStat 要一般點擊，已記住）。開發機是 macOS 26.7，所以先做 26 後端，同時在 M0 用虛擬機驗證 27，確保抽象層不會只適合 26。
每個里程碑結束時都要能實際使用，並把新學到的平台行為寫回 wiki。

## M0：骨架與實驗

- XcodeGen 專案：App、XPC service、`Packages/*` 都先建成空殼，確認可以簽章、建置、執行。
- 只動自己項目的 spike 小程式，在 26.7 上驗證：
  - S1：分隔項目撐長的上限（Frost 量到約 5,016 pt），以及 length 0 時殘留的寬度。
  - S2：`CGWindowListCopyWindowInfo` 回報的擁有者是否都是 Control Center；AX `AXExtrasMenuBar` 的 frame 能否以 midX 對上視窗。
  - S3：`0x33` window-ID 路由的 ⌘-drag 在 26.7 是否仍有效（只移動自己的兩個項目）。
- 架好 macOS 27 虛擬機（UTM 或 Tart），驗證：
  - S4：`MBAssessmentModeAssertion` 能否載入，以及隱藏與恢復的行為。（2026-10-14 補）同一個程序 `invalidate()` 後通知中心是否仍打不開；holder 子程序模式能否持有 assertion、兩個 assertion 重疊時的結果；bundle 清單少了 `com.apple.MenuBarAgent` 時時鐘是否點不動（[MenuTidy](../projects/menutidy.md)）。
  - S5：MenuBarAgent 的 AX tree 和逐 App 的 `AXExtrasMenuBar` frame 是否一致（Pelmet 與 Frost 的說法矛盾）。
  - S6（2026-10-14 加）：系統「Allow in the Menu Bar」清單能否當隱藏機制：檔案位置與格式、寫入後多久生效、crash 後如何還原；Open panel 的檔案授權撐不撐得過重開機與更新；「關著時寫位置再打開」的落點；和 allow-list 能否混用（[Chest](../projects/chest.md)、Tuck 的路線，[隱藏手法](../concepts/status-item-hiding.md) §5.1）。
  - S7（2026-10-14 加）：有界寬度的斷崖（螢幕寬度一半）與 « 行為；合成 ⌘ 拖曳會不會被交給 Mission Control（[隱藏手法](../concepts/status-item-hiding.md) §5.2、§5.4；[allow-list](../concepts/menubar-agent-allow-list.md) 第 20 點）。
  - S8（2026-10-14 加，26.7 與 27 都要做）：menu mirroring 的前提。對三種狀態的 item（瀏海溢出、被分隔線推到螢幕外、27 被藏）記錄 `AXUIElementCopyActionNames`、對 item `AXPress` 的回傳碼、`AXMenu` children 能否讀取、對 `AXMenuItem` `AXPress` 是否生效（[點擊隱藏項目](../concepts/menu-bar-item-activation.md)「待實測」）。
- S1 也順便確認 26.7 上超寬項目是被夾到約 5,016 pt，還是被丟掉並出現 «（Champ-KTP/Tuck 的說法與其他專案矛盾）。
- 結果寫成 `wiki/concepts/platform-verification.md`。

**完成條件**：空殼 App 可以啟動；S1–S8 都有結論，或明確標成【未知】。

## M1：隱藏／顯示 MVP（macOS 26）

- 三個自有項目：Whisky 圖示、Hidden 分隔、Always Hidden 分隔。用 `autosaveName` 持久化位置。
- 點圖示顯示或隱藏；自動收回；使用者自己用 ⌘ 拖曳安排項目（和最早期的 Dozer、Hidden Bar 一樣）。
- 不需要任何權限，也不用私有 API。
- fail-open：結束時分隔項目消失，所有項目自然回到可見。

**完成條件**：可以每天使用；重開機後版面還在；`kill -9` 後所有項目可見。

## M2：列舉與版面編輯器

- `WhiskyAXService`：每次查詢都有 timeout、負快取，並記錄回應慢的 App。
- `ItemIdentity` 與快照比對；新項目規則。
- 設定視窗（SwiftUI）：三區清單，顯示 App icon，可拖曳調整區段（此時只改模型，還不搬動實際項目）。
- Accessibility 權限 onboarding。

**完成條件**：編輯器正確列出所有第三方與系統項目；App 重開、重開機後身分仍正確。

## M3：套用排列

- `ArrangePlan`：算出最少步數的移動。
- `WhiskyEvents`：⌘-drag mover（26 用 `0x33` 路由，失敗退回真實拖曳）、`InputShield`、游標隱藏與還原。
- 每一步都驗證；失敗有上限，超過就標成無法移動；遇到 Zoom、全螢幕、切換 Space 時中止。

**完成條件**：在編輯器按「套用」後，實際選單列和模型一致；不可移動的項目在 UI 上有標示，不會無限重試。

## M4：Whisky Bar、搜尋、熱鍵

- Whisky Bar（NSPanel）：顯示 Hidden 與 Always Hidden 的項目，預設用 App icon。
- 點擊轉送：優先用 menu mirroring（AX 讀出選單、在 Whisky 的位置重建再轉送），只接受真實點擊的 App 才暫時顯示再點擊（[點擊隱藏項目](../concepts/menu-bar-item-activation.md)）。
- Quick Search：模糊搜尋，可用鍵盤操作。
- KeyboardShortcuts：切換顯示、搜尋、針對單一項目的「顯示並點擊」。
- 選用：Screen Recording 開啟時用 `SCScreenshotManager` 擷取項目真實圖片。

**完成條件**：不用滑鼠就能用熱鍵加搜尋點開任何隱藏項目。

## M5：macOS 27 後端

- `GoldenGateBackend`：
  - allow-list engine：先啟用新的再作廢舊的；不需變更時不做任何事；偵測到被系統拆掉就重送。assertion 放在 holder 子程序，新 holder 回報成功後才殺舊的（依 S4 結果）。
  - 系統項目編號 0–8：Clock、Control Center 只能藏、不能移。
  - adoption window：處理新項目被擱置的問題。
  - 點時鐘開通知中心要轉送。
  - 降級路線：有界分隔項目，寬度低於螢幕一半（例如 Blinds 的 44%），讓系統收進 «（[隱藏手法](../concepts/status-item-hiding.md) §5.2）。
- UI 依 `visibilityGranularity == .bundle` 把項目按 App 分組。
- 在虛擬機或第二台 Mac 上完成 M1–M4 的驗收。

**完成條件**：在 27 上 M1–M4 的驗收條件都通過；不可用的功能在 UI 上清楚說明原因。

## M6：Presets、Triggers、自動化

- Presets：例如工作與家裡兩種版面。
- Triggers：Wi-Fi、電池、App 啟動、外接螢幕、Focus（App Intents Focus Filter）。
- URL scheme 與 App Intents。
- 選單列間距：寫入 `NSStatusItemSpacing`，提示使用者登出；27 上可以重啟 MenuBarAgent 讓系統項目立即套用。

## M7：發佈打磨

- Sparkle 2（EdDSA）、Developer ID 簽章與 notarization。
- 檢查安裝位置（必須在 /Applications）、onboarding 文案、匯出與匯入、log viewer。

## 之後

選單列著色與圓角、Notch bar、Widgets、剪貼簿。依使用需求再決定。
