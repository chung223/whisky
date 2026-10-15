來源（Apple Developer 官方 release notes；以 docs JSON 端點取得）：
- https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes （macOS 27 Golden Gate Release Notes）
- https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes （macOS Tahoe 26）
- https://developer.apple.com/documentation/macos-release-notes/macos-15-release-notes （macOS Sequoia 15）
- https://developer.apple.com/documentation/macos-release-notes/macos-15_1-release-notes （macOS Sequoia 15.1）
- https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14 （AppKit Release Notes for macOS Sonoma 14）
標題：Apple macOS Release Notes（14、15、15.1、26、27）中與選單列管理工具相關的條目
發佈日期：各版 beta 起陸續更新；本次讀取 2026-10-12 的版本
存取日期：2026-10-12

# 摘要筆記

## macOS 14 Sonoma（AppKit release notes）
- App activation 改為「user intent」驅動：`activate(ignoringOtherApps:)` deprecated；新 `NSApplication.activate()`、`yield(to:)` cooperative activation；activation 是請求、不保證成功。
- 以 macOS 14 SDK 連結時，從非主執行緒改動 main menu 會 assert。
- 26/27 release notes 未提 NSStatusItem 行為變更（14 的 notes 也沒有）。

## macOS 15 Sequoia
- ScreenCaptureKit Deprecations：使用 `CGDisplayStream`、`CGWindowListCreateImage` 等已 deprecated 的擷取 API，可能觸發系統警示（App 可能收集使用者詳細資訊）；開發者需改用 `ScreenCaptureKit` 與 `SCContentSharingPicker`。（120910350）
- SwiftUI：menu bar extras 的 window style 下 `scenePhase`、`onAppear/onDisappear` 行為更可預期。
## macOS 15.1
- MDM 新 key `forceBypassScreenCaptureAlert`：受管裝置可關閉 content capture 通知。（131327961）
- 使用 deprecated content capture 技術的 App 有「enhanced user awareness policies」；已接受風險且常用的 App 會看到較少對話框。（133431080）

## macOS 26 Tahoe
- 開發者 release notes **沒有** NSStatusItem / menu bar 相關條目（使用者層級的 Menu Bar 設定見 Apple Support）。

## macOS 27 Golden Gate
- AppKit：27.0 起選單列與 context menu 顯示較少的 menu item 圖片；`NSMenu` 預設隱藏 symbol images；適用於以 macOS 26.0 以上連結的 App；新 `NSMenuItem.preferredImageVisibility`。（170477566）SwiftUI / UIKit 有對應條目。
- **Automatic Assessment Configuration**：macOS 27 提供更彈性的 assessment 設定，可控制 Dock、**Menu Bar**、accessibility 設定、系統預檢與 App 啟動限制。（158132137）
- TCC Deprecations：「Apps can no longer access the local TCC database directly.」（90775556）
- 其他：存取其他開發團隊 App 的 data container 預設拒絕。
- **注意：developer release notes 沒有提到「選單列改為單一視窗」、MenuBarAgent、status item 白名單、overflow。** 這些只見於 Apple 企業版 release notes（overflow）與社群觀察。
