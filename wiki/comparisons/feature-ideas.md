---
title: 功能點子庫
type: comparison
tags: [features, ideas, open-source, macos-27, whisky]
sources:
  - wiki/projects/long-tail.md
  - wiki/comparisons/open-source-menu-bar-managers.md
  - wiki/bartender/public-features.md
  - raw/github/readmes
updated: 2026-10-14
---

# 功能點子庫

從 [其他同類專案](../projects/long-tail.md)（README；其中 [Chest](../projects/chest.md)、[Mezzanine](../projects/mezzanine.md)、[MenuTidy](../projects/menutidy.md) 已讀原始碼）、[已 clone 的 9 個專案](open-source-menu-bar-managers.md) 和
[Bartender 公開功能](../bartender/public-features.md) 整理出的功能點子。基本功能（三區段、hover 顯示、自動收回、熱鍵、搜尋、
profiles、triggers）已在比較表裡，這裡只收比較特別的。

**除了上述三個，長尾專案的點子都只根據 README，沒有驗證過。**

「對 Whisky」欄：**採用**＝建議放進 [路線圖](../synthesis/roadmap.md)；**考慮**＝值得做 spike 驗證；**略過**＝不符合範圍或風險太高。

## 1. macOS 27 隱藏的其他路線

| 點子 | 出處 | 說明 | 對 Whisky |
|---|---|---|---|
| 改用系統的「Allow in the Menu Bar」開關 | Chest、Champ-KTP/Tuck、Tuck（usetuck） | 用 Apple 自己的 per-app 開關隱藏，沒有 allow-list 的副作用（Focus、相機／麥克風指示消失，時鐘打不開通知中心，/Applications 以外的 App 被藏）。Chest 直接寫清單檔，Tuck 用 AX 操作 System Settings | **考慮**：格式已從 [Chest](../projects/chest.md) 原始碼得知；授權流程、race 與 crash 後的還原要在 M0 的 S6 實測（[隱藏手法](../concepts/status-item-hiding.md) §5.1） |
| 有界寬度把項目推進系統 « | Blinds（44%）、CleanMenuBar（半寬斷崖）、IceMelt、IconCloak | 只用公開 API、不需權限；被藏的項目仍能從系統 « 叫出來 | **採用**為 27 的降級路線（取代原本 Frost 式 ≤ 600 pt 的設定） |
| 蓋一層模糊視窗 | Tidy | 只遮住、不騰出空間 | 略過 |
| assertion 放在可被殺掉的子程序 | [MenuTidy](../projects/menutidy.md) | 作者實測同一個程序 `invalidate()` 後通知中心仍打不開；子程序也隔離了私有 API 的崩潰 | **採用**（M5），依 S4 結果 |

## 2. 不顯示也能使用被藏的項目

| 點子 | 出處 | 說明 | 對 Whisky |
|---|---|---|---|
| Menu mirroring | Mezzanine、SmartHiddenBar、Barn | 用 AX 讀出被藏項目的選單，在自己的位置重建 NSMenu，選了再轉送回去。完全不用暫時顯示或移動原圖示 | **採用**（M4）：Whisky Bar 和搜尋的首選開啟方式；只接受真實點擊的 App 才退回暫時顯示（Barn 的做法） |
| 單獨顯示 | Ellipsis | 沒有 AX 時，只把那一個 App 放回選單列讓使用者自己點 | 採用為 27 上沒有 AX 時的退路 |
| 暫時 pin | BarNook | 點了就把 App 暫時加回選單列，最多 3 個，只讓出必要空間 | 考慮 |

## 3. 診斷與「絕不弄丟圖示」

| 點子 | 出處 | 說明 | 對 Whisky |
|---|---|---|---|
| 選單列已滿警示 | MenuTidy | 系統 « 出現時從瀏海垂下提示；點名因不在 /Applications 而留不住的 App | **採用**（M5） |
| 容量感知 | Barn | 拒絕顯示放不下的項目並說要騰出多少 pt；警告本身就是修復按鈕 | **採用**（M4） |
| 零權限找出被系統丟掉的項目 | overhang | `CGWindowListCopyWindowInfo(.optionAll)` 的 layer 25 視窗含被丟掉的項目，幾何正確 | 考慮：26 上做 M2 的輔助來源，要實測 |
| 列出被強制隱藏的 App | Persiana、MenuTidy | 不在 /Applications 的 App 在 27 上一律被藏 | **採用**（M5） |
| 安全啟動、系統控制項救回 | Valet、OverflowBar | 啟動時確認不會把新圖示或 Wi-Fi、時鐘藏起來；提供 Safe Reset | **採用**（M1）：符合 fail-open 原則 |
| 自己的圖示消失時的後備 | NookBar | 在空位放一個可點的「N」，找不到空位就全部還原 | 考慮 |

## 4. 情境規則（Triggers）

