# JD 適合度評分（2026-10-13）

依據：`JD/` 內 15 份 104 職缺 PDF 的可見文字，對照 `base/resume.tex` 與 `tasks/progress.md` 的自我回答結論。
注意：01、06、07、09、10、11、14、15 的 PDF 在「其他條件」處被「顯示全部」截斷，評分只依可見部分。

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

## 排名

| # | 職缺 | 地點 | 核心 40 | 領域 25 | 條件 10 | 可補 15 | 加分 10 | 總分 | 級 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | MediaTek SystemC/TLM Modeling Engineer (VDK) | 竹北 | 38 | 23 | 10 | 13 | 8 | **92** | A |
| 2 | MediaTek SystemC/TLM Modeling Engineer (VDK) - 2 | 竹北 | 38 | 22 | 10 | 12 | 8 | **90** | A |
| 3 | 耐能 C Model / RTL Co-Simulation and Verification | 台北內湖 | 30 | 17 | 7 | 10 | 7 | **71** | B |
| 4 | MediaTek SystemC Modeling Designer | 新竹市 | 30 | 15 | 10 | 8 | 5 | **68** | B |
| 5 | 耐能 C-Model Engineer (C++) | 台北內湖 | 30 | 16 | 7 | 9 | 5 | **67** | B |
| 6 | 群聯 AI/SoC 架構設計工程師（竹南） | 竹南 | 26 | 15 | 10 | 8 | 7 | **66** | B |
| 7 | 群聯 AI/SoC 架構設計工程師（板橋） | 板橋 | 26 | 15 | 4 | 8 | 7 | **60** | C |
| 8 | MediaTek 數位IC設計工程師（Performance 驗證與分析） | 竹北 | 24 | 14 | 10 | 6 | 4 | **58** | C |
| 9 | MediaTek AI 處理器建模工程師 | 新竹市 | 20 | 11 | 10 | 5 | 9 | **55** | C |
| 10 | MediaTek 運算系統架構工程師（記憶體系統） | 新竹市 | 20 | 12 | 10 | 5 | 3 | **50** | C |
| 11 | 千逢 NPU Modeling Engineer | 竹北 | 18 | 8 | 4 | 5 | 7 | **42** | D |
| 12 | MediaTek 6G/5G 基頻系統架構師 | 新竹市 | 16 | 8 | 8 | 3 | 3 | **38** | D |
| 13 | 晶心 CPU Solution Engineer（亞太） | 新竹市 | 12 | 6 | 6 | 6 | 6 | **36** | D |
| 14 | 耐能 C-Model / Embedded Platform Software Engineer | 竹北 | 10 | 5 | 7 | 3 | 3 | **28** | D |
| 15 | 百仕聯 Lead Vector Compute Architect（GPU） | 新竹市 | 3 | 2 | 2 | 1 | 2 | **10** | D |

## 逐項說明

### A：主投

**1–2. MediaTek SystemC/TLM Modeling Engineer (VDK)（兩份）**
- 吻合：JD 要求的 SystemC/TLM-2.0（LT 即可）、MMIO / interrupt / DMA / register map / state machine、gdb 與 trace debug，全部是你每天做的事。VDK 也是你用的工具。
- 缺口：AT（加分項）、CI/CD automation、bootable vSOC 的 boot FW 經驗。三項都有誠實說法（見 `mediatek/prep-notes.md` 第三部分）。
- 兩份可見的條件清單相同；差別是第 1 份寫 2 年以上、1–2 人，第 2 份寫經歷不拘、1–4 人，且第 2 份的 PDF 沒有顯示工作內容。
- 面試風險：simulation speed 案例會被追問原理與精度取捨。

### B：可投

**3. 耐能 C Model / RTL Co-Simulation and Verification（71）**
- 吻合：C model vs RTL 驗證、自動比對、FSDB/VCD parsing、regression、文件，與你的 Senior Engineer 經歷高度重疊。年資 3 年以上，你符合。
- 缺口：cycle-level profiling、cycle-accurate model、bit-true / 數值比對（NPU 資料型別）、從零架設 co-sim 通訊框架。
- 其他：台北內湖，從竹北通勤是實際成本。履歷沒有明寫「verified C model against RTL」的成果數字，可在此版本補強。

