來源（多個官方小頁面，合併摘要）：
- https://www.macbartender.com/Bartender5/PermissionInfo/ （Bartender Permissions）
- https://www.macbartender.com/Bartender5/PermissionIssues/ （權限疑難排解）
- https://www.macbartender.com/Bartender5/ScreenCaptureMenuBarItem/ （macOS purple menu bar item）
- https://www.macbartender.com/B5blog/Bartender-is-capturing-your-screen/ （2023-09-25）
- https://www.macbartender.com/Screen-Recording-Permission/ （macOS Catalina and Screen Recording Permission, Bartender 3）
- https://www.macbartender.com/Bartender5/menu-bar-item-not-movable/ （Menu bar item not movable）
- https://www.macbartender.com/B4blog/macOS-Ventura-Permissions/ （2022-11-08）
- https://www.macbartender.com/privacy/ （Privacy Policy）
標題：Bartender 官方權限與隱私說明頁（合輯）
發佈日期：多數未標示；部落格文為 2022-11-08、2023-09-25
存取日期：2026-10-12

# 摘要筆記

## 為何需要 Screen Recording（官方說法）
- PermissionInfo：Bartender「reads your menu bar items」以顯示每個項目的正確圖片；只讀選單列區域；不錄你的螢幕。
- Catalina 頁（Bartender 3）：用 Screen Recording「take a photo of your menu bar」，用來知道目前顯示哪些項目並管理它們；只拍選單列區域，不儲存、不上傳。
- 2023-09-25 文：取得項目圖片用於 **Bartender Settings、Bartender Bar、Search**；每次取得後 macOS 顯示紫色 screen capture 指示器約 20 秒，Bartender 無法隱藏。
- 降低出現頻率：少用 Bartender Bar、改用在選單列 scroll/swipe、用鍵盤快捷鍵。
- Privacy Policy：screen recording 只用來拍選單列；不送伺服器、不以任何形式儲存；App 不傳任何資料給開發者。（網站本身用 Google Analytics、Mixpanel；付款 FastSpring。公司名 Bartender App LLC。）

## 為何需要 Accessibility（官方說法）
- PermissionInfo：「to move your menu bar items」，以便在選單列中排列項目。

## 移動機制線索
- menu-bar-item-not-movable：有些項目無法被 Bartender 移動，因為擁有該項目的 App 阻止 **command+drag**；測試法：退出 Bartender，自己 ⌘-drag 看看。
- 給開發者：檢查是否覆寫 `sendEvent:` 而擋掉 command+drag。
  → 公開資料顯示 Bartender 是用模擬 ⌘-drag 的方式移動項目（Tahoe 及之前）。

## 疑難排解
- PermissionIssues：移除兩項權限後重開；或 `tccutil reset ScreenCapture/Accessibility <bundle id>`；bundle id：直購版 `com.surteesstudios.Bartender`，Setapp 版 `com.surteesstudios.Bartender-setapp`。
- Ventura / 12.6.1 bug（2022-11-08）：重開機後權限失效，同樣用 tccutil reset。

## 歷史註記
- system-item-setup 頁：Bartender 1 在 El Capitan 需暫時關閉 SIP 安裝 system component 才能控制 Apple 系統項目（Bartender 2 起不需要）。
