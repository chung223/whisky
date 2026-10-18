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

## [2026-10-15] query | v0.7：設定視窗、快捷鍵自訂、記住版面
- 新功能：設定視窗（⌘,）、可錄製的快捷鍵、Whisky Bar 裡 Apple 系統項目用 SF Symbols、記住排好的版面並在跑掉時提醒（不自動移動）。
- 實測（只讀）：選單列 90 秒內穩定；麥克風指示（AudioVideoModule）會自己插進 Whisky 左邊。版面比對因此改成比順序、不算 Control Center 模組、連續兩次才提醒。
- 更新 concepts/platform-verification.md、synthesis/roadmap.md、synthesis/whisky-architecture.md（實作現況）。

## [2026-10-15] query | v0.8：瀏海面板與介面整理
- Whisky Bar 從瀏海倒出來（滑過提示、點了展開，瓶頸造型不遮選單列）；玻璃小面板給沒有瀏海的螢幕；排列視窗改成選單列預覽；設定視窗整理。
- 實測：全螢幕時選單列項目全部不在畫面上（新增保護）；溢出的選單列最左項目在螢幕外，送走失敗（改目標）；重排改成每步重算。
- 更新 concepts/platform-verification.md、projects/notch-apps.md、synthesis/roadmap.md、synthesis/whisky-architecture.md。

## [2026-10-15] query | 實際使用回饋：iStat 下拉面板、常用、圖示快捷鍵
- 記錄顯示使用者從瀏海面板打開 Keysmith、DigUp、Presence（menu mirroring）都正常；iStat 的一個項目「暫時放回再點」兩次都判定沒打開。
- 【推論】下拉面板不是由項目自己的程序開的，或出現得比 0.6 秒慢。改成認選單列附近新出現的任何視窗（PopupDetection），等久一點，認不出時記下新視窗細節。
- 新增：Whisky Bar「常用」（frecency，一週減半）、圖示快捷鍵（設定 › 圖示快捷鍵，或 Whisky Bar 右鍵）。

## [2026-10-15] re | 酒杯只在搬移時出現：自我測試兩種模式
- isVisible=false 會讓 AppKit 忘記酒杯位置（再出現在最左邊）；改成移除後重建並寫回位置，回到原位。
- 自我測試：一般模式與「酒杯住在瀏海裡」都 0 失敗；修掉重排「每步重算」遇到已在定位的釘選會原地重複的回歸。
- 發現：沒有分隔項目時，拿掉酒杯會讓 macOS 重排瀏海旁的項目順序，所以這個模式要求分隔項目。iStat 仍打不開（AXPress 與兩種點擊都沒有任何新視窗）。
- 瀏海裡的酒杯：滑過時倒酒動畫、展開時圖示依序流出；啟動與滑過時先擷取真實圖案。更新 concepts/platform-verification.md。

## [2026-10-15] re | 更正：iStat Menus 用一般點擊打得開
- 上一筆說 iStat「仍打不開」是錯的：14:30 使用者再試時，第三招（真的移動游標的一般點擊）兩個 iStat 項目都打開了；AXPress 回 -25200、指定視窗的點擊沒反應。
- Whisky 現在記住哪些 App 要用一般點擊（plainClickApps），下次直接用；失效時清掉重來。更新 synthesis/roadmap.md。

## [2026-10-16] re | 在使用者的選單列上打開分隔項目、酒杯住進瀏海
- 舊流程兩次失敗：1 pt 的分隔項目被擠到瀏海邊界後跑掉，Whisky 送走了大批藏著的項目，失敗後還原。可見的版面一度少了 LLM Wiki、Plaud。
- 新流程：分隔項目先放到酒杯旁、立刻展開，再把要留的釘回；自我測試 0 失敗；真實選單列 10 步完成，版面和原本一致。之後酒杯離開選單列，順序不變。
- 更新 concepts/platform-verification.md。

