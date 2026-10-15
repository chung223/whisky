# Whisky Wiki 目錄

每頁一行：連結 — 一句話摘要。新增頁面時同步更新這裡。操作紀錄見 [log](log.md)。

## 概覽

- [概覽](overview.md) — 目前知道什麼、還不知道什麼，以及各頁入口。

## Bartender 6（逆向）

- [架構](bartender/architecture.md) — 程序結構與子系統（列舉、隱藏、移動、Bar、外觀、更新偵測、觸發、Widgets、持久化）與對應類別。
- [機制](bartender/mechanisms.md) — 隱藏（length 10000）、CGS 列舉、⌘ 拖曳事件欄位、截圖與點擊轉送、Tahoe XPC+AX+圖示雜湊配對。
- [功能盤點（資源檔）](bartender/features-from-resources.md) — 從 plist、字串表、sdef、致謝清單整理的 6.6.2 功能、權限、程序結構與第三方元件。
- [公開功能](bartender/public-features.md) — 官網與發行說明中的 Bartender 6 功能，分 18 類，各附來源（公開資料，非逆向）。
- [產品歷史](bartender/history.md) — 2012 到 Bartender 7：2024 年出售給 Applause 的信任風波、Tahoe 抱怨、各版價格、使用者流向。

## 開源同類專案

- [Ice](projects/ice.md) — GPL-3.0、停滯：10,000 pt 分隔項目、私有 CGS 視窗清單、以 `0x33` 欄位指定視窗的 ⌘ 拖曳、暫時顯示再點擊；macOS 26/27 失效。
- [Thaw](projects/thaw.md) — GPL-3.0、活躍的 Ice fork：macOS 26 修正；macOS 27 的隱藏核心是閉源二進位（PlatformRuntimeKit）。
- [Hidden Bar](projects/hidden-bar.md) — MIT：雙引擎設計；macOS 27 用私有 `MBAssessmentModeAssertion` allow-list 隱藏；Notch Overflow 選單。
- [MenuBarHider](projects/menubarhider.md) — MIT、只支援 macOS 27：allow-list 隱藏、卸載 Apple `CoreMenuExtra*`、時鐘 hover 繞道。
- [Frost](projects/frost.md) — MIT、macOS 26 + 27：分版本後端、27 的公開 API 做法、最完整的行為量測。
- [MenubarHide](projects/menubarhide.md) — MIT：macOS 27 寬度斷崖、閃現展開擷取、改寫他人 `NSStatusItem Preferred Position` 鍵。
- [SaneBar](projects/sanebar.md) — 現為 MIT、已停止維護：不用私有 API、不需螢幕錄製；AX 優先；功能廣；授權歷史混亂。
- [SketchyBar](projects/sketchybar.md) — GPL-3.0：約 70 個私有 SkyLight 函式；以 alias 鏡像顯示選單列項目。
- [Pelmet](projects/pelmet.md) — GPL-3.0、活躍：macOS 27 allow-list 也能隱藏 Control Center、時鐘等系統圖示；處理新項目被擱置的問題；以真實 HID ⌘ 拖曳在按 Apply 時才排序。
- [Dozer](projects/dozer.md) — MPL-2.0、無人維護：10,000 pt 分隔項目手法的始祖。
- [Chest](projects/chest.md) — MIT、只支援 27：改寫系統「Allow in the Menu Bar」清單，不用私有 API；關著時寫位置再打開來排序；fail-closed。
- [Mezzanine](projects/mezzanine.md) — MIT、26：取用瀏海溢出的 item；menu mirroring；AX 掃描最佳化與 `NOTES.md` 平台觀察。
- [MenuTidy](projects/menutidy.md) — Unlicense、14–27：27 的 assertion 放在 holder 子程序（invalidate 解不掉通知中心）；選單列已滿偵測。
- [其他同類專案](projects/long-tail.md) — 2026-10 盤點的 58 個小專案（只讀 README）：Ice 衍生、27 allow-list、改系統開關、有界寬度、瀏海工具，各附可信度。
- [輔助函式庫](projects/supporting-libraries.md) — KeyboardShortcuts、HotKey、MenuBarExtraAccess、Sparkle、LaunchAtLogin-Modern、AXSwift 等與建議。
- [瀏海 App](projects/notch-apps.md) — boring.notch、NotchDrop：瀏海幾何與視窗層級。

## 技術概念

- [隱藏項目的手法](concepts/status-item-hiding.md) — 四種隱藏技術、Tahoe 的 5,016 pt 上限、macOS 27 移除過寬分隔項目。
- [macOS 27 MenuBarAgent allow-list](concepts/menubar-agent-allow-list.md) — 私有 allow-list API 的完整規格、限制與副作用。
- [列舉選單列項目](concepts/menu-bar-item-enumeration.md) — 視窗清單 vs AX `AXExtrasMenuBar` vs AX hit-test；26/27 的擁有者變化。
- [移動選單列項目](concepts/menu-bar-item-moving.md) — `0x33` 視窗 ID 移動、真實 ⌘ 拖曳、改寫偏好設定；常見陷阱。
- [擷取項目圖片](concepts/menu-bar-item-imaging.md) — CG、SkyLight、ScreenCaptureKit、凍結畫面與條帶擷取。
- [點擊隱藏項目](concepts/menu-bar-item-activation.md) — AXPress、合成點擊、暫時顯示。
- [私有 API 清單](concepts/private-apis.md) — 所有找到的私有符號、事件欄位、defaults 鍵與呼叫位置。
- [權限](concepts/permissions.md) — 各專案的 Accessibility 與 Screen Recording 需求與理由。
- [瀏海與多螢幕](concepts/notch-and-displays.md) — 瀏海、多螢幕、Spaces/全螢幕、視窗層級。
- [顯示與再隱藏](concepts/reveal-and-rehide.md) — hover/點擊/捲動顯示、自動再隱藏、熱鍵、profiles、triggers。
- [選單列外觀](concepts/menu-bar-appearance.md) — 著色覆蓋層、項目間距 defaults、隱藏 App 選單。
- [平台實測紀錄](concepts/platform-verification.md) — 在真機上量到的行為：2026-10-14 MacBook Pro 14"、macOS 26.7，31 個項目只畫出 11 個、擁有者全是控制中心、`kCGWindowIsOnscreen` 精確對應有沒有畫出來。
- [macOS 選單列平台變化](concepts/macos-menu-bar-platform.md) — macOS 14/15/26/27 對選單列管理工具的影響、API 現況、Whisky 必須處理的 14 件事。

## 比較

- [開源選單列管理工具比較](comparisons/open-source-menu-bar-managers.md) — 功能 × 專案表、授權與活躍度、26/27 支援、起點建議。
- [功能點子庫](comparisons/feature-ideas.md) — 依主題整理各專案的特別功能（27 新路線、menu mirroring、診斷、情境規則、圖示來源），附對 Whisky 的建議。

## 綜合與決策

- [Whisky 架構提案](synthesis/whisky-architecture.md) — 26/27 雙後端、AX 走 XPC、出錯全顯示、模組切分、資料模型、6 個待決定事項。
- [開發路線圖](synthesis/roadmap.md) — M0 實驗到 M7 發佈，每個里程碑附完成條件。
- [可行性](synthesis/feasibility.md) — 自己用 Swift 重寫可行；依難度分層、開源專案行數、主要風險與起步建議。
