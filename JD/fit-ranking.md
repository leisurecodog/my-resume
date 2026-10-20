# JD 適合度評分（2026-10-13 初評，2026-10-20 重評）

依據：`JD/` 內 15 份 104 職缺 PDF 的可見文字，對照 `base/resume.tex` 與 `tasks/progress.md` 的自我回答結論。

## 截斷註記（2026-10-20 重新逐份檢查 PDF）

- **PDF 條件區完整**（沒有「顯示全部」）：MediaTek VDK 兩份、MediaTek Performance 驗證、MediaTek AI 處理器建模、千逢 NPU、百仕聯 GPU。評分可信度較高。
- **PDF 在「其他條件」處被「顯示全部」截斷**：MediaTek 6G/5G、MediaTek Designer、MediaTek 記憶體系統、群聯（竹南、板橋）、耐能三份（Co-Sim、C-Model、Embedded）、晶心。評分只依可見部分，投遞前到 104 看完整條件再校正。
- 10-13 初評的截斷清單有誤：VDK 兩份與 Performance、AI 處理器實際上是完整的，已更正。

## 重評變動摘要（2026-10-20）

| 職缺 | 舊分 | 新分 | 原因 |
|---|---|---|---|
| MediaTek Performance 驗證 | 58 (C) | **70 (B)** | 條件區只要求「Familiar with」Verilog/C++/Python、computer architecture、APB/AXI/ACE/CHI，經歷不拘；sign-off 與 cycle approximate model 只在工作內容，不是資格門檻。SystemC/TLM 是加分，你有 |
| MediaTek AI 處理器建模 | 55 (C) | **62 (C 上緣)** | 條件區完整：經歷不拘；只有 RTL design experience 是非加分項（未寫年資與程度），其餘 4 項加分你大多有（SystemC/TLM/ESL、C/C++、SW emulator）。應徵人數 0~5 人 |
| MediaTek VDK 第 2 份 | 90 (A) | **92 (A)** | 原以為沒有工作內容，實際有（與第 1 份相同的 5 條職責）；兩份條件相同，差別只在年資（2 年以上 vs. 不拘）與人數 |
| MediaTek 記憶體系統 | 50 (C) | **55 (C)** | 「基本要求」只要碩士、熟悉 SystemC/C++/Python、記憶體系統「基礎知識」；DRAM/SRAM 架構與最佳化、真實環境功耗分析是「進階」。仍被截斷 |
| MediaTek 6G/5G 基頻 | 38 (D) | **40 (D)** | 條件 1（ESL/SystemC 建模、SW/FW control-path simulation 的實務經驗）你符合；條件 2 仍是二選一都沒有 |
| 其餘 10 份 | | 不變 | 重讀後內容與初評一致 |

## 履歷現況（評分基準）

- 強項：C++/SystemC/TLM-2.0（LT）、VDK 平台整合、6 個 IP model（含 NAND controller、DMA、msg IP）、CModel vs RTL 驗證、Python 工具化、simulation speed 優化（無數字）。
- 缺口：timing / 效能建模、AT、interconnect 建模（只讀 spec 與接線）、工作上的 CI/CD、RTL 設計、AI/NPU 領域、無線/modem、OS/driver/FPGA。
- 條件：碩士、約 4 年年資、住竹北。

## 評分標準（滿分 100）

| 面向 | 配分 | 看什麼 |
|---|---|---|
| 核心技能吻合 | 40 | 必要條件與主要職責的技能，履歷有沒有實際證據 |
| 領域與職責吻合 | 25 | 工作內容是不是你做過的事（IP model、VDK、驗證 vs. 架構、效能分析） |
| 條件 | 10 | 年資、學歷、地點、出差 |
| 缺口可補性 | 15 | 缺口在面試前能不能用誠實說法或短期準備補上 |
| 加分項 | 10 | JD 列為加分的項目，你有幾個 |

分級：A 主投（≥85）、B 可投（65–84）、C 補強後再投（45–64）、D 不建議（<45）。

**判分原則（重評時釐清）**：JD 的「條件」區寫成「Familiar with」或「加分」的，不要因為工作內容列了某項職責就當成資格門檻；職責缺口主要影響「領域」與「可補性」，不是「核心」。

## 排名

