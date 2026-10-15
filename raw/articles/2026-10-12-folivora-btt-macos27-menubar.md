來源：https://community.folivora.ai/t/macos-27-golden-gate-menu-bar-management-broken-solutions-ice-thaw-bartender-barbee-etc/47232
標題：macOS 27 Golden Gate Menu Bar Management Broken - Solutions (Ice, Thaw, Bartender, Barbee etc.)（BetterTouchTool 社群）
發佈日期：2026-06-10 起（至 2026-09-23）
存取日期：2026-10-12

# 摘要筆記

- BTT 開發者 Andreas Hegenberg：Apple「completely changed the menubar architecture (again)」。
- 以前每個 status item 是可被第三方擷取、移動、隱藏、推出畫面的獨立視窗；現在「all of the menu bar items are represented by only one window」。
- 受影響：Bartender、Barbee、Ice、Thaw、Sane Bar、Glow，以及 BTT 自己的選單列功能。
- 方法一已實作：「Load Menu Bar Layout」action（可綁任何 trigger、可循環）。版本號：本頁摘要讀為 6.569 / 6.575，但同一作者在 Ice #954 寫「BetterTouchTool 5.670」——兩者不一致，未查證。方法二未說明。
- 兩種方法都「not official」，Apple 可能在 beta 期間封鎖。
- bug：使用 layout action 後點時鐘不再開 Notification Center；隱藏項目後點擊無法再顯示。
- 2026-09：確認此功能只限 macOS 27。
