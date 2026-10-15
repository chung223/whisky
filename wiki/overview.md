---
title: Whisky 知識庫概覽
type: overview
tags: [overview, whisky, bartender, menu-bar]
sources:
  - wiki/projects/long-tail.md
  - wiki/comparisons/feature-ideas.md
  - wiki/index.md
updated: 2026-10-14
---

# Whisky 知識庫概覽

目標：用 Swift 從零重寫一個 Bartender 類的 macOS 選單列管理工具（Whisky）。
這份知識庫整理了三種資料：Bartender 6.6.2 的逆向結果、9 個開源同類專案的原始碼，以及 macOS 14–27 的平台變化。
全部頁面見 [index](index.md)，下一步見 [架構提案](synthesis/whisky-architecture.md) 與 [路線圖](synthesis/roadmap.md)。

## 目前知道的

### 1. Bartender 怎麼做（[架構](bartender/architecture.md)、[機制](bartender/mechanisms.md)）

- **隱藏**：用三個自有的分隔項目（HIS、RHS、EItem）切出三區；隱藏時把分隔項目的 `length` 設成 10000，把左邊的項目推出螢幕。
- **列舉**：用私有的 `CGSGetProcessMenuBarWindowList` 取得選單列視窗，以 layer 25 過濾。項目 ID 是 `<bundleID>-<視窗標題>`。
- **移動**：合成 ⌘ 拖曳的 CGEvent，事件欄位 51 填目標視窗 ID。移動期間用 active event tap 擋住使用者輸入，並隱藏、復原游標。
- **Bartender Bar**：用 `CGWindowListCreateImage` 截圖，點擊時先把真的項目移進畫面再合成點擊。
- **macOS 26 專屬**：視窗看不出真正的擁有者，所以用 XPC 服務做 AX 查詢、對位置比對，再加上圖示雜湊建立索引。

### 2. 平台現況（[平台變化](concepts/macos-menu-bar-platform.md)）

- **macOS 26**：所有項目視窗都歸 Control Center 所有，只能靠 AX 辨識項目。分隔項目最長被夾到約 5,016 pt。
- **macOS 27（2026-09-14 發佈）**：整條選單列改由 MenuBarAgent 用單一視窗繪製，撐長分隔項目的手法失效。
  真正能隱藏的方法只剩私有的 `MBAssessmentModeAssertion` allow-list（[allow-list](concepts/menubar-agent-allow-list.md)），而且以 App 為單位。

### 3. 開源參考（[比較](comparisons/open-source-menu-bar-managers.md)）

- **可以參考的 MIT 專案**：Frost（26/27 雙後端）、Hidden Bar、MenuBarHider、SaneBar。
- **GPL 專案，只學機制**：Ice、Thaw、Pelmet、SketchyBar。Pelmet 對 27 的實測最完整。
- **其他 58 個專案**（2026-10-14 只讀 README）：27 發佈後冒出大批小專案，多數是 AI 一次產出，但帶來幾條新路線：
  改系統「Allow in the Menu Bar」開關、寬度低於螢幕一半讓系統收進 «、menu mirroring（不顯示就能用被藏項目的選單）。
  見 [其他同類專案](projects/long-tail.md) 與 [功能點子庫](comparisons/feature-ideas.md)。

## 還不知道的

- 27 上怎麼移動項目才能不碰游標（Bartender 7、Thaw 3 已做到，但都閉源；Pelmet 實測寫入位置表無效）。
- 27 上逐 App 的 `AXExtrasMenuBar` frame 是否可信。
- Apple 會不會在 27.x 封鎖 `MBAssessmentModeAssertion`。
- 改寫系統「Allow in the Menu Bar」清單：檔案位置與格式已從 [Chest](projects/chest.md) 原始碼得知，但授權流程、和 MenuBarAgent 的 race、crash 後的還原仍要實測（S6）。
- 27 上同一個程序 `invalidate()` 之後通知中心是否仍打不開（[MenuTidy](projects/menutidy.md) 的說法，和 Pelmet 的做法矛盾，S4）。
- 被藏的項目能不能不顯示就用 menu mirroring 打開；26 與 27 上對 item 本身 `AXPress` 的結果不同（S8）。
- 27 上撐寬還推不推得動、26 會不會丟掉超寬項目、合成 ⌘ 拖曳會不會被交給 Mission Control：各專案的 README 互相矛盾（S1、S7）。
- Bartender 的 `.BartenderPreferences` 格式；Ghidra 對主程式的分析逾時，部分位址還沒看到偽代碼。

這些都列在 [路線圖](synthesis/roadmap.md) M0 的實驗中。
