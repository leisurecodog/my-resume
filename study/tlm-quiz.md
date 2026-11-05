# TLM-2.0 LT、Quantum、DMI 複習題

對應 `tasks/learning-plan.md` 的 TLM-2.0 項目，完成標準：能畫出 read/write 流程並解釋加速原理。

用法：先讀「教學導讀」，再做選擇題（MC1–MC53，由淺到深，程式碼都能在本機跑；MC23 起是 AT 專題，MC37 起是 2026-11-05 補的題目），再做後面的口述題（Q1–Q15）與手寫練習（E1、E2）。口述題先只看題目，用講的方式回答（像在面試現場），講完再展開參考答案對照。每題最後的「上次的弱點」是 2026-10-20 第一次口試的紀錄；Q6–Q8 是之後補的，Q9–Q15 是 2026-11-05 補的，都還沒考過。

情境題請用三段式回答：**元件 + 事件 + 軟體看到的現象**。

Q4 與 Q6–Q8 的參考答案已對照 SystemC 2.3.3 原始碼核對過（`~/cpp_practice/side_project/uArch/systemc-2.3.3`），核對範圍和沒核對到的地方見文末「核對紀錄」。

---

## 教學導讀（先讀這段，再做題）

這一段是給第一次接觸 TLM-2.0 的人。每個主題都有三塊：**白話解釋**、**小範例**（完整程式，已在本機編譯執行，輸出寫在程式後面）、**常見陷阱**。已經在 MC 或 Q 裡講過細節的主題，這裡只給重點與題號，不重複。

範例的編譯指令與上面相同，開頭的 `#include` 與 `using` 也一樣（見下方「程式碼省略的開頭」）。

### T1　Generic payload：欄位與所有權

**白話**：payload（`tlm_generic_payload`）是一筆交易的信封。initiator 負責填 command、address、data pointer、data length、streaming width，response status 預設是 INCOMPLETE；target 負責把資料讀寫進 data pointer，並設定 response status。

所有權只有一個問題：**誰建立、誰負責，到交易結束為止**。

- 只用 `b_transport` 時，交易在函式返回時就結束，payload 可以放在堆疊或成員變數上重複使用。
- 用 AT（`nb_transport_*`），或 payload 在函式返回後還會被別的元件用到時，要用 memory manager（`tlm_mm_interface`）加上 `acquire()` / `release()` 做 reference counting。計數歸零時呼叫 `free()`，通常是把 payload 還進 pool（見 MC15、Q8）。

```cpp
#include <vector>
struct Pool : tlm::tlm_mm_interface {
  std::vector<tlm::tlm_generic_payload*> free_list;
  int frees = 0;
  tlm::tlm_generic_payload* get() {
    if (free_list.empty()) return new tlm::tlm_generic_payload(this);
    tlm::tlm_generic_payload* p = free_list.back(); free_list.pop_back(); return p;
  }
  void free(tlm::tlm_generic_payload* gp) { ++frees; gp->reset(); free_list.push_back(gp); }
};
int sc_main(int, char**) {
  Pool pool;
  tlm::tlm_generic_payload* a = pool.get();
  a->set_address(0x100);
  a->acquire();           // ref = 1
  a->acquire();           // ref = 2
  a->release();           // ref = 1
  cout << "refs=" << a->get_ref_count() << " frees=" << pool.frees << endl;
  a->release();           // ref = 0 -> free -> back to pool
  cout << "refs=" << a->get_ref_count() << " frees=" << pool.frees << " pooled=" << pool.free_list.size() << endl;
  tlm::tlm_generic_payload* b = pool.get();
  cout << "same object reused: " << (a == b) << " addr=0x" << std::hex << b->get_address() << std::dec << endl;
  return 0;
}
```

```text
refs=1 frees=0
refs=0 frees=1 pooled=1
same object reused: 1 addr=0x100
```

第三行的 `addr=0x100` 是重點：`reset()` 不會把 address 清掉，下一次使用前要自己把欄位設好（事實修正 5）。

**常見陷阱**

1. 沒有 mm 卻呼叫 `acquire()`：assert 失敗（MC15）。
2. 把堆疊上的 extension 掛在 payload 上，payload 還活著就離開 scope。payload 解構時會對每個掛著的 extension 呼叫 `free()`，預設實作是 `delete this`（`tlm_gp.h:60`、`tlm_gp.cpp:284-287`）。堆疊物件被 `delete` 是未定義行為。本機實測結果不固定：有時 SIGSEGV（exit 139），有時 SIGABRT（exit 134），見 MC53。離開 scope 前要 `clear_extension<T>()`（MC14）。
3. 把 `reset()` 當成「完全清空」。它只釋放 auto extension（`set_auto_extension` 掛上的），response status、address、command 都保留（MC39）。

### T2　Socket 種類怎麼選

**白話**：socket 是模組之間的接頭。TLM-2.0 的底層介面很多，`tlm_utils` 的 socket 幫你包好了。

| socket | 用在哪裡 | 重點 |
|---|---|---|
| `simple_initiator_socket` / `simple_target_socket` | 一般 IP（CPU、memory、peripheral） | 只註冊需要的 callback；b / nb 會自動轉換（MC13、MC28） |
| `simple_target_socket_tagged` | 一個 module 內，每個來源各用一個 socket，靠 `register` 時給的 id 區分（範例 `SimpleBusLT.h:36-51`） | callback 第一個參數 `int id` 是你在 `register_b_transport(..., id)` 時給的值（MC50）；一個 tagged socket 只能 bind 一次（第二次 bind 報 E109，本機實跑） |
| `passthrough_target_socket` | bus 的上游（接 initiator 的那一側） | 不做 b / nb 轉換；沒註冊的 callback 被呼叫時報 `SC_REPORT_ERROR`（事實修正 1） |
| `multi_passthrough_target_socket` / `multi_passthrough_initiator_socket` | 一個 socket 要接多個 initiator 或 target | 可以多次 bind；callback 的 `id` 是綁定順序（MC16） |

bus 的最小例子（上游 passthrough、下游 simple，已實跑）：

```cpp
#include <tlm_utils/passthrough_target_socket.h>
struct Mem : sc_module {
  tlm_utils::simple_target_socket<Mem> socket;
  SC_CTOR(Mem) : socket("socket") { socket.register_b_transport(this, &Mem::b); }
  void b(tlm::tlm_generic_payload& gp, sc_time& d) {
    cout << "  mem sees 0x" << std::hex << gp.get_address() << std::dec << " delay=" << d << endl;
    d += sc_time(4, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};
struct Bus : sc_module {
  tlm_utils::passthrough_target_socket<Bus> in;
  tlm_utils::simple_initiator_socket<Bus> out;   // 2.3.3 沒有 passthrough_initiator_socket；bus 下游可用 simple 或 multi_passthrough_initiator_socket
  SC_CTOR(Bus) : in("in"), out("out") { in.register_b_transport(this, &Bus::b); }
  void b(tlm::tlm_generic_payload& gp, sc_time& d) { d += sc_time(1, SC_NS); out->b_transport(gp, d); }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4]; tlm::tlm_generic_payload gp; sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND); gp.set_address(0x40); gp.set_data_ptr(buf); gp.set_data_length(4);
    socket->b_transport(gp, d);
    cout << "init: " << gp.get_response_string() << " delay=" << d << endl;
  }
};
int sc_main(int, char**) {
  Init i("i"); Bus b("b"); Mem m("m");
  i.socket.bind(b.in);
  b.out.bind(m.socket);
  sc_start();
  return 0;
}
```

```text
  mem sees 0x40 delay=1 ns
init: TLM_OK_RESPONSE delay=5 ns
```

Bus 把 `delay` 一路加下去（bus 1 ns、memory 4 ns），initiator 最後拿到 5 ns，而且 address 沒有被改（這個 bus 沒有做 base 扣除，見 T8）。

**常見陷阱**

1. 以為 passthrough 會自動轉換：不會，只有 simple socket 會（事實修正 1）。
2. 以為 tagged 和 multi 一樣：tagged 的 socket 只能 bind 一次，要多個來源就要多個 socket，id 是你自己給的；multi 可以多次 bind，id 是綁定順序。
3. 直接用底層 `tlm_initiator_socket` / `tlm_target_socket`：要自己實作整組介面，大部分 model 用 simple 就夠（Q7）。

### T3　b_transport 的時間標註與 quantum keeper

**白話**：`b_transport` 的 `sc_time& delay` 是「這筆交易已經花掉多少時間」。每一層都把自己的延遲加進去，target 不 `wait`。initiator 決定什麼時候真的 `wait`：每筆都 `wait`（慢但時序準），或用 `tlm_quantumkeeper` 把時間攢在 local time，超過 quantum 才 sync（快，但時序不準，見 Q3）。

quantum keeper 常用的四組函式：

- `reset()`：local time 歸零，並算出下一個同步點（用全域 quantum，對齊到整數倍）。thread 開頭與每次 sync 之後都要有。
- `inc(t)` / `set(t)`：`inc` 是累加；`set` 是把 local time 設成絕對值 `t`，不是加上去。
- `need_sync()`：`sc_time_stamp() + local >= next_sync_point`。`next_sync_point` 是**絕對時間**，中間 `wait` 不會改它（MC52）。
- `sync()`：`wait(local)` 再 `reset()`。`set_and_sync(t)` 是「`set(t)`，需要的話再 `sync()`」（MC42）。

```cpp
struct Mem : sc_module {
  tlm_utils::simple_target_socket<Mem> socket;
  SC_CTOR(Mem) : socket("socket") { socket.register_b_transport(this, &Mem::b); }
  void b(tlm::tlm_generic_payload& gp, sc_time& d) { d += sc_time(10, SC_NS); gp.set_response_status(tlm::TLM_OK_RESPONSE); }
};
struct Cpu : sc_module {
  tlm_utils::simple_initiator_socket<Cpu> socket;
  tlm_utils::tlm_quantumkeeper qk;
  int syncs = 0;
  SC_CTOR(Cpu) : socket("socket") { SC_THREAD(run); }
  void run() {
    qk.reset();
    unsigned char buf[4];
    for (int i = 0; i < 10; ++i) {
      tlm::tlm_generic_payload gp;
      gp.set_command(tlm::TLM_READ_COMMAND); gp.set_address(4 * i); gp.set_data_ptr(buf); gp.set_data_length(4);
      sc_time d = qk.get_local_time();
      socket->b_transport(gp, d);
      qk.set(d);
      if (qk.need_sync()) { qk.sync(); ++syncs; }
    }
    cout << "syncs=" << syncs << " now=" << sc_time_stamp() << " local=" << qk.get_local_time() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(50, SC_NS));
  Cpu c("c"); Mem m("m");
  c.socket.bind(m.socket);
  sc_start();
  return 0;
}
```

```text
syncs=2 now=100 ns local=0 s
```

10 次存取、每次 10 ns、quantum 50 ns：local time 每累積到 50 ns 才 sync 一次，所以是 2 次 sync，而不是 10 次 `wait`。注意 `d` 是 `qk.get_local_time()` 的副本，target 加上去的延遲要用 `qk.set(d)` 寫回。

**常見陷阱**

1. 忘了 `reset()`：`need_sync()` 一開始就是 true，每筆都 sync，沒有加速，也沒有錯誤訊息（MC9）。
2. 以為 quantum 是「從 reset 起算 N ns」：其實同步點是全域時間的整數倍（MC10）。
3. 改了全域 quantum 卻沒有 `reset()`：新值要到下一次 `reset()` / `sync()` 才生效（MC44）。
4. 記錄時間用 `sc_time_stamp()`：應該用 `get_current_time()`，它把 local time 算進去（MC11）。
5. 有副作用的 peripheral 存取前要先 sync（Q3）。

### T4　DMI：拿指標、提示與作廢

**白話**：DMI（direct memory interface）讓 initiator 直接拿到 memory 的指標。之後在範圍內的讀寫不再經過 `b_transport`，只要把 latency 加到 local time。流程：

1. target 在 `b_transport` 裡 `set_dmi_allowed(true)` 當作提示。規範是：若同位址、同種存取的 DMI request 會成功，target 必須把提示設成 true；initiator 可以忽略提示（`tlm_fw_bw_ifs.h`，DMI hint 註解）。
2. initiator 呼叫 `get_direct_mem_ptr(gp, dmi)`，檢查**回傳的 bool**。
3. 之後在 `dmi` 的範圍內用 `dmi.get_dmi_ptr()` 直接存取，並把 read / write latency 加到 local time（MC21 是完整流程）。
4. target 的狀態改變時，走 backward 呼叫 `invalidate_direct_mem_ptr(start, end)` 作廢。全部作廢用 `0` 到 `(sc_dt::uint64)-1`（Q4）。

**常見陷阱**

1. 以為 `get_direct_mem_ptr` 失敗時 `granted access` 會是 0。預設的 fallback 會把權限設成 READ_WRITE 再回傳 false，只能看 bool（MC47；`simple_target_socket.h:363-366`）。
2. 作廢不會中斷領先中的 initiator：它在 local time 內可能還拿著舊指標（MC21）。
3. 在 invalidate 的回呼裡呼叫 `get_direct_mem_ptr`：不允許（`tlm_fw_bw_ifs.h`）。
4. DMI 繞過 target：target 看不到這些存取，tracing 與計數會少（Q5）。

### T5　transport_dbg：除錯存取

**白話**：debugger 要看記憶體、改暫存器，但不能改變模擬：不加時間、不觸發副作用。`transport_dbg(gp)` 回傳成功搬移的 byte 數，範圍是 0 到要求的長度。沒有註冊 callback 時回傳 0（MC12）。bus 只做 decode 和轉送，不加 delay。

重點是三條規則（`tlm_fw_bw_ifs.h`，transport_dbg 註解）：不加時間、不能有副作用、回傳值 ≤ 要求長度。部分搬移是合法的（MC45）。

**常見陷阱**

1. 回傳 0 不是錯誤，是「不支援」。讀不到東西時先查 target 有沒有註冊（MC12）。
2. 回傳值小於要求長度：呼叫端要自己看數字，不能假設全部成功（MC45）。
3. 規範說不能 `wait`、不能改模擬時間，但 2.3.3 的 socket 不會檢查。實測在 thread 裡 `wait` 會正常推進時間（MC48）。這是違反規範，不是 SystemC 會報錯的事。
4. data 的順序是 host endianness（T9）。

### T6　Byte enable 與 streaming width

**白話**：

- **byte enable**：payload 帶一個遮罩指標與長度。`0xff` 的 byte 要存取，`0x00` 的不要（`TLM_BYTE_ENABLED` 巨集是 `0xff`，`tlm_gp.h:113`）。遮罩長度可以比 data length 短，會循環使用：`tlm_gp.cpp:241` 是 `m_byte_enable[i % m_byte_enable_length]`。
- **streaming width**：每一拍傳幾個 byte。預設是 **0**，不是 data length。

下面的 target 寫法和 SystemC 範例 `memory.cpp` 的檢查一樣（第 104–108 行）。

```cpp
struct Reg : sc_module {
  tlm_utils::simple_target_socket<Reg> socket;
  SC_CTOR(Reg) : socket("socket") { socket.register_b_transport(this, &Reg::b_transport); }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time&) {
    if (gp.get_byte_enable_ptr()) { gp.set_response_status(tlm::TLM_BYTE_ENABLE_ERROR_RESPONSE); return; }
    if (gp.get_streaming_width() != gp.get_data_length()) { gp.set_response_status(tlm::TLM_BURST_ERROR_RESPONSE); return; }
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void send(const char* label, bool use_be, unsigned sw) {
    unsigned char buf[4] = {0xaa, 0xbb, 0xcc, 0xdd};
    unsigned char be[4] = {0xff, 0x00, 0xff, 0x00};
    tlm::tlm_generic_payload gp;
    sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_WRITE_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    if (sw) gp.set_streaming_width(sw);
    if (use_be) { gp.set_byte_enable_ptr(be); gp.set_byte_enable_length(4); }
    socket->b_transport(gp, d);
    cout << label << ": " << gp.get_response_string() << endl;
  }
  void run() {
    send("plain, sw=0 (default)", false, 0);
    send("plain, sw=4", false, 4);
    send("with byte enable, sw=4", true, 4);
  }
};
int sc_main(int, char**) {
  Init i("i"); Reg r("r");
  i.socket.bind(r.socket);
  sc_start();
  return 0;
}
```

```text
plain, sw=0 (default): TLM_BURST_ERROR_RESPONSE
plain, sw=4: TLM_OK_RESPONSE
with byte enable, sw=4: TLM_BYTE_ENABLE_ERROR_RESPONSE
```

**常見陷阱**

1. 忘了設 streaming width：預設 0，這個 target 就回 `TLM_BURST_ERROR_RESPONSE`（第一行）。一般的連續存取要設成等於 data length。
2. 帶了 byte enable 給不支援它的 target：回 `TLM_BYTE_ENABLE_ERROR_RESPONSE`。
3. byte enable 的長度與 data length 不同時，遮罩怎麼循環要和 target 的實作一致（Q8）。

