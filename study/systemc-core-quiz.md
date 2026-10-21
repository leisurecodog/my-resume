# SystemC 核心：process、event、delta cycle 與 scheduler 複習題

對應 `tasks/learning-plan.md` 的 SystemC / TLM 基礎，也是 `study/tlm-quiz.md` 的前置：TLM 的 `b_transport`、quantum 都建立在 `wait()`、`sc_event` 和 scheduler 之上。目標是能解釋 SystemC 的執行模型，並說明「每個 clock cycle 都 `wait` 為什麼慢」。

用法跟其他題庫一樣：先自己想或寫在紙上，再展開 `<details>` 對照。

**難度分級**：L1 學習（看懂概念，附提示）→ L2 應用（預測輸出）→ L3 面試（口述）→ L4 深入（連結你的案例，對照原始碼）。從 L1 開始依序做。

**環境與驗證方式**：本機 SystemC 2.3.3，原始碼在 `~/cpp_practice/side_project/uArch/systemc-2.3.3`。本檔所有程式碼都實際編譯、執行過，輸出貼的是實測結果（2026-10-21）。編譯指令：

```
S=~/cpp_practice/side_project/uArch/systemc-2.3.3
g++ -std=c++11 -I$S/include x.cpp -L$S/lib-linux64 -lsystemc -Wl,-rpath,$S/lib-linux64 -o x
```

注意：這份 library 是用 C++11 編的（`sc_api_version_2_3_3_cxx201103L`），用 `-std=c++14` 會在連結階段報 `undefined reference to sc_api_version_...`，要用 `-std=c++11`。程式入口是 `sc_main`，不是 `main`。

---

