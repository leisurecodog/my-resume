# Handoff

## Current state
- 針對聯發科 SystemC/TLM Modeling Engineer (VDK) 備戰，學習順序見 `mediatek/prep-notes.md`。
- 複習進度：2026-10-21 起題庫分 L1–L4 難度（見 Next steps）；已整理 C++11/14 題庫於 `study/cpp11-14-quiz.md`（15 題觀念/陷阱題 + 2 題白板手寫題，附折疊答案）；下一步配合 `tasks/learning-plan.md`「第 1 項：C++11/14 最小練習」做 4 步動手練習；TLM-2.0 LT、Quantum、DMI 複習進行中。
- 使用者已回答缺口問題，結論在 `progress.md`，並已寫進 `mediatek/prep-notes.md` 第三部分（缺口表）與第四部分（學習方向與建議）。
- 已完成：四份履歷的 AMBA 措辭改為整合與 spec 閱讀層級（見 `progress.md`）；`prep-notes.md` 第三部分 CI/CD 說法已改為「個人專案自己架過 CI，工作上沒用過」。

## Files touched
- 2026-10-21（難度分級題庫）：`study/cpp11-14-quiz.md`（新增第零模組 L1–L2、舊題補級別標籤、難度分級說明、驗證紀錄）；新增 `study/systemc-core-quiz.md`；`CLAUDE.md`（study/ 一行）、`tasks/task.md`、`tasks/progress.md`、`tasks/handoff.md`、`tasks/lesson.md`。
- 2026-10-21：新增 `study/cpp11-14-quiz.md`（C++11/C++14 核心考題與參考答案）；派發 3 位 subagent 審查並依 ISO C++11/14 標準條文修正 2 處事實失準與多處觀念細節；更新 `tasks/task.md`、`tasks/progress.md`、`tasks/handoff.md`、`tasks/lesson.md`、`CLAUDE.md`。
- 2026-10-20：`tasks/progress.md`、`tasks/handoff.md`（記錄 TLM-2.0 LT/quantum/DMI 口試結果）；新增 `study/tlm-quiz.md`（新資料夾 `study/` 放跨公司的複習材料）（5 題題目、可展開參考答案、上次弱點、下一輪加考題）；`CLAUDE.md` Layout 加一行。之後對照 SystemC 2.3.3 原始碼核對 Q4、Q6–Q8 並修正（`study/tlm-quiz.md` 文末有核對紀錄），`tasks/lesson.md` 加一條。
- 2026-10-20：`tasks/learning-plan.md`（第 1 項表格欄位更新，新增「第 1 項：C++11/14 最小練習」小節）、`tasks/progress.md`、`tasks/handoff.md`。
- 2026-10-20：`JD/fit-ranking.md`（全面重評、重新編號、截斷註記更正）、`mediatek/prep-notes.md`（定位段分數）、`tasks/learning-plan.md`（新增第 13 項 computer architecture 與 ACE/CHI）、`tasks/progress.md`、`tasks/lesson.md`。
- `tasks/learning-plan.md`（新增第 10–12 項）、`tasks/progress.md`（新增待辦：向 HR 確認技術面形式）
- `tasks/learning-plan.md`（新增）、`mediatek/prep-notes.md`（第 7–9 項移出）、`CLAUDE.md`（Layout 兩處）
- `mediatek/prep-notes.md` 第四部分學習優先順序（新增 AI/NPU、記憶體系統、RTL 三項與缺口統計）
- `JD/fit-ranking.md`（新增：15 份 JD 評分、投遞順序、補強影響）、`mediatek/prep-notes.md` 定位段、`CLAUDE.md` JD 說明一行
- `credo/resume-credo.tex`、`credo/resume-credo-fw.tex`（只改 AMBA 措辭，未加 simulation speed bullet）
- `mediatek/prep-notes.md`（缺口表更新、新增第四部分）
- `tasks/lesson.md`
- `CLAUDE.md`（Build / Layout 路徑改為 `base/`、`misc/`）
- `tasks/progress.md`、`tasks/handoff.md`
- `base/resume.tex`（加同一條 bullet）與重新編譯的 `base/resume.pdf`
- `mediatek/resume-mediatek-vdk.tex`（加一條 bullet）與重新編譯的 `mediatek/resume-mediatek-vdk.pdf`