**4. MediaTek SystemC Modeling Designer（68）**
- 之前 `prep-notes.md` 寫「吻合度低」。這次重看：條件清單其實寬鬆（碩士、經歷不拘，SystemC/C++ OOP 為必要，TLM-2.0、虛擬平台、AXI/AHB/CHI 基礎為加分或尤佳），你的履歷全部對得上。
- 缺口在職責：「bus 數位系統建模與性能分析」是第 1 條，而你沒寫過 interconnect model、沒做過 timing 建模。
- 判斷：可投，但面試會問 bus 與效能；你只能誠實說整合與 spec 閱讀層級。

**5. 耐能 C-Model Engineer (C++)（67）**
- 吻合：碩士、C++/Python、OOP 與設計模式、C-Model 開發與自動化測試、文件、與 HW/FW 團隊整合。
- 缺口：NPU 演算法與 bit-true 數值（可見文字沒有要求，但「simulate NPU behavior accurately」會問）。PDF 被截斷，看不到完整條件。
- 其他：台北內湖。

**6. 群聯 AI/SoC 架構設計工程師（竹南，66）**
- 吻合：C/C++、Python、Linux、SystemC 建模（加分）、SSD/UFS 經驗（加分，且你的 NAND controller 與 DMA 經驗直接相關）、規格文件。
- 缺口：深度學習框架與 AI 運算架構（基本條件，只有碩士論文的 DL/CV 經驗）、operator tiling/mapping、效能建模與 profiling。
- 其他：竹南離竹北近。職務偏架構分析而非 IP model，是轉型而非延續。

### C：補強後再投

**7. 群聯（板橋，60）**：職務內容與竹南相同，差在通勤（板橋）。

**8. MediaTek Performance 驗證與分析（58）**
- 吻合：Verilog、C++、Python、SystemC/TLM（加分）、APB/AXI 基礎。
- 缺口：performance sign-off、cycle approximate model、computer architecture 深度、ACE/CHI 實作。這是這份的核心，履歷沒有證據。

**9. MediaTek AI 處理器建模（55）**
- 吻合：加分項（SystemC/TLM-2.0/ESL、C/C++、SW emulator）你幾乎全有。
- 缺口：第一條必要條件是 RTL design experience，你只有 Verilog 技能與 CModel vs RTL 驗證；AI 模型與 HW/SW bottleneck analysis 也沒有。可見文字只列到 bottleneck analysis，之後被截斷。

**10. MediaTek 記憶體系統架構（50）**
- 吻合：碩士、SystemC/C++/Python、記憶體系統基礎知識（NAND controller 不等於 DRAM/SRAM，只算部分）。
- 缺口：DRAM / SRAM 架構與最佳化、真實環境功耗與效能分析、CPU/GPU/NPU 與記憶體互動分析。

### D：不建議

- **11. 千逢 NPU Modeling（42）**：要求 3 年 NPU 架構設計與實作、PE array、systolic array、cycle-accurate 與 bit-true model。你有 C/C++ 與 model 經驗，但沒有 NPU 架構經驗。
- **12. MediaTek 6G/5G 基頻架構（38）**：需要無線通訊／modem 領域，或系統效能與功耗分析經驗（二選一），你兩者都沒有。
- **13. 晶心 CPU Solution Engineer（36）**：職責是 RISC-V 軟體 build 環境、CI/CD、客戶技術顧問、教育訓練、一年最多 3 個月出差。C/C++ 與 SystemC 符合，但角色是 FAE/售前，不是建模。
- **14. 耐能 Embedded Platform Software（28）**：名稱有 C-Model，實際是 embedded driver、OS platform owner、FPGA bring-up、kernel debug。
- **15. 百仕聯 GPU Lead（10）**：要求 6 年以上資料平行微架構經驗與技術領導。

## 每份職缺缺少的能力

「必要」指 JD 明列為必要條件或第一順位職責；「加分」指 JD 列為加分或尤佳。「補法」是面試前可做的事，不代表能補成經驗。

### 1–2. MediaTek VDK（92 / 90）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| AT / non-blocking transport 實作 | 加分 | 用現有 model 寫一個 AT 版 initiator/target，理解四個 phase |
| CI/CD automation（工作上） | 職責第 5 條 | 以個人專案的 CI 說明；整理 regression 觸發流程 |
| Boot FW / bootable vSOC bring-up | 職責第 3 條（bring-up） | 說明 FW 團隊在你的平台上 bring-up，你負責 model 與平台正確性 |
| Kernel-level debug | 無（Linux 環境即可） | 不需補 |