## [2026-10-16] query | 藏起來的圖示有變化時從瀏海提醒；排列視窗的瀏海裡畫酒杯
- 新功能：ChangeWatcher 每 30 秒比對藏著的項目，安靜過後有變化就在瀏海顯示 5 秒，點了直接打開。一輪約 0.3 秒。
- 排列視窗：酒杯住在瀏海裡時畫在預覽的瀏海裡；版面跑掉時，滑過瀏海會顯示橘點。
- 更正 README 的限制：分隔項目打開時大多仍截得到真實圖案。更新 concepts/platform-verification.md。

## [2026-10-16] lint | 第一次健康檢查
- 索引完整，沒有孤兒頁。
- 過時：overview.md 還停在研究階段，補上「Whisky 做到哪裡、實測學到什麼」，並更新「還不知道的」。
- 矛盾：concepts/menu-bar-item-imaging.md 說螢幕外擷取回 -3811，和 26.7 實測不同，已標【矛盾】。concepts/menu-bar-item-activation.md 的「待實測」補上 26.7 的答案（menu mirroring、iStat 要一般點擊）。

## [2026-10-16] lint | 程式審查（獨立代理）與修正
- 重新啟動後分隔項目不會展開（AppKit 把它放回 1 pt 的狀態），而酒杯照樣被拿掉，使用者的版面又被瀏海邊界重挑。改成啟動時比對分隔項目右邊的順序：一致才展開，不一致就留著、酒杯放回選單列、跳出版面提醒，由使用者決定要不要排回來。
- 其他修正：
  - 酒杯在瀏海時版面檢查失效。
  - 分隔項目開著時自我測試會把整排推走（現在拒絕執行）。
  - 酒杯位置在重新啟動後遺失（改存在 Whisky 自己的 key）。
  - 酒杯使用中被收走、同時兩個搬移搶酒杯。
  - 暫時放回失敗會把項目留在原處。
  - 瀏海面板關閉後還佔著鍵盤。
  - 同時掃描時拿到舊資料。
  - 重排計畫來回跳。
  - 酒杯在瀏海時，以它右邊的鄰居當右邊界。
- 排回來或套用時，若分隔項目沒展開，一律走可靠流程：先放分隔項目、展開，再釘回。

## [2026-10-16] re | 重新啟動後的分隔項目：自動排回
- 使用者選擇「重新啟動後等閒置自動排回」。實測每次重新啟動，分隔項目都會跟左邊的鄰居對調，所以每次都要排回一次（約 8 秒）。
- 修正一個會遺失版面的漏洞：排回時有 App 沒回應掃描，記住版面時把它忘掉；改成保留暫時不在的項目，排回前多掃描幾次。
- 更新 concepts/platform-verification.md。

## [2026-10-16] re | 重新啟動不用排回（分隔項目以展開長度建立）；自我測試補測
- 使用者離開滑鼠約 6 分鐘：安裝、關掉分隔項目、跑兩輪自我測試、重新打開分隔項目、做重新啟動實驗。
- 結果：分隔項目以展開長度建立後，三次重新啟動都 0 次移動，已設為預設；啟動時等排版穩定才比對。
- 自我測試第 9 步（排好的一段塞到瀏海邊界）用 Whisky 自己的測試項目會對調，原因未明，改成選用。放不下時瀏海邊界的順序會自己變。
- 另外：關掉分隔項目時記下的版面不完整（瀏海邊界被重挑），這次先備份、之後寫回。更新 concepts/platform-verification.md。

## [2026-10-16] query | 情境版面（Presets / Triggers）
- 每個情境是一份排好的版面加上觸發條件：平常、接上外接螢幕時、用電池時、只手動。PresetSelector 依清單順序挑第一個成立的，否則用平常（WhiskyCore，有測試）。
- 監聽螢幕變化與電源（IOPSNotificationCreateRunLoopSource）。切換時把該情境設成要維持的版面，等閒置後排好；在某情境下重新排列會存回該情境。
- 使用者的 Mac 上已建立「平常」與「外接螢幕」兩個情境（內容相同，作為起點）。同時打開了「登入時自動開啟」。

