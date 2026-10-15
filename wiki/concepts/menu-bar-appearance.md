---
title: 選單列外觀、間距與 app menu 隱藏
type: concept
tags: [appearance, tint, overlay, spacing, nsstatusitemspacing]
sources:
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/junior-rj__menubar-hide
updated: 2026-10-12
---

# 選單列外觀、間距與 app menu 隱藏

## 外觀（tint、shape、border、shadow）

macOS 沒有讓 app 改選單列外觀的 API。做法都是**在選單列上方疊一個不吃滑鼠的 window**，自己畫顏色或形狀。

| 專案 | window | 內容 | file:line |
|---|---|---|---|
| [Ice](../projects/ice.md) | `NSPanel`，level `.statusBar`，`ignoresMouseEvents = true`，`[.fullScreenNone, .ignoresCycle, .moveToActiveSpace]` | tint（純色／漸層）、shadow、border、圓角／分段形狀；形狀模式要先擷取桌布 window 在選單列範圍的影像墊底（需 Screen Recording）；切 Space 時更新 | `Ice/MenuBar/Appearance/MenuBarOverlayPanel.swift:91-96`, `:106`, `:296-303` |
| [Thaw](../projects/thaw.md) | 同 Ice（fork） | 再加：從桌布取一或兩個主色的 adaptive tint、per-Space 覆寫、notch-aware 形狀、Thaw Bar 獨立外觀 | README「Menu bar appearance」 |
| [SaneBar](../projects/sanebar.md) | click-through 無邊框 `NSPanel`，level `.statusBar − 1` 或 `.statusBar` | macOS 26 用 `.glassEffect(Glass.regular)`（Liquid Glass）；尊重「減少透明度」；全螢幕與 Mission Control 時隱藏 | `MenuBarAppearanceService.swift:516-592`；`MenuBarOverlayView.swift:78-98`；`MenuBarAppearanceSuppressionPolicy.swift:30-111` |

注意：

- 選單列本身半透明，overlay 要畫在選單列「下面」的視覺效果，只能靠擷取桌布模擬。
- 淺色／深色模式、per-display 都要分開設定（Ice「dynamic appearance」）。
- SaneBar 的 #158：macOS 27 上 overlay 蓋住了 Mission Control——overlay 要在 Mission Control／全螢幕時讓位。

## Item 間距

全域 defaults `NSStatusItemSpacing` 與 `NSStatusItemSelectionPadding`（等同 `defaults -currentHost write -globalDomain …`）。
每個 app 只在啟動時讀，所以要嘛重啟所有有 status item 的 app（Ice 會逐一 terminate 再 relaunch，`MenuBarItemSpacingManager.swift:79-126`），
要嘛請使用者登出（MenubarHide `MenuBarSpacing.swift:8-54`；SaneBar `MenuBarSpacingService.swift:24-37`）。預設值 spacing 16（Ice `:20`）。
Thaw 標為 beta，會讓 item 被裁切或藏起（`FREQUENT_ISSUES.md:175`）。

## 隱藏 app menu

可見 item 太多時會和前景 app 的選單（File、Edit…）重疊。Ice／Thaw 的「Hide application menus」：用 AX 取得 app menu 的範圍
（`AXUIElementCopyElementAtPosition` 找 role 為 menuBar 的元素再合併子項 frame），重疊時把自己 activate，前景 app 的 menu 就消失
（Ice `MenuBarManager.swift:160-215`, `:292-320`）；SaneBar 同法（`MenuBarVisibilityWorkflow.swift:303-336`）。

## 對 Whisky 的建議

外觀是 Bartender 6 也有的功能（見 `wiki/bartender/`），但不是核心；可以晚做。做的時候：overlay panel + 不需權限的純色／漸層 tint 先做，
需要 Screen Recording 的形狀／adaptive tint 後做。
