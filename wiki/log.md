# Whisky Wiki 紀錄

只追加。格式：`## [YYYY-MM-DD] <ingest|query|lint|re> | 標題`

## [2026-10-12] lint | 建立知識庫骨架
- 依 Karpathy LLM Wiki 模式建立 raw/、wiki/、CLAUDE.md（schema）。

## [2026-10-12] re | Bartender 6.6.2 bundle 盤點
- 複製 Info.plist、entitlements、sdef、字串表、Acknowledgements、App Intents 到 raw/bartender/bundle/。
- REA inspect_macho（ev_9a068074…）→ raw/bartender/rea/inspect_macho.json、dylibs.txt、imports*.txt；strings 與 Swift 類別清單。
- 新增 wiki/bartender/features-from-resources.md。

## [2026-10-12] re | Bartender Service.xpc（TahoeXPC）
- Ghidra 分析 arm64 slice：逐 pid 讀第二個 AXMenuBar 的項目 frame（ev_c9ba9de4…）。
- 筆記 raw/bartender/rea/notes-xpc-service.md。

## [2026-10-12] ingest | 網路資料：Bartender 6/7 與 macOS 14–27 選單列變化
- raw/articles/ 新增 31 份摘要（官網、發行說明、媒體、Apple 文件、Ice/Thaw macOS 27 issue）。
- 新增 wiki/bartender/public-features.md、wiki/bartender/history.md、wiki/concepts/macos-menu-bar-platform.md。
- 重點：macOS 27（2026-09-14）讓傳統手法失效；Bartender 7 與 Thaw 不再移動游標；Screen Recording 應設為可選。

## [2026-10-12] ingest | GitHub 開源同類專案（8 個 clone）
- Clone：Ice、Thaw、Hidden Bar、SaneBar、SketchyBar、MenubarHide、MenuBarHider、Frost（SHA 見 raw/github/manifest.md）。
- 新增 wiki/projects/ 11 頁、wiki/concepts/ 11 頁、wiki/comparisons/open-source-menu-bar-managers.md。
- 重點：macOS 27 真正的隱藏靠私有 MenuBarClientCore allow-list；身分辨識只剩 AX 可靠；MIT 參考優先用 Frost / Hidden Bar / MenuBarHider。
- 待辦：clone fif7y/pelmet（GPL）、追 MenuBarAgent 不動游標的移動介面。

## [2026-10-12] ingest | Pelmet (fif7y/pelmet)
- Clone 3f757c96（v0.3.1，GPL-3.0），新增 wiki/projects/pelmet.md。
- 更新 concepts/ 8 頁、comparisons/open-source-menu-bar-managers.md，矛盾處加註不覆寫。
- 重點：allowedSystemItems 不放系統項目編號即可隱藏系統圖示；assertion 生效期間新項目會被擱置；寫 TrailingItemPreferredPositions 無法重排執行中的項目（與「Thaw 用 preferred-position 寫入」的說法矛盾）。

## [2026-10-12] re | Bartender 6.6.2 主程式
- Ghidra 對 15 MB Swift binary 的分析逾時，改用 otool 反組譯加 Mach-O metadata 解析；筆記 raw/bartender/rea/notes-main-*.md。
- 新增 wiki/bartender/architecture.md、wiki/bartender/mechanisms.md。
- 重點：三個分隔項目 + length 10000；CGSGetProcessMenuBarWindowList；⌘ 拖曳事件欄位 51（0x33）= 目標視窗；截圖用 CGWindowListCreateImage；Tahoe 走 XPC+AX+圖示雜湊。

## [2026-10-12] query | Whisky 架構提案與路線圖
- 新增 wiki/synthesis/whisky-architecture.md、wiki/synthesis/roadmap.md、wiki/overview.md。
- 建議：只支援 macOS 26/27、arm64、On-Demand 排列、Screen Recording 選用、27 用私有 allow-list 並保留公開 API 降級。

## [2026-10-14] query | 能不能自己用 Swift 重寫
- 新增 wiki/synthesis/feasibility.md，更新 index。
- 結論：可行，目標設成核心功能而非完全對等；隱藏／顯示容易，排列難，27 隱藏依賴私有 allow-list 屬高風險。
- 用 wc -l 量了 8 個 clone 的 Swift 行數（MenuBarHider 1.8k 到 Thaw 137k）作為規模參考。

