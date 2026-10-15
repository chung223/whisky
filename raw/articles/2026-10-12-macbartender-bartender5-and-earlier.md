來源：
- https://www.macbartender.com/Bartender5/ （Bartender 5 產品頁）
- https://www.macbartender.com/Bartender5/release_notes/ （Bartender 5 release notes）
- https://www.macbartender.com/Bartender4/ （Bartender 4 產品頁）
- https://www.macbartender.com/B5blog/Bartender5-menu-bar-groups/ （2023-10-02）
- https://www.macbartender.com/B5blog/How-Bartender-Ensures-Compatibility-with-macOS-Sequoia/ （2024-09-26）
- https://www.macbartender.com/B5blog/Bartender-Permissions-Issue/ （2024-05-20）
標題：Bartender 4 / 5 官方功能頁與 Bartender 5 release notes（合輯）
發佈日期：見各項；產品頁未標示
存取日期：2026-10-12

# 摘要筆記

## Bartender 4 產品頁（Big Sur 起）
- Quick Reveal：滑鼠移到選單列或點擊選單列即顯示隱藏項目。
- Bartender Bar is back（在選單列下方）。
- Menu Bar Item Spacing：Big Sur 加大了間距，可恢復舊間距或更小。
- Quick Search（鍵盤找、顯示、啟用）。
- Triggers（Show for Updates）：any change、icon matching、script；內建 Battery、WiFi、Time Machine。
- Menu bar layout 畫面：Hidden / always visible / 精確順序，Bartender 維持順序。
- Hotkeys for any menu bar item；Menu bar Spacers（空白、文字、emoji）；**AppleScript support**（show and activate items）；swap shown 與 hidden 以節省空間；Spotlight 搜尋（關鍵字 "Bartender "）；新項目出現位置可選。
- 相容：Big Sur、Monterey、Ventura and newer。

## Bartender 5 產品頁（Sonoma）
- 「designed for macOS Sonoma」；FAQ：因 macOS 內部變更，B5 只能支援最新版（當時為 Sonoma）。
- Speed（swipe/scroll/click/hover）、Full access（瀏海）、Bartender Bar、Styling（tint、gradient、rounded/pill 含左右分離、border、shadow、圓角螢幕、每個選單列不同 style）、Groups、Presets（可由 triggers 與 **macOS Focus modes** 套用）、Triggers（Battery、WiFi、Location、Time and date；條件可組合）、Spacing、Quick Search、Hotkeys、Spacers、AppleScript、swap、新項目位置。
- 「Coming soon... Menu Bar Widgets!」
- 舊 FAQ：Setapp 當時 $9.99/mo。2022-07 之後買 B4 者免費升 B5。

## Groups 文（2023-10-02）
- 「Menu Bar Item Groups」：在 Settings 的 Menu Bar Items 或 Preset 中，把「Add a menu bar item group」拖到位置，開啟 Group Settings Editor；右鍵 group 也可編輯。

## Bartender 5 release notes 重點
- 5.0.x：「Bartender 5 is a paid upgrade… completely redeveloped for macOS Sonoma」；Bartender 4 未針對 Sonoma 最佳化。
- 5.0.52：一次性憑證變更（2024-05-20 文：權限畫面會再開，OS 可能不認得已授權）。
- 5.0.53：「Bartender is now part of the Applause family」；移除 5.0.52 加入的 **Amplitude** product analytics（原本用來計算遇到權限問題的使用者）。
- 5.0.54：遇到權限問題時自動在背景執行 `tccutil reset All com.surteesstudios.Bartender`。
- 5.1.x–5.2.x：Sequoia 相容與效能；「apply default style to new displays」設定。
- 5.3.4 / 5.3.5：**screen recording 變成可選**，但會移除許多功能；可先開啟設定好再關；「never stores, scans, or uploads」畫面內容；修正多螢幕 crash。
- 5.5.0：Bartender 5 不相容 Tahoe；防止移動時點到 Apple Menu。
- 5.5.8（對應 6.2.1）：滑鼠移動時不執行動作，閒置才做。

## Sequoia 相容文（2024-09-26）
- 重建 Bartender Bar 以應付 Sequoia 帶來的效能挑戰。
- 手動遷移 Sequoia 未正確轉移的系統項目（例：Time Machine）。
- 調整選單列刷新頻率以配合 Sequoia 動態桌布。