### T7　Response status 與錯誤處理

這一塊的完整表格在 Q8 第 3 題；每個狀態的 `is_response_error()` 判斷見 MC2；忘了設 status 會變成 INCOMPLETE，也算錯誤（MC3）。只要記一條：**target 的每條路徑都要設 status，initiator 的每次呼叫都要檢查**。

### T8　Address map 與 router

**白話**：router（bus）收到全域位址後，決定要交給哪個 target。轉送前把位址改成 target 的本地 offset，回來時改回原值（MC7 的寫法）。這個「改回」是範例 bus 的建議慣例，不是本機原始碼的規定（事實修正 2）。沒有任何 target 負責的位址，router 直接回 `TLM_ADDRESS_ERROR_RESPONSE`，不轉送（MC49 的輸出）。

```text
  t0 sees addr=0x4
init addr=0x4 status=TLM_OK_RESPONSE delay=5 ns
  t1 sees addr=0x4
init addr=0x1004 status=TLM_OK_RESPONSE delay=5 ns
init addr=0x3000 status=TLM_ADDRESS_ERROR_RESPONSE delay=0 s
```

**常見陷阱**

1. 忘了改回位址：initiator 看到的位址就變了（MC7 第二段對照）。
2. 每一層都要把自己的延遲加進同一個 `delay`；只有最後的 initiator 決定何時 `wait`（MC7）。
3. 跨 target 邊界的交易怎麼處理，標準沒有規定，是實作選擇（Q6 第 4 題、Q13）。
4. 手寫練習 E1 就是這一題的完整版。

### T9　Endianness 與 host 順序

**白話**：payload 的 data 是 byte 陣列。`transport_dbg` 的規範是 data 一律用 host 的 endianness（`tlm_fw_bw_ifs.h`，transport_dbg 註解）。如果 initiator 的 endianness 和 host 不同，SystemC 提供 `tlm_to_hostendian_word<T>` / `tlm_from_hostendian_word<T>`（`tlm_endian_conv.h:112-113`、`531`、`562`）：送出前轉成 host 順序，回來後轉回 initiator 的順序。檔頭註解的限制：只用在 initiator 內部；交易建立時呼叫 `to_` 函式、交易完成時呼叫對應的 `from_` 函式；兩者的 template 參數與 bus 寬度要一樣；不能直接拿來當 bridge 用。範例用法見 `examples/tlm/lt_mixed_endian/src/me_traffic_generator.cpp:235、252、292、309`。

先看 host 本身的順序（MC46，x86-64 是 little endian）：

```cpp
#include <cstdint>
int sc_main(int, char**) {
  uint32_t v = 0x11223344;
  unsigned char b[4];
  memcpy(b, &v, 4);
  cout << std::hex << (int)b[0] << " " << (int)b[3] << endl;
  return 0;
}
```

```text
44 11
```

**常見陷阱**

1. 以為 `buf[0]` 一定是最低位元組：取決於主機（MC46）。
2. 只呼叫 `to_` 忘了 `from_`，或兩邊的 template 參數與寬度不一致（檔頭註解建議一律呼叫 `from_`）。
3. `tlm_to_hostendian_word` / `tlm_from_hostendian_word` 的 round trip 本次沒有實跑，這一段只依標頭註解與範例呼叫點寫。要練習時請自己跑一次確認。

### T10　Base protocol：ignorable 與 mandatory extension

**白話**：extension 是附在交易上的額外資訊（例如 AXI ID、secure bit）。收到不認得的 extension 時：

- **ignorable**：可以忽略，交易照常完成。
- **mandatory**：必須處理；不能處理時要回錯誤。

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};
struct Other : tlm::tlm_extension<Other> {   // 目標不認得的 extension
  tlm::tlm_extension_base* clone() const { return new Other(*this); }
  void copy_from(const tlm::tlm_extension_base&) {}
};
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") { socket.register_b_transport(this, &Target::b_transport); }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time&) {
    if (!gp.get_extension<Tag>()) { gp.set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE); return; }  // mandatory
    gp.set_response_status(tlm::TLM_OK_RESPONSE);   // Other 不認得，直接忽略（ignorable）
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void send(const char* label, bool with_tag, bool with_other) {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND); gp.set_address(0); gp.set_data_ptr(buf); gp.set_data_length(4);
    Tag t; Other o;
    if (with_tag) gp.set_extension(&t);
    if (with_other) gp.set_extension(&o);
    socket->b_transport(gp, d);
    cout << label << ": " << gp.get_response_string() << endl;
    gp.clear_extension<Tag>(); gp.clear_extension<Other>();
  }
  void run() {
    send("no tag, no other", false, false);
    send("tag only", true, false);
    send("tag + unknown Other", true, true);
    send("unknown Other only", false, true);
  }
};
int sc_main(int, char**) {
  Init i("i"); Target t("t");
  i.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

```text
no tag, no other: TLM_COMMAND_ERROR_RESPONSE
tag only: TLM_OK_RESPONSE
tag + unknown Other: TLM_OK_RESPONSE
unknown Other only: TLM_COMMAND_ERROR_RESPONSE
```

`ignorable` 與 `mandatory` 是 IEEE 1666 TLM-2.0 base protocol 的用語。2.3.3 的 TLM 標頭與原始碼（`include/tlm*`、`src/tlm*`）裡找不到這兩個字（`grep` 沒有結果），本機只有範例慣例：`examples/tlm/lt_extension_mandatory` 的 target 在 extension 不存在時印出 `not present - ERROR`。標準條文本機沒有，這裡**未核對條文**，以上面的實跑為準。

**常見陷阱**

1. 以為 extension 會自動跟著 bus 複製：bus 只轉交 payload；只有 `deep_copy_from` 才會 clone（MC40）。
2. 以為 mandatory 的檢查是 socket 自動做的：2.3.3 的 socket 不會檢查，是 target 自己要寫（上面的 `if`）。

### T11　AT 收尾：回傳值、提前完成、回傳路徑、PEQ

這一塊的題目大多在 MC17–MC36，這裡只整理規則與題號。

- `TLM_ACCEPTED`：收到了、phase 沒動，之後會用另一個方向回覆（MC17、MC24）。
- `TLM_UPDATED`：phase 已推進，要看 `phase` 這個 in/out 參數（MC17、MC24）。
- `TLM_COMPLETED`：整筆交易已經結束，不必再看 phase（MC18、MC24）。
- **提前完成**：target 在第一次 forward 呼叫就回 `TLM_COMPLETED`，資料與 status 必須在返回前寫好（MC18）；或者 target 在 `BEGIN_REQ` 的回程回 `TLM_UPDATED` + `END_REQ`，之後自己送 `BEGIN_RESP`，initiator 對 `BEGIN_RESP` 回 `TLM_COMPLETED`（MC17、MC34）。
- **回傳路徑**：target 只用 backward 送 `END_REQ`、`BEGIN_RESP`；initiator 只用 forward 送 `BEGIN_REQ`、`END_RESP`（MC26；MC35 說明 socket 不會檢查方向）。
- **end-response 規則**：對 `BEGIN_RESP` 回 `TLM_ACCEPTED` 就必須之後送 `END_RESP`，否則下一筆回應永遠送不出（MC36）。
- **payload 要活到交易結束**：非阻塞交易的 payload 不能只放在 `nb_transport_fw` 的堆疊上（MC17 的 segfault 經驗）。
- **PEQ**：`peq_with_get` 要用 `while` 取完到期的項目，否則剩下的會卡住（MC31）；同一時間的項目維持通知順序（MC29）。`peq_with_cb_and_phase` 會依時間排序，並在到期時呼叫 callback（MC30、MC32）。

---

## 選擇題：先建立直覺（MC1–MC53）

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

**C。** bus 直接改 payload 的位址（扣掉 base 0x1000）再往下送，所以 target 看到的是區域位址 `0x8`；這份範例 bus 在返回前把位址還原，所以 initiator 仍看到 `0x1008`。還原位址是建議的慣例（讓上游看到的 payload 與送進來時一致），不是本機原始碼規定；若 bus 忘了還原，initiator 看到的就是被改過的位址，這份題庫只實跑了有還原的版本。延遲是一路累加的：bus 加 5 ns，再傳給 target 又加 10 ns，initiator 最後拿到 15 ns，`now` 仍是 `0 s`：**每一層都要把自己的延遲加進同一個 `delay`**，只有最後的 initiator 決定何時 `wait`。

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

### AT 非阻塞傳輸（MC23–MC36）

前面的題目以 LT（`b_transport`）為主；這一批是 AT（`nb_transport_fw/bw`、phase、`tlm_sync_enum`、payload event queue），同樣由淺到深（L1 → L3）。這批題目的程式碼比較長，因為 AT 至少要有一個 initiator 和一個 target 互相呼叫。

**這一批額外需要的開頭**：除了上面的 `#include`，再加上：

```cpp
#include <tlm_utils/peq_with_get.h>
#include <tlm_utils/peq_with_cb_and_phase.h>
```

##### 入門（L1）

#### MC23：`tlm_phase` 的內容〔L1〕

```cpp
int sc_main(int, char**) {
  tlm::tlm_phase p;
  cout << p << " " << (unsigned)p << endl;
  tlm::tlm_phase all[] = {tlm::BEGIN_REQ, tlm::END_REQ, tlm::BEGIN_RESP, tlm::END_RESP};
  for (auto ph : all) cout << ph << "=" << (unsigned)ph << " ";
  cout << endl;
  cout << (p == tlm::UNINITIALIZED_PHASE) << (all[0] == tlm::BEGIN_REQ) << endl;
  return 0;
}
```

三行輸出是？

- A. `BEGIN_REQ 0`；`BEGIN_REQ=0 END_REQ=1 BEGIN_RESP=2 END_RESP=3`；`11`
- B. `UNINITIALIZED_PHASE 0`；`BEGIN_REQ=1 END_REQ=2 BEGIN_RESP=3 END_RESP=4`；`00`
- C. `UNINITIALIZED_PHASE 0`；`BEGIN_REQ=1 END_REQ=2 BEGIN_RESP=3 END_RESP=4`；`11`
- D. 編譯錯誤，`tlm_phase` 不能直接 `cout`

<details>
<summary>答案</summary>

**C。** 標準的四個 phase 數值是 1 到 4（`tlm_phase.h`：`BEGIN_REQ=1, END_REQ, BEGIN_RESP, END_RESP`），預設建構的 `tlm_phase` 是 `UNINITIALIZED_PHASE`（0）。`tlm_phase` 是一個 class，可以隱含轉成 `unsigned int`（所以能比較），也有 `operator<<` 印出名字（`get_name()`）；`p == tlm::UNINITIALIZED_PHASE` 與 `all[0] == tlm::BEGIN_REQ` 都成立，印出 `11`。

```
UNINITIALIZED_PHASE 0
BEGIN_REQ=1 END_REQ=2 BEGIN_RESP=3 END_RESP=4
11
```

注意：phase 是**物件**不是裸 enum，所以可以擴充（見 MC25）；比較時用 `==`，不要自己比數字。

</details>

---

#### MC24：`tlm_sync_enum` 的三個回傳值各代表什麼？〔L1〕

```cpp
int mode = 0;

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::nb_transport_fw);
  }
  tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& gp,
                                     tlm::tlm_phase& phase, sc_time&) {
    switch (mode) {
      case 0:  return tlm::TLM_ACCEPTED;
      case 1:  phase = tlm::END_REQ; return tlm::TLM_UPDATED;
      default: gp.set_response_status(tlm::TLM_OK_RESPONSE); return tlm::TLM_COMPLETED;
    }
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    for (mode = 0; mode < 3; ++mode) {
      tlm::tlm_generic_payload gp;
      tlm::tlm_phase phase = tlm::BEGIN_REQ;
      sc_time delay = SC_ZERO_TIME;
      gp.set_command(tlm::TLM_READ_COMMAND);
      gp.set_address(0);
      gp.set_data_ptr(buf);
      gp.set_data_length(4);
      tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, phase, delay);
      cout << "ret=" << r << " phase=" << phase << " status=" << gp.get_response_string() << endl;
    }
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

三行輸出是？（`tlm_sync_enum` 以整數印出）

- A. 三行依序 `ret=0`、`ret=1`、`ret=2`；只有第二行的 phase 變成 `END_REQ`；只有第三行的 status 變成 OK
- B. 三行依序 `ret=1`、`ret=2`、`ret=3`；其餘相同
- C. 三行依序 `ret=0`、`ret=1`、`ret=2`；第三行的 phase 也變成 `END_RESP`
- D. 三行依序 `ret=0`、`ret=1`、`ret=2`；第二行的 phase 仍是 `BEGIN_REQ`，因為 `TLM_UPDATED` 不會改 phase

<details>
<summary>答案</summary>

**A。** `enum tlm_sync_enum { TLM_ACCEPTED, TLM_UPDATED, TLM_COMPLETED }`（`tlm_fw_bw_ifs.h`），數值 0、1、2。三個值告訴呼叫者「接下來怎麼辦」：

- `TLM_ACCEPTED`（0）：我收下了，**什麼都沒改**；之後我會用另一個方向的呼叫通知你（第一行：phase 沒變、status 還是 INCOMPLETE）。
- `TLM_UPDATED`（1）：我已經把交易推進到新的 phase，**請看 `phase` 這個 in/out 參數**（第二行：phase 變成 `END_REQ`）。
- `TLM_COMPLETED`（2）：整筆交易已經完成，回應都在 payload 裡（第三行：status 已是 OK，phase 沒被改，這時不需要再看 phase）。

```
ret=0 phase=BEGIN_REQ status=TLM_INCOMPLETE_RESPONSE
ret=1 phase=END_REQ status=TLM_INCOMPLETE_RESPONSE
ret=2 phase=BEGIN_REQ status=TLM_OK_RESPONSE
```

</details>

---

##### 應用（L2）

#### MC25：自訂 phase〔L2〕

```cpp
TLM_DECLARE_EXTENDED_PHASE(PREPARE);
TLM_DECLARE_EXTENDED_PHASE(RETRY);

int sc_main(int, char**) {
  tlm::tlm_phase p = PREPARE;
  cout << PREPARE << "=" << (unsigned)PREPARE << " " << RETRY << "=" << (unsigned)RETRY << endl;
  cout << (p == PREPARE) << (p == RETRY) << (p == tlm::END_RESP) << endl;
  cout << (unsigned)tlm::END_RESP << endl;
  return 0;
}
```

三行輸出是？

- A. `PREPARE=1 RETRY=2`；`100`；`4`
- B. `PREPARE=5 RETRY=6`；`100`；`4`
- C. `PREPARE=0 RETRY=1`；`100`；`4`
- D. 編譯錯誤，不能自己新增 phase

<details>
<summary>答案</summary>

**B。** `TLM_DECLARE_EXTENDED_PHASE(名字)` 會產生一個 `tlm_phase` 的衍生物件，建構時向 phase registry 註冊（`tlm_phase.cpp`）：registry 一開始已有 5 個內建名稱（0 到 4），新的 phase 依註冊順序從 5 開始編號，所以 `PREPARE=5`、`RETRY=6`，不會與標準 phase 重疊；`p == PREPARE` 為真，其餘為假，`END_RESP` 仍是 4。

```
PREPARE=5 RETRY=6
100
4
```

自訂 phase 通常用來表達標準 phase 沒涵蓋的細節（例如 cache coherency 的額外握手）。不認識這個 phase 的元件，在 SystemC 的範例 target（`at_target_4_phase.cpp` 的 `default:` 分支）是印一次警告、回 `TLM_ACCEPTED`；這是範例的處理方式，標準對「可忽略的 phase」的規定這份題庫沒有查條文。

</details>

---

#### MC26：一筆完整的四 phase 讀取，哪些 phase 走 forward、哪些走 backward？〔L2〕

```cpp
const char* str(tlm::tlm_sync_enum r) {
  return r == tlm::TLM_ACCEPTED ? "TLM_ACCEPTED"
       : r == tlm::TLM_UPDATED  ? "TLM_UPDATED" : "TLM_COMPLETED";
}

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  tlm::tlm_generic_payload* gp = nullptr;
  sc_event start;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::fw);
    SC_THREAD(respond);
  }
  tlm::tlm_sync_enum fw(tlm::tlm_generic_payload& t, tlm::tlm_phase& ph, sc_time&) {
    if (ph == tlm::BEGIN_REQ) {
      gp = &t;
      start.notify(SC_ZERO_TIME);
      return tlm::TLM_ACCEPTED;
    }
    return tlm::TLM_COMPLETED;   // END_RESP
  }
  void respond() {
    wait(start);
    wait(5, SC_NS);
    tlm::tlm_phase ph = tlm::END_REQ;
    sc_time d = SC_ZERO_TIME;
    tlm::tlm_sync_enum r = socket->nb_transport_bw(*gp, ph, d);
    cout << "bw END_REQ @" << sc_time_stamp() << " -> " << str(r) << endl;
    wait(10, SC_NS);
    gp->set_response_status(tlm::TLM_OK_RESPONSE);
    ph = tlm::BEGIN_RESP;
    r = socket->nb_transport_bw(*gp, ph, d);
    cout << "bw BEGIN_RESP @" << sc_time_stamp() << " -> " << str(r) << endl;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  sc_event resp;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum bw(tlm::tlm_generic_payload&, tlm::tlm_phase& ph, sc_time&) {
    if (ph == tlm::BEGIN_RESP) resp.notify();
    return tlm::TLM_ACCEPTED;
  }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase ph = tlm::BEGIN_REQ;
    sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, ph, d);
    cout << "fw BEGIN_REQ @" << sc_time_stamp() << " -> " << str(r) << endl;
    wait(resp);
    wait(2, SC_NS);
    ph = tlm::END_RESP;
    r = socket->nb_transport_fw(gp, ph, d);
    cout << "fw END_RESP @" << sc_time_stamp() << " -> " << str(r) << endl;
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

