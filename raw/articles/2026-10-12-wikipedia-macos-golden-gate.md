來源：
- https://en.wikipedia.org/wiki/MacOS_Golden_Gate
- https://www.macrumors.com/2026/06/11/macos-27-golden-gate-menu-items/ （MacRumors, Tim Hardwick, 2026-06-11）
- https://mjtsai.com/blog/2026/06/18/appkit-in-macos-27/ （Michael Tsai, 2026-06-18）
標題：macOS Golden Gate（Wikipedia）＋ macOS 27 選單圖示變更報導
發佈日期：Wikipedia 持續更新；MacRumors 2026-06-11；mjtsai 2026-06-18
存取日期：2026-10-12

# 摘要筆記

## 版本時間線（Wikipedia）
- WWDC **2026-06-08** 發表 macOS 27「Golden Gate」，同日第一個 developer beta。
- beta 3：2026-07-06；beta 6：2026-08-17。
- **正式版 2026-09-14**（27.0，build 26A428）；**27.0.1：2026-09-28**（26A434）；27.2 beta 3：2026-10-05（26B5101f）。
- **只支援 Apple silicon**（Intel 被淘汰；Rosetta 2 仍可跑 Intel App）。→ Whisky 若支援 macOS 14–26 仍需 Universal；27 起只需 arm64。
- 選單列：選單項目預設不再顯示 icon（反轉 Tahoe 的設計）；27.0 beta 3 對 Siri 等候名單使用者移除選單列 Spotlight；天氣項目有動畫。
- 其他：Liquid Glass 調整、Control Center 收起動畫一致、screen recording 支援系統音訊。
- Wikipedia 未提單一視窗選單列或 overflow。

## MacRumors（2026-06-11）
- 移除 Tahoe 加在選單項目旁的大量小圖示；HIG 改為「sparingly and with purpose」。
- 未談 overflow 或第三方選單列管理工具。

## mjtsai AppKit in macOS 27（2026-06-18）
- 引用 Apple notes：NSMenu 預設隱藏 symbol images、新 `preferredImageVisibility`。未提 NSStatusItem。
