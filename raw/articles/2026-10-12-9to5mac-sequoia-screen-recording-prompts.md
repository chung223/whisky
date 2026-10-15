來源：
- https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/ （Chance Miller）
- https://9to5mac.com/2024/10/07/macos-sequoia-screen-recording-popups/
- https://tidbits.com/2024/09/23/how-to-avoid-sequoias-repetitive-screen-recording-permissions-prompts/ （僅搜尋摘要）
標題：macOS Sequoia screen recording 重複授權提示（weekly → monthly → 15.1 減少）
發佈日期：2024-08-14；2024-10-07；2024-09-23
存取日期：2026-10-12

# 摘要筆記

- Sequoia 早期 beta：使用 screen recording 的 App 每週要重新確認，且每次重開機也問。
- **Sequoia 15.0 beta 6（2024-08）**：改為每月一次（「Allow For One Month」），不再每次重開機提示。
- 受影響：CleanShot X、Zoom、Slack 等；9to5Mac 點名 **Bartender** 也會受影響（為了其他目的使用 screen recording 的選單列工具）；ScreenCaptureKit App 也一樣。
- TidBITS：正式版 Sequoia 仍有大量提示，介紹 plist 繞過法（易碎）。
- **15.1 beta 6（2024-10-07）**：Apple notes「deprecated content capture technologies」有新的 user awareness policies，已接受風險的常用 App 對話框更少；細節未說明。
- 開發者無官方方式永久免除（Persistent Content Capture entitlement 只給 VNC 類）。
