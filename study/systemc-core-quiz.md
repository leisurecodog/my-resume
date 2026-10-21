# SystemC 核心：process、event、delta cycle 與 scheduler 複習題

對應 `tasks/learning-plan.md` 的 SystemC / TLM 基礎，也是 `study/tlm-quiz.md` 的前置：TLM 的 `b_transport`、quantum 都建立在 `wait()`、`sc_event` 和 scheduler 之上。目標是能解釋 SystemC 的執行模型，並說明「每個 clock cycle 都 `wait` 為什麼慢」。

用法跟其他題庫一樣：先自己想或寫在紙上，再展開 `<details>` 對照。

**難度分級**：L1 學習（看懂概念，附提示）→ L2 應用（預測輸出）→ L3 面試（口述）→ L4 深入（連結你的案例，對照原始碼）。建議順序：先做選擇題（MC1–MC23，由淺到深），再做問答題（L1 → L4）。

**環境與驗證方式**：本機 SystemC 2.3.3，原始碼在 `~/cpp_practice/side_project/uArch/systemc-2.3.3`。本檔所有程式碼都實際編譯、執行過，輸出貼的是實測結果（2026-10-21）。編譯指令：

```
S=~/cpp_practice/side_project/uArch/systemc-2.3.3
g++ -std=c++11 -I$S/include x.cpp -L$S/lib-linux64 -lsystemc -Wl,-rpath,$S/lib-linux64 -o x
```

注意：這份 library 是用 C++11 編的（`sc_api_version_2_3_3_cxx201103L`），用 `-std=c++14` 會在連結階段報 `undefined reference to sc_api_version_...`，要用 `-std=c++11`。程式入口是 `sc_main`，不是 `main`。

---

## 目錄
- [選擇題：先建立直覺 (MC1–MC23)](#選擇題先建立直覺mc1mc23)（先做這一段，再做下面的問答題）
- [L1：入門 (L1-1–L1-3)](#l1入門)
- [L2：預測輸出 (L2-1–L2-3)](#l2預測輸出)
- [L3：scheduler 口述 (L3-1)](#l3scheduler-口述)
- [L4：simulation speed 案例 (L4-1)](#l4simulation-speed-案例)
- [核對紀錄](#核對紀錄2026-10-21)

---

## 選擇題：先建立直覺（MC1–MC23）

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

這是 IEEE 1666 的預設檢查；本機 2.3.3 另有環境變數 `SC_SIGNAL_WRITE_CHECK`：設成 `CONFLICT` 時只檢查「同一個 delta 內的衝突寫入」，設成 `DISABLE` 時完全不檢查（實測兩者都讓這段程式正常印出 `finished`）。不要靠環境變數繞過，要多個 writer 必須明確宣告 `sc_signal<int, SC_MANY_WRITERS>`（本機實測同一段程式改成這樣可以正常結束，`s` 最後是 2），但這時要自己確保同一個 delta 內不會有衝突的寫入。

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

**C。** `sc_start(SC_ZERO_TIME)` 只執行**一個 delta cycle** 就返回（simulation time 不前進），每次呼叫推進一個 delta。這個用法在 debug 時很有用（單步看 delta），也能在 testbench 裡把 reset 結束後的初始化先跑完。原始碼 `sc_simcontext::simulate` 對 `duration == SC_ZERO_TIME` 有專門的分支：`crunch(true)`，也就是只跑一輪。

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
- C. `SC_METHOD` 比較快（耗時少約四成），但兩者每次喚醒都要走 timed event queue 和 scheduler，成本仍然是同一個量級，最有效的辦法還是減少喚醒的次數
- D. `SC_METHOD` 快很多，幾乎沒有成本，所以把全部 process 改成 `SC_METHOD` 就能解決 simulation speed 問題

<details>
<summary>答案</summary>

**C。** 本機 `-O2` 實測（各跑 3 次，每次約 9999999 次喚醒）：`SC_THREAD` 約 0.73–0.78 秒，`SC_METHOD` 約 0.45–0.47 秒，`SC_METHOD` 耗時少了約 40%，因為不需要切換堆疊（context switch）。但兩者每次喚醒都要經過：timed event 的插入與取出（heap 型 priority queue）、runnable 佇列、scheduler 流程，所以只是少了一部分成本（D 錯）。這個差距也遠比「喚醒次數少 1000 倍」（L4-1 的實驗，幾百倍的 wall-clock 差距）小。A、B 與實測不符。

程式輸出（wall-clock 因機器而異，只有喚醒次數是固定的）：

```
SC_THREAD: wakeups=9999999
```

換成 `./x method` 則是 `SC_METHOD: wakeups=9999999`。數字只代表本機，不要當通用常數。

</details>

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
