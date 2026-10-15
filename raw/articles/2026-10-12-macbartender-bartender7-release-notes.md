來源：
- https://www.macbartender.com/Bartender7/release_notes/ （7.0.0–7.0.5）
- https://www.macbartender.com/goldengate/releases/ （Golden Gate Preview One–Three、Bartender Seven Beta One–Four）
標題：Bartender 7 Release Notes ＋ Bartender for Golden Gate preview release notes（官方）
發佈日期：頁面無逐版日期；Preview One 約在 macOS 27 beta 期間（2026-06 起），7.0.0 約 2026-09-14
存取日期：2026-10-12

# 摘要筆記（重點為 macOS 27 平台行為的第一手描述）

## Golden Gate Preview One（第一個 macOS 27 alpha）
- 只能在 macOS 27 執行；免費（Pro 除外）。
- 「Bartender no longer touches your mouse to move items」；只有從 Bartender Bar 啟用項目時才動滑鼠。
- 可在**完全沒有 screen recording** 下運作；Bartender Bar 先顯示 App icon（例：ChatGPT 圖示）而非真實項目。
- 「more unrecoverable changes from Apple」→ 暫時無法維持舊 profiles。
- indexing 比舊版 macOS 快很多；單一項目移動更快。
- 停用功能：Profiles（簡化版）、Triggers、Widgets、**Live Mode**（只剩 on-demand layout）。
- Known issues：瀏海機種不穩；新的系統 overflow 有怪行為；**部分系統項目（尤其 Control Center widgets）只能移不能藏**；**同一 App 的多個項目，藏一個就全部藏、顯示亦然**；Shortcuts 項目被標為「Control Center」且不能移；移動足夠多次後選單列會停止回應（提供「Restart Menu Bar」按鈕，預期是 macOS beta bug）。

## Preview Three
- 「Bartender cannot show/hide any item you've hidden in Control Center」（指 System Settings 的 Allow in the Menu Bar）。
- 熱鍵部分恢復；Bartender Bar 可在滑鼠位置顯示；layout 的 "gravity" 右到左。

## Beta One（Bartender Seven）
- 支援 macOS 27 大部分 overflow 行為；可啟用自動處理（暫時閃爍）。
- Command Bar、Triggers 改名 **Automations**（URL 動作、Focus filter）、**App Intents**（取得項目、show/click、切 profile、toggle bar）、Focus Mode 熱鍵、**可隱藏系統項目（clock、Control Center）**、presets 依螢幕組合同步。
- 記憶體目標 < 100 MB。
- iStat Menus 等 App 不相容、自動隱藏；歡迎開發者合作做「Golden Gate updates」。

## Beta Two
- Triggers 回歸（Automations 頁）；**Spacers 回歸**（寬度可調、可顯示文字/emoji/SF Symbol、per-profile）。
- Hidden 列顯示真實項目圖片（Show Bar Item Images）＋「Recapture Items」；Show App Icons 選項。
- **Settings Imports**：實驗性從 Bartender 6 匯入 profiles（非破壞性）。
- 持續變動標籤的項目（OneDrive、Granola、CPU 讀數）不再重複/漂移。
- **同一 App 的項目只能在同一區（Shown/Hidden/Always Hidden）**；舊的分裂 layout 會自動「heal」。
- iStat Menus、Setapp 會在 Bartender 隱藏其他項目時把自己藏起來 → 暫時看不到；可由 App 端修正。

## Beta Three
- **Menu bar spacing 回歸**（Default、Small、Tiny、No Spacing），需**登出再登入**才會被每個 App 套用。
- 新選項：顯示隱藏項目時暫時藏起顯示中項目（clock 與 Control Center 保持可見）。
- 外觀：Material、Glass（Light/Dark/Match System/Match Menu Bar）。
- Top Shelf 新背景 Glass、Siri Style。
- **AppleScript 改進**：取得項目細節與 App icon、以 left/right/Option-click reveal 或 click 項目；提升 Raycast 相容。
- 背景權限檢查不再重複詢問；macOS 27 上 Screen Recording 權限變更仍可偵測。

## Beta Four
- **Disabled Items**：可偵測部分透過 Control Center 設定隱藏的 App，另列一區（實驗性）。
- 項目可見時定期自動更新圖片；較寬項目（Granola 標題、網路流量）以自然寬度顯示。
- Groups 仍不可用。

## 7.0.0
- 只支援 macOS 27；Tahoe 支援稍後。
- 正式列出：mouse-free、Screen Recording 完全可選、Command Bar、Automation、App Intents（與 AppleScript 同等選項）、Focus Mode 熱鍵、可隱藏 clock / Control Center（flag 在 Advanced，隱藏某些系統項目會讓音量 pop-up 等系統 UI 失效）、presets 依螢幕同步、presets 移入 layout 頁、idle < 100 MB。
- Known issues：多項目 App 可分別排序但隱藏一個就全部隱藏；native overflow 邊界情況會閃爍，建議開「Move items that don't fit on-screen into Hidden」；部分項目圖片可能過時。

## 7.0.4
- 移動 Control Center 項目（電池、Wi-Fi）不再需要「Allow hiding system items」；該 toggle 只管 clock 與 Control Center 的 "bento box"。
- 部分 Advanced 權限改為要求特定檔案而非 Full Disk Access（實驗功能；Bartender 不需要 FDA）。
- 修正部分 macOS 27 build 上選單列卡住：Bartender 會自動 refresh bar；未開 Screen Recording 時顯示「Refresh menu bar」按鈕。
- 新增說明：macOS 27 會把同一 App 的所有項目一起隱藏/顯示。
- 相容性提示：提醒更新已發布 Golden Gate 版本的已知不相容項目。
- Clipboard（Command Bar）：貼到前一個 focus 的 App、鍵盤選擇、pin 等。

## 7.0.5
- Fn+N（Notification Center）在項目被隱藏時可正常開關；點擊時鐘開 Notification Center 更可靠。
- 擷取失敗時不再反覆重試；可用「Recapture Items」。
