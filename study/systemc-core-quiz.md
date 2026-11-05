# SystemC 核心：process、event、delta cycle 與 scheduler 複習題

對應 `tasks/learning-plan.md` 的 SystemC / TLM 基礎，也是 `study/tlm-quiz.md` 的前置：TLM 的 `b_transport`、quantum 都建立在 `wait()`、`sc_event` 和 scheduler 之上。目標是能解釋 SystemC 的執行模型，並說明「每個 clock cycle 都 `wait` 為什麼慢」。

用法跟其他題庫一樣：先自己想或寫在紙上，再展開 `<details>` 對照。

**難度分級**：L1 學習（看懂概念，附提示）→ L2 應用（預測輸出）→ L3 面試（口述）→ L4 深入（連結你的案例，對照原始碼）。建議順序：不熟的主題先讀下方「教學導讀」，再做選擇題（MC1–MC38，由淺到深），再做問答題（L1 → L4）。

**環境與驗證方式**：本機 SystemC 2.3.3，原始碼在 `~/cpp_practice/side_project/uArch/systemc-2.3.3`。本檔所有程式碼都實際編譯、執行過，輸出貼的是實測結果（2026-10-21；2026-11-05 新增的部分見「核對紀錄（2026-11-05 第二輪）」）。編譯指令：

```
S=~/cpp_practice/side_project/uArch/systemc-2.3.3
g++ -std=c++11 -I$S/include x.cpp -L$S/lib-linux64 -lsystemc -Wl,-rpath,$S/lib-linux64 -o x
```

注意：這份 library 是用 C++11 編的（`sc_api_version_2_3_3_cxx201103L`），用 `-std=c++14` 會在連結階段報 `undefined reference to sc_api_version_...`，要用 `-std=c++11`。程式入口是 `sc_main`，不是 `main`。

---

## 教學導讀

這一段給還不熟的主題用。每節先講白話概念，再給一個小範例（已實跑，輸出是實測結果），最後寫常見陷阱。已經熟的主題直接跳到題目。範例省略 `#include <systemc>` 與 `using` 宣告（同選擇題段落）。

### T1 三種 channel：`sc_signal`、`sc_buffer`、`sc_fifo`

- **`sc_signal`**：primitive channel。`write()` 只登記新值，值要到 update phase 才生效，同一個 evaluate phase 內 `read()` 看到的仍是舊值（L2-3）。值沒有改變就不發 `value_changed_event`（MC12、MC15）。
- **`sc_buffer`**：跟 `sc_signal` 一樣延後更新，但每次 `write()` 都發事件，即使值相同（MC15）。
- **`sc_fifo`**：有容量的佇列。`read()` / `write()` 是 blocking，空或滿時會自己 `wait`（MC18）。`nb_read()` / `nb_write()` 不等待，回傳 `bool`。寫入後 `num_free()` 立刻減少，但 `num_available()` 要等 update phase 才增加（MC38；`sc_fifo.h:93`、`:113`、`:350–356`）。

常見陷阱：在 `SC_METHOD` 裡呼叫 blocking `write()`，資料滿了就要 `wait`，method 不能 wait，直接報錯：

```cpp
SC_MODULE(M) {
  sc_fifo<int> f;
  SC_CTOR(M) : f(1) { SC_METHOD(m); }
  void m() { f.write(1); f.write(2); cout << "done" << endl; }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

```
Error: (E519) wait() is only allowed in SC_THREADs and SC_CTHREADs: 
        in SC_METHODs use next_trigger() instead
