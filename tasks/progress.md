# Progress

## Done
- 2026-11-18：MediaTek VDK 職缺由兩份變一份。104 上「VDK - 2」（93a5b，經歷不拘、1~4 人）已下架，PDF 刪除；保留 896h2（2 年以上、1–2 人），符合 Alan 的 4 年年資。`JD/fit-ranking.md` 的 #2 標為已下架、**編號不重排**（維持其他文件的交叉引用），全庫 15 份剩 14 份；`tasks/learning-plan.md` 兩處「VDK 兩份」改為單一 VDK。內推優先序：#1 → #4 Performance → #5 Designer（→ #8 AI 可選）。另外檢視「一份 MTK 履歷投全部」的可行性：現有 `mediatek/resume-mediatek-vdk.tex` 對 #1 精準、#4/#5 小改即可、#8 偏弱、#10/#12 不適合；建議同一份投 #1/#4/#5。已按使用者確認的事實改檔：SystemVerilog 只是讀過 DV testbench 程式碼、ACE 只知道是 coherence，兩者都不加（避免面試被追問）。實際改動：Summary 拉高到 full-system virtual platforms、6 個 IP model 加 reusable 與 MMIO/interrupt/DMA/register map/state machine、尾句加 profiled/tuned simulation speed；Chief Engineer 第 1 條加 reusable；Skills 補 Memory-Mapped I/O 與 Performance Profiling (VDK top-down, Valgrind)、移除重複的 Waveform Parsing；碩論補 PyTorch。第一版編譯成 2 頁，壓縮 Summary 並移除 Skills 重複項後回到 1 頁，無 Overfull。
- 2026-11-17：新增群聯板橋客製版 `phison/resume-phison-banqiao.tex`（1 頁）。Summary 改為 SSD controller 虛擬平台＋NAND controller＋simulation profiling＋碩論 DL/CV；Skills 重排（C/C++、Python、Linux 提前，新增 Virtual Platforms & Performance、Architecture & Storage、Deep Learning 關鍵字）。沒有寫 AI 效能建模、operator tiling、RTL 設計。台南 FW 另議。碩論細節已確認：PyTorch、CNN/YOLO、物件追蹤，寫進 Summary、Skills、Education 三處。使用者確認 NAND controller 模型的 register map 與 interrupt 都是真的，第一條 bullet 另補「from RTL design specifications」，整體以 ESL 經驗為主、AI 只放碩論。2026-11-17 第二輪潤稿：Skills 移除 Waveform Parsing、Simulation Speed Tuning，類別改為 Virtual Platforms \& Debugging；Summary 與 8 條 bullet 全部重寫順句（去掉 performance 主導與 CModels 混用），PDF 重新編譯（1 頁）。使用者確認定稿，交由朋友代投板橋（竹南可沿用同一份）。
- 2026-11-10：派三個唯讀 subagent 審查 2026-11-09 改好的選擇題，各負責一份檔案，用原始碼核對並實跑。發現的問題都已修正，紀錄寫在各檔尾「Agent 審查修正（2026-11-10）」：
  - **SystemC**：抓到一個舊錯誤「`SC_CTHREAD` 在初始化時執行」。實際上 `m_dont_init = true`，0 s 那次是被 clock 的 0 s posedge 叫醒的。T4、MC27、L2-5-a、EX-2 已一起改正。
  - **C++**：
    - L1-3-d 的 SSO 門檻改成 15／16 個字元。
    - Q7-c 答案改成 C、D。
    - L1-2 題幹的「都能編譯」改正。
    - Q16-c 補上 `main`。
    - Q20 統一用 `my_make_unique` 這個名稱。
    - L2-4、E1、E2 的提示改成折疊；E2 不再直接給出 `allows` 的寫法。
  - **TLM**：
    - 驗證紀錄裡有三處選項字母，在打亂選項後過時了，已更正。
    - `ver_pool` 的引用改正。
    - 四處措辭太強，已放寬。
- 2026-11-09: 三份題庫依 Alan 選的比例改題型：約 80% 選擇題加一句理由，約 20% 口述加手寫。
  - **改成選擇題的題目**：L1–L2 題，以及大部分 L3–L4 問答題，拆成子題（`Q11-a`、`L2-1-a`），每題都有〔單選〕或〔複選〕標記、一行「理由」、一個「答案＋理由要點」。原本的參考答案保留成「完整解說」。
    - TLM：Q3、Q4、Q6–Q15，共 41 個子題。
    - SystemC：L1-1～L2-6、L3-2～L3-4，共 34 個子題。
    - C++：L1-1～L2-3、Q1–Q16、Q18、Q19、Q21，共 77 個子題。另外新增兩個複習弱點的子題：L1-1-d（`auto` 與頂層／底層 const）、L1-3-d（SSO）。
  - **保留〔口述〕**：C++ Q17、Q22、C2；SystemC L3-1、L4-1、L4-2；TLM Q1、Q2、Q5、Q7-d。
  - **〔手寫〕輪替**：L2-4 → C1 `Buffer` 10 分鐘版（新骨架和測試）→ Q20 改成手寫 `my_make_unique`（新骨架和測試）。
  - **〔選做〕**：C++ E1／E2、SystemC EX-1／EX-2、TLM E1／E2。
  - **作答規則**：每份 MC 段開頭都加了「作答規則」。
  - **驗證**：新加的行為說法都在本機用 g++ 11、SystemC 2.3.3 實測，C1 和 Q20 的骨架用 scratchpad 裡的參考解驗證過（參考解不進 repo）。紀錄在各檔最後的「選擇題化驗證紀錄（2026-11-09）」。
  - **選項平衡**：用 session scratchpad 裡的一次性腳本平衡正確選項的位置。腳本已經跟著 session 消失，以後要用就重寫：交換兩個選項的內容，同時把答案區裡的字母引用一起換掉。
  - **刪掉的原子題**：C++ L1-3 第 1 題（用一句話說明左值與右值，Q4-a 部分涵蓋）、Q15 第 2 題（寫一個 mask 範例）。
  - **原題號引用**：舊的「第 n 小題」引用已改成子題編號（例如 Q3-c、Q6-d、Q14-a）。
  - **其他同步**：`CLAUDE.md` Study mode 第 2、4 條與 Layout 的 `study/` 一行、`tasks/learning-plan.md` 第 1 項練習方式也一起更新。