## 目錄
- [L1：入門 (L1-1–L1-3)](#l1入門)
- [L2：預測輸出 (L2-1–L2-3)](#l2預測輸出)
- [L3：scheduler 口述 (L3-1)](#l3scheduler-口述)
- [L4：simulation speed 案例 (L4-1)](#l4simulation-speed-案例)
- [核對紀錄](#核對紀錄2026-10-21)

---

## L1：入門

### L1-1：`SC_MODULE`、`SC_THREAD`、`SC_METHOD` 差在哪？〔L1〕

1. `SC_THREAD` 和 `SC_METHOD` 各自什麼時候會被執行？函式內的區域變數在多次執行之間能不能保留？
2. 在 `SC_METHOD` 裡呼叫 `wait()` 會怎樣？想「過一段時間再被叫」要用什麼？
3. `dont_initialize()` 是做什麼的？

<details>
<summary>提示</summary>

- `SC_THREAD` 有自己的執行堆疊（coroutine），可以暫停在 `wait()` 然後從同一行繼續。
- `SC_METHOD` 每次被觸發都是從頭呼叫一次、跑到 return 為止，沒有暫停的概念。

</details>

<details>
<summary>參考答案</summary>

1. `SC_THREAD`：模擬開始時執行一次，之後由自己呼叫 `wait()` 暫停、等條件成立後從 `wait()` 的下一行繼續；函式通常包在 `for(;;)` 裡，**區域變數可以跨多次喚醒保留**，因為堆疊還在。`SC_METHOD`：每次靜態敏感度（`sensitive << ...`）或 `next_trigger()` 指定的事件發生時被呼叫一次，從頭跑到 return，**區域變數每次都重新初始化**，要保留的狀態要放成員變數。L2-2 會實跑確認。
2. 執行期錯誤，實測訊息：

   ```
   Error: (E519) wait() is only allowed in SC_THREADs and SC_CTHREADs:
           in SC_METHODs use next_trigger() instead
   ```

   `SC_METHOD` 要改變下一次被觸發的條件，用 `next_trigger(...)`（可傳時間、事件）。`next_trigger` 只決定「下一次」，不會暫停目前這次執行。
3. 預設 `SC_METHOD`、`SC_THREAD` 都會在模擬開始（time 0 的 initialization phase）先跑一次。`dont_initialize()` 讓該 process 跳過這次，只在敏感的事件真的發生時才執行。實測：同一個 signal 上兩個 `SC_METHOD`，`m1` 在 `0 s` 就被呼叫（初始化），`m2` 因為有 `dont_initialize()` 在 `1 ns` signal 變化後才第一次被呼叫：

   ```
   m1 @0 s v=0
m2 @1 ns v=1
m1 @1 ns v=1
m2 @2 ns v=0
m1 @2 ns v=0
   ```

   （`m1`、`m2` 在同一個 delta 裡先後順序，標準沒有保證，不要依賴。）

   `SC_METHOD` 的成本比 `SC_THREAD` 低（沒有 context switch），所以能用 `SC_METHOD` 寫的組合邏輯與簡單反應，常用 `SC_METHOD`。

</details>

---

### L1-2：`wait(10, SC_NS)` 會讓程式睡 10 奈秒嗎？〔L1〕

1. `wait(10, SC_NS)` 之後 `sc_time_stamp()` 會變成什麼？程式真的 sleep 了嗎？
2. **simulation time** 和 **wall-clock time** 差別在哪？
3. `wait(time)` 和 `wait(event)` 各自在什麼情境用？

<details>
<summary>提示</summary>

- simulation time 是模擬器內部維護的一個 64 位元整數計數器，只有 scheduler 能推進。
- 想一想：如果所有 process 都在等，scheduler 下一步做什麼？

</details>

<details>
<summary>參考答案</summary>

1. 該 process 被擱置，`sc_time_stamp()` 在它被喚醒時等於呼叫時間加 10 ns，**不是真的 sleep**：沒有任何 wall-clock 的等待。
2. simulation time 是模型裡的虛擬時間，只有 scheduler 在「沒有 runnable process」時，才把時間跳到下一個 timed event 的時間；wall-clock time 是你等結果的真實時間。一個 process 在 `0 s` 和 `100 ms` 之間若沒事做，simulation time 瞬間跳過，不花 wall-clock；相反地，同一個 simulation time 內，如果有很多 process 被喚醒、很多 delta cycle，wall-clock 就會被花掉。這是 L4-1 的核心。
3. `wait(time)`：固定延遲（模擬 latency、timer、週期輪詢）。`wait(event)`：等某件事發生（interrupt、資料到、signal 變化），不知道會多久。兩個也可以合用：`wait(5, SC_NS, e)` 表示「等 `e`，但最多 5 ns」（timeout），注意參數順序是**時間、單位、事件**。

</details>

---

### L1-3：`sc_event::notify()` 的三種形式〔L1〕

1. `e.notify()`、`e.notify(SC_ZERO_TIME)`、`e.notify(10, SC_NS)` 各叫什麼？分別在什麼時候喚醒等待它的 process？
2. 如果呼叫 `e.notify()` 的時候，沒有任何 process 在等 `e`，這個通知會被保留嗎？

<details>
<summary>提示</summary>

- 想想 scheduler 的三個階段：evaluate、update、delta notification。
- 事件（`sc_event`）沒有「值」也沒有「記憶」。

</details>

<details>
<summary>參考答案</summary>

1. `notify()`：**immediate notification**，等待者在**同一個 evaluate phase** 內立刻變成 runnable，但目前這個 process 要跑到自己下一次 `wait()` 才換別人；`notify(SC_ZERO_TIME)`：**delta notification**，等待者在**下一個 delta cycle** 才被喚醒；`notify(10, SC_NS)`：**timed notification**，在 10 ns 之後才被喚醒。L2-1 會實跑兩種的順序。
2. **不會。** `sc_event` 沒有記憶，immediate notify 只喚醒「此刻已經在等」的 process；沒人等就消失。實測：`A` 在 `1 ns` 呼叫 `e.notify()`，`B` 在 `2 ns` 才 `wait(5, SC_NS, e)`，結果 `B` 是因為 timeout 在 `7 ns` 醒來，沒有收到那次通知：

   ```cpp
   #include <systemc>
   using namespace sc_core; using std::cout; using std::endl;
   SC_MODULE(M) {
     sc_event e;
     SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
     void a(){ wait(1, SC_NS); e.notify(); cout << "A notified @" << sc_time_stamp() << endl; }
     void b(){ wait(2, SC_NS); cout << "B waits @" << sc_time_stamp() << endl; wait(5, SC_NS, e); cout << "B woke @" << sc_time_stamp() << " timed_out=" << (sc_time_stamp()==sc_time(7,SC_NS)) << endl; }
   };
   int sc_main(int, char**){ M m("m"); sc_start(); return 0; }
   ```

   實測輸出：

   ```
   A notified @1 ns
B waits @2 ns
B woke @7 ns timed_out=1
   ```

   這就是為什麼「事件」不能拿來傳資料或計數；要保留狀態要用 `sc_signal`、`sc_fifo` 或自己的變數搭配事件。

</details>

---

## L2：預測輸出

規則：先在紙上寫出輸出，再展開。

### L2-1：delta cycle 的執行順序〔L2〕

```cpp
#include <systemc>
using namespace sc_core; using std::cout; using std::endl;
SC_MODULE(M) {
  sc_event e_imm, e_delta;
  void tag(const char* s){ cout << s << " @" << sc_time_stamp() << " delta=" << sc_delta_count() << endl; }
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); SC_THREAD(c); }
  void a(){ wait(1, SC_NS); tag("A1"); e_imm.notify(); tag("A2"); e_delta.notify(SC_ZERO_TIME); tag("A3"); }
  void b(){ wait(e_imm); tag("B woke"); }
  void c(){ wait(e_delta); tag("C woke"); }
};
int sc_main(int, char**){ M m("m"); sc_start(); return 0; }
```

1. 預測五行輸出的順序，以及每行的 `delta=` 彼此差多少。
2. `B` 和 `C` 為什麼在不同的 delta？
3. `A` 在 `A3` 之後直接結束。如果在 `A3` 後面再加 `wait(SC_ZERO_TIME);`，`A` 會跟誰在同一個 delta 被喚醒？

<details>
<summary>提示</summary>

- 看 L1-3：immediate 與 delta 通知各在哪個階段喚醒等待者？
- `A1`、`A2`、`A3` 三行之間，`A` 有沒有交出執行權？
- `sc_delta_count()` 是從模擬開始累計的，只看相對差，絕對值不用在意。

</details>

<details>
<summary>參考答案</summary>

實測輸出：

```
A1 @1 ns delta=1
A2 @1 ns delta=1
A3 @1 ns delta=1
B woke @1 ns delta=1
C woke @1 ns delta=2
```

1. 順序：`A1 → A2 → A3 → B woke → C woke`。`A1`、`A2`、`A3`、`B woke` 都在**同一個 delta（`delta=1`）**，`C woke` 是 `delta=2`，差 1。
2. `A` 用 `e_imm.notify()` 的時候，`B` 立刻變 runnable，但 `A` 沒有 `wait`，沒交出執行權，所以 `A2`、`A3` 都先印；`A` 結束後，scheduler 在同一個 evaluate phase 才跑 `B`。`C` 等的是 delta notification，要等 evaluate 和 update 結束、進入 delta notification phase 才被放進 runnable，所以跑在下一個 delta。
3. `wait(SC_ZERO_TIME)` 也是 delta 層級的等待，會和 `C` 同一個 delta 被喚醒，實測 `A4` 與 `C woke` 都在 `delta=2`，兩者之間誰先誰後標準**沒有規定**，不要寫出依賴這個順序的程式。

這個行為在原始碼的 `sc_simcontext::crunch`（`src/sysc/kernel/sc_simcontext.cpp`）看得到：迴圈的 evaluate phase 一直跑 runnable process 到沒有為止；接著 update phase 呼叫 `perform_update()`；最後 notification phase 才觸發 `m_delta_events` 裡的 delta 事件，被喚醒的 process 進入下一輪 evaluate。

</details>

---

### L2-2：`SC_METHOD` 的 `next_trigger` 與 `SC_THREAD` 的 `wait`〔L2〕

```cpp
#include <systemc>
using namespace sc_core; using std::cout; using std::endl;
SC_MODULE(M) {
  SC_CTOR(M) { SC_METHOD(m); SC_THREAD(t); }
  void m(){ int x = 0; ++x; cout << "method x=" << x << " @" << sc_time_stamp() << endl; next_trigger(2, SC_NS); }
  void t(){ int y = 0; wait(1, SC_NS); for(;;){ ++y; cout << "thread y=" << y << " @" << sc_time_stamp() << endl; wait(2, SC_NS);} }
};
int sc_main(int, char**){ M m("m"); sc_start(6, SC_NS); cout << "end @" << sc_time_stamp() << endl; return 0; }
```

1. 預測輸出，特別注意兩個變數 `x` 與 `y`。
2. `sc_start(6, SC_NS)` 結束時，在 `6 ns` 的事件（`method` 的下一次執行）有沒有跑？

<details>
<summary>提示</summary>

- `SC_METHOD` 每次被呼叫都是新的函式呼叫，區域變數 `x` 會怎樣？
- `SC_THREAD` 的 `y` 在 `wait` 前後是同一個變數嗎？
- 第 2 題想一想 `sc_start(duration)` 的終點是包含還是不包含。

</details>

<details>
<summary>參考答案</summary>

實測輸出：

```
method x=1 @0 s
thread y=1 @1 ns
method x=1 @2 ns
thread y=2 @3 ns
method x=1 @4 ns
thread y=3 @5 ns
end @6 ns
```

1. `method` 在 `0 s`（初始化）、`2 ns`、`4 ns` 各跑一次，每次 `x` 都是 `1`（區域變數每次重新初始化）；`thread` 從 `1 ns` 起每 2 ns 一次，`y` 依序 `1、2、3`（堆疊上的區域變數跨 `wait` 保留）。想讓 `method` 記住次數，要改成成員變數。
2. **沒有跑**。`sc_start(6, SC_NS)` 的終點是 `6 ns`，但**終點那個時間點上的 process 不會被執行**：simulation time 被推進到 `6 ns`（`end @6 ns`），可是 `method` 排在 `6 ns` 的執行沒有執行。原始碼 `sc_simcontext::simulate` 裡有一行註解 `hold off on the delta for the until_t time`，就是這個行為。所以輸出裡看不到 `method x=1 @6 ns`。

</details>

---

### L2-3：`sc_signal` 的 evaluate / update 兩階段〔L2〕

```cpp
#include <systemc>
using namespace sc_core; using std::cout; using std::endl;
SC_MODULE(M) {
  sc_signal<int> sig; int plain = 0;
  SC_CTOR(M) : sig("sig") { SC_THREAD(w); SC_THREAD(r); }
  void w(){
    cout << "W0 sig=" << sig.read() << endl;
    sig.write(5); plain = 5;
    cout << "W1 sig=" << sig.read() << " plain=" << plain << endl;
    sig.write(7);
    cout << "W2 sig=" << sig.read() << endl;
    wait(SC_ZERO_TIME);
    cout << "W3 sig=" << sig.read() << " delta=" << sc_delta_count() << endl;
    wait(1, SC_NS);
    sig.write(7);   // same value
    wait(1, SC_NS);
    sig.write(8);
  }
  void r(){ for(;;){ wait(sig.value_changed_event());
      cout << "R sig=" << sig.read() << " @" << sc_time_stamp() << " delta=" << sc_delta_count() << endl; } }
};
int sc_main(int, char**){ M m("m"); sc_start(5, SC_NS); return 0; }
```

1. 預測 `W0`、`W1`、`W2`、`W3`、`R` 各行印出的 `sig` 值。
2. `plain` 是普通 `int`，為什麼 `W1` 的 `plain=5` 立刻看得到，而 `sig` 還是 0？
3. `1 ns` 的那次 `sig.write(7)`（跟目前值一樣）有沒有觸發 `R`？`R` 一共印幾次？

<details>
<summary>提示</summary>

- `sc_signal::write()` 只是登記「我想寫這個值」，真正更新在 update phase。
- `value_changed_event()` 在值**真的改變**的時候才觸發。

</details>

<details>
<summary>參考答案</summary>

實測輸出：

```
W0 sig=0
W1 sig=0 plain=5
W2 sig=0
R sig=7 @0 s delta=1
W3 sig=7 delta=1
R sig=8 @2 ns delta=4
```

1. `W0 sig=0`、`W1 sig=0 plain=5`、`W2 sig=0`、`W3 sig=7`、`R sig=7`（`0 s` 的第一次）以及 `R sig=8`（`2 ns`）。
2. 普通變數立刻改；`sc_signal` 是 **primitive channel**，`write()` 只把新值存進 `m_new_val` 並登記到 update 清單，要等目前 evaluate phase 結束、update phase 才把 `m_cur_val` 換成新值，同一 evaluate phase 內 `read()` 看到的永遠是舊值。這樣所有 process 在同一個 delta 看到的 signal 值是一致的，不會因為誰先跑而改變結果（模擬硬體同步邏輯的需要）。`W2` 是在同一個 evaluate phase 裡寫兩次，最後生效的是最後一次的 `7`（不是 5），`R` 也只觸發一次。
3. **沒有觸發**。新值與舊值相同，signal 不發 `value_changed_event`。所以 `R` 總共只印兩次（`7` 與 `8`）。這也是 `sc_signal` 不會讓每次 write 都喚醒 reader 的原因。

</details>

---

## L3：scheduler 口述

### L3-1：用一分鐘講完 SystemC scheduler 的 evaluate → update → delta notification 流程〔L3〕

請自己口述（面試的標準開場題），要求提到：

1. 三個階段各做什麼，什麼時候結束一個 delta cycle，什麼時候推進 simulation time。
2. `SC_METHOD` 與 `SC_THREAD` 在 evaluate phase 的執行方式有何不同。
3. 用你自己的 msg IP（或任何你寫過的模型）舉一個例子：某個 `wait` 或 `notify` 是在哪個階段生效的。

<details>
<summary>提示</summary>

- 用 L2-1、L2-3 的實測當例子：immediate 與 delta 事件，`sc_signal` 的值什麼時候更新。
- 第 3 點要用你**實際做過的細節**，不要背通用答案。

</details>

<details>
<summary>參考答案（骨架，第 3 點要自己補）</summary>

SystemC 是 discrete-event simulation。一個 time step 內重複下面的 delta cycle，直到沒有 runnable process：

1. **Evaluate phase**：scheduler 從 runnable 佇列拿出 process 執行，先跑 `SC_METHOD`（直接呼叫、跑完 return），再跑 `SC_THREAD`（切換到該 thread 的堆疊，直到它遇到 `wait` 讓出）。執行期間 process 可以做 immediate notification，被喚醒的 process 在同一個 evaluate phase 內變 runnable，直到佇列清空。
2. **Update phase**：呼叫所有登記過的 primitive channel 的 `update()`（例如 `sc_signal` 把新值換成現值），在這裡觸發 `value_changed_event` 等事件。
3. **Delta notification phase**：觸發 `notify(SC_ZERO_TIME)` 排隊的 delta 事件，被喚醒的 process 變 runnable；若佇列有 process，開始下一個 delta cycle（回到 evaluate，**simulation time 不變**）。
4. 若沒有 runnable process，scheduler 把 simulation time 推進到最早的 timed event 時間，觸發那個時間的事件，再回到 evaluate。沒有 timed event 就結束（event starvation）。

對照原始碼：`sc_simcontext::crunch` 實作 1～3，外層 `sc_simcontext::simulate` 實作時間推進；`sc_thread_process::wait` 與 `suspend_me()` 是 thread 的暫停點，最後透過 coroutine package（`sc_cor_pkg::yield`，本機 build 用 QuickThreads）切換堆疊。

第 3 點請把你模型中的具體情境填進去，例如「這個 `wait` 是 `SC_THREAD` 裡的 timed wait，它被喚醒時間在 timed event queue 裡」，這部分要自己回答，我不替你編。

</details>

---

## L4：simulation speed 案例

### L4-1：每個 clock cycle 都 `wait` 為什麼慢？連結你的 msg IP 優化案例〔L4〕

背景（引用自 `tasks/progress.md`）：你在 msg IP 用 VDK top-down profiling、valgrind，找到每個 clock cycle 都 wait 的不必要喚醒，改成較粗的時間等待，simulation 變快（加速倍數不確定）。

1. 把「每個 cycle 都 `wait`」變慢的成本拆成幾項，並指出原始碼對應的位置。
2. 下面的實驗：同一個 `100 ms` 的模擬，`Dev` 只是不斷 `wait(period)`；`10 ns` 與 `10 us` 的 wall-clock 差多少？每次喚醒大約要多少時間？
3. 這個優化有什麼精度上的取捨？面試官會追問什麼？你怎麼確認功能一致？（這題請用你自己的案例回答。）

```cpp
#include <systemc>
#include <chrono>
#include <cstdio>
#include <cstring>
using namespace sc_core;
static unsigned long wakeups = 0;
SC_MODULE(Dev) {
  sc_time period;
  SC_HAS_PROCESS(Dev);
  Dev(sc_module_name n, sc_time p) : sc_module(n), period(p) { SC_THREAD(t); }
  void t(){ for(;;){ wait(period); ++wakeups; } }
};
int sc_main(int argc, char** argv){
  bool fine = argc > 1 && !strcmp(argv[1], "fine");
  Dev d("d", fine ? sc_time(10, SC_NS) : sc_time(10, SC_US));
  auto t0 = std::chrono::steady_clock::now();
  sc_start(100, SC_MS);
  double s = std::chrono::duration<double>(std::chrono::steady_clock::now()-t0).count();
  std::printf("%s: wakeups=%lu wall=%.3fs\n", fine?"fine(10ns)":"coarse(10us)", wakeups, s);
  return 0;
}
```

<details>
<summary>提示</summary>

- 一次 `wait(time)` 到被喚醒，scheduler 要做哪些事？想 L3-1 的流程，以及 `wait` 與 `suspend_me()`。
- 做完 2 之後，用「每次喚醒的 wall-clock 成本」 × 「喚醒次數」來估算。
- 第 3 題的答案在你自己的案例裡，不在這個檔案裡。

</details>

<details>
<summary>參考答案</summary>

**1. 成本拆解（對照 SystemC 2.3.3 原始碼）**

每一次 `wait(t)`（`sc_thread_process::wait( const sc_time& )`，`sc_thread_process.h`）都要：

- 呼叫 `m_timeout_event_p->notify_internal(t)`：在 timed event queue（`m_timed_events`）裡新增一個 `sc_event_timed`，queue 是 heap 實作的 priority queue（`sc_ppq`，`src/sysc/utils/sc_pq.h`），insert 與 `extract_top` 都是 `O(log N)`。
- `add_dynamic(this)` 把 process 掛到該事件的動態敏感清單。
- `suspend_me()` → `cor_pkg()->yield(...)`：**coroutine 切換**（保存暫存器、切換堆疊），回到 scheduler。
- 時間到時：`simulate()` 取出 timed event、`trigger()`，把 process 放進 runnable，`crunch()` 再走一遍 evaluate→update→notification，最後 `m_cor_pkg->yield(thread_h->m_cor_p)` 切回 thread。

也就是：**一次喚醒 = 一次 timed event 的插入與取出 + 兩次 context switch + 一輪 scheduler 流程**，跟你在 `wait` 後面做的事情多寡無關。喚醒的次數和 simulation time 成正比、和 cycle 數成正比。

**2. 實測（本機，`-O2`，`sc_start(100, SC_MS)`）**

```
fine(10ns): wakeups=9999999 wall=0.649s
coarse(10us): wakeups=9999 wall=0.001s
```

喚醒次數差 1000 倍，wall-clock 約 `0.667 s` 對 `0.001 s`。平均每次喚醒約 `0.667 s / 10^7 ≈ 67 ns`。這是最簡單的 process，模型越複雜（多個 process、signal 更新、每次喚醒又觸發別的事件）每次的成本越高。數字只代表本機這個環境，不要當作通用常數。

**3. 取捨（面試追問方向，答案要自己寫）**

- 精度：`wait` 變粗之後，該 process「看得到事件的時間解析度」變差，原本在某個 cycle 邊界上的行為（例如 poll 某個狀態、timer 到期的精度）現在最多會有一個粗週期的誤差。你要能說明：你的 IP 在什麼前提下這個誤差不影響軟體看到的行為。
- 確認功能一致：回歸測試比對優化前後的輸出（register trace、中斷時序、軟體測試結果）；對時間敏感的行為，要有針對性的測試。
- 如果能用事件驅動取代輪詢（等 interrupt、等 register 被寫）更好：不需要定期喚醒，也沒有精度損失，不過要改設計的程度比較大。

沒有加速倍數的話，面試時要誠實說「確定有變快，數字我沒有留下」，不要編數字；可以用這個實驗的結果說明量級。

</details>

---

## 核對紀錄（2026-10-21）

- 所有程式碼用 `g++ -std=c++11`（見上）編譯並執行；輸出為實測。L1-1 的 `E519` 訊息、L1-3 的 immediate notify 遺失、L2-1～L2-3 的輸出、L4-1 的 wall-clock 都出自實跑。
- 原始碼對照：`sc_simcontext::crunch`（evaluate / update / delta notification 與 `m_delta_count` 遞增）、`sc_simcontext::simulate`（時間推進，終點 `until_t` 的 delta 不執行）、`sc_thread_process::wait` 與 `suspend_me`、`sc_cor_pkg_qt::yield`、`sc_wait.cpp` 中 `SC_ID_WAIT_NOT_ALLOWED_` 的錯誤訊息。
- 未核對項目：IEEE 1666 標準原文（本機沒有），涉及「標準保證什麼」的敘述（`m1` 與 `m2` 順序、`wait(SC_ZERO_TIME)` 與 delta 事件的順序為不保證）依 SystemC 語意的一般理解，沒有查標準條文。
- `sc_signal` 的 `m_cur_val` / `m_new_val` 欄位（L2-3）有在 `sc_signal.h` 看到；`write()` 登記到 update 清單的流程沒有逐行追。
- `sc_ppq` 為 heap 實作（`sc_pq.h`）、本機 library 含 `sc_cor_pkg_qt`（QuickThreads）已確認。