| # | 職缺 | 地點 | 核心 40 | 領域 25 | 條件 10 | 可補 15 | 加分 10 | 總分 | 級 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | MediaTek SystemC/TLM Modeling Engineer (VDK) | 竹北 | 38 | 23 | 10 | 13 | 8 | **92** | A |
| 2 | MediaTek SystemC/TLM Modeling Engineer (VDK) - 2 | 竹北 | 38 | 23 | 10 | 13 | 8 | **92** | A |
| 3 | 耐能 C Model / RTL Co-Simulation and Verification | 台北內湖 | 30 | 17 | 7 | 10 | 7 | **71** | B |
| 4 | MediaTek 數位IC設計工程師（Performance 驗證與分析） | 竹北 | 31 | 16 | 10 | 8 | 5 | **70** | B |
| 5 | MediaTek SystemC Modeling Designer | 新竹市 | 30 | 15 | 10 | 8 | 5 | **68** | B |
| 6 | 耐能 C-Model Engineer (C++) | 台北內湖 | 30 | 16 | 7 | 9 | 5 | **67** | B |
| 7 | 群聯 AI/SoC 架構設計工程師（竹南） | 竹南 | 26 | 15 | 10 | 8 | 7 | **66** | B |
| 8 | MediaTek AI 處理器建模工程師 | 新竹市 | 24 | 13 | 10 | 6 | 9 | **62** | C |
| 9 | 群聯 AI/SoC 架構設計工程師（板橋） | 板橋 | 26 | 15 | 4 | 8 | 7 | **60** | C |
| 10 | MediaTek 運算系統架構工程師（記憶體系統） | 新竹市 | 26 | 10 | 10 | 6 | 3 | **55** | C |
| 11 | 千逢 NPU Modeling Engineer | 竹北 | 18 | 8 | 4 | 5 | 7 | **42** | D |
| 12 | MediaTek 6G/5G 基頻系統架構師 | 新竹市 | 18 | 8 | 8 | 3 | 3 | **40** | D |
| 13 | 晶心 CPU Solution Engineer（亞太） | 新竹市 | 12 | 6 | 6 | 6 | 6 | **36** | D |
| 14 | 耐能 C-Model / Embedded Platform Software Engineer | 竹北 | 10 | 5 | 7 | 3 | 3 | **28** | D |
| 15 | 百仕聯 Lead Vector Compute Architect（GPU） | 新竹市 | 3 | 2 | 2 | 1 | 2 | **10** | D |

## 逐項說明

### A：主投

**1–2. MediaTek SystemC/TLM Modeling Engineer (VDK)（兩份，PDF 完整）**
- 吻合：JD 要求的 SystemC/TLM-2.0（LT 即可）、MMIO / interrupt / DMA / register map / state machine、gdb 與 trace debug，全部是你每天做的事。VDK 也是你用的工具。
- 缺口：AT（加分項）、CI/CD automation（職責第 5 條）、bootable vSOC 的 boot FW / system bring-up（職責第 3 條）。三項都有誠實說法（見 `mediatek/prep-notes.md` 第三部分）。條件區沒有把 CI/CD 或 bring-up 列為資格。
- 兩份的職責與條件清單相同；差別是第 1 份寫 2 年以上、1–2 人，並多一段 Summary（VDK team、bootable virtual SoC）；第 2 份寫經歷不拘、1–4 人。
- 面試風險：simulation speed 案例會被追問原理與精度取捨。

### B：可投

**3. 耐能 C Model / RTL Co-Simulation and Verification（71，被截斷）**
- 吻合：C model vs RTL 驗證、自動比對、FSDB/VCD parsing、regression、文件，與你的 Senior Engineer 經歷高度重疊。年資 3 年以上，你符合。
- 缺口：必要條件寫「Hands-on experience building or maintaining C model and RTL co-simulation environments」與「integrating software models with RTL simulators」，你只有驗證側；另有 cycle-level profiling、cycle-accurate model、bit-true / 數值比對。
- 其他：台北內湖，從竹北通勤是實際成本。履歷沒有明寫「verified C model against RTL」的成果數字，可在此版本補強。