## [2026-10-16] lint | 第二次程式審查（自動搬移與情境版面）與修正
- 自動排回一次只跑一個：新的請求先取消舊的、等它停下；排回完成時若要維持的版面已經換了（情境切換），不再把結果記下覆蓋。
- 自動排回只准送走 Whisky 認得、而且不在版面裡的項目；掃描漏掉的視窗（App 回應慢）一律不碰（以前可能把排好的項目送走）。
- 情境切換先「待生效」，排好才變成目前情境；這段時間手動排列會取消切換並存回原情境。刪除目前情境時正式切換。
- 等使用者閒置有上限，排到一半等太久就停；選單列隱藏時啟動檢查改成「先不判斷」；關掉自動排回時，位置不對就收起分隔項目。
- 螢幕變化要穩定 3 秒才算數，螢幕睡眠期間不算；醒來後等 10 秒再判斷。

## [2026-10-16] query | macOS 27 降級保護
- 27 的選單列由 MenuBarAgent 畫成單一視窗，Whisky 的移動、分隔項目、逐項擷取都會失效（beta 1 時所有同類工具都壞了）。
- PlatformSupport.movesItems：27 以上停用所有移動（ItemMover 一律拒絕）、分隔項目、版面檢查、變化提醒、暫時放回、酒杯住在瀏海裡、情境版面選單；保留 Whisky Bar、menu mirroring、AXPress、快捷鍵。
- 設定與開場教學顯示說明。用 simulateMacOS27 在 26.7 上模擬驗證過，關掉模擬後版面照常。

## [2026-10-16] query | 暫停開發，先實際使用
- v0.9 裝在使用者的 Mac 上每天用：分隔項目開著、酒杯住在瀏海裡、登入時開啟、情境「平常／外接螢幕」。
- macOS 27 支援與公開發佈，使用者都說「不急」。下一步：使用幾天後讀記錄，修實際碰到的問題。
- 還沒用真實事件驗證過的：插拔外接螢幕或用電池時的情境切換、有變化時的瀏海提醒、版面真的跑掉時的排回。

## [2026-10-18] query | 選單列圖示全部不見：情境版面被自動排回越改越少
- 原因：插拔外接螢幕時，每次自動排回後把重讀的結果寫回情境；重讀碰上選單列在動（酒杯離開、螢幕接上）就漏項目，「平常」從 9 個縮成 1 個，切回來就把其他圖示都藏起來。
- 修正 LayoutMemory（選單列靜止時才採用掃描、配不到視窗的項目保留）與 PresetManager（自動排回不改情境內容）。細節寫進 concepts/platform-verification.md。
- 把使用者的「平常」「外接螢幕」改回記錄裡最後完整的內容（各 9 項），裝新版後自動排回：7 次移動全部成功，情境仍是 9 項。貼貼沒在執行，所以沒出現。install.sh 的建置輸出改到 build.noindex。

## [2026-10-18] query | 還是不穩定：虛擬螢幕測試、圖示被拖出選單列、版面放不下
- Dockette 對話的多螢幕測試建立虛擬螢幕，每次 35–45 秒就移除；Whisky 6 分鐘內換了 6 次版面，貼貼與 MenuBarUSB 的圖示被拖出選單列，App 跟著結束。
- 修正 PresetManager（穩定 60 秒才切換）、Arranger（螢幕一變就停）、AppDelegate（螢幕穩定才排回，被打斷最多再試 3 次）、DragPoster/ItemMover（不在選單列外放開）。WhiskyCore 加 `MovePlanning.isSafeDrop` 與測試。
- 把 MenuBarUSB 的 `VisibleCC` 改回 true，重開它和貼貼。新版排回 14 次移動都成功，但 Purrbit（166 pt）加進來後「平常」放不下，MenuBarUSB 和 Shot 被擠到瀏海底下。細節在 concepts/platform-verification.md。