In file: ../../../src/sysc/kernel/sc_wait.cpp:93
In process: m.m @ 0 s
```

改法：method 裡用 `nb_write()`，或把這段改成 `SC_THREAD`。

### T2 `sc_event`：三種通知與覆蓋規則

- `e.notify()`：immediate，只喚醒「此刻正在等 `e`」的 process，同一個 evaluate phase 內生效；沒人等就消失（L1-3）。
- `e.notify(SC_ZERO_TIME)`：delta，下一個 delta cycle 才喚醒，simulation time 不變（MC8、L2-1）。
- `e.notify(t, unit)`：timed，t 之後喚醒。
- 規則：同一個 event 同時最多保留一個 pending 通知。較早的會取代較晚的，delta 會取代任何 timed，immediate 會取消 pending 通知（MC9；`sc_event.cpp` 的 `notify`）。`e.cancel()` 取消 pending 的 delta 或 timed 通知（`sc_event.cpp:66` 起）。

```cpp
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(n); }
  void w() { wait(e); cout << "woke @" << sc_time_stamp() << " d=" << sc_delta_count() << endl; }
  void n() {
    e.notify(5, SC_NS);
    e.notify(SC_ZERO_TIME);
    wait(10, SC_NS);
    e.notify(3, SC_NS); e.notify(7, SC_NS);
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

```
woke @0 s d=1
```

這裡 `e.notify(5, SC_NS)` 被後面的 `e.notify(SC_ZERO_TIME)` 取代，所以只醒一次，而且是 delta 醒。

常見陷阱：以為 timed 與 delta 通知會各醒一次。實際上同一個 event 只保留一個 pending 通知。需要「每次通知都要處理」的情境用 `sc_event_queue`（MC22）。

### T3 靜態敏感度、動態敏感度、`dont_initialize()`、`next_trigger()`

- 靜態敏感度：`sensitive << e`，永久有效。
- 動態敏感度：thread 的 `wait(e)`，或 method 的 `next_trigger(...)`，只對「下一次」有效。
- `dont_initialize()`：跳過 time 0 的初始執行（MC4、MC24）。
- thread 裡沒有參數的 `wait()`，用的是靜態敏感度清單（MC24）。
- method 裡呼叫 `next_trigger()` 會暫時蓋過靜態敏感度；下一次被動態條件觸發後，若 method 沒有再呼叫 `next_trigger()`，靜態敏感度就會回來。

```cpp
SC_MODULE(M) {
  sc_event e, tick;
  SC_CTOR(M) {
    SC_METHOD(m);
    sensitive << tick;
    dont_initialize();
    SC_THREAD(drv);
  }
  void m() {
    cout << "m @" << sc_time_stamp() << endl;
    if (sc_time_stamp() == sc_time(1, SC_NS))
      next_trigger(e);              // 只在 1 ns 改成動態等待
  }
  void drv() {
    wait(1, SC_NS);  tick.notify(SC_ZERO_TIME);   // 1 ns: m 執行，改等 e
    wait(2, SC_NS);  tick.notify(SC_ZERO_TIME);   // 3 ns: 被忽略（m 在等 e）
    wait(1, SC_NS);  e.notify(SC_ZERO_TIME);      // 4 ns: m 執行，恢復靜態敏感度
    wait(1, SC_NS);  tick.notify(SC_ZERO_TIME);   // 5 ns: m 執行
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

```
m @1 ns
m @4 ns
m @5 ns
```

常見陷阱：每次執行都呼叫 `next_trigger(e)`，靜態敏感度就永遠不會回來（MC26）。另外，`next_trigger()` 只改「下一次」，不會暫停目前這次執行。

### T4 `SC_METHOD`、`SC_THREAD`、`SC_CTHREAD`

- `SC_METHOD`：沒有自己的 stack，每次觸發都從頭跑到 return。適合組合邏輯或簡單反應。區域變數每次都會重新初始化（L2-2）。
- `SC_THREAD`：有自己的 stack，可以在任何地方 `wait`，區域變數跨 `wait` 保留（L1-1）。
- `SC_CTHREAD`：`SC_THREAD` 的特例，只綁一個 clock edge（例如 `clk.pos()`），用 `wait()` 等下一個 edge，並可以用 `reset_signal_is()` 設定同步 reset。

```cpp
SC_MODULE(M) {
  sc_in<bool> clk;
  sc_signal<bool> rst;
  SC_CTOR(M) { SC_CTHREAD(t, clk.pos()); reset_signal_is(rst, true); SC_THREAD(drv); }
  void drv() { wait(25, SC_NS); rst.write(true); wait(10, SC_NS); rst.write(false); }
  void t() {
    int n = 0;
    cout << "reset-branch @" << sc_time_stamp() << endl;
    n = 0;
    wait();
    for (;;) { cout << "count=" << n << " @" << sc_time_stamp() << endl; n++; wait(); }
  }
};
int sc_main(int, char**) {
  sc_clock clk("clk", 10, SC_NS);
  M m("m");
  m.clk(clk);
  sc_start(60, SC_NS);
  return 0;
}
```

```
reset-branch @0 s
count=0 @10 ns
count=1 @20 ns
reset-branch @30 ns
count=0 @40 ns
count=1 @50 ns
```

輸出的解讀：CTHREAD 在初始化時就開始執行，所以 `0 s` 先進入 reset 分支。之後第一個 `wait()` 等的是下一個 edge（10 ns），不是 time 0 的那次。`rst` 在 25 ns 拉高，30 ns 的 edge 讓 thread 從頭執行（reset 分支），counter 歸零。

常見陷阱：以為 CTHREAD 第一個 `wait()` 會在 time 0 就返回。另外，`reset_signal_is` 只是讓 reset 生效時 thread 從頭執行，計數器的值要自己在 reset 分支裡歸零。

### T5 `wait` 的各種寫法

| 寫法 | 意思 | 參考題 |
|---|---|---|
| `wait()` | 靜態敏感度的下一次觸發 | MC24 |
| `wait(t, SC_NS)` | 等 t 之後 | L1-2、MC21 |
| `wait(e)` | 等 `e` | L1-3 |
| `wait(t, SC_NS, e)` | 等 `e`，最多等 t（timeout 從這次 `wait` 開始算） | MC11、MC25 |
| `wait(e1 \| e2)` | 任一事件發生 | MC10 |
| `wait(e1 & e2)` | 兩個都要在這次 `wait` 之後各發生過一次 | MC10 |
| `wait(SC_ZERO_TIME)` | 下一個 delta | MC21、L2-1 |

常見陷阱：參數順序是「時間、單位、事件」（L1-2）。`&` 不是「同時發生」，而是「兩個都發生過」。

### T6 `sc_time` 與 time resolution

- `sc_time` 內部用整數 tick 儲存，一個 tick 是 time resolution（預設 1 ps）。
- 運算：`sc_time ± sc_time`、`sc_time * int`、`sc_time / sc_time` 得 `double`、`sc_time / double` 得 `sc_time`、`to_seconds()` 得秒數。印出時選能整除的最大單位（MC1、MC28）。
- 解析度只能在建立任何 `sc_time` 之前設定（MC29）。

```cpp
int sc_main(int, char**) {
  sc_set_time_resolution(1, SC_FS);
  sc_time t(1, SC_NS);
  cout << "t=" << t << " ps_units=" << t.value() << " res=" << sc_get_time_resolution() << endl;
  cout << sc_time(1.5, SC_PS) << " " << sc_time(1234, SC_FS) << endl;
  return 0;
}
```

```
t=1 ns ps_units=1000000 res=1 fs
1500 fs 1234 fs
```

常見陷阱：預設 1 ps 解析度下，`sc_time(0.4, SC_PS)` 會被四捨五入成 0（MC2），不會報錯。另外，`sc_set_time_resolution()` 在任何 `sc_time` 建立後呼叫，會報 E514（MC29）。

### T7 `sc_start`、`sc_pause`、`sc_stop`

- `sc_start()`：跑到沒有事件為止（MC6）。
- `sc_start(t, unit)`：從目前時間往後跑 t（相對，不是絕對時間，MC6）。終點那個時間點上的 process 不執行（L2-2）。
- `sc_start(SC_ZERO_TIME)`：只跑一個 delta cycle（MC20）。
- `sc_pause()`：在 process 裡呼叫，目前的 delta 結束後 `sc_start` 返回，之後可以再呼叫 `sc_start` 接著跑（MC36；`sc_simcontext.cpp:589–591`、`:892–897`）。
- `sc_stop()`：預設 `SC_STOP_FINISH_DELTA`，目前 delta 跑完才停（MC19）。`SC_STOP_IMMEDIATE` 會清掉目前 delta 裡還沒跑的 process（MC37；`sc_simcontext.cpp:992`、`:1015`）。

常見陷阱：`sc_stop()` 不會讓正在執行的那行 C++ 停下來，只是停止之後的排程。`sc_pause()` 之後的 `sc_start()` 會接著跑，時間不會重設。

### T8 elaboration 與 simulation 的 callback

順序（實測，見 MC30）：建構子 → `before_end_of_elaboration()` → 綁定檢查 → `end_of_elaboration()` → 第一次 `sc_start` 時 `start_of_simulation()` → 模擬 → `end_of_simulation()`。

- `start_of_simulation` 之後不能再建立 module（E529）。
- 2.3.3 原始碼中，`sc_simcontext::end()` 只被 `do_sc_stop_action()` 呼叫（`sc_simcontext.cpp:963`），所以 `end_of_simulation()` 只在 `sc_stop()` 之後執行（`sc_simcontext.cpp:990–1000` 的註解也是這樣描述）。sc_main 正常返回而沒有 `sc_stop()` 時，實測不會印出 `end_of_simulation`。標準條文本身這裡沒有核對。

```cpp
SC_MODULE(Late) { SC_CTOR(Late) { cout << "late ctor" << endl; } };
SC_MODULE(M) { SC_CTOR(M) {} void start_of_simulation() { cout << "start_of_simulation" << endl; Late* l = new Late("late"); (void)l; } };
int sc_main(int, char**) { M m("m"); sc_start(5, SC_NS); cout << "after" << endl; return 0; }
```

```
start_of_simulation
Error: (E529) insert module failed: elaboration done
In file: ../../../src/sysc/kernel/sc_module_registry.cpp:54
```

常見陷阱：把 module 的建立放在 `start_of_simulation()`；以及依賴 `end_of_simulation()` 做收尾，卻忘了呼叫 `sc_stop()`。

### T9 階層式 port、export、channel

- `sc_port<IF>`：「我需要一個實作 IF 的東西」。綁定發生在 elaboration。
- `sc_export<IF>`：「我把我內部、實作 IF 的 channel 公開給上層」。
- 綁定方向：port 綁 channel 或 export；export 綁的是 channel（不是 port）。

```cpp
struct Child : sc_module {
  sc_port<sc_fifo_in_if<int> > in;
  SC_CTOR(Child) { SC_THREAD(t); }
  void t() { int v = in->read(); cout << "child read " << v << " @" << sc_time_stamp() << endl; }
};
struct Mid : sc_module {
  sc_fifo<int> local;
  sc_export<sc_fifo_in_if<int> > exp;
  Child c;
  SC_CTOR(Mid) : local("local", 4), c("c") { exp(local); c.in(exp); SC_THREAD(src); }
  void src() { wait(2, SC_NS); local.write(42); }
};
int sc_main(int, char**) { Mid mid("mid"); sc_start(); return 0; }
```

```
child read 42 @2 ns
```

常見陷阱：
- port 沒綁：`sc_start()` 時報 E109（MC31，`sc_port.cpp:235`）。實測這個錯誤發生在 end-of-elaboration 的 callback 之前，所以 `end_of_elaboration()` 沒有印出。
- `sc_in<T>` 沒有 `write()`，寫成 `in.write()` 是編譯錯誤（MC32）。
- `exp(port)` 也是編譯錯誤，因為 `sc_export::operator()` 只接受 `IF&`（實測，錯誤訊息是 no match for call to `sc_export::operator()`）。

### T10 `sc_mutex` 與 `sc_semaphore`

- `sc_mutex`：二元鎖。`lock()` 會阻塞。`trylock()` 拿不到時回傳 `-1`（MC33；`sc_mutex.cpp:79–86`）。非持有者呼叫 `unlock()` 回傳 `-1`，不會解鎖（`sc_mutex.cpp:93–96`）。
- `sc_semaphore`：計數鎖，初始值是可用數量。`wait()` 在數量為 0 時阻塞，`post()` 加一（MC34）。

```cpp
SC_MODULE(M) {
  sc_mutex mtx;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() { mtx.lock(); wait(5, SC_NS); mtx.unlock(); cout << "a done" << endl; }
  void b() { wait(1, SC_NS); cout << "b unlock=" << mtx.unlock() << endl; }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

```
b unlock=-1
a done
```

常見陷阱：`lock()` 之後忘記 `unlock()`，其他 process 會永遠阻塞，但 kernel 不會報錯，`sc_start()` 會因為沒有事件而直接返回。

```cpp
SC_MODULE(M) {
  sc_mutex mtx;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() { mtx.lock(); cout << "a got lock @" << sc_time_stamp() << endl; }
  void b() { wait(1, SC_NS); mtx.lock(); cout << "b got lock @" << sc_time_stamp() << endl; }
};
int sc_main(int, char**) { M m("m"); sc_start(); cout << "sc_start returned @" << sc_time_stamp() << endl; return 0; }
```

```
a got lock @0 s
sc_start returned @1 ns
```

### T11 `sc_spawn`

- `sc_spawn()` 在模擬中動態建立 process，回傳 `sc_process_handle`。預設是 `SC_THREAD`。
- `sc_spawn_options` 可以指定 method、靜態敏感度、是否 `dont_initialize`。
- `h.terminated()` 查詢 process 是否已結束（MC35）。
- 需要 `#include <sysc/kernel/sc_spawn.h>`。只 `#include <systemc>` 時，實測會編譯失敗（找不到 `sc_spawn`）。

```cpp
#include <sysc/kernel/sc_spawn.h>
void m_fn() { cout << "method fn @" << sc_time_stamp() << endl; }
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    sc_spawn_options o; o.spawn_method(); o.set_sensitivity(&e); o.dont_initialize();
    sc_spawn(&m_fn, "mfn", &o);
    e.notify(2, SC_NS);
    wait(5, SC_NS);
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

```
method fn @2 ns
```

常見陷阱：spawn 出來的 process 不會自動等待。要知道它何時結束，就要保留 handle 再查詢。會呼叫 `wait()` 的函式，spawn 時不能指定成 method（同 MC3 的 E519 規則）。

---

## 目錄
- [教學導讀](#教學導讀)
- [選擇題：先建立直覺（MC1–MC38）](#選擇題先建立直覺mc1mc38)（先做這一段，再做下面的問答題）
- [L1：入門 (L1-1–L1-3)](#l1入門)
- [L2：預測輸出 (L2-1–L2-6)](#l2預測輸出)
- [L3：scheduler 口述 (L3-1–L3-4)](#l3scheduler-口述)
- [L4：simulation speed 案例 (L4-1–L4-2)](#l4simulation-speed-案例)
- [手寫練習](#手寫練習)
- [下一輪可以加考](#下一輪可以加考)
- [核對紀錄](#核對紀錄2026-10-21)

---

## 選擇題：先建立直覺（MC1–MC38）

單選題，由淺到深（L1 → L3）。做法跟 C++ 題庫一樣：先在紙上選，再展開看每個選項為什麼對或錯，最後挑幾題自己打進編譯器跑（編譯指令見檔案開頭，記得 `-std=c++11`）。

**程式碼省略的開頭**：這一段所有程式都省略下面四行，要自己跑時請補上：

```cpp
#include <systemc>
using namespace sc_core;
using std::cout;
using std::endl;
```

每題答案中的輸出都是本機實跑的結果；驗證方式見這一段的最後。

---

### 入門（L1）

#### MC1：`sc_time` 怎麼印？〔L1〕

```cpp
int sc_main(int, char**) {
  cout << sc_time(2, SC_NS) + sc_time(500, SC_PS) << endl;
  cout << sc_time(1, SC_NS) * 3 << endl;
  cout << (sc_time(1, SC_US) == sc_time(1000, SC_NS)) << endl;
  return 0;
}
```

三行輸出是？

- A. `2.5 ns`、`3 ns`、`1`
- B. `2500 ps`、`3 ns`、`1`
- C. `2500 ps`、`3 ns`、`0`
- D. `2500 ps`、`3000 ps`、`1`

<details>
<summary>答案</summary>

**B。** `sc_time` 可以直接加、乘整數、比較大小，`1 us` 和 `1000 ns` 是同一個時間（比較結果印出來是 `1`）。印出時會選「能整除的最大單位」：2500 ps 不能被 1 ns 整除，所以印 `2500 ps`；3000 ps 剛好是 3 ns，所以印 `3 ns`。

```
2500 ps
3 ns
1
```

</details>

---

#### MC2：比時間解析度更小的時間會怎樣？〔L1〕

```cpp
int sc_main(int, char**) {
  cout << sc_time(1.5, SC_PS) << endl;
  cout << sc_time(0.4, SC_PS) << endl;
  cout << sc_time(1.4, SC_NS) << endl;
  return 0;
}
```

預設的時間解析度（time resolution）是 1 ps。三行輸出是？

- A. `1.5 ps`、`0.4 ps`、`1.4 ns`
- B. `1 ps`、`0 s`、`1400 ps`
- C. `2 ps`、`0 s`、`1400 ps`
- D. 編譯錯誤，`sc_time` 不能接受小數

<details>
<summary>答案</summary>

**C。** `sc_time` 內部用整數儲存（單位是 time resolution，預設 1 ps），建構時小數會**四捨五入**到最近的整數個 ps：1.5 ps 變成 2 ps、0.4 ps 變成 0（印成 `0 s`）、1.4 ns 是 1400 ps。精度比解析度更細的延遲會被悄悄改掉，不會報錯；需要更細要在建立任何 `sc_time` 之前呼叫 `sc_set_time_resolution()`。

```
2 ps
0 s
1400 ps
```

</details>

---

#### MC3：誰可以呼叫 `wait()`？〔L1〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_METHOD(m); }
  void m() { wait(1, SC_NS); }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(2, SC_NS);
  return 0;
}
```

這段的結果是？

- A. 執行期錯誤（E519）：`wait()` 只能用在 `SC_THREAD` 和 `SC_CTHREAD`，`SC_METHOD` 要用 `next_trigger()`
- B. 正常執行，`m` 每 1 ns 被呼叫一次
- C. 編譯錯誤
- D. 只印警告，`wait()` 被忽略

<details>
<summary>答案</summary>

**A。** 編譯通過（`wait` 在語法上合法），但 `SC_METHOD` 沒有自己的堆疊，不能暫停，執行時 scheduler 直接報錯並中止：

```
Error: (E519) wait() is only allowed in SC_THREADs and SC_CTHREADs: 
        in SC_METHODs use next_trigger() instead
In file: ../../../src/sysc/kernel/sc_wait.cpp:179
In process: m.m @ 0 s
```

這是執行期錯誤，不是編譯錯誤，所以要執行到才會發現。

</details>

---

#### MC4：誰會在 time 0 先跑一次？〔L1〕

```cpp
SC_MODULE(M) {
  sc_signal<int> s;
  SC_CTOR(M) {
    SC_THREAD(t);
    SC_METHOD(m1);
    sensitive << s;
    SC_METHOD(m2);
    sensitive << s;
    dont_initialize();
    SC_THREAD(w);
  }
  void t()  { cout << "thread ran @" << sc_time_stamp() << endl; }
  void m1() { cout << "m1 ran @" << sc_time_stamp() << endl; }
  void m2() { cout << "m2 ran @" << sc_time_stamp() << endl; }
  void w()  { wait(3, SC_NS); s.write(1); }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(5, SC_NS);
  return 0;
}
```

哪些行會出現？（`0 s` 與 `3 ns` 是時間）

- A. 只有 `m2 ran @3 ns`
- B. `thread ran @0 s`、`m1 ran @0 s`、`m2 ran @0 s`、`m1 ran @3 ns`、`m2 ran @3 ns`
- C. `thread ran @0 s`、`m2 ran @3 ns`
- D. `thread ran @0 s`、`m1 ran @0 s`、`m1 ran @3 ns`、`m2 ran @3 ns`

<details>
<summary>答案</summary>

**D。** 所有 process 預設在 time 0 的初始化階段先跑一次（`SC_THREAD` 跑到第一個 `wait` 或結束、`SC_METHOD` 跑一次）；`dont_initialize()` 讓 `m2` 跳過這次，只在 `s` 真的變化（3 ns）才跑。`m1` 沒有 `dont_initialize()`，所以 0 s 和 3 ns 各跑一次。

同一個 delta 內幾個 process 的先後順序標準沒有規定，所以下面的順序只是本機結果（比對時不看順序）：

```
m1 ran @0 s
thread ran @0 s
m2 ran @3 ns
m1 ran @3 ns
```

</details>

---

#### MC5：thread 結束之後，`sc_start(10, SC_NS)` 會停在哪？〔L1〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    for (int i = 0; i < 2; ++i) {
      cout << "round " << i << " @" << sc_time_stamp() << endl;
      wait(1, SC_NS);
    }
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(10, SC_NS);
  cout << "end @" << sc_time_stamp() << endl;
  return 0;
}
```

最後一行的時間是？

- A. `end @0 s`
- B. `end @1 ns`
- C. `end @2 ns`
- D. `end @10 ns`

<details>
<summary>答案</summary>

**D。** thread 在 `1 ns` 之後跑完就結束（`for` 只跑兩圈，結束後不會重新開始），之後沒有任何事件，但 `sc_start(10, SC_NS)` 明確要求跑 10 ns，simulation time 還是會被推進到 10 ns。對照：沒有給時間的 `sc_start()` 是「跑到沒有事件為止」，那時會停在最後一個事件的時間（見 MC6）。

```
round 0 @0 s
round 1 @1 ns
end @10 ns
```

</details>

---

#### MC6：`sc_start()` 與 `sc_start(t)` 的累計〔L1〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    wait(10, SC_NS);
    wait(10, SC_NS);
    cout << "t done @" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "after sc_start() @" << sc_time_stamp() << endl;
  sc_start(10, SC_NS);
  cout << "after +10ns @" << sc_time_stamp() << endl;
  sc_start(10, SC_NS);
  cout << "after +10ns @" << sc_time_stamp() << endl;
  return 0;
}
```

三行 `after` 的時間依序是？

- A. `20 ns`、`10 ns`、`10 ns`
- B. `20 ns`、`30 ns`、`40 ns`
- C. `20 ns`、`20 ns`、`20 ns`
- D. `0 s`、`10 ns`、`20 ns`

<details>
<summary>答案</summary>

**B。** `sc_start()` 沒給時間，跑到沒有事件為止（thread 在 20 ns 結束），停在 20 ns；之後每次 `sc_start(10, SC_NS)` 是「從目前時間再往後跑 10 ns」（相對時間，不是絕對時間），所以 30 ns、40 ns。

```
t done @20 ns
after sc_start() @20 ns
after +10ns @30 ns
after +10ns @40 ns
```

</details>

---

#### MC7：階層名稱〔L1〕

```cpp
SC_MODULE(Sub) {
  SC_CTOR(Sub) { SC_THREAD(proc); }
  void proc() {
    cout << name() << " | " << sc_get_current_process_handle().name()
         << " | " << basename() << " | " << kind() << endl;
  }
};

SC_MODULE(Top) {
  Sub sub;
  SC_CTOR(Top) : sub("sub") {}
};

int sc_main(int, char**) {
  Top top("top");
  sc_start();
  return 0;
}
```

輸出是？

- A. `top.sub | top.sub.proc | sub | sc_module`
- B. `sub | sub.proc | sub | sc_module`
- C. `top.sub | proc | top.sub | Sub`
- D. `top.sub | top.sub.proc | top.sub | sc_module`

<details>
<summary>答案</summary>

**A。** SystemC 的物件名稱是階層式、用 `.` 分隔：`Sub` 的實例叫 `top.sub`（`name()` 是完整階層名），`basename()` 只有最後一段 `sub`；process 的名稱再往下一層 `top.sub.proc`；`kind()` 對所有 `SC_MODULE` 都是 `sc_module`（不是你的類別名稱）。看 log 與 error message 時，會用這種完整名稱指出是哪個 process（例如 MC3 的 `m.m`）。

