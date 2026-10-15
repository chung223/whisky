---
title: 可重用的 Swift 函式庫
type: project
tags: [open-source, swift, library, mit, dependencies]
sources:
  - https://github.com/sindresorhus/KeyboardShortcuts
  - https://github.com/orchetect/MenuBarExtraAccess
  - https://github.com/sparkle-project/Sparkle
  - https://github.com/sindresorhus/LaunchAtLogin-Modern
  - https://github.com/tmandry/AXSwift
  - https://github.com/soffes/HotKey
  - raw/github/repos/sane-apps__SaneBar/project.yml
  - raw/github/repos/jordanbaird__Ice/Ice.xcodeproj/project.pbxproj
updated: 2026-10-12
---

# 可重用的 Swift 函式庫

## 概要

開源選單列管理工具共用的第三方函式庫。這些都**沒有 clone**（不是選單列管理工具本身），資料來自 `gh api`（2026-10-12）
與各專案的 `Package.swift`／`Package.resolved`。對 Whisky 而言重點是：**全部是 MIT 或相容授權**，可以直接當 SPM 依賴使用，
不會污染授權。

## 函式庫一覽

| 函式庫 | 授權 | Stars | 最後 push | 最低 macOS | 用途 | 誰在用 |
|---|---|---|---|---|---|---|
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | MIT | 2.7k | 2026-09-11 | 10.15 | 使用者可自訂的全域 hotkey + SwiftUI／AppKit 錄製元件 | [SaneBar](sanebar.md)；Bartender 本身也內含（見 `wiki/bartender/`） |
| [soffes/HotKey](https://github.com/soffes/HotKey) | MIT | 1.1k | 2024-12-29 | — | 輕量 Carbon hotkey 包裝（無錄製 UI） | [Hidden Bar](hidden-bar.md) |
| [orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) | MIT | 222 | 2026-08-05 | 10.15（`MenuBarExtra` 本身需 13） | 用 Binding 控制 SwiftUI `MenuBarExtra` 顯示／隱藏、取得底層 `NSStatusItem` | （本次研究的專案都直接用 `NSStatusItem`） |
| [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle) | MIT 風格（GitHub 顯示 NOASSERTION，LICENSE 含多個著作權人與附帶元件授權） | 9.8k | 2026-10-11（2.10.0 於 2026-09-13） | — | App 外自動更新（EdDSA 簽章 appcast） | [Ice](ice.md)、[Thaw](thaw.md)、[SaneBar](sanebar.md)、[Frost](frost.md)、IceMelt |
| [sindresorhus/LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | MIT | 582 | 2024-01-11 | 13 | `SMAppService.mainApp` 的 SwiftUI 包裝 | [Ice](ice.md)、[Thaw](thaw.md)；其他人直接呼叫 `SMAppService` |
| [tmandry/AXSwift](https://github.com/tmandry/AXSwift) | MIT | 418 | 2023-07-25 | — | Accessibility C API 的 Swift 包裝（`UIElement`、`Application`） | [Ice](ice.md)；[Thaw](thaw.md) 改用自家 fork `thaw-app/AXSwift6`（MIT，Swift 6） |
| [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults) | MIT | 2.5k | 2026-06-23 | — | 型別安全的 UserDefaults | （候選） |
| [sindresorhus/Settings](https://github.com/sindresorhus/Settings) | MIT | 1.6k | 2025-11-10 | — | 設定視窗 | （候選） |
| [buh/CompactSlider](https://github.com/buh/CompactSlider) | MIT | 564 | 2026-07-27 | — | SwiftUI slider | [Ice](ice.md)、[Thaw](thaw.md) |
| [ukushu/Ifrit](https://github.com/ukushu/Ifrit) | MIT | 99 | 2026-03-20 | — | 模糊搜尋（item search） | [Ice](ice.md)、[Thaw](thaw.md) |

## 選用建議（給 Whisky）

- **Hotkey**：用 KeyboardShortcuts。Bartender 6 自己就內含它，功能（錄製 UI、衝突偵測、UserDefaults 儲存）完整。Ice／Thaw／
  MenubarHide 自己寫 Carbon `RegisterEventHotKey`，沒有必要重造。
- **自動更新**：Sparkle 2.x，幾乎是 Developer ID 發布的唯一標準選擇；注意 Thaw 與 Frost 都 pin 精確版本並驗證 EdDSA。
- **Login item**：`SMAppService.mainApp` 只有幾行，可以不用 LaunchAtLogin-Modern；若要現成的 SwiftUI Toggle 再引入。
- **Accessibility 包裝**：AXSwift 已兩年多沒更新，Swift 6 strict concurrency 下要自己包或用 AXSwift6。考量到 AX 呼叫需要
  timeout、背景執行、負快取（見 [Thaw](thaw.md) 的 `SourcePIDCache`），建議 Whisky 自己寫一層薄包裝。
- **MenuBarExtraAccess**：只在 Whisky 的主圖示想用 SwiftUI `MenuBarExtra` 時才需要；分隔線與 spacer 一定要用 AppKit
  `NSStatusItem`（要控制 `length`、`autosaveName`、button window），所以不建議主架構建立在 `MenuBarExtra` 上。

## 授權注意

上表全部為 MIT（Sparkle 為 MIT 風格的寬鬆授權），可作為依賴；發布時在 About／Acknowledgements 附上授權文字。