**4. MediaTek 數位IC設計工程師（Performance 驗證與分析）（70，PDF 完整，原 58）**
- 條件區（經歷不拘、碩士以上）：Familiar with Verilog/SystemVerilog/C++/Perl/Python；Familiar with computer architecture；Familiar with industry bus protocols (APB, AXI, ACE, CHI)。加分：embedded system、SystemC/TLM、RTL design。
- 吻合：Verilog、C++、Python 符合；bus protocol 你有 spec 閱讀與 IP 接線，達到「familiar」層級；SystemC/TLM 加分你有；工作內容第 2 條「ESL platform and simulation technology development」與第 3 條 model development 是你做的事。
- 缺口：工作內容第 1 條 pre-silicon performance sign-off、第 3 條 cycle approximate modeling。這兩項沒有出現在條件區，是面試會問的職責，不是資格門檻。computer architecture 的深度是最大面試風險。
- 之前把 sign-off 與 cycle approximate model 當核心必要條件，高估了門檻。

**5. MediaTek SystemC Modeling Designer（68，被截斷）**
- 之前 `prep-notes.md` 寫「吻合度低」。重看：條件清單寬鬆（碩士、經歷不拘，SystemC/C++ OOP 為必要，TLM-2.0、虛擬平台、AXI/AHB/CHI 基礎為加分或尤佳），你的履歷全部對得上。
- 缺口在職責：「bus 數位系統建模與性能分析」是第 1 條，而你沒寫過 interconnect model、沒做過 timing 建模。
- 判斷：可投，但面試會問 bus 與效能；你只能誠實說整合與 spec 閱讀層級。

**6. 耐能 C-Model Engineer (C++)（67，被截斷）**
- 吻合：碩士、C++/Python、OOP 與設計模式、C-Model 開發與自動化測試、文件、與 HW/SW 團隊整合。年資 3 年以上，你符合。
- 缺口：NPU 演算法與 bit-true 數值（可見文字沒有要求，但「simulate NPU behavior accurately」會問）。
- 其他：台北內湖。

**7. 群聯 AI/SoC 架構設計工程師（竹南，66，被截斷）**
- 吻合：基本條件 C/C++、Python、Linux 符合（經歷不拘、碩士）；SystemC 建模與 SoC 模擬/驗證（加分）、SSD/UFS 經驗（加分，且你的 NAND controller 與 DMA 經驗直接相關）、規格文件。
- 缺口：基本條件的「AI 運算架構/演算法知識、深度學習框架原理」（只有碩士論文的 DL/CV 經驗）、operator tiling/mapping、效能建模與 profiling。
- 其他：竹南離竹北近。職務偏架構分析而非 IP model，是轉型而非延續。

### C：補強後再投

**8. MediaTek AI 處理器建模（62，PDF 完整，原 55）**
- 條件區（經歷不拘、碩士以上、資工/電機/通信相關、擅長工具 Verilog）：第 1 條 RTL design experience（未寫年資或程度）；加分為 chip level architecture 或 system level C/C++/SC modeling、C/C++、SystemC/TLM2.0/ESL、SW 或 HW emulator。
- 吻合：加分項你幾乎全有（system-level SystemC modeling、C/C++、SystemC/TLM-2.0、VDK 屬 SW-based emulator）。應徵人數 0~5 人，競爭少。
- 缺口：RTL design experience（你有 Verilog 技能與 CModel vs RTL 驗證，但沒有獨立 RTL 設計）；工作內容的 AI model development 與 HW/SW bottleneck analysis。
- 判斷：RTL 一條是否為硬門檻要看面試；把 CModel vs RTL 驗證講具體（讀過、debug 過 RTL）即可投，不必等補強。

**9. 群聯 AI/SoC 架構設計工程師（板橋，60，被截斷）**：職務內容與竹南相同，差在通勤（板橋）。

**10. MediaTek 運算系統架構（記憶體系統，55，被截斷，原 50）**
- 基本要求：碩士、熟悉 SystemC/Verilog/VHDL 或 C/C++/Python、記憶體系統/架構設計/分析/模型開發的基礎知識。你的技能符合，NAND controller 對「記憶體系統基礎」只算部分。
- 進階（為佳）：SRAM/DRAM 架構設計與最佳化、真實環境功耗/效能分析，你沒有。
- 缺口：職責是 CPU/GPU/NPU 與記憶體互動分析、效能/能耗模型建立與競爭分析。

### D：不建議

