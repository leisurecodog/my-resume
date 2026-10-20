# TLM-2.0 LT、Quantum、DMI 複習題

對應 `tasks/learning-plan.md` 的 TLM-2.0 項目，完成標準：能畫出 read/write 流程並解釋加速原理。

用法：先只看題目，用講的方式回答（像在面試現場），講完再展開參考答案對照。每題最後的「上次的弱點」是 2026-10-20 第一次口試的紀錄；Q6–Q8 是之後補的，還沒考過。

情境題請用三段式回答：**元件 + 事件 + 軟體看到的現象**。

Q4 與 Q6–Q8 的參考答案已對照 SystemC 2.3.3 原始碼核對過（`~/cpp_practice/side_project/uArch/systemc-2.3.3`），核對範圍和沒核對到的地方見文末「核對紀錄」。

---

## Q1：一筆 READ 的完整路徑

在 LT 模式下，CPU（initiator）透過 bus（interconnect）讀 memory（target）的某個位址。

1. 這筆 READ 依序經過哪些元件、呼叫了哪些函式？generic payload 裡至少要設定哪幾個欄位？
2. `delay`（`sc_time&` 參數）在哪些地方會被加上去？
3. 函式 return 回到 initiator 之後，誰負責 `wait`？有哪兩種做法？

<details>
<summary>參考答案</summary>

**1. 路徑與 payload**

```
Initiator (CPU)                 Interconnect (bus)             Target (memory)
     |-- b_transport(trans, delay) --->|                              |
     |                                 | address decode，              |
     |                                 | 全域位址改成 target 本地 offset |
     |                                 |-- b_transport(trans, delay) ->|
     |                                 |                              | memcpy(data_ptr, mem+addr)
     |                                 |                              | delay += 存取延遲
     |                                 |                              | response = TLM_OK_RESPONSE
     |                                 |<------------ return ---------|
     |                                 | address 改回原值               |
     |<------------ return ------------|                              |
     | 檢查 response                    |                              |
```

payload 欄位：

- `set_command(TLM_READ_COMMAND)`
- `set_address(addr)`
- `set_data_ptr(buf)`：READ 時 target 把資料寫進 initiator 給的這塊 buffer。
- `set_data_length(len)`
- `set_response_status(TLM_INCOMPLETE_RESPONSE)`：initiator 先設 INCOMPLETE，target 改成 OK，initiator 回來後檢查。

**2. `delay` 在哪裡加**

target（存取延遲）和 interconnect（bus latency、arbitration）都可以加。大家在同一個 `sc_time&` 上累加，過程中通常不呼叫 `wait`。

**3. 誰 `wait`**

initiator。兩種做法：

- (a) 立刻 `wait(delay)`：簡單，但每筆 transaction 都 context switch 一次。
- (b) 累加到 local time，超過 quantum 才 `sync()`：temporal decoupling（見 Q3）。

target 在 `b_transport` 裡 `wait` 是規範允許的。一般 LT target 不這樣做，因為會打斷 initiator 的時間累加、拖慢速度；但也正因為它會讓 initiator 在這裡同步，有時被刻意用來強制 sync（見 Q3 第 3 小題）。

**30 秒版本（背到能直接講）：**
「initiator 建 payload（command、address、data ptr、length、response 設 INCOMPLETE）→ 呼叫 `b_transport(trans, delay)` → bus decode 並改 address、加 bus delay → target memcpy、加存取延遲、設 OK → 一路 return → initiator 檢查 response，然後 `wait(delay)` 或累加進 quantum。」

</details>

**上次的弱點：** 只答到「init → bus → target、address、slave 加 delay、init wait」，太簡略。缺 payload 其他欄位、bus 也會加 delay、兩種 wait 做法。

---

## Q2：LT vs AT

1. AT 跟 LT 在介面上差在哪？用的是哪個函式、有哪幾個 phase？
2. 什麼樣的建模需求一定要用 AT，LT 做不到？請舉一個具體例子。
3. VDK 這類虛擬平台（給軟體團隊跑 OS 和 driver）通常選 LT 還是 AT？為什麼？

<details>
<summary>參考答案</summary>

**1. 介面**

