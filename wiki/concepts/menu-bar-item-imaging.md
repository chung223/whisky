---
title: 擷取選單列項目的圖像
type: concept
tags: [imaging, screencapturekit, cgwindowlistcreateimage, skylight, screen-recording, macos-26, macos-27]
sources:
  - raw/github/readmes
  - raw/github/repos/PerpetualBeta__MenuTidy
  - raw/github/repos/brianmpollack__Mezzanine
  - raw/github/repos/boringbar__chest
  - raw/github/repos/jordanbaird__Ice
  - raw/github/repos/thaw-app__Thaw
  - raw/github/repos/frostbar__frost
  - raw/github/repos/junior-rj__menubar-hide
  - raw/github/repos/FelixKratz__SketchyBar
  - raw/github/repos/sane-apps__SaneBar
  - raw/github/repos/dwarvesf__hidden
  - raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md
  - raw/github/repos/fif7y__pelmet
updated: 2026-10-16
---

# 擷取選單列項目的圖像

要在「獨立的 bar／panel」（Ice Bar、Thaw Bar、Frost Bar、Bartender Bar）或 layout 編輯器裡畫出別人 item 的樣子，只有兩個選擇：
**擷取它的像素**（需要 Screen Recording），或**畫它所屬 app 的 icon**（不需權限，但認不出是哪個 item）。

## 難點

被藏起來的 item 在螢幕外（x 為負）或在瀏海後面，而公開 API 大多只能擷取「螢幕上」的東西：

- `CGWindowListCreateImage`／`CGWindowListCreateImageFromArray`：macOS 14 deprecated，**macOS 15 SDK 起 obsoleted**（無法編譯，見
  `raw/articles/2026-10-12-apple-developer-docs-menu-bar-apis.md`）；macOS 15 起使用會觸發系統隱私提示。
- ScreenCaptureKit：擷取螢幕外 window 回 `-3811`（[MenubarHide](../projects/menubarhide.md) `MenubarHide/ItemCapturer.swift:38-40`；[Frost](../projects/frost.md)
  `docs/macos-behavior.md:119-124`）。
- macOS 27：MenuBarAgent 的 window 不在 `SCShareableContent` 裡，也沒有 per-item window（Frost 表格「Capturing icons」）。

## 手法比較

| 專案 | API | 怎麼處理螢幕外 item | file:line |
|---|---|---|---|
| [Ice](../projects/ice.md) | `CGImage(windowListFromArrayScreenBounds:…)`（deprecated），整排合成再裁切 | 這個舊 API 可擷取螢幕外 window | `Ice/Utilities/ScreenCapture.swift:63-99`；`MenuBarItemImageCache.swift:102-190` |
| [Thaw](../projects/thaw.md) | 可見：ScreenCaptureKit；隱藏：私有 `SLWindowListCreateImageFromArray`（`dlsym` SkyLight） | 私有 API 可擷取螢幕外；因每次呼叫漏記憶體，放進可回收的 `MenuBarCaptureService.xpc` | `Shared/Bridging/Shims.swift:173-205`；`Bridging.swift:516-561`, `:655-700`；`docs/ARCHITECTURE.md` |
| [SketchyBar](../projects/sketchybar.md) | 私有 `SLSCaptureWindowsContentsToRectWithOptions(…, 1<<8, …)` | 1 Hz 輪詢 | `src/window.c:372-403` |
| [MenubarHide](../projects/menubarhide.md) | 先 `CGWindowListCreateImage`，再 SCK `desktopIndependentWindow` | **flash-expand**：展開 300 ms → 擷取 → 收合 | `ItemCapturer.swift:27-78`；`StatusBarController.swift:383-401` |
| [Frost](../projects/frost.md)（26） | SCK `SCContentFilter(display:including:)` 批次 | **freeze frame**：先拍選單列快照蓋在 level 26 的 click-through window 上，底下偷偷展開擷取；瀏海後 item 則在使用者閒置時一次一個移出、擷取、移回 | `FrostCore/Capture/ItemImageCapturer.swift:532-560`；`Frost/FrostBar/MenuBarFreezeFrame.swift:54`, `:110-128`；`FrostBarController+ObscuredCapture.swift:136-275` |
| [Frost](../projects/frost.md)（27） | 擷取整個 display 的選單列條帶 | 每個 item 的範圍做逐欄背景減法，把 glyph 變成 alpha；只能拍到「當下畫在 bar 上」的 item | `ItemImageCapturer.swift:470-516`；`StripGlyphExtraction.swift:20-26` |
| [SaneBar](../projects/sanebar.md) | 不擷取 | 畫 `NSRunningApplication.icon`，Apple extras 用 SF Symbol | `Core/Models/RunningApp.swift:194-221`, `:486-505` |
| [Hidden Bar](../projects/hidden-bar.md) | 不擷取 | Notch Overflow 選單用 app icon 18×18 | `NotchOverflowController.swift:188-213` |
| [Pelmet](../projects/pelmet.md)（27，v0.3.1） | 編輯器與搜尋不擷取：app icon、系統 item 用 SF Symbol；Screen Recording 只用來拍整條選單列（`SCStream` 取一幀，`SCContentFilter(display:excludingWindows:)`）當動畫 cover | 不處理：隱藏的 item 沒有圖。曾用 SCK 裁切共用的 "Menubar" window，因非作用中 display 的 bar 褪色、瀏海遮擋、tag 對不上而在 2026-08-21 移除 | `Pelmet/Editor/ItemImageCache.swift:1-7`, `:36-60`；`Pelmet/StatusItem/ConcealGhostOverlay.swift:1-9`, `:394-438` |

