# Progress

## Done
- 2026-10-13: 四份履歷（base、mediatek、credo 兩份）Skills 的 `AMBA (AXI, AHB, APB, CHI)` 改為 `AMBA spec \& bus integration (AXI, AHB, APB, CHI)`，全部重新編譯確認仍為 1 頁。
- 2026-10-13: 在 `mediatek/prep-notes.md` 第四部分加入「何時可以投效能相關職缺」的判準與投遞策略。
- 2026-10-13: 在 `mediatek/prep-notes.md` 新增「四、學習方向與建議」（定位、simulation speed 案例追問、學習優先順序、履歷措辭、不要做的事），並同步更新第三部分缺口表。
- 2026-10-13: 更新 CLAUDE.md 的 Build 與 Layout 段落，反映 `base/` 與 `misc/` 的實際路徑。
- 2026-10-13: 同一條 simulation speed bullet 也加入 `base/resume.tex` 的 Chief Engineer 底下，重新編譯確認仍為 1 頁。
- 2026-10-13: 在 `mediatek/resume-mediatek-vdk.tex` 的 Chief Engineer 底下（messaging IP bullet 之後）加入 simulation speed bullet，重新編譯確認仍為 1 頁。
- 2026-10-13: 使用者回答 `mediatek/prep-notes.md` 第二部分的自我檢查問題（見下方結論）。

## In progress
- 複習順序：C++14 → TLM-2.0 → VDK 流程（尚未開始勾選）。

## Blocked / open questions
- simulation speed 案例：加速倍數忘記了，只確定有變快。可從舊 profiling 報告、commit 紀錄或同事回憶找數字；找不到就不寫數字。
- 文件：只寫過 msg IP 的文件，平台層沒寫過（與先前「三種都寫過」對照，以此為準）。

## 回答結論
- A 效能建模：沒做過 timing / latency 建模，但有優化過 simulation speed（VDK top-down profiling、valgrind）→ 主打 VDK 職缺，履歷可補一條 profiling bullet；純效能建模類仍不主投。
- B Bus：只讀過 spec，並把 fast model IP 接到 bus（Synopsys VDK 工具）→ 整合經驗，不是 interconnect 建模；Designer 吻合度低。
- C 文件：model spec、user guide、release note 寫過，但只針對 msg IP，平台層沒寫過。
- Simulation speed 案例（msg IP）：用 VDK top-down profiling、valgrind 找到每個 clock cycle 都 wait 的不必要喚醒，改成 wait(time, SC_MS) 等較粗的時間等待；加速倍數不確定。
- C：知道 non-blocking 概念但沒做過 AT；個人專案有跑 CI，工作上沒用過。
