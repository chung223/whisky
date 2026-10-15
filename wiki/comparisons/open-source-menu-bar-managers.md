---
title: 開源選單列管理工具比較
type: comparison
tags: [comparison, open-source, menu-bar-manager, license, macos-26, macos-27]
sources:
  - wiki/projects/long-tail.md
  - wiki/comparisons/feature-ideas.md
  - raw/github/manifest.md
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/dwarvesf__hidden
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/frostbar__frost
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/happy666End__MenuBarHider
  - raw/github/repos/FelixKratz__SketchyBar
  - raw/github/repos/fif7y__pelmet
  - https://github.com/Mortennn/Dozer
  - https://github.com/pnikolaidis/icemelt
  - https://github.com/mocki-toki/barik
  - https://badgeify.app/macos-27-golden-gate-menu-bar-changes/
updated: 2026-10-14
---

# 開源選單列管理工具比較

資料日期 2026-10-12（stars 與活動來自 `gh api`；機制來自 `raw/github/repos/` 的原始碼，見各專案頁）。
背景：macOS 26 Tahoe 把所有 status item window 改歸 Control Center；macOS 27 把整條選單列改成 MenuBarAgent 畫的單一 window，
2026-06 的 27 beta 1 讓 Bartender、Ice、Thaw、Hidden Bar、SaneBar 等**全部失效**（Ice [#954](https://github.com/jordanbaird/Ice/issues/954)；
[Badgeify 文章](https://badgeify.app/macos-27-golden-gate-menu-bar-changes/)）。之後只有部分專案找到新做法。

另外 58 個較小的專案（只讀 README）整理在 [其他同類專案](../projects/long-tail.md)，特別的功能整理在 [功能點子庫](feature-ideas.md)。

2026-10-14 再 clone 三個並讀了原始碼（不在下表）：

| 專案 | 授權 | 支援 | 隱藏機制 | 對 Whisky 最有價值的地方 |
|---|---|---|---|---|
| [Chest](../projects/chest.md) | MIT | 27 | 改寫系統「Allow in the Menu Bar」清單，不用私有 API | 沒有 allow-list 副作用；不合成拖曳就能排序；抽屜裡的 menu mirroring |
| [Mezzanine](../projects/mezzanine.md) | MIT | 26 | 不隱藏，只取用瀏海溢出的 item | menu mirroring、AX 掃描最佳化、`NOTES.md` 的平台觀察 |
| [MenuTidy](../projects/menutidy.md) | Unlicense | 14–27 | 14–26 撐開 spacer；27 用 allow-list，assertion 放在 holder 子程序 | holder 模式、選單列已滿偵測、AX 快照處理規則；public domain 可直接複製 |

## 基本資料

| 專案 | 授權 | 語言 | Stars | 最近活動 | 最低 macOS | macOS 26 | macOS 27 |
|---|---|---|---|---|---|---|---|
| [Ice](../projects/ice.md) | GPL-3.0 | Swift | 29.8k | 停滯（最後實質更新 2025-09 dev 版） | 14 | ⚠️ 多處壞（列舉、Ice Bar、crash） | ❌ |
| [Thaw](../projects/thaw.md) | GPL-3.0（27 核心閉源） | Swift | 12.0k | 極活躍（2026-10-12） | 26 | ✅ 主要目標 | ✅ alpha（閉源 PlatformRuntimeKit） |
| [Hidden Bar](../projects/hidden-bar.md) | MIT | Swift | 15.2k | 活躍（v1.11.1，2026-09） | 13 | ✅ | ✅ 直接下載版（私有 allow-list）；App Store 版 ❌ |
| [SaneBar](../projects/sanebar.md) | MIT（曾為 GPL／PolyForm） | Swift | 324 | 已 sunset（2026-09 最後 commit） | 14 | ✅ | ❌ 放棄 |
| [Frost](../projects/frost.md) | MIT | Swift 6 | 27 | 極活躍（v0.4.1，2026-10-10） | 26 | ✅ | ✅（公開 API 路線，功能受限） |
| [MenubarHide](../projects/menubarhide.md) | MIT | Swift 6 | 53 | 活躍（2026-10） | 14 | ✅ | ✅ 只剩 sideways 隱藏 |
| [MenuBarHider](../projects/menubarhider.md) | MIT | Swift | 178 | 新（2026-09／10） | 27 | — | ✅ 唯一目標（私有 allow-list） |
| [Pelmet](../projects/pelmet.md) | GPL-3.0（+ CLA） | Swift 6 | 840 | 極活躍（v0.3.1 2026-10-05；0.3.2-beta.4 2026-10-12） | 27 | — | ✅ 唯一目標（私有 allow-list，含系統 icon） |
| [SketchyBar](../projects/sketchybar.md) | GPL-3.0 | C／ObjC | 12.5k | 活躍（v2.24.1，2026-10-09） | 11 | ✅（自己的 bar） | ✅ bar；alias【推論】❌ |
| [Dozer](../projects/dozer.md) | MPL-2.0 | Swift | 8.7k | 停止維護（2022） | 10.13 | 未知 | ❌（原理失效） |

## 功能 × 專案

圖例：✅ 有；◐ 部分／有條件；— 無。

| 功能 | Ice | Thaw | Hidden Bar | SaneBar | Frost | MenubarHide | MenuBarHider | SketchyBar |
|---|---|---|---|---|---|---|---|---|
| 隱藏（分隔線） | ✅ 10,000 pt | ✅ 10,000 + spacer | ✅ ≤ 26 | ✅ 10,000 | ✅ 26；27 有界寬度 | ✅ 26；27 sub-cliff | — | — |
| 隱藏（27 allow-list） | — | ✅（閉源） | ✅ | — | — | — | ✅ | — |
| Always-hidden 區 | ✅ | ✅ | ◐ | ✅ | ✅ | — | ◐（兩分隔線） | — |
| 移動／排列別人的 item | ✅ 0x33 瞬移 | ✅ 多策略 | — | ✅ 公開真實拖曳 | ✅ 26 瞬移／27 真實拖曳 | ◐ 改 preferences | — | — |
| 獨立 bar／panel | ✅ Ice Bar | ✅ Thaw Bar | ◐ Notch Overflow 選單 | ✅ 第二選單列 | ✅ Frost Bar | ✅ Panel（≤ 26） | — | ◐ alias（只顯示） |
| 真實 item 圖像 | ✅ | ✅ | — | — | ✅ | ✅（≤ 26） | — | ✅ |
| 點擊轉送 | ✅ temp-show | ✅ AXPress + temp-show | ✅ AXPress | ✅ AXPress + 展開 | ✅（27 只左鍵） | ✅ 合成點擊 | — | — |
| 搜尋 | ✅ | ✅ | — | ✅ | — | — | — | — |
| hover／空白處點擊／scroll 顯示 | ✅ | ✅ | ◐ hover | ✅ | ◐ 點擊 | — | — | — |
| 自動收回 | ✅ 三策略 | ✅ | ✅ | ✅ | ✅ | ◐ | ✅ | — |
| 全域 hotkey | ✅ Carbon | ✅ Carbon | ✅ HotKey | ✅ KeyboardShortcuts | — | ✅ 固定 ⌃⌥H | — | — |
| Profiles | — | ✅ 綁 display／Space／Focus | — | ✅ | — | — | — | — |
| Triggers | — | ✅ 十多種 | — | ✅ | — | — | — | ◐（事件腳本） |
| 外觀（tint／形狀） | ✅ | ✅ | — | ✅ Liquid Glass | — | — | — | ✅（自己的 bar） |
| Item spacing | ✅ | ✅ beta | — | ✅ | — | ✅ | — | — |
| 瀏海處理 | ✅ Ice Bar | ✅ overflow rebalance | ✅ Notch Overflow | ◐ | ✅ 背景擷取 | ✅ Panel | — | ✅ notch_width |
| 多螢幕 | ◐ | ✅ | ◐ | ✅ | ✅ 26（replica 處理） | ✅ | — 未測 | ✅ |
| AppleScript／URL scheme | — | ✅ `thaw://` | — | ✅ ~30 指令 | — | — | — | ✅ CLI |
| 需要的權限 | AX（必要）＋ SR | AX（必要）＋ SR | AX（27） | AX | AX（排列／bar）＋ SR | 皆選用 | AX | SR（alias） |
| 私有 API | CGS 多個 | CGS、SkyLight、閉源 27 | MenuBarClientCore | 無 | 只有 SetsCursorInBackground | 無 | MenuBarClientCore、CoreMenuExtra | SLS ~70 個 |

[Pelmet](../projects/pelmet.md)（2026-10-12 加入，v0.3.1；上表沒有加欄，逐列對照如下）：

| 功能 | Pelmet |
|---|---|
| 隱藏（分隔線）／（27 allow-list） | —／✅ 唯一方式，**含系統 icon**（battery、Wi-Fi、音量…，Control Center 與 Clock 可藏不可移） |
| Always-hidden 區 | ✅（自己的 item 由每區段一個 helper app host） |
| 移動／排列別人的 item | ✅ 27 HID 真實 ⌘-drag + drag shield，**只在按 Apply 時** |
| 獨立 bar／panel | — （0.3.2-beta 的 `panel` 分支才有） |
| 真實 item 圖像 | —（編輯器用 app icon；SR 只拍整條 bar 做動畫 cover） |
| 點擊轉送 | ✅ 單一 bundle 暫加回 allow-list + HID 點擊（刻意不用 AXPress） |
| 搜尋 | ✅ ⌥⌘K（0.3.1） |
| hover／空白處點擊／scroll 顯示 | ◐ hover、點擊（無 scroll） |
| 自動收回 | ✅ |
| 全域 hotkey | ✅ Carbon |
| Profiles／Triggers | ◐ 只有 per-display 行為 |
| 外觀（tint／形狀） | — |
| Item spacing | ✅（並重啟 MenuBarAgent） |
| 瀏海處理 | ◐ Apply 時展開系統 « 再移動 |
| 多螢幕 | ✅ per-display 行為；layout 全域 |
| AppleScript／URL scheme | — |
| 需要的權限 | AX（必要）＋ SR（選用） |
| 私有 API | MenuBarClientCore、CoreMenuExtra（SystemUIPlugin）、SiriFoundation、login.framework、SetsCursorInBackground、`com.apple.MenuBarAgent` defaults |

（AX = Accessibility，SR = Screen Recording。機制細節見概念頁：[status-item-hiding](../concepts/status-item-hiding.md)、
[menu-bar-item-enumeration](../concepts/menu-bar-item-enumeration.md)、[menu-bar-item-moving](../concepts/menu-bar-item-moving.md)、
[menu-bar-item-imaging](../concepts/menu-bar-item-imaging.md)、[menu-bar-item-activation](../concepts/menu-bar-item-activation.md)、
[menubar-agent-allow-list](../concepts/menubar-agent-allow-list.md)、[private-apis](../concepts/private-apis.md)、[permissions](../concepts/permissions.md)、
[notch-and-displays](../concepts/notch-and-displays.md)、[reveal-and-rehide](../concepts/reveal-and-rehide.md)、[menu-bar-appearance](../concepts/menu-bar-appearance.md)。）

## 其他候選（未 clone）

| 專案 | 授權 | 備註 |
|---|---|---|
| [fif7y/pelmet](https://github.com/fif7y/pelmet) | GPL-3.0 | 840 stars（2026-08 建立，2026-10-12 仍更新）；專為 macOS 27，README 明言用 `MenuBarClientCore` 的 assessment-mode 機制隱藏，其餘（位置、點擊、預覽）用 Accessibility 與 ScreenCaptureKit；連 Sound、Battery 等系統 icon 都能藏，Clock／Control Center 鎖定；瀏海後的 icon 透過系統 `«` 打開再移動。值得下一輪 clone 研究（只讀，GPL） |
| [brentc22/stash](https://github.com/brentc22/stash) | MIT | 3 stars；「built on the assessment-mode allowlist」的 macOS 27 hider |
| [pnikolaidis/icemelt](https://github.com/pnikolaidis/icemelt) | GPL-3.0 | Ice 的 Tahoe fork（33 stars，v2026.4.0 於 2026-10-06，已宣布支援 27）。README：用 `AXExtrasMenuBar` 走訪對應 window ID 解決 Control Center 擁有權；沒有 Screen Recording 時退回 app icon；只支援 26+ |
| leonardovida/icey、wakmail/Hoarfrost、kempu/Twice、kogolar/OpenMenu | GPL-3.0 | 其他 Ice／Thaw fork，規模小 |
| SnowDrit/Cornice、william-jin-cmu/FoldBar、Kodak2383/BarT、whrss9527/meno | GPL-3.0 | 2026 新出現的小型 26／27 管理工具 |
| EvanProgramming/OverflowBar、benwbooth/lloyd、howells/overfold、bylaaabs/baaar（Apache-2.0） | MIT／Apache | 小型；lloyd 專攻瀏海後的 icon |
| [mocki-toki/barik](https://github.com/mocki-toki/barik) | MIT | 518 stars；給 yabai／AeroSpace 用的選單列**替代品**（macOS 14.6+），README 已掛「沒空維護」公告；不管理別人的 item |
| 函式庫與瀏海 app | MIT／GPL | 見 [supporting-libraries](../projects/supporting-libraries.md)、[notch-apps](../projects/notch-apps.md) |

註（2026-10-12）：fif7y/pelmet 已 clone，見 [Pelmet](../projects/pelmet.md)。依原始碼更正上表兩處描述：(1)「Clock／Control Center 鎖定」是**位置鎖定**，
兩者都能經 allow-list 隱藏（`raw/github/repos/fif7y__pelmet/Packages/PelmetCore/Sources/PelmetCore/MenuBarPolicy.swift:54-58`, `:83-91`；`docs/FAQ.md:64-67`）；
(2) v0.3.1 的預覽只用 app icon，ScreenCaptureKit 只用來拍整條選單列做動畫 cover（`Pelmet/Editor/ItemImageCache.swift:1-7`）。

## 給 Whisky 的最佳起點（尊重授權）

**結論：不要 fork 任何一個專案；以 MIT 專案為主要參考與可引用來源，GPL 專案只學「機制」，自己寫程式碼。**

1. **架構骨架學 [Frost](../projects/frost.md)（MIT）**：純 core package（Scanning／Moving／Capture／Layout）＋ app 層；啟動時依 OS 選 backend
   （26 = window list、27 = accessibility）；`docs/macos-behavior.md` 是目前最完整的 26／27 行為實測，可直接當 Whisky 的平台規格來源。
2. **macOS 27 真正隱藏學 [Hidden Bar](../projects/hidden-bar.md) 與 [MenuBarHider](../projects/menubarhider.md)（MIT）**：`MBAssessmentModeAssertion`
   allow-list 的探測、生命週期與失敗即恢復；MenuBarHider 另示範 `CoreMenuExtra*` 與通知中心例外。用 [menubar-agent-allow-list](../concepts/menubar-agent-allow-list.md)
   當實作規格。
3. **功能廣度與「零私有 API」安全模式學 [SaneBar](../projects/sanebar.md)（MIT）**：AX-first 列舉、公開 CGEvent 真實拖曳、AXPress 點擊與驗證、
   KeyboardShortcuts、profiles／triggers／AppleScript。因授權史曾是 GPL，只取概念與小片段，避免大段搬運。
4. **macOS 26 的進階技巧學 [Thaw](../projects/thaw.md)／[Ice](../projects/ice.md)（GPL-3.0，只讀不抄）**：0x33 window-ID 路由、事件送給
   Control Center PID、`SourcePIDCache` 式的 AX 擁有者反查與 XPC 隔離、SkyLight 螢幕外擷取與記憶體洩漏隔離、notch overflow 自動平衡。
   這些是「事實與 API 名稱」，可以用自己的話記在 wiki、再獨立實作；不得複製任何程式碼。**不得碰 Thaw 的閉源 PlatformRuntimeKit**（授權禁止逆向）。
5. **依賴**：KeyboardShortcuts（hotkey）、Sparkle 2（更新）、`SMAppService`（login item）、自寫 AX 薄包裝；全部 MIT。
6. **支援範圍建議**：只支援 macOS 26 與 27（IceMelt、Thaw、Frost 都這樣取捨），避免 14／15／26／27 四套行為矩陣；以 Developer ID + notarization
   發布，不上 App Store（私有 API 與非 sandbox 的必然結果）。
7. **macOS 27 allow-list 的完整行為清單學 [Pelmet](../projects/pelmet.md)（GPL-3.0，只讀不抄）**：系統 icon 的個別隱藏、新 item 的 adoption window、
   collateral extras、clock／通知中心 blink、每區段一個 helper app、MenuBarAgent AX tree 列舉、drag shield，以及「sets, not positions」（只在使用者
   按 Apply 時移動）的產品原則。程式碼請以 MIT 的 Hidden Bar／MenuBarHider 為底自己寫。

## 尚未解決的問題

- 27 上「不移動游標、不展開選單列」就能重排 item 的 MenuBarAgent 介面：Bartender 與 Thaw 已有，但都閉源（【未知】）。
- `MBAssessmentModeAssertion` 是否會與 macOS 27 公開的 Automatic Assessment Configuration（可控制 Menu Bar）衝突，Apple 是否會在 27.x 加 entitlement 檢查。
- 27 上被 allow-list 藏起的 item 能否擷取圖像（目前看來不能，只能用快取或 app icon）。
- （Pelmet 帶出的新問題）Pelmet 實測 MenuBarAgent 的 `TrailingItemPreferredPositions` 對 live item 無效、送給 pid／session 的 ⌘-drag 不會重排，和社群對
  Thaw 3「preferred-position writes、不碰游標」的描述矛盾；27 上逐 app `AXExtrasMenuBar` 的 frame 是否可信（Pelmet 說在螢幕外）也待實測。
- 新註冊 item 在 assertion 生效時被 park 的問題，Hidden Bar／MenuBarHider 是否也會遇到（它們的 swap 也是無縫的）【未知】。