### 3. 耐能 C Model / RTL Co-Simulation（71）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 自行架設 C model 與 RTL 的 co-sim 框架（通訊、同步，例如 DPI / PLI） | 必要（職責 1、2） | 做小型 DPI-C 範例，或釐清過去 co-sim 中你負責的部分 |
| RTL cycle profiling 與效能瓶頸分析 | 必要（職責 3、12） | 用 waveform 量一個 IP 的 cycle，寫成分析 |
| Cycle-aware / cycle-accurate C model | 必要（職責 5） | 同上，補 timing 建模小專案 |
| Bit-true / 數值正確性驗證（定點、浮點差異） | 必要（職責 6） | 讀 fixed-point 基礎，做一個比對範例 |

### 4. MediaTek SystemC Modeling Designer（68）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| Bus / interconnect model（arbiter、decoder、bridge） | 必要（職責 1） | 寫一個簡單 AXI-like interconnect LT model |
| Bus 效能分析（latency、throughput、contention） | 必要（職責 1） | 在上述 model 掛 delay 並量測 |
| 可重用、可延展的模型架構設計 | 職責 2 | 整理自己 6 個 IP 的共用設計 |
| 晶片／平台層高層次建模與平台層文件 | 尤佳 | 文件只寫過 msg IP；說明範圍，不誇大 |

### 5. 耐能 C-Model Engineer（67）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| NPU 運算行為（卷積、矩陣乘、量化）理解 | 職責（simulate NPU accurately） | 讀 NPU / systolic array 入門資料，寫一個 conv 的 C model |
| 設計模式的明確實例 | 必要（OOP + design patterns） | 從自己 code 找出 factory、observer 等實例 |
| Model 效能與精度優化（不只 simulation speed） | 職責 | 以 msg IP 優化案例說明，並準備精度取捨 |

### 6–7. 群聯 AI/SoC 架構（竹南 66 / 板橋 60）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 深度學習框架原理（PyTorch C++ backend、operator） | 必要（基本條件）／加分 | 讀 PyTorch dispatcher 與 operator 流程；碩士論文只算間接經驗 |
| AI 運算負載分析與優化 | 必要 | 挑一個 CNN / Transformer 估算 compute 與 memory 需求 |
| 效能建模與 profiling（SystemC / Python） | 必要（職責）／加分 | timing model 小專案 |
| Operator 分割 / 映射（tiling） | 職責／加分 | 手算一個 matmul tiling 的 buffer 與頻寬 |
| GPU / DSP / AI accelerator 設計或軟體（CUDA driver、compiler） | 加分 | 無近期補法 |
| On-chip bus、記憶體管理、功耗分析 | 加分／尤佳 | 與 Designer 補強共用 |

### 8. MediaTek Performance 驗證與分析（58）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| Pre-silicon performance sign-off 流程 | 必要（職責 1） | 讀 performance sign-off 方法論，了解 workload、KPI、報告 |
| Cycle approximate model 開發 | 必要（職責 3） | timing model 小專案 |
| Computer architecture（pipeline、cache、memory hierarchy）紮實度 | 必要（條件 2） | 複習 cache、coherency、memory ordering |
| ACE / CHI 協定實作層級理解 | 必要（條件 3，只讀過 spec） | 讀 CHI 交易流程，準備能講的案例 |
| RTL design | 加分 | 小型 RTL 專案 |
| Emulation（HW emulator）技術 | 職責 2 | 無近期補法 |

### 9. MediaTek AI 處理器建模（55）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| RTL design 經驗 | 必要（條件 1） | 做一個小型 RTL 專案，或把 CModel vs RTL 驗證經驗講具體 |
| AI model 開發與 AI 負載理解 | 必要（職責） | 同群聯 AI 補強 |
| System-level HW/SW bottleneck analysis | 必要（職責） | 用 VDK trace 找 FW hot path 做成案例 |
| Chip-level architecture design | 加分 | 無近期補法 |
| HW emulator 經驗 | 加分 | 無近期補法 |

