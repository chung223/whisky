來源：https://github.com/jordanbaird/Ice/issues/954
標題：[Bug]: Ice in menu bar not working anymore (MacOS Golden Gate 27)
發佈日期：2026-06-08 開啟（仍 open；42 則留言，讀至 2026-10）
存取日期：2026-10-12（以 gh api 讀取 issue 與留言）

# 摘要筆記（社群觀察，非 Apple 官方，也非 Ice 維護者）

- 原報告：Ice 0.11.13-dev.2、macOS 27 beta 1；所有圖示都顯示、無法隱藏；選單列可看到 Live Activities；電池圖示改版。
- 2026-06-10 fifafu（BetterTouchTool 開發者）：找到兩種可行但受限的方式，第一種已實作於 BTT 5.670（見 folivora 討論串）。
- 2026-06-13 Thaw 維護者 diazdesandi：「Ice is no longer maintained」；macOS 27 上 screen recording 權限行為不同（Bartender 6 亦同）。
- 2026-07-06：有人貼假 fork（Ice-Maintained）內含惡意 curl|bash 指令，被揭發並檢舉下架 → **注意：此類空窗期有惡意軟體冒充**。
- 2026-09-04：fif7y 發佈新開源工具 Pelmet（為新架構重寫）。
- 2026-09-13：Thaw 的 macOS 27 版程式碼暫時改為私有 repo（抱怨被其他專案與付費 App 抄襲）；有人質疑 GPL 授權問題。
- **2026-09-22 brentc22 技術分析（重要但屬個人觀察）**：
  - 到 macOS 26 為止，每個 status item 是**獨立視窗**（未文件化），整個類別的工具都靠 `CGWindowList` 列舉、截圖、推出畫面外。
  - macOS 27 把整條選單列畫成**一個視窗**，沒有東西可列舉。
  - spacer 撐開推擠法失效：status item 視窗寬度達螢幕一半時會被直接**丟棄**而非夾住（1728pt 螢幕上 848pt 隱藏、849pt 不隱藏；848+16=864=一半）。
  - 有白名單：`MenuBarAgent` 記錄「Filtering out unsupported status item: com.jordanbaird.Ice」，一分鐘 34 次，spacer 一出現就被丟掉。
  - 可行替代：**assessment mode**（學校考試模式）的 allowlist——持有一個列出允許顯示 bundle id 的 assertion，其餘不畫；收合/展開就是換 assertion。`MBAssessmentModeConfiguration` 只接受 NSArray；`allowedSystemItems` 要用 0...255；自己的 bundle id 一定要在清單中。屬 private framework（dlopen），隨時可能壞、不能上 App Store。
  - 說 Bartender 有 Golden Gate build、Brow 與 Thaw 已為新架構重建，都放棄了視窗列舉。
- 2026-10-11：leonardovida 有 commit 改系統項目編號到 255。
- 維護者 jordanbaird 未回應；Ice 最後 commit 為 2025-09（見 Ice releases 摘要）。
