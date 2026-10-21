# TLM-2.0 LT、Quantum、DMI 複習題

對應 `tasks/learning-plan.md` 的 TLM-2.0 項目，完成標準：能畫出 read/write 流程並解釋加速原理。

用法：先做選擇題（MC1–MC22，由淺到深，程式碼都能在本機跑），再做後面的口述題。口述題先只看題目，用講的方式回答（像在面試現場），講完再展開參考答案對照。每題最後的「上次的弱點」是 2026-10-20 第一次口試的紀錄；Q6–Q8 是之後補的，還沒考過。

情境題請用三段式回答：**元件 + 事件 + 軟體看到的現象**。

Q4 與 Q6–Q8 的參考答案已對照 SystemC 2.3.3 原始碼核對過（`~/cpp_practice/side_project/uArch/systemc-2.3.3`），核對範圍和沒核對到的地方見文末「核對紀錄」。

---

## 選擇題：先建立直覺（MC1–MC22）

單選題，由淺到深（L1 → L3）。做法跟其他兩份題庫一樣：先在紙上選，再展開看每個選項為什麼對或錯，最後挑幾題自己打進編譯器跑（編譯指令見下面，記得 `-std=c++11`）。

本機 SystemC 2.3.3 的 library 是用 C++11 編的，編譯指令：

```
S=~/cpp_practice/side_project/uArch/systemc-2.3.3
g++ -std=c++11 -I$S/include x.cpp -L$S/lib-linux64 -lsystemc -Wl,-rpath,$S/lib-linux64 -o x
```

**程式碼省略的開頭**：這一段所有程式都省略下面這幾行，要自己跑時請補上：

```cpp
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/multi_passthrough_target_socket.h>
#include <tlm_utils/tlm_quantumkeeper.h>
#include <cstring>
using namespace sc_core;
using std::cout;
using std::endl;
```

每題答案中的輸出都是本機實跑的結果，並對照 SystemC 2.3.3 原始碼；驗證方式與核對範圍見這一段的最後。

---

### 入門（L1）

#### MC1：剛建好的 `tlm_generic_payload` 長什麼樣？〔L1〕

```cpp
int sc_main(int, char**) {
  tlm::tlm_generic_payload gp;
  cout << gp.get_response_status() << " " << gp.is_response_ok() << " " << gp.is_response_error() << endl;
  cout << gp.get_command() << " " << gp.get_data_length() << " " << gp.get_streaming_width() << " " << gp.is_dmi_allowed() << endl;
  return 0;
}
```

兩行輸出是？（`tlm_command` 以整數印出）

- A. `1 1 0` 和 `0 0 0 0`
- B. `0 0 1` 和 `2 0 0 0`
- C. `0 0 1` 和 `0 4 0 0`
- D. `-1 0 1` 和 `2 0 0 0`

<details>
<summary>答案</summary>

**B。** `tlm_generic_payload` 的預設建構子（`tlm_gp.cpp`）把 response status 設成 `TLM_INCOMPLETE_RESPONSE`（數值 0），所以 `is_response_ok()` 為 false、`is_response_error()` 為 **true**（INCOMPLETE 也算 error）；command 預設是 `TLM_IGNORE_COMMAND`（列舉順序 `READ=0`、`WRITE=1`、`IGNORE=2`，所以印 2）；data length、streaming width 都是 0，`dmi_allowed` 預設 false。

```
0 0 1
2 0 0 0
```

重點：忘了 `set_command` 時 target 看到的是 `IGNORE`，不是 READ。

</details>

---

#### MC2：哪些 response status 算 error？〔L1〕

```cpp
int sc_main(int, char**) {
  tlm::tlm_generic_payload gp;
  tlm::tlm_response_status all[] = {
    tlm::TLM_OK_RESPONSE, tlm::TLM_INCOMPLETE_RESPONSE,
    tlm::TLM_GENERIC_ERROR_RESPONSE, tlm::TLM_ADDRESS_ERROR_RESPONSE,
    tlm::TLM_COMMAND_ERROR_RESPONSE, tlm::TLM_BURST_ERROR_RESPONSE,
    tlm::TLM_BYTE_ENABLE_ERROR_RESPONSE};
  for (auto s : all) {
    gp.set_response_status(s);
    cout << s << " ok=" << gp.is_response_ok() << " error=" << gp.is_response_error() << endl;
  }
  gp.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
  cout << gp.get_response_string() << endl;
  return 0;
}
```

有幾行是 `error=1`？`TLM_OK_RESPONSE` 的數值是多少？

- A. 5 行；`TLM_OK_RESPONSE` 是 0
- B. 7 行；`TLM_OK_RESPONSE` 是 1
- C. 6 行；`TLM_OK_RESPONSE` 是 1
- D. 5 行；`TLM_OK_RESPONSE` 是 1

<details>
<summary>答案</summary>

**C。** `tlm_gp.h` 裡 `is_response_ok()` 是 `status > 0`、`is_response_error()` 是 `status <= 0`。只有 `TLM_OK_RESPONSE`（1）是 ok，其他六個（INCOMPLETE 0 與五個負值錯誤碼）都是 error，共 6 行。`get_response_string()` 會把狀態轉成同名字串。

```
1 ok=1 error=0
0 ok=0 error=1
-1 ok=0 error=1
-2 ok=0 error=1
-3 ok=0 error=1
-4 ok=0 error=1
-5 ok=0 error=1
TLM_ADDRESS_ERROR_RESPONSE
```

所以 target 不要只回 `TLM_GENERIC_ERROR_RESPONSE` 了事：地址錯用 `ADDRESS_ERROR`、不支援的命令用 `COMMAND_ERROR`、不支援的 byte enable 用 `BYTE_ENABLE_ERROR`，initiator 才分得出是哪種錯。

</details>

---

