來源（Apple Developer Documentation，以 https://developer.apple.com/tutorials/data/documentation/<path>.json 取得 availability）：
- https://developer.apple.com/documentation/appkit/nsstatusitem
- https://developer.apple.com/documentation/appkit/nsstatusitem/expandedinterfacedelegate
- https://developer.apple.com/documentation/appkit/nsstatusitem/expandedinterfacesession
- https://developer.apple.com/documentation/appkit/nsstatusitemexpandedinterfacedelegate
- https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible
- https://developer.apple.com/documentation/appkit/nsstatusbar
- https://developer.apple.com/documentation/swiftui/menubarextra
- https://developer.apple.com/documentation/swiftui/controlwidget
- https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager
- https://developer.apple.com/documentation/coregraphics/cgwindowlistcreateimage
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.persistent-content-capture
- https://bugs.webkit.org/show_bug.cgi?id=277564 （CGWindowListCreateImage 在 macOS 15 SDK obsoleted 的編譯錯誤，2024-08-02）
標題：Apple 選單列與螢幕擷取相關 API 文件（availability 摘錄）
發佈日期：文件持續更新；讀取當日版本
存取日期：2026-10-12

# 摘要筆記

## NSStatusItem / NSStatusBar
- NSStatusItem 主要成員：`button`、`menu`、`length`（`variableLength`、`squareLength`）、`isVisible`（10.12）、`behavior`（`.removalAllowed`、`.terminationOnRemoval`，10.12）、`autosaveName`。舊的 `image`、`title`、`view` 相關多已 deprecated（改用 `button`）。
- `isVisible` 文件：「returns true even if the status item is temporarily hidden due to insufficient space」→ App 自己無法從此屬性得知被擠掉或被 overflow 藏起。visibility 依 `autosaveName` 持久化；可 KVO 觀察使用者手動移除。
- **macOS 27.0 新增**：`NSStatusItem.expandedInterfaceDelegate`、`expandedInterfaceSession`、`NSStatusItemExpandedInterfaceDelegate`（`statusItem(_:didBegin:)`、`statusItemDidEndExpandedInterfaceSession(_:animated:)`）、`NSStatusItemExpandedInterfaceSession`（`cancel()`）。
  - 文件：有 `NSMenu` 的 status item 不會收到 callback，系統自動處理展開的 menu；否則由 delegate 在 didBegin 時顯示展開介面（例：status item 下方的 NSWindow），didEnd 時關閉。
  - 【推論】與 macOS 27 由系統統一管理選單列（含 overflow）有關：系統而非 App 決定何時「展開」一個項目。
- NSStatusBar：`system`、`statusItem(withLength:)`、`removeStatusItem(_:)`、`thickness`、`isVertical`；無列舉其他 App 項目的 API。
- NSStatusBarButton：`appearsDisabled`（10.10）。
- SwiftUI `MenuBarExtra`：macOS 13.0；`isInserted` binding；`.window` style。

## Control Center / Controls
- `ControlWidget`、`ControlWidgetToggle`：**macOS 26.0** 起可用（iOS 18）→ 第三方 App 可在 Control Center（與選單列）提供 controls。

## 螢幕擷取
- `CGWindowListCreateImage` / `CGWindowListCreateImageFromArray`：文件頁無 Swift platform 資訊；macOS 14 deprecated；**macOS 15 SDK 標為 obsoleted**——編譯錯誤「unavailable: obsoleted in macOS 15.0 - Please use ScreenCaptureKit instead」（WebKit bug 277564）。
- `CGWindowListCopyWindowInfo`：10.5，未 deprecated（仍可列舉視窗資訊）。
- `SCScreenshotManager`：macOS 14.0；`captureImage(in:)`：15.2；`captureScreenshot(rect:configuration:)`：**26.0**。
- `SCShareableContent.getCurrentProcessShareableContent`：14.4；`SCStreamConfiguration.includeChildWindows`：14.2；`SCContentSharingPicker`：14.0。
- `CGPreflightScreenCaptureAccess()`：10.15。
- **Persistent Content Capture entitlement**（macOS 14.4）：只給 VNC 類 App、需向 Apple 申請；可免除重複的 screen capture 確認。選單列管理工具不屬此類。