- **11. 千逢 NPU Modeling（42，PDF 完整）**：要求 3 年 NPU 架構設計與實作（104 的經歷欄位寫不拘，資格寫在內文）、PE array、systolic array、cycle-accurate 與 bit-true model。你有 C/C++ 與 model 經驗，但沒有 NPU 架構經驗。月薪 80K–250K。
- **12. MediaTek 6G/5G 基頻架構（40，被截斷，原 38）**：條件 1（數位設計/系統/架構建模，含 ESL/SystemC、SW/FW control-path simulation）你符合；條件 2 要無線通訊／modem 領域，或系統效能與功耗分析經驗（二選一），你兩者都沒有。2 年以上，碩士。
- **13. 晶心 CPU Solution Engineer（36，被截斷）**：最低條件（碩士、C/C++ 與 SystemC model、能出差）你符合，但職責是 RISC-V 軟體 build 環境、CI/CD、客戶技術顧問、教育訓練、一年最多 3 個月出差，角色是 FAE/售前，不是建模。
- **14. 耐能 Embedded Platform Software（28，被截斷）**：名稱有 C-Model，實際是 embedded driver、OS platform owner、FPGA bring-up、kernel debug。
- **15. 百仕聯 Lead Vector Compute Architect（10，PDF 完整）**：104 經歷欄位寫不拘，但必要條件內文要求 6 年以上資料平行微架構經驗與技術領導。

## 每份職缺缺少的能力

「必要」指 JD 條件區明列為必要的條件；「職責」指只出現在工作內容；「加分」指 JD 列為加分或尤佳。「補法」是面試前可做的事，不代表能補成經驗。

### 1–2. MediaTek VDK（92 / 92）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| AT / non-blocking transport 實作 | 加分 | 用現有 model 寫一個 AT 版 initiator/target，理解四個 phase |
| CI/CD automation（工作上） | 職責第 5 條 | 以個人專案的 CI 說明；整理 regression 觸發流程 |
| Boot FW / bootable vSOC bring-up | 職責第 3 條（bring-up） | 說明 FW 團隊在你的平台上 bring-up，你負責 model 與平台正確性 |
| Kernel-level debug | 無（Linux 環境即可） | 不需補 |

### 3. 耐能 C Model / RTL Co-Simulation（71）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 自行架設 C model 與 RTL 的 co-sim 框架（通訊、同步，例如 DPI / PLI） | 必要（資格 3、4；職責 1、2） | 做小型 DPI-C 範例，或釐清過去 co-sim 中你負責的部分 |
| RTL cycle profiling 與效能瓶頸分析 | 職責 3、12 | 用 waveform 量一個 IP 的 cycle，寫成分析 |
| Cycle-aware / cycle-accurate C model | 職責 5 | 同上，補 timing 建模小專案 |
| Bit-true / 數值正確性驗證（定點、浮點差異） | 職責 6 | 讀 fixed-point 基礎，做一個比對範例 |

### 4. MediaTek Performance 驗證與分析（70）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| Computer architecture（pipeline、cache、memory hierarchy）熟悉度 | 必要（條件 2，「familiar」） | 複習 cache、coherency、memory ordering |
| ACE / CHI 協定理解 | 必要（條件 3，「familiar」；你只讀過 spec） | 讀 CHI 交易流程，準備能講的案例 |
| Pre-silicon performance sign-off 流程 | 職責 1 | 讀 performance sign-off 方法論，了解 workload、KPI、報告 |
| Cycle approximate model 開發 | 職責 3 | timing model 小專案 |
| RTL design | 加分 | 小型 RTL 專案 |
| Embedded system 設計 | 加分 | 以 VDK 上 FW 與 model 的互動說明 |
| Emulation（HW emulator）技術 | 職責 2 | 無近期補法 |

### 5. MediaTek SystemC Modeling Designer（68）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| Bus / interconnect model（arbiter、decoder、bridge） | 職責 1 | 寫一個簡單 AXI-like interconnect LT model |
| Bus 效能分析（latency、throughput、contention） | 職責 1 | 在上述 model 掛 delay 並量測 |
| 可重用、可延展的模型架構設計 | 職責 2 | 整理自己 6 個 IP 的共用設計 |
| 晶片／平台層高層次建模與平台層文件 | 尤佳 | 文件只寫過 msg IP；說明範圍，不誇大 |