#### MC3：target 忘了設定 response status〔L1〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    // 這個 target 忘了設定 response status
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << gp.get_response_string() << " ok=" << gp.is_response_ok()
         << " error=" << gp.is_response_error() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `TLM_OK_RESPONSE ok=1 error=0`（預設就是 OK）
- B. 編譯錯誤，`b_transport` 必須設定 response status
- C. 執行期錯誤，TLM 會偵測到 target 沒有設定 status
- D. `TLM_INCOMPLETE_RESPONSE ok=0 error=1`

<details>
<summary>答案</summary>

**D。** 沒有任何機制檢查 target 有沒有設定 status：payload 建構時就是 `TLM_INCOMPLETE_RESPONSE`，target 不碰它，initiator 看到的就是 INCOMPLETE，被 `is_response_error()` 判成錯誤。它是在提醒你「這筆交易沒有被任何人處理完」。

```
TLM_INCOMPLETE_RESPONSE ok=0 error=1
```

反過來要小心：如果 payload 被重複使用（例如 pool 裡拿出來的），上一筆的 status 還留著，這次 target 忘了設定的話，initiator 會錯誤地看到舊的 OK。

</details>

---

#### MC4：`delay` 參數怎麼用？〔L1〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "delay=" << delay << " now=" << sc_time_stamp() << endl;
    wait(delay);
    cout << "after wait now=" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `delay=10 ns now=0 s` 與 `after wait now=10 ns`
- B. `delay=0 s now=0 s` 與 `after wait now=0 s`
- C. `delay=10 ns now=10 ns` 與 `after wait now=20 ns`
- D. `delay=10 ns now=0 s` 與 `after wait now=0 s`

<details>
<summary>答案</summary>

**A。** `sc_time& delay` 是 in/out 參數：target 把自己的延遲**加**上去（`delay += ...`），返回後 initiator 看到 10 ns。但 LT 的 `b_transport` 本身**不推進 simulation time**（`now` 仍是 `0 s`），要不要等、什麼時候等由 initiator 決定：這裡立刻 `wait(delay)`，時間才到 10 ns。如果不立刻 `wait`，而是把 `delay` 累積起來晚點才等，就是 temporal decoupling（見 MC8）。

```
delay=10 ns now=0 s
after wait now=10 ns
```

</details>

---

#### MC5：socket 沒有綁定會怎樣？〔L1〕

```cpp
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") {}
};

int sc_main(int, char**) {
  Init i("i");
  sc_start(1, SC_NS);
  cout << "finished" << endl;
  return 0;
}
```

結果是？

- A. 正常結束，印出 `finished`
- B. 編譯錯誤
- C. 只印警告，之後照常執行
- D. 執行期錯誤 E109（port not bound），`sc_start` 時中止，不會印出 `finished`

<details>
<summary>答案</summary>

**D。** initiator socket 預設的 port policy 是「至少要綁一個」（`SC_ONE_OR_MORE_BOUND`），模擬在 elaboration 結束（`sc_start` 開始）時檢查，沒綁就報 E109 並中止，所以 `finished` 不會印：

```
Error: (E109) complete binding failed: port not bound: port 'i.socket' (tlm_initiator_socket)
In file: ../../../src/sysc/communication/sc_port.cpp:235
```

錯誤訊息裡的名字是 `i.socket`（階層名稱，見 SystemC 題庫 MC7），可以直接定位是哪個 socket 沒綁。

</details>

---

#### MC6：READ 和 WRITE 的資料誰寫誰讀？〔L1〕

```cpp
struct Memory : sc_module {
  tlm_utils::simple_target_socket<Memory> socket;
  unsigned char mem[16] = {};
  SC_CTOR(Memory) : socket("socket") {
    socket.register_b_transport(this, &Memory::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time&) {
    unsigned char* p = mem + gp.get_address();
    if (gp.is_write()) memcpy(p, gp.get_data_ptr(), gp.get_data_length());
    else               memcpy(gp.get_data_ptr(), p, gp.get_data_length());
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void access(tlm::tlm_command cmd, unsigned addr, unsigned char* buf) {
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(cmd);
    gp.set_address(addr);
    gp.set_data_ptr(buf);
    gp.set_data_length(2);
    socket->b_transport(gp, delay);
  }
  void run() {
    unsigned char out[2] = {0xAB, 0xCD};
    unsigned char in[2]  = {0, 0};
    access(tlm::TLM_WRITE_COMMAND, 4, out);
    out[0] = 0;
    access(tlm::TLM_READ_COMMAND, 4, in);
    cout << std::hex << (int)in[0] << " " << (int)in[1] << " " << (int)out[0] << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Memory m("m");
  i.socket.bind(m.socket);
  sc_start();
  return 0;
}
```

輸出是？（十六進位）

- A. `0 0 0`
- B. `ab cd 0`
- C. `ab cd ab`
- D. `cd ab 0`

<details>
<summary>答案</summary>

**B。** `data_ptr` 指向 initiator 自己的緩衝區，`data_length` 是位元組數。WRITE 時 target **從** `data_ptr` 讀出資料存進記憶體；READ 時 target 把資料**寫進** `data_ptr`。所以寫入 `{AB, CD}` 後，把 `out[0]` 清成 0 不影響記憶體裡的值（target 已經複製走），再 READ 回來 `in` 是 `ab cd`，`out[0]` 是 0。資料是位元組序列、按記憶體順序排列（`AB` 在前），不是一個整數。

```
ab cd 0
```

</details>

---

### 應用（L2）

