來源：https://github.com/thaw-app/Thaw/issues/687
標題：[Tracking] macOS 27 (Golden Gate) support & preview builds
發佈日期：2026-06-08 開啟；已 closed；438 則留言（本摘要只讀維護者 diazdesandi 的長留言）
存取日期：2026-10-12（gh api）

# 摘要筆記（Thaw 維護者在 macOS 27 beta 期間的觀察；社群一手資料，非 Apple 官方）

- 2026-06-10：macOS 27 有新程序 **MenuBarAgent**（有 man page 但幾乎無內容）；XPC 只要 App 有簽章就能 handshake；許多函式是 stub。可以偵測項目屬性（出現新的 `com.apple.campo`）、擷取與重排圖示；缺的是切換 visible / hidden / always hidden。
- 2026-06-22 Preview 1：除 always hidden 外功能大致可用。
- Preview 2：修正「重試無法達成的移動（例：強迫放在 Sound 這類 anchored 系統項目旁）」造成的游標 thrash 無窮迴圈。
- Preview 3：支援隱藏/重排 Apple 系統項目（預覽）；加保護避免反覆嘗試 macOS 拒絕的移動。
- Preview 4（2026-06-30 / 07-03）：macOS 27 新的 **native overflow chevron** 不能被當成一般 status item（否則重複圖示、錯配 App）；移動項目時抑制使用者滑鼠輸入；Always Hidden 透過「control-item synthesis、divider ordering」恢復；醒來/重接螢幕後不要把未穩定的 layout 存檔。
- 2026-07-16：有些 App 每次更新改名，難以追蹤；macOS 27 上某些 App 需要發出 **`AXExtrasMenuBar`** 才能被選單列看見（Little Snitch 為例）。
- 2026-07-20：**已不再用游標移動項目，改為「preferred-position writes」取代 synthetic drags**；Stats 一個 bundle 多個圖示，**hiding 是 per bundle 不是 per icon**。
- 2026-07-19：native hidden overflow 會「污染」screen capture；以 App icon fallback 當開關。
- 2026-07-24 已知限制：同 bundle 多項目無法分開（macOS 27 限制）；部分 App 不發出 `AXExtrasMenuBar`；Focus、Sound 等系統子項目可移不可單獨隱藏；Game Mode 等被系統強制隱藏的項目無解。
- 從 Thaw Bar 開啟項目需要 App 的 `AXExtrasMenuBar` 下有可 `AXPress` 的子元素；沒有就無法從 Thaw Bar 開啟。
- 政策：依賴其他 App 或 macOS 如何暴露項目的問題（缺 AXExtrasMenuBar、身分不穩、Control Center 代管怪癖）視為上游問題。
- macOS 26 上 Little Snitch 常以 **Control Center 代管項目**出現、沒有穩定的 source PID。
- 拔接外接螢幕時若各螢幕 spacing 不同，Thaw 會問是否套用；套用要**重新啟動有選單列項目的 App**（macOS 無法即時更新 spacing）。
- 記憶體：冷啟動約 24–25 MB，暖 cache 約 67 MB（3 台 4K、10–12 項目）。
- 2026-07-25 頂端狀態：Preview 5，「works well for most people」，往 v2.1.0 Nightly 推進；之後 Tuck 頁面稱 macOS 27 支援在 3.0 alpha。
