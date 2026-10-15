# Whisky — 知識庫 Schema

Whisky 是用 Swift 從零重寫的 macOS 選單列管理工具，參考對象是 Bartender 6。
這個資料夾依照 Karpathy 的 [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
模式分三層：**raw（原始資料）→ wiki（LLM 維護的知識）→ schema（本檔）**，最後才是 `app/` 的實作。

人負責挑資料、問問題、做決定；LLM 負責摘要、交叉連結、歸檔、維護 index 與 log。

## 目錄

```
raw/                    原始資料。只能新增，不能修改或刪除既有檔案。
  bartender/bundle/     從 Bartender.app 複製出來的原文（plist、sdef、entitlements、nib 清單）
  bartender/rea/        REA 逆向輸出（evidence JSON、字串、類別清單、偽代碼摘錄）
  github/repos/         開源專案的 shallow clone，一個專案一個資料夾 <owner>__<repo>（不進版控）
  github/manifest.md    每個 clone 的網址、commit SHA、授權、clone 日期
  articles/             網頁文章剪輯成的 Markdown（檔名 YYYY-MM-DD-slug.md，開頭註明來源網址）
  assets/               截圖與圖片
wiki/                   LLM 擁有的知識層。人讀，LLM 寫。
  index.md              全部頁面的分類目錄（每頁一行：連結 + 一句話摘要）
  log.md                依時間排序、只追加的操作紀錄
  overview.md           整體概覽：目前知道什麼、還不知道什麼
  bartender/            Bartender 6 的功能與架構（逆向所得）
  projects/             每個開源同類專案一頁
  concepts/             技術概念（隱藏選單列項目的手法、私有 API、權限…）
  comparisons/          橫向比較表
  synthesis/            綜合結論：Whisky 的架構提案、重寫路線圖、決策紀錄
app/                    Whisky 的 Swift 原始碼（Xcode 專案）
```

## 頁面慣例

- 檔名用英文 kebab-case（`status-item-hiding.md`），內文用繁體中文，技術名詞保留英文。
- 每頁開頭放 YAML frontmatter：

  ```yaml
  ---
  title: Ice
  type: project        # overview | bartender | project | concept | comparison | synthesis
  tags: [open-source, swift, appkit]
  sources:             # raw/ 內的路徑或外部網址
    - raw/github/repos/jordanbaird__Ice
    - https://github.com/jordanbaird/Ice
  updated: 2026-10-12
  ---
  ```

- 頁面之間用相對路徑的 Markdown 連結（`[Ice](../projects/ice.md)`），Obsidian 與 GitHub 都能讀。
- 每個論點要能追溯到 `raw/` 的檔案、REA Evidence ID 或外部網址。

### 逆向結論的標記

`wiki/bartender/` 的每個結論都要標明證據等級：

- **【觀察】** 直接從檔案或 REA 輸出看到（類別名、字串、plist 欄位、偽代碼）。附 Evidence ID 或 raw 路徑。
- **【推論】** 從觀察推得的行為。寫出依據。
- **【未知】** 還沒確認的事。靜態分析不等於觀察到執行行為。

## 乾淨室（clean-room）規則

- 逆向的目的是理解 Bartender **做了什麼、用了哪些系統機制**，不是抄它的程式碼。
- `wiki/bartender/` 只描述行為、資料流與用到的 API；不要貼大段偽代碼。偽代碼只留在 `raw/bartender/rea/`。
- `app/` 的程式碼只依據 wiki 的行為描述、Apple 文件與開源專案（遵守其授權）撰寫，不得從偽代碼轉寫。
- 引用開源專案的程式碼前先查授權（Ice 是 GPL-3.0，直接複製會讓 Whisky 也必須 GPL）。
- `raw/bartender/` 與 `raw/github/repos/` 不要推到公開的 GitHub repo。

## 工作流程

### Ingest（加入新資料）

1. 把來源放進 `raw/` 對應位置（clone、剪輯、REA 輸出）。github clone 要同時更新 `raw/github/manifest.md`。
2. 讀完後新增或更新相關 wiki 頁面：一份來源可能動到 5–15 頁（專案頁、概念頁、比較表、overview）。
3. 更新 `wiki/index.md`。
4. 在 `wiki/log.md` 追加一筆。

### Query（提問）

1. 先讀 `wiki/index.md` 找相關頁面，再讀頁面，必要時回到 `raw/` 查證。
2. 回答附上引用的頁面。值得保留的答案歸檔成新的 wiki 頁面（通常放 `synthesis/` 或 `concepts/`），並記 log。

### Lint（健康檢查）

定期檢查：頁面間矛盾、過時說法（例如 macOS 新版改了 API）、沒被連到的孤兒頁、
該有卻沒有的概念頁、缺少的交叉連結、可以用網路搜尋補上的空白。結果記 log。

### RE（逆向）

用 REA 分析 `/Applications/Setapp/Bartender.app`。原始輸出存 `raw/bartender/rea/`，
結論寫進 `wiki/bartender/`，並依上面的證據等級標記。

## log.md 格式

只追加，最新的在最下面。每筆開頭固定格式，方便 grep：

```
## [2026-10-12] ingest | Ice (jordanbaird/Ice)
## [2026-10-12] re | Bartender 6.6.2 bundle inventory
## [2026-10-12] query | 如何偵測被瀏海遮住的選單列項目
## [2026-10-12] lint | 第一次健康檢查
```

標題下用 1–5 行列出動到的頁面與重點。