- AT 用 `nb_transport_fw` 和 `nb_transport_bw`，四個 phase：BEGIN_REQ、END_REQ、BEGIN_RESP、END_RESP。
- 方向：BEGIN_REQ、END_RESP 走 fw（initiator 往 target）；END_REQ、BEGIN_RESP 走 bw（target 回呼 initiator）。
- 回傳值 `tlm_sync_enum`：
  - `TLM_ACCEPTED`：收到了，之後用另一個方向回覆。
  - `TLM_UPDATED`：phase 在這次呼叫中被推進。
  - `TLM_COMPLETED`：整筆 transaction 直接結束。
- 四個 phase 不一定全部走完，可以用 `TLM_UPDATED` 或 `TLM_COMPLETED` 提前結束。

**2. 一定要 AT 的情況**

類別：pipelining、outstanding transaction、bus contention。

具體例子：「DMA 和 CPU 同時存取 DDR controller，要量 CPU 的 read latency 被 DMA 拖慢多少。LT 的 `b_transport` 一次呼叫就完成整筆 transaction，request 和 response 之間沒有可以插入其他事件的時間點，所以建不出 arbitration 和排隊。AT 用 END_REQ 的時機表達『bus 何時接受下一個 request』，contention 才建得出來。」

**3. VDK 選 LT**

「軟體團隊在乎功能正確和開機速度（Linux boot、driver bring-up），不需要 transaction 之間的時序互動。LT 加上 quantum 和 DMI 可以跑到接近真實時間的數量級；AT 每筆 transaction 要多次呼叫和 event，慢很多。」

注意：不要說「AT 是 cycle 精度」，AT 是 approximately-timed，也不是 cycle-accurate。

</details>

**上次的弱點：** 第 2 小題給了類別沒給例子；第 3 小題說「不需要 cycle 精度」，容易讓人以為 AT 是 cycle-accurate。

---

## Q3：quantum 的代價

1. quantum 設太大會出什麼錯？請舉一個具體情境：哪兩個元件、發生了什麼事、軟體看到什麼現象。
2. quantum 設太小又會怎樣？
3. 平台上有個元件必須很準時回應（例如 timer interrupt），但整體又想保持大 quantum，有什麼做法？

<details>
<summary>參考答案</summary>

**1. 太大**

情境：DMA 寫完資料後發 interrupt，但 CPU 還在 quantum 內往前跑，晚一段時間才看到 interrupt。軟體可能看到 driver timeout，或讀到舊資料。

機制：

- CPU 的 local time 領先全域時間，只有 `sync()` 時才回到 kernel 檢查 event，所以 interrupt 最多延遲**一整個 quantum**。
- 讀到舊資料的原因是時間順序被打亂：CPU 在 local time t+800ns 讀 buffer，DMA 應該在全域 t+300ns 寫入，但 kernel 還停在 t，DMA 根本還沒跑。

**2. 太小**

`wait` 次數變多、context switch 增加，速度掉回接近沒用 quantum。quantum 縮到接近 0 就等於每筆都 sync，退化成沒有 temporal decoupling。quantum 是速度和時序準確度之間的取捨參數，實務上從大往小調，直到軟體行為正確為止。

**3. 保持大 quantum 又要準時**

- 存取有副作用的 peripheral（timer、interrupt controller 的 register）前先 `qk.sync()`。一般 memory 存取不用。
- target 在 `b_transport` 裡 `wait(delay)`：`b_transport` 跑在 initiator 的 thread 上，所以等於強迫 initiator 在這裡 sync。
- CPU 執行 WFI（wait for interrupt）時立即 sync。
- per-initiator quantum：quantumkeeper 預設用全域的 `tlm_global_quantum`，可以覆寫 `compute_local_quantum()` 讓個別 initiator 用較小的值。

**接自己的案例：** 第 2 小題講完可以接「我在 msg IP 上做過類似取捨：原本每個 clock cycle 都 `wait`，改成較粗的 `wait(time, SC_MS)`，減少 scheduler 喚醒次數。」

</details>

**上次的弱點：** 這題答得最好。可以補「最壞延遲 = 一個 quantum」這句量化說法，以及第 3 小題的具體實作方式。

---

## Q4：DMI 的生命週期