### 6. 耐能 C-Model Engineer（67）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| NPU 運算行為（卷積、矩陣乘、量化）理解 | 職責（simulate NPU accurately） | 讀 NPU / systolic array 入門資料，寫一個 conv 的 C model |
| 設計模式的明確實例 | 必要（OOP + design patterns） | 從自己 code 找出 factory、observer 等實例 |
| Model 效能與精度優化（不只 simulation speed） | 職責 | 以 msg IP 優化案例說明，並準備精度取捨 |

### 7、9. 群聯 AI/SoC 架構（竹南 66 / 板橋 60）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 深度學習框架原理（PyTorch C++ backend、operator） | 必要（基本條件）／加分 | 讀 PyTorch dispatcher 與 operator 流程；碩士論文只算間接經驗 |
| AI 運算負載分析與優化 | 必要 | 挑一個 CNN / Transformer 估算 compute 與 memory 需求 |
| 效能建模與 profiling（SystemC / Python） | 職責／加分 | timing model 小專案 |
| Operator 分割 / 映射（tiling） | 職責／加分 | 手算一個 matmul tiling 的 buffer 與頻寬 |
| GPU / DSP / AI accelerator 設計或軟體（CUDA driver、compiler） | 加分 | 無近期補法 |
| On-chip bus、記憶體管理、功耗分析 | 加分／尤佳 | 與 Designer 補強共用 |

### 8. MediaTek AI 處理器建模（62）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| RTL design 經驗 | 必要（條件 1，未寫年資與程度） | 把 CModel vs RTL 驗證經驗講具體；或做一個小型 RTL 專案 |
| AI model 開發與 AI 負載理解 | 職責 | 同群聯 AI 補強 |
| System-level HW/SW bottleneck analysis | 職責 | 用 VDK trace 找 FW hot path 做成案例 |
| Chip-level architecture design | 加分（二擇一，另一為 system-level SC modeling，你有） | 無近期補法 |
| HW emulator 經驗 | 加分（SW-based emulator 你有 VDK） | 無近期補法 |

### 10. MediaTek 記憶體系統架構（55）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 記憶體系統、架構設計/分析、模型開發基礎知識 | 必要（基本要求，部分符合） | 補 DRAM 基礎，說明 NAND controller 經驗的範圍 |
| SRAM / DRAM（DDR、LPDDR）架構設計與最佳化 | 進階（為佳） | 讀 DRAM 時序、bank、row buffer 基礎 |
| 記憶體系統效能 / 能耗模型建立 | 職責 3 | 做簡單 DRAM controller 模型 |
| 運算單元與記憶體互動分析（CPU/GPU/NPU/DSP） | 職責 1 | 讀 roofline model，套到一個 workload |
| 真實環境功耗 / 效能分析 | 進階（為佳） | 無近期補法 |
| 競爭分析（competitive analysis） | 職責 | 無近期補法 |

### 11. 千逢 NPU Modeling（42）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| NPU 架構設計與實作（3 年） | 必要（年資門檻） | 無法短期補 |
| PE array、memory hierarchy、systolic array、矩陣乘 | 必要 | NPU 入門與小型 C model |
| Bit-true C model（算術、記憶體存取） | 必要 | 定點運算範例 |
| Cycle-accurate model（pipeline、data dependency） | 必要 | timing 建模小專案 |
| 對參考神經網路 workload 驗證 | 必要 | 無近期補法 |

### 12. MediaTek 6G/5G 基頻架構（40）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 無線通訊或 modem 領域（5G/6G、WiFi PHY/MAC、modem FW）二選一 | 必要（條件 2） | 無法短期補 |
| 或：系統效能 / 功耗分析與管理經驗 | 必要（替代） | 見效能建模補強，但仍偏弱 |
| PPA 架構優化、HRT latency 分析 | 職責 | 無近期補法 |
| 產出量化報告驅動架構決策 | 職責 3 | 無近期補法 |

條件 1（數位設計/系統/架構建模實務，含 ESL/SystemC、SW/FW control-path simulation）你符合。