```
top.sub | top.sub.proc | sub | sc_module
```

</details>

---

### 應用（L2）

#### MC8：delta 通知一路往下傳〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e1, e2;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); SC_THREAD(c); }
  void a() {
    wait(1, SC_NS);
    cout << "A d=" << sc_delta_count() << endl;
    e1.notify(SC_ZERO_TIME);
  }
  void b() {
    wait(e1);
    cout << "B d=" << sc_delta_count() << " @" << sc_time_stamp() << endl;
    e2.notify(SC_ZERO_TIME);
  }
  void c() {
    wait(e2);
    cout << "C d=" << sc_delta_count() << " @" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`B`、`C` 的時間與 delta 計數（`d`）相對 `A` 的關係是？（只看相對差）

- A. 都在 `1 ns`；`B` 比 `A` 多 1 個 delta，`C` 比 `B` 多 1 個 delta
- B. `B` 在 `1 ns`、`C` 在 `2 ns`
- C. 三個都在同一個 delta
- D. `B` 在 `1 ns`、`C` 在 `1 ns`，但兩個 delta 計數相同

<details>
<summary>答案</summary>

**A。** 每次 `notify(SC_ZERO_TIME)` 都讓被喚醒的 process 在**下一個 delta** 才跑，simulation time 不變。一條 `A → B → C` 的 delta 通知鏈，要花 2 個 delta，卻不花任何 simulation time。實測（`d` 是從模擬開始累計的計數，只看差）：

```
A d=1
B d=2 @1 ns
C d=3 @1 ns
```

這也說明了：硬體上「同一時間」發生的因果鏈，在 SystemC 裡是用 delta cycle 排出先後。

</details>

---

#### MC9：同一個事件排了多個通知〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(n); }
  void w() {
    for (;;) {
      wait(e);
      cout << "woke @" << sc_time_stamp() << endl;
    }
  }
  void n() {
    wait(5, SC_NS);
    e.notify(2, SC_NS);  e.notify(1, SC_NS);   // (1) 5 ns 時
    wait(10, SC_NS);
    e.notify(1, SC_NS);  e.notify(2, SC_NS);   // (2) 15 ns 時
    wait(10, SC_NS);
    e.notify(3, SC_NS);  e.notify();           // (3) 25 ns 時
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`w` 被喚醒的時間是？

- A. `7 ns`、`18 ns`、`28 ns`
- B. `6 ns`、`7 ns`、`16 ns`、`17 ns`、`25 ns`、`28 ns`
- C. `7 ns`、`16 ns`、`28 ns`
- D. `6 ns`、`16 ns`、`25 ns`

<details>
<summary>答案</summary>

**D。** 一個 `sc_event` 同一時間只保留**一個**待處理的通知，新的通知只在「比已存在的更早」時才會取代它：

- (1) 先排 2 ns、再排 1 ns：1 ns 比較早，取代；只有一次，在 5 + 1 = 6 ns 醒。
- (2) 先排 1 ns、再排 2 ns：2 ns 比較晚，被忽略；只有一次，在 15 + 1 = 16 ns 醒。
- (3) 先排 3 ns、再 `notify()`（immediate）：immediate 比任何延遲通知都早，並且會**取消**已排的 3 ns 通知；在 25 ns 醒一次，28 ns 不會醒。

這是 `sc_event` 與 `sc_event_queue` 的差別（見 MC22）。

```
woke @6 ns
woke @16 ns
woke @25 ns
```

</details>

---

#### MC10：`|` 與 `&` 等待事件組合〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e1, e2;
  SC_CTOR(M) { SC_THREAD(any); SC_THREAD(both); SC_THREAD(n); }
  void any() {
    wait(e1 | e2);
    cout << "OR woke @" << sc_time_stamp() << endl;
  }
  void both() {
    wait(e1 & e2);
    cout << "AND woke @" << sc_time_stamp() << endl;
  }
  void n() {
    e1.notify(1, SC_NS);
    e2.notify(3, SC_NS);
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

兩個 thread 各在什麼時候醒？

- A. `OR` 在 `3 ns`、`AND` 在 `1 ns`
- B. 兩個都在 `1 ns`
- C. `OR` 在 `1 ns`、`AND` 在 `3 ns`
- D. 兩個都在 `3 ns`

<details>
<summary>答案</summary>

**C。** `wait(e1 | e2)`：任何一個事件發生就醒（1 ns）；`wait(e1 & e2)`：要兩個事件**都**發生過才醒（3 ns，等到最後一個）。注意 `&` 要等的是「這次 wait 之後」兩個事件各發生一次，不是同時發生。

```
OR woke @1 ns
AND woke @3 ns
```

</details>

---

#### MC11：`wait(時間, 事件)` 的 timeout〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(n); }
  void w() {
    wait(10, SC_NS, e);
    cout << "w1 @" << sc_time_stamp() << endl;
    wait(10, SC_NS, e);
    cout << "w2 @" << sc_time_stamp() << endl;
  }
  void n() {
    wait(4, SC_NS);
    e.notify();
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`w1` 與 `w2` 的時間是？

- A. `4 ns`、`8 ns`
- B. `4 ns`、`14 ns`
- C. `10 ns`、`20 ns`
- D. `4 ns`、`10 ns`

<details>
<summary>答案</summary>

**B。** `wait(10, SC_NS, e)` 是「最多等 10 ns，期間 `e` 發生就提早醒」。第一次 `e` 在 4 ns 發生，4 ns 醒（`w1 @4 ns`）；第二次從 4 ns 開始等，`e` 再也沒有被通知，等滿 10 ns 的 timeout，在 14 ns 醒。timeout 是從**這次 wait 開始**算，不是從 time 0 算。

```
w1 @4 ns
w2 @14 ns
```

</details>

---

#### MC12：`sc_signal<bool>` 的三種邊緣事件〔L2〕

```cpp
SC_MODULE(M) {
  sc_signal<bool> s;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(p); SC_THREAD(n); SC_THREAD(c); }
  void w() {
    wait(1, SC_NS); s.write(true);
    wait(1, SC_NS); s.write(false);
    wait(1, SC_NS); s.write(true);
    wait(1, SC_NS); s.write(true);
  }
  void p() { for (;;) { wait(s.posedge_event());       cout << "pos @" << sc_time_stamp() << endl; } }
  void n() { for (;;) { wait(s.negedge_event());       cout << "neg @" << sc_time_stamp() << endl; } }
  void c() { for (;;) { wait(s.value_changed_event()); cout << "chg @" << sc_time_stamp() << endl; } }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`pos`、`neg`、`chg` 各出現幾次？

- A. `2`、`1`、`3`
- B. `3`、`1`、`4`
- C. `2`、`2`、`4`
- D. `3`、`1`、`3`

<details>
<summary>答案</summary>

**A。** signal 值依序是 初始 `false` → 1 ns `true` → 2 ns `false` → 3 ns `true` → 4 ns 再寫 `true`。`posedge`（false→true）在 1、3 ns 共 2 次；`negedge`（true→false）在 2 ns 共 1 次；`value_changed` 是值有變就觸發，1、2、3 ns 共 3 次。4 ns 寫入相同的值，**不產生任何事件**。

```
pos @1 ns
chg @1 ns
neg @2 ns
chg @2 ns
pos @3 ns
chg @3 ns
```

（同一個時間點上 `pos` 與 `chg` 的先後，標準沒有規定，比對時不看順序。）

</details>

---

#### MC13：另一個 process 在同一個 delta 寫入，我讀到什麼？〔L2〕

```cpp
SC_MODULE(M) {
  sc_signal<int> s;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() {
    wait(1, SC_NS);
    s.write(5);
  }
  void b() {
    wait(1, SC_NS);
    cout << "B reads " << s.read() << " @" << sc_time_stamp() << endl;
    wait(SC_ZERO_TIME);
    cout << "B reads " << s.read() << " after delta" << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

兩行 `B reads` 依序讀到？

- A. `5`、`5`
- B. `0`、`0`
- C. `0`、`5`
- D. 取決於 `a` 和 `b` 誰先被排程：可能是 `5`、`5` 也可能是 `0`、`5`

<details>
<summary>答案</summary>

**C。** `write()` 只登記新值，要等 update phase 才生效，所以同一個 evaluate phase 內無論 `a` 與 `b` 誰先跑，`b` 讀到的都是舊值 `0`；`b` 等過一個 delta 後才看到 `5`。**這正是 `sc_signal` 的設計目的：結果不依賴 process 的執行順序**（D 錯）。如果改用普通的 `int` 變數，D 就會成立，那就是 race。

```
B reads 0 @1 ns
B reads 5 after delta
```

</details>

---

#### MC14：兩個 process 寫同一個 `sc_signal`〔L2〕

```cpp
SC_MODULE(M) {
  sc_signal<int> s;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() { wait(1, SC_NS); s.write(1); }
  void b() { wait(5, SC_NS); s.write(2); }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "finished" << endl;
  return 0;
}
```

兩個寫入相隔 4 ns，結果是？

- A. 正常結束，`s` 最後是 2
- B. 編譯錯誤
- C. 只印警告，`s` 最後是 2
- D. 執行期錯誤 E115：`sc_signal` 不能有一個以上的 driver

<details>
<summary>答案</summary>

**D。** `sc_signal` 預設只允許**一個 process** 寫入（`SC_ONE_WRITER`），檢查的是「寫入者是不是同一個 process」，**跟是否在同一個 delta 或時間無關**。第二個 process 第一次寫入時就報錯並中止，所以 `finished` 不會印出：

```
Error: (E115) sc_signal<T> cannot have more than one driver: 
 signal `m.signal_0' (sc_signal)
 first driver `m.a' (sc_thread_process)
 second driver `m.b' (sc_thread_process)
In file: ../../../src/sysc/communication/sc_signal.cpp:67
In process: m.b @ 5 ns
```

這是 IEEE 1666 的預設檢查；本機 2.3.3 另有環境變數 `SC_SIGNAL_WRITE_CHECK`：設成 `CONFLICT` 時只檢查「同一個 delta 內的衝突寫入」，設成 `DISABLE` 時完全不檢查（實測兩者都讓這段程式正常印出 `finished`）。

實測對照（兩個 process 的寫入分別在 `1 ns` 的同一個 delta，或 `1 ns` 的不同 delta）：未設環境變數時兩種都報 E115；`CONFLICT` 時同一 delta 報 E115（多一行 `conflicting write in delta cycle N`），不同 delta 正常結束；`DISABLE` 時兩種都正常結束。原始碼依據：`sc_simcontext.cpp:328–335` 讀取環境變數；`sc_simcontext_int.h:91–92` 在 `DISABLE` 時不記錄 writer；`sc_signal.h:47–67` 的 `check_write` 比較 writer；`sc_signal.h:70–74` 的 `update()` 在 `m_delta_only`（即 `CONFLICT`）時於 update phase 清空 writer，所以只對同一個 delta 有效。

不要靠環境變數繞過。要多個 writer 必須明確宣告 `sc_signal<int, SC_MANY_WRITERS>`，本機實測同一段原題程式改成這樣可以正常結束，`s` 最後是 2。但 `SC_MANY_WRITERS` 不是完全不檢查：`sc_writer_policy_check<SC_MANY_WRITERS>` 繼承 `sc_writer_policy_check_delta`（`sc_writer_policy.h:141–144`），所以同一個 delta 內的衝突寫入仍由 kernel 報 E115（實測，環境變數未設或設 `CONFLICT` 都會報），不同 delta 的寫入允許。要完全不檢查只能用 `SC_UNCHECKED_WRITERS`（實測同一 delta 兩寫入正常結束），這是非標準行為，不建議在模型中使用。

</details>

---

#### MC15：`sc_signal` 與 `sc_buffer` 的事件〔L2〕

```cpp
SC_MODULE(M) {
  sc_signal<int> s;
  sc_buffer<int> b;
  int ns = 0, nb = 0;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(rs); SC_THREAD(rb); }
  void w() {
    wait(1, SC_NS); s.write(7); b.write(7);
    wait(1, SC_NS); s.write(7); b.write(7);
    wait(1, SC_NS);
  }
  void rs() { for (;;) { wait(s.value_changed_event()); ++ns; } }
  void rb() { for (;;) { wait(b.value_changed_event()); ++nb; } }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "signal events=" << m.ns << " buffer events=" << m.nb << endl;
  return 0;
}
```

輸出是？

- A. `signal events=2 buffer events=2`
- B. `signal events=1 buffer events=2`
- C. `signal events=1 buffer events=1`
- D. `signal events=2 buffer events=1`

<details>
<summary>答案</summary>

**B。** 兩次都寫入 `7`，初始值是 0：第一次寫入（0→7）兩者都有事件；第二次寫入相同的值，`sc_signal` 因為值沒變**不發事件**，`sc_buffer` 則是**每次寫入都發事件**，即使值相同。`sc_buffer` 適合用來表示「每次寫入本身就是一個事件」的訊號（例如一個脈衝、一個命令）。

```
signal events=1 buffer events=2
```

</details>

---

#### MC16：`SC_METHOD` 的 `next_trigger` 會蓋過靜態敏感度〔L2〕

```cpp
SC_MODULE(M) {
  sc_signal<int> s;
  SC_CTOR(M) {
    SC_METHOD(m);
    sensitive << s;
    dont_initialize();
    SC_THREAD(w);
  }
  void m() {
    cout << "method @" << sc_time_stamp() << " s=" << s.read() << endl;
    next_trigger(5, SC_NS);
  }
  void w() {
    wait(1, SC_NS);  s.write(1);
    wait(1, SC_NS);  s.write(2);
    wait(10, SC_NS); s.write(3);
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(30, SC_NS);
  return 0;
}
```

`m` 前三次被呼叫的時間與讀到的 `s` 是？（`s` 在 1、2、12 ns 被寫成 1、2、3）

- A. `1 ns s=1`、`2 ns s=2`、`12 ns s=3`
- B. `1 ns s=1`、`6 ns s=1`、`11 ns s=1`
- C. `1 ns s=1`、`6 ns s=2`、`11 ns s=2`
- D. `1 ns s=1`、`6 ns s=2`、`12 ns s=3`

<details>
<summary>答案</summary>

**C。** 第一次被 `s` 的變化（1 ns）觸發，`m` 呼叫 `next_trigger(5, SC_NS)`，**這一次**的觸發條件變成「5 ns 後」，靜態敏感度暫時失效，所以 2 ns 時 `s` 變成 2 **不會**叫醒 `m`；`m` 在 6 ns 被時間叫醒，讀到 `s=2`，又呼叫 `next_trigger(5, SC_NS)`，之後 12 ns 的變化也同樣被忽略，在 11 ns 被叫醒時 `s` 還是 2。

因為每次都呼叫 `next_trigger(時間)`，`m` 從此變成固定每 5 ns 輪詢，不再理會 `s`。若想回到「由 signal 觸發」，不呼叫 `next_trigger`（回到靜態敏感度）即可。這與 L4-1 的「改成較粗的時間等待」是同一類機制。

```
method @1 ns s=1
method @6 ns s=2
method @11 ns s=2
method @16 ns s=3
method @21 ns s=3
method @26 ns s=3
```

</details>

---

#### MC17：沒有敏感度的 `SC_METHOD`〔L2〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_METHOD(m); }
  void m() { cout << "method ran @" << sc_time_stamp() << endl; }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(100, SC_NS);
  cout << "end @" << sc_time_stamp() << endl;
  return 0;
}
```

`method ran` 會印幾次？

- A. 一次（`0 s`），之後再也不會被觸發
- B. 每個 delta 一次
- C. 每 1 ns 一次
- D. 零次，因為沒有指定敏感度

<details>
<summary>答案</summary>

**A。** 初始化階段會跑一次；沒有 `sensitive`、也沒有 `next_trigger`，之後沒有任何事件能再叫它，也就不會再跑。（`SC_METHOD` 不像 `SC_THREAD` 能自己用迴圈保持活著。）想週期性執行要靠 `next_trigger(時間)` 或改成 `SC_THREAD` 加 `wait`。

```
method ran @0 s
end @100 ns
```

</details>

---

### 進階（L3）

#### MC18：`sc_fifo` 滿了會怎樣？〔L3〕

```cpp
SC_MODULE(M) {
  sc_fifo<int> f;
  SC_CTOR(M) : f(2) { SC_THREAD(p); SC_THREAD(c); }
  void p() {
    for (int i = 1; i <= 4; ++i) {
      f.write(i);
      cout << "wrote " << i << " @" << sc_time_stamp() << endl;
    }
  }
  void c() {
    for (int i = 0; i < 4; ++i) {
      wait(10, SC_NS);
      cout << "read " << f.read() << " @" << sc_time_stamp() << endl;
    }
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

fifo 容量是 2。`wrote 3` 與 `wrote 4` 各在什麼時候完成？

- A. 都在 `0 s`，`write` 不會阻塞
- B. `10 ns` 和 `10 ns`
- C. `20 ns` 和 `40 ns`
- D. `10 ns` 和 `20 ns`

<details>
<summary>答案</summary>

**D。** `sc_fifo::write()` 是**阻塞式**的：滿了就自己 `wait`，直到有空位。前兩筆在 0 s 就寫進去，第 3 筆卡住，直到 consumer 在 10 ns 讀走一筆、空出位置，才完成（10 ns）；第 4 筆同理要等 consumer 在 20 ns 再讀一筆。producer 的速度被 consumer 的速度拖住，這就是 fifo 的「背壓（back-pressure）」。

```
wrote 1 @0 s
wrote 2 @0 s
read 1 @10 ns
wrote 3 @10 ns
read 2 @20 ns
wrote 4 @20 ns
read 3 @30 ns
read 4 @40 ns
```

（`read` 與 `wrote` 在同一個時間點上的先後順序，這裡實測是 `read` 先，標準不保證，比對時不看同時間的順序。）

</details>

---

#### MC19：呼叫 `sc_stop()` 之後〔L3〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); SC_THREAD(c); }
  void a() {
    wait(1, SC_NS);
    sc_stop();
    cout << "A after sc_stop @" << sc_time_stamp() << endl;
    wait(SC_ZERO_TIME);
    cout << "A next delta" << endl;
  }
  void b() {
    wait(1, SC_NS);
    cout << "B same delta @" << sc_time_stamp() << endl;
  }
  void c() {
    wait(2, SC_NS);
    cout << "C at 2ns" << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "end @" << sc_time_stamp() << endl;
  return 0;
}
```

哪些行會被印出來？

- A. 只有 `end @1 ns`
- B. `A after sc_stop`、`B same delta`、`end @1 ns`
- C. `A after sc_stop`、`B same delta`、`A next delta`、`end @1 ns`
- D. 全部都會印，包含 `C at 2ns`

<details>
<summary>答案</summary>

**B。** `sc_stop()` 不會立刻中斷目前的 process：`A` 的下一行 `A after sc_stop` 還是會印；預設的停止模式（`SC_STOP_FINISH_DELTA`）是「把**目前這個 delta cycle** 跑完再結束」，所以同一個 delta 裡的 `B` 也會印；但下一個 delta 不會開始，`A next delta` 與 2 ns 的 `C` 都不會印。模擬器還會多印一行 `Info: /OSCI/SystemC: Simulation stopped by user.`。

```
A after sc_stop @1 ns
B same delta @1 ns
end @1 ns
```

（`A after sc_stop` 與 `B same delta` 的先後，標準不保證，比對時不看順序。）

</details>

---

#### MC20：`sc_start(SC_ZERO_TIME)` 跑多少？〔L3〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    for (int i = 0; i < 5; ++i) {
      cout << "delta loop " << i << " @" << sc_time_stamp() << endl;
      wait(SC_ZERO_TIME);
    }
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(SC_ZERO_TIME);
  cout << "after sc_start(SC_ZERO_TIME)" << endl;
  sc_start(SC_ZERO_TIME);
  cout << "after second" << endl;
  return 0;
}
```

輸出是？

- A. 兩次呼叫之後 `delta loop 0` 到 `delta loop 4` 全部印完
- B. 什麼都不印，`sc_start(SC_ZERO_TIME)` 不會執行任何 process
- C. 第一次 `sc_start` 只印 `delta loop 0`，第二次再印 `delta loop 1`
- D. 無窮迴圈

<details>
<summary>答案</summary>

**C。** `sc_start(SC_ZERO_TIME)` 只執行**一個 delta cycle** 就返回（simulation time 不前進），每次呼叫推進一個 delta。這個用法在 debug 時很有用（單步看 delta），也能在 testbench 裡把 reset 結束後的初始化先跑完。原始碼 `sc_simcontext::simulate` 對 `duration == SC_ZERO_TIME` 有專門的分支（`sc_simcontext.cpp:867–870`）：`crunch(true)`，也就是只跑一輪。`crunch` 在 delta 結束時 `if ( once ) break;`（`sc_simcontext.cpp:595`），所以一次 `sc_start(SC_ZERO_TIME)` 最多做一個 evaluate→update→notify 循環；`initialize(true)` 不做 `initial_crunch`（`sc_simcontext.cpp:796`），第一次呼叫時 thread 的初始執行也在這一輪的 evaluate 裡完成。

```
delta loop 0 @0 s
after sc_start(SC_ZERO_TIME)
delta loop 1 @0 s
after second
```

</details>

---

#### MC21：`wait(0, SC_NS)`〔L3〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(a); }
  void a() {
    wait(1, SC_NS);
    cout << "A before d=" << sc_delta_count() << " @" << sc_time_stamp() << endl;
    wait(0, SC_NS);
    cout << "A after  d=" << sc_delta_count() << " @" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`A after` 的時間與 delta 是？

- A. 時間仍是 `1 ns`，delta 比 `before` 多 1
- B. 時間仍是 `1 ns`，delta 與 `before` 相同（`wait(0)` 什麼都不做）
- C. 時間變成 `2 ns`
- D. 執行期錯誤，`wait` 的時間不能是 0

<details>
<summary>答案</summary>

**A。** `wait(0, SC_NS)`（零長度的時間）等同於 `wait(SC_ZERO_TIME)`：是一個 **delta 等待**，讓出執行權、下一個 delta cycle 才繼續，time 不變。它不是「什麼都不做」，也不會報錯。

```
A before d=1 @1 ns
A after  d=2 @1 ns
```

</details>

---

#### MC22：`sc_event_queue` 與 `sc_event` 的差別〔L3〕

```cpp
SC_MODULE(M) {
  sc_event_queue q;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(n); }
  void w() {
    for (;;) {
      wait(q.default_event());
      cout << "q woke @" << sc_time_stamp() << " d=" << sc_delta_count() << endl;
    }
  }
  void n() {
    q.notify(1, SC_NS);
    q.notify(2, SC_NS);
    q.notify(1, SC_NS);
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

`w` 被喚醒幾次？（如果 `q` 是普通 `sc_event`，依 MC9 只會醒一次）

- A. 一次，在 `1 ns`
- B. 兩次，`1 ns` 和 `2 ns`
- C. 三次，在 `1 ns`、`2 ns`、`3 ns`
- D. 三次：`1 ns`、`1 ns`（下一個 delta）、`2 ns`

<details>
<summary>答案</summary>

**D。** `sc_event_queue` 會把**每一次**通知都保留下來，依時間依序送出；兩個通知在同一個時間點（1 ns）時，它們被錯開在連續的 delta cycle，所以 `w` 會在 `1 ns` 醒兩次（`d` 差 1），再在 `2 ns` 醒一次。需要「不能掉任何一次通知」的情境（例如每個到來的封包都要處理）用它，普通 `sc_event` 會把重疊的通知合併成一個。

```
q woke @1 ns d=1
q woke @1 ns d=2
q woke @2 ns d=3
```

</details>

---

#### MC23：`SC_METHOD` 比 `SC_THREAD` 便宜多少？〔L3〕

```cpp
static unsigned long n = 0;

SC_MODULE(Th) {
  SC_CTOR(Th) { SC_THREAD(t); }
  void t() { for (;;) { wait(10, SC_NS); ++n; } }
};

SC_MODULE(Me) {
  sc_event ev;
  SC_CTOR(Me) {
    SC_METHOD(m);
    dont_initialize();
    sensitive << ev;
    ev.notify(10, SC_NS);
  }
  void m() { ++n; next_trigger(10, SC_NS); }
};

int sc_main(int argc, char** argv) {
  bool th = argc > 1 && std::string(argv[1]) == "thread";
  if (th) new Th("t"); else new Me("m");
  sc_start(100, SC_MS);
  cout << (th ? "SC_THREAD" : "SC_METHOD") << ": wakeups=" << n << endl;
  return 0;
}
```

兩個版本都在 100 ms 內喚醒約一千萬次（`-O2`）。以下哪個說法最符合實測？

- A. 兩者幾乎一樣快，差在 5% 以內
- B. `SC_THREAD` 比較快，因為 coroutine 切換很便宜
- C. `SC_METHOD` 比較快（耗時少約三到五成），但兩者每次喚醒都要走 timed event queue 和 scheduler，成本仍然是同一個量級，最有效的辦法還是減少喚醒的次數
- D. `SC_METHOD` 快很多，幾乎沒有成本，所以把全部 process 改成 `SC_METHOD` 就能解決 simulation speed 問題

<details>
<summary>答案</summary>

**C。** 本機 `-O2` 實測（同一時段成對交錯重跑 8 次，每次約 9999999 次喚醒）：`SC_THREAD` 約 1.0–1.2 秒，`SC_METHOD` 約 0.6–0.7 秒。`SC_METHOD` 的耗時是 `SC_THREAD` 的 0.54–0.66 倍（少約 34–46%），主要因為不需要切換堆疊（context switch）。絕對秒數會隨機器負載變動，只看相對比例。但兩者每次喚醒都要經過：timed event 的插入與取出（heap 型 priority queue）、runnable 佇列、scheduler 流程，所以只是少了一部分成本（D 錯）。這個差距也遠比「喚醒次數少 1000 倍」（L4-1 的實驗，wall-clock 差距是千倍量級）小。A、B 與實測不符。

程式輸出（wall-clock 因機器而異，只有喚醒次數是固定的）：

```
SC_THREAD: wakeups=9999999
```

換成 `./x method` 則是 `SC_METHOD: wakeups=9999999`。數字只代表本機，不要當通用常數。

</details>

---

### 補充題（MC24–MC38）：channel、process 控制與 elaboration

同樣由淺到深排列，每題標籤獨立標示。程式省略的開頭同上方說明。

---

#### MC24：`dont_initialize()` 的 `SC_THREAD`〔L1〕

```cpp
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(t); sensitive << e; dont_initialize(); SC_THREAD(n); }
  void t() { for (;;) { cout << "t @" << sc_time_stamp() << endl; wait(); } }
  void n() { wait(2, SC_NS); e.notify(); wait(3, SC_NS); e.notify(); }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

`t` 會在什麼時間印出？

- A. `t @0 s`、`t @2 ns`、`t @5 ns`
- B. `t @2 ns`、`t @5 ns`
- C. `t @2 ns`、`t @3 ns`、`t @5 ns`
- D. 只有 `t @2 ns`

<details>
<summary>答案</summary>

**B。** `dont_initialize()` 讓 `t` 跳過 time 0 的初始執行。`t` 的 `wait()` 沒有參數，使用靜態敏感度 `e`（見 T3）。`n` 在 2 ns 與 5 ns 通知 `e`，所以 `t` 在這兩個時間被喚醒。`n` 中的 `wait(3, SC_NS)` 是從 2 ns 算起，所以第二次通知是 5 ns，不是 3 ns。

```
t @2 ns
t @5 ns
```

</details>

---

#### MC25：`cancel()` 之後的 timeout〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e;
  SC_CTOR(M) { SC_THREAD(w); SC_THREAD(n); }
  void w() {
    wait(20, SC_NS, e);
    cout << "w woke @" << sc_time_stamp() << endl;
  }
  void n() {
    e.notify(5, SC_NS);
    wait(2, SC_NS);
    e.cancel();
    cout << "cancelled @" << sc_time_stamp() << endl;
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

`w` 在什麼時候醒？

- A. 5 ns
- B. 2 ns
- C. 20 ns
- D. 0 s

<details>
<summary>答案</summary>

**C。** `e.notify(5, SC_NS)` 在 2 ns 被 `e.cancel()` 取消。`w` 的 `wait(20, SC_NS, e)` 因此等到 timeout，在 20 ns 醒。`cancel()` 只取消 pending 的通知，不影響之後的 `wait`。注意 timeout 是從這次 `wait` 開始算（見 MC11）。

```
cancelled @2 ns
w woke @20 ns
```

</details>

---

#### MC26：每次都呼叫 `next_trigger(e)`〔L2〕

```cpp
SC_MODULE(M) {
  sc_event e, tick;
  SC_CTOR(M) { SC_METHOD(m); sensitive << tick; dont_initialize(); SC_THREAD(drv); }
  void m() {
    cout << "m @" << sc_time_stamp() << endl;
    next_trigger(e);
  }
  void drv() {
    wait(1, SC_NS); tick.notify(SC_ZERO_TIME);
    wait(2, SC_NS); tick.notify(SC_ZERO_TIME);
    wait(1, SC_NS); e.notify(SC_ZERO_TIME);
    wait(1, SC_NS); tick.notify(SC_ZERO_TIME);
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

`m` 在哪些時間被呼叫？5 ns 的 `tick` 會叫醒 `m` 嗎？

- A. 1 ns、3 ns、4 ns、5 ns
- B. 1 ns、4 ns、5 ns
- C. 1 ns、3 ns、5 ns
- D. 1 ns、4 ns

<details>
<summary>答案</summary>

**D。** 1 ns 時 `tick` 叫醒 `m`，`m` 呼叫 `next_trigger(e)`。3 ns 的 `tick` 被忽略，因為 `m` 正在等 `e`。4 ns 時 `e` 叫醒 `m`，但 `m` 又呼叫了一次 `next_trigger(e)`，靜態敏感度沒有回來，所以 5 ns 的 `tick` 也被忽略。如果只在 1 ns 呼叫 `next_trigger`，5 ns 就會醒（見 T3 的範例）。

```
m @1 ns
m @4 ns
```

</details>

---

#### MC27：`SC_CTHREAD` 的第一次執行〔L2〕

```cpp
SC_MODULE(M) {
  sc_in<bool> clk;
  SC_CTOR(M) { SC_CTHREAD(t, clk.pos()); }
  void t() { for (int i = 0; i < 3; ++i) { cout << "t @" << sc_time_stamp() << endl; wait(); } }
};
int sc_main(int, char**) {
  sc_clock clk("clk", 10, SC_NS);
  M m("m");
  m.clk(clk);
  sc_start(100, SC_NS);
  return 0;
}
```

`t` 在哪些時間印出？

- A. 10 ns、20 ns、30 ns
- B. 0 s、10 ns、20 ns
- C. 0 s、0 s、0 s
- D. 編譯錯誤，`sc_in` 不能用在 `SC_CTHREAD`

<details>
<summary>答案</summary>

**B。** `SC_CTHREAD` 在初始化時就開始執行，所以第一次印出在 `0 s`。第一個 `wait()` 等的是下一個 posedge，也就是 10 ns，之後是 20 ns。`sc_clock` 預設 posedge 從 0 開始（實測 `clk` 的第一個 posedge 在 0 s）。

```
t @0 s
t @10 ns
t @20 ns
```

</details>

---

#### MC28：`sc_time` 的除法與 `to_seconds()`〔L1〕

```cpp
int sc_main(int, char**) {
  sc_time a(3, SC_NS), b(2, SC_NS);
  cout << a / b << endl;
  cout << a / 2 << endl;
  cout << a.to_seconds() << endl;
  return 0;
}
```

三行輸出是？

- A. `1.5 ns`、`1.5 ns`、`3e-09`
- B. `1.5`、`1500 ps`、`3e-09`
- C. `1`、`1 ns`、`3`
- D. 編譯錯誤，`sc_time` 不能做除法

<details>
<summary>答案</summary>

**B。** `sc_time / sc_time` 得到 `double`（3 ns / 2 ns = 1.5）。`sc_time / double` 得到 `sc_time`，`3 ns / 2 = 1.5 ns`，印出時因為 1.5 ns 不能被 1 ns 整除，選 `1500 ps`。`to_seconds()` 回傳秒數 `3e-09`。

```
1.5
1500 ps
3e-09
```

</details>

---

#### MC29：time resolution 設定得太晚〔L2〕

```cpp
int sc_main(int, char**) {
  sc_time t(1, SC_NS);
  cout << "made " << t << endl;
  sc_set_time_resolution(1, SC_FS);
  cout << "after set " << sc_time(1, SC_NS) << endl;
  return 0;
}
```

程式的結果是？

- A. 三行都正常印出
- B. 印出 `made 1 ns` 後報 E514 錯誤並結束，`after set` 不會印出
- C. 只印警告，程式照常跑完
- D. 編譯錯誤

<details>
<summary>答案</summary>

**B。** `sc_time t(1, SC_NS)` 已經建立，之後的 `sc_set_time_resolution()` 會被拒絕（E514）。錯誤在 `sc_time.cpp:396`。解析度必須在建立任何 `sc_time` 之前設定（見 T6）。

```
made 1 ns

Error: (E514) set time resolution failed: sc_time object(s) constructed
In file: ../../../src/sysc/kernel/sc_time.cpp:396
```

</details>

---

#### MC30：elaboration 與 simulation 的 callback 順序〔L2〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { cout << "ctor" << endl; }
  void before_end_of_elaboration() { cout << "before_end_of_elaboration" << endl; }
  void end_of_elaboration() { cout << "end_of_elaboration" << endl; }
  void start_of_simulation() { cout << "start_of_simulation @" << sc_time_stamp() << endl; }
  void end_of_simulation() { cout << "end_of_simulation @" << sc_time_stamp() << endl; }
};
int sc_main(int, char**) {
  cout << "sc_main" << endl;
  M m("m");
  sc_start(5, SC_NS); sc_stop();
  return 0;
}
```

輸出順序是？（忽略 `Info:` 那一行）

- A. `ctor`、`sc_main`、`before_end_of_elaboration`、`end_of_elaboration`、`start_of_simulation @0 s`、`end_of_simulation @5 ns`
- B. `sc_main`、`ctor`、`before_end_of_elaboration`、`end_of_elaboration`、`start_of_simulation @0 s`、`end_of_simulation @5 ns`
- C. `sc_main`、`ctor`、`start_of_simulation @0 s`、`before_end_of_elaboration`、`end_of_elaboration`、`end_of_simulation @5 ns`
- D. 沒有 `end_of_simulation`，因為 `sc_main` 正常返回

<details>
<summary>答案</summary>

**B。** `sc_main` 先印（M 還沒建立）。建構子執行時印 `ctor`。接著是 `before_end_of_elaboration`、`end_of_elaboration`，第一次 `sc_start` 時進入 `start_of_simulation`，最後 `sc_stop()` 觸發 `end_of_simulation`。D 的錯誤在於：這個程式有呼叫 `sc_stop()`。沒有 `sc_stop()` 時，2.3.3 不會印 `end_of_simulation`（見 T8）。

```
sc_main
ctor
before_end_of_elaboration
end_of_elaboration
start_of_simulation @0 s
Info: /OSCI/SystemC: Simulation stopped by user.
end_of_simulation @5 ns
```

</details>

---

#### MC31：沒有綁定的 `sc_port`〔L2〕

```cpp
SC_MODULE(Child) { sc_in<int> in; SC_CTOR(Child) {} };
SC_MODULE(M) { Child c; SC_CTOR(M) : c("c") {} };
int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "after sc_start" << endl;
  return 0;
}
```

程式的結果是？

- A. 正常印出 `after sc_start`
- B. 編譯錯誤
- C. `sc_start()` 時報 E109，`after sc_start` 不會印出
- D. 只印警告，程式照常跑完

<details>
<summary>答案</summary>

**C。** `c.in` 沒有綁定。綁定檢查在 `sc_start()` 時做，錯誤是 E109（`sc_port.cpp:235`），所以 `after sc_start` 不會出現（見 T9）。

```
Error: (E109) complete binding failed: port not bound: port 'm.c.port_0' (sc_in)
In file: ../../../src/sysc/communication/sc_port.cpp:235
```

</details>

---

#### MC32：`sc_in` 上呼叫 `write()`〔L2〕

```cpp
SC_MODULE(M) {
  sc_in<int> in;
  SC_CTOR(M) { SC_THREAD(t); }
  void t() { in.write(1); }
};
int sc_main(int, char**) { M m("m"); return 0; }
```

程式的結果是？

- A. 正常執行
- B. 編譯錯誤，`sc_in<int>` 沒有 `write()` 成員
- C. 執行期錯誤
- D. 只印警告

<details>
<summary>答案</summary>

**B。** `sc_in<T>` 是 input port，只有讀取的介面。實測的 g++ 錯誤訊息是 `'class sc_core::sc_in<int>' has no member named 'write'`。要寫入應該用 `sc_out<int>`（見 T9）。

</details>

---

#### MC33：`trylock()` 與 `unlock()` 的回傳值〔L2〕

```cpp
SC_MODULE(M) {
  sc_mutex mtx;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() {
    mtx.lock();
    cout << "a locked @" << sc_time_stamp() << endl;
    wait(5, SC_NS);
    mtx.unlock();
    cout << "a unlocked @" << sc_time_stamp() << endl;
  }
  void b() {
    wait(1, SC_NS);
    cout << "b trylock=" << mtx.trylock() << " @" << sc_time_stamp() << endl;
    mtx.lock();
    cout << "b locked @" << sc_time_stamp() << endl;
    mtx.unlock();
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

輸出是？（同一時間點上 `a unlocked` 與 `b locked` 的先後不保證，比對時不看順序）

- A. `a locked @0 s`、`b trylock=0 @1 ns`、`a unlocked @5 ns`、`b locked @5 ns`
- B. `a locked @0 s`、`b trylock=-1 @1 ns`、`a unlocked @5 ns`、`b locked @5 ns`
- C. `a locked @0 s`、`b locked @1 ns`、`a unlocked @5 ns`
- D. 執行期錯誤，`lock` 不能重複

<details>
<summary>答案</summary>

**B。** `a` 在 0 s 鎖住，持有 5 ns。`b` 在 1 ns 呼叫 `trylock()`，因為鎖被別人持有，回傳 `-1`（`sc_mutex.cpp:79–86`）。`b` 之後的 `lock()` 會阻塞，直到 5 ns `a` 解鎖。

```
a locked @0 s
b trylock=-1 @1 ns
a unlocked @5 ns
b locked @5 ns
```

</details>

---

#### MC34：`sc_semaphore` 的計數〔L3〕

```cpp
SC_MODULE(M) {
  sc_semaphore sem;
  SC_CTOR(M) : sem("sem", 2) { SC_THREAD(u1); SC_THREAD(u2); SC_THREAD(u3); }
  void use(const char* n) {
    sem.wait();
    cout << n << " got @" << sc_time_stamp() << endl;
    wait(5, SC_NS);
    sem.post();
  }
  void u1() { use("u1"); }
  void u2() { use("u2"); }
  void u3() { use("u3"); }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

三個 thread 取得資源的時間是？（`u1` 與 `u2` 的先後不保證）

- A. `u1 got @0 s`、`u2 got @0 s`、`u3 got @0 s`
- B. `u1 got @0 s`、`u2 got @0 s`、`u3 got @5 ns`
- C. `u1 got @0 s`、`u2 got @5 ns`、`u3 got @10 ns`
- D. `u3` 永遠不會取得，因為死結

<details>
<summary>答案</summary>

**B。** 初始計數為 2，所以 `u1`、`u2` 在 0 s 都取得。`u3` 的 `wait()` 阻塞，直到 `u1` 在 5 ns `post()`，計數回到 1，`u3` 取得（見 T10）。

```
u1 got @0 s
u2 got @0 s
u3 got @5 ns
```

</details>

---

#### MC35：`sc_spawn` 動態建立 process〔L2〕

```cpp
#include <sysc/kernel/sc_spawn.h>
void worker() {
  cout << "worker @" << sc_time_stamp() << endl;
  wait(3, SC_NS);
  cout << "worker done @" << sc_time_stamp() << endl;
}
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    wait(2, SC_NS);
    sc_process_handle h = sc_spawn(&worker);
    wait(10, SC_NS);
    cout << "terminated=" << h.terminated() << " @" << sc_time_stamp() << endl;
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

輸出是？

- A. `worker @2 ns`、`worker done @5 ns`、`terminated=1 @12 ns`
- B. `worker @0 s`、`worker done @3 ns`、`terminated=1 @12 ns`
- C. `worker @2 ns`、`worker done @5 ns`、`terminated=0 @12 ns`
- D. 執行期 E519，`worker` 裡有 `wait()`，spawn 出來的 process 不能是 `SC_THREAD`

<details>
<summary>答案</summary>

**A。** `t` 在 2 ns 才 `sc_spawn`，所以 `worker` 從 2 ns 開始。它 `wait(3, SC_NS)` 後在 5 ns 結束。`t` 在 12 ns 查詢 `h.terminated()` 得到 `1`。D 錯在 `sc_spawn` 預設產生的是 `SC_THREAD`，可以 `wait()`（見 T11）。

```
worker @2 ns
worker done @5 ns
terminated=1 @12 ns
```

</details>

---

#### MC36：`sc_pause()` 之後接著 `sc_start()`〔L2〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(t); }
  void t() {
    wait(3, SC_NS);
    cout << "pause @" << sc_time_stamp() << endl;
    sc_pause();
    wait(2, SC_NS);
    cout << "t @" << sc_time_stamp() << endl;
  }
};
int sc_main(int, char**) {
  M m("m");
  sc_start();
  cout << "returned @" << sc_time_stamp() << endl;
  sc_start();
  cout << "returned again @" << sc_time_stamp() << endl;
  return 0;
}
```

輸出是？

- A. `pause @3 ns`、`returned @3 ns`、`t @5 ns`、`returned again @5 ns`
- B. `pause @3 ns`、`t @5 ns`、`returned @5 ns`
- C. `pause @3 ns`、`returned @3 ns`、`t @3 ns`、`returned again @5 ns`
- D. `returned @0 s`、`pause @3 ns`、`t @5 ns`

<details>
<summary>答案</summary>

**A。** `sc_pause()` 讓第一次 `sc_start()` 在 3 ns 返回。`sc_start()` 再呼叫時接著跑，`t` 的 `wait(2, SC_NS)` 讓它在 5 ns 印出，之後沒有事件，第二次 `sc_start()` 在 5 ns 返回（見 T7）。

```
pause @3 ns
returned @3 ns
t @5 ns
returned again @5 ns
```

</details>

---

#### MC37：`SC_STOP_IMMEDIATE`〔L3〕

```cpp
SC_MODULE(M) {
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() {
    wait(1, SC_NS);
    sc_stop();
    cout << "A after sc_stop" << endl;
    wait(SC_ZERO_TIME);
    cout << "A next delta" << endl;
  }
  void b() {
    wait(1, SC_NS);
    cout << "B same delta" << endl;
  }
};
int sc_main(int, char**) {
  sc_set_stop_mode(SC_STOP_IMMEDIATE);
  M m("m");
  sc_start();
  cout << "end @" << sc_time_stamp() << endl;
  return 0;
}
```

輸出是？（忽略 `Info:` 那一行）

- A. `A after sc_stop`、`B same delta`、`end @1 ns`
- B. `A after sc_stop`、`end @1 ns`
- C. `A after sc_stop`、`A next delta`、`B same delta`、`end @1 ns`
- D. 全部都會印，包含 `A next delta`

<details>
<summary>答案</summary>

**B。** `sc_stop()` 不會讓 `A` 目前這一行停下來，所以 `A after sc_stop` 會印。但 `SC_STOP_IMMEDIATE` 會清掉目前 delta 裡還沒執行的 runnable process（`sc_simcontext.cpp:1015`，對照 `:992` 的註解），所以 `B` 的 `same delta` 被跳過。下一個 delta 也不會開始，所以 `A next delta` 不會印。比較 MC19 的預設模式，`B` 會印出來。

```
A after sc_stop
Info: /OSCI/SystemC: Simulation stopped by user.
end @1 ns
```

</details>

---

#### MC38：`sc_fifo` 的 `nb_write` / `nb_read` 與 update 時序〔L3〕

```cpp
SC_MODULE(M) {
  sc_fifo<int> f;
  SC_CTOR(M) : f(2) { SC_THREAD(t); }
  void t() {
    int w1 = f.nb_write(1);
    int w2 = f.nb_write(2);
    int w3 = f.nb_write(3);
    cout << "w1=" << w1 << " w2=" << w2 << " w3=" << w3 << endl;
    cout << "num_available=" << f.num_available() << " num_free=" << f.num_free() << endl;
    int v = 0;
    int r1 = f.nb_read(v);
    cout << "r=" << r1 << " v=" << v << endl;
    wait(SC_ZERO_TIME);
    cout << "num_available=" << f.num_available() << endl;
    int r2 = f.nb_read(v);
    cout << "r=" << r2 << " v=" << v << endl;
    int r3 = f.nb_read(v);
    cout << "r=" << r3 << " v=" << v << endl;
    int r4 = f.nb_read(v);
    cout << "r=" << r4 << " v=" << v << endl;
  }
};
int sc_main(int, char**) { M m("m"); sc_start(); return 0; }
```

依序回答：（a）`w3` 是多少？（b）`wait(SC_ZERO_TIME)` 之前 `num_available()` 是多少？（c）`wait` 之前第一次 `nb_read` 的結果是多少？

- A. (a) 1，(b) 2，(c) `r=1 v=1`
- B. (a) 0，(b) 0，(c) `r=0 v=0`
- C. (a) 0，(b) 2，(c) `r=1 v=1`
- D. (a) 0，(b) 0，(c) `r=1 v=1`

<details>
<summary>答案</summary>

**B。** 容量是 2，前兩次寫入成功，第三次 `nb_write` 失敗（回傳 0）。`num_free()` 立刻減少，但 `num_available()` 要等 update phase 才增加，所以同一個 delta 裡讀不到剛寫的資料（`sc_fifo.h:113`、`:350–356`）。`wait(SC_ZERO_TIME)` 之後 `num_available()` 變成 2，`nb_read` 才能讀到。

```
w1=1 w2=1 w3=0
num_available=0 num_free=0
r=0 v=0
num_available=2
r=1 v=1
r=1 v=2
r=0 v=2
```

</details>

---

---

### 選擇題驗證紀錄（2026-10-21）

- 環境：本機 SystemC 2.3.3，`g++ -std=c++11 -O2`（見檔案開頭）。
- 方式：寫完後用腳本從這份檔案抽出每題的程式碼，補上開頭四行，實際編譯執行，再把輸出逐行與答案裡的輸出區塊比對（會多印的 SystemC 版本橫幅、空行不比；同一時間點上先後順序標準不保證的題目，比對時不看順序）。MC23 的輸出是 wall-clock，只比對喚醒次數那一行。
- 原始碼核對（SystemC 2.3.3，2026-10-21）：
  - MC9：`sc_event::notify(const sc_time&)`（`sc_event.cpp`）：已有 delta 通知時，新的延遲通知直接 return；已有 timed 通知時，新的通知只有「更早」才取代（`m_timed->m_notify_time <= now + t` 就 return），`SC_ZERO_TIME` 會取消 timed 改成 delta；`notify()`（immediate）先 `cancel()` 再 `trigger()`。immediate 通知只能在 evaluation phase 呼叫，在 elaboration 或 update phase 呼叫會報錯。
  - MC22：`sc_event_queue::notify` 把每次通知放進 priority queue，`fire_event` 每次只取出一個，剩下還有的再用 `m_e.notify(時間差)` 排下一次，同一時間的第二個通知時間差為 0，因此變成下一個 delta。
  - MC14：`sc_writer_policy_check_write::check_write`（`sc_writer_policy.h`）比較的是 writer 的 process 是否相同，預設（`SC_ONE_WRITER`）不管 delta；環境變數 `SC_SIGNAL_WRITE_CHECK` 在 `sc_simcontext.cpp` 讀取，值是 `DISABLE`、`CONFLICT` 或其他（預設）。
  - MC15：`sc_buffer::write` 無條件 `request_update()`；`sc_signal_t::write` 只在 `m_new_val != value_` 時才 `request_update()`。
  - MC19：`stop_mode` 預設 `SC_STOP_FINISH_DELTA`（`sc_simcontext.cpp`）。
- 沒有核對 IEEE 1666 標準原文（本機沒有）：上面是 2.3.3 的實作行為，標準條文本身沒有查。

---

## 問答題（從這裡開始）

下面是 L1–L4 的問答、預測輸出與口述題。選擇題熟了再做這一段。

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

### L2-4：`sc_mutex` 與 `sc_semaphore`〔L2〕

用 T10 的兩段程式回答：

1. `trylock()` 回傳 `-1` 代表什麼？非持有者呼叫 `unlock()` 會怎樣？
2. 「4 個 process 搶 2 個 DMA 通道」應該用 `sc_mutex` 還是 `sc_semaphore`？為什麼？
3. 忘記 `unlock()`，會看到什麼症狀？kernel 會報錯嗎？

<details>
<summary>提示</summary>

- 想想 mutex 的狀態只有「被誰持有」，semaphore 的狀態是「剩幾個」。
- 忘記 unlock 的時候，還有沒有任何會叫醒等待者的事件？

</details>

<details>
<summary>參考答案</summary>

1. `-1` 表示鎖已被別的 process 持有，`trylock()` 沒有阻塞就返回。非持有者呼叫 `unlock()` 回傳 `-1`，鎖不會被解開（`sc_mutex.cpp:93–96`，實測見 T10）。
2. `sc_semaphore`，初始值 2。mutex 只允許一個持有者，表達不了「兩個資源」。
3. 其他 process 永遠阻塞，kernel 不會報錯；沒有 pending 事件時 `sc_start()` 就返回（實測見 T10 的 `t_mutex_leak`）。這種 bug 只能靠 log 或 end-of-sim 檢查發現，所以測試時要檢查每個 process 是否走完。

</details>

---

### L2-5：`SC_CTHREAD` 與 reset〔L2〕

用 T4 的 `t_cthread_reset2` 程式回答：

1. 為什麼 `reset-branch @0 s` 會在第一個 clock edge 之前印出？
2. `rst` 在 25 ns 拉高，為什麼 counter 要到 30 ns 才歸零？它在 40 ns 的第一個值是多少？
3. 如果把 `reset_signal_is(rst, true)` 拿掉，reset 還會生效嗎？你要怎麼驗證？

<details>
<summary>提示</summary>

- `SC_CTHREAD` 什麼時候開始執行？它是被 edge 叫醒的嗎？
- reset 是在 edge 上檢查還是在 `rst` 寫入的當下檢查？

</details>

<details>
<summary>參考答案</summary>

1. `SC_CTHREAD` 在初始化階段就開始執行，不是等 edge。所以 reset 分支在 `0 s` 先跑一次，之後的第一個 `wait()` 才等下一個 edge。
2. 30 ns 是 `rst` 為 true 時的第一個 posedge（`rst` 在 25 ns 寫入、經 update 生效，下一個 edge 才看得到）。之後 thread 從頭跑 reset 分支，第一個 `wait()` 讓它在 40 ns 才印第一個值，所以是 `count=0 @40 ns`。
3. 不會。實測把 `reset_signal_is` 拿掉（其他不變），`count` 在 25–35 ns 的 reset 期間照樣增加：`count=0 @10 ns`、`1 @20`、`2 @30`、`3 @40`、`4 @50`。

</details>

---

### L2-6：`sc_spawn` 的 process 型態與生命週期〔L2〕

1. `sc_spawn(&worker)` 預設產生什麼型態的 process？它從哪個時間點開始跑？（參考 MC35）
2. 如果要讓 spawn 出來的 process 只在某個 `sc_event` 觸發，且不要在初始化時執行，`sc_spawn_options` 要怎麼設？（參考 T11）
3. `h.terminated()` 什麼時候是 `true`？它能不能代替同步（例如等 worker 結束再繼續）？

<details>
<summary>提示</summary>

- 「spawn 的時間」與「process 的初始執行」是兩回事。
- 查 `sc_process_handle` 的成員，看看有沒有 wait 之類的同步介面。

</details>

<details>
<summary>參考答案</summary>

1. 預設是 `SC_THREAD`，在呼叫 `sc_spawn()` 的那個時間點開始跑（MC35 實測在 2 ns 呼叫，`worker` 也在 2 ns 開始）。
2. 用 `o.spawn_method()`、`o.set_sensitivity(&e)`、`o.dont_initialize()`（`t_spawn_opts` 的寫法）。
3. process 結束後 `terminated()` 為 `true`。它只是查詢狀態，不會阻塞。要等它結束，必須自己用 event、semaphore 或 `sc_join` 之類的機制同步（`sc_join` 這一輪沒有驗證，請自己查 `sc_join.h`）。

</details>

---

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

### L3-2：elaboration 與 simulation callback〔L3〕

1. 依序列出：建構子、`before_end_of_elaboration`、`end_of_elaboration`、`start_of_simulation`、`end_of_simulation`，各在什麼時候被呼叫？
2. 為什麼不能在 `start_of_simulation()` 裡 `new` 一個 module？看到的錯誤是哪個代碼？
3. 2.3.3 中，`sc_main` 正常返回而沒有呼叫 `sc_stop()` 時，`end_of_simulation()` 會不會被呼叫？你會怎麼驗證？標準條文你會去哪裡查？

<details>
<summary>提示</summary>

- 想想「elaboration」結束之後，kernel 是否還允許註冊新的 module。
- 看 `sc_simcontext::end()` 有哪些呼叫點（`grep -n "end()" sc_simcontext.cpp`）。

</details>

<details>
<summary>參考答案</summary>

1. 建構子：`sc_module` 物件建立時（elaboration）。`before_end_of_elaboration()`、`end_of_elaboration()`：elaboration 結束前後（MC30）。`start_of_simulation()`：第一次 `sc_start()` 進入模擬前。`end_of_simulation()`：模擬結束的通知（在 2.3.3 中只在 `sc_stop()` 之後，見 T8）。
2. elaboration 結束後，module registry 不接受新 module，錯誤是 E529（`sc_module_registry.cpp:54`，實測見 T8）。
3. 2.3.3 不會呼叫（`sc_simcontext::end()` 只在 `do_sc_stop_action()` 呼叫，`sc_simcontext.cpp:963`）。驗證方法是寫一個 `sc_main` 不呼叫 `sc_stop()`、在 `end_of_simulation` 印字，看有沒有輸出（MC30 的 D 選項就是這個陷阱）。標準條文 IEEE 1666-2011 本機沒有，這裡沒有核對，要查標準原文的 simulation termination 段落，不要只依賴實作行為。

</details>

---

### L3-3：port 與 export 的綁定〔L3〕

1. 為什麼 `sc_port` 的綁定要留到 elaboration 才做？綁定檢查在哪個時間點發生？（參考 MC31）
2. 寫 `exp(port)` 為什麼編譯失敗？`sc_export` 應該綁什麼？（參考 T9）
3. 面試官問：「為什麼 channel 不直接用指標傳給子模組？」你會怎麼回答？

<details>
<summary>提示</summary>

- port 的意思是「我需要一個實作某 interface 的東西」。它本身不是實作。
- 想想如果子模組直接拿到 `sc_fifo*`，換一個 channel 實作要改哪裡。

</details>

<details>
<summary>參考答案</summary>

1. port 在建構時還不知道誰會實作它，等整個 hierarchy 建好才能確認。檢查在 `sc_start()` 的 elaboration 結束時做，未綁定就報 E109（MC31）。
2. `sc_export::operator()` 只接受 interface（`IF&`），port 不是 interface 的實作。export 應該綁到 channel（例如 `sc_fifo`）本身，子模組的 port 再綁到這個 export（T9 的 `t_export`）。
3. 答案要點：port/export 讓 module 只依賴 interface，不依賴具體 channel；elaboration 時綁定，錯誤（未綁定、型別不符）在 elaboration 就會抓到；換實作或插入 TLM 中介層時不用改子模組。這是 TLM 的基礎概念。

</details>

---

### L3-4：testbench 的控制流程〔L3〕

情境：你寫一個 testbench，要跑 300 ns，每 100 ns 檢查一次 DUT 狀態；某個條件（例如 `done` 事件）發生時，要讓 `sc_main` 停下來檢查，然後繼續跑；全部結束時要收尾。

1. 這三種需求分別用 `sc_start(t)`、`sc_pause()` 還是 `sc_stop()`？各舉一個適合的情境。
2. 在 `sc_main` 裡呼叫 `sc_stop()`，會不會觸發 `end_of_simulation()`？（參考 T8）
3. 用 `SC_STOP_IMMEDIATE` 會有什麼代價？為什麼 testbench 通常不用它？

<details>
<summary>提示</summary>

- `sc_start(t)` 是相對時間；`sc_pause()` 是 process 通知 `sc_start` 返回；`sc_stop()` 是結束。
- 想想 `SC_STOP_IMMEDIATE` 會跳過哪些 process。

</details>

<details>
<summary>參考答案</summary>

1. 每 100 ns 檢查：用 `sc_start(100, SC_NS)` 的迴圈。`done` 事件要 main 介入：process 裡 `sc_pause()`，`sc_main` 在 `sc_start` 返回後檢查，再 `sc_start()` 續跑（MC36）。全部結束：`sc_stop()`。
2. 會。實測 `sc_stop()` 從 `sc_main` 呼叫時會印 `Simulation stopped by user.` 並觸發 `end_of_simulation()`（MC30）。
3. 代價是 delta 中剩下的 process 直接被跳過（MC37），狀態可能不一致，檢查結果就不可靠。testbench 一般用預設的 `SC_STOP_FINISH_DELTA`，讓目前 delta 跑完再停。

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

在 `SC_MODULE` 裡寫的 `wait(t)` 要經過三層呼叫：`sc_module::wait(const sc_time&)`（`sc_module.h:191`，類別作用域先找到的成員，內部呼叫 `::sc_core::wait(t, simcontext())`）→ sc_core 自由函式 `wait(const sc_time&, sc_simcontext*)`（宣告 `sc_wait.h:71`，定義 `sc_wait.cpp:162`，依目前 process 的類別分派）→ `sc_thread_process::wait(const sc_time&)`（`sc_thread_process.h:316`）。`sc_thread_process.h:87` 只是自由函式的前向宣告。每一次這樣的呼叫都要：

- 呼叫 `m_timeout_event_p->notify_internal(t)`：在 timed event queue（`m_timed_events`）裡新增一個 `sc_event_timed`，queue 是 heap 實作的 priority queue（`sc_ppq`，`src/sysc/utils/sc_pq.h`），insert 與 `extract_top` 都是 `O(log N)`。
- `add_dynamic(this)` 把 process 掛到該事件的動態敏感清單。
- `suspend_me()` → `cor_pkg()->yield(...)`：**coroutine 切換**（保存暫存器、切換堆疊），回到 scheduler。
- 時間到時：`simulate()` 取出 timed event、`trigger()`，把 process 放進 runnable，`crunch()` 再走一遍 evaluate→update→notification，最後 `m_cor_pkg->yield(thread_h->m_cor_p)` 切回 thread。

也就是：**一次喚醒 = 一次 timed event 的插入與取出 + 兩次 context switch + 一輪 scheduler 流程**，跟你在 `wait` 後面做的事情多寡無關。喚醒的次數和 simulation time 成正比、和 cycle 數成正比。

**2. 實測（本機，`-O2`，`sc_start(100, SC_MS)`）**

```
fine(10ns): wakeups=9999999 wall=0.958s
coarse(10us): wakeups=9999 wall=0.001s
```

上面的 `0.958s` 是同一台機器重跑 10 次中的一次；coarse 的 `0.001s` 已到計時解析度，只能說低於 0.002 s。

喚醒次數差 1000 倍。fine 端 wall-clock 的範圍是 `0.93–1.08 s`（10 次重跑，`-O2`，`sc_start(100, SC_MS)`），換算成平均每次喚醒約 `93–108 ns`。同一台機器前後的紀錄還有 `0.649 s`（原紀錄）與 `0.923 s`（審查重跑），跨時段差異可達約 1.7 倍（`0.649 s` 對 `1.08 s`），所以**只比相對比例與數量級**：fine 與 coarse 的 wall-clock 差距是千倍量級，絕對秒數與每次喚醒的 ns 數會隨機器負載變動。這是最簡單的 process，模型越複雜（多個 process、signal 更新、每次喚醒又觸發別的事件）每次的成本越高。數字只代表本機這個環境，不要當作通用常數。

**3. 取捨（面試追問方向，答案要自己寫）**

- 精度：`wait` 變粗之後，該 process「看得到事件的時間解析度」變差，原本在某個 cycle 邊界上的行為（例如 poll 某個狀態、timer 到期的精度）現在最多會有一個粗週期的誤差。你要能說明：你的 IP 在什麼前提下這個誤差不影響軟體看到的行為。
- 確認功能一致：回歸測試比對優化前後的輸出（register trace、中斷時序、軟體測試結果）；對時間敏感的行為，要有針對性的測試。
- 如果能用事件驅動取代輪詢（等 interrupt、等 register 被寫）更好：不需要定期喚醒，也沒有精度損失，不過要改設計的程度比較大。

沒有加速倍數的話，面試時要誠實說「確定有變快，數字我沒有留下」，不要編數字；可以用這個實驗的結果說明量級。

</details>

---

### L4-2：你的 msg IP 中的 channel 選擇〔L4〕

1. 你的 msg IP 裡，哪些地方用 `sc_signal`、哪些用 `sc_fifo`、哪些用 `sc_event`？每一種各舉一個例子，說明你為什麼這樣選。
2. 如果把其中一個 `sc_fifo` 換成 `sc_buffer` 或直接用 `sc_event` 通知，行為會改變哪些地方？用 MC9、MC15、MC38 的規則回答。
3. 如果你的模型有 back-pressure 的問題（producer 等 consumer），你會用 `write()` 的阻塞行為，還是 `nb_write()` 加 `num_free()` 檢查？各自的代價是什麼？

<details>
<summary>提示</summary>

- 先想清楚每個通道要表達的是「值」、「佇列」還是「發生了一次」。
- 如果是 `sc_fifo`，想想 `num_available()` 和 `num_free()` 各在什麼時候改變。

</details>

<details>
<summary>參考答案（骨架，要自己用你的 IP 補）</summary>

1. 這一題要用你的實際模型回答，我不替你編。判斷的骨架是：「值要保留到下次讀」用 signal 或 fifo；「只是通知有事發生」用 event；「有順序、可能多筆」用 fifo（或 `sc_event_queue`，MC22）。
2. 要看的規則：`sc_buffer` 每次寫都發事件（MC15）；`sc_event` 同一時間只保留一個 pending 通知（MC9）；`sc_fifo` 的資料要下一個 delta 才能讀（MC38）。
3. 要說清楚兩者的代價：阻塞 `write()` 讓 producer 自動等待，但只能在 thread 裡用；`nb_write()` 要自己處理失敗的情況，但能在 method 裡使用。

</details>

---

## 手寫練習（只給規格與骨架，請自己寫）

這一段跟前面不一樣：**沒有參考解答**。先照規格寫、用骨架裡的 `check()` 自己檢查，寫完再請我看你的版本（會給 review 意見，不會直接貼完整解答）。

### EX-1：用 `sc_semaphore` 限制同時使用的通道數〔L3〕

**規格**
- 4 個 requester（`r0`～`r3`），每個重複 3 次：取得 resource → 使用 4 ns → 歸還。
- 同時可用的 resource 數量是 2。
- 每次取得與歸還都印出 `<name> acquire @時間` / `<name> release @時間`。
- 用計數器 `inuse` 記錄目前使用中的數量；取得後 `++`，歸還前 `--`，並記錄 `max_inuse` 與 `acquisitions`。

**骨架（`ex1_skel.cpp`，需要你補 TODO）**

```cpp
#include <systemc>
using namespace sc_core;
using std::cout;
using std::endl;

static void check(bool ok, const char* msg) { cout << (ok ? "PASS " : "FAIL ") << msg << endl; }

SC_MODULE(Arbiter) {
  sc_semaphore sem;   // TODO: 初始化成 2 個 resource（建構子初始化列表）
  int inuse;          // 目前使用中的數量
  int max_inuse;      // 觀察到的最大同時使用數
  int acquisitions;   // 總共取得次數
  SC_CTOR(Arbiter) : sem("sem", 1) /* TODO: 改成 2 */, inuse(0), max_inuse(0), acquisitions(0) {
    // TODO: 用 SC_THREAD 註冊 4 個 requester。SC_THREAD 不能帶參數，
    //       請寫 4 個小 wrapper（r0..r3）各自呼叫 requester(id)。
  }
  void requester(int id) {
    // TODO: 重複 3 次：sem.wait() -> 記錄 inuse++、max_inuse、acquisitions++ 並印出 -> wait(4 ns) -> inuse-- 並印出 -> sem.post()
    (void)id;
  }
};

int sc_main(int, char**) {
  Arbiter arb("arb");
  sc_start();
  // TODO: 用 check() 檢查：max_inuse == 2、acquisitions == 12、inuse == 0
  check(false, "TODO: fill in checks");
  return 0;
}
```

**自我檢查（harness 的 `check()` 應該全部 PASS）**
- `max_inuse == 2`
- `acquisitions == 12`
- `inuse == 0`（模擬結束時歸零）

**提示**
1. `SC_THREAD` 不能傳參數。要區分 4 個 requester，寫 4 個小的 wrapper，各自呼叫 `requester(id)`。
2. `sc_semaphore` 的建構子第二個參數是初始計數；`sem.wait()` 會阻塞，`sem.post()` 加一（T10）。
3. 「`inuse` 變化」與「`sem` 取得」要寫在 `wait()` 之後或之前？想想計數器的正確性：在取得成功後才能 `++`。
4. 如果 `max_inuse` 是 3，代表你的 semaphore 沒有正確初始化，檢查建構子初始化列表。

---

### EX-2：用 `SC_CTHREAD` 寫同步 reset 的計數器〔L2〕

**規格**
- `Counter` module：`sc_in<bool> clk`、`sc_signal<bool> rst`（active-high，同步 reset）。
- 每個 posedge 印出 `count=N @時間`，然後 `N++`。reset 生效後 `N` 從 0 重新開始。
- `sc_main` 建立 10 ns 的 `sc_clock`，綁到 `clk`。
- driver：`rst` 在 25 ns 拉高，35 ns 拉低。
- `sc_start(60, SC_NS)`。

**骨架（`ex2_skel.cpp`，需要你補 TODO）**

```cpp
#include <systemc>
using namespace sc_core;
using std::cout;
using std::endl;

SC_MODULE(Counter) {
  sc_in<bool> clk;        // 由 sc_main 綁定 sc_clock
  sc_signal<bool> rst;    // 同步、active-high reset
  int count;
  SC_CTOR(Counter) : count(0) {
    // TODO: SC_CTHREAD(run, clk.pos())，並用 reset_signal_is(rst, true) 設定 reset
    SC_THREAD(driver);    // TODO: 若要用 thread 驅動 rst，保留這行，否則刪除
  }
  void driver() {
    // TODO: 在 25 ns 拉高 rst，維持一個 clock cycle 後拉低（時間自己算，注意 posedge 的位置）
  }
  void run() {
    // TODO: reset 分支與主迴圈；每個 posedge 印出 "count=N @時間"，然後 count++
  }
};

int sc_main(int, char**) {
  sc_clock clk("clk", 10, SC_NS);
  Counter c("c");
  c.clk(clk);
  sc_start(60, SC_NS);
  return 0;
}
```

**自我檢查**
- 先在紙上推算每一行的時間，再跑，看是否一致。
- 把 `rst` 的時間改成 45 ns 與 55 ns，預測輸出會怎麼變。

**提示**
1. `SC_CTHREAD` 在初始化時就開始執行，第一個 `wait()` 等的是下一個 edge（T4、MC27）。
2. reset 分支要放在主迴圈之前，reset 生效時 thread 會從頭執行（T4、L2-5）。
3. `rst` 的寫入在 update phase 才生效，所以 25 ns 寫入的值要到下一個 posedge 才看得到（L2-3）。

---


## 下一輪可以加考

以下是還沒出題、或只做了一半的主題。下一輪挑 2–3 題做，不必全部。

- **sc_mutex 的遞迴鎖定**：同一個 process 再次呼叫 `lock()` 的行為（`sc_mutex.cpp:65–72` 的 `m_owner` 判斷），要用程式驗證後再出題。
- **sc_semaphore 的公平性**：標準沒有保證先到先得；可以設計一個會暴露差異的情境，但要標明「依實作，不保證」。
- **`sc_join` 等待多個 spawn 的 process**：目前 T11 只說明 `terminated()` 不會阻塞，還沒驗證 `sc_join`。
- **`async_reset_signal_is` 與 `reset_signal_is` 的差異**：本輪只驗證了同步 reset（edge 上檢查）。
- **`sc_clock` 的 duty cycle、start_time、`posedge_first`**：本輪只用了預設值。
- **`wait(t, SC_NS, list)` 與 `sc_event_and_list` 的 timeout 組合**：MC10、MC11 只有單一事件與 OR/AND。
- **多個 module 的 `end_of_simulation` 順序**：目前只有一個 module，順序未驗證。
- **`sc_port` 的綁定策略**（如 `SC_ONE_OR_MORE_BOUND`）與 E109 的關係：T9 只說明未綁定會報錯。
- **`SC_METHOD` 的 `next_trigger(time)` 與靜態敏感度組合**：MC16 的延伸，讓 method 在兩種觸發之間切換。
- **`sc_time` 的大數值與比較**：超出 64 位元 tick 範圍時的行為（只是出題方向，尚未實測）。

---

## 核對紀錄（2026-10-21）

- 所有程式碼用 `g++ -std=c++11`（見上）編譯並執行；輸出為實測。L1-1 的 `E519` 訊息、L1-3 的 immediate notify 遺失、L2-1～L2-3 的輸出、L4-1 的 wall-clock 都出自實跑。
- 原始碼對照：`sc_simcontext::crunch`（evaluate / update / delta notification 與 `m_delta_count` 遞增）、`sc_simcontext::simulate`（時間推進，終點 `until_t` 的 delta 不執行）、`sc_thread_process::wait` 與 `suspend_me`、`sc_cor_pkg_qt::yield`、`sc_wait.cpp` 中 `SC_ID_WAIT_NOT_ALLOWED_` 的錯誤訊息。
- 未核對項目：IEEE 1666 標準原文（本機沒有），涉及「標準保證什麼」的敘述（`m1` 與 `m2` 順序、`wait(SC_ZERO_TIME)` 與 delta 事件的順序為不保證）依 SystemC 語意的一般理解，沒有查標準條文。
- `sc_signal` 的 `m_cur_val` / `m_new_val` 欄位（L2-3）有在 `sc_signal.h` 看到；`write()` 登記到 update 清單的流程沒有逐行追。
- `sc_ppq` 為 heap 實作（`sc_pq.h`）、本機 library 含 `sc_cor_pkg_qt`（QuickThreads）已確認。

### 事實修正（2026-11-03）

以下每項列出原敘述、實測（SystemC 2.3.3，`g++ -std=c++11 -O2` 或 `-O0`，本機 12 核，同一時段）與修改。

1. **L4-1 wall-clock**
   - 原敘述：「約 0.667 s」「平均約 67 ns」，與同段實測 0.649 s 不一致；審查重跑 0.923 s。
   - 實測：fine(10ns) 同機重跑 10 次，wall-clock `0.930–1.082 s`，每次喚醒約 `93–108 ns`；coarse(10us) 為 `0.001 s`（已到計時解析度）。
   - 修改：輸出區塊與文字改為區間，註明只比相對比例、絕對值隨機器變動，並保留原 0.649 s、0.923 s 作為跨時段參考。

2. **L4-1 的 `wait` 簽章**
   - 原敘述：`sc_thread_process::wait( const sc_time& )`，`sc_thread_process.h`。
   - 原始碼（三層）：`SC_MODULE` 內的 `wait(t)` 先找到成員 `sc_module::wait(const sc_time&)`（`sc_module.h:191`，內部呼叫 `::sc_core::wait(t, simcontext())`）；自由函式 `wait(const sc_time&, sc_simcontext*)` 宣告於 `sc_wait.h:71`、定義於 `sc_wait.cpp:162`，依 process 類別分派；thread 的成員 `sc_thread_process::wait(const sc_time&)` 定義於 `sc_thread_process.h:316`（宣告 `:158`）。`sc_thread_process.h:87` 只是自由函式的前向宣告。
   - 修改：L4-1 參考答案改寫為三層呼叫，並列出每層行號。全檔只有 L4-1 這一處寫成單獨的成員簽章；核對紀錄中提到 `sc_thread_process::wait` 的地方只是名稱列舉，未改。

3. **MC14 `SC_SIGNAL_WRITE_CHECK=CONFLICT` 的語意**
   - 原敘述：`CONFLICT` 只檢查同一 delta 內的衝突寫入；`DISABLE` 完全不檢查；兩者都讓原程式正常印出 `finished`。
   - 實測（兩個 process 寫同一 `sc_signal<int>`）：

     | 情境 | 未設 | `CONFLICT` | `DISABLE` |
     |---|---|---|---|
     | 原題（`1 ns` 與 `5 ns` 寫入） | E115 於 `5 ns` | `finished` | `finished` |
     | 同一 delta（兩者都在 `1 ns`） | E115 | E115（多一行 `conflicting write in delta cycle 1`） | 正常，`s=2` |
     | 不同 delta（同為 `1 ns`，後者先 `wait(SC_ZERO_TIME)`） | E115 | 正常，`s=2` | 正常，`s=2` |

   - `SC_MANY_WRITERS` 版本（同一段原題程式）實測正常結束，`s=2`。但 `SC_MANY_WRITERS` 的 policy 繼承 `sc_writer_policy_check_delta`（`sc_writer_policy.h:141–144`），同一 delta 的衝突寫入仍報 E115，見下表最後兩列。
   - 補充表（`SC_MANY_WRITERS`）：

     | 情境 | 未設 | `CONFLICT` | `DISABLE` |
     |---|---|---|---|
     | `SC_MANY_WRITERS`，同一 delta（`1 ns`） | E115（`conflicting write in delta cycle 1`） | E115 | 正常，`s=2` |
     | `SC_MANY_WRITERS`，不同 delta（同為 `1 ns`） | 正常，`s=2` | 正常，`s=2` | 正常，`s=2` |

   - `SC_UNCHECKED_WRITERS`（非標準）實測同一 delta 也正常，`s=2`，未設環境變數。
   - 修改：原文的「同一段程式改成 `SC_MANY_WRITERS` 可正常結束」與環境變數描述一致，未改結論；原本「要自己確保同一 delta 不會衝突」的說法與實測不符，已改寫為 kernel 仍會報同一 delta 的衝突（見上）。原始碼依據：`sc_simcontext.cpp:328–335`、`sc_simcontext_int.h:91–92`、`sc_signal.h:47–67`、`sc_signal.h:70–74`。

4. **補驗的題目**
   - MC5、MC6、MC16、MC17：重跑輸出與答案區塊逐行一致，已重跑無誤。
   - MC20：重跑輸出一致；`crunch(true)` 分支已對照 `sc_simcontext.cpp` 的 `simulate`（`:867–870`）、`crunch`（`:595`）與 `initialize`／`initial_crunch`（`:796`），答案中已補行號。
   - MC23：wall-clock 原數字不符（同機重跑 `SC_THREAD` 約 1.0–1.2 s、`SC_METHOD` 約 0.6–0.7 s，成對比例 `0.54–0.66`）。已改為區間與比例，選項 C 的「少約四成」改為「少約三到五成」（實測少 34–46%，原「約四成」落在範圍內，但 41–46% 的部分不在「三到四成」內）；喚醒次數 `9999999` 不變。
   - L1-1 第 3 點 `m1`／`m2`：輸出與文件一致，但文件沒有附程式碼，無法直接重現。依輸出重建如下，結果一致（`m1 @0 s v=0`、`m2 @1 ns v=1`、`m1 @1 ns v=1`、`m2 @2 ns v=0`、`m1 @2 ns v=0`）。重建程式只存於本紀錄，未改動題目本文：

     ```cpp
     SC_MODULE(M) {
       sc_signal<int> v;
       SC_CTOR(M) {
         SC_METHOD(m1); sensitive << v;
         SC_METHOD(m2); sensitive << v; dont_initialize();
         SC_THREAD(drv);
       }
       void m1() { cout << "m1 @" << sc_time_stamp() << " v=" << v.read() << endl; }
       void m2() { cout << "m2 @" << sc_time_stamp() << " v=" << v.read() << endl; }
       void drv() { wait(1, SC_NS); v.write(1); wait(1, SC_NS); v.write(0); }
     };
     ```

---

## 核對紀錄（2026-11-05 第二輪）

- **環境**：本機 SystemC 2.3.3，library 在 `/home/alan/cpp_practice/side_project/uArch/systemc-2.3.3`（`lib-linux64/libsystemc.so`）。編譯 `g++ -std=c++11 -O0 -I$S/include x.cpp -L$S/lib-linux64 -lsystemc -Wl,-rpath,$S/lib-linux64`。實際的測試程式與輸出存在 `/tmp/claude-1000/-mnt-c-Users-FengAn-Documents-resume/29103af2-e193-4832-9e43-1b02a70074da/scratchpad/sc/`（`run.sh` 負責編譯與執行）。
- **新增題目（MC24–MC38、L2-4–L2-6、L3-2–L3-4、L4-2、EX-1、EX-2）**：每個 predict-the-output 程式都獨立編譯、執行，輸出貼的是實測結果。同一時間點上 process 先後不一致的行，比對時不看順序（MC33、MC34、MC19 同類）。
- **教學範例（T1–T11）**：每個附輸出的範例都實跑過。T1 的 E519、T8 的 E529、T9 的 E109 與 export 寫法的編譯錯誤、T10 的 mutex 回傳值與 starvation、T11 的 spawn 選項與 E519，都是實測。
- **修正過程中自己發現的問題（已修正，未進入最終題目）**：
  - 初版 MC26 的程式在 4 ns 被 `e` 叫醒後又呼叫 `next_trigger(e)`，導致 5 ns 的 `tick` 不被處理。這是測試程式的寫法，不是 kernel 的 bug；另寫了只在 1 ns 呼叫 `next_trigger` 的對照版本（T3 的 `t_nt_cond`），5 ns 會醒，符合 IEEE 語意。
  - 初版 MC27 用 `sc_clock` 直接當 `SC_CTHREAD` 的 sensitivity，g++ 編譯失敗（`sc_clock` 沒有 `pos()`，`posedge_event()` 也不能當 `SC_CTHREAD` 的 sensitivity）。改成 `sc_in<bool>` 再綁 `sc_clock`。
  - 初版 MC29 的程式我原本想寫成「警告」，實測是 E514 錯誤並結束，已依實測修正。
  - 初版 MC30 沒有呼叫 `sc_stop()`，實測 `end_of_simulation` 沒有印出，所以加上 `sc_stop()`，並在 T8 說明這個行為。
  - 初版 MC38 的 `cout << f.nb_read(v) << v` 寫法在同一個運算式中修改並讀取 `v`，有 unsequenced 的問題。改成分開的語句。
  - 初版 MC35 缺 `#include <sysc/kernel/sc_spawn.h>`，實測 `sc_spawn` 不在 `<systemc>` 的展開範圍內，補上。
- **原始碼核對（SystemC 2.3.3）**：
  - `sc_event::cancel()`：`sc_event.cpp:66` 起（T2）。
  - `sc_simcontext::end()` 只在 `do_sc_stop_action()` 中呼叫：`sc_simcontext.cpp:959–968`、`:1031–1040`；`stop()` 的註解說明 sc_main 直接呼叫時會做 end-of-simulation 通知：`sc_simcontext.cpp:990–1000`（T8）。
  - `SC_STOP_IMMEDIATE` 的 `m_runnable->init()`：`sc_simcontext.cpp:1015`（MC37）。
  - `sc_pause()` 的 `m_paused` 檢查：`sc_simcontext.cpp:589–591`、`:892–897`（MC36、T7）。
  - `sc_mutex::trylock()` / `unlock()` 的回傳值：`sc_mutex.cpp:79–86`、`:93–96`（MC33、T10）。
  - `sc_fifo` 的 `num_free()` / `num_available()` 與 update：`sc_fifo.h:93`、`:113`、`:285`、`:350–356`（MC38、T1）。
  - E514：`sc_time.cpp:396`（MC29）。E109：`sc_port.cpp:235`（MC31）。E529：`sc_module_registry.cpp:54`（T8）。E519 的兩個位置：`sc_wait.cpp:179`（MC3）與 `sc_wait.cpp:93`（T1，blocking fifo write），以及 `sc_wait.cpp:179`（T11，spawn 成 method）。
  - 既有的 `sc_simcontext.cpp:595`、`:867–870`、`:929`（"hold off on the delta"）也重新確認，與 L2-2、MC20 的敘述一致。`:796` 是 `initialize` 裡的 `no_crunch` 判斷，與 MC20 的敘述一致，未逐行追完整條件。
- **重跑既有題目**：L1-3、L2-1、L2-2、L2-3 的輸出與原文逐行一致。既有 MC 題目未重跑，沿用 2026-10-21 的實測紀錄。
- **未核對 / 只依實作**：
  - IEEE 1666-2011 條文本身：本機沒有標準文件，以下都只是 2.3.3 的實作行為：`end_of_simulation` 只在 `sc_stop()` 後觸發、port 綁定檢查（E109）發生在 `end_of_elaboration` callback 之前（MC31 的程式沒有覆寫 callback，只看到 E109 與沒有 callback 輸出，這是觀察）、`SC_CTHREAD` 初始化時就執行、`sc_mutex` 的回傳值、`sc_fifo` 的 update 時序。
  - `sc_join`、`async_reset_signal_is`、`sc_clock` 的進階參數：只在「下一輪可以加考」列出，尚未驗證。
- **事實修正**：本輪沒有發現既有題目的錯誤，既有內容未改動。新增部分的修正見上面的「修正過程中自己發現的問題」。