補充：

- 選項 `[.boundsIgnoreFraming, .bestResolution]`（Ice、MenubarHide）。
- 合成擷取後依 `backingScaleFactor` 換算 frame 裁切；寬度對不上就逐個擷取（Ice `:135-187`）。SCK 會挑 frame 交集最大的 display 的 scale，
  要以實際影像為準（Thaw `MenuBarItemImageCache+Capture.swift:158-194`）。
- 沒有權限時退回 app icon：Thaw、Frost、IceMelt 都這樣做，避免 layout 頁空白（Ice 的 Tahoe issue #744、#716 就是空白）。
- 外觀 tint 也需要擷取：Ice 擷取桌布 window 在選單列範圍的影像來畫自訂形狀（`MenuBarOverlayPanel.swift:296-303`），Thaw 從桌布取主色做 adaptive tint。
- 圖像變化可當訊號：Thaw 用「icon 變化／閃爍」當 trigger（README Triggers）。
- **截圖當 cover 蓋住系統動畫**（[Pelmet](../projects/pelmet.md)）：macOS 27 的 MenuBarAgent 每次 allow-list swap 都有無法關閉的動畫（reveal 滑入、
  conceal 原地淡出），Pelmet 先拍「空 bar」與「有 icon 的 bar」兩張圖，在系統動畫上播放自己的 Instant／Smooth／Fade（`ConcealGhostOverlay.swift:1-9`）。
  實測 `SCScreenshotManager` 的靜態截圖缺少 key window 投到 bar 底部的陰影，蓋上去會有色差（+4 luma），所以改用 `SCStream` 取一幀（約 90 ms，
  要預先拍好；`:425-438`）；每次擷取都會讓錄影指示亮起並使右側 icon 位移約 16 pt 約 3 s（`docs/ARCHITECTURE-REVIEW.md:82`）。
- 【待確認】Frost 說 27 上 MenuBarAgent 的 window 不在 `SCShareableContent` 裡；Pelmet 的註解則說早期曾「裁切共用的 "Menubar" window」
  （`ItemImageCache.swift:4-7`，2026-08-21 前、27 beta 期間）。可能是 beta 間的差異，Whisky 要自己實測。
- Pelmet 0.3.2-beta（`panel` 分支，不在 clone 內）加入把隱藏 icon 顯示在 bar 下方 panel 的「Picture pass」，被 « 收起的 item 退回 app icon
  （GitHub release v0.3.2-beta.4）。

## 不擷取畫面的圖示來源與 ScreenCaptureKit 補充（2026-10-14）

- **從 App bundle 靜態抽取**：搜尋一般圖片、編譯過的 `Assets.car` 和 Electron ASAR，再加上 11 個 App 的 adapter（Tailscale、Docker Desktop…）。
  作者實測 20 個 App 中「至少有一個候選圖」的從 4 個增加到 15 個；候選不明確時不自動採用，讓使用者比較（[MBAR](../../raw/github/readmes/QiushanHuang__MBAR.md)）。
  缺點：圖示是靜態的，CPU、網速這類數字圖示不會更新。