1. initiator 怎麼取得 DMI 指標？呼叫哪個函式、拿到哪些資訊？target 怎麼提示 initiator 可以申請 DMI？
2. DMI 指標什麼時候必須作廢？請舉兩個具體情境。
3. 作廢由誰發起？走哪條路徑、呼叫哪個函式？中間有 bus 時，bus 要做什麼？
4. 用了 DMI 之後，時間（latency）要怎麼算？

<details>
<summary>參考答案</summary>

```
第一次：
Initiator --get_direct_mem_ptr(trans, dmi_data)--> Interconnect --> Target
Initiator <-- dmi_data: { 指標, start/end addr, 讀寫權限, read/write latency } --

之後（位址在 DMI 範圍內）：
Initiator: memcpy(buf, dmi_ptr + (addr - start), len);   ← 不走 bus，不呼叫 b_transport
           local_time += dmi_read_latency;

失效時（backward path）：
Target --invalidate_direct_mem_ptr(start, end)--> Interconnect --> Initiator 丟掉指標
```

**1. 取得**

- 呼叫 `get_direct_mem_ptr(trans, dmi_data)`。payload 裡設好 address 和 command（要讀還是要寫），回傳 `bool` 表示 target 是否同意。
- 拿到：指標、位址範圍、讀寫權限、read/write latency。
- target 給的範圍和權限可能比要求的大或小，initiator 要檢查 `is_read_allowed()` 和 `is_write_allowed()`。
- 回程經過 bus 時，bus 把 target 的本地位址範圍轉回全域位址，並裁切到自己 address map 裡分給這個 target 的那段。
- 提示：target 在 `b_transport` 回應裡呼叫 `trans.set_dmi_allowed(true)`。initiator 可以忽略這個提示，但 target 有**義務**設定：如果同一位址、同一 command 的 DMI 請求會成功，target 就必須把它設成 true。
- initiator 每次呼叫前要給一個剛初始化的 `tlm_dmi`（新建，或對舊的呼叫 `init()`）。

**2. 作廢情境（要講具體情境，不要只講類別）**

- **Boot remap**：開機時位址 0 映射到 boot ROM，bootloader 寫 remap register 後位址 0 改成 DRAM。CPU 的舊指標還指向 ROM，不作廢就會繼續從 ROM 抓指令。
- **Debugger 設 watchpoint**：target 要看到每次存取才能觸發中斷，但 DMI 存取繞過 `b_transport`，target 根本不知道。必須先作廢，讓存取改回走 transport。
- 其他：TrustZone 或 MPU 權限切換、memory model 換了底層 backing store。

**3. 作廢路徑**

target 呼叫 `invalidate_direct_mem_ptr(start, end)`，走 backward path。bus 要把位址範圍轉成全域位址，而且因為 bus 不知道哪些 initiator 拿著指標，通常要**廣播給所有 initiator**（原始碼註解：安全的做法是呼叫每一個接上的 initiator）。

- 整個 memory map 都變了（例如 bus remap）時，用範圍 `0` 到 `(sc_dt::uint64)-1` 表示全部作廢，initiator 必須丟掉所有 DMI 指標。
- 在 `invalidate_direct_mem_ptr` 裡面**不可以**直接或間接呼叫 `get_direct_mem_ptr`。

**4. 時間**

每次存取把 DMI 的 read/write latency 加到 local time。DMI 不經過 `b_transport`，target 沒機會在裡面 `wait`，所以 initiator 仍要照常 `qk.inc()` 和檢查 `need_sync()`，否則純 DMI 的迴圈可能長時間不交出控制權。

</details>

**上次的弱點：** 第 2 小題只答「memory map 改變、權限改變」，是類別不是情境；第 3 小題漏了「廣播給所有 initiator」。

---

## Q5：總結題（面試收尾常見）

「用一分鐘跟我講，LT、quantum、DMI 各自省掉了什麼成本？三個都開了，平台上還有哪些東西是準的、哪些不準？」

用講的語氣回答。

<details>
<summary>參考答案</summary>

**省掉的成本**

- LT：省掉逐 cycle 的 signal 和 phase 交握，一次函式呼叫完成一筆 transaction。
- quantum：省掉每筆 transaction 後的 `wait` 和 context switch。
- DMI：省掉 payload 建立、bus decode 和整條函式呼叫鏈，直接 memcpy。
- 三者疊加：LT 讓一筆變成一次呼叫，quantum 減少呼叫之間的 `wait`，DMI 連呼叫本身都省掉。

