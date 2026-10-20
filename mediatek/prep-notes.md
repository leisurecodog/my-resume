# MediaTek SystemC/TLM Modeling Engineer (VDK) 備忘

對應職缺：聯發科 SystemC/TLM Modeling Engineer (VDK Virtual Platform)，竹北，碩士、2 年以上。
同系列：SystemC Modeling Designer（新竹市，偏 bus 建模與效能分析）。

## 一、複習順序

### 1. C++14（優先，面試最常從你自己的 model 往下問）
- [ ] 智慧指標：`unique_ptr` / `shared_ptr` / `weak_ptr`，什麼時候用哪個、所有權怎麼表達
- [ ] Move semantics：`std::move`、rvalue reference、move constructor，與 copy 的差別
- [ ] RAII：資源（記憶體、檔案、lock）如何綁定物件生命週期
- [ ] Lambda 與 `std::function`、capture 方式（by value / by reference）及生命週期陷阱
- [ ] `auto`、range-based for、`constexpr`（C++14 放寬的範圍）、generic lambda
- [ ] `virtual` / `override` / `final`、純虛擬函式、virtual destructor 為何重要
- [ ] 模板基礎：function / class template，你的 model 裡有沒有用到
- [ ] 自我檢查：能否說明你自己 model 裡一個 class 的繼承關係與設計理由

### 2. TLM-2.0 基礎（再走一遍）
- [ ] `tlm_generic_payload` 欄位：command、address、data ptr、length、response status、byte enable
- [ ] Blocking transport (`b_transport`)：呼叫流程、delay 參數怎麼累加
- [ ] Non-blocking transport (`nb_transport_fw/bw`)：四個 phase、返回值 TLM_ACCEPTED / UPDATED / COMPLETED
- [ ] LT 與 AT 的差別：什麼情境選哪個、各自的準確度與速度取捨（JD 說 AT 是加分）
- [ ] Temporal decoupling 與 quantum keeper：為何能加速、代價是什麼
- [ ] DMI (Direct Memory Interface)：何時使用、invalidate 怎麼處理
- [ ] Initiator / target socket、convenience socket（simple_target_socket 等）
- [ ] Interrupt 在 TLM 裡常見的建模方式（sc_signal / 獨立 socket / sc_in<bool>）
- [ ] 自我檢查：你的 model 用了哪些 socket 與 transport，能否畫出一筆 read/write 的流程

### 3. VDK 流程（你履歷寫了 VDK，要能講清楚）
- [ ] Model 如何掛進 VDK 平台（連接 bus、memory map）
- [ ] Register 與 interrupt 如何與 processor fast model 互動
- [ ] FW 在 VDK 上如何載入、除錯、trace
- [ ] 你自己是如何驗證 model 與 RTL／spec 一致
- [ ] 自我檢查：一個 FW 在 VDK 上遇到 bug，你的 debug 流程是什麼（gdb、log、trace）

## 二、值得追問自己的問題（會改變投遞策略）

### A. 效能建模（缺口最大）
10/15 份 JD 要求效能建模、profiling 或瓶頸分析，你的履歷目前沒有。
- [ ] 你的 model 有沒有掛 timing（`b_transport` delay、quantum）？
- [ ] 有沒有量過 latency / throughput，或比對過 model 與 RTL 的 cycle 差距？
- [ ] 有沒有用 trace 做過效能分析（例如找 FW 在 VDK 上的 hot path）？
- [ ] 有沒有量過 simulation speed，或優化過 model 的執行速度？
- 回答「有」：可補一條 bullet，Designer、群聯、效能驗證三類吻合度會提高。
- 回答「沒有」：投遞時主打 VDK 職缺，不要硬投效能類。

### B. Bus / interconnect 建模
Skills 有列 AXI / AHB / APB / CHI，但 bullet 裡沒有實際證據。
- [ ] 你有沒有寫過 interconnect、bridge、arbiter 或 address decoder model？
- [ ] 還是只是 IP 接進現成的 bus 使用？
- [ ] 有沒有碰過 cache coherency（ACE / CHI）、DRAM 或 memory controller 的 model？
- 有的話：Designer（bus 建模）的吻合度會明顯提高。

### C. 其他（較低優先）
- [ ] 你有用過 AT 或 non-blocking transport 嗎（即使只是閱讀別人的 code）？
- [ ] 有沒有看過或參與過 CI（即使不是你架設的），例如 pipeline 如何觸發 regression？
- [ ] 你寫過的文件類型：model spec、user guide、release note？能否舉一個例子？

## 三、面試時要能如實說明的缺口

| 項目 | 狀態 | 建議說法 |
|---|---|---|
| CI/CD | 工作上沒用過；個人專案自己架過 CI | 工作上有 automated regression 與 Python 工具化；個人專案自己架過 CI，能快速接手公司的 pipeline |
| AT 建模 | 沒做過，只知道 non-blocking 概念 | 現有 model 都是 LT / behavior，理解 AT 的 phase 與 LT 的差別，正在補 |
| Boot FW | 沒做過 | FW 團隊在我提供的 VDK 平台上做 bring-up |
| Kernel | 未涉及 | JD 只要求 Linux 開發環境，user-space 已足夠 |
| 效能建模 | 沒做過 timing / latency 建模 | 沒做過 timing 建模，但做過 simulation speed 優化（見下方案例） |
| Bus 建模 | 只讀 spec、把 fast model IP 接到 bus | 整合與 spec 閱讀層級，沒寫過 interconnect / arbiter model |
| 文件 | 只寫過 msg IP（spec、user guide、release note） | 範圍限於自己負責的 IP，平台層沒寫過 |