## [2026-10-14] ingest | GitHub 長尾同類專案（58 個 README）
- gh search 找到 58 個未收錄的專案，README 快照存 raw/github/readmes/，manifest 補說明；4 個子代理分組摘要，抽查 15 個說法與原文一致。
- 新增 wiki/projects/long-tail.md、wiki/comparisons/feature-ideas.md；概念頁 7 頁加補充段落；public-features §11 補 Top Shelf agent bridge。
- 重點：27 的新路線（改系統「Allow in the Menu Bar」清單、低於半寬的有界分隔項目、menu mirroring）；README 之間有矛盾（27 撐寬、26 丟項目、合成 ⌘ 拖曳）。
- 路線圖 M0 加 S6、S7，M4 點擊改以 menu mirroring 為主；架構 §10 #5 改為「先不定案」。

## [2026-10-14] ingest | Chest、Mezzanine、MenuTidy 原始碼
- Clone boringbar/chest 4bc62a5（MIT）、brianmpollack/Mezzanine e3f4c10（MIT）、PerpetualBeta/MenuTidy b518455（Unlicense），manifest 已更新；3 個子代理精讀，抽查關鍵段落與原文一致。
- 新增 wiki/projects/chest.md、mezzanine.md、menutidy.md；概念頁 9 頁更新（hiding、allow-list 第 21–24 點、activation 改寫 menu mirroring 段、moving §4–5、enumeration、imaging、notch、reveal、permissions）。
- 重點：Chest 用 group.com.apple.controlcenter 的 trackedApplications 隱藏、用 com.apple.MenuBar 的 TrailingItemPreferredPositions 排序（和 Pelmet 記載的位置表矛盾）；MenuTidy 說同一個程序 invalidate 後通知中心仍打不開，改用 holder 子程序；26 與 27 上對被藏 item AXPress 的結果不同。
- 架構：私有 API 改放 holder 子程序、點擊以 menu mirroring 為主；路線圖 S4、S6 補細節，新增 S8。

## [2026-10-14] query | 先讓 Whisky 在使用者的 Mac 上能用
- 量測使用者的 MacBook Pro 14"（macOS 26.7）：31 個選單列項目只畫出 11 個，其餘被瀏海擋住。新增 wiki/concepts/platform-verification.md。
- 路線圖調整：先做 v0.1（Whisky Bar + menu mirroring，原 M4 的一部分），macOS 27 延後。
- app/ 建立 XcodeGen 專案、WhiskyCore 套件（18 個 Swift Testing 測試通過）與 App 本體；Release 版以 Developer ID 簽章裝到 /Applications/Whisky.app。

## [2026-10-15] re | Whisky 0.1 在 macOS 26.7 上的 AX 掃描（S8 前半）
- 更新 wiki/concepts/platform-verification.md：31 個項目、22 個沒畫出來；15 個關掉的 App 的 AX frame 在螢幕左下角；控制中心會重複列出第三方項目；全部項目只有 AXPress（沒有 AXShowMenu）；13/22 讀得到選單。
- app：掃描改用中線判斷選單列那一列與視窗對位，以視窗去重；診斷檔加上動作與選單內容。

## [2026-10-15] query | 不在選單列上的 15 個 App 是 Bartender 隱藏的
- 讀使用者的 Bartender 偏好設定（只讀）：版面在 ProfileSettings.activeProfile 的 Show／Hide／AlwaysHide，元素是 `<bundleID>-<autosave name>`。15 個 App 都在 Hide 或 AlwaysHide。寫進 bartender/architecture.md「持久化」。
- app：掃描加上 Placement（shown／hidden／off），Whisky Bar 分兩列，第二列列出不在選單列上的項目；15 個裡 9 個讀得到選單。

## [2026-10-15] re | 排列功能：0x33 ⌘ 拖曳在 macOS 26.7 上驗證（S3）
- app 0.2.0：WhiskyCore 加 MovePlanning／DragReleaseGate（27 個測試通過）；App 加 DragPoster、ItemMover、Arranger、CursorConcealment（dlsym 取 SetsCursorInBackground）、whisky:// URL scheme；Bar 右鍵「放到選單列上」、酒杯選單「收到瀏海後面」。
- 實測：放到 Whisky 左邊、送到最左邊都一次到位；windowNumber 超出 UInt32 造成一次當機（已修，改用位置對位）；沒有 Screen Recording 讀不到視窗名稱。更新 concepts/platform-verification.md、menu-bar-item-moving.md。