- **App 內附的選單 glyph**：MenuBarCompact 的 panel 用 bundle 內附的 menu glyph，不截圖（[MenuBarCompact](../../raw/github/readmes/iamwrm__MenuBarCompact.md)）。
- **從系統 « 擷取**：短暫展開系統的 overflow，擷取真實圖示再收回；擷取期間位置有變就作廢（[NookBar](../../raw/github/readmes/kevinLay7__NookBar.md)，未驗證）。
- **背景色取樣**：開 strip 時先取樣選單列背景色，讓白色 glyph 在淺色背景上仍看得清楚（[Tuck](../../raw/github/readmes/beaugunderson__tuck.md)）。
- **警告**：用 ScreenCaptureKit 的 live stream 會讓紫色螢幕分享 pill 出現在選單列裡，而且無法排除（[Tidy](../../raw/github/readmes/Itzhaik07__Tidy.md) `:26`）。只用單張擷取。
- **用截圖蓋住動畫**：收起時先擷取選單列，蓋住系統重排時圖示滑動的中間幀再淡出，約 0.5 s（[LineBar](../../raw/github/readmes/zzc059__LineBar.md)）。

以上出自 README；以下出自 [Mezzanine](../projects/mezzanine.md) 原始碼與 `NOTES.md`（【作者稱】）：

- **沒畫出來的 item 仍有活的 backing store**：26 上被瀏海擠掉、`onscreen = false` 的 item，`SCScreenshotManager.captureImage` 搭配 `SCContentFilter(desktopIndependentWindow:)` 仍擷取得到（`NOTES.md:56-59`）。
  注意這是「座標在螢幕內但沒被合成」的情況；被分隔線推到螢幕外的 item 仍會回 `-3811`（本頁「難點」）。
- 【矛盾】【觀察】Whisky 在 26.7 實測（2026-10-16）：分隔項目展開（10000 pt）時，被推到螢幕外的 24 個項目用 `SCContentFilter(desktopIndependentWindow:)` 擷取，23 個成功，只有 1 個一直回「音訊/影片擷取失敗」。
  一輪 0.31–0.35 秒（[實測](platform-verification.md)）。和 MenubarHide、Frost 說的 `-3811` 不同，可能跟 OS 版本或擷取設定有關，未查明。
- **AX 不提供任何圖像**：status item 有 43 個屬性，沒有一個和圖片有關（`NOTES.md:53-54`）。
- **App 內附圖檔的限制**：Docker 有 13 張狀態圖、選哪張要看不到的內部狀態；Bitwarden 的圖在 `app.asar`；「鯨魚加更新徽章」是繪製時才合成的（`NOTES.md:61-65`）。
  所以 MBAR 式的靜態抽取只能當「沒有 Screen Recording 時比 App icon 好一點」的退路。
- **配對**：CGWindowList 讀 layer 25 視窗的 bounds 不需要錄影權限；AX 元素和視窗的中心 x 完全對齊，以 4 pt 為容差配對（`GlyphCapture.swift:57-86`）。
- **只在 panel 打開時擷取**：連續擷取會讓錄影指示一直亮（`NOTES.md:436-437`）。

## 對 Whisky 的建議

1. 預設不要求 Screen Recording：先畫 app icon（SaneBar 路線），使用者授權後再升級為真實圖像。
2. macOS 26：可見 item 用 SCK；隱藏 item 選一個——(a) Frost 的 freeze frame + 暫時展開（公開 API，但會有約 0.2 s 的凍結畫面），或
   (b) Thaw 的私有 `SLWindowListCreateImageFromArray`（放隔離 process）。
3. macOS 27：只能拍選單列條帶，被 allow-list 藏起來的 item 根本沒畫出來 → 無法擷取，只能用快取的舊圖或 app icon。
4. 擷取一律走背景 actor，並對每個 item 設失敗次數上限（Thaw `recordCaptureFailure`）。
5. 若要遮掉 macOS 27 allow-list swap 的系統動畫，可參考 Pelmet 的「預拍整條 bar → 疊圖」作法；不想要求 Screen Recording 就直接接受系統動畫。