| 點子 | 出處 | 對 Whisky |
|---|---|---|
| Presentation mode：偵測到螢幕鏡像、Screen Sharing、Zoom 會議時只留必要圖示 | Stash | **採用**（M6） |
| 這個 App 在前景時顯示它的圖示 | Stash；Bartender 的 App trigger 已有 | **採用**（M6） |
| 狀態條件：Wi-Fi 只在斷線時出現 | Stash；Bartender 的 Wi-Fi trigger 已有（[公開功能](../bartender/public-features.md) §9） | **採用**（M6） |
| 麥克風開啟時觸發；Zen 一鍵清空 | Meno | 採用（M6） |
| 切換 App 時收起 | Bouncer | 採用為自動收回的選項之一 |
| 喚醒、解鎖、換顯示器後重新套用並重試 | FoldBar、NookBar | **採用**（M1／M5）：屬於穩定性必要項目 |
| 依選單列寬度（＝目前螢幕組合）自動切換 preset | Tuck（usetuck） | 採用（M6），比綁 display ID 直觀 |
| 內建與外接螢幕各自的點擊行為 | SmartHiddenBar | 考慮 |

## 5. 圖示來源（不需要 Screen Recording）

| 點子 | 出處 | 對 Whisky |
|---|---|---|
| 從 App bundle 抽取選單列圖示（一般圖片、`Assets.car`、Electron ASAR），加上 per-app adapter，不確定時讓使用者選 | MBAR | **考慮**：能讓預設的 App icon 退路好看很多 |
| 短暫展開系統 « 擷取真實圖示 | NookBar | 考慮（需要 Screen Recording） |
| 取樣選單列背景色，讓白色 glyph 在 bar 上看得清楚 | Tuck（usetuck） | 採用（M4） |
| 警告：ScreenCaptureKit 的 live stream 會讓紫色分享 pill 出現在選單列 | Tidy | 只用單張擷取，不用 stream |

## 6. 外觀與動畫

| 點子 | 出處 | 對 Whisky |
|---|---|---|
| 收起時用截圖蓋住系統重排的動畫再淡出 | LineBar；Pelmet 有類似做法 | 考慮（需要 Screen Recording，設為選用） |
| 兩條 divider 依位置自動交換角色，設定永遠和畫面一致 | Cornice | **採用**（M1） |
| 按住 Preview 試看淺色／深色外觀 | NookBar | 延後（外觀功能本來就延後） |

## 7. 整合與共存

| 點子 | 出處 | 對 Whisky |
|---|---|---|
| 匯入 Ice／Thaw 的設定，或和它們交接、在它們執行時暫停 | FloeBar、MenuBarCompact、shelf | **採用**（M7）：使用者從 Ice、Thaw 換過來的門檻最低 |
| 跨 App 讓位協定（帶 TTL） | Barn `MenuBarYield` | 略過（需要其他 App 配合） |
| 通訊 App 未讀數加總徽章 | Menu Hub | 考慮：只在項目被藏時才有意義，可放進 Whisky Bar |
| 把電池、Wi-Fi、音量合成一個圖示 | MacTools | 略過（屬於替身 item，和 Pelmet 同類，延後） |
| AI agent 狀態看板 | Bartender 6 Pro Top Shelf；herdr-bartender 透過它的本機 HTTP bridge 送狀態 | 略過，但記為競品動向（[公開功能](../bartender/public-features.md) §11） |
| iStat Menus helper 搬到 /Applications 的相容處理 | MenuBarCompact | 考慮：27 上第三方 helper 被藏時給使用者指引即可，不要自動改別人的 LaunchAgent |

## 8. 開發與測試工具

這些不是使用者功能，但可以直接用在 Whisky 的開發流程（[架構](../synthesis/whisky-architecture.md) §9）。

- **用 signal 和 CLI 控制 App**：BigMenu、CleanMenuBar、Champ-KTP/Tuck 用 `kill -USR1/-USR2` 切換狀態或傾印狀態；
  NookBar、Flux 有 `--self-test`、`--snapshot`；shelf 有 `check`，有問題時回傳 exit code 1。→ Whisky 加一個 `--diagnose` 輸出 JSON。
- **Churn 測試**：shelf 讓測試圖示出現又消失 50 次。→ 放進 M2 的驗收。
- **讀 MenuBarAgent 自己的 log 驗證行為**（Stash）→ 27 spike 的工具。
- **備份與還原所有 App 的 `NSStatusItem Preferred Position`**（Barn 的腳本）→ 實驗前先備份。
- **固定的自簽或 designated requirement 簽章**，讓重新 build 後 TCC 授權不會失效（Bouncer、Flux、IconCloak、Champ-KTP/Tuck）→ M0 就要設好。

## 9. 有趣但離題

- 在視窗標題列用兩指滑動 snap 視窗，event tap 只觀察不攔截（Cornice）。
- 用 Force Touch 觸控板秤重（MacTools）。
- 權限稽核：提醒「已授權但沒有功能在用」的權限（Vorssaint）。這點可以借來做 Whisky 的權限頁。