輸出四行的標頭是 `fw` 或 `bw`，表示是 initiator 呼叫 target（forward）還是 target 呼叫 initiator（backward）。四個 phase 的方向分別是？

- A. forward：`BEGIN_REQ`、`END_REQ`；backward：`BEGIN_RESP`、`END_RESP`
- B. 四個都走 forward，backward 只用來回傳 `TLM_COMPLETED`
- C. forward：`BEGIN_REQ`、`BEGIN_RESP`；backward：`END_REQ`、`END_RESP`
- D. forward：`BEGIN_REQ`、`END_RESP`；backward：`END_REQ`、`BEGIN_RESP`

<details>
<summary>答案</summary>

**D。** 規則可以這樣記：**「開始請求」與「結束回應」是 initiator 發的（forward）；「結束請求」與「開始回應」是 target 發的（backward）**。

```
fw BEGIN_REQ @0 s -> TLM_ACCEPTED
bw END_REQ @5 ns -> TLM_ACCEPTED
bw BEGIN_RESP @15 ns -> TLM_ACCEPTED
fw END_RESP @17 ns -> TLM_COMPLETED
```

時間線：`0 s` initiator 送 `BEGIN_REQ`，target 回 `TLM_ACCEPTED`；5 ns 後 target 用 backward 送 `END_REQ`，initiator 回 `TLM_ACCEPTED`；再過 10 ns（15 ns）target 送 `BEGIN_RESP`，initiator 回 `TLM_ACCEPTED`；initiator 再等 2 ns（17 ns）送 `END_RESP`，target 回 `TLM_COMPLETED`，交易結束。

原始碼佐證：SystemC 範例 target（`examples/tlm/common/src/at_target_4_phase.cpp`）在 forward 路徑收到 `END_REQ` 或 `BEGIN_RESP` 時直接 `REPORT_FATAL`（`Illegal phase received by target -- END_REQ or BEGIN_RESP`）；`simple_target_socket` 的 nb→b 轉換路徑也只接受 forward 的 `BEGIN_REQ` 與 `END_RESP`，其他 phase 報 `invalid phase received`。

</details>

---

#### MC27：`delay` 在 `nb_transport` 裡的意思〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::fw);
  }
  tlm::tlm_sync_enum fw(tlm::tlm_generic_payload&, tlm::tlm_phase& phase, sc_time& delay) {
    cout << "target: arrival=" << sc_time_stamp() + delay << " (now=" << sc_time_stamp()
         << ", delay=" << delay << ")" << endl;
    delay += sc_time(3, SC_NS);
    phase = tlm::END_REQ;
    return tlm::TLM_UPDATED;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase phase = tlm::BEGIN_REQ;
    sc_time delay(7, SC_NS);
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, phase, delay);
    cout << "init: ret=" << r << " phase=" << phase << " delay=" << delay
         << " now=" << sc_time_stamp() << endl;
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

- A. `target: arrival=0 s (now=0 s, delay=7 ns)`；`init: ret=1 phase=END_REQ delay=10 ns now=0 s`
- B. `target: arrival=7 ns (now=0 s, delay=7 ns)`；`init: ret=1 phase=END_REQ delay=7 ns now=0 s`
- C. `target: arrival=7 ns (now=0 s, delay=7 ns)`；`init: ret=1 phase=END_REQ delay=10 ns now=0 s`
- D. `target: arrival=7 ns (now=0 s, delay=7 ns)`；`init: ret=1 phase=END_REQ delay=10 ns now=10 ns`

<details>
<summary>答案</summary>

**C。** `nb_transport` 的 `sc_time& delay` 和 `b_transport` 一樣是 in/out：**呼叫者說「這次呼叫發生在 simulation time 加上 delay 的時間點」**。initiator 說 7 ns，所以 target 計算的到達時間是 `sc_time_stamp() + delay = 7 ns`（而 `now` 仍是 `0 s`，沒有 `wait`）。target 處理要 3 ns，就把 `delay` 加成 10 ns，並回 `TLM_UPDATED`、phase 改成 `END_REQ`，這些修改都會透過參考傳回 initiator，initiator 看到的 `delay=10 ns`，`now` 還是 `0 s`。

```
target: arrival=7 ns (now=0 s, delay=7 ns)
init: ret=1 phase=END_REQ delay=10 ns now=0 s
```

所以 AT 也可以搭配 temporal decoupling：initiator 領先的時間放在 `delay` 裡傳給 target。

</details>

---

#### MC28：AT initiator 呼叫只有 `b_transport` 的 target〔L2〕

