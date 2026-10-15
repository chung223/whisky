來源：https://tidbits.com/2024/06/05/bartender-developer-explains-and-apologizes-for-quiet-acquisition/
標題：Bartender Developer Explains and Apologizes for Quiet Acquisition（TidBITS, Adam Engst）
發佈日期：2024-06-05
存取日期：2026-10-12

# 摘要筆記

- Ben Surtees 把 Bartender 賣給 Applause；他說約「三個月前」賣出（MacRumors 6/4 報導寫約兩個月）；未公告。
- 導火線：簽章憑證更換沒告知使用者 → **MacUpdater** 把 5.0.52 起的更新標為可疑。
- 有報導指 5.0.51 被重新發佈並加入 Amplitude 分析框架（留言提到檔案從約 8 MB 變 10 MB）。
- 社群反應：退回 5.0.48/5.0.49、用 Little Snitch 擋連線或移除；替代品提到 Ice、Hidden Bar、BetterTouchTool、zNotch。
- 風險點：Bartender 需要 **Accessibility**（可控制 Mac）與 **Screen Recording**（可看到螢幕所有內容），且**未 sandbox**；在未公告的易主下引發信任問題。
- Surtees：為沒溝通憑證變更道歉；App 由有效 Developer ID 簽章並經 Apple notarize；Applause 加 Amplitude 是「to get an idea of the user base」。
- Engst 評：屬於「botched PR」而非惡意；先公告再做技術變更即可避免；Applause 需以透明度修復信任。
- 留言補充：之後 5.0.53 移除 Amplitude 並發道歉文。
