# Whisky

從零用 Swift 打造、為**有瀏海的 Mac** 設計的 macOS 選單列管理工具。

14 吋 MacBook Pro 的瀏海右邊只放得下大約 9 個選單列圖示，其餘的 macOS 根本不畫出來，也點不到。
Whisky 把它們找回來，讓你決定哪些留在選單列上，其他的收進一條可以搜尋的 Whisky Bar。

> 目前是 0.9，只支援 **macOS 26（Tahoe）、Apple Silicon**，仍在開發中。
> macOS 27 的選單列機制完全不同，還沒支援（研究筆記見 [wiki](wiki/concepts/menubar-agent-allow-list.md)）。

## 功能

- **從瀏海倒出來**：游標移到瀏海，它會往下長一點、告訴你藏了幾個圖示；點一下，Whisky Bar 就從瀏海展開。
  面板和瀏海一樣是黑色，頂端只佔瀏海的位置，不會蓋住旁邊的選單列。沒有瀏海的螢幕從酒杯下方打開。
- **Whisky Bar**：點瀏海、點選單列上的酒杯，或按 **⌃⌥⌘W**（可以在設定裡換），列出所有被瀏海擋住、或不在選單列上的圖示。
  - 有選單的圖示：讀出它的選單、在 Whisky Bar 下方重建，選了就照常執行，原本的圖示完全不用動（menu mirroring）。
  - 沒有選單的圖示（點了是跳出小視窗的那種）：暫時放回選單列、點一下，關掉後再收回去。
  - 打字就能搜尋，←→ 選擇、Enter 打開；最常用的圖示排在最前面「常用」。
- **有變化時提醒**：藏起來的圖示換了樣子（例如出現通知標記），瀏海會長出來幾秒顯示它，點一下就打開；一直在變的數字（CPU、網速、溫度）會自動忽略。需要螢幕錄製權限。
- **圖示快捷鍵**：幫常用的圖示指定快捷鍵，按下就直接打開它的選單或面板（在 Whisky Bar 對圖示按右鍵 › 指定快捷鍵…）。
- **排列選單列**：畫出你的選單列（瀏海、圖示、酒杯），直接拖曳決定哪些顯示、順序如何，按「套用」才移動；也可以**從 Bartender 匯入**原本的版面。
- **分隔項目**（選用）：只顯示排好的圖示，其他的推到螢幕外，不會因為某個圖示寬度變了就被別的圖示補位。
  macOS 在 Whisky 重新啟動時會把它放錯位置，Whisky 會等你閒置 5 秒自動排回來（中途你一動就暫停，瀏海會顯示進度）；設定裡可改成只提醒。
- **情境版面**：把排好的圖示存成情境，指定什麼時候自動換過去：接上外接螢幕時、用電池時，或只手動切換（右鍵點瀏海 › 情境版面）。
  在某個情境下重新排列會存回那個情境；切換時一樣等你停下滑鼠才搬。
- **記住版面**：App 更新或重開後圖示換了位置，Whisky Bar 會提醒你，按「排回來」才移動；也可以「保留現在的」。
- **設定視窗**（右鍵點瀏海或酒杯 › 設定…）：快捷鍵、真實圖案、瀏海、分隔項目、版面提醒、登入時開啟、權限狀態。
- **倒酒動畫**：游標滑過瀏海時，瀏海裡的酒杯倒滿；展開時圖示一個個流出來。選單列上的酒杯在打開時倒滿、關閉時倒空。
- **酒杯住在瀏海裡**（選用，要搭配分隔項目）：選單列上不放酒杯，多一格給排好的圖示；只有搬移圖示時酒杯才出來，右鍵點瀏海打開 Whisky 的選單。
- 不連網、不收集資料；記錄只寫在 `~/Library/Logs/Whisky/`。

## 怎麼做到的

macOS 沒有提供「管理別人的選單列圖示」的 API。Whisky 用的是：

- **Accessibility**：讀每個 App 的 `AXExtrasMenuBar`，找出所有圖示與它們的選單。
- **CGWindowList**：每個圖示背後的視窗有沒有被畫出來（`kCGWindowIsOnscreen`）。
- **⌘ 拖曳**：合成 ⌘ 拖曳事件，並用未公開的事件欄位 `0x33` 指定要拖的視窗，只用「放到 Whisky 圖示左邊」與「送到最左邊」兩種動作，
  不把任何東西丟在瀏海邊界（macOS 會在那裡重新挑選要顯示的項目，順序也可能變）。
- **瀏海面板**：一個蓋在瀏海上、層級高於選單列的無邊框視窗，位置和大小只用公開的 `NSScreen` 介面算出來。
- **分隔項目**：一個長度 10000 pt 的空白 status item（Ice、Bartender、Frost 在 macOS 26 也用這招）。

每個做法都在作者的 MacBook Pro 14"（macOS 26.7）上實測過，紀錄在 [wiki/concepts/platform-verification.md](wiki/concepts/platform-verification.md)。

## 建置

需要 Xcode 27、[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
cd app
xcodegen generate
open Whisky.xcodeproj
```

`app/project.yml` 用作者的 Developer ID 簽章（`DEVELOPMENT_TEAM`）。自己建置時請改成你的團隊，或改用 Apple Development 簽章。
**簽章要固定**：macOS 的 Accessibility 授權綁在簽章上，ad-hoc 簽章每次建置都不同，授權會默默失效。

`app/scripts/install.sh` 會建置 Release 版、裝到 `/Applications` 並重新啟動。核心邏輯的測試：

```bash
cd app/Packages/WhiskyCore && swift test
```

## 權限

| 權限 | 必要 | 用途 |
|---|---|---|
| 輔助使用（Accessibility） | 必要 | 讀取圖示與選單、移動圖示 |
| 螢幕錄製 | 選用 | Whisky Bar 顯示圖示的真實圖案；沒有的話顯示 App 圖示（Apple 的系統圖示用對應的符號） |

## 限制

- 只支援 macOS 26。macOS 27 改由 MenuBarAgent 繪製整條選單列，需要另一套做法。
- 搜尋不支援中文輸入法組字。
- 少數圖示截不到真實圖案（顯示 App 圖示）。

## 專案結構

```
app/        Whisky 的原始碼（XcodeGen 專案、WhiskyCore 套件）
wiki/       研究知識庫：Bartender 的行為分析、12 個開源同類專案、macOS 26/27 平台變化、實測紀錄、架構與路線圖
raw/        網頁文章的摘要筆記與開源專案清單
CLAUDE.md   知識庫的寫作規則（依 Karpathy 的 LLM Wiki 模式）
```

研究從 [wiki/overview.md](wiki/overview.md) 開始看。Bartender 的分析只描述行為與用到的系統機制，程式碼依 wiki、Apple 文件與開源專案（遵守其授權）撰寫。

和 [Whisky（Wine 包裝工具）](https://github.com/Whisky-App/Whisky) 沒有關係，只是同名。