```cpp
const char* str(tlm::tlm_sync_enum r) {
  return r == tlm::TLM_ACCEPTED ? "TLM_ACCEPTED"
       : r == tlm::TLM_UPDATED  ? "TLM_UPDATED" : "TLM_COMPLETED";
}

struct Target : sc_module {          // 只有 LT 的 b_transport
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {            // AT initiator
  tlm_utils::simple_initiator_socket<Init> socket;
  sc_event done;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum bw(tlm::tlm_generic_payload& gp, tlm::tlm_phase& ph, sc_time&) {
    cout << "bw " << ph << " @" << sc_time_stamp() << " status=" << gp.get_response_string() << endl;
    done.notify();
    return tlm::TLM_COMPLETED;
  }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase ph = tlm::BEGIN_REQ;
    sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, ph, d);
    cout << "fw BEGIN_REQ @" << sc_time_stamp() << " -> " << str(r) << endl;
    wait(done);
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

- A. `fw BEGIN_REQ @0 s -> TLM_ACCEPTED`；`bw BEGIN_RESP @10 ns status=TLM_OK_RESPONSE`
- B. `fw BEGIN_REQ @0 s -> TLM_COMPLETED`；`bw` 不會被呼叫
- C. `fw BEGIN_REQ @10 ns -> TLM_UPDATED`
- D. 執行期錯誤：`nb_transport_fw` 不能用來呼叫只有 `b_transport` 的 target

<details>
<summary>答案</summary>

**A。** 這是 `simple_target_socket` 的 nb→b 轉換（`nb2b_thread`）：收到 forward 的 `BEGIN_REQ` 時，socket spawn 一個內部 thread 去呼叫 target 的 `b_transport`，並立刻回 `TLM_ACCEPTED`（這個 thread 會 `wait` 掉 `b_transport` 回報的 delay，這裡是 10 ns）；時間到後，socket 自己用 backward path 呼叫 initiator 的 `nb_transport_bw(BEGIN_RESP)`。所以 AT initiator 可以直接接 LT target，不需要改 target。

```
fw BEGIN_REQ @0 s -> TLM_ACCEPTED
bw BEGIN_RESP @10 ns status=TLM_OK_RESPONSE
```

反方向（LT initiator 對只有 nb 的 target）見 MC13。

</details>

---

#### MC29：`peq_with_get` 的取出順序〔L2〕

```cpp
struct M : sc_module {
  tlm_utils::peq_with_get<tlm::tlm_generic_payload> peq;
  tlm::tlm_generic_payload a, b, c;
  SC_CTOR(M) : peq("peq") { SC_THREAD(producer); SC_THREAD(consumer); }
  char label(tlm::tlm_generic_payload* p) { return p == &a ? 'a' : p == &b ? 'b' : 'c'; }
  void producer() {
    peq.notify(a, sc_time(20, SC_NS));
    peq.notify(b, sc_time(10, SC_NS));
    peq.notify(c, sc_time(10, SC_NS));
  }
  void consumer() {
    for (;;) {
      wait(peq.get_event());
      tlm::tlm_generic_payload* p;
      while ((p = peq.get_next_transaction()))
        cout << label(p) << " @" << sc_time_stamp() << endl;
    }
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

輸出是？

- A. `a @20 ns`、`b @10 ns`、`c @10 ns`（照通知順序）
- B. `b @10 ns`、`a @20 ns`（`c` 被丟掉）
- C. `c @10 ns`、`b @10 ns`、`a @20 ns`
- D. `b @10 ns`、`c @10 ns`、`a @20 ns`

<details>
<summary>答案</summary>

**D。** `peq_with_get`（`tlm_utils/peq_with_get.h`）內部是以「到期時間」為 key 的 `std::multimap`：到期時間早的先出；時間相同的，依通知（插入）順序出，所以 `b` 在 `c` 前面。`get_next_transaction()` 只會回傳**已經到期**的項目，沒有到期的就回 0，並順便重新排好下一次的事件（`m_event.notify(下一個到期時間 - 現在)`）；所以 consumer 要用 `while` 把到期的全部取完（見 MC31）。

```
b @10 ns
c @10 ns
a @20 ns
```

</details>

---

#### MC30：`peq_with_cb_and_phase`，時間相同的順序〔L2〕

```cpp
struct M : sc_module {
  tlm_utils::peq_with_cb_and_phase<M> peq;
  tlm::tlm_generic_payload a, b, c;
  SC_CTOR(M) : peq(this, &M::cb) { SC_THREAD(producer); }
  void cb(tlm::tlm_generic_payload& p, const tlm::tlm_phase&) {
    cout << (&p == &a ? 'a' : &p == &b ? 'b' : 'c') << " @" << sc_time_stamp() << endl;
  }
  void producer() {
    peq.notify(a, tlm::BEGIN_REQ, sc_time(10, SC_NS));
    peq.notify(b, tlm::BEGIN_REQ, sc_time(10, SC_NS));
    peq.notify(c, tlm::BEGIN_REQ, sc_time(5, SC_NS));
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

輸出是？

- A. `a @10 ns`、`b @10 ns`、`c @5 ns`（照通知順序）
- B. `c @5 ns`、`a @10 ns`、`b @10 ns`
- C. `c @5 ns`、`b @10 ns`、`a @10 ns`
- D. 只有 `c @5 ns`

<details>
<summary>答案</summary>

**B。** 這個 PEQ 以 `SC_METHOD` 在到期時呼叫你登記的 callback（`peq_with_cb_and_phase.h`），內部用一個依時間排序的串列：新項目插在「所有時間 `<=` 它的項目」之後，所以時間不同的按時間排序（`c` 的 5 ns 最早），時間相同的維持先進先出（`a` 在 `b` 之前）。它可以同時掛任意多個待處理通知；`m_e.notify(when)` 會被後面更早的通知取代（`c` 的 5 ns），callback 結束時再把事件重新排到下一個到期時間（10 ns）。

```
c @5 ns
a @10 ns
b @10 ns
```

</details>

---

##### 進階（L3）

#### MC31：只呼叫一次 `get_next_transaction()`〔L3〕

```cpp
struct M : sc_module {
  tlm_utils::peq_with_get<tlm::tlm_generic_payload> peq;
  tlm::tlm_generic_payload a, b, c;
  SC_CTOR(M) : peq("peq") { SC_THREAD(producer); SC_THREAD(consumer); }
  char label(tlm::tlm_generic_payload* p) { return p == &a ? 'a' : p == &b ? 'b' : 'c'; }
  void producer() {
    peq.notify(a, sc_time(20, SC_NS));
    peq.notify(b, sc_time(10, SC_NS));
    peq.notify(c, sc_time(10, SC_NS));
  }
  void consumer() {
    for (;;) {
      wait(peq.get_event());
      tlm::tlm_generic_payload* p = peq.get_next_transaction();
      if (p) cout << label(p) << " @" << sc_time_stamp() << endl;
    }
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start(100, SC_NS);
  cout << "end @" << sc_time_stamp() << endl;
  return 0;
}
```

（`a`、`b`、`c` 的通知時間與 MC29 相同。）輸出是？

- A. `b @10 ns`、`c @10 ns`、`a @20 ns`，然後 `end @100 ns`
- B. `b @10 ns`、`c @20 ns`、`a @20 ns`，然後 `end @100 ns`
- C. `b @10 ns`，然後 `end @100 ns`：`c` 與 `a` 再也不會被送出
- D. `b @10 ns`、`c @10 ns`，然後 `end @100 ns`：只有 `a` 遺失

<details>
<summary>答案</summary>

**C。** `peq_with_get` 的 event 是依通知時間排好的：`a`（20 ns）之後 `b`、`c`（都是 10 ns）的 `m_event.notify(...)` 讓事件只在 10 ns 觸發一次（較早的通知蓋掉較晚的）。10 ns 時 consumer 醒來，呼叫一次 `get_next_transaction()` 取得 `b`；`c` 同樣已到期，但沒有人再去取，而**重新排下一次事件的動作只發生在 `get_next_transaction()` 被呼叫、且發現隊首還沒到期的時候**，所以事件不會再被觸發，`c` 與 `a` 永遠卡在佇列裡，模擬照常結束，沒有任何錯誤訊息。

```
b @10 ns
end @100 ns
```

規則：每次被喚醒，用 `while ((p = peq.get_next_transaction()))` 取到回傳 0 為止（MC29）。

</details>

---

#### MC32：`peq_with_cb_and_phase` 的三種通知，callback 的順序〔L3〕

```cpp
struct M : sc_module {
  tlm_utils::peq_with_cb_and_phase<M> peq;
  tlm::tlm_generic_payload gp;
  sc_dt::uint64 base = 0;
  SC_CTOR(M) : peq(this, &M::cb) { SC_THREAD(run); }
  void cb(tlm::tlm_generic_payload&, const tlm::tlm_phase& ph) {
    cout << ph << " @" << sc_time_stamp() << " delta+" << (sc_delta_count() - base) << endl;
  }
  void run() {
    wait(1, SC_NS);
    base = sc_delta_count();
    peq.notify(gp, tlm::END_RESP, sc_time(10, SC_NS));
    peq.notify(gp, tlm::END_REQ, SC_ZERO_TIME);
    peq.notify(gp, tlm::BEGIN_REQ);
    peq.notify(gp, tlm::BEGIN_RESP, SC_ZERO_TIME);
  }
};

int sc_main(int, char**) {
  M m("m");
  sc_start();
  return 0;
}
```

四個通知的呼叫順序與時間是？（`delta+N` 是相對於一開始的 delta 計數，只有前三行的差別有意義）

- A. `END_RESP` → `END_REQ` → `BEGIN_REQ` → `BEGIN_RESP`（依通知順序）
- B. `END_REQ` → `BEGIN_RESP` → `BEGIN_REQ` → `END_RESP`
- C. `BEGIN_REQ`、`END_REQ`、`BEGIN_RESP` 全部在 `delta+0`，之後才是 `END_RESP`
- D. `BEGIN_REQ`（`delta+0`）→ `END_REQ`（`delta+1`）→ `BEGIN_RESP`（`delta+1`）→ `END_RESP`（`11 ns`）

<details>
<summary>答案</summary>

**D。** 這個 PEQ 依「通知的種類」分三類處理，不是單純依通知順序：`notify(payload, phase)`（沒有時間參數，immediate）先處理，`notify(..., SC_ZERO_TIME)`（delta）其次，有時間的最後（`fec()` 的順序：immediate yield 清單 → delta 清單 → 時間排序串列）。所以第三個呼叫的 `BEGIN_REQ`（immediate）最先、在同一個 delta；兩個 delta 通知（`END_REQ`、`BEGIN_RESP`）在下一個 delta，彼此維持通知順序；10 ns 的 `END_RESP` 最後，時間是 11 ns。delta 通知內部還按 delta 計數的奇偶分兩個清單，確保「在 callback 裡又發出的 delta 通知」會落在再下一個 delta，而不是同一個 delta 被連環處理。

```
BEGIN_REQ @1 ns delta+0
END_REQ @1 ns delta+1
BEGIN_RESP @1 ns delta+1
END_RESP @11 ns delta+2
```

</details>

---

#### MC33：不照順序完成的回應〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  tlm_utils::peq_with_cb_and_phase<Target> peq;
  SC_CTOR(Target) : socket("socket"), peq(this, &Target::cb) {
    socket.register_nb_transport_fw(this, &Target::fw);
  }
  tlm::tlm_sync_enum fw(tlm::tlm_generic_payload& gp, tlm::tlm_phase& ph, sc_time& d) {
    if (ph == tlm::BEGIN_REQ) {
      sc_time latency(gp.get_address() == 0 ? 20 : 5, SC_NS);
      peq.notify(gp, tlm::BEGIN_RESP, d + latency);
      ph = tlm::END_REQ;
      return tlm::TLM_UPDATED;
    }
    return tlm::TLM_COMPLETED;
  }
  void cb(tlm::tlm_generic_payload& gp, const tlm::tlm_phase&) {
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
    tlm::tlm_phase ph = tlm::BEGIN_RESP;
    sc_time d = SC_ZERO_TIME;
    socket->nb_transport_bw(gp, ph, d);
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  sc_event all_done;
  int done = 0;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum bw(tlm::tlm_generic_payload& gp, tlm::tlm_phase&, sc_time&) {
    cout << "resp addr=" << gp.get_address() << " @" << sc_time_stamp() << endl;
    if (++done == 2) all_done.notify();
    return tlm::TLM_COMPLETED;
  }
  void run() {
    unsigned char buf0[4], buf1[4];
    tlm::tlm_generic_payload gp0, gp1;
    tlm::tlm_generic_payload* gps[2] = {&gp0, &gp1};
    unsigned char* bufs[2] = {buf0, buf1};
    for (int i = 0; i < 2; ++i) {
      tlm::tlm_phase ph = tlm::BEGIN_REQ;
      sc_time d = SC_ZERO_TIME;
      gps[i]->set_command(tlm::TLM_READ_COMMAND);
      gps[i]->set_address(4 * i);
      gps[i]->set_data_ptr(bufs[i]);
      gps[i]->set_data_length(4);
      socket->nb_transport_fw(*gps[i], ph, d);
    }
    wait(all_done);
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

target 對地址 0 的讀取要 20 ns，其他地址 5 ns。輸出是？

- A. `resp addr=4 @5 ns`、`resp addr=0 @20 ns`
- B. `resp addr=0 @20 ns`、`resp addr=4 @20 ns`（回應必須按請求順序）
- C. `resp addr=0 @20 ns`、`resp addr=4 @25 ns`（第二筆要等第一筆完成才會送出）
- D. 執行期錯誤：第一筆交易還沒完成，不能發出第二筆

<details>
<summary>答案</summary>

**A。** target 在 forward 呼叫的**回程**就用 `TLM_UPDATED` + `END_REQ` 表示「請求已接受」，initiator 因此可以立刻發第二筆 `BEGIN_REQ`（不必等第一筆回應）；兩筆各自進 PEQ，按各自的延遲回 `BEGIN_RESP`，所以較快的 `addr=4` 先在 5 ns 完成，`addr=0` 在 20 ns。initiator 要靠 payload 指標（或 extension 裡的 ID）把回應對回請求。這就是 out-of-order 的 AT 模型（SystemC 範例：`examples/tlm/at_ooo`）。

```
resp addr=4 @5 ns
resp addr=0 @20 ns
```

注意：如果 target 回的是 `TLM_ACCEPTED`，initiator 就必須等到 target 用 backward 送 `END_REQ`，才能發下一筆 `BEGIN_REQ`（請求通道一次只接受一筆），這個「等 END_REQ」的限制是 AT 的 request 管線深度的來源（這條規則依範例與一般的 TLM-2.0 規則，標準條文沒有查）。

</details>

---

#### MC34：四 phase 與走捷徑，呼叫次數差多少？〔L3〕

```cpp
bool shortcut = false;

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  tlm::tlm_generic_payload* pending = nullptr;
  sc_event ev;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::fw);
    SC_THREAD(respond);
  }
  tlm::tlm_sync_enum fw(tlm::tlm_generic_payload& gp, tlm::tlm_phase& ph, sc_time&) {
    if (ph == tlm::BEGIN_REQ) {
      pending = &gp;
      ev.notify(SC_ZERO_TIME);
      if (shortcut) { ph = tlm::END_REQ; return tlm::TLM_UPDATED; }
      return tlm::TLM_ACCEPTED;
    }
    return tlm::TLM_COMPLETED;   // END_RESP
  }
  void respond() {
    for (;;) {
      wait(ev);
      tlm::tlm_phase ph;
      sc_time d = SC_ZERO_TIME;
      if (!shortcut) {
        wait(5, SC_NS);
        ph = tlm::END_REQ;
        socket->nb_transport_bw(*pending, ph, d);
      }
      wait(10, SC_NS);
      pending->set_response_status(tlm::TLM_OK_RESPONSE);
      ph = tlm::BEGIN_RESP;
      socket->nb_transport_bw(*pending, ph, d);
    }
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  sc_event resp;
  int fw_calls = 0, bw_calls = 0;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum bw(tlm::tlm_generic_payload&, tlm::tlm_phase& ph, sc_time&) {
    ++bw_calls;
    if (ph == tlm::BEGIN_RESP) {
      resp.notify();
      return shortcut ? tlm::TLM_COMPLETED : tlm::TLM_ACCEPTED;
    }
    return tlm::TLM_ACCEPTED;    // END_REQ
  }
  void run() {
    unsigned char buf[4];
    for (int m = 0; m < 2; ++m) {
      shortcut = (m == 1);
      fw_calls = bw_calls = 0;
      tlm::tlm_generic_payload gp;
      tlm::tlm_phase ph = tlm::BEGIN_REQ;
      sc_time d = SC_ZERO_TIME;
      gp.set_command(tlm::TLM_READ_COMMAND);
      gp.set_address(0);
      gp.set_data_ptr(buf);
      gp.set_data_length(4);
      socket->nb_transport_fw(gp, ph, d); ++fw_calls;
      wait(resp);
      if (!shortcut) {
        ph = tlm::END_RESP;
        socket->nb_transport_fw(gp, ph, d); ++fw_calls;
      }
      cout << (shortcut ? "shortcut" : "full") << ": fw=" << fw_calls << " bw=" << bw_calls
           << " done @" << sc_time_stamp() << endl;
      wait(1, SC_NS);
    }
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

`full` 是完整四 phase（target 回 `TLM_ACCEPTED`，initiator 回 `TLM_ACCEPTED`），`shortcut` 是 target 用 return path 回 `TLM_UPDATED(END_REQ)`、initiator 對 `BEGIN_RESP` 回 `TLM_COMPLETED`。`fw`、`bw` 的次數各是？

- A. `full: fw=4 bw=4`；`shortcut: fw=2 bw=2`
- B. `full: fw=2 bw=2`；`shortcut: fw=1 bw=1`
- C. `full: fw=2 bw=2`；`shortcut: fw=2 bw=2`
- D. `full: fw=1 bw=3`；`shortcut: fw=1 bw=1`

<details>
<summary>答案</summary>

**B。** 完整四 phase 一共 4 次呼叫：forward 2 次（`BEGIN_REQ`、`END_RESP`）加 backward 2 次（`END_REQ`、`BEGIN_RESP`）。走捷徑只要 2 次：`BEGIN_REQ` 的**回程**帶回 `END_REQ`（省掉 backward 的 `END_REQ`），`BEGIN_RESP` 回 `TLM_COMPLETED`（省掉 forward 的 `END_RESP`）。每次呼叫都是一個同步點（可能伴隨 context switch 與 event），少一次就少一次開銷，這是 AT 模型加速常用的手法。

```
full: fw=2 bw=2 done @15 ns
shortcut: fw=1 bw=1 done @26 ns
```

（`full` 比 `shortcut` 多花的時間，是我在 target 裡模擬的 5 ns `END_REQ` 延遲，不是呼叫次數造成的。）

範例的 target 對 backward 呼叫回傳值的解讀（`at_target_4_phase.cpp`）：對 `END_REQ` 回 `TLM_ACCEPTED` 才有效，回 `TLM_COMPLETED` 或 `TLM_UPDATED` 範例視為錯誤（因為 initiator 還沒收到資料）；對 `BEGIN_RESP` 回 `TLM_COMPLETED` 表示交易結束，回 `TLM_ACCEPTED` 表示「之後還會送 `END_RESP`」，回 `TLM_UPDATED` 範例視為錯誤。

</details>

---

#### MC35：socket 會檢查 phase 的方向嗎？〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_nb_transport_fw(this, &Target::fw);
  }
  tlm::tlm_sync_enum fw(tlm::tlm_generic_payload&, tlm::tlm_phase& ph, sc_time&) {
    cout << "target got fw " << ph << endl;
    return tlm::TLM_ACCEPTED;
  }
};

struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    tlm::tlm_phase ph = tlm::BEGIN_RESP;   // 這是 backward path 才會用的 phase
    sc_time d = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    tlm::tlm_sync_enum r = socket->nb_transport_fw(gp, ph, d);
    cout << "init: ret=" << r << endl;
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

initiator 故意用 forward path 送出一個只該走 backward 的 `BEGIN_RESP`。輸出是？

- A. 編譯錯誤：`BEGIN_RESP` 不是 forward phase
- B. 執行期錯誤：socket 偵測到方向錯誤並中止
- C. target 不會被呼叫，`init: ret=2`
- D. `target got fw BEGIN_RESP`；`init: ret=0`：沒有任何檢查

<details>
<summary>答案</summary>

**D。** phase 只是一個值，`simple_target_socket` 看到 target 有註冊 `nb_transport_fw` 就原樣轉交（`simple_target_socket.h` 的 `nb_transport_fw`），不檢查方向，也不檢查順序。只有 target 沒註冊 `nb_transport_fw`、靠 nb→b 轉換時，socket 才會自己檢查並報 `invalid phase received`（MC26 提到的那一段）。2.3.3 未附 protocol checker（已在 `src`、`include`、`examples` 搜尋 `checker`，沒有 checker 元件）。

```
target got fw BEGIN_RESP
init: ret=0
```

所以 AT 模型的協定錯誤要靠 target / initiator 自己檢查（像範例那樣對非法 phase 報錯），否則會悄悄地跑出錯誤的結果。

</details>

---

#### MC36：對 `BEGIN_RESP` 回 `TLM_ACCEPTED` 卻忘了送 `END_RESP`〔L3〕

```cpp
struct Target : sc_module {          // 只有 LT 的 b_transport
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") {
    socket.register_b_transport(this, &Target::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};

struct Init : sc_module {            // AT initiator
  tlm_utils::simple_initiator_socket<Init> socket;
  int responses = 0;
  SC_CTOR(Init) : socket("socket") {
    socket.register_nb_transport_bw(this, &Init::bw);
    SC_THREAD(run);
  }
  tlm::tlm_sync_enum bw(tlm::tlm_generic_payload& gp, tlm::tlm_phase& ph, sc_time&) {
    cout << "response " << ++responses << " @" << sc_time_stamp() << endl;
    return tlm::TLM_ACCEPTED;        // 之後要自己再送 END_RESP
  }
  void run() {
    unsigned char buf0[4], buf1[4];
    tlm::tlm_generic_payload gp0, gp1;
    tlm::tlm_generic_payload* gps[2] = {&gp0, &gp1};
    unsigned char* bufs[2] = {buf0, buf1};
    for (int i = 0; i < 2; ++i) {
      tlm::tlm_phase ph = tlm::BEGIN_REQ;
      sc_time d = SC_ZERO_TIME;
      gps[i]->set_command(tlm::TLM_READ_COMMAND);
      gps[i]->set_address(4 * i);
      gps[i]->set_data_ptr(bufs[i]);
      gps[i]->set_data_length(4);
      socket->nb_transport_fw(*gps[i], ph, d);
    }
    wait(100, SC_NS);                // 沒有送過任何 END_RESP
    cout << "end @" << sc_time_stamp() << " responses=" << responses << endl;
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

target 只有 `b_transport`（靠 socket 轉換）。initiator 連發兩筆請求，對 `BEGIN_RESP` 回 `TLM_ACCEPTED` 但從不送 `END_RESP`。輸出是？

- A. `response 1 @10 ns`、`response 2 @10 ns`，然後 `end @100 ns responses=2`
- B. `response 1 @10 ns`、`response 2 @20 ns`，然後 `end @100 ns responses=2`
- C. `response 1 @10 ns`，然後 `end @100 ns responses=1`
- D. 執行期錯誤：忘了送 `END_RESP`

<details>
<summary>答案</summary>

**C。** `TLM_ACCEPTED` 的意思是「我還在處理這個回應，處理完會自己送 `END_RESP`」。socket 的 nb→b 轉換（`nb2b_thread`）因此把 `m_response_in_progress` 設成 true，下一筆回應要等到收到 `END_RESP`（`m_end_response` 事件）才能送出；沒人送，第二筆就**永遠送不出來**，沒有錯誤也沒有警告，模擬照常結束。

```
response 1 @10 ns
end @100 ns responses=1
```

socket 認定「回應已完成」的條件是 `TLM_COMPLETED`，或 `TLM_UPDATED` 且 phase 為 `END_RESP`（原始碼 `nb2b_thread` 內的判斷）。所以：要嘛對 `BEGIN_RESP` 直接回 `TLM_COMPLETED`，要嘛回 `TLM_ACCEPTED` 並在處理完後一定送 `END_RESP`（範例稱為 end-response rule）。

</details>

---

### 補充題（MC37–MC53，2026-11-05 補）

這一批補的是教學導讀 T1–T10 的題目。順序同樣是 L1 → L3。**用到 extension 的題目都會把 `Tag` 定義寫在題目裡**（與 MC14 相同），不需要另外找。

#### MC37：`tlm_dmi` 的預設權限〔L1〕

```cpp
int sc_main(int, char**) {
  tlm::tlm_dmi d;
  cout << d.get_granted_access() << " " << d.is_read_allowed() << d.is_write_allowed() << endl;
  d.set_granted_access(tlm::tlm_dmi::DMI_ACCESS_READ);
  cout << d.get_granted_access() << " " << d.is_read_allowed() << d.is_write_allowed() << endl;
  d.set_granted_access(tlm::tlm_dmi::DMI_ACCESS_READ_WRITE);
  cout << d.is_read_allowed() << d.is_write_allowed() << endl;
  return 0;
}
```

三行輸出是？（`get_granted_access()` 以整數印出）

- A. `0 00`、`1 10`、`10`
- B. `0 00`、`1 10`、`11`
- C. `0 11`、`1 10`、`11`
- D. `0 00`、`0 00`、`11`

<details>
<summary>答案</summary>

**B。** `tlm_dmi` 預設的 granted access 是 `DMI_ACCESS_NONE`（0），讀寫都不允許。設成 READ（1）之後只有 `is_read_allowed()` 為真；設成 READ_WRITE（3）兩者都為真（`tlm_dmi.h` 的 `dmi_access_e`）。

```
0 00
1 10
11
```

</details>

---

#### MC38：哪一行能編譯〔L1〕

下面四行各自放在 `sc_main` 裡單獨編譯，哪一行能編譯成功？

- A. `tlm::tlm_sync_enum r = tlm::BEGIN_REQ;`
- B. `tlm::tlm_generic_payload gp; gp.set_response_status(0);`
- C. `tlm::tlm_phase p = tlm::BEGIN_REQ; tlm::tlm_sync_enum r = tlm::TLM_UPDATED; cout << p << " " << r << endl;`
- D. `tlm::tlm_generic_payload gp; gp.set_command(2);`

<details>
<summary>答案</summary>

**C。** A 是把 phase 值放進 sync enum（GCC：`cannot convert 'tlm::tlm_phase_enum' to 'tlm::tlm_sync_enum'`）；B 和 D 是把整數直接放進 enum 參數（GCC：`invalid conversion from 'int' to ...`）。C 的 phase 和 sync enum 各自用對應的值，編譯成功：

```
BEGIN_REQ 1
```

另一個陷阱：`tlm::tlm_phase p = tlm::TLM_ACCEPTED;` **會**編譯成功（sync enum 先轉成整數，再經過 `tlm_phase(unsigned int)` 這個建構子，`tlm_phase.h:46`，註解寫著 should be dropped），印出的是 `UNINITIALIZED_PHASE`，因為 `TLM_ACCEPTED` 的數值是 0。編譯器不會替你檢查語意，要靠自己看 enum 的型別。

</details>

---

#### MC39：`reset()` 之後，payload 裡還剩什麼〔L2〕

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};

int sc_main(int, char**) {
  unsigned char buf[4];
  tlm::tlm_generic_payload gp;
  Tag tag; tag.value = 42;
  gp.set_command(tlm::TLM_WRITE_COMMAND);
  gp.set_address(0x10);
  gp.set_data_ptr(buf);
  gp.set_data_length(4);
  gp.set_response_status(tlm::TLM_OK_RESPONSE);
  gp.set_extension(&tag);
  gp.reset();
  cout << "cmd=" << (int)gp.get_command() << " addr=0x" << std::hex << gp.get_address() << std::dec
       << " len=" << gp.get_data_length() << " status=" << gp.get_response_string() << endl;
  cout << "ptr_kept=" << (gp.get_data_ptr() == buf) << " ext_kept=" << (gp.get_extension<Tag>() != 0) << endl;
  gp.clear_extension<Tag>();
  return 0;
}
```

兩行輸出是？（command 以整數印出）

- A. `cmd=0 addr=0x0 len=0 status=TLM_INCOMPLETE_RESPONSE`、`ptr_kept=0 ext_kept=0`
- B. `cmd=1 addr=0x10 len=4 status=TLM_OK_RESPONSE`、`ptr_kept=1 ext_kept=0`
- C. `cmd=1 addr=0x10 len=4 status=TLM_OK_RESPONSE`、`ptr_kept=1 ext_kept=1`
- D. `cmd=1 addr=0x10 len=4 status=TLM_INCOMPLETE_RESPONSE`、`ptr_kept=1 ext_kept=0`

<details>
<summary>答案</summary>

**C。** `reset()` 的實作只有兩件事：把 `m_gp_option` 設回預設，然後 `m_extensions.free_entire_cache()`（`tlm_gp.cpp:128-132`）。`free_entire_cache()` 只走訪 cache 裡的項目，而 cache 只收 `set_auto_extension` 掛上的 extension（`tlm_array.h:102-111`）。所以用 `set_extension` 手動掛的 `tag` 還在，command、address、length、response status 也都保留。

```
cmd=1 addr=0x10 len=4 status=TLM_OK_RESPONSE
ptr_kept=1 ext_kept=1
```

這題直接修正了 Q8 第 5 題的說法（見下方「事實修正 5」）：`reset()` 不會清掉手動掛的 extension。要清要自己 `clear_extension`。

</details>

---

#### MC40：`deep_copy_from` 會複製什麼〔L2〕

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};

