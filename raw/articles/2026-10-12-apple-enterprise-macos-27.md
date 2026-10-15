來源：https://support.apple.com/en-us/148830
標題：What's new for enterprise in macOS Golden Gate 27（Apple Support）
發佈日期：2026-09-28（頁面發佈日）
存取日期：2026-10-12

# 摘要筆記

- **選單列 overflow（Apple 官方唯一明文）**：空間不足時選單列會動態調整，把項目藏起來，以精簡的 overflow indicator 取代；按下即顯示被藏的項目。
- Status items（此處指 MDM 狀態回報，非 NSStatusItem）：新增 enrollment type、Lockdown Mode、Setup Assistant 等狀態。
- TCC：可設定 consolidated consent prompt；新指令 `tccutil list` 在受管裝置列出隱私授權；App 不能再直接讀本機 TCC 資料庫。
- Accessibility：PPPC payload 中已 deprecated 的 Accessibility key 若被套用，使用者每個 App 會看到一次通知；使用者可在 System Settings 關閉 MDM 授予的 accessibility 權限。
- 27.0.1 修正 Platform SSO 鎖定畫面問題。
- 沒有提到 ScreenCaptureKit、CGWindowList 或選單列相關 MDM key。