### 10. MediaTek 記憶體系統架構（50）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| SRAM / DRAM（DDR、LPDDR）架構與最佳化 | 必要（進階）／職責 | 讀 DRAM 時序、bank、row buffer 基礎 |
| 記憶體系統效能 / 能耗模型建立 | 必要（職責 3） | 做簡單 DRAM controller 模型 |
| 運算單元與記憶體互動分析（CPU/GPU/NPU/DSP） | 必要（職責 1） | 讀 roofline model，套到一個 workload |
| 競爭分析（competitive analysis） | 職責 | 無近期補法 |
| 真實環境功耗 / 效能量測 | 進階 | 無近期補法 |

### 11. 千逢 NPU Modeling（42）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| NPU 架構設計與實作（3 年） | 必要（年資門檻） | 無法短期補 |
| PE array、memory hierarchy、systolic array、矩陣乘 | 必要 | NPU 入門與小型 C model |
| Bit-true C model（算術、記憶體存取） | 必要 | 定點運算範例 |
| Cycle-accurate model（pipeline、data dependency） | 必要 | timing 建模小專案 |
| 對參考神經網路 workload 驗證 | 必要 | 無近期補法 |

### 12. MediaTek 6G/5G 基頻架構（38）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| 無線通訊或 modem 領域（5G/6G、WiFi PHY/MAC、modem FW）二選一 | 必要（條件 2） | 無法短期補 |
| 或：系統效能 / 功耗分析與管理經驗 | 必要（替代） | 見效能建模補強，但仍偏弱 |
| PPA 架構優化、HRT latency 分析 | 必要（職責） | 無近期補法 |
| 產出量化報告驅動架構決策 | 職責 3 | 無近期補法 |
| 定點 / data-flow 演算法建模 | 條件 1 範例之一 | 可挑 SW/FW control-path simulation 說明 |

### 13. 晶心 CPU Solution Engineer（36）
| 缺的能力 | 性質 | 補法 |
|---|---|---|
| RISC-V / CPU IP 軟體 toolchain 與 build 環境 | 必要（職責 1、2） | 讀 RISC-V toolchain 與 build 流程 |
| CI/CD workflow 建置 | 必要（職責 1） | 以個人專案 CI 說明 |
| 客戶技術顧問、售前支援、教育訓練、技術教學文件 | 必要（職責 3–8） | 工作上沒做過，此為角色轉換 |
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
| Timing / 效能建模與 profiling | 10 份（#3–#6、#8–#12、#15 等） | 最高，一個小專案同時影響多份 |
| AI / NPU 領域知識 | 5 份（#5–#7、#9、#11） | 高，但需較長時間 |
| Bus / interconnect 與記憶體系統 | 5 份（#4、#6–#8、#10） | 中 |
| RTL 設計 / Verilog 層級建模 | 4 份（#8 加分、#9 必要、#11、#15） | 中 |
| CI/CD | 3 份（#1–#2、#13） | 低（有個人專案說法） |
| OS / driver / FPGA | 1 份（#14） | 不補，不投 |

## 結論與投遞順序

1. 先投 #1、#2（MediaTek VDK）。這是唯一 A 級，且履歷已針對它調整（`mediatek/resume-mediatek-vdk.tex`）。
2. 第二批：#3 耐能 Co-Simulation、#4 MediaTek Designer、#6 群聯竹南。#5 耐能 C-Model 地點同 #3，可一併投，但內容相對平淡。
3. C 級先不投，等補強後再看（見下節）。

## 哪些補強會明顯改變分數

| 補強 | 影響的職缺 | 預估變化 |
|---|---|---|
| 做一個小型 timing model（LT + `b_transport` delay、quantum、再加一個 AT 版本，並量 latency / throughput） | #4 Designer、#8 Performance、#6/#7 群聯、#2/#1 的 AT 加分 | #4 +8~10、#8 +10~12、群聯 +6~8 |
| 找回 simulation speed 的加速倍數（舊 profiling 報告或 commit 紀錄） | 所有 VDK 與 Designer 類 | 面試說服力提升，不改變分數 |
| 補 RTL design 小專案或把現有 CModel vs RTL 驗證寫成具體成果 | #3 耐能 Co-Sim、#9 MediaTek AI | #3 +4、#9 +6 |
| 補 AI/NPU 基礎（DL framework、operator、tiling） | 群聯、#9、#11 | 群聯 +6~8 |

沒有補強前，不要把履歷的 Skills 寫成建模或效能分析經驗（見 `tasks/lesson.md`、`prep-notes.md` 第四部分）。