int sc_main(int, char**) {
  unsigned char a[4] = {1, 2, 3, 4}, b[4] = {0, 0, 0, 0};
  tlm::tlm_generic_payload orig, copy;
  Tag t; t.value = 42;
  orig.set_command(tlm::TLM_READ_COMMAND);
  orig.set_address(8);
  orig.set_data_ptr(a);
  orig.set_data_length(4);
  orig.set_response_status(tlm::TLM_OK_RESPONSE);
  orig.set_extension(&t);
  copy.set_data_ptr(b);
  copy.deep_copy_from(orig);
  cout << "data=" << (int)b[0] << (int)b[3] << " addr=" << copy.get_address()
       << " status=" << copy.get_response_string() << endl;
  Tag* ct = copy.get_extension<Tag>();
  cout << "ext=" << (ct ? ct->value : -1) << " same_ptr=" << (ct == &t) << endl;
  orig.clear_extension<Tag>();
  return 0;
}
```

兩行輸出是？

- A. `data=14 addr=8 status=TLM_OK_RESPONSE`、`ext=42 same_ptr=1`
- B. `data=14 addr=8 status=TLM_INCOMPLETE_RESPONSE`、`ext=-1 same_ptr=0`
- C. `data=14 addr=8 status=TLM_OK_RESPONSE`、`ext=42 same_ptr=0`
- D. `data=00 addr=0 status=TLM_OK_RESPONSE`、`ext=42 same_ptr=0`

<details>
<summary>答案</summary>

**C。** `deep_copy_from` 複製 command、address、長度、response status，並把 data 內容 `memcpy` 進 copy 自己的 buffer（`tlm_gp.cpp:137-153`）。extension 不是共用指標：copy 會呼叫 `clone()` 取得一個新物件，所以 `value` 是 42，但位址不同（`same_ptr=0`）。

```
data=14 addr=8 status=TLM_OK_RESPONSE
ext=42 same_ptr=0
```

所以「深複製」在 TLM 裡指的是資料與 extension 都複製一份；如果 extension 沒有實作 `clone()`，複製會被略過（`tlm_gp.cpp` 的 `if(ext)` 判斷）。

</details>

---

#### MC41：同一型別的 extension 掛兩次〔L2〕

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};

int sc_main(int, char**) {
  tlm::tlm_generic_payload gp;
  Tag t1, t2; t1.value = 1; t2.value = 2;
  Tag* old1 = gp.set_extension(&t1);
  Tag* old2 = gp.set_extension(&t2);
  cout << (old1 == 0) << " " << (old2 == &t1) << " " << gp.get_extension<Tag>()->value << endl;
  gp.clear_extension<Tag>();
  cout << (gp.get_extension<Tag>() == 0) << endl;
  return 0;
}
```

兩行輸出是？

- A. `0 0 2`、`0`
- B. `1 1 2`、`1`
- C. `1 0 1`、`0`
- D. 編譯錯誤：同一型別的 extension 不能掛兩次

<details>
<summary>答案</summary>

**B。** 每個 extension 型別在 payload 上只有一個槽（索引是 `T::ID`）。`set_extension` 會回傳被換掉的舊指標（`tlm_gp.cpp` 的 `set_extension` 回傳 `tmp`），第一次是 0，第二次是 `&t1`；之後 `get_extension` 拿到的是 `t2`。`clear_extension<T>()` 把槽清成 0，之後取出是 0。

```
1 1 2
1
```

注意：舊的 `t1` 不會被任何人 delete，因為它本來就是堆疊物件；這正是 T1 的陷阱，只是這裡沒有 payload 解構，所以不會 crash。

</details>

---

#### MC42：`set_and_sync` 的 `t` 是絕對值還是增量〔L2〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    qk.set_and_sync(sc_time(150, SC_NS));
    cout << "now=" << sc_time_stamp() << " local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
    qk.set_and_sync(sc_time(30, SC_NS));
    cout << "now=" << sc_time_stamp() << " local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）兩行輸出是？

- A. `now=0 s local=150 ns need_sync=1`、`now=0 s local=180 ns need_sync=1`
- B. `now=150 ns local=0 s need_sync=0`、`now=150 ns local=30 ns need_sync=0`
- C. `now=150 ns local=0 s need_sync=0`、`now=150 ns local=180 ns need_sync=0`
- D. `now=0 s local=150 ns need_sync=0`、`now=150 ns local=30 ns need_sync=0`

<details>
<summary>答案</summary>

**B。** `set_and_sync(t)` 先 `set(t)`，**把 local time 設成絕對值 t**，不是加上去。第一次：local = 150 ns，`0 + 150 >= 100` 成立，所以 `sync()`：`wait(150)`，時間到 150 ns，再 `reset()`，下一個同步點變成 150 + 100 = 250 ns。第二次：local 設成 30 ns（不是 180 ns），`150 + 30 < 250`，不需要 sync。

```
now=150 ns local=0 s need_sync=0
now=150 ns local=30 ns need_sync=0
```

</details>

---

#### MC43：`need_sync` 的邊界是 `>=`〔L2〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    qk.inc(sc_time(99, SC_NS));
    cout << "local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
    qk.inc(sc_time(1, SC_NS));
    cout << "local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）兩行輸出是？

- A. `local=99 ns need_sync=1`、`local=100 ns need_sync=1`
- B. `local=99 ns need_sync=0`、`local=100 ns need_sync=1`
- C. `local=99 ns need_sync=0`、`local=100 ns need_sync=0`
- D. `local=99 ns need_sync=1`、`local=100 ns need_sync=0`

<details>
<summary>答案</summary>

**B。** `need_sync()` 的判斷式是 `sc_time_stamp() + local >= next_sync_point`（`tlm_quantumkeeper.h`），是 `>=`。local 剛好等於 quantum 時就要 sync。這個邊界常被寫成 `>`，寫錯時會多跑一段時間才同步。

```
local=99 ns need_sync=0
local=100 ns need_sync=1
```

</details>

---

#### MC44：中途改全域 quantum〔L3〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();                                                  // next sync point = 100 ns
    tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(10, SC_NS));
    qk.inc(sc_time(50, SC_NS));
    cout << "before sync: need_sync=" << qk.need_sync() << endl;
    qk.sync();                                                   // wait(50 ns), then reset()
    qk.inc(sc_time(50, SC_NS));
    cout << "after sync: now=" << sc_time_stamp() << " need_sync=" << qk.need_sync() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

兩行輸出是？

- A. `before sync: need_sync=1`、`after sync: now=50 ns need_sync=0`
- B. `before sync: need_sync=0`、`after sync: now=50 ns need_sync=1`
- C. `before sync: need_sync=0`、`after sync: now=100 ns need_sync=0`
- D. 編譯錯誤：`set_global_quantum` 不能在 thread 裡呼叫

<details>
<summary>答案</summary>

**B。** 中途改全域 quantum 不會影響已經算好的 `next_sync_point`（在 `reset()` 時就算好了，還是 100 ns）。所以第一次 `need_sync` 是 0。`sync()` 之後的 `reset()` 才用新的 quantum：下一個同步點是 50 + 10 = 60 ns。再 `inc(50)` 後 local 是 50，`50 + 50 >= 60`，需要 sync。

```
before sync: need_sync=0
after sync: now=50 ns need_sync=1
```

結論：改 quantum 之後要等下一次 `reset()` 或 `sync()` 才會用到新值。

</details>

---

#### MC45：`transport_dbg` 只搬一部分〔L2〕

```cpp
struct Mem : sc_module {
  tlm_utils::simple_target_socket<Mem> socket;
  unsigned char mem[8];
  SC_CTOR(Mem) : socket("socket") {
    for (int i = 0; i < 8; ++i) mem[i] = 0x10 + i;
    socket.register_transport_dbg(this, &Mem::dbg);
  }
  unsigned int dbg(tlm::tlm_generic_payload& gp) {
    sc_dt::uint64 a = gp.get_address();
    if (a >= 8) return 0;
    unsigned int room = 8 - (unsigned)a;
    unsigned int n = gp.get_data_length() < room ? gp.get_data_length() : room;
    memcpy(gp.get_data_ptr(), mem + a, n);
    return n;
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    tlm::tlm_generic_payload gp;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(4);
    gp.set_data_ptr(buf);
    gp.set_data_length(8);
    unsigned int n = socket->transport_dbg(gp);
    cout << "n=" << n << " buf=" << std::hex;
    for (int i = 0; i < 8; ++i) cout << (int)buf[i] << " ";
    cout << std::dec << endl;
  }
};
int sc_main(int, char**) {
  Init i("i");
  Mem m("m");
  i.socket.bind(m.socket);
  sc_start();
  return 0;
}
```

輸出是？（`n` 是十進位，buf 是十六進位）

- A. `n=8 buf=14 15 16 17 18 19 1a 1b`
- B. `n=4 buf=14 15 16 17 0 0 0 0`
- C. `n=0 buf=0 0 0 0 0 0 0 0`
- D. `n=8 buf=14 15 16 17 0 0 0 0`

<details>
<summary>答案</summary>

**B。** 要求從位址 4 讀 8 byte，但記憶體只有 8 byte，所以 target 只能搬 4 byte，回傳 4。`buf` 的前 4 格拿到 `0x14`–`0x17`，後 4 格沒被碰過，還是 0。這是部分搬移，`transport_dbg` 的回傳值就是用來判斷這件事的（`tlm_fw_bw_ifs.h`：回傳值必須 ≤ 要求的 byte 數）。

```
n=4 buf=14 15 16 17 0 0 0 0
```

</details>

---

#### MC46：主機的 byte 順序〔L2〕

```cpp
#include <cstdint>
int sc_main(int, char**) {
  uint32_t v = 0x11223344;
  unsigned char b[4];
  memcpy(b, &v, 4);
  cout << std::hex << (int)b[0] << " " << (int)b[3] << endl;
  return 0;
}
```

兩個數字（十六進位）是？（以 x86-64 Linux 主機為準）

- A. `11 44`
- B. `44 11`
- C. `11 22`
- D. `44 44`

<details>
<summary>答案</summary>

**B。** x86-64 是 little endian，最低位元組 `0x44` 放在最前面，最高位元組 `0x11` 放在最後。這個結果取決於主機：在 big endian 主機上會是 `11 44`。`transport_dbg` 的 data 用的就是這個 host 順序，所以寫 debugger 時不能假設 `buf[0]` 是最低位元組（T9）。

```
44 11
```

</details>

---

