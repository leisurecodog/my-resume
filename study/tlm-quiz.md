# TLM-2.0 LT、Quantum、DMI 複習題

對應 `tasks/learning-plan.md` 的 TLM-2.0 項目，完成標準：能畫出 read/write 流程並解釋加速原理。

用法：先只看題目，用講的方式回答（像在面試現場），講完再展開參考答案對照。每題最後的「上次的弱點」是 2026-10-20 第一次口試的紀錄。

情境題請用三段式回答：**元件 + 事件 + 軟體看到的現象**。

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
- 提示：target 在 `b_transport` 回應裡呼叫 `trans.set_dmi_allowed(true)`。

**2. 作廢情境（要講具體情境，不要只講類別）**

- **Boot remap**：開機時位址 0 映射到 boot ROM，bootloader 寫 remap register 後位址 0 改成 DRAM。CPU 的舊指標還指向 ROM，不作廢就會繼續從 ROM 抓指令。
- **Debugger 設 watchpoint**：target 要看到每次存取才能觸發中斷，但 DMI 存取繞過 `b_transport`，target 根本不知道。必須先作廢，讓存取改回走 transport。
- 其他：TrustZone 或 MPU 權限切換、memory model 換了底層 backing store。

**3. 作廢路徑**

target 呼叫 `invalidate_direct_mem_ptr(start, end)`，走 backward path。bus 要把位址範圍轉成全域位址，而且因為 bus 不知道哪些 initiator 拿著指標，通常要**廣播給所有 initiator**。

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

## 下一輪可以加考的題目

- AT 細節：畫出一筆 AT READ 的四個 phase 時序，標出每一步是 fw 還是 bw、回傳哪個 `tlm_sync_enum`。
- `TLM_COMPLETED` 提前結束的情境：什麼樣的 target 會直接回 `TLM_COMPLETED`？
- 實作驗證：用 C++ 練習第 4 步寫一個 initiator/target，分別量「每筆 `wait`」、「加 quantumkeeper」、「加 DMI」三種的模擬時間。
