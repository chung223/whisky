來源：
- https://github.com/jordanbaird/Ice/releases （gh api repos/jordanbaird/Ice/releases）
- https://github.com/jordanbaird/Ice/commits （gh api，最近 commit）
- https://github.com/jordanbaird/Ice/issues?q=Tahoe （gh search issues）
標題：Ice release notes 與 Tahoe 相關 issue（作為平台變化的佐證）
發佈日期：0.11.0（2024-09-16）…0.11.12（2024-10-29）…0.11.13-dev.2（2025-09-16）
存取日期：2026-10-12

# 摘要筆記

- 最後正式版 **0.11.12（2024-10-29）**；之後只有 prerelease 0.11.13-dev.1（2025-06-20）、0.11.13-dev.2（2025-09-16）。main 分支最後 commit 2025-09-20（issue template）。
- 0.11.0（2024-09-16）：item spacing 調整（偶爾失敗需登出）；改善 macOS 15 相容；修正移動項目時與「修改 system events 的 App」衝突造成的 timeout。
- 0.11.3（2024-09-19）：修正 **macOS 15 Sequoia 的 screen capture 權限問題**。
- 0.11.9（2024-10-08）：Sequoia 上 Smart rehide 修正；重做選單列項目取得與快取。
- **0.11.13-dev.1（2025-06-20，Tahoe beta 1）**：「Apple made significant changes to the menu bar that require new solutions」；只恢復基本功能。
  - 項目移動可能變慢並間歇失敗 → `killall ControlCenter`、重開 Ice 或重開機。
  - 暫時顯示的項目重新隱藏時沒檢查選單是否仍開著、可能回不到正確位置。
  - 搜尋與 hover 顯示**錯誤的名稱與 App icon**（項目身分辨識出問題）。
  - **第三方項目的 spacing 需要登出**才生效。
- 0.11.13-dev.2（2025-09-16）：「fixes a majority of known issues introduced in macOS 26 Tahoe」；Liquid Glass；已知：Tahoe 透明選單列下 Ice 的 Menu Bar Appearance 會讓背後亮度不同 → 開 System Settings > Menu Bar 的 Show menu bar background。
- Tahoe 相關 issue（留言數高者）：#647 Tahoe crash、#716 layout 空白、#665 Ice Bar 看不見、#760 要求 Tahoe 穩定版、#710「Unable to display menu bar item」、#877「PROJECT DEAD」（2026-02）。
