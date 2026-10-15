---
title: 自己用 Swift 重寫的可行性
type: synthesis
tags: [whisky, feasibility, risk, scope]
sources:
  - wiki/synthesis/whisky-architecture.md
  - wiki/synthesis/roadmap.md
  - wiki/concepts/macos-menu-bar-platform.md
  - wiki/concepts/menubar-agent-allow-list.md
  - wiki/comparisons/open-source-menu-bar-managers.md
  - raw/github/repos
updated: 2026-10-14
---

# 自己用 Swift 重寫的可行性

結論：**可行**，但目標要設成「Bartender 的核心功能」，不是功能完全對等。
難點不在 Swift 或 AppKit，而在 macOS 每個大版本都會改掉選單列的底層行為。

## 依難度分層

| 層級 | 內容 | 為什麼 | 對應里程碑 |
|---|---|---|---|
| 容易 | 隱藏／顯示（自有分隔項目撐長）、自動收回、熱鍵、登入啟動、設定 | 只用公開 API、不需權限；Dozer、Hidden Bar 早期版本就是這樣做 | [M1](roadmap.md) |
| 中等 | AX 列舉（XPC + timeout）、項目身分比對、Whisky Bar、點擊轉送、搜尋、Presets／Triggers | 公開 API 為主，工作量大但沒有未知數 | M2、M4、M6 |
| 難 | 自動排列（移動別人的項目） | 26 要合成 ⌘ 拖曳加事件欄位 `0x33`（私有、易壞），而且會動到游標；這正是 Bartender 6 在 Tahoe 上最大的抱怨 | M3 |
| 高風險 | macOS 27 的隱藏 | 唯一真正有效的方法是私有 `MBAssessmentModeAssertion` allow-list：以 bundle 為單位、只認 /Applications、會連帶拿掉 Now Playing 等系統膠囊、擋住通知中心、新項目會被擱置，而且 Apple 隨時可能關掉（[allow-list](../concepts/menubar-agent-allow-list.md) 限制 1–11） | M5 |
| 【未知】 | 27 上不動游標的移動 | Bartender 7、Thaw 3 做到了，但都閉源；Pelmet 實測寫位置表無效 | — |

## 規模參考

開源專案的 Swift 行數（2026-10-14 用 `wc -l` 計算 `raw/github/repos/`，不含 Tests）：

| 專案 | 行數 | 範圍 |
|---|---|---|
| MenuBarHider | 1,792 | 只有 27 allow-list 隱藏 |
| MenubarHide | 1,975 | 隱藏 + panel |
| Hidden Bar | 3,363 | 隱藏 + 27 allow-list + Notch Overflow |
| Ice | 18,156 | 完整功能（26 以前） |
| Frost | 20,923 | 26/27 雙後端 + bar + 排列 |
| Pelmet | 27,175 | 27 完整功能 |
| SaneBar | 40,750 | 功能最廣 |
| Thaw | 137,310 | 含 Ice 全部歷史程式碼與大量功能 |

【推論】M1 的規模接近 MenuBarHider／MenubarHide（約 2,000 行）；做到 M4 大約是 Ice、Frost 的量級（約 2 萬行）。

## 有利條件

- 工具鏈已就緒：Xcode 27.0（27A266a）、XcodeGen、macOS 26.7 開發機（2026-10-14 確認）。
- 知識庫已涵蓋 Bartender 的機制、9 個開源專案與 macOS 14–27 的平台變化；MIT 參考（Frost、Hidden Bar、MenuBarHider）26、27 兩版都有。
- 同類工具多半是個人專案，例如 Ice、Pelmet（見各專案頁）。

## 主要風險

1. **平台變動**：Sonoma 讓 Bartender 4 失效，Tahoe 讓 Ice 多處壞掉，27 beta 1 讓所有工具一起失效（[比較](../comparisons/open-source-menu-bar-managers.md)）。每年 WWDC 後都要預留修補時間。
2. **私有 API**：27 的隱藏完全依賴私有 allow-list，沒有公開 API 能達到同樣效果。
3. **27 測試環境**：開發機是 26.7，要另外架 27 虛擬機。

## 建議

先做 [路線圖](roadmap.md) 的 M0 + M1：在 26.7 上一兩次工作時段就能做出每天可用的隱藏／顯示工具，同時用 spike 驗證 S1–S3。
之後依實際使用需求決定要不要往 M3（排列）與 M5（27 後端）走。
