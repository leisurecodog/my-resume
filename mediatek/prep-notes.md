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
| CI/CD | 沒有實際使用工具 | 已有 automated regression 與 Python 工具化經驗，可快速上手 CI |
| AT 建模 | 沒做過 | 現有 model 都是 LT / behavior，理解 AT 概念與差別 |
| Boot FW | 沒做過 | FW 團隊在我提供的 VDK 平台上做 bring-up |
| Kernel | 未涉及 | JD 只要求 Linux 開發環境，user-space 已足夠 |
| 效能建模 | 待確認（見 A） | — |