## Next steps
- 新題庫：先做 `study/cpp11-14-quiz.md` 第零模組 L1→L2，L2-4（Rule of Zero）自己寫完貼來 review，不要先給解。接著 `study/systemc-core-quiz.md` 由 L1 往 L4。使用者做完後再補 TLM-2.0 的 L1–L2（入門與 AT 細節），並把口試結果記回各檔的「上次的弱點」。
- TLM-2.0 口試已做一輪（結果在 `progress.md` Done 2026-10-20）。下次複習要練「元件、事件、軟體看到的現象」三段式具體情境（例如 DMA+CPU contention、boot remap、debugger watchpoint、DMA 完成 interrupt 延遲），以及 30 秒講完 `b_transport` 完整路徑。`study/tlm-quiz.md` 已補 Q6–Q8（`transport_dbg`、socket binding、payload 進階），尚未口試。Q7 第 4 小題要使用者用自己 msg IP 接 bus 的實際細節回答，不要替使用者編。可以再口試一輪，重點放 Q6–Q8 與 AT 細節（`tlm_sync_enum`、fw/bw 各走哪些 phase）。
- C++：利用 `study/cpp11-14-quiz.md` 口頭與白板自測，並依 `tasks/learning-plan.md`「第 1 項：C++11/14 最小練習」做 4 步練習（Buffer rule of five → unique_ptr → lambda → 小 TLM initiator/target），第 4 步可與 TLM-2.0 複習合併。
- 新排名（`JD/fit-ranking.md`，編號已重排）：#1–2 VDK 92、#3 耐能 Co-Sim 71、#4 Performance 70、#5 Designer 68、#6 耐能 C-Model 67、#7 群聯竹南 66、#8 AI 處理器 62。使用者對 Performance 與 AI 處理器有興趣，建議跟 VDK 一起投；尚未做這兩份的客製履歷（可放 `mediatek/`），使用者要求才動。
- 被截斷、投遞前須到 104 看完整條件的 JD：6G/5G、群聯兩份、耐能三份、晶心、Designer、記憶體系統。其餘六份條件區完整。
- `tasks/learning-plan.md` 的職缺名稱對照仍有效（用名稱而非編號），不需改。
- 學習順序以 `tasks/learning-plan.md` 為準；第 1–6 項的細項仍在 `mediatek/prep-notes.md`，改動時兩邊對照。
- `JD/fit-ranking.md` 缺口表的「補法」是準備方向，不是履歷可寫的經驗；做完小專案後再回頭改分數與缺口。
- 評分只依 PDF 可見文字；多份 JD 在「顯示全部」處被截斷（01、06、07、09、10、11、14、15），投遞前到 104 看完整條件再校正分數。
- 若使用者有個人專案的 CI，可考慮在履歷補一行（先確認專案名稱與工具）。
- Bullet 已加入 MediaTek 版（無數字）。若找回加速倍數再補。
- 面試準備：為何變快（context switch / scheduler 事件變少）、精度取捨、如何確認功能一致。
- 文件只限 msg IP，履歷不要寫成平台層文件。

## Gotchas
- 本機 SystemC library 是用 C++11 編的，編譯 SystemC 程式要 `-std=c++11`（用 c++14 會報 `undefined reference to sc_api_version_..._cxx201103L`），入口要寫 `sc_main`。`sc_start(t)` 不會執行終點 `t` 那個時間點上的 process。
- 本機有 SystemC 2.3.3 原始碼與範例：`~/cpp_practice/side_project/uArch/systemc-2.3.3`（TLM 在 `src/tlm_core`、`src/tlm_utils`，範例在 `examples/tlm`）。寫或改 TLM 參考答案時用它核對；沒有 IEEE 1666 原文，標準獨有的語意要註明未核對。`study/tlm-quiz.md` 的 Q2（phase 方向、`tlm_sync_enum`）還沒核對。
- 已加到 MediaTek 版與 `base/resume.tex`；`credo/` 尚未加，使用者要求才動。
- `resume.tex` 已搬到 `base/`，CLAUDE.md 的 Build / Layout 已於 2026-10-13 更新（含 `misc/`）。
- 該 bullet 放在 Chief Engineer（2026/7 起）底下，因 messaging IP 出現在該職稱；實際優化發生的時期若不同需調整。
