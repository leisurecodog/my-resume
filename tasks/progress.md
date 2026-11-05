# Progress

## Done
- 2026-11-05: 第一次 study mode session 的複習輪（C++，三題）：`auto` 與頂層/底層 const、`std::move` 與 SSO、`unique_ptr` move 後。三塊都還沒穩：`auto& b = ci` 漏 `&`、`auto c = cr` 答成 `int&`、`const int*` 的 `auto` 答成 `int*`；仍答「move address」、短字串 move 位址答成相同；`p.get()` 答成 UB、把 null 說成 dangling。結果記在 `study/cpp11-14-quiz.md`「口頭練習紀錄」的「複習輪（2026-11-05）」。尚未進入 lambda `[=]`/`this`。另：使用者問輸入框灰色建議文字怎麼關（`/config` 的 Prompt suggestions，設定名稱未查證）。
- 2026-11-05: 派 3 個 subagent 平行擴充三份題庫並加教學導讀，全部用本機 g++ 11.4 / SystemC 2.3.3 實跑驗證。`cpp11-14-quiz.md`：導讀 G1–G12、MC26–MC43、Q16–Q22、手寫 E1（weak_ptr observer）E2（enum class + std::array）。`systemc-core-quiz.md`：導讀 T1–T11、MC24–MC38、L2-4–L2-6、L3-2–L3-4、L4-2、手寫 EX-1（sc_semaphore arbiter）EX-2（CTHREAD 計數器）。`tlm-quiz.md`：導讀 T1–T11、MC37–MC53、Q9–Q15、手寫 E1（router + ROM/RAM）E2（wait vs quantum keeper vs DMI）。手寫題只給規格、骨架、提示，參考解只在 scratchpad。修正：cpp Q3（`unique_ptr<void>` 一定編譯失敗）、Q8（轉換運算子範例）、Q10/Q14 缺 `</details>`；tlm Q8（`reset()` 不清 `set_extension` 掛的 extension）。尚未核對：IEEE 1666 / ISO 條文編號（本機無原文）、`sc_join`、`async_reset_signal_is`、`sc_clock` 進階參數、`tlm_to_hostendian_word` round trip。使用者還沒做這批新題。
- 2026-11-05: `CLAUDE.md` Study mode 改成學習台模式：每次 session 先複習上次學過的內容與弱點；新主題預設不會，先教（解釋、小範例、常見陷阱）再出題，除非使用者說已經會。
- 2026-11-03: 派 4 個唯讀 subagent 審查題庫缺口（C++11/14、SystemC 核心、TLM-2.0、無題庫主題），再派 3 個 subagent 各修一份題庫的事實疑點，每項用本機 g++ / SystemC 2.3.3 重跑驗證，紀錄在各檔尾「事實修正（2026-11-03）」。`cpp11-14-quiz.md`：Q2 friend+`make_shared` 不可行（`T::T() is private`）改為 passkey / static factory；C2 `detach()` 改為成員 thread + 解構 join；L2-3 答案 `1 2 1` 改 `1 2`；MC17、L2-2 的 `<<` 串接拆句；Q9 socket 說明與 libstdc++ 註記；L2-4 規格補 `size()` 由 `regs_` 推得。`tlm-quiz.md`：passthrough / multi socket 只註冊 nb 時呼叫 `b_transport` 會 `SC_REPORT_ERROR`（預設 throw，exit 1），simple 才自動轉換；還原位址改為慣例；streaming width 與 protocol checker 措辭精確化。`systemc-core-quiz.md`：L4-1 與 MC23 wall-clock 改區間；`wait` 實為三層呼叫；MC14 `SC_MANY_WRITERS` 同 delta 仍報 E115（原文有誤）；MC5/6/16/17/20 重跑無誤。缺口審查結果（待擴充清單）見 `handoff.md` Next steps。
- 2026-11-03: 第一次實際口頭演練 C++（tutor 模式，L1→L2）：`auto`/const、`std::move`、`unique_ptr`、lambda 捕獲與 `mutable`。弱點與下一輪題目記在 `study/cpp11-14-quiz.md`「口頭練習紀錄（2026-11-03）」。尚未開始 SystemC / TLM 題庫與 L2-4 Rule of Zero。
- 2026-10-21: `study/tlm-quiz.md` 選擇題再補 AT 專題 MC23–MC36（L1 2 題、L2 6 題、L3 6 題）：`tlm_phase` 內容與自訂 phase、`tlm_sync_enum` 三個回傳值、四個 phase 的 fw/bw 方向、`nb_transport` 的 `delay` 語意、AT initiator 接 LT target 的 nb→b 轉換、`peq_with_get`（排序、只呼叫一次的陷阱）、`peq_with_cb_and_phase`（同時間先進先出、immediate/delta/timed 順序）、out-of-order 完成、四 phase 對捷徑的呼叫次數、socket 不檢查 phase 方向、對 `BEGIN_RESP` 回 `TLM_ACCEPTED` 卻不送 `END_RESP` 會讓下一筆回應永遠送不出來。MC1–MC36 用腳本逐題抽出編譯執行，輸出與答案全部一致，並對照 SystemC 2.3.3 原始碼與 `examples/tlm`（核對範圍在驗證紀錄）。
- 2026-10-21: `study/tlm-quiz.md` 新增「選擇題」段（MC1–MC22：L1 6 題、L2 10 題、L3 6 題，放在口述題 Q1–Q8 之前），涵蓋 generic payload 預設值與 response status、`delay` 累加、bus 位址與延遲、`tlm_quantumkeeper`（忘了 `reset()`、對齊整數倍、預設 quantum 為 0）、`transport_dbg`、b/nb 轉換、extension、引用計數、multi socket id、AT 的 return path、`TLM_COMPLETED`、temporal decoupling 的因果問題、`SC_METHOD` 呼叫 `b_transport`、DMI 與領先時間。22 題程式碼用腳本抽出編譯執行，輸出與答案逐行比對一致，並對照 SystemC 2.3.3 原始碼（核對範圍在該段末尾的驗證紀錄）。
- 2026-10-21: `study/systemc-core-quiz.md` 新增「選擇題」段（MC1–MC23：L1 7 題、L2 10 題、L3 6 題，放在問答題之前）。從檔案抽出程式碼用腳本編譯執行，22 題的輸出與答案區塊逐行比對全部一致（MC23 是 wall-clock，另跑兩個版本確認喚醒次數）。
- 2026-10-21: `study/cpp11-14-quiz.md` 新增「選擇題」段（MC1–MC25，L1 8 題、L2 11 題、L3 6 題，放在檔案最前面），問答題與手寫題移到後面並加分隔標題。每題程式碼與結論在本機 g++ 實跑（含 ASan、-std=c++11 對照、volatile/atomic 計數實驗）。
- 2026-10-21: 增加漸進式難度的考題。`study/cpp11-14-quiz.md` 新增第零模組（L1-1 auto/range-for、L1-2 nullptr/enum class/override、L1-3 左值右值與 std::move、L1-4 unique_ptr、L2-1 copy/move 輸出預測、L2-2 lambda 懸空參考、L2-3 shared_ptr 循環參考、L2-4 Rule of Zero 動手題），舊題 Q1–Q15、C1–C2 標上 L3/L4。新增 `study/systemc-core-quiz.md`（L1-1–L1-3、L2-1–L2-3、L3-1 scheduler 口述、L4-1 msg IP simulation speed）。L2 預測輸出與 L4 的 wall-clock 數字都在本機實跑；L2-4 的測試以私下寫的參考解驗證（舊版會觸發 4 個 static_assert）。
- 2026-10-21: 整理 C++11 / C++14 面試與核心觀念題庫（`study/cpp11-14-quiz.md`，涵蓋智慧指標與 control block、Move semantics 與 noexcept 原理、Lambda/std::function 性能陷阱、C++14 特性如 make_unique/init capture/generic lambda/constexpr 放寬、atomic vs volatile、手寫 Buffer 與 Code Review 題，共 15 題問答 + 2 題手寫實作題，均附可折疊式詳細參考答案）。派發 3 位 subagent 針對 ISO C++11/C++14 標準條文與編譯器底層審查，修正 2 處事實失準（auto 函式回傳值推導為 C++14、move-only 類別於 vector resize 之降級行為），並強化 Copy-and-Swap、decltype(auto) 懸空引用等陷阱，核對紀錄寫在該檔末。
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
  - 使用者要依序做新題：C++ 第零模組 L1→L2（L2-4 要自己寫並貼來 review），SystemC 核心 L1→L4；L3-1、L4-1 第 3 點要用自己的案例回答，不要替使用者編。
  - C++11/14 考題已整理完畢（`study/cpp11-14-quiz.md`），進行題目演練並搭配 `tasks/learning-plan.md`「第 1 項：C++11/14 最小練習」的 4 步動手練習。
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