**哪些準（要加前提）**

「前提是軟體有正確同步（用 interrupt 或 flag 等 DMA 完成，不靠時間假設），而且平台在存取 peripheral 前會 sync。在這前提下，功能行為和資料內容是準的。軟體如果靠『等夠久應該就好了』這種時序假設，在大 quantum 下可能出錯；不過這種 bug 在真實硬體上通常也是 bug，所以虛擬平台反而能幫忙抓出來。」

**哪些不準**

- interrupt 時機（最多延遲一個 quantum）
- 多個 initiator 之間的存取順序
- bus contention
- 絕對效能數字：只能當數量級參考，不能做效能簽核
- DMI 存取對 bus 和 target 不可見：tracing、存取次數統計不完整

</details>

**上次的弱點：** 說「資料內容是準的」，跟 Q3 自己舉的「讀到舊資料」矛盾，要加上前提。

---

## Q6：debug transport（`transport_dbg`）

VDK 的 debugger 要顯示 memory 內容、修改某個 register。

1. 這類存取應該走 `b_transport`、DMI 還是 `transport_dbg`？為什麼？
2. `transport_dbg` 的函式簽名跟 `b_transport` 差在哪？回傳值代表什麼？
3. target 實作 `transport_dbg` 時有哪些不能做的事？請用一個 peripheral register 舉具體情境。
4. 中間有 bus 時，bus 要怎麼處理 `transport_dbg`？

<details>
<summary>參考答案</summary>

**1. 走 `transport_dbg`**

debugger 的存取不應該影響模擬：不能讓模擬時間前進、不能觸發硬體副作用、也不該被 bus 統計或 trace 算進去。

- `b_transport` 會累加 delay、可能觸發 target 的行為。
- DMI 只適用於能給出指標的一般 memory，peripheral register 通常不給 DMI；而且 debugger 不一定在 initiator 的 process 裡執行。
- `transport_dbg` 就是為這個用途設計的：不計時間、不產生副作用。

**2. 簽名**

```cpp
void         b_transport (tlm_generic_payload& trans, sc_time& delay);
unsigned int transport_dbg(tlm_generic_payload& trans);
```

- 沒有 `delay` 參數，因為 debug 存取不花模擬時間。
- 回傳值是**實際讀寫的 byte 數**。例如要求 16 byte，但位址範圍在第 8 byte 就超出 target 的範圍，就回傳 8。回傳 0 代表 target 不支援或位址無效。
- 主要用 payload 的 command、address、data ptr、data length，以及可能影響存取的 extension。data 一律用 host 機器的 endianness。

**3. target 不能做的事**

原始碼註解明訂：`transport_dbg` 執行過程中不能有副作用、不能 `wait`、不能 notify event。

- 不能呼叫 `wait`。理由之一是 debugger 可能在任何時間點呼叫，不一定在 SC_THREAD 裡。
- 不能讓模擬時間前進，也不能 notify event 去觸發其他行為。
- 不能有硬體副作用。

具體情境：UART 的 RX FIFO data register，一般讀取會 pop 一筆資料；interrupt status register 是 read-to-clear，一般讀取會清掉 interrupt。debugger 打開 register view 時如果走一般讀取，畫面一刷新就把 FIFO 資料吃掉、把 interrupt 清掉，軟體接著會漏收資料或漏掉 interrupt。`transport_dbg` 要回傳目前的值，但不 pop、不清除。

debug **寫**可以改 memory 或 register 的內容（這是 debugger 改值的目的），但同樣不應觸發寫入的副作用，例如不應因此啟動 DMA。

**4. bus 的處理**

跟 `b_transport` 一樣做 address decode，把全域位址轉成 target 的本地 offset 再轉送給對應的 target。不加 delay、不做 arbitration、不算進 bus 統計。如果要求的範圍跨過兩個 target，常見的簡單實作是只轉送給第一個，回傳值會小於要求的長度，由呼叫端自行處理剩下的部分。這是實作上的選擇，標準只規定回傳值必須小於等於要求的 byte 數。

**三種存取路徑對照**