## 四、學習方向與建議

### 定位
- 主投 VDK Modeling Engineer。你的實際強項是 IP model + VDK 整合 + 優化 simulation speed。
- SystemC Modeling Designer（bus 建模、效能分析）與 Performance 驗證吻合度較 VDK 低，但都是 B 級可投（Designer 68、Performance 驗證 70；2026-10-20 重評，Performance 原 58，條件區只要求「familiar」，sign-off 與 cycle approximate model 是職責不是資格）。AI 處理器建模 62（C 級上緣，RTL design 是唯一非加分條件）。純效能分析類仍需面試時誠實說明範圍。完整評分見 `JD/fit-ranking.md`。

### 要能講的案例：simulation speed 優化（msg IP）
- 做法：用 VDK top-down profiling 與 valgrind 找到每個 clock cycle 都 `wait()` 造成的不必要喚醒，改成 `wait(time, SC_MS)` 等較粗的時間單位。
- 加速倍數想不起來：找不到就不要編數字，只說「明顯變快」。可試著翻舊 profiling 報告、commit 紀錄。
- 面試一定會往下追，先想好三題：
  1. 為什麼變快：scheduler 事件與 context switch 變少，每個 cycle 不再喚醒 thread。
  2. 精度取捨：喚醒粒度變粗，時間精度下降。哪些行為會受影響、為什麼對 FW 無影響。
  3. 怎麼確認功能一致：用什麼測試或 regression 前後比對。
- 與 TLM 的連結：這與 temporal decoupling / quantum 是同一類取捨（用時間精度換速度），可以順著講。

### 學習優先順序
| 順序 | 主題 | 目標 | 做法 |
|---|---|---|---|
| 1 | C++14 | 能說明自己 model 的類別設計 | 依第一部分清單，從自己的 code 回頭對照 |
| 2 | TLM-2.0 LT 與 DMI、quantum | 能畫出 read/write 流程並解釋加速原理 | 依第二部分清單，與上面的優化案例連結 |
| 3 | AT / non-blocking | 能說明四個 phase 與 TLM_ACCEPTED / UPDATED / COMPLETED | 讀 TLM-2.0 LRM 的 base protocol 章節；跑 Accellera 範例 `at_1_phase`、`at_2_phase`、`at_4_phase`；把一個 LT target 改寫成 AT target |
| 4 | Bus 建模 | 從整合者提升到會寫簡單 interconnect | 個人小專案：一個 router（address decoder）加簡單 arbiter 的 TLM model，2 initiator 對 3 target，附測試。做完才可在履歷寫 bus 建模 |
| 5 | 效能建模入門 | 能解釋 latency / throughput 如何加到 model | 在上面的 router 加固定 latency 與 bandwidth 限制，用 trace 量出差異 |
| 6 | CI | 能講自己的 CI 流程 | 整理個人專案 CI 的工具與觸發方式，面試時能說明 |

第 7 項以後（AI / NPU、記憶體系統、RTL）以及跨 JD 的缺口排序，見 `tasks/learning-plan.md`。

### 何時可以投效能相關職缺
只讀完清單不夠，效能類看的是做過什麼。以下全部達成才算：
- [ ] 第 4 項完成：router + arbiter 有 code 與測試，能展示（GitHub 或面試現場）。
- [ ] 第 5 項完成：加了 latency / bandwidth 限制，用 trace 量出前後差異，能說明數字怎麼來。
- [ ] 履歷補一條如實的 bullet，明確標示是個人專案，不寫成工作經驗。
- [ ] 能回答：為什麼這樣建 timing、與 RTL 或 spec 的差距在哪、精度怎麼取捨。

投遞策略：
- 現在先主投 VDK 職缺，不必等學完。
- 小專案做完後，挑 JD 寫「加分」而非「必要」的效能類職缺試投。
- 投遞時把 simulation speed 優化案例擺前面，這是工作上真有的效能相關經驗。
- 要求「N 年以上效能建模經驗」的 JD，即使做完仍可能被資格篩掉，不要期望過高。

### 履歷措辭
- Skills 裡的 AXI / AHB / APB / CHI 改成整合與 spec 閱讀層級的說法，避免被當成寫過 bus model。
- Simulation speed bullet 已加入 `base/resume.tex` 與 `mediatek/resume-mediatek-vdk.tex`，無數字。
- 文件類 bullet 限定 msg IP，不要寫成平台層文件。
- 做完第 4 項小專案後再補一行，不要預先寫。

### 不要做的事
- 不要為了貼近 Designer JD 而誇大 bus 或效能建模經驗，面試會從細節追問。
- 不要把 AT 寫進履歷，目前只有概念層級。
