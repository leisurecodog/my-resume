# Progress

## Done
- 2026-10-20: TLM-2.0 LT / quantum / DMI 口試 5 題（路徑、LT vs AT、quantum 代價、DMI 生命週期、總結）。機制觀念完整，Q2–Q4 達面試水準；Q1 第一次答得太簡略（payload 欄位、bus 也加 delay、兩種 wait 做法）。共通弱點：題目要具體情境時只給類別。Q5 「資料內容是準的」與 Q3 自己舉的讀到舊資料矛盾，需加前提（軟體正確同步、peripheral 存取前 sync）。題目與參考答案整理在 `study/tlm-quiz.md`，之後補了 Q6 `transport_dbg`、Q7 socket 與 binding、Q8 generic payload 進階（尚未口試）。Q4、Q6–Q8 已對照本機 SystemC 2.3.3 原始碼核對並修正，結果在檔案末的「核對紀錄」。
- 2026-10-20: `tasks/learning-plan.md` 第 1 項新增「C++11/14 最小練習」小節（C++14 差異清單、4 步動手練習、練習方式），因為 C++11/14 目前只讀過、沒實際寫過。
- 2026-10-20: `tasks/learning-plan.md` 新增第 13 項（Computer architecture 與 ACE/CHI，對應 Performance 驗證條件 2、3），第 9 項說明與建議做法依重評更新。
- 2026-10-20: 重讀 `JD/` 全部 15 份 PDF 並重評 `JD/fit-ranking.md`：Performance 驗證 58→70（B）、AI 處理器建模 55→62（C 上緣）、VDK 第 2 份 90→92、記憶體系統 50→55、6G/5G 38→40，其餘不變；排名與編號重排；截斷註記更正（VDK 兩份、Performance、AI、千逢、百仕聯條件區其實完整；被截斷的是 6G、群聯兩份、耐能三份、晶心、Designer、記憶體）。`mediatek/prep-notes.md` 定位段同步。
- 2026-10-13: `tasks/learning-plan.md` 新增第 10 項（C/C++ 基礎題與 bit 操作）、第 11 項（Co-sim 框架與 bit-true 驗證）、第 12 項（VDK 流程與 debug），並補缺口統計與建議做法。
- 2026-10-13: 新增 `tasks/learning-plan.md`（跨 JD 學習順序與缺口統計），`mediatek/prep-notes.md` 第四部分移除第 7–9 項與統計表並指向該檔；CLAUDE.md 同步。
- 2026-10-13: 把 JD 缺口共通項排序寫進 `mediatek/prep-notes.md` 第四部分「學習優先順序」（新增第 7–9 項與缺口統計表）。
- 2026-10-13: `JD/fit-ranking.md` 新增「每份職缺缺少的能力」（15 份各一張表：缺的能力、必要或加分、補法）與缺口共通項統計。
- 2026-10-13: 重新評分 `JD/` 全部 15 份職缺，結果寫在 `JD/fit-ranking.md`（A 級：MediaTek VDK 兩份 92/90；B 級：耐能 Co-Sim 71、MediaTek Designer 68、耐能 C-Model 67、群聯竹南 66）。`mediatek/prep-notes.md` 的定位段已對齊（Designer 由「低」改為 B 級可投）。
- 2026-10-13: 四份履歷（base、mediatek、credo 兩份）Skills 的 `AMBA (AXI, AHB, APB, CHI)` 改為 `AMBA spec \& bus integration (AXI, AHB, APB, CHI)`，全部重新編譯確認仍為 1 頁。
- 2026-10-13: 在 `mediatek/prep-notes.md` 第四部分加入「何時可以投效能相關職缺」的判準與投遞策略。
- 2026-10-13: 在 `mediatek/prep-notes.md` 新增「四、學習方向與建議」（定位、simulation speed 案例追問、學習優先順序、履歷措辭、不要做的事），並同步更新第三部分缺口表。
- 2026-10-13: 更新 CLAUDE.md 的 Build 與 Layout 段落，反映 `base/` 與 `misc/` 的實際路徑。
- 2026-10-13: 同一條 simulation speed bullet 也加入 `base/resume.tex` 的 Chief Engineer 底下，重新編譯確認仍為 1 頁。
- 2026-10-13: 在 `mediatek/resume-mediatek-vdk.tex` 的 Chief Engineer 底下（messaging IP bullet 之後）加入 simulation speed bullet，重新編譯確認仍為 1 頁。
- 2026-10-13: 使用者回答 `mediatek/prep-notes.md` 第二部分的自我檢查問題（見下方結論）。

## In progress
- 複習進行中：
  - C++11 已讀（C++14 差異待補：`std::make_unique`、generic lambda、放寬的 `constexpr` 等）。只讀過、沒寫過，下一步做 `tasks/learning-plan.md`「第 1 項：C++11/14 最小練習」的 4 步（約 3 到 5 天）。
  - TLM-2.0 複習中：LT (`b_transport`)、Quantum (temporal decoupling)、DMI。2026-10-20 口試已過一輪（見 Done），剩下補每個概念的具體情境，並用 C++ 練習第 4 步實作驗證。
- 向 HR 確認技術面形式：是否有手寫 coding、題型（C/C++ 基礎、演算法、bit 操作）、是否以英文進行。結果決定 `tasks/learning-plan.md` 第 10 項與 C++11/14 最小練習的練習量。投遞後才能確認。
## Blocked / open questions
- simulation speed 案例：加速倍數忘記了，只確定有變快。可從舊 profiling 報告、commit 紀錄或同事回憶找數字；找不到就不寫數字。
- 文件：只寫過 msg IP 的文件，平台層沒寫過（與先前「三種都寫過」對照，以此為準）。

## 回答結論
- A 效能建模：沒做過 timing / latency 建模，但有優化過 simulation speed（VDK top-down profiling、valgrind）→ 主打 VDK 職缺，履歷可補一條 profiling bullet；純效能建模類仍不主投。
- B Bus：只讀過 spec，並把 fast model IP 接到 bus（Synopsys VDK 工具）→ 整合經驗，不是 interconnect 建模；Designer 吻合度低。
- C 文件：model spec、user guide、release note 寫過，但只針對 msg IP，平台層沒寫過。
- Simulation speed 案例（msg IP）：用 VDK top-down profiling、valgrind 找到每個 clock cycle 都 wait 的不必要喚醒，改成 wait(time, SC_MS) 等較粗的時間等待；加速倍數不確定。
- C：知道 non-blocking 概念但沒做過 AT；個人專案有跑 CI，工作上沒用過。