- 2026-11-09: 第二次 study mode session 的複習輪（C++，三題，用 g++ 驗證）。`auto` 與 const：`auto b = cr` 答成 `const int`（應為 `int`）、`const int* const p; auto q = p;` 答成 `const int* const`（應為 `const int*`），連續兩輪沒穩。`std::string` move 後答成 `nullptr`（應為有效但未指定，libstdc++ 為空字串）、短字串位址答「相同」但理由是「複製」（自相矛盾，實測不同）。`unique_ptr` move 後 `p.get()` 答對 `nullptr`，null vs dangling 補了差別，算修好。結果記在 `study/cpp11-14-quiz.md`「第二次複習輪（2026-11-09）」。L2-4 仍未交稿。
- 2026-11-05: `CLAUDE.md` Study mode 新增第 7 條：貼來的 LeetCode 等題目連結用 hint ladder 漸進帶領（先讓使用者試、review C++、之後才給參考解）。
- 2026-11-05: 第一次 study mode session 的複習輪（C++，三題）：`auto` 與頂層/底層 const、`std::move` 與 SSO、`unique_ptr` move 後。三塊都還沒穩：`auto& b = ci` 漏 `&`、`auto c = cr` 答成 `int&`、`const int*` 的 `auto` 答成 `int*`；仍答「move address」、短字串 move 位址答成相同；`p.get()` 答成 UB、把 null 說成 dangling。結果記在 `study/cpp11-14-quiz.md`「口頭練習紀錄」的「複習輪（2026-11-05）」。同 session 後續已教並考 G1（lambda `[=]`/`this`）、G2（`shared_ptr` 循環與 `weak_ptr`）：觀念大致過，小錯在 `this` 捕獲的 const 語意、抄範例變數名、`weak_ptr::lock()` 的設計理由；結果記在同一個「複習輪」段。再教並考 G3（Rule of Zero）：move 沒生成的因果鏈、`= default` 修法都過（修法二經兩層提示才寫出 `D(D&&) = default;`）。L2-4（RegBank 改 Rule of Zero）已出題，使用者尚未交稿，是下次起點。另：使用者問輸入框灰色建議文字怎麼關（`/config` 的 Prompt suggestions，設定名稱未查證）。
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
- 向 HR 確認技術面形式：是否有手寫 coding、題型（C/C++ 基礎、演算法、bit 操作）、是否以英文進行。結果決定 `tasks/learning-plan.md` 第 10 項與 C++11/14 最小練習的練習量。投遞後才能確認。**若確認有手寫**：題型比例要從 80/20 調高手寫比例，E1／E2／EX-1／EX-2 排回輪替，並明確告訴 Alan（2026-11-09 他選 80/20 時已知道這個風險）。
## Blocked / open questions
- simulation speed 案例：加速倍數忘記了，只確定有變快。可從舊 profiling 報告、commit 紀錄或同事回憶找數字；找不到就不寫數字。
- 文件：只寫過 msg IP 的文件，平台層沒寫過（與先前「三種都寫過」對照，以此為準）。

## 回答結論
- 2026-11-17 群聯評估：板橋與竹南是同一份 JD（AI/SoC 架構設計），fit 60（C，板橋通勤扣分）／66（B）。履歷沒有群聯版、沒有 AI/DL 關鍵字，基本條件「AI 運算架構/演算法、DL 框架原理」只有碩論可講。台南歸仁沒有建模或架構職；使用者想投台南 FW，需另做客製版（起點用 `credo/resume-credo-fw.tex`），並先補齊該 JD 條件。
- A 效能建模：沒做過 timing / latency 建模，但有優化過 simulation speed（VDK top-down profiling、valgrind）→ 主打 VDK 職缺，履歷可補一條 profiling bullet；純效能建模類仍不主投。
- B Bus：只讀過 spec，並把 fast model IP 接到 bus（Synopsys VDK 工具）→ 整合經驗，不是 interconnect 建模；Designer 吻合度低。
- C 文件：model spec、user guide、release note 寫過，但只針對 msg IP，平台層沒寫過。
- Simulation speed 案例（msg IP）：用 VDK top-down profiling、valgrind 找到每個 clock cycle 都 wait 的不必要喚醒，改成 wait(time, SC_MS) 等較粗的時間等待；加速倍數不確定。
- C：知道 non-blocking 概念但沒做過 AT；個人專案有跑 CI，工作上沒用過。