| | `b_transport` | DMI | `transport_dbg` |
|---|---|---|---|
| 用途 | 一般功能存取 | 高速存取一般 memory | debugger、載入程式、檢查狀態 |
| 時間 | 累加 delay | 自己加 DMI latency | 不計時間 |
| 副作用 | 有 | 無（只是 memory） | 不能有 |
| 經過 bus | 是 | 只有取得指標時 | 是，但不加 delay、不統計 |

</details>

**上次的弱點：** 尚未考過。

---

## Q7：Socket 與 binding

1. `simple_initiator_socket`、`simple_target_socket` 和最底層的 `tlm_initiator_socket`、`tlm_target_socket` 差在哪？為什麼大部分 model 用 simple socket？
2. 一個 bus 要接 2 個 initiator（CPU、DMA）和 3 個 target，bus 上要用什麼 socket？callback 怎麼知道 transaction 是從哪一個 socket 進來的？
3. 寫出 CPU → bus → memory 的 binding 程式碼。如果 target 沒有註冊 `get_direct_mem_ptr` 或 `transport_dbg`，被呼叫時會怎樣？
4. 結合你自己的經驗：你把 fast model IP 接到 bus 時，IP 用的是哪種 socket？接在 bus 的哪裡？

<details>
<summary>參考答案</summary>

**1. simple socket vs 底層 socket**

- 底層的 `tlm_initiator_socket` 和 `tlm_target_socket` 要求 module 自己實作完整的介面：target 要實作 fw 介面的全部函式（`b_transport`、`nb_transport_fw`、`get_direct_mem_ptr`、`transport_dbg`），initiator 要實作 bw 介面（`nb_transport_bw`、`invalidate_direct_mem_ptr`）。用不到的也要寫空的實作。
- `simple_initiator_socket<Module>` 和 `simple_target_socket<Module>`（在 `tlm_utils` 裡）讓你只**註冊需要的 callback**，例如 `socket.register_b_transport(this, &Memory::b_transport)`，其他函式由 socket 提供預設行為。
- `simple_target_socket` 還會在 blocking 和 non-blocking 之間**雙向自動轉換**：只註冊 `b_transport` 的 target，也能接受 AT initiator 的 `nb_transport_fw` 呼叫（socket 內部 spawn 一個 thread 去呼叫 `b_transport`）；反過來，只註冊 `nb_transport_fw` 的 target 也能接受 `b_transport`（socket 內部用 PEQ 和 event 等 transaction 結束）。
- `passthrough_target_socket` 不做轉換，適合 bus 這種只負責轉送的元件。

**2. 多個 initiator 和 target 的 bus**

- bus 用 `multi_passthrough_target_socket` 接所有 initiator，用 `multi_passthrough_initiator_socket` 接所有 target。
- 這兩種 socket 可以 bind 多次，callback 會多一個 `int id` 參數，表示是第幾個 bind 上來的 socket：

```cpp
void Bus::b_transport(int id, tlm_generic_payload& trans, sc_time& delay) {
    int target_nr = decode(trans);                 // 依 address 決定 target，並改成本地 offset
    init_socket[target_nr]->b_transport(trans, delay);
    // 位址改回原值
}
```

- `invalidate_direct_mem_ptr` 從 target 回來時，bus 要轉成全域位址，然後對所有 initiator 廣播：`for (i...) targ_socket[i]->invalidate_direct_mem_ptr(start, end);`

**3. binding**

```cpp
cpu.socket.bind(bus.targ_socket);    // initiator socket 綁到 bus 的 target socket
bus.init_socket.bind(mem.socket);    // bus 的 initiator socket 綁到 memory
```

- 一律是 initiator socket 去 bind target socket。
- socket 的 BUSWIDTH 模板參數兩端要一致，否則編譯失敗。
- 沒有 bind 的 socket 在 elaboration 時會報錯。
- 沒有 bind 的原因：socket 底層是 `sc_port`，預設 policy 是 `SC_ONE_OR_MORE_BOUND`，至少要 bind 一次。
- simple、passthrough、multi_passthrough 這幾種 target socket，沒有註冊的 callback 都走同樣的預設行為：`get_direct_mem_ptr` 回傳 `false`（不給 DMI），`transport_dbg` 回傳 `0`（不支援 debug 存取）。initiator 要能處理這兩種結果。
- simple target socket 如果 `b_transport` 和 `nb_transport_fw` 都沒註冊，收到 transaction 時會報錯。