### 13. 晶心 CPU Solution Engineer（36）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| RISC-V / CPU IP 軟體 toolchain 與 build 環境 | 職責 1、2 | 讀 RISC-V toolchain 與 build 流程 |
| CI/CD workflow 建置 | 職責 1 | 以個人專案 CI 說明 |
| 客戶技術顧問、售前支援、教育訓練、技術教學文件 | 職責 3–8 | 工作上沒做過，此為角色轉換 |
| 英文口說（聽說讀寫中等） | 條件（你 TOEIC 780，偏弱） | 準備英文自我介紹 |
| 出差（一年約三個月以下） | 條件 | 個人意願，非能力 |

### 14. 耐能 Embedded Platform Software（28）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| Embedded driver 與 middleware 開發 | 必要 | 無法短期補 |
| OS platform ownership（bring-up、設定、客製） | 必要 | 無 |
| FPGA 平台 porting、bring-up、驗證 | 必要 | 無 |
| Device driver、kernel-level debug | 必要 | 無 |
| 系統效能、boot time、可靠性優化 | 職責 | 無 |
| 技術領導與跨團隊協調 | 職責 10 | 以 Chief Engineer 與 mentor 經驗說明 |

### 15. 百仕聯 Lead Vector Compute Architect（10）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 6 年以上資料平行微架構經驗 | 必要（年資） | 無 |
| GPU / CPU / NPU 微架構、ISA、out-of-order、occupancy 優化 | 必要 | 無 |
| 工作負載特性分析與 profiling、效能建模 | 必要 | 無 |
| 記憶體階層與 cache coherency 架構 | 必要 | 無 |
| RTL 設計與硬體驗證方法 | 必要 | 無 |
| 技術領導與產品路線規劃 | 必要 | 無 |

### 缺口共通項（出現次數）
| 能力 | 出現在幾份 JD | 優先度 |
|---|---|---|
| Timing / 效能建模與 profiling | 10 份（#3–#5、#7–#12、#15） | 最高，一個小專案同時影響多份 |
| AI / NPU 領域知識 | 5 份（#6–#9、#11） | 高，但需較長時間 |
| Bus / interconnect 與記憶體系統 | 5 份（#4、#5、#7、#9、#10） | 中 |
| RTL 設計 / Verilog 層級建模 | 4 份（#4 加分、#8 必要、#11、#15） | 中 |
| CI/CD | 3 份（#1–#2、#13） | 低（有個人專案說法） |
| OS / driver / FPGA | 1 份（#14） | 不補，不投 |

## 結論與投遞順序

1. 先投 #1、#2（MediaTek VDK）。這是唯一 A 級，且履歷已針對它調整（`mediatek/resume-mediatek-vdk.tex`）。
2. 第二批：#4 MediaTek Performance 驗證（條件寬鬆、你有興趣）、#8 MediaTek AI 處理器建模（條件區完整、應徵人數少、你有興趣；RTL 一條靠 CModel vs RTL 驗證經驗說明），以及 #3 耐能 Co-Simulation、#5 MediaTek Designer、#7 群聯竹南。#6 耐能 C-Model 地點同 #3，可一併投，但內容相對平淡。
3. 其餘 C 級（#9、#10）先不投，等補強後再看（見下節）；D 級不投。
4. #4、#8 履歷不用先做 timing model 才能投；先投，面試前再補。履歷不要寫成效能建模或 RTL 設計經驗。

## 哪些補強會明顯改變分數

| 補強 | 影響的職缺 | 預估變化 |
|---|---|---|
| 做一個小型 timing model（LT + `b_transport` delay、quantum、再加一個 AT 版本，並量 latency / throughput） | #5 Designer、#4 Performance、#7/#9 群聯、#1/#2 的 AT 加分 | #5 +8~10、#4 +6~8（可補性與領域面向）、群聯 +6~8 |
| 找回 simulation speed 的加速倍數（舊 profiling 報告或 commit 紀錄） | 所有 VDK 與 Designer 類 | 面試說服力提升，不改變分數 |
| 補 RTL design 小專案或把現有 CModel vs RTL 驗證寫成具體成果 | #3 耐能 Co-Sim、#8 MediaTek AI、#4 Performance（加分） | #3 +4、#8 +6、#4 +2 |
| 補 AI/NPU 基礎（DL framework、operator、tiling） | 群聯、#8、#11 | 群聯 +6~8 |

沒有補強前，不要把履歷的 Skills 寫成建模或效能分析經驗（見 `tasks/lesson.md`、`prep-notes.md` 第四部分）。
