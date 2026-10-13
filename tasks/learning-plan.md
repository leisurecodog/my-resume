# 學習計畫（跨職缺）

依據 `JD/fit-ranking.md` 的缺口共通項統計排序。順序是「出現在幾份 JD 的缺口」，不是難易度。
VDK 面試複習（C++14、TLM-2.0、VDK 流程）的細項清單在 `mediatek/prep-notes.md`，這裡不重複。

## 順序

| 順序 | 主題 | 目標 | 細節與做法 | 影響的職缺 |
|---|---|---|---|---|
| 1 | C++14 | 能說明自己 model 的類別設計 | `mediatek/prep-notes.md` 第一部分與第四部分 | VDK、耐能 C-Model（OOP / 設計模式） |
| 2 | TLM-2.0 LT、DMI、quantum | 能畫出 read/write 流程並解釋加速原理 | 同上 | VDK 兩份 |
| 3 | AT / non-blocking | 能說明四個 phase 與回傳值 | 同上，第四部分第 3 項 | VDK（加分）、Designer、Performance 驗證 |
| 4 | Bus 建模 | 會寫簡單 interconnect | 同上，第四部分第 4 項（router + arbiter 小專案） | Designer、Performance 驗證、群聯、記憶體系統 |
| 5 | 效能建模入門 | 能解釋並量測 latency / throughput | 同上，第四部分第 5 項（在 router 加 latency 與 bandwidth） | 10 份 JD，缺口統計第一名 |
| 6 | CI | 能講自己的 CI 流程 | 同上，第四部分第 6 項 | VDK（職責 5）、晶心 |
| 7 | AI / NPU 基礎 | 能說明 CNN / Transformer 的 compute 與 memory 需求、operator tiling | 讀 PyTorch operator 流程；手算 matmul tiling 的 buffer 與頻寬；寫一個 conv 的 C model。長期項目 | 群聯兩份、耐能 C-Model、MediaTek AI 處理器建模、千逢 |
| 8 | 記憶體系統 | 能說明 DRAM bank / row buffer 與 roofline | 讀 DRAM 時序基礎，把 roofline 套到一個 workload | MediaTek 記憶體系統架構 |
| 9 | RTL 小專案 | 能寫簡單 RTL 並與自己的 C model 比對 | 用同一個 router 或 DMA 寫 RTL，與 TLM 版本比對 | MediaTek AI 處理器建模（必要）、Performance 驗證（加分） |
| 10 | C/C++ 基礎題與 bit 操作 | 能在白板上寫出並解釋基礎題與 register field 操作 | C/C++：pointer 與 reference、memory layout、`virtual` 與 vtable、copy / move、`volatile`、`const`、struct 對齊。Bit：mask、set / clear field、endianness、位址對齊。再加約 20 到 30 題簡單到中等的 LeetCode（C++，陣列、字串、linked list、hash map、queue / stack），不練 DP 與進階 graph。每週 2 到 3 題維持手感，面試前兩週加量，總量不超過學習時間約 15% | 所有職缺的技術面（群聯、耐能、千逢較可能出現手寫題） |
| 11 | Co-sim 框架與 bit-true 驗證 | 能說明 C model 與 RTL 如何通訊、同步與自動比對，並解釋定點與浮點差異 | 讀 DPI-C / PLI 基礎，做一個小範例（C model 與簡單 RTL module 以 DPI-C 互呼並比對輸出）；讀 fixed-point 表示與捨入、溢位處理；整理過去 CModel vs RTL 驗證中自己負責的部分 | 耐能 Co-Sim（4 項必要缺口都在此）、千逢、耐能 C-Model |
| 12 | VDK 流程與 debug | 能講清楚 FW 在 VDK 上出 bug 時的 debug 流程 | 依 `mediatek/prep-notes.md` 第三部分清單；實際整理一個你處理過的 bug（現象、gdb / log / trace 怎麼用、root cause、怎麼確認修好）作為可講的案例 | VDK 兩份（JD 第 4 條 solid debugging skills） |

## 缺口統計（對應上表）

| 缺口 | 出現份數 | 對應順序 | 說明 |
|---|---|---|---|
| Timing / 效能建模與 profiling | 10 份 | 3、5 | 最高優先，一個小專案同時影響 Designer、Performance 驗證、群聯、耐能 Co-Sim |
| AI / NPU 領域 | 5 份 | 7 | 高，但耗時長，放在效能建模之後 |
| Bus / interconnect 與記憶體系統 | 5 份 | 4、8 | 4 與第 5 項共用同一個小專案 |
| RTL 設計 | 4 份 | 9 | 中，可與 router 專案共用 |
| Co-sim / bit-true 驗證 | 3 份 | 11 | 中高，耐能 Co-Sim 是 B 級第 1 名，缺口集中在這項 |
| CI/CD | 3 份 | 6 | 低，已有個人專案說法 |
| OS / driver / FPGA | 1 份 | 無 | 不補，不投 |

## 建議做法

- 第 3 到 5 項用同一個 router 專案串起來（AT 版本、interconnect、latency 量測），第 9 項再沿用同一個 router 寫 RTL。
- 第 7、8 項等前面做完再開始。
- 第 10、12 項跟著第 1、2 項一起準備（VDK 是主投）；第 11 項在第 5 項之後、準備投耐能 Co-Sim 前完成。
- 投遞後向 HR 確認技術面形式，再決定第 10 項要加多少量（見 `tasks/progress.md`）。
- 做完才可在履歷寫對應能力，且標明是個人專案（規則見 `mediatek/prep-notes.md`「何時可以投效能相關職缺」）。
- 完成一項後回頭更新 `JD/fit-ranking.md` 的分數與缺口表。

## 進度

- [ ] 1 C++14　[ ] 2 TLM-2.0　[ ] 3 AT　[ ] 4 Bus　[ ] 5 效能建模　[ ] 6 CI　[ ] 7 AI/NPU　[ ] 8 記憶體系統　[ ] 9 RTL　[ ] 10 C/C++ 基礎與 bit　[ ] 11 Co-sim 與 bit-true　[ ] 12 VDK debug