**4. 自己的經驗**

這題沒有標準答案，要用你實際的工作內容回答。面試前先確認：

- msg IP 對外是 initiator、target，還是兩者都有？
- 用的是 simple socket、multi socket，還是 VDK 工具提供的 wrapper？
- 接到哪一條 bus、在 memory map 上的位址範圍是什麼？

記不清楚就照實說「透過 VDK 工具接到 bus」，不要猜細節。

</details>

**上次的弱點：** 尚未考過。

---

## Q8：Generic payload 進階

1. byte enable 是什麼？initiator 要設定哪些欄位？什麼情境會用到？
2. streaming width 是什麼？跟 data length 是什麼關係？什麼情境會用到？
3. target 遇到不支援或錯誤的 transaction，應該回哪些 response status？請舉三個情境。initiator 收到錯誤時該怎麼辦？
4. 想在 payload 帶 AXI 的 transaction ID 或 secure 位元這類 protocol 專屬資訊，要怎麼做？
5. memory manager（`tlm_mm_interface`）是做什麼的？為什麼只用 `b_transport` 時常常可以不用，用 AT 時通常一定要？

<details>
<summary>參考答案</summary>

**1. byte enable**

- 設定 `set_byte_enable_ptr(ptr)` 和 `set_byte_enable_length(len)`。每個 byte 對應一個 enable 值：`0xff` 表示這個 byte 要存取，`0x00` 表示不存取。
- byte enable 的長度可以比 data length 短，此時 enable 的 pattern 會重複套用（原始碼裡就是用 `m_byte_enable[i % m_byte_enable_length]` 取值）。
- 情境：CPU 對 32-bit register 只寫其中 1 個 byte（例如 `strb` 指令），其他 byte 的內容不能被改到。
- 不使用時把指標設成 `0`。

**2. streaming width**

- streaming width 是每一拍（beat）傳幾個 byte。每一拍都從 payload 的 address 開始，所以 streaming width 小於 data length 時，等於對同一段位址範圍存取好幾次。
- 一般的連續存取要把 streaming width 設成等於 data length。
- **陷阱**：`tlm_generic_payload` 建構時 streaming width 預設是 **0**，不會自動等於 data length。initiator 忘了設的話，像 SystemC 範例裡的 memory target 檢查 `streaming_width != data_length` 就會回 `TLM_BURST_ERROR_RESPONSE`。SystemC 範例的 initiator 都會明確寫 `trans.set_streaming_width(trans.get_data_length())`。
- 情境：寫 FIFO 型 peripheral。對同一個 4-byte data register 連續寫 64 byte，就是 data length = 64、streaming width = 4。

**3. 錯誤處理**

| 情境 | response status |
|---|---|
| 位址落在 target 範圍外，或是沒有 register 的空洞 | `TLM_ADDRESS_ERROR_RESPONSE` |
| 寫入唯讀 register，或 target 不支援該 command | `TLM_COMMAND_ERROR_RESPONSE` |
| target 不支援 byte enable，但 payload 帶了 byte enable | `TLM_BYTE_ENABLE_ERROR_RESPONSE` |
| target 不支援 streaming width 小於 data length 的存取 | `TLM_BURST_ERROR_RESPONSE` |
| 其他錯誤 | `TLM_GENERIC_ERROR_RESPONSE` |

initiator 一定要檢查 `trans.is_response_error()`。注意它的實作是 `response_status <= 0`，所以 `TLM_INCOMPLETE_RESPONSE`（值為 0）也算錯誤：target 忘了把 status 設成 OK，initiator 就會當成失敗。CPU model 通常把它轉成處理器的例外，例如 ARM 的 data abort 或 bus fault，讓軟體看到跟真實硬體一致的錯誤行為。不檢查的話，軟體會讀到垃圾值卻不知道出錯了。

**4. extension**

