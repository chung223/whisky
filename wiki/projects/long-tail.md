---
title: 其他同類專案（2026-10 盤點）
type: project
tags: [open-source, long-tail, macos-26, macos-27, survey]
sources:
  - raw/github/readmes
  - raw/github/readmes/_meta-2026-10-14.tsv
updated: 2026-10-14
---

# 其他同類專案（2026-10 盤點）

2026-10-14 用 `gh search repos` 搜尋選單列管理工具，排除已 clone 的 9 個專案後，抓了 58 個候選的 README 與基本資料。
其中 Chest、Mezzanine、MenuTidy 後來 clone 下來讀了原始碼，各有專案頁：[Chest](chest.md)、[Mezzanine](mezzanine.md)、[MenuTidy](menutidy.md)。
README 快照在 `raw/github/readmes/<owner>__<repo>.md`（每檔開頭註明網址、stars、commits、建立日期與授權），彙總資料在 `_meta-2026-10-14.tsv`。

**本頁只根據 README，沒有讀原始碼，也沒有實際執行。** 功能與量測數字都是作者的說法。
功能點子的整理見 [功能點子庫](../comparisons/feature-ideas.md)；新的隱藏機制已補進 [隱藏項目的手法](../concepts/status-item-hiding.md) 等概念頁。

## 整體觀察

- **macOS 27 帶來一波新專案**：58 個裡有 44 個是 2026-07 以後建立的，48 個 stars 不到 10。
- **很多是 AI 一次產出**：一天內 1–4 個 commit、README 像範本、roadmap 和功能表重複。shelf、Stewardie 自己寫明是用 AI coding agent 做的；Stash、Stow 的 repo 裡有 `docs/superpowers/`。
  但也有幾個 AI 協作的專案量測紮實（例如 Stash），不能只看這點判斷。
- **授權要注意**：MenuBarCompact、Stow、Stewardie、Nuviloft 沒有 LICENSE（法律上等於保留所有權利）；Barp 衍生自 Ice（GPL）卻沒附授權。
- **README 之間有矛盾**，需要實測（見 [隱藏項目的手法](../concepts/status-item-hiding.md) §5）：
  separator 撐寬在 27 上還推不推得動、26 會不會丟掉超寬的項目。
- Stash 的 README 提到另一個已支援 27 的競品 **Brow**（brow-app.com），本次沒查。

可信度：**高** = 有具體量測或清楚的取捨說明；**中** = 說法合理但細節少；**低** = 範本式、空殼、只有 binary，或宣稱多但無從驗證。

## A. Ice 衍生（GPL-3.0）

