---
title: Dozer
type: project
tags: [open-source, swift, appkit, mpl-2.0, menu-bar-hider, unmaintained]
sources:
  - https://github.com/Mortennn/Dozer
  - https://github.com/Mortennn/Dozer/blob/b0540378c01690ce566058b67bc7dc7e01efa4e6/Dozer/StatusIconClasses/HelperStatusIcon.swift
updated: 2026-10-12
---

# Dozer

## 概要

| 項目 | 內容 |
|---|---|
| Repo | [Mortennn/Dozer](https://github.com/Mortennn/Dozer) |
| 授權 | **MPL-2.0**（檔案層級 copyleft） |
| 語言 | Swift |
| Stars | 約 8.7k |
| 活躍度 | **停止維護**：最後 commit 2022-11-01（只修 README gif），最後 release v4.2.0（2020-07，prerelease）；102 個 open issue |
| 支援的 macOS | 10.13+（README） |
| macOS 26／27 | 未知／未維護；分隔線原理在 27 上必然失效（見 [status-item-hiding](../concepts/status-item-hiding.md)） |

Dozer 是 Hidden Bar 之前的經典作品：三個點狀圖示（normal left、normal right、remove），點一下就把左邊的 icon 推走。
**沒有 clone**（停止維護、機制與 [Hidden Bar](hidden-bar.md) 相同），只用 `gh api` 讀了 commit `b054037` 的兩個檔。

## 架構

`Dozer/DozerIcons.swift`（三個 icon 的集合，`hide()`／`show()`／`toggle()`，自動隱藏計時器）、
`Dozer/StatusIconClasses/{Normal,Helper,Remove}StatusIcon.swift`、`Dozer/ViewControllers/GeneralVC.swift`（設定）。

## 關鍵機制

- 隱藏：`HelperStatusIcon` 的 `StatusIconLength.hide = 10_000`（`HelperStatusIcon.swift:12`），`hide()` 把 `statusIcon.length` 設為
  10,000，`show()` 設回顯示寬度（`:39-45`）；狀態直接由 `length` 判斷（`:85-89`）。
- 「remove」icon 是第三條分隔線，等同 always-hidden 區（`DozerIcons.swift:134-165`）。
- 啟動時隱藏、延遲自動隱藏、全部隱藏模式（`DozerIcons.swift:18-90`）。
- 不列舉、不移動、不擷取別人的 item。

## 權限

不需要任何權限。

## 已知問題

停止維護，新版 macOS 的問題無人處理。

## 對 Whisky 的參考價值

歷史參考：證明「10,000 pt 分隔線」這招至少從 2018 年就被使用，直到 macOS 26 都有效。沒有其他值得借用的技術。

## 授權注意

MPL-2.0：若直接使用其檔案，該檔案修改後須以 MPL 開源，但不會傳染整個專案。實務上沒有必要引用。