- 定義一個繼承 `tlm_extension<T>` 的 class，必須實作 `clone()` 和 `copy_from()`。
- initiator 用 `trans.set_extension(ext)` 附上，target 用 `trans.get_extension(ext)` 取出。
- 不認得這個 extension 的元件可以直接忽略它（ignorable extension），所以不影響和其他 generic payload model 的互通。
- 例子：AXI ID、secure 或 non-secure 位元、master ID。

**5. memory manager**

- payload 物件的生命週期問題：誰配置、誰釋放、什麼時候可以重用。
- 有設 memory manager 時，用 `acquire()` 和 `release()` 做 reference counting，計數歸零時呼叫 memory manager 的 `free()`，通常是放回 pool 重用。
- 沒有設 memory manager 就呼叫 `acquire()` 會觸發 assert（原始碼是 `sc_assert(m_mm != 0)`）。
- 放回 pool 前通常呼叫 `reset()`，它會清掉 extension，但不會重設 address、command 這些欄位，下一次使用前要自己重新設定。
- 只用 `b_transport` 時，transaction 在函式 return 時就結束，initiator 可以把 payload 放在 stack 或成員變數上重複使用，所以常常不需要 memory manager。
- AT 的 payload 在 `nb_transport_fw` return 之後還會繼續在其他元件間傳遞，可能同時有好幾筆在進行中，所以需要用 reference counting 確定沒有人在用了才能釋放。

</details>

**上次的弱點：** 尚未考過。

---

## 核對紀錄（2026-10-20）

對照來源：本機 SystemC 2.3.3 原始碼與範例（`~/cpp_practice/side_project/uArch/systemc-2.3.3`）。

- `src/tlm_core/tlm_2/tlm_2_interfaces/tlm_fw_bw_ifs.h`：DMI 與 debug transport 的規則註解（Q4、Q6）。
- `src/tlm_core/tlm_2/tlm_generic_payload/tlm_gp.h`、`tlm_gp.cpp`：response status、byte enable、streaming width 預設值、`is_response_error()`、`acquire()`/`release()`、`reset()`、extension 的 `clone()`/`copy_from()`（Q8）。
- `src/tlm_utils/simple_target_socket.h`、`simple_initiator_socket.h`、`passthrough_target_socket.h`、`multi_socket_bases.h`：callback 預設行為、b/nb 自動轉換、multi socket callback 的 `int id` 參數（Q7）。
- `src/tlm_core/tlm_2/tlm_sockets/tlm_initiator_socket.h`：bind 只接受相同 BUSWIDTH 的 socket，預設 port policy 是 `SC_ONE_OR_MORE_BOUND`（Q7）。
- `examples/tlm/common/src/memory.cpp` 等範例：streaming width 的設定方式與錯誤回應（Q8）。

核對後修正或補充的地方：

- Q8：streaming width 預設是 0，不是 data length（原本沒寫，是常見陷阱）。
- Q8：`is_response_error()` 對 INCOMPLETE 也回傳 true。
- Q7：simple target socket 是雙向轉換（原本只寫了 nb 轉 b）；passthrough 和 multi socket 的預設行為和 simple 相同。
- Q6：bus 跨 target 只轉送第一段是實作選擇，不是標準規定。
- Q4：target 設 DMI hint 是義務；全部作廢用 `0` 到 `(sc_dt::uint64)-1`；不能在 invalidate 裡呼叫 `get_direct_mem_ptr`。

沒有原始碼可核對、依 IEEE 1666 標準的記憶或二手資料寫的部分：

- streaming width「每拍從同一個 address 開始」的語意：只對照到引用 LRM 的論壇與 UVM 文件，沒看到 IEEE 1666 原文。
- 「ignorable extension」的定義：IEEE 1666 的概念，原始碼裡沒有對應註解。
- Q2 的 phase 方向和 `tlm_sync_enum` 語意：這次沒有核對。

---

## 下一輪可以加考的題目

- AT 細節：畫出一筆 AT READ 的四個 phase 時序，標出每一步是 fw 還是 bw、回傳哪個 `tlm_sync_enum`。
- `TLM_COMPLETED` 提前結束的情境：什麼樣的 target 會直接回 `TLM_COMPLETED`？
- 實作驗證：用 C++ 練習第 4 步寫一個 initiator/target，分別量「每筆 `wait`」、「加 quantumkeeper」、「加 DMI」三種的模擬時間。