| Repo | 支援 | 重點 | 可信度 |
|---|---|---|---|
| [pnikolaidis/icemelt](https://github.com/pnikolaidis/icemelt) | 26、27 | 27 上撐寬隱形 divider（大螢幕再加 spacer），讓系統的 « overflow 收走左邊的項目，不用 allow-list；沒有 Screen Recording 時改用 App icon。README 有「只用 27 內建 vs 加裝 IceMelt」的比較表 | 高 |
| [leonardovida/icey](https://github.com/leonardovida/icey) | 14–27 | 沿用 Ice 的 bundle ID 和設定，可直接取代 Ice；Ice Bar 可只在部分螢幕出現；可指定新項目的落點；宣稱修了 150 多個 bug | 低（repo 才建立 3 天，宣稱無法驗證） |
| [EvanZhuYF/FloeBar](https://github.com/EvanZhuYF/FloeBar) | 14–26 | Ice 0.12 精簡版：每個項目記住所屬區段並主動還原；刻意拿掉搜尋省記憶體；修 Ice 在 26／Intel 上的 crash 與洩漏；首次啟動匯入 Ice 設定 | 中 |
| [AaqifZ/shelf](https://github.com/AaqifZ/shelf) | 26 | 記住每個項目的位置，漂移時一次一格 ⌘ 拖曳拉回；`shelf check` 等 CLI；可和 Ice 交接版面 | 中（1 commit） |
| [beaugunderson/tuck](https://github.com/beaugunderson/tuck)（Tuck，usetuck.com） | 15–27 | ≤26 用 SkyLight + 截圖；**27 改寫 Control Center 設定檔裡的「Allow in the Menu Bar」清單**（需要 Full Disk Access）；依選單列寬度存不同 preset；開 strip 時取樣背景色。click／move 程式碼移植自 Ice | 高 |
| [kogolar/OpenMenu](https://github.com/kogolar/OpenMenu)、[A-Moses-Varghese/Barp](https://github.com/A-Moses-Varghese/Barp) | 14+ | 換名或極簡版 Ice，沒有新東西；Barp 沒附授權 | 低 |

## B. macOS 27 allow-list（私有 `MBAssessmentModeAssertion`）

全部以 App 為單位隱藏，必須裝在 `/Applications`，機制見 [allow-list](../concepts/menubar-agent-allow-list.md)。

| Repo | 授權 | 重點 | 可信度 |
|---|---|---|---|
| [brentc22/stash](https://github.com/brentc22/stash) | MIT | 每個 App 三種狀態；「這個 App 在前景時顯示」；規則（Wi-Fi 只在斷線時出現）；Presentation mode（偵測到螢幕鏡像、Screen Sharing、Zoom 會議時只留必要圖示）；研究筆記（寬度門檻、NSSet／NSArray、`0...63` 弄壞螢幕鏡像） | 高 |
| [ronny/ellipsis](https://github.com/ronny/ellipsis) | Apache-2.0 | 免權限模式：直接在設定裡挑要藏的 App；沒有 AX 時點 bar 上的 App 只把它單獨放回選單列 | 高 |
| [chlee1001/barnook](https://github.com/chlee1001/barnook) | Apache-2.0 | ellipsis 的 fork：下方浮動 bar，點了就把該 App 暫時 pin 回選單列（最多 3 個，只讓出必要空間） | 中 |
| [MenuTidy](menutidy.md)（已讀原始碼） | Unlicense | 14–26 用 separator，27 用 allow-list；「選單列已滿」警示；點名無法保留的 App；跨線項目一律保留；瀏海右側死帶校正 `notchDrawInset` | 高 |
| [SnowDrit/Cornice](https://github.com/SnowDrit/Cornice) | GPL-3.0 | 26 不需權限，27 用 allow-list；兩條 divider 依位置自動交換角色；hover 時鐘時暫時解除；附標題列兩指手勢 snap 視窗 | 高 |
| [QiushanHuang/MBAR](https://github.com/QiushanHuang/MBAR) | GPL-3.0 | 不截圖也有圖示：從 App bundle 的圖片、`Assets.car`、Electron ASAR 抽取選單列圖示，加上 11 個 App 的 adapter | 高 |
| [iamwrm/MenuBarCompact](https://github.com/iamwrm/MenuBarCompact) | 無 | iStat Menus helper 搬到 /Applications 的相容處理；執行期從 `MBSystemItemIdentifier.allCases` 與 `Menu Extras/*.menu` 找系統項目；restriction 交接不留空窗；可匯入 Thaw 群組、Thaw 執行時暫停 | 中 |
| [william-jin-cmu/FoldBar](https://github.com/william-jin-cmu/FoldBar) | GPL-3.0 | 喚醒、解鎖、換顯示器後自動重新折疊並重試 | 中 |
| [roypadina/SmartHiddenBar](https://github.com/roypadina/SmartHiddenBar) | MIT（含 Hidden Bar 聲明） | menu mirroring；內建與外接螢幕各自的點擊模式；新 App 可自動進 Always Hidden | 中 |
| [StevenACZ/Persiana](https://github.com/StevenACZ/Persiana) | MIT | 列出「因不在 /Applications 而被強制隱藏」的 App | 中 |
| [saturdaysort/stow](https://github.com/saturdaysort/stow) | 無 | 每個 App 一個開關；README 清楚列出 allow-list 的副作用 | 中 |
| [unknown6003/flux](https://github.com/unknown6003/flux) | MIT | 存下最後一次有效的排列，AX 權限被撤銷後仍能隱藏；Arrange Mode 在真實選單列插入區段標記；另附一整套瀏海面板 | 中 |
| [kevinLay7/NookBar](https://github.com/kevinLay7/NookBar) | GPL-3.0 | 宣稱用 allow-list 加有界 divider 做到單一圖示的粒度；自己的圖示消失時放「N」後備；從系統 overflow 擷取圖示 | 低（2 天、多處寫著還沒實機驗證） |
| [Siwolmoon/Nuviloft](https://github.com/Siwolmoon/Nuviloft) | 無 | 只有 binary | 低 |

## C. macOS 27 不用 allow-list 的路線

| 路線 | Repo | 說明 | 可信度 |
|---|---|---|---|
| 系統「Allow in the Menu Bar」開關 | [Chest](chest.md)（MIT，已讀原始碼） | 直接寫系統的清單檔與選單列版面檔，用 Open panel 讓使用者授權這兩個受保護的檔案（有 Full Disk Access 就不用）；被收的圖示放進「抽屜」，點了選單在原處打開；「Refresh Menu Bar」重啟選單列讓新 App 進清單 | 中（2 commits，但有 `docs/APPROACH.md`） |
| 同上 | [Champ-KTP/Tuck](https://github.com/Champ-KTP/Tuck)（MIT） | 在背景開著 System Settings 的 Menu Bar 頁，用 AX 按每個 App 的開關；peek 約 50–100 ms | 中 |
| 有界寬度推進系統 « | [massimodascola/blinds](https://github.com/massimodascola/blinds)（MIT） | divider 設成最窄螢幕寬度的 44%：放不下、但沒寬到被丟掉，系統就把它和左邊所有項目移進 «；不需任何權限 | 高 |
| 同上 | [atilac/CleanMenuBar](https://github.com/atilac/CleanMenuBar)（MIT，Hidden Bar 衍生） | 量到「寬度達螢幕一半就被丟掉」的斷崖；用 pusher 和 arrow 兩個項目；熱鍵衝突偵測 | 高 |
| 同上 | [LarsAtassi/icon-cloak](https://github.com/LarsAtassi/icon-cloak)（MIT） | 依前景 App 的選單寬度動態填滿瀏海兩側；自繪 « 蓋掉系統的 | 中 |
| 同上 | [zzc059/LineBar](https://github.com/zzc059/LineBar)（MIT） | 收起時用截圖蓋住系統重排的動畫再淡出（約 0.5 s） | 中 |
| 蓋一層模糊 | [Itzhaik07/Tidy](https://github.com/Itzhaik07/Tidy)（MIT） | 在選單列上方疊三層 `NSVisualEffectView` 模糊掉圖示，不需 Screen Recording；只是視覺上遮住，不會騰出空間 | 中 |

## D. 舊式 separator 型（多半沒說 27 怎麼辦）

| Repo | 重點 | 可信度 |
|---|---|---|
| [nicholaspsmith/menubar-barn](https://github.com/nicholaspsmith/menubar-barn)（MPL-2.0） | 容量感知：拒絕顯示放不下的項目並說要騰出多少 pt；跨 App 的 `MenuBarYield` 讓位協定（帶 TTL）；即時讀取被藏 App 的真實選單；在 27 上自動退出 | 高 |
| [Talljack/menu-hub](https://github.com/Talljack/menu-hub)（MIT） | 從 18 個通訊 App 的 AX title 加總未讀數，畫成徽章；⌘1–9 開常用項目 | 中 |
| [whrss9527/meno](https://github.com/whrss9527/meno)（GPL-3.0） | 麥克風開啟觸發；Zen 一鍵清空 App 圖示；向下滑動或點空白處展開；Quick Open | 中 |
| [EvanProgramming/OverflowBar](https://github.com/EvanProgramming/OverflowBar)（MIT） | 系統控制項被推出畫面時自動救回；Safe Reset | 中 |
| [roeezolantz/BigMenu](https://github.com/roeezolantz/BigMenu)（MIT） | 預寫 `NSStatusItem Preferred Position` 避開 26 的瀏海死區；Apply 後用 AX 讀回驗證 | 中 |
| [masudurHimel/Valet](https://github.com/masudurHimel/Valet)（MIT） | 安全啟動：確認不會讓新圖示一啟動就被藏 | 中 |
| [fstermann/bouncer](https://github.com/fstermann/bouncer)（MIT） | 切換 App 時自動收起；沒開的功能不裝 event monitor | 中 |
| [yansircc/nanobar](https://github.com/yansircc/nanobar)（MIT） | 約 90 行 Rust | 中 |
| [stacksjs/barista](https://github.com/stacksjs/barista)（MIT） | 主要是防睡眠工具，順便隱藏圖示 | 低 |
| [james-see/taargus](https://github.com/james-see/taargus)、[rpsadarangani/OpenBartender](https://github.com/rpsadarangani/OpenBartender)、[nick318/bar-manager](https://github.com/nick318/bar-manager)、[howells/overfold](https://github.com/howells/overfold)、[bzantium/cleanbar](https://github.com/bzantium/cleanbar)、[TonmoyBishwas/Tuck](https://github.com/TonmoyBishwas/Tuck)、[NoahSmo/HiddenBar](https://github.com/NoahSmo/HiddenBar)、[mxvixxn/Stewardie](https://github.com/mxvixxn/Stewardie)、[jayjasmine/menu-bar-manager](https://github.com/jayjasmine/menu-bar-manager) | 範本式或空殼，沒有新東西 | 低 |

## E. 瀏海 overflow 取用工具（不負責隱藏）

| Repo | 重點 | 可信度 |
|---|---|---|
| [Mezzanine](mezzanine.md)（MIT，26+，已讀原始碼） | **menu mirroring**：沒畫出來的項目做 `AXPress` 會回 `kAXErrorCannotComplete`，但選單內容仍讀得到，於是自己重建 NSMenu 再轉送；AX 掃描從 2143 ms 降到約 20 ms；實測開 sandbox 後讀不到任何 extras | 高 |
| [nicglazkov/overhang](https://github.com/nicglazkov/overhang)（MIT） | 用 `CGWindowListCopyWindowInfo(.optionAll)` 零權限找出被系統丟掉的項目；預寫 Preferred Position 讓自己的圖示貼緊 Control Center | 高 |
| [joonlab/barback](https://github.com/joonlab/barback)（MIT） | 重排時用 LCS 算最少的 ⌘ 拖曳次數 | 中 |
| [benwbooth/lloyd](https://github.com/benwbooth/lloyd)（MIT） | 拖曳時隱藏游標，等確認移動完才還原；用「有沒有出現新視窗」判斷點擊是否成功 | 中 |
| [CHashtager/notch-dock](https://github.com/CHashtager/notch-dock)（MIT） | 游標移到瀏海就跳出 panel | 低 |

## F. 選單列替代品、工具集與周邊

| Repo | 說明 |
|---|---|
| [mocki-toki/barik](https://github.com/mocki-toki/barik)（MIT，518★，作者已無暇維護）、[azixxxxx/glance](https://github.com/azixxxxx/glance)（MIT，barik fork） | 自己畫一條 bar 取代系統選單列，給 yabai／AeroSpace 使用者；glance 有 islands、pills 等形狀和執行 shell 指令的 script widget。不管理別人的圖示 |
| [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils)（GPL-3.0，27k★） | 大型工具集，沒有選單列管理模組；權限頁會提醒「已授權但沒有功能在用」的權限 |
| [mactools-app/MacTools](https://github.com/mactools-app/MacTools)（GPL-3.0，1.3k★） | plugin 工具箱；把電池、Wi-Fi、音量合成一個狀態圖示；給 AI agent 用的 JSON CLI |
| [voodootikigod/herdr-bartender](https://github.com/voodootikigod/herdr-bartender)（MIT） | 把 AI coding agent 的狀態送進 **Bartender 6 Pro 的 Top Shelf**（本機 HTTP bridge）；README 說 Bartender 內建 Claude Code 與 Codex 的 hooks。見 [公開功能](../bartender/public-features.md) §11 |
| [w0lfschild/moreMenu](https://github.com/w0lfschild/moreMenu)（2018）、[kevinmbeaulieu/CleanMenuBar](https://github.com/kevinmbeaulieu/CleanMenuBar)（2016） | 舊時代用程式碼注入（MacForge、SIMBL）的做法，只有歷史意義 |