#### MC47：DMI 提示與 `get_direct_mem_ptr` 的失敗〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") { socket.register_b_transport(this, &Target::b_transport); }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    *gp.get_data_ptr() = 7;
    gp.set_dmi_allowed(true);
    delay += sc_time(10, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[1];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(1);
    socket->b_transport(gp, delay);
    cout << "hint=" << gp.is_dmi_allowed() << endl;
    tlm::tlm_dmi dmi;
    bool ok = socket->get_direct_mem_ptr(gp, dmi);
    cout << "get=" << ok << " ptr_null=" << (dmi.get_dmi_ptr() == 0) << " access=" << dmi.get_granted_access() << endl;
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

兩行輸出是？（`access` 以整數印出）

- A. `hint=0`、`get=1 ptr_null=0 access=3`
- B. `hint=1`、`get=1 ptr_null=0 access=1`
- C. `hint=1`、`get=0 ptr_null=1 access=3`
- D. `hint=1`、`get=0 ptr_null=1 access=0`

<details>
<summary>答案</summary>

**C。** 提示是 1，但 target 沒有註冊 `get_direct_mem_ptr` callback，所以 socket 的預設 fallback 執行：把 `dmi` 設成「整個範圍、可讀寫」（`allow_read_write()`，access = 3），然後回傳 false（`simple_target_socket.h:363-366`）。所以 `access=3` 不代表可以用 DMI，**只能看回傳的 bool**。

```
hint=1
get=0 ptr_null=1 access=3
```

關於規範：`tlm_fw_bw_ifs.h` 要求的是「若 DMI 會成功，target 必須把提示設成 true」；沒有禁止「提示是 true 但 DMI 失敗」。所以這個 target 不算違規，只是 initiator 會白試一次。

</details>

---

#### MC48：`transport_dbg` 裡呼叫 `wait()`〔L3〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  SC_CTOR(Target) : socket("socket") { socket.register_transport_dbg(this, &Target::dbg); }
  unsigned int dbg(tlm::tlm_generic_payload&) {
    wait(1, SC_NS);
    return 0;
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void run() {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(0);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    unsigned int n = socket->transport_dbg(gp);
    cout << "n=" << n << " now=" << sc_time_stamp() << endl;
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

- A. `n=0 now=0 s`
- B. `n=0 now=1 ns`
- C. 執行期錯誤：`transport_dbg` 裡不能 `wait`，模擬中止
- D. 編譯錯誤：debug callback 不能有 `wait`

<details>
<summary>答案</summary>

**B。** 呼叫端是 `SC_THREAD`，所以 `wait` 合法，socket 也不檢查，時間照樣前進到 1 ns。這是違反規範的寫法：`tlm_fw_bw_ifs.h` 的 transport_dbg 註解寫明 debug 存取不能 `wait`、不能 notify、不能讓模擬時間前進。2.3.3 不會替你檢查，所以程式不會報錯，錯誤要靠 code review 找。（如果呼叫端是 `SC_METHOD`，這份題庫沒有實跑。）

```
n=0 now=1 ns
```

</details>

---

#### MC49：router 的位址還原與錯誤回應〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  std::string name;
  SC_CTOR(Target) : socket("socket") { socket.register_b_transport(this, &Target::b_transport); }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    cout << "  " << name << " sees addr=0x" << std::hex << gp.get_address() << std::dec << endl;
    delay += sc_time(5, SC_NS);
    gp.set_response_status(tlm::TLM_OK_RESPONSE);
  }
};
struct Router : sc_module {
  tlm_utils::simple_target_socket<Router> in;
  tlm_utils::simple_initiator_socket<Router> out0, out1;
  SC_CTOR(Router) : in("in"), out0("out0"), out1("out1") {
    in.register_b_transport(this, &Router::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    sc_dt::uint64 a = gp.get_address();
    if (a < 0x1000) {
      out0->b_transport(gp, delay);
    } else if (a < 0x2000) {
      gp.set_address(a - 0x1000);
      out1->b_transport(gp, delay);
      gp.set_address(a);
    } else {
      gp.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
    }
  }
};
struct Init : sc_module {
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void issue(sc_dt::uint64 a) {
    unsigned char buf[4];
    tlm::tlm_generic_payload gp;
    sc_time delay = SC_ZERO_TIME;
    gp.set_command(tlm::TLM_READ_COMMAND);
    gp.set_address(a);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "init addr=0x" << std::hex << a << std::dec << " status=" << gp.get_response_string()
         << " delay=" << delay << endl;
  }
  void run() {
    issue(0x0004);
    issue(0x1004);
    issue(0x3000);
  }
};
int sc_main(int, char**) {
  Init i("i");
  Router r("r");
  Target t0("t0"), t1("t1");
  t0.name = "t0"; t1.name = "t1";
  i.socket.bind(r.in);
  r.out0.bind(t0.socket);
  r.out1.bind(t1.socket);
  sc_start();
  return 0;
}
```

輸出是？（`0x4` 送給 t0；`0x1004` 送給 t1；`0x3000` 不屬於任何 target）

- A. 和正確答案相同，但 t1 看到的是 `addr=0x1004`（router 沒有扣 base）
- B. `  t0 sees addr=0x4`、`init addr=0x4 status=TLM_OK_RESPONSE delay=5 ns`、`  t1 sees addr=0x4`、`init addr=0x1004 status=TLM_OK_RESPONSE delay=5 ns`、`init addr=0x3000 status=TLM_ADDRESS_ERROR_RESPONSE delay=0 s`
- C. 和正確答案相同，但最後一行是 `status=TLM_GENERIC_ERROR_RESPONSE`
- D. 和正確答案相同，但 `0x3000` 那行的 delay 是 `5 ns`（router 也會把 target 的延遲算進去）

<details>
<summary>答案</summary>

**B。** router 把 `0x1004` 扣掉 base `0x1000` 再送給 t1，所以 t1 看到 `0x4`；回來時還原成 `0x1004`，initiator 看到的仍是原值。`0x3000` 沒有 target 負責，router 直接回 `TLM_ADDRESS_ERROR_RESPONSE`，**不轉送**，所以 delay 還是 0（只有 target 加了 5 ns）。

```
  t0 sees addr=0x4
init addr=0x4 status=TLM_OK_RESPONSE delay=5 ns
  t1 sees addr=0x4
init addr=0x1004 status=TLM_OK_RESPONSE delay=5 ns
init addr=0x3000 status=TLM_ADDRESS_ERROR_RESPONSE delay=0 s
```

這個 router 沒有加自己的解碼延遲，E1 的參考寫法會加 2 ns（那題的規格）。

</details>

---

#### MC50：tagged socket 的 `id`〔L2〕

```cpp
struct Target : sc_module {
  tlm_utils::simple_target_socket_tagged<Target> socket;
  SC_CTOR(Target) : socket("socket") { socket.register_b_transport(this, &Target::b_transport, 7); }
  void b_transport(int id, tlm::tlm_generic_payload& gp, sc_time&) {
    cout << "id=" << id << " addr=0x" << std::hex << gp.get_address() << std::dec << endl;
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
    gp.set_address(0x20);
    gp.set_data_ptr(buf);
    gp.set_data_length(4);
    socket->b_transport(gp, delay);
    cout << "status=" << gp.get_response_string() << endl;
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

- A. `id=0 addr=0x20`、`status=TLM_OK_RESPONSE`
- B. `id=7 addr=0x20`、`status=TLM_OK_RESPONSE`
- C. `id=1 addr=0x20`、`status=TLM_OK_RESPONSE`
- D. 編譯錯誤：tagged socket 不能註冊 `b_transport`

<details>
<summary>答案</summary>

**B。** tagged socket 的 `id` 是你在 `register_b_transport(..., id)` 時給的值，這裡是 7。multi socket（MC16）的 `id` 則是綁定順序，兩者不要混為一談。

```
id=7 addr=0x20
status=TLM_OK_RESPONSE
```

</details>

---

#### MC51：覆寫 `compute_local_quantum`〔L2〕

```cpp
struct MyKeeper : tlm_utils::tlm_quantumkeeper {
  sc_time compute_local_quantum() { return sc_time(30, SC_NS); }
};
SC_MODULE(M) {
  MyKeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    qk.inc(sc_time(20, SC_NS));
    cout << "after 20 ns need_sync=" << qk.need_sync() << endl;
    qk.inc(sc_time(10, SC_NS));
    cout << "after 30 ns need_sync=" << qk.need_sync() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns。）兩行輸出是？

- A. `after 20 ns need_sync=0`、`after 30 ns need_sync=0`
- B. `after 20 ns need_sync=0`、`after 30 ns need_sync=1`
- C. `after 20 ns need_sync=1`、`after 30 ns need_sync=1`
- D. 編譯錯誤：`compute_local_quantum` 不是 virtual，無法覆寫

<details>
<summary>答案</summary>

**B。** `compute_local_quantum()` 是 virtual（`tlm_quantumkeeper.h:160`），`reset()` 呼叫它來算下一個同步點。這個子類覆寫之後，quantum 是 30 ns，不是全域的 100 ns。這就是 Q3 第 3 題說的「每個 initiator 用不同的 quantum」的寫法。

```
after 20 ns need_sync=0
after 30 ns need_sync=1
```

</details>

---

#### MC52：同步點是絕對時間〔L3〕

```cpp
SC_MODULE(M) {
  tlm_utils::tlm_quantumkeeper qk;
  SC_CTOR(M) { SC_THREAD(run); }
  void run() {
    qk.reset();
    wait(90, SC_NS);
    qk.inc(sc_time(9, SC_NS));
    cout << "now=" << sc_time_stamp() << " local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
    qk.inc(sc_time(1, SC_NS));
    cout << "now=" << sc_time_stamp() << " local=" << qk.get_local_time() << " need_sync=" << qk.need_sync() << endl;
  }
};
int sc_main(int, char**) {
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  M m("m");
  sc_start();
  return 0;
}
```

（全域 quantum 設為 100 ns，`reset()` 在 0 ns 呼叫。）兩行輸出是？

- A. `now=90 ns local=9 ns need_sync=0`、`now=90 ns local=10 ns need_sync=0`
- B. `now=90 ns local=9 ns need_sync=0`、`now=90 ns local=10 ns need_sync=1`
- C. `now=90 ns local=9 ns need_sync=1`、`now=90 ns local=10 ns need_sync=1`
- D. `now=90 ns local=9 ns need_sync=0`、`now=90 ns local=10 ns need_sync=0`（因為 `reset` 之後下一個同步點是 190 ns）

<details>
<summary>答案</summary>

**B。** 同步點是 `reset()` 那時算好的**絕對時間**：100 ns。中途 `wait` 不會把它往後推。所以在 90 ns 時 local 加到 10 ns，`90 + 10 >= 100`，就需要 sync。常見的誤解是以為 `wait` 之後要重新 `reset()` 才會往後推，或以為同步點是「現在 + quantum」。

```
now=90 ns local=9 ns need_sync=0
now=90 ns local=10 ns need_sync=1
```

</details>

---

#### MC53：payload 解構時，掛著的堆疊 extension〔L3〕

```cpp
struct Tag : tlm::tlm_extension<Tag> {
  int value = 0;
  tlm::tlm_extension_base* clone() const { return new Tag(*this); }
  void copy_from(const tlm::tlm_extension_base& e) { value = static_cast<const Tag&>(e).value; }
};
void f() {
  Tag tag; tag.value = 5;
  tlm::tlm_generic_payload gp;
  gp.set_extension(&tag);
  cout << "leaving f() with extension still attached" << endl;
}
int sc_main(int, char**) {
  f();
  cout << "main continues" << endl;
  return 0;
}
```

輸出是？

- A. `leaving f() with extension still attached`，然後 `main continues`，正常結束
- B. `leaving f() with extension still attached`，之後程式異常終止（SIGSEGV 或 SIGABRT，依執行而異），`main continues` 不會出現
- C. 編譯錯誤：`tlm_extension` 不能放在堆疊上
- D. 只有警告，`main continues` 會出現

<details>
<summary>答案</summary>

**B。** `gp` 先於 `tag` 被解構（反向宣告順序），`~tlm_generic_payload` 會對每個非空的 extension 呼叫 `free()`；預設的 `tlm_extension_base::free()` 是 `delete this`（`tlm_gp.h:60`）。於是堆疊上的 `tag` 被 `delete`，這是未定義行為。本機重複執行的結果不固定：有時 SIGSEGV（exit 139），有時 SIGABRT（exit 134，glibc 印出 `double free or corruption` 或 `free(): invalid size` 之類的訊息）。所以不要把某一種結果當成固定輸出，重點是「這樣寫就是錯的」。

```
leaving f() with extension still attached
```

（之後程式異常終止；stdout 只到這一行，`main continues` 不會出現。）

修法：離開 scope 前呼叫 `clear_extension<Tag>()`（MC14 的寫法），或改用 heap 上的 extension 並搭配 memory manager（`set_auto_extension`）。

</details>

---

### 選擇題驗證紀錄（2026-10-21）

- 環境：本機 SystemC 2.3.3，`g++ -std=c++11`（見上方指令）。
- 方式：寫完後用腳本從這份檔案抽出每題的程式碼，補上開頭那幾行，實際編譯執行，再把輸出逐行與答案裡的輸出區塊比對，MC1–MC22 全部一致（MC23–MC36 見下一段）。
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
- AT 專題（MC23–MC36，2026-10-21 補）：同樣用腳本抽出程式碼、補開頭（多了 `peq_with_get.h`、`peq_with_cb_and_phase.h`）、編譯執行，輸出與答案逐行比對一致。MC23–MC36 另有以下原始碼核對：
  - MC23、MC25：`tlm_phase.h`／`tlm_phase.cpp`（phase 列舉值、`tlm_phase` 轉 `unsigned`、`operator<<`、extended phase 註冊從 5 開始）。
  - MC24：`tlm_fw_bw_ifs.h` 的 `tlm_sync_enum` 數值。
  - MC26、MC34：`examples/tlm/common/src/at_target_4_phase.cpp`（fw 收到 `END_REQ`／`BEGIN_RESP` 為 fatal；對 backward 呼叫回傳值的處理）與 `at_target_1_phase_dmi.cpp`（`TLM_UPDATED` + `END_REQ` 的 return-path 寫法）；`simple_target_socket.h` 的 `nb_transport_fw`（nb→b 路徑只接受 `BEGIN_REQ`／`END_RESP`）。
  - MC28、MC36：`simple_target_socket.h` 的 `nb2b_thread`（spawn thread、呼叫 `b_transport`、`wait(delay)`、回送 `BEGIN_RESP`、`m_response_in_progress` 與 `m_end_response`）。
  - MC29、MC31：`peq_with_get.h`（`std::multimap`、`get_next_transaction` 只回已到期並重新排事件）。
  - MC30、MC32：`peq_with_cb_and_phase.h`（`time_ordered_list::insert` 的 `<=` 規則、`fec()` 的 immediate → delta → timed 順序、delta 清單依 delta 計數奇偶分兩個）。
  - MC33：範例 `examples/tlm/at_ooo`（out-of-order AT）。
  - MC35：2.3.3 未附 protocol checker（在 `src`、`include`、`examples` 搜尋 `checker`，只有 `examples/tlm/common/src/lt_dmi_initiator.cpp` 一則註解提到 "TLM2.0 checker"，沒有 checker 元件）。
  - 未核對 IEEE 1666 標準原文：phase 的方向規則、ignorable phase、`TLM_ACCEPTED`／`TLM_UPDATED`／`TLM_COMPLETED` 的合法組合、「請求通道一次只接受一筆」等，都是依範例與本機實跑，標準條文沒有查（題目內有逐處註明）。
- 沒有核對 IEEE 1666 標準原文（本機沒有）：MC17、MC18 的 `TLM_ACCEPTED`／`TLM_UPDATED`／`TLM_COMPLETED` 語意、MC7 的「bus 在返回前還原位址」只是範例 bus 的寫法，當成建議慣例，不是標準或原始碼規定，都是依本機實跑，標準條文沒有查；MC21 的 DMI 作廢語意只對照到先前核對過的 `tlm_fw_bw_ifs.h` 註解（見文末核對紀錄）。

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
- simple、passthrough、multi_passthrough 這幾種 target socket，沒有註冊的 callback 時，`get_direct_mem_ptr` 都回傳 `false`（不給 DMI），`transport_dbg` 都回傳 `0`（不支援 debug 存取）。initiator 要能處理這兩種結果。
- 但 `b_transport` 的預設行為**不同**：只註冊 `nb_transport_fw` 時，simple 會自動做 nb→b 轉換；passthrough 和 multi 不做轉換，被呼叫時會報 SC_REPORT_ERROR（預設 action 是 throw）。
- simple 或 passthrough target socket 如果 `b_transport` 和 `nb_transport_fw` 都沒註冊，收到 transaction 時會報錯（SC_REPORT_ERROR）。multi socket 連一個 callback 都沒註冊時，不會等到 transaction：sc_start 的 binding 檢查就會報 E109（export not bound）。

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
- **陷阱**：`tlm_generic_payload` 建構時 streaming width 預設是 **0**，不會自動等於 data length。initiator 忘了設的話，像 SystemC 範例裡的 memory target 檢查 `streaming_width != data_length` 就會回 `TLM_BURST_ERROR_RESPONSE`。SystemC 2.3.3 範例中只有兩個檔案呼叫 `set_streaming_width`：`examples/tlm/lt_extension_mandatory/src/lt_initiator_extension_mandatory.cpp`（寫 `trans.set_streaming_width(trans.get_data_length())`）與 `examples/tlm/lt_mixed_endian/src/me_traffic_generator.cpp`（寫 `len * sizeof(T)`，同樣等於 data length）。其他會設定 command／address 的檔案（`SimpleBusLT.h`、`SimpleBusAT.h` 是轉送 bus，`lt_dmi_initiator.cpp` 只改 address 與 `set_dmi_allowed`）都沒有設定 data length 或 streaming width，所以不能說「範例的 initiator 都會設」。
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
- 放回 pool 前通常呼叫 `reset()`。它只釋放由 `set_auto_extension` 掛上、交給 mm 管理的 extension；用 `set_extension` 手動掛的指標不會被清掉（要自己 `clear_extension`）。command、address、data length、response status 也都保留，下一次使用前要自己重新設定（MC39、事實修正 5）。
- 只用 `b_transport` 時，transaction 在函式 return 時就結束，initiator 可以把 payload 放在 stack 或成員變數上重複使用，所以常常不需要 memory manager。
- AT 的 payload 在 `nb_transport_fw` return 之後還會繼續在其他元件間傳遞，可能同時有好幾筆在進行中，所以需要用 reference counting 確定沒有人在用了才能釋放。

</details>

**上次的弱點：** 尚未考過。

---

## Q9：Payload 所有權與 AT pool〔L2〕

1. AT 的 initiator 把 payload 放在哪裡？為什麼不能像 LT 那樣直接放在函式的堆疊上？
2. 用 memory manager 時，`free()` 通常做哪兩件事？`reset()` 清掉什麼、沒清掉什麼？
3. 具體 bug：target 把 payload 指標存下來，等下一個 phase 才用，但 initiator 已經 `release()` 把它還進 pool。會怎樣？怎麼防？

<details>
<summary>參考答案</summary>

**1.** AT 的 payload 在 `nb_transport_fw` 返回後還會在元件之間傳遞，而且同時可能有好幾筆在進行中，不能綁在某個函式的堆疊上。通常放在 heap，由 memory manager（`tlm_mm_interface`）管理，用 `acquire()` / `release()` 做 reference counting（T1、MC15、MC17）。

**2.** `free()` 通常呼叫 `reset()` 再放回 pool（`ver_pool` 的寫法，見教學導讀 T1）。`reset()` 的實際範圍（事實修正 5、MC39）：

- 會做的：釋放由 `set_auto_extension` 掛上、交給 mm 管理的 extension；把 `m_gp_option` 設回預設。
- 不會做的：command、address、data length、response status 都保留；用 `set_extension` 手動掛的 extension 指標也保留。

所以 pool 的 `free()` 只呼叫 `reset()` 還不夠：下一次使用前要把欄位全部重新設定，手動掛的 extension 要自己清。

**3.** 這是懸空指標（dangling pointer），結果是未定義行為：讀到別人的資料、寫壞別人的 payload，或直接 crash。防法有兩種：

- 存指標的一方在存的時候 `acquire()`，用完再 `release()`，計數歸零才會被回收。
- 或讓 pool 的規則保證：payload 只在 `END_RESP` 之後才能回收（這是協定層的約定，不是 SystemC 自動保證的）。

連結：MC17 的第一版 initiator 太早離開，就是同類的問題（只是堆疊版本，會 segfault）。

</details>

**上次的弱點：** 尚未考過。

---

## Q10：Socket 選擇與 bus 接線〔L2〕

1. 一個 CPU（initiator）透過 bus 接兩個 memory。bus 的上游與下游各用哪種 socket？`passthrough` 和 `simple` 的差別是什麼？
2. 一個 IP 有兩條 DMA 通道，各自是一個 initiator socket，都要接到同一個 module 的 target 側。要區分來源，你會用 tagged 還是 multi？為什麼？`id` 是誰決定的？
3. `passthrough` 在 bus 裡為什麼不做 b / nb 轉換？如果 bus 上游只註冊了 nb，LT initiator 呼叫時會怎樣？

<details>
<summary>參考答案</summary>

**1.** 2.3.3 的範例 bus `examples/tlm/common/include/models/SimpleBusLT.h` 用的是 `simple_target_socket_tagged` 陣列（每個 initiator 一個 socket，`register_b_transport(this, ..., i)` 的 `i` 是索引，見第 36–51 行），下游是 `simple_initiator_socket_tagged` 陣列。`passthrough_target_socket` 是另一種選擇。兩者的差別在轉換行為：simple 會自動做 b / nb 轉換（MC13、MC28）；passthrough 不做轉換，缺少的 callback 會直接報 `SC_REPORT_ERROR`（事實修正 1）。

**2.** 用 **tagged**，而且要讓每個來源有自己的 target socket：tagged socket 只能 bind 一次（第二次 bind 報 E109，本機實跑），所以兩條 DMA 通道各自接一個 socket，註冊時給不同的 id（MC50）。如果你想要的是「同一個 socket 接兩條通道」，那是 **multi**：它可以多次 bind，callback 的 `id` 是綁定順序（MC16），不要依賴它對應到特定的 initiator 名字。

**3.** passthrough 只轉送、不翻譯：bus 註冊哪一種 callback，就只會收到那一種呼叫。上游 LT 呼叫 bus 的 `b_transport`，bus 也用 `b_transport` 往下送；下游 target 如果只實作 nb，轉換由**下游 target 的 simple socket** 負責（MC13 的寫法），bus 不用管。反過來，如果 bus 上游只註冊了 nb，LT initiator 呼叫 `b_transport` 時會報 `SC_REPORT_ERROR`（事實修正 1），不會被悄悄轉換。

</details>

**上次的弱點：** 尚未考過。

---

## Q11：Quantum keeper 的迴圈與 `need_sync`〔L3〕

1. 寫出 LT initiator 的存取迴圈（5–10 行偽碼或 C++）：每次存取怎麼把 delay 交給 target、什麼時候 sync、sync 後做什麼。
2. `need_sync()` 的判斷式是什麼？為什麼 `next_sync_point` 是絕對時間？
3. 全域 quantum 改成 10 ns 之後，既有的 keeper 什麼時候才會用新值？

<details>
<summary>參考答案</summary>

**1.** 參考教學導讀 T3 的程式（已實跑，輸出 `syncs=2 now=100 ns local=0 s`）。骨架是：

```
qk.reset()                                  // thread 開頭
loop:
  d = qk.get_local_time()                   // 把目前領先的時間傳進去
  socket->b_transport(gp, d)                // target 會把自己的延遲加進 d
  qk.set(d)                                 // 把加完的時間寫回 keeper
  if qk.need_sync(): qk.sync(); (sync 內部會 reset)
```

重點：`d` 是副本，忘了 `qk.set(d)` 的話 target 加的延遲會丟掉。

**2.** `sc_time_stamp() + local >= next_sync_point`（`tlm_quantumkeeper.h`，`need_sync()`），是 `>=`（MC43）。`next_sync_point` 在 `reset()` 時算成絕對時間（現在 + quantum），中間 `wait` 不會更新它（MC52）。這樣才能讓同步點對齊到全域時間的整數倍（MC10）。

**3.** 要等下一次 `reset()` 或 `sync()`，因為 `compute_local_quantum()` 只在那時被呼叫（MC44）。在那之前 `need_sync` 還是用舊的同步點判斷。

</details>

**上次的弱點：** 尚未考過。

---

## Q12：DMI 的權限、範圍與失敗〔L3〕

1. target 只給 READ 權限的 DMI，initiator 想寫入怎麼辦？
2. `get_direct_mem_ptr` 回傳 false 時，`dmi` 物件裡的範圍與權限是什麼？initiator 該看哪個值？
3. 作廢只涵蓋一小段範圍，但 initiator 手上有一個跨越那段範圍的 DMI 區塊。依規範要怎麼處理？

<details>
<summary>參考答案</summary>

**1.** 只能用 `b_transport` 寫。`dmi.is_write_allowed()` 是 false 時，initiator 不能直接寫入指標（MC37 的權限位元）。granted access 的意思是「target 允許的存取種類」，不是「你可以忽略 transport」。

**2.** 回傳 false 時，`dmi` 的內容由 target 或 socket 的 fallback 決定。預設的 simple socket 會把範圍設成整個位址空間、權限設成 READ_WRITE（MC47 的 `access=3`），但回傳值是 false。所以**只看回傳的 bool**，不要看 access 位元。

**3.** 規範（`tlm_fw_bw_ifs.h`）的要求是：initiator 必須丟掉指向被作廢區域的 DMI 指標。建議（不是強制）是把所有與作廢範圍有重疊的 DMI 區域都丟掉，所以只保留沒有重疊的部分也可以。interconnect 還要把位址範圍轉成 initiator 的全域位址，並廣播給所有可能拿著指標的 initiator。

</details>

**上次的弱點：** 尚未考過。

---

## Q13：Router 與 address map〔L2〕

1. 一個 router 接一個 CPU、兩個 target：ROM 在 0x0000–0x0FFF，RAM 在 0x1000–0x1FFF。decode 有哪三種結果？各自怎麼處理 payload 與 delay？
2. 一筆 4-byte 讀取從 0x0FFE 開始，跨進 ROM 和 RAM 的邊界。你的 router 怎麼辦？標準規定什麼？
3. 每一層的 delay 怎麼累加？router 自己的 decode 成本要不要加？

<details>
<summary>參考答案</summary>

**1.** 三種結果：

- 轉送到 ROM（ROM 的 base 是 0，本地位址就是全域位址）。
- 轉送到 RAM：位址先扣掉 0x1000，回來時改回原值（MC49）。
- 沒有對應的 target：直接回 `TLM_ADDRESS_ERROR_RESPONSE`，不轉送，也不加 target 的延遲（MC49 第三行）。

**2.** 標準沒有規定跨邊界的交易要怎麼處理，這是實作選擇（Q6 第 4 題）。常見做法有兩種：直接對整筆交易回 `TLM_ADDRESS_ERROR_RESPONSE`；或把它拆成兩筆交易，分別送到兩個 target（拆開時要自己處理第二段的位址與 payload）。`b_transport` 沒有「回傳部分長度」的規範；只有 `transport_dbg` 的回傳值才有部分搬移的語意（MC45）。要在 router 的文件裡寫清楚。

**3.** 每層都把自己的延遲加進同一個 `delay`，只有最後的 initiator 決定何時 `wait`（MC7）。router 的 decode 成本也要加，這是模型的一部分；E1 的規格就是每筆交易先加 2 ns。

</details>

**上次的弱點：** 尚未考過。

---

## Q14：AT 的提前完成與回傳路徑〔L3〕（對應下一輪清單第 1、2 條）

1. 不看筆記，畫出一筆 AT READ 的四個 phase 時序：每一步是 fw 還是 bw、回傳哪個 `tlm_sync_enum`、payload 的 response status 在哪一步變成 OK。
2. 什麼樣的 target 會直接回 `TLM_COMPLETED`？它的理由是什麼？
3. target 回了 `TLM_ACCEPTED`，initiator 之後的責任是什麼？

<details>
<summary>參考答案</summary>

**1.** 以 MC26 的實跑結果為準（時間是 SystemC 的模擬時間）：

```
fw BEGIN_REQ  @0 ns   -> TLM_ACCEPTED     initiator 送出請求
bw END_REQ    @5 ns   -> TLM_ACCEPTED     target 說「請求已接受」
bw BEGIN_RESP @15 ns  -> TLM_ACCEPTED     target 說「回應開始」，status 在這之前已設好（MC26 的寫法）
fw END_RESP   @17 ns  -> TLM_COMPLETED    initiator 確認收完，交易結束
```

規則：BEGIN_REQ 與 END_RESP 走 fw；END_REQ 與 BEGIN_RESP 走 bw（MC26）。response status 在 BEGIN_RESP 之前就要設好（MC26 的 target 在 `BEGIN_RESP` 前設 OK）。

**2.** 沒有 timing 需求、可以在第一次呼叫裡就把結果寫好的 target，例如暫存器、單純的 memory，會直接回 `TLM_COMPLETED`（MC18）。理由是省掉整個四 phase 握手，只剩一次函式呼叫。代價是 target 不能在這之後才回應，所以延遲要用 `delay` 參數加進來，而不是等。另一種提前完成是 MC17 與 MC34 的寫法：target 在 BEGIN_REQ 的回程就用 `TLM_UPDATED` + `END_REQ`，之後 initiator 對 BEGIN_RESP 回 `TLM_COMPLETED`。

**3.** `TLM_ACCEPTED` 的意思是「我還在處理」。對 `BEGIN_RESP` 回 `TLM_ACCEPTED`，就必須之後送出 `END_RESP`；否則下一筆回應永遠送不出，模擬也不會報錯（MC36）。initiator 對 `END_REQ` 回 `TLM_ACCEPTED`，意思是「收到了、phase 不改」（MC26 第二行），不代表回應已經到了。

</details>

**上次的弱點：** 尚未考過。

---

## Q15：Payload event queue（PEQ）的取出規則〔L3〕（對應下一輪清單第 1 條的 AT 部分）

1. `peq_with_get` 和 `peq_with_cb_and_phase` 差在哪裡？各適合哪一種 model？
2. 為什麼 `peq_with_get` 的 consumer 要用 `while (get_next_transaction())` 把到期的全部取完？
3. 兩個項目到期時間相同，取出順序由什麼決定？

<details>
<summary>參考答案</summary>

**1.** `peq_with_get` 是 pull：consumer 在自己的 thread 裡 `wait(get_event())`，再用 `get_next_transaction()` 取。適合 consumer 本來就是 thread、想自己控制節奏的 model。`peq_with_cb_and_phase` 是 push：到期時會呼叫你登記的 callback（以 `SC_METHOD` 執行），並同時帶著 phase。適合 target 用 callback 方式寫的 AT model。

**2.** `get_event()` 只通知「有東西到期了」，不會每個項目都通知一次。如果只取一次，同時到期的其他項目會一直留在佇列裡，直到下一次通知（MC31 的 `c` 與 `a` 永遠沒被送出，模擬也不會報錯）。所以要用 `while` 取到回傳 0 為止。

**3.** 時間早的先出。時間相同的，依通知（插入）順序出：`peq_with_get` 用 `multimap`（MC29），`peq_with_cb_and_phase` 的插入規則是新項目放在所有「時間 `<=` 它」的項目後面（MC30）。兩者在同一個時間點內都維持通知順序（MC29、MC30）。

</details>

**上次的弱點：** 尚未考過。

---

## 手寫練習（只給規格與骨架，解答不附在這裡）

這一段是給 Alan 自己寫的。骨架可以直接編譯（未實作時會印出 INCOMPLETE 或 0，代表還沒寫完）。寫完先自己跑，再把程式貼過來做 review。**不要直接複製提示裡的程式碼以外的東西**，先看規格。

### E1：Router + 兩個 memory target〔L2〕

**規格**

- Router 有 1 個上游 target socket（`up`）與 2 個下游 initiator socket（`rom`、`ram`）。
- ROM 負責 0x0000–0x0FFF，本地位址等於全域位址。
- RAM 負責 0x1000–0x1FFF，本地位址是全域位址減 0x1000。
- 其他位址回 `TLM_ADDRESS_ERROR_RESPONSE`，不轉送。
- Router 每筆交易先加 2 ns（decode 成本），不論是否轉送。
- 送到 RAM 時位址要改成本地 offset，回來時要改回原值。
- Memory 的規則：超出 4096 byte 的範圍回 `TLM_ADDRESS_ERROR_RESPONSE`；ROM 是唯讀，寫入回 `TLM_COMMAND_ERROR_RESPONSE`。正常的讀寫把自己的延遲加進 `delay`（讀 10 ns、寫 5 ns）。**錯誤回應（超出範圍或唯讀寫入）不加 memory 的延遲**，只有 router 的 2 ns。

**骨架**（harness 與 Memory 已給，Router 的 `b_transport` 與 Memory 的 `b_transport` 內容請自己寫）

```cpp
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <cstring>
using namespace sc_core;
using std::cout;
using std::endl;

struct Memory : sc_module {                      // 已給建構子，b_transport 你來寫
  tlm_utils::simple_target_socket<Memory> socket;
  unsigned char store[4096];
  bool read_only;
  sc_time read_lat, write_lat;
  Memory(sc_module_name n, bool ro, sc_time rl, sc_time wl)
    : sc_module(n), socket("socket"), read_only(ro), read_lat(rl), write_lat(wl) {
    memset(store, 0, sizeof store);
    socket.register_b_transport(this, &Memory::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    // TODO：依規格檢查範圍、唯讀、做讀寫、累加延遲、設定 response status
  }
};

struct Router : sc_module {                      // 你來寫
  tlm_utils::simple_target_socket<Router> up;
  tlm_utils::simple_initiator_socket<Router> ram, rom;
  SC_CTOR(Router) : up("up"), ram("ram"), rom("rom") {
    up.register_b_transport(this, &Router::b_transport);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    // TODO：加 decode 延遲；依全域位址選 rom / ram / 錯誤；RAM 的位址要扣掉 base 再還原
  }
};

struct Init : sc_module {                        // 已給，不要改
  tlm_utils::simple_initiator_socket<Init> socket;
  SC_CTOR(Init) : socket("socket") { SC_THREAD(run); }
  void go(const char* label, tlm::tlm_command c, sc_dt::uint64 a, unsigned char* buf) {
    tlm::tlm_generic_payload gp;
    sc_time d = SC_ZERO_TIME;
    gp.set_command(c); gp.set_address(a); gp.set_data_ptr(buf); gp.set_data_length(4);
    socket->b_transport(gp, d);
    cout << label << ": " << gp.get_response_string() << " delay=" << d
         << " addr=0x" << std::hex << gp.get_address() << std::dec
         << " data=" << (int)buf[0] << (int)buf[3] << endl;
  }
  void run() {
    unsigned char b[4] = {1, 2, 3, 4}, r[4] = {0, 0, 0, 0};
    go("W ram 0x1010", tlm::TLM_WRITE_COMMAND, 0x1010, b);
    go("R ram 0x1010", tlm::TLM_READ_COMMAND, 0x1010, r);
    go("W rom 0x0010", tlm::TLM_WRITE_COMMAND, 0x0010, b);
    go("R rom 0x0010", tlm::TLM_READ_COMMAND, 0x0010, r);
    go("R 0x2000", tlm::TLM_READ_COMMAND, 0x2000, r);
  }
};

int sc_main(int, char**) {                       // 已給，不要改
  Init i("i");
  Router rt("rt");
  Memory ram("ram", false, sc_time(10, SC_NS), sc_time(5, SC_NS));
  Memory rom("rom", true, sc_time(10, SC_NS), sc_time(5, SC_NS));
  i.socket.bind(rt.up);
  rt.ram.bind(ram.socket);
  rt.rom.bind(rom.socket);
  sc_start();
  return 0;
}
```

**期望輸出**（五行，全部符合才算通過）

```
W ram 0x1010: TLM_OK_RESPONSE delay=7 ns addr=0x1010 data=14
R ram 0x1010: TLM_OK_RESPONSE delay=12 ns addr=0x1010 data=14
W rom 0x0010: TLM_COMMAND_ERROR_RESPONSE delay=2 ns addr=0x10 data=14
R rom 0x0010: TLM_OK_RESPONSE delay=12 ns addr=0x10 data=00
R 0x2000: TLM_ADDRESS_ERROR_RESPONSE delay=2 ns addr=0x2000 data=00
```

（以上期望輸出是用一份自己寫的參考實作跑出來的，該實作**不附在這裡**。）

**提示**（一次只開一個）

<details>
<summary>提示 1：Router 的位址判斷</summary>

先用 `gp.get_address()` 讀全域位址，判斷落在哪個範圍。只有需要轉送時才改位址。回來時的還原要在 `b_transport` 返回前做。

</details>

<details>
<summary>提示 2：Memory 的範圍檢查</summary>

檢查的是「位址 + 長度」是否超過 4096，不只是位址。注意 `gp.get_data_length()` 的型別是 unsigned。

</details>

<details>
<summary>提示 3：delay 與 status 的順序</summary>

每一層都是把自己的延遲加進同一個 `delay`。注意錯誤路徑的檢查要放在加延遲之前，否則 `W rom` 那行會多出 5 ns。

</details>

<details>
<summary>提示 4：偵錯方法</summary>

如果某行印出 `TLM_INCOMPLETE_RESPONSE`，代表那條路徑沒有設定 status（MC3）。如果 RAM 的資料不對，先看寫入時位址有沒有扣 base（MC7、T8）。

</details>

**驗收後的延伸**：把 Memory 改成回傳 `TLM_BURST_ERROR_RESPONSE`，當 `gp.get_streaming_width()` 不等於 data length（T6）。

### E2：三種存取方式的模擬時間〔L3〕（對應下一輪清單第 3 條）

**規格**

- Initiator 做 1000 次 4-byte READ，第 i 次（從 0 開始）的位址是 `4 × (i mod 1000)`，都在 4 KB 之內。
- Target 的 `b_transport` 加 10 ns；`get_direct_mem_ptr` 給整塊 4 KB 的指標，READ 權限，讀延遲 5 ns，回傳 true。
- 全域 quantum 設為 100 ns。
- 程式用命令列參數選模式：
  - `0`：每次 `b_transport` 之後都 `wait(delay)`，delay 每次從 `SC_ZERO_TIME` 開始。
  - `1`：用 `tlm_quantumkeeper`。每次 `b_transport` 的 delay 都從 `qk.get_local_time()` 開始，回來後 `qk.set(delay)`，超過 quantum 才 sync。
  - `2`：第一次 `b_transport` 的做法同模式 1（也經過 quantum keeper）；之後用 DMI 直接讀 memory，讀延遲用 `qk.inc()` 加進 quantum keeper。
- 結束時印出 `mode=… end=… waits=… transports=… dmi_reads=…`。`end` 是 `qk.get_current_time()`（模式 0 時和 `sc_time_stamp()` 相同）。`waits` 是每次 `wait` 或 `sync()` 的次數（`sync()` 內含一次 `wait`，算一次）。

**骨架**（Target 與 Cpu 的 TODO 你來寫，sc_main 已給）

```cpp
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/tlm_quantumkeeper.h>
#include <cstring>
#include <cstdlib>
using namespace sc_core;
using std::cout;
using std::endl;
const int N = 1000;

struct Target : sc_module {
  tlm_utils::simple_target_socket<Target> socket;
  unsigned char mem[4096];
  SC_CTOR(Target) : socket("socket") {
    memset(mem, 0x5a, sizeof mem);
    socket.register_b_transport(this, &Target::b_transport);
    socket.register_get_direct_mem_ptr(this, &Target::get_dmi);
  }
  void b_transport(tlm::tlm_generic_payload& gp, sc_time& delay) {
    // TODO：搬資料、加 10 ns、設 OK、DMI 提示設 true
  }
  bool get_dmi(tlm::tlm_generic_payload&, tlm::tlm_dmi& d) {
    // TODO：指標、範圍、READ 權限、讀延遲 5 ns；回傳 true
    return false;
  }
};

struct Cpu : sc_module {
  tlm_utils::simple_initiator_socket<Cpu> socket;
  tlm_utils::tlm_quantumkeeper qk;
  int mode = 0;
  int waits = 0, transports = 0, dmi_reads = 0;
  SC_CTOR(Cpu) : socket("socket") { SC_THREAD(run); }
  void run() {
    // TODO：依 mode 實作三種存取；注意 quantum keeper 要先 reset()
    cout << "mode=" << mode << " end=" << qk.get_current_time()
         << " waits=" << waits << " transports=" << transports
         << " dmi_reads=" << dmi_reads << endl;
  }
};

int sc_main(int argc, char** argv) {             // 已給，不要改
  int m = argc > 1 ? atoi(argv[1]) : 0;
  tlm_utils::tlm_quantumkeeper::set_global_quantum(sc_time(100, SC_NS));
  Cpu c("c");
  Target t("t");
  c.mode = m;
  c.socket.bind(t.socket);
  sc_start();
  return 0;
}
```

**期望輸出**（分別執行 `./e2 0`、`./e2 1`、`./e2 2`）

```
mode=0 end=10 us waits=1000 transports=1000 dmi_reads=0
mode=1 end=10 us waits=100 transports=1000 dmi_reads=0
mode=2 end=5005 ns waits=50 transports=1 dmi_reads=999
```

（同樣是參考實作的輸出，實作不附。）

**提示**（一次只開一個）

<details>
<summary>提示 1：模式 0</summary>

每次 `b_transport` 前把 `delay` 設為 `SC_ZERO_TIME`，之後 `wait(delay)`，並把 `waits` 加 1。注意 `delay` 是 in/out，要用同一個變數接住 target 加的延遲。

</details>

<details>
<summary>提示 2：模式 1 的寫法</summary>

參考教學導讀 T3 的迴圈：`d = qk.get_local_time()`、`b_transport(gp, d)`、`qk.set(d)`、`need_sync` 時 `sync()`。`sync()` 會 `wait`，記得把它算進 `waits`。

</details>

<details>
<summary>提示 3：模式 2 的 DMI</summary>

第一次 `b_transport` 之後用 `get_direct_mem_ptr` 拿 DMI，**檢查回傳的 bool**（MC47）。之後每次讀取做 `memcpy`，然後 `qk.inc(讀延遲)`，檢查 `need_sync`。注意 DMI 讀取沒有經過 `b_transport`，所以 target 的 10 ns 不會再加進來。

</details>

<details>
<summary>提示 4：數字對不上時</summary>

- 模式 1 的 `end` 應該是 10 us（1000 × 10 ns），因為 `end` 用 `get_current_time()`，會把剩餘的 local time 算進去；如果不是，先看有沒有忘了 `reset()`（MC9）。
- 模式 2 的 `end` 應該比 1000 × 10 ns 小很多，因為 DMI 讀只加 5 ns。
- 印出時一定要用 `get_current_time()`，不要用 `sc_time_stamp()`（MC11）。

</details>

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
- Q7：simple target socket 是雙向轉換（原本只寫了 nb 轉 b）；passthrough 和 multi socket 不做 b／nb 轉換，只有 DMI 與 debug 的預設行為和 simple 相同（2026-11-03 已修正，見下方「事實修正」）。
- Q6：bus 跨 target 只轉送第一段是實作選擇，不是標準規定。
- Q4：target 設 DMI hint 是義務；全部作廢用 `0` 到 `(sc_dt::uint64)-1`；不能在 invalidate 裡呼叫 `get_direct_mem_ptr`。

沒有原始碼可核對、依 IEEE 1666 標準的記憶或二手資料寫的部分：

- streaming width「每拍從同一個 address 開始」的語意：只對照到引用 LRM 的論壇與 UVM 文件，沒看到 IEEE 1666 原文。
- 「ignorable extension」的定義：IEEE 1666 的概念，原始碼裡沒有對應註解。
- Q2 的 phase 方向和 `tlm_sync_enum` 語意：這次沒有核對。

### 事實修正（2026-11-03）

以下用本機 SystemC 2.3.3（`-std=c++11`，連結 `lib-linux64/libsystemc.a`）重新實測；測試程式放在 scratchpad，未進 repo。

1. **passthrough 與 multi 是否做 b／nb 轉換（Q3 預設行為、Q7 摘要）**
   - 原敘述：simple、passthrough、multi 沒註冊 callback 的預設行為都相同（Q3）；passthrough 和 multi 與 simple 相同（Q7）。
   - 實測：只註冊 `nb_transport_fw`，initiator 呼叫 `b_transport`：simple 自動轉換，回 `TLM_OK_RESPONSE`；passthrough 報 `no blocking callback registered`；multi 報 `Call to b_transport without a registered callback for b_transport`。這些都是 SC_REPORT_ERROR（不是 SC_FATAL），預設 action 含 SC_THROW，程式以 exit 1 結束。三者都不註冊時，simple 與 passthrough 收到 `b_transport` 才報錯，multi 在模擬開始前的 binding 檢查就報 E109（export not bound）。`get_direct_mem_ptr` 回 `false`、`transport_dbg` 回 `0`，三者一致。反方向：只註冊 `b_transport` 時，simple 會把收到的 `nb_transport_fw` 自動轉成 b→nb；passthrough 報 `no non-blocking callback registered`。
   - 原始碼：`src/tlm_utils/passthrough_target_socket.h`（`b_transport` 只呼叫 `display_error`，沒有轉換）、`src/tlm_utils/convenience_socket_bases.cpp`（`display_error` 是 `SC_REPORT_ERROR`）、`include/sysc/utils/sc_report.h`（`SC_DEFAULT_ERROR_ACTIONS = SC_LOG | SC_CACHE_REPORT | SC_THROW`）。
   - 改了什麼：Q3 改為「DMI 與 debug 三者相同，`b_transport` 不同」，並補上 SC_REPORT_ERROR 與 multi 的 E109；Q7 摘要改為 passthrough、multi 不做 b／nb 轉換。與 Q2 的「passthrough 不做轉換」一致。

2. **MC7 的 bus 還原位址（原敘述：bus 在返回前還原位址，寫成事實）**
   - 實測：MC7 原程式（bus 有 `gp.set_address(orig)`）輸出 `target sees addr=0x8`、`init: addr=0x1008 delay=15 ns now=0 s`；拿掉還原那一行後，initiator 看到 `init: addr=0x8`。
   - 改了什麼：答案改為「這份範例 bus 在返回前還原位址；還原是建議的慣例，不是本機原始碼規定」；未核對條文那段改為「範例寫法，當成建議慣例」。

3. **streaming width 的範例說法（Q8）**
   - 原敘述：「SystemC 範例的 initiator 都會明確寫 `set_streaming_width`」。
   - 實測：`grep -rl set_streaming_width examples` 只有 2 個檔案（`lt_extension_mandatory/src/lt_initiator_extension_mandatory.cpp`、`lt_mixed_endian/src/me_traffic_generator.cpp`），兩者都設成等於 data length。會設定 command／address 的 5 個檔案中，`SimpleBusLT.h`、`SimpleBusAT.h` 是轉送 bus，`lt_dmi_initiator.cpp` 只設 address 與 `set_dmi_allowed`，都沒有設 streaming width。`memory.cpp` 第 108 行的 `streaming_width != data_length` 檢查已確認。
   - 改了什麼：改為精確列出那兩個檔案，並說明其他檔案不設。

4. **protocol checker（MC35、MC 答案 D 段）**
   - 原敘述：「本機 SystemC 2.3.3 也沒有內建的 protocol checker（在 `src`、`include`、`examples` 搜尋過，沒有）」。
   - 實測：`grep -rni checker src include examples` 只有 `examples/tlm/common/src/lt_dmi_initiator.cpp:39` 一則註解 `TLM2.0 checker.`，沒有 checker 元件。
   - 改了什麼：改為「2.3.3 未附 protocol checker」，並附搜尋範圍與那則註解。

5. **`reset()` 的範圍（Q8 第 5 題）**
   - 原敘述：「放回 pool 前通常呼叫 `reset()`，它會清掉 extension，但不會重設 address、command 這些欄位」。
   - 實測（2026-11-05，MC39）：用 `set_extension` 手動掛上的 extension，`reset()` 之後仍然取得到（`ext_kept=1`）；command、address、data length、response status 都保留（`status=TLM_OK_RESPONSE`）。
   - 原始碼：`src/tlm_core/tlm_2/tlm_generic_payload/tlm_gp.cpp:128-132`（`reset()` 只設 `m_gp_option`，並呼叫 `m_extensions.free_entire_cache()`）；`include/tlm_core/tlm_2/tlm_generic_payload/tlm_array.h:102-111`（`free_entire_cache()` 只走訪 `m_entries`，而 `m_entries` 只由 `set_auto_extension` 的 `insert_in_cache` 填入）。
   - 改了什麼：Q8 第 5 題改為「只釋放 auto extension」，並補上 response status 等欄位保留的說明。MC39 與教學導讀 T1 是這個結論的題目與範例。


### 補充驗證紀錄（2026-11-05）

- 測試程式放在 scratchpad 的 `tlm` 子目錄（不在 repo 裡）。編譯指令同上方，`-I` 指向 `~/cpp_practice/side_project/uArch/systemc-2.3.3/include`。
- 方式：從這份檔案抽出 MC37–MC53 與教學導讀的程式碼，補上開頭，編譯、執行，與答案（或該段的 `text` 輸出區塊）逐行比對。MC38 的四個選項各自單獨編譯；E1、E2 的骨架單獨編譯，參考實作的輸出只用來當作期望輸出，實作本身不附在 repo。
- 原始碼核對（SystemC 2.3.3）：
  - MC39、MC40、MC41、事實修正 5：`tlm_gp.cpp`（`reset`、`deep_copy_from`、`set_extension`、`~tlm_generic_payload`）、`tlm_array.h`（`free_entire_cache`）、`tlm_gp.h`（`tlm_extension_base::free()` 預設是 `delete this`，第 60 行）。
  - MC42–MC44、MC51、MC52：`tlm_utils/tlm_quantumkeeper.h`（`need_sync` 是 `>=`、`set_and_sync` 是絕對值、`compute_local_quantum` 是 virtual，第 160 行）。
  - MC37：`tlm_2_interfaces/tlm_dmi.h` 的 `dmi_access_e`。
  - MC45、MC48：`tlm_2_interfaces/tlm_fw_bw_ifs.h`（transport_dbg 的回傳值規則與「不能 wait／notify」的註解）。
  - MC47：`tlm_utils/simple_target_socket.h:363-366`（沒有 callback 時的 fallback：`allow_read_write()`，回傳 false）。
  - MC38：`tlm_phase.h:46`（`tlm_phase(unsigned int)` 建構子，註解 "should be dropped"）。
  - T6：`tlm_gp.h:113`（`TLM_BYTE_ENABLED 0xff`）、`tlm_gp.cpp:241`（`m_byte_enable[i % m_byte_enable_length]`）、`examples/tlm/common/src/memory.cpp:104-108`（byte enable 與 streaming width 的檢查）。
  - T9：`tlm_endian_conv.h` 的 `tlm_to_hostendian_word`／`tlm_from_hostendian_word`，以及檔頭註解（to_ 在交易建立時呼叫、from_ 在完成時呼叫、template 與 bus 寬度要一致）；呼叫點 `examples/tlm/lt_mixed_endian/src/me_traffic_generator.cpp`。
  - T10：`examples/tlm/lt_extension_mandatory/src/lt_target_extension_mandatory.cpp`（`not present - ERROR`）；TLM 相關的 `include/tlm*`、`src/tlm*` 裡沒有 "ignorable" 或 "mandatory" 這兩個字（`include/sysc/datatypes/bit/sc_bit.h` 的 MANDATORY 與 TLM 無關）。
  - Q10、T2：`tlm_utils/` 裡沒有 `passthrough_initiator_socket.h`，bus 下游用的是 simple 或 `multi_passthrough_initiator_socket.h`；`simple_target_socket_tagged` 第二次 bind 報 `E109: 2 binds exceeds maximum of 1`（本機實跑）；`examples/tlm/common/include/models/SimpleBusLT.h:36-51` 用 tagged 陣列。
- 沒有核對或沒有實跑的部分（照實標示）：
  - IEEE 1666 的條文：本機沒有標準原文。在 `~` 與 Documents 下（深度 6 以內）找不到 IEEE 1666 PDF；`GitHub/systemc-3.0.2` 是另一個版本，這次沒有拿來當依據。所以 ignorable／mandatory extension、phase 方向規則、`TLM_UPDATED` 合法組合等，都只依範例與實跑寫，沒有寫條號。
  - `tlm_to_hostendian_word` 與 `tlm_from_hostendian_word` 的 round trip：只依標頭註解，沒有實跑。
  - `TLM_UPDATED` 但 phase 沒有推進（不合法組合）的行為：沒有實跑，沒有加題。
  - MC48 的 `SC_METHOD` 呼叫情況：沒有實跑，答案裡已註明。


---

## 下一輪可以加考的題目

- AT 細節（選擇題 MC23–MC36 已涵蓋 phase 方向、`tlm_sync_enum`、return path、PEQ）：口述版還沒考，要能不看筆記畫出一筆 AT READ 的四個 phase 時序，標出每一步是 fw 還是 bw、回傳哪個 `tlm_sync_enum`。
- `TLM_COMPLETED` 提前結束的情境：什麼樣的 target 會直接回 `TLM_COMPLETED`？（MC18、MC34 已有實跑例子，口述時要能講出理由。）
- 實作驗證：用 C++ 練習第 4 步寫一個 initiator/target，分別量「每筆 `wait`」、「加 quantumkeeper」、「加 DMI」三種的模擬時間。

**2026-11-05 狀態更新**：以下三條原題保留，處理方式如下。

- 上面第 1 條（AT 細節）→ 已由 Q14 第 1 題處理，口述還沒考。
- 上面第 2 條（`TLM_COMPLETED` 提前結束）→ 已由 Q14 第 2 題處理，口述還沒考。
- 上面第 3 條（實作驗證三種時間）→ 已由手寫練習 E2 處理（參考輸出已核對），還沒寫。

新的待辦：

- 口述 Q9–Q15 還沒考。
- 手寫練習 E1（router + 兩個 memory target）：Alan 寫完後貼上來 review。
- endian helper（`tlm_to_hostendian_word` / `tlm_from_hostendian_word`）的 round trip 還沒實跑（見上方「補充驗證紀錄」）。
- `TLM_UPDATED` 但 phase 沒有推進（不合法組合）的行為：還沒實跑，還沒加題。
- IEEE 1666 條文（ignorable／mandatory extension、phase 方向規則）：找到標準原文後再補條號與題目。