## [2026-10-15] query | 選單列順序是不是 Bartender 控制的、能不能關掉它
- 使用者機器上的 Bartender 自 2026-10-02 起沒有執行（TerminationReasons：Setapp 結束它），沒有 LaunchAgent。各 App 的位置存在它們自己的 `NSStatusItem Preferred Position <autosave>` defaults（例：Telegram 1570、Surge 611），是 macOS 保存的，不需要 Bartender 在跑。
- 備份使用者的 Bartender 偏好設定到 raw/bartender/user-prefs/（不進版控），供日後匯入版面。

## [2026-10-15] re | v0.3 排列視窗與 Bartender 匯入
- WhiskyCore 加 LayoutPlanner、BartenderMatcher、AutosaveNameInference（40 個測試通過）；App 加 LayoutDraft、LayoutEditorView／Controller、Arranger.apply、whisky://apply、whisky://plan-bartender。
- 實測：多步套用一次到位；Cloudflare WARP 常駐的 20×1 layer-101 視窗讓「有選單開著」誤判（已修）；iStat 的 defaults 位置 key 可推回 autosave 名稱。更新 concepts/platform-verification.md、synthesis/roadmap.md。

## [2026-10-15] re | 分隔項目測試失敗（使用者的真實選單列）
- v0.4 分隔項目：放置失敗（落在跨邊界的輸入法左邊）；自動調整因找錯視窗進入回饋迴圈，把可見圖示推到瀏海後面。已結束 Whisky 止血，之後以單步移動大致還原。
- 新觀察寫進 concepts/platform-verification.md：邊界放置會落到隱藏群左邊、邊界移動會讓鄰近項目互換、SystemUIServer 項目依記住的位置歸位、拎起寬項目時整排滑動。
- 分隔項目預設關閉並從選單移除；下一步先用測試項目研究邊界行為。

## [2026-10-15] re | 分隔項目改用固定長度並以假圖示自我測試通過；倒酒動畫
- 第一次自我測試因計畫最佳化搬動了 9 個真實圖示（已依原順序放回）；修正為「只重放想要的項目」並加硬性保險。
- 「剛好填滿空隙」的動態分隔項目不穩定，改用 Ice／Bartender／Frost 的固定 10000 pt；自我測試 6 步全過、0 次重試，結束後使用者的選單列與測試前相同。
- 新增 WhiskyCore RebuildPlanner（52 個測試通過）、App 的 OwnItems（以建立前後的視窗差集取得自己項目的 ID）、SpacerSpike、GlassIcon／GlassAnimator（打開 Whisky Bar 時倒酒、關閉時倒空）。
- 更新 concepts/platform-verification.md、synthesis/roadmap.md。

## [2026-10-15] query | v0.6：被藏的圖示暫時放回再點、⌃⌥⌘W、搜尋
- ItemActivator：沒有選單、被藏在瀏海後面或螢幕外的項目，先放到 Whisky 旁邊（可靠的移動）、AXPress（沒反應再用帶 0x33 的真實點擊）、等它開的視窗關掉再送回去。未實機測試（會在使用者畫面上彈出視窗）。
- GlobalHotKey：Carbon RegisterEventHotKey 註冊 ⌃⌥⌘W 開關 Whisky Bar（不需權限）。
- Whisky Bar 搜尋：打字過濾、←→ 選擇、Enter 打開、Esc 先清除再關閉。

## [2026-10-15] lint | 公開到 GitHub 前的檢查
- raw/github/readmes/（58 份第三方 README 的完整複本）改為只留本機，不進版控；manifest 註明重抓方式。
- 實測紀錄中的銀行憑證元件名稱改為泛稱。raw/articles 為自寫摘要加短引文，保留。
- wiki/bartender 依本檔 schema（只描述行為、不含偽代碼）保留；raw/bartender、clone、使用者設定備份不進版控。

## [2026-10-15] re | 自我測試擴充：送走、menu mirroring、暫時放回再點
- 第 7、8 步通過；第 9 步發現兩個問題並修正：自己的 status item 要在主執行緒 AXPress（AppKit 在呼叫端執行動作，曾因此當機一次）、空的選單列上放回圖示前要先收起分隔項目。
- 測試用 popover 關不掉（推測是排版中被孤立），第 9 步移出自我測試；正式功能放回後多等 600 ms。更新 concepts/platform-verification.md。