#### MC7：經過 bus 之後，位址與延遲〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    cout << "target sees addr=0x" << std::hex << gp.get_address() << std::dec << endl;
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Bus : sc_module {
  tlm_utils::simple_target_socket<Bus> in;
  tlm_utils::simple_initiator_socket<Bus> out;
  SC_CTOR(Bus) : in("in"), out("out") {
    in.register_b_transport(this, &Bus::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    sc_dt::uint64 orig = gp.get_address();
    gp.set_address(orig - 0x1000);
    delay += sc_time(5, SC_NS);
    out->b_transport(gp, delay);
    gp.set_address(orig);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0x1008);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "init: addr=0x" << std::hex << gp.get_address() << std::dec
         << " delay=" << delay << " now=" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Bus b("b");
  Target t("t");
  i.socket.bind(b.in);
  b.out.bind(t.socket);
  sc_start();
  return 0;
}
```

兩行輸出是？

- A. `target sees addr=0x1008`，`init: addr=0x1008 delay=15 ns now=0 s`
- B. `target sees addr=0x8`，`init: addr=0x8 delay=15 ns now=0 s`
- C. `target sees addr=0x8`，`init: addr=0x1008 delay=15 ns now=0 s`
- D. `target sees addr=0x8`，`init: addr=0x1008 delay=10 ns now=0 s`

<details>
<summary>答案</summary>

**C。** bus 直接改 payload 的位址（扣掉 base 0x1000）再往下送，所以 target 看到的是區域位址 `0x8`；bus 在返回前把位址還原，所以 initiator 仍看到 `0x1008`（若 bus 忘了還原，initiator 看到的就是被改過的位址，這份題庫只實跑了有還原的版本）。延遲是一路累加的：bus 加 5 ns，再傳給 target 又加 10 ns，initiator 最後拿到 15 ns，`now` 仍是 `0 s`：**每一層都要把自己的延遲加進同一個 `delay`**，只有最後的 initiator 決定何時 `wait`。

```
target sees addr=0x8
init: addr=0x1008 delay=15 ns now=0 s
```

</details>

---

#### MC8：連續四筆 LT 讀取，`delay` 與時間〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    for (int i = 0; i < 4; ++i) {
      gp.set_command(tlm::TLM_READ_COMMAND);
      gp.set_address(4 * i);
      gp.set_data_ptr(buf);
      gp.set_data_length(4);
      socket->b_transport(gp, delay);
      cout << "i=" << i << " delay=" << delay << " now=" << sc_time_stamp() << endl;
    }
    wait(delay);
    cout << "after wait now=" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `delay` 依序 10、20、30、40 ns，`now` 每圈都是 0 s，最後 `after wait now=40 ns`
- B. `delay` 每圈都是 10 ns，`now` 依序 0、10、20、30 ns，最後 `after wait now=40 ns`
- C. `delay` 依序 10、20、30、40 ns，`now` 也依序 10、20、30、40 ns，最後 `after wait now=80 ns`
- D. `delay` 每圈都是 10 ns，`now` 每圈都是 0 s，最後 `after wait now=10 ns`

<details>
<summary>答案</summary>

**A。** 四次呼叫共用同一個 `delay` 變數，target 每次加 10 ns，所以累積成 10、20、30、40 ns；沒有任何 `wait`，`sc_time_stamp()` 一直是 `0 s`，最後一次 `wait(delay)` 才讓時間一次跳到 40 ns。這就是手工版的 temporal decoupling：4 筆交易只有 1 次 `wait`（1 次 context switch），而不是 4 次。代價是 initiator 的「本地時間」領先了 simulation time（見 MC19）。

```
i=0 delay=10 ns now=0 s
i=1 delay=20 ns now=0 s
i=2 delay=30 ns now=0 s
i=3 delay=40 ns now=0 s
after wait now=40 ns
```

</details>

---

#### MC9：`tlm_quantumkeeper` 忘了 `reset()`〔L2〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    cout << "no reset: " << qk.need_sync() << endl;
    qk.inc(sc_time(10, SC_NS));
    cout << "no reset, local=10 ns: " << qk.need_sync() << endl;
    qk.reset();
    for (int i = 0; i < 4; ++i) {
      qk.inc(sc_time(30, SC_NS));
      cout << "local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
    }
  }
};

int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）六行輸出是？

- A. 前兩行 `0`、`0`；之後 `0 0 0 1`
- B. 前兩行 `1`、`1`；之後 `1 1 1 1`
- C. 前兩行 `1`、`1`；之後 `0 0 0 1`
- D. 前兩行 `0`、`1`；之後 `0 0 1 1`

<details>
<summary>答案</summary>

**C。** `tlm_quantumkeeper` 剛建構時內部的 `m_next_sync_point` 是 0，而 `need_sync()` 的判斷是 `sc_time_stamp() + local_time >= m_next_sync_point`，所以**在第一次 `reset()` 之前永遠是 true**（連 local time 為 0 時都是）。`reset()` 會把 local time 歸零並算出下一個同步點（現在時間加上本地 quantum，這裡是 100 ns），之後 local time 累加到 30、60、90 都還沒到，累加到 120 才 `>= 100`，`need_sync` 變 true。

```
no reset: 1
no reset, local=10 ns: 1
local=30 ns need_sync=0
local=60 ns need_sync=0
local=90 ns need_sync=0
local=120 ns need_sync=1
```

結論：使用 quantum keeper 要在 thread 開頭（或每次 `sync()` 後，`sync()` 內部會 `reset()`）呼叫 `reset()`；忘了的話等於每筆都要同步，temporal decoupling 完全沒效果，而且不會有任何錯誤訊息。

</details>

---

#### MC10：quantum 是對齊到整數倍的時間點〔L2〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    wait(50, SC_NS);
    qk.reset();
    for (int i = 0; i < 2; ++i) {
      qk.inc(sc_time(30, SC_NS));
      cout << "now=" << sc_time_stamp() << " local=" << qk.get_local_time()
           << " need_sync=" << qk.need_sync() << endl;
    }
  }
};

int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）輸出是？

- A. 兩行的 `need_sync` 都是 `0`（quantum 從 `reset` 時起算 100 ns）
- B. 兩行的 `need_sync` 都是 `1`
- C. 第一行 `need_sync=0`，第二行還是 `0`，要累積到 120 ns 才會是 `1`
- D. 第一行 `need_sync=0`，第二行 `need_sync=1`

<details>
<summary>答案</summary>

**D。** 全域 quantum 的同步點是 quantum 的**整數倍時間**（0、100、200 ns…），不是每個 initiator 從自己的起點各算 100 ns。`reset()` 內部用 `quantum - (now % quantum)` 算本地 quantum：現在是 50 ns，`100 - 50 % 100 = 50 ns`，下一個同步點是 100 ns。第一次 `inc(30)`：50 + 30 = 80 < 100，不用同步；第二次 local 變 60：50 + 60 = 110 >= 100，需要同步。

```
now=50 ns local=30 ns need_sync=0
now=50 ns local=60 ns need_sync=1
```

所以 initiator 在「剛好離下一個整數倍很近」時醒來，能領先的時間會比 quantum 小很多。

</details>

---

#### MC11：`sync()` 與 `get_current_time()`〔L2〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    qk.inc(sc_time(60, SC_NS));
    cout << "before sync: stamp=" << sc_time_stamp() << " current=" << qk.get_current_time()
         << " local=" << qk.get_local_time() << endl;
    qk.sync();
    cout << "after sync:  stamp=" << sc_time_stamp() << " current=" << qk.get_current_time()
         << " local=" << qk.get_local_time() << endl;
  }
};

int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

輸出是？

- A. `before sync: stamp=0 s current=0 s local=60 ns`；`after sync:  stamp=60 ns current=60 ns local=0 s`
- B. `before sync: stamp=0 s current=60 ns local=60 ns`；`after sync:  stamp=60 ns current=60 ns local=0 s`
- C. `before sync: stamp=60 ns current=60 ns local=60 ns`；`after sync:  stamp=60 ns current=120 ns local=0 s`
- D. `before sync: stamp=0 s current=60 ns local=60 ns`；`after sync:  stamp=0 s current=60 ns local=0 s`

<details>
<summary>答案</summary>

**B。** `sc_time_stamp()` 是「模擬器的時間」，`qk.get_current_time()` 是「模擬器時間 + local time」，也就是 initiator 自己認為的現在時間。`inc(60 ns)` 之後 initiator 領先 60 ns，`stamp=0`、`current=60 ns`。`sync()` 做的事是 `wait(local_time)` 再 `reset()`：模擬器時間追上來變 60 ns，local time 歸零，兩個時間重合。

```
before sync: stamp=0 s current=60 ns local=60 ns
after sync:  stamp=60 ns current=60 ns local=0 s
```

給 target 的 `delay` 應傳 `qk.get_local_time()`；記錄 timestamp 要用 `get_current_time()`，不要用 `sc_time_stamp()`，否則記錄的時間比 initiator 實際認為的時間慢。

</details>

---

#### MC12：`transport_dbg` 沒有註冊會怎樣？〔L2〕

```cpp
struct Plain : sc_module {
  tlm_utils::simple_target_socket<Plain> socket;
  SC_CTOR(Plain) : socket("socket") {}
};

struct WithDbg : sc_module {
  tlm_utils::simple_target_socket<WithDbg> socket;
  SC_CTOR(WithDbg) : socket("socket") {
    socket.register_transport_dbg(this, &WithDbg::dbg);
  }
  unsigned int dbg(tlm::tlm_generic_payload& gp) {
    return gp.get_data_length();
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> a, b;
  SC_CTOR(Init) : a("a"), b("b") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    cout << "plain: " << a->transport_dbg(gp) << endl;
    cout << "with dbg: " << b->transport_dbg(gp) << " now=" << sc_time_stamp() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Plain p("p");
  WithDbg w("w");
  i.a.bind(p.socket);
  i.b.bind(w.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `plain: 0` 與 `with dbg: 4 now=0 s`
- B. `plain: 4` 與 `with dbg: 4 now=0 s`
- C. 編譯錯誤，沒註冊 `transport_dbg` 時不能呼叫
- D. `plain: 0` 與 `with dbg: 4 now=...`（debug 存取會讓時間前進）

<details>
<summary>答案</summary>

**A。** `simple_target_socket` 沒有註冊 debug callback 時，`transport_dbg` 直接回傳 0（原始碼註解 `No debug support`），代表「搬了 0 個位元組」，不報錯；註冊後回傳 callback 的結果（這裡回傳資料長度 4）。`transport_dbg` 沒有 `delay` 參數，也不應該改變模型狀態，所以 `now` 不會動。

```
plain: 0
with dbg: 4 now=0 s
```

這也提醒：用 debugger 看記憶體讀不到東西時，先確認 target 有沒有實作 `transport_dbg`。

</details>

---

#### MC13：只註冊 `nb_transport_fw` 的 target，被 `b_transport` 呼叫〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::nb_transport_fw);
  }
  tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& gp,
                                     tlm::tlm_phase& phase, sc_time& delay) {
    cout << "target nb_transport_fw phase=" << phase.get_name() << endl;
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
    return tlm::TLM_COMPLETED;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "init: " << gp.get_response_string() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. 執行期錯誤：沒有註冊 `b_transport`
- B. `target nb_transport_fw phase=BEGIN_REQ` 與 `init: TLM_OK_RESPONSE`
- C. 只印 `init: TLM_INCOMPLETE_RESPONSE`（target 沒被呼叫）
- D. 編譯錯誤

<details>
<summary>答案</summary>

**B。** `simple_target_socket` 會做 b / nb 轉換：目標只註冊了 nb、被呼叫 `b_transport` 時，socket 在內部 spawn 一個轉換 thread（`b2nb_thread`），用 `BEGIN_REQ` 呼叫你註冊的 `nb_transport_fw`；target 回 `TLM_COMPLETED` 就代表交易完成，`b_transport` 返回。反方向（只註冊 b、被 nb 呼叫）也有轉換（`nb2b_thread`）。

```
target nb_transport_fw phase=BEGIN_REQ
init: TLM_OK_RESPONSE
```

所以 LT 的 initiator 和 AT 的 target 可以直接接在一起，不需要自己寫轉接。

</details>

---

#### MC14：payload 的 extension〔L2〕

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time&) {
    Tag* t = gp.get_extension<Tag>();
    if (t) cout << "target sees tag=" << t->value << endl;
    else   cout << "target sees no tag" << endl;
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    Tag tag;
    tag.value = 42;
    gp.set_extension(&tag);
    socket->b_transport(gp, delay);
    gp.clear_extension(&tag);
    socket->b_transport(gp, delay);
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

三行輸出是？

- A. `no tag`、`tag=42`、`no tag`
- B. `target sees no tag` 三次
- C. `no tag`、`tag=42`、`tag=42`
- D. `tag=0`、`tag=42`、`no tag`

<details>
<summary>答案</summary>

**A。** `get_extension<Tag>()` 找不到時回傳 `nullptr`（不是預設值，也不會丟例外），所以第一筆要先判斷。`set_extension(&tag)` 只是把指標掛到 payload 上，target 用同一個 payload 就能取到；`clear_extension(&tag)` 把它拿掉（只清掉指標，不 delete），第三筆又找不到。這個 `Tag` 在 initiator 的堆疊上，所以要在它離開 scope 之前先 `clear_extension`；`set_auto_extension` 則要求 payload 有 memory manager（原始碼 `tlm_gp.cpp` 內 `sc_assert(m_mm != 0)`），payload 被回收時會一併釋放 extension；這條路徑這份題庫沒有實跑。

```
target sees no tag
target sees tag=42
target sees no tag
```

</details>

---

#### MC15：payload 的引用計數〔L2〕

```cpp
struct MM : tlm::tlm_mm_interface {
  void free(tlm::tlm_generic_payload* gp) {
    cout << "mm.free called" << endl;
    gp->reset();
    delete gp;
  }
};

int sc_main(int, char**) {
  MM mm;
  tlm::tlm_generic_payload* gp = new tlm::tlm_generic_payload(&mm);
  cout << "ref=" << gp->get_ref_count() << endl;
  gp->acquire();
  cout << "ref=" << gp->get_ref_count() << endl;
  gp->acquire();
  cout << "ref=" << gp->get_ref_count() << endl;
  gp->release();
  cout << "ref=" << gp->get_ref_count() << endl;
  gp->release();
  cout << "done" << endl;
  return 0;
}
```

輸出是？

- A. `ref=1`、`ref=2`、`ref=3`、`ref=2`，然後 `mm.free called`、`done`
- B. `ref=0`、`ref=1`、`ref=2`、`ref=1`，然後 `done`（`free` 不會被呼叫）
- C. `ref=0`、`ref=1`、`ref=2`、`ref=1`，然後 `done`、`mm.free called`
- D. `ref=0`、`ref=1`、`ref=2`、`ref=1`，然後 `mm.free called`、`done`

<details>
<summary>答案</summary>

**D。** 剛建構時引用計數是 0；每次 `acquire()` 加 1、`release()` 減 1，**減到 0 時由 payload 呼叫 memory manager 的 `free(this)`**，所以最後一次 `release()` 就印出 `mm.free called`，在 `done` 之前。payload 本身不會 `delete` 自己，回收（還給 pool 或 delete）是 memory manager 的責任。

```
ref=0
ref=1
ref=2
ref=1
mm.free called
done
```

補充（本機另外實測）：沒有 memory manager 的 payload（堆疊上建立的那種）呼叫 `acquire()` 會直接中止，`Fatal: (F4) assertion failed: m_mm != 0`（`tlm_gp.h:132`）。所以 `acquire/release` 只用在有 mm 的 payload 上；堆疊 payload 只適用於 blocking 傳輸、交易結束前不離開 scope 的情況。

</details>

---

#### MC16：multi socket 的 `id` 是怎麼來的？〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::multi_passthrough_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(int id, tlm::tlm_generic_payload& gp, sc_time&) {
    cout << "target: id=" << id << " addr=0x" << std::hex << gp.get_address()
         << std::dec << " @" << sc_time_stamp() << endl;
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  unsigned addr, start;
  Init(sc_module_name n, unsigned a, unsigned s) : sc_module(n), socket("socket"), addr(a), start(s) {
    SC_HAS_PROCESS(Init);
    SC_THREAD(run);
  }
  void run() {
    wait(start, SC_NS);
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(addr);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
  }
};

int sc_main(int, char**) {
  Init x("x", 0x10, 0);
  Init y("y", 0x20, 1);
  Target t("t");
  y.socket.bind(t.socket);
  x.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `id=0 addr=0x10 @0 s` 與 `id=1 addr=0x20 @1 ns`（依 initiator 建立順序）
- B. 兩筆的 `id` 都是 0
- C. `id=1 addr=0x10 @0 s` 與 `id=0 addr=0x20 @1 ns`
- D. 編譯錯誤：multi socket 不能綁 `simple_initiator_socket`

<details>
<summary>答案</summary>

**C。** `multi_passthrough_target_socket` 的 `id` 是**綁定順序**，不是模組建立順序或名字順序：程式先 `y.socket.bind(...)`，所以 `y` 是 `id=0`，後綁的 `x` 是 `id=1`（原始碼：每次 bind 用 `m_binders.size()` 當新 binder 的 id）。bus 若用 `id` 當索引查表，順序一變、對應就全錯，所以通常要在 elaboration 時由 bus 自己依 `id` 決定路由，而不是假設 `id` 的意義。

```
target: id=1 addr=0x10 @0 s
target: id=0 addr=0x20 @1 ns
```

</details>

---

### 進階（L3）

#### MC17：一筆 AT 讀取，兩邊各回傳什麼？〔L3〕

```cpp
const char* str(tlm::tlm_sync_enum r) {
  return r == tlm::TLM_ACCEPTED ? "TLM_ACCEPTED"
       : r == tlm::TLM_UPDATED  ? "TLM_UPDATED" : "TLM_COMPLETED";
}

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  tlm::tlm_generic_payload* pending = nullptr;
  sc_event ev;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::nb_transport_fw);
    SC_THREAD(respond);
  }
  tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& gp,
                                     tlm::tlm_phase& phase, sc_time& delay) {
    cout << "target: fw " << phase.get_name() << endl;
    pending = &gp;
    ev.notify(10, SC_NS);
    phase = tlm::END_REQ;
    return tlm::TLM_UPDATED;
  }
  void respond() {
    wait(ev);
    pending->set_response_status(tlm::TLM_OK_RESPONSE);
    tlm::tlm_phase phase = tlm::BEGIN_RESP;
    sc_time delay = SC_ZERO_TIME;
    tlm::tlm_sync_enum r = socket->nb_transport_bw(*pending, phase, delay);
    cout << "target: bw BEGIN_RESP @" << sc_time_stamp() << " returned " << str(r) << endl;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  sc_event done;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::nb_transport_bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum nb_transport_bw(tlm::tlm_generic_payload& gp,
                                     tlm::tlm_phase& phase, sc_time& delay) {
    cout << "init: bw " << phase.get_name() << endl;
    done.notify();
    return tlm::TLM_COMPLETED;
  }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase phase = tlm::BEGIN_REQ;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, phase, delay);
    cout << "init: fw returned " << str(r) << " phase=" << phase.get_name() << endl;
    wait(done);   // payload 在堆疊上，必須等交易結束才能離開
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

`init: fw returned ...` 那行，與 `target: bw ... returned ...` 那行，各是？

- A. fw 回 `TLM_ACCEPTED`（phase 仍是 `BEGIN_REQ`），bw 回 `TLM_UPDATED`
- B. fw 回 `TLM_UPDATED`（phase 被改成 `END_REQ`），bw 回 `TLM_COMPLETED`
- C. fw 回 `TLM_COMPLETED`，bw 回 `TLM_COMPLETED`
- D. fw 回 `TLM_UPDATED`（phase 被改成 `END_REQ`），bw 回 `TLM_ACCEPTED`

<details>
<summary>答案</summary>

**B。** 這是用 return path 縮短 AT 握手的寫法：

1. initiator 以 `nb_transport_fw(BEGIN_REQ)` 發起；
2. target 在**同一次呼叫的回程**把 `phase` 改成 `END_REQ` 並回 `TLM_UPDATED`，等於把「backward 的 END_REQ」省掉一次呼叫（回傳值 + `phase` 這個 in/out 參數一起帶回）；
3. 10 ns 後 target 主動走 backward path 呼叫 `nb_transport_bw(BEGIN_RESP)`；
4. initiator 回 `TLM_COMPLETED`，代表這筆交易到此結束，不必再另外呼叫 `END_RESP`。

```
target: fw BEGIN_REQ
init: fw returned TLM_UPDATED phase=END_REQ
init: bw BEGIN_RESP
target: bw BEGIN_RESP @10 ns returned TLM_COMPLETED
```

`TLM_ACCEPTED` 的意思是「我收到了，之後會自己用另一個方向的呼叫通知你」，phase 不改；`TLM_UPDATED` 是「我已經推進到新的 phase，看 `phase` 參數」；`TLM_COMPLETED` 是「整筆交易已完成」。（這三個值的語意是依 IEEE 1666 的規則與本機實跑的行為，標頭檔中沒有逐項註解；socket 只是把回傳值原樣傳回，不檢查 phase 順序是否合法。）

一個容易踩的坑：這支程式的 payload 和緩衝區在 initiator 的堆疊上，所以 initiator 必須 `wait(done)` 等交易結束才能離開。我寫第一版時 thread 在 `nb_transport_fw` 返回後就結束了，10 ns 後 target 還在使用那個 payload，程式直接 segfault。**非阻塞交易的 payload 必須活到交易結束**（通常用 memory manager 或 pool）。

</details>

---

#### MC18：target 直接回 `TLM_COMPLETED`〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::nb_transport_fw);
  }
  tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& gp,
                                     tlm::tlm_phase& phase, sc_time& delay) {
    *gp.get_data_ptr() = 0x5A;
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
    return tlm::TLM_COMPLETED;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4] = {0, 0, 0, 0};
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase phase = tlm::BEGIN_REQ;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, phase, delay);
    cout << (r == tlm::TLM_COMPLETED) << " phase=" << phase.get_name()
         << " data=" << std::hex << (int)buf[0] << " " << gp.get_response_string() << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

輸出是？

- A. `0 phase=BEGIN_REQ data=0 TLM_INCOMPLETE_RESPONSE`
- B. `1 phase=END_RESP data=5a TLM_OK_RESPONSE`
- C. `1 phase=BEGIN_REQ data=0 TLM_OK_RESPONSE`
- D. `1 phase=BEGIN_REQ data=5a TLM_OK_RESPONSE`

<details>
<summary>答案</summary>

**D。** target 在**第一次** forward 呼叫裡就把資料寫好、status 設成 OK 並回 `TLM_COMPLETED`：交易在這次呼叫內完成，initiator 立刻就能讀資料（`5a`），不會再有任何後續 phase。`phase` 參數沒被 target 修改，所以仍是 `BEGIN_REQ`。這是「AT 介面、LT 速度」的寫法：沒有 timing 需求的 target（例如暫存器、單純的記憶體）直接回 `TLM_COMPLETED`，省下整個握手。

```
1 phase=BEGIN_REQ data=5a TLM_OK_RESPONSE
```

</details>

---

#### MC19：temporal decoupling 讓你看到「未來」的資料〔L3〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  int flag = 0;
  SC_CTOR(M) { SC_THREAD(a); SC_THREAD(b); }
  void a() {
    qk.reset();
    qk.inc(sc_time(50, SC_NS));
    flag = 1;
    cout << "A wrote flag at its local time " << qk.get_current_time() << endl;
  }
  void b() {
    wait(10, SC_NS);
    cout << "B @" << sc_time_stamp() << " sees flag=" << flag << endl;
  }
};

int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）輸出的第二行 `B` 讀到的 `flag` 是？

- A. `flag=0`，因為 A 的本地時間是 50 ns，比 B 讀的 10 ns 晚
- B. 取決於排程器先跑 A 還是 B，可能是 0 也可能是 1
- C. `flag=1`
- D. 只有 quantum 小於等於 10 ns 才會是 1

<details>
<summary>答案</summary>

**C。** `A` 沒有呼叫 `wait`，在 simulation time 0 就把 `flag` 寫完了；它的「本地時間」50 ns 只是一個領先量（用 `qk` 記帳），並不會延後實際的記憶體寫入。`B` 先 `wait(10, SC_NS)` 才讀，這時 `flag` 早已是 1。不是排程順序的問題（B 錯）：`B` 一定在 10 ns 才讀，而 `A` 在 0 ns 就寫完。

```
A wrote flag at its local time 50 ns
B @10 ns sees flag=1
```

結果就是 `B` 在 simulation time 10 ns 看到了「模型裡 50 ns 才會發生」的寫入：**因果關係被打破了**，這就是 quantum 的代價（對應 `study/tlm-quiz.md` 的 Q3）：quantum 越大越快，時序與資料順序越不準。軟體正確同步（用旗標、中斷）的程式不受影響，靠時序巧合的程式會出問題。

</details>

---

#### MC20：在 `SC_METHOD` 裡呼叫 `b_transport`〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    wait(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_METHOD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "returned" << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

結果是？

- A. 執行期錯誤 E519：`wait()` 只能在 thread 裡呼叫，錯誤出在 `i.run`
- B. 正常執行，印出 `returned`
- C. 編譯錯誤
- D. `wait(10, SC_NS)` 被忽略，印出 `returned`

<details>
<summary>答案</summary>

**A。** `b_transport` 是**同步呼叫**，在 initiator 的 process 裡直接執行 target 的函式，target 要是呼叫了 `wait()`，等的是**呼叫者的 process**；`SC_METHOD` 不能暫停，所以 target 一呼叫 `wait` 就報 E519，錯誤訊息指出的 process 是呼叫端 `i.run`，而不是 target：

```
Error: (E519) wait() is only allowed in SC_THREADs and SC_CTHREADs:
        in SC_METHODs use next_trigger() instead
In file: ../../../src/sysc/kernel/sc_wait.cpp:179
In process: i.run @ 0 s
```

反過來，如果 target 的 `b_transport` 完全不呼叫 `wait`（本機另外實測，把這支程式的 `wait(10, SC_NS)` 那行拿掉），從 `SC_METHOD` 呼叫就能正常印出 `returned`。結論：initiator 要呼叫「可能會 wait」的 target，必須是 `SC_THREAD`；一個 `SC_METHOD` 形式的 initiator 只能搭配保證不會 wait 的 target。

</details>

---

#### MC21：DMI 與 initiator 的領先時間〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  unsigned char mem[256];
  SC_CTOR(Target) : socket("socket") {
    memset(mem, 0x11, sizeof mem);
    socket.register_b_transport(this, &Target::b_transport);
    socket.register_get_direct_mem_ptr(this, &Target::get_dmi);
    SC_THREAD(invalidate);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    *gp.get_data_ptr() = mem[gp.get_address()];
    delay += sc_time(20, SC_NS);
    gp.set_dmi_allowed(true);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
  bool get_dmi(tlm::tlm_generic_payload&, tlm::tlm_dmi& dmi) {
    dmi.set_dmi_ptr(mem);
    dmi.set_start_address(0);
    dmi.set_end_address(255);
    dmi.set_granted_access(tlm::tlm_dmi::DMI_ACCESS_READ_WRITE);
    dmi.set_read_latency(sc_time(5, SC_NS));
    dmi.set_write_latency(sc_time(2, SC_NS));
    return true;
  }
  void invalidate() {
    wait(10, SC_NS);
    cout << "target: invalidate @" << sc_time_stamp() << endl;
    socket->invalidate_direct_mem_ptr(0, 255);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  tlm::tlm_dmi dmi;
  bool dmi_valid = false;
  SC_CTOR(Init) : socket("socket") {
    socket.register_invalidate_direct_mem_ptr(this, &Init::invalidate_dmi);
    SC_THREAD(run);
  }
  void invalidate_dmi(sc_dt::uint64 start, sc_dt::uint64 end) {
    cout << "init: invalidate " << start << ".." << end << " @" << sc_time_stamp() << endl;
    dmi_valid = false;
  }
  void run() {
    unsigned char buf[1];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(1);
    socket->b_transport(gp, delay);
    cout << "b_transport: delay=" << delay << " dmi_allowed=" << gp.is_dmi_allowed() << endl;
    if (gp.is_dmi_allowed()) dmi_valid = socket->get_direct_mem_ptr(gp, dmi);
    cout << "dmi_valid=" << dmi_valid << " range=" << dmi.get_start_address()
         << ".." << dmi.get_end_address() << endl;
    for (int i = 0; i < 3; ++i) {
      if (dmi_valid && dmi.is_read_allowed()) {
        buf[0] = dmi.get_dmi_ptr()[i];
        delay += dmi.get_read_latency();
      }
    }
    cout << "after 3 DMI reads: delay=" << delay << " now=" << sc_time_stamp() << endl;
    wait(delay);
    cout << "now=" << sc_time_stamp() << " dmi_valid=" << dmi_valid << endl;
  }
};

int sc_main(int, char**) {
  Init i("i");
  Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

下面哪個說法正確？

- A. 35 ns 是 20 ns 加 3 × 5 ns；10 ns 的 invalidate 會在第二次 DMI 讀取中途打斷它
- B. `delay` 的 35 ns 是 20 ns（`b_transport`）加上 3 × 5 ns（DMI 讀延遲）；三次 DMI 讀在 simulation time 0 就全部做完，比 10 ns 的 invalidate 還早，最後 `dmi_valid` 才變 0
- C. 35 ns 是 3 × 5 ns 加 20 ns；invalidate 在 DMI 讀之後才發生，所以最後 `dmi_valid` 仍是 1
- D. `delay` 只有 15 ns，因為 `b_transport` 的 20 ns 不算在內

<details>
<summary>答案</summary>

**B。** 流程：第一次走 `b_transport`（20 ns），target 順便設定 `dmi_allowed`；initiator 看到後呼叫 `get_direct_mem_ptr`，拿到範圍 0..255、讀延遲 5 ns；之後三次讀都**直接存取記憶體指標**，沒有任何 TLM 呼叫，只是把 5 ns 累加到 `delay`（20 + 15 = 35 ns），這些都在 simulation time 0 完成。target 的 10 ns invalidate 要等 initiator 的 `wait(delay)` 讓出時間後才會發生；回呼裡把 `dmi_valid` 清成 false。

```
b_transport: delay=20 ns dmi_allowed=1
dmi_valid=1 range=0..255
after 3 DMI reads: delay=35 ns now=0 s
target: invalidate @10 ns
init: invalidate 0..255 @10 ns
now=35 ns dmi_valid=0
```

注意時間線：以 initiator 的本地時間看，它在 20–35 ns 之間「還在使用」DMI 指標，但 target 在 10 ns 就已經作廢了它。DMI 與 temporal decoupling 搭配時這是已知的取捨：作廢通知不會中斷領先中的 initiator，所以 initiator 每次用 DMI 之前要檢查旗標、用完要 `sync`；驗證功能時要準備「作廢後要重新要 DMI」的測試。

</details>

---

#### MC22：忘了設定全域 quantum〔L3〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    qk.inc(sc_time(1, SC_NS));
    cout << "global quantum=" << tlm_utils::tlm_quantumkeeper::get_global_quantum()
         << " need_sync=" << qk.need_sync() << endl;
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

輸出是？

- A. `global quantum=0 s need_sync=0`
- B. `global quantum=100 ns need_sync=0`
- C. 編譯錯誤，必須先呼叫 `set_global_quantum`
- D. `global quantum=0 s need_sync=1`

<details>
<summary>答案</summary>

**D。** 全域 quantum 的預設值是 `SC_ZERO_TIME`（`tlm_global_quantum` 的建構子），此時 `compute_local_quantum()` 回傳 0，`reset()` 算出的下一個同步點就是「現在」，任何 `inc()` 之後 `need_sync()` 都是 true。程式能正常執行、結果也正確，只是每筆交易都同步，**完全沒有 temporal decoupling 的加速**。這是「quantum keeper 用了卻沒變快」的第一個檢查點。

```
global quantum=0 s need_sync=1
```

</details>

---

### 選擇題驗證紀錄（2026-10-21）

- 環境：本機 SystemC 2.3.3，`g++ -std=c++11`（見上方指令）。
- 方式：寫完後用腳本從這份檔案抽出每題的程式碼，補上開頭那幾行，實際編譯執行，再把輸出逐行與答案裡的輸出區塊比對，22 題全部一致。
- MC15 的 `acquire()` 無 memory manager 會 `Fatal: (F4) assertion failed: m_mm != 0`、MC20 把 target 的 `wait` 拿掉之後 `SC_METHOD` 能正常呼叫，這兩項是額外跑的小程式，不在檔案的程式碼區塊裡。MC17 第一版 initiator 太早離開導致 segfault，是實際遇到的錯誤，已修正並寫在答案裡。
- 原始碼核對（SystemC 2.3.3）：
  - MC1：`tlm_gp.cpp` 預設建構子（`TLM_IGNORE_COMMAND`、`TLM_INCOMPLETE_RESPONSE`、`m_streaming_width(0)`、`m_dmi(false)`）。
  - MC2：`tlm_gp.h` 的 `is_response_ok/is_response_error` 與 response status 列舉值；`tlm_gp.cpp` 的 `get_response_string`。
  - MC5：`sc_port.cpp` 的 E109，與先前核對過的預設 `SC_ONE_OR_MORE_BOUND`。
  - MC9、MC10、MC11、MC22：`tlm_utils/tlm_quantumkeeper.h`（`need_sync`、`reset`、`sync`、`get_current_time`）與 `tlm_global_quantum.cpp`（預設 0、`compute_local_quantum`）。
  - MC12：`simple_target_socket.h` 內 `transport_dbg` 在沒有 callback 時回傳 0。
  - MC13：`simple_target_socket.h` 的 `b2nb_thread`、`nb2b_thread`。
  - MC14：`tlm_gp.h`／`tlm_gp.cpp` 的 `get_extension`（找不到回 0）、`clear_extension`（只把欄位設 0）、`set_auto_extension`（需要 mm）。
  - MC15：`tlm_gp.h` 的 `acquire`／`release`／`get_ref_count`。
  - MC16：`multi_passthrough_target_socket.h` 的 binder id 取自 `m_binders.size()`（綁定順序）。
- 沒有核對 IEEE 1666 標準原文（本機沒有）：MC17、MC18 的 `TLM_ACCEPTED`／`TLM_UPDATED`／`TLM_COMPLETED` 語意、MC7 的「bus 應該還原位址」規則，都是依本機實跑，標準條文沒有查；MC21 的 DMI 作廢語意只對照到先前核對過的 `tlm_fw_bw_ifs.h` 註解（見文末核對紀錄）。

---

## 問答題（從這裡開始）

下面是 Q1–Q8 的口述與情境題，要用講的回答。選擇題熟了再做這一段。

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
