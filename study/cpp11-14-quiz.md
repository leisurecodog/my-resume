# C++11 / C++14 面試與核心觀念複習題

對應 `tasks/learning-plan.md` 第 1 項（C++14）與 `mediatek/prep-notes.md` 第一部分，目標：能說明類別設計、手寫 C++11/14 常考語法，並應對 SystemC / Modeling / 底層系統軟體職缺的面試追問。

用法：先看題目，嘗試在紙上或白板口頭作答/手寫，再展開 `<details><summary>參考答案</summary>` 對照。每題標記常考公司/類型（觀念題、手寫題、陷阱題）。

**難度分級**（標在每題標題後）：L1 學習（看懂概念，附提示）→ L2 應用（預測輸出、找錯、動手改）→ L3 面試（開放式問答與白板題）→ L4 深入（陷阱、效能、原理）。建議順序：先讀「教學導讀」（G1–G12，只讀你還不熟的主題），再做選擇題（MC1–MC43，由淺到深），再做「問答題與手寫題」：第零模組（L1–L2），然後是第一模組之後的 L3、L4 題，最後是第七模組補充問答與第八模組手寫練習。

---

## 目錄
- [教學導讀 (G1–G12)](#教學導讀g1g12)（先讀，再做選擇題）
- [選擇題：先建立直覺 (MC1–MC43)](#選擇題先建立直覺mc1mc43)（再做下面的問答題）
- [第零模組：L1 入門 與 L2 應用 (L1-1–L1-4、L2-1–L2-4)](#第零模組l1-入門-與-l2-應用)
- [第一模組：記憶體管理與智慧指標 (Q1–Q3)](#第一模組記憶體管理與智慧指標)
- [第二模組：Move Semantics、右值與生命週期 (Q4–Q6)](#第二模組move-semantics右值與生命週期)
- [第三模組：Lambda 表達式與函式物件 (Q7–Q9)](#第三模組lambda-表達式與函式物件)
- [第四模組：物件導向、型別推導與編譯期計算 (Q10–Q13)](#第四模組物件導向型別推導與編譯期計算)
- [第五模組：底層系統、並行與 Bit 操作 (Q14–Q15)](#第五模組底層系統並行與-bit-操作)
- [第六模組：白板手寫實作題 (C1–C2)](#第六模組白板手寫實作題)
- [第七模組：補充問答 (Q16–Q22)](#第七模組補充問答q16q22)
- [第八模組：手寫練習 (E1–E2)](#第八模組手寫練習e1e2只給規格與骨架)

---

## 教學導讀（G1–G12）

這一節是給還不熟的主題用的。每節四段：**白話說明 → 小例子（已在本機 g++ 實測）→ 常見陷阱 → 深入題號**。前面模組已經完整展開的主題（例如 Q7、Q9、Q10），這裡只做摘要與指向，不重複長篇解說。讀完再進選擇題。

### G1：lambda 捕獲與隱式 `this`（深入：Q7、C2、MC35、MC36、Q16）

- **白話**：`[=]` 不是「把整個物件複製一份」。它只複製 lambda 內實際用到的**區域變數**。在成員函式裡用到成員 `m` 時，被捕獲的其實是 `this` 指標，所以 lambda 讀到的是物件**現在**的 `m`。
- **例子**（`-std=c++14`，`[m = m]` 是 C++14）：

  ```cpp
  struct S {
    int m = 1;
    std::function<int()> by_this()  { return [=] { return m; }; }      // 捕獲 this
    std::function<int()> by_value() { return [m = m] { return m; }; }  // 複製 m
  };
  S s; auto a = s.by_this(); auto b = s.by_value(); s.m = 5;
  // a() 得到 5，b() 得到 1
  ```
- **陷阱**：lambda 活得比物件久，`[=]` 與 `[this]` 都會懸空（見 Q16）。C++20 起 `[=]` 隱式捕獲 `this` 會得到 deprecated 警告（實測 `-std=c++20 -Wall`：`implicit capture of 'this' via '[=]' is deprecated in C++20`），寫成 `[this]` 或 `[=, this]` 才明確。

### G2：`shared_ptr` 循環與 `weak_ptr`（深入：L2-3、Q1、Q17、MC16、MC37）

- **白話**：`shared_ptr` 的 strong count 是「擁有者人數」。兩個物件互相持有就永遠到不了 0。拆循環的做法是找出**從屬**那一方，讓它改持有 `weak_ptr`。`weak_ptr` 不保證物件還在，每次使用都要 `lock()`；拿到空的 `shared_ptr` 就代表已經被釋放。
- **例子**（實測輸出 `1 2`、`parent=root`，之後 `~root`、`~child`）：

  ```cpp
  struct Node {
    std::weak_ptr<Node> parent;               // 不擁有父節點
    std::vector<std::shared_ptr<Node>> kids;  // 擁有子節點
  };
  if (auto p = child->parent.lock()) { /* p 有效才使用 */ }
  ```
- **陷阱**：從 `this` 另外包一個 `shared_ptr`（`std::shared_ptr<Node>(this)`）會建立第二個 control block，同一個物件會被 delete 兩次。本機 ASan 實測報 `attempting free on address which was not malloc()-ed`。要從成員函式拿到自己的 `shared_ptr`，應用 `enable_shared_from_this`（MC37）。

### G3：Rule of Zero（深入：Q6、L2-4、MC21、MC38、MC39、Q18）

- **白話**：成員都選會自己管理資源的型別（`unique_ptr`、`vector`、`string`），類別就不用寫 destructor、copy、move。編譯器會生成正確版本，這就是 Rule of Zero。
- **例子**（`-std=c++11` 與 `c++14` 都通過 static_assert）：

  ```cpp
  struct LogFile {
    explicit LogFile(const char* path) : fp_(std::fopen(path, "w")) {}
    // 不寫 destructor / copy / move
   private:
    std::unique_ptr<std::FILE, FcloseFn> fp_;   // FcloseFn 是無狀態 struct（見 Q3）
  };
  static_assert(std::is_move_constructible<LogFile>::value, "");
  static_assert(!std::is_copy_constructible<LogFile>::value, "");
  ```
- **陷阱**：只要自己寫了 destructor，就不會再生成 move（MC21）。而且 `unique_ptr` 成員讓 copy 被刪除，所以「寫了解構子」加「有 `unique_ptr` 成員」的類別**既不能 copy 也不能 move**（MC39：`D d2(std::move(d1));` 編譯錯誤）。

### G4：`std::function` 的開銷（深入：Q9、MC22、MC34、Q19）

- **白話**：`std::function` 用 type erasure 包住任何 callable，呼叫是間接呼叫，編譯器通常不能 inline。捕獲夠小且 trivially copyable 時可以放在物件內（SBO）；否則要 heap 配置。
- **例子**（`-std=c++11` 與 `c++14` 都輸出 `2`）：

  ```cpp
  template <class F> void run_fast(F&& f) { f(); }                       // 模板：型別在編譯期固定，可 inline
  void run_slow(const std::function<void()>& f) { f(); }                 // 間接呼叫，大捕獲可能 heap
  ```
- **陷阱**：MC34 實測（libstdc++）：捕獲 `int*` 配置 0 次；捕獲 8 bytes 但有使用者定義 copy 的型別配置 1 次；捕獲 64 bytes 配置 1 次。SBO 規則是實作細節，不要寫進設計假設。在每秒百萬次的 callback 熱路徑上，這些配置與間接呼叫會變成瓶頸（Q19）。

### G5：完美轉發與 `std::forward`（深入：Q4、MC32、MC33、Q20）

- **白話**：`template <class T> void f(T&& x)` 中的 `T&&` 是 forwarding reference：傳 lvalue 進來時 `T` 是 `U&`，傳 rvalue 進來時 `T` 是 `U`。但 `x` 一旦有名字就是 lvalue，所以要用 `std::forward<T>(x)` 把「原本是不是 rvalue」還給下一層。
- **例子**（實測輸出 `const& && | const& const&`）：

  ```cpp
  void sink(const int&) { /* const& */ }
  void sink(int&&)      { /* && */ }
  template <class T> void good(T&& x) { sink(std::forward<T>(x)); }
  template <class T> void bad(T&& x)  { sink(x); }
  // good(1) 呼叫 sink(int&&)；bad(1) 呼叫 sink(const int&)
  ```
- **陷阱**：忘了 `forward`，所有參數都會變成 lvalue。`std::forward` 只能用在 forwarding reference 上；非模板的 `T&&`（例如 `std::vector<T>::push_back(T&&)`）不是 forwarding reference（見 Q4）。

### G6：`constexpr`：C++11 與 C++14 的差別（深入：Q12、MC24、MC40、MC41）

- **白話**：`constexpr` 函式「可以」在編譯期執行，但**不保證**。只有在必須是常數的地方（陣列大小、template 參數、`constexpr` 變數初始化）才被強制在編譯期算。C++11 的 `constexpr` 函式只能有一個 `return`，所以要靠遞迴；C++14 才允許區域變數與迴圈。
- **例子**（`-std=c++11` 會在 `fact` 報 `body of 'constexpr' function ... not a return-statement`；`-std=c++14` 輸出 `55 120`）：

  ```cpp
  constexpr int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }  // C++11 可用
  constexpr int fact(int n) {                                               // C++14 才可用
    int r = 1;
    for (int i = 2; i <= n; ++i) r *= i;
    return r;
  }
  ```
- **陷阱**：`int n = 3; constexpr int c = sq(n);` 編譯錯誤（`the value of 'n' is not usable in a constant expression`）。`constexpr` 只是「能」，`int a = sq(n);` 就是執行期呼叫，完全合法。C++11 的 `constexpr` 成員函式隱含 `const`，所以 `constexpr void set()` 在 C++11 不能編譯（MC41）。

### G7：`enum class`（深入：L1-2、MC3、MC27、Q13）

- **白話**：`enum class` 有獨立作用域（`Color::RED`），不會隱式轉成整數，可以指定底層型別（`: std::uint8_t`，沒寫就是 `int`）。代價是位元運算子不會自動存在，要自己寫 `operator|`。
- **例子**（實測輸出 `10 1` 與 `2`）：

  ```cpp
  enum class Perm : std::uint8_t { None = 0, R = 0b01, W = 0b10 };
  constexpr Perm operator|(Perm a, Perm b) {
    return static_cast<Perm>(static_cast<std::uint8_t>(a) | static_cast<std::uint8_t>(b));
  }
  // Perm p = Perm::R | Perm::W;    // 沒有上面的 operator| 就編譯錯誤（MC27）
  // int raw = static_cast<int>(Perm::W);   // 要轉整數必須顯式
  ```
- **陷阱**：`enum class` 的 `|`、`&`、`<` 都要自己定義；直接比較兩種不同 enum 也會是編譯錯誤，這正是它的設計目的。

### G8：`override` 與 `final`（深入：L1-2、Q10、MC42）

- **白話**：`override` 要求編譯器確認「我真的覆寫了 base 的 virtual 函式」；簽名差一點（例如少了 `const`）就報錯，而不是悄悄變成新函式。`final` 禁止再繼承（class 上）或再覆寫（函式上）。
- **例子**（實測：`'void D::f()' marked 'override', but does not override`）：

  ```cpp
  struct Base { virtual void f() const {} };
  struct Derived : Base { void f() override {} };   // 錯誤：Base::f 是 const
  ```
- **陷阱**：`override` 不能取代 virtual 解構子；base 會被 delete 的話，解構子還是要 `virtual`（Q10、MC19）。

### G9：`std::array`（深入：MC26、MC28、Q21）

- **白話**：固定大小、值語意的陣列。知道自己的 `size()`，可以用 `by value` 傳遞，`at()` 會做邊界檢查。拿來當暫存器庫比 C 陣列安全。
- **例子**（實測 `static_assert(sizeof(regs) == 64)` 通過）：

  ```cpp
  std::array<std::uint32_t, 16> regs{};   // 16 個元素全部零初始化，sizeof == 64
  ```
- **陷阱**：大小必須是常數（MC28）。`operator[]` 越界是 UB，`at()` 才會丟 `std::out_of_range`。C 陣列當函式參數 `int a[4]` 只是指標，`sizeof(a)` 是 8（`-Wsizeof-array-argument` 警告，Q21）。

### G10：`noexcept` 與 `move_if_noexcept`（深入：Q5、MC8、MC20、MC29、MC30、Q22）

- **白話**：`noexcept` 是**承諾**，編譯器不會替你檢查。如果例外真的從 `noexcept` 函式離開，程式會呼叫 `std::terminate`，而不是被外層 `catch`。`vector` 重新配置時，用 `move_if_noexcept` 決定要 move 還是 copy：move 不是 noexcept 且有 copy 時才 copy。
- **例子**（實測：印出 `start`、`in f` 後 abort，exit 134，不會印 `caught`）：

  ```cpp
  void thrower() { throw 1; }
  void f() noexcept { thrower(); }   // 例外離開 noexcept 函式 -> std::terminate
  ```
- **陷阱**：忘了在 move ctor 加 `noexcept` 不會出錯，只會讓 `vector` 悄悄改用 copy（MC20）。寫的時候用 `static_assert(std::is_nothrow_move_constructible<T>::value, "")` 把承諾鎖住。

### G11：`initializer_list` 的陷阱（深入：MC5、MC13、MC31、L1-1）

- **白話**：`{...}` 初始化會先找 `std::initializer_list<T>` 建構子，只要有可行的就優先用它，不管 `()` 版本怎麼寫。`initializer_list` 本身只是指向底層陣列的視窗，**不擁有**那塊陣列。
- **例子**（實測 `3 1 3` 與 `2 ab`）：

  ```cpp
  int n = 3;
  std::vector<int> a(n);     // 3 個 0
  std::vector<int> b{n};     // 1 個元素，值為 3
  std::vector<std::string> s{2, "ab"};   // 2 不能轉成 string，改走 vector(size_type, const T&)：2 個 "ab"
  ```
- **陷阱**：回傳 `std::initializer_list` 會懸空。反例：`std::initializer_list<int> make() { return {1, 2, 3}; }`，g++ 給 `-Winit-list-lifetime` 警告，執行後讀到的是垃圾值（本機兩次結果不同）。不要把 `initializer_list` 存起來或回傳，要保存就用 `std::vector`。

### G12：放進 SystemC 風格的模型時怎麼組合

- 模型程式裡這些特性常一起出現：`enum class` 定義暫存器欄位（G7）、`std::array` 放暫存器（G9）、`constexpr` 放位址表（G6）、lambda 當 callback 時注意捕獲的 `this` 生命週期（G1、Q16）、`unique_ptr` 管 transaction 緩衝區（G3）、`noexcept` move 讓容器重配置保持快（G10）。
- 「structured bindings」（`auto [a, b] = ...`）是 C++17，不在本檔 C++11/14 的範圍內，這裡不教。

---

## 選擇題：先建立直覺（MC1–MC43）

只讀過沒寫過的人，最快的學法是「先猜、再看編譯器怎麼說」。這一段全是單選題，由淺到深。建議做法：

1. 先在紙上選答案，不要馬上展開。
2. 展開後看每個選項為什麼對或錯。
3. 挑幾題自己把程式碼打進編譯器跑一遍（指令：`g++ -std=c++14 -Wall x.cpp -o x && ./x`），看輸出是不是跟你猜的一樣。**手打一次比讀十次有用。**

每題的程式碼與結論都在本機用 g++（`-std=c++14`，另有標明的除外）實際編譯、執行過，驗證紀錄在文末。

---

### 入門（L1）

#### MC1：`auto` 推導出什麼型別？〔L1〕

```cpp
auto x = 5.0f * 2;
```

`x` 的型別是？

- A. `int`
- B. `float`
- C. `double`
- D. `long`

<details>
<summary>答案</summary>

**B. `float`。** `5.0f` 是 `float`，`2` 是 `int`，運算時 `int` 被轉成 `float`，結果是 `float`。`auto` 只是照運算式的型別，不會自己「升級」成 `double`。要 `double` 要寫 `5.0`。

</details>

---

#### MC2：`auto`、`auto&`、`decltype` 對 `const` 的處理〔L1〕

```cpp
const int ci = 1;
auto a = ci;
auto& b = ci;
decltype(ci) c = 2;
```

哪一個變數之後可以被賦值（例如 `x = 10;`）？

- A. 只有 `a`
- B. 只有 `b`
- C. `a` 和 `c`
- D. 三個都可以

<details>
<summary>答案</summary>

**A. 只有 `a`。**

- `a` 是 `int`：`auto` 是「複製出一個新物件」，頂層 `const` 被丟掉。
- `b` 是 `const int&`：`auto&` 綁定到 `const int` 時，`const` 會保留（不然就能透過參考改 `const` 物件了）。
- `c` 是 `const int`：`decltype` 照原樣取型別，包含 `const`。

實測用 `static_assert` 確認了三個型別。

</details>

---

#### MC3：`enum class` 的大小〔L1〕

```cpp
enum class E  { A, B };
enum class E8 : std::uint8_t { A };
```

`sizeof(E)` 和 `sizeof(E8)` 在一般 x86-64 g++ 上各是多少？

- A. 都是 `1`
- B. `4` 和 `4`
- C. `8` 和 `1`
- D. `4` 和 `1`

<details>
<summary>答案</summary>

**D. `4` 和 `1`。** `enum class` 不指定時底層型別預設是 `int`（標準保證），所以 `E` 是 `sizeof(int)`（通常 4）；寫 `: std::uint8_t` 後就是 1 byte。這在寫暫存器欄位或封包格式時很有用：要控制大小就明確指定底層型別。實測輸出 `sizeof(E)=4`、`sizeof(E8)=1`。

</details>

---

#### MC4：哪一個是 C++11 就有的？〔L1〕

下面四個，哪一個在 `g++ -std=c++11` 下可以編譯？

- A. `auto p = std::make_unique<int>(1);`
- B. `auto f = [](auto a) { return a; };`
- C. `auto x = 1; auto f = [](int a) -> int { return a; };`
- D. `int x = 1'000;`

<details>
<summary>答案</summary>

**C。** `auto` 變數和 lambda 是 C++11；其他三個是 C++14：

- A：`std::make_unique` 是 C++14（C++11 有 `make_shared` 沒有 `make_unique`），實測 `'make_unique' is not a member of 'std'`。
- B：generic lambda（lambda 參數寫 `auto`）是 C++14，實測 `use of 'auto' in lambda parameter declaration only available with '-std=c++14'`。
- D：數字分隔符 `'` 是 C++14，C++11 模式下實測報 `missing terminating ' character`。

順帶一提：`auto f(int x) { return x*2; }`（函式回傳型別推導）也是 C++14，C++11 只能寫 `-> decltype(...)`。

</details>

---

#### MC5：`()` 和 `{}` 初始化不一樣〔L1〕

```cpp
std::vector<int> v1(3, 1);
std::vector<int> v2{3, 1};
int x{3.5};
```

下列敘述哪個正確？

- A. `v1` 是三個 1、`v2` 是 `{3, 1}` 兩個元素，`int x{3.5}` 是編譯錯誤
- B. `v1`、`v2` 都是 `{1, 1, 1}`，`int x{3.5}` 得到 3
- C. `v1` 是 `{3, 1}`、`v2` 是三個 1，`int x{3.5}` 得到 3
- D. 兩者都是 `{3, 1}`，`int x{3.5}` 是編譯錯誤

<details>
<summary>答案</summary>

**A。**

- `v1(3, 1)` 呼叫「個數、值」的建構子，三個 `1`（size 3）；`v2{3, 1}` 優先匹配 `std::initializer_list<int>` 建構子，元素是 `3` 和 `1`（size 2）。實測 `v1.size=3 v2.size=2`。這是 `{}` 最常見的陷阱：**只要有接受 `initializer_list` 的建構子，`{}` 會優先選它**。
- `int x{3.5};` 是 narrowing conversion（`double` 轉 `int` 會丟資料），`{}` 初始化禁止，編譯錯誤（實測 `narrowing conversion of '3.5e+0' from 'double' to 'int'`）；`int y = 3.5;` 用 `=` 則允許（可能只有警告）。

</details>

---

#### MC6：lambda 的 `[=]` 與 `[&]` 什麼時候讀值？〔L1〕

```cpp
int cap = 1;
auto f = [=] { return cap; };
cap = 2;
std::cout << f() << "\n";

auto g = [&] { return cap; };
cap = 3;
std::cout << g() << "\n";
```

輸出是？

- A. `2`、`3`
- B. `1`、`2`
- C. `1`、`3`
- D. `2`、`2`

<details>
<summary>答案</summary>

**C. `1` 和 `3`。** `[=]` 在**建立 lambda 的當下**就把 `cap` 複製進去（複製的是 1），之後改外面的 `cap` 不影響它；`[&]` 存的是參考，每次呼叫才去讀 `cap` 目前的值（3）。實測輸出 `f()=1`、`g()=3`。

</details>

---

#### MC7：智慧指標有多大？〔L1〕

在 64-bit 的 g++ 上，下面四個 `sizeof` 分別是？

```cpp
sizeof(std::unique_ptr<int>)
sizeof(std::shared_ptr<int>)
sizeof(std::unique_ptr<int, void(*)(int*)>)
sizeof(int*)
```

- A. `8, 8, 8, 8`
- B. `8, 16, 8, 8`
- C. `16, 16, 16, 8`
- D. `8, 16, 16, 8`

<details>
<summary>答案</summary>

**D. `8, 16, 16, 8`。**

- `unique_ptr<int>`：預設的 deleter 是空物件，不占空間，所以跟裸指標一樣大（8）。這就是 zero-overhead。
- `shared_ptr<int>`：兩個指標，一個指向物件、一個指向 control block（16）。
- `unique_ptr<int, void(*)(int*)>`：deleter 是函式指標，要多存一個指標（16）。如果 deleter 是沒有捕獲的 lambda 或空的 functor，則仍是 8。

實測輸出 `8 16 16 8`；無捕獲 lambda 當 deleter 實測是 8，有捕獲一個 `int` 的 lambda 是 16。

</details>

---

#### MC8：`push_back` 和 `emplace_back` 差在哪？〔L1〕

```cpp
struct P {
  P(int a, int b) { std::cout << "ctor "; }
  P(const P&)     { std::cout << "copy "; }
  P(P&&) noexcept { std::cout << "move "; }
};

std::vector<P> v;
v.reserve(4);
v.push_back(P(1, 2));  std::cout << "| ";
v.emplace_back(3, 4);  std::cout << "| ";
v.push_back({5, 6});   std::cout << "\n";
```

輸出是？（`reserve(4)` 保證沒有重新配置）

- A. `ctor | ctor | ctor`
- B. `ctor move | ctor | ctor move`
- C. `ctor copy | ctor | ctor copy`
- D. `ctor move | ctor move | ctor move`

<details>
<summary>答案</summary>

**B。** `push_back(P(1,2))`：先在外面建一個暫時物件（`ctor`），再 move 進 vector（`move`）；`emplace_back(3,4)`：把引數直接傳給建構子，**就地建構**，只有 `ctor`；`push_back({5,6})`：`{5,6}` 先建出一個暫時的 `P`，再 move 進去。暫時物件是右值，所以是 `move` 不是 `copy`。實測輸出 `ctor move | ctor | ctor move`。

注意：對於 `int`、指標這類便宜的型別，兩者沒有差別；差異在建構成本高、或不可複製的型別。

</details>

---

### 應用（L2）

#### MC9：有名字的右值參考，是左值嗎？〔L2〕

```cpp
void f(std::string&&);
void g(std::string&& s) { f(s); }
```

這段程式的結果？

- A. 編譯通過，`f` 收到右值
- B. 編譯通過，但 `s` 會被複製一份
- C. 編譯錯誤：不能把左值 `s` 綁定到 `std::string&&`
- D. 執行期錯誤

<details>
<summary>答案</summary>

**C。** 型別是 `std::string&&`，但 `s` 是**有名字的變數，運算式 `s` 是左值**。想轉傳要明確寫 `f(std::move(s))`（只有你確定之後不再用 `s`）或 `f(std::forward<T>(s))`（在 template 裡）。實測報 `cannot bind rvalue reference of type 'std::string&&' to lvalue of type 'std::string'`。

一句話記：「看有沒有名字，有名字的就是左值，跟型別怎麼寫無關。」

</details>

---

#### MC10：多載決議選哪一個？〔L2〕

```cpp
void f(const std::string&) { std::cout << "const&\n"; }
void f(std::string&&)      { std::cout << "&&\n"; }
void g(std::string&& s)    { f(s); }
std::string make() { return "x"; }

std::string s = "a";
const std::string cs = "c";
f(std::string("tmp"));   // (1)
f(s);                    // (2)
f(std::move(s));         // (3)
f(std::move(cs));        // (4)
f(make());               // (5)
g(make());               // (6)
```

(1)–(6) 各印什麼？

- A. `&&, const&, &&, &&, &&, &&`
- B. `&&, &&, &&, const&, &&, &&`
- C. `const&, const&, const&, const&, const&, const&`
- D. `&&, const&, &&, const&, &&, const&`

<details>
<summary>答案</summary>

**D。**

1. 暫時物件是右值 → `&&`。
2. `s` 是左值 → `const&`。
3. `std::move(s)` 是右值 → `&&`。
4. `std::move(cs)` 是 `const std::string&&`，`std::string&&` 收不下 const 右值，只能選 `const&` → `const&`（呼應 L1-3：對 `const` 物件 `std::move` 沒有效果）。
5. `make()` 回傳暫時值 → `&&`。
6. `g` 裡的 `s` 有名字，是左值 → `const&`（呼應 MC9）。

實測輸出順序是 `&&, const&, &&, const&, &&, const&`（實測時另外多測了 `f(cs)`，結果是 `const&`）。

</details>

---

#### MC11：`return std::move(local)` 會更快嗎？〔L2〕

```cpp
struct T { T(){ std::cout << "ctor "; } T(const T&){ std::cout << "copy "; } T(T&&) noexcept { std::cout << "move "; } };
T a() { T t; return t; }
T b() { T t; return std::move(t); }

T x = a(); std::cout << "| ";
T y = b();
```

輸出是？

- A. `ctor | ctor move`
- B. `ctor | ctor`
- C. `ctor move | ctor move`
- D. `ctor copy | ctor move`

<details>
<summary>答案</summary>

**A。** `return t;` 編譯器可以做 NRVO（具名回傳值最佳化），`t` 直接建在呼叫端的 `x`，沒有 move 也沒有 copy。`return std::move(t);` 回傳的運算式不再是區域變數本身，而是一個右值參考，**NRVO 不成立**，反而多一次 move。實測輸出 `ctor | ctor move`。

規則：回傳區域變數就直接 `return t;`，不要寫 `std::move`。（g++ 的 `-Wpessimizing-move` 也會警告。）

</details>

---

#### MC12：被 move 走之後，原物件是什麼狀態？〔L2〕

下列哪一個敘述正確？

- A. 對 `std::string` 做了 move 之後，來源字串一定是空字串
- B. 對 `std::vector<int>` 做 move construction 之後，來源 vector 保證是空的
- C. moved-from 物件已經被解構，不能再賦值
- D. moved-from 物件在 move 之後不能對它呼叫 `size()`

<details>
<summary>答案</summary>

**B。** 標準對 `std::vector` 的 move constructor 保證來源會是空的。

- A 錯：標準只說 `std::string` 的 moved-from 是「有效但未指定的狀態」，libstdc++ 實測剛好是空的，但不要依賴。
- C 錯：物件還活著，只是內容被搬走；對它賦值、解構都合法。
- D 錯：moved-from 物件是有效的，可以呼叫不需要前置條件的成員函式（如 `size()`、`empty()`）。

通則：moved-from 物件只做兩件事，**賦新值、或讓它被解構**。實測 `vector moved-from size=0`。

</details>

---

#### MC13：`auto` 搭配 `{}`〔L2〕

```cpp
auto x = {1, 2, 3};
auto y{1};
```

在 `g++ -std=c++14` 下，`x` 和 `y` 的型別是？

- A. `std::vector<int>` 和 `int`
- B. `std::initializer_list<int>` 和 `int`
- C. `std::initializer_list<int>` 和 `std::initializer_list<int>`
- D. 兩者都是編譯錯誤

<details>
<summary>答案</summary>

**B。** `auto x = {1,2,3}` 推導成 `std::initializer_list<int>`（這是 `auto` 唯一特別處理 `{}` 的地方，跟你直覺的 `vector` 無關）；`auto y{1}` 在採用 N3922 規則的編譯器（g++ 5 以上，包含 C++14 模式）是 `int`，更早的編譯器曾經推成 `initializer_list<int>`，這是一個「會因編譯器版本而改變」的角落，不要在程式裡依賴，要 `int` 就寫 `int y = 1;`。實測 `static_assert` 兩者皆成立。

</details>

---

#### MC14：`unique_ptr<int>` 配上 `new int[3]`〔L2〕

```cpp
std::unique_ptr<int> p(new int[3]);
```

哪個敘述正確？

- A. 編譯錯誤，因為 `new int[3]` 不是 `int*`
- B. 編譯通過，解構時自動呼叫 `delete[]`
- C. 編譯通過，解構時呼叫 `delete`（不是 `delete[]`），是未定義行為
- D. 編譯通過，而且沒有任何問題，因為 `int` 是 trivial 型別

<details>
<summary>答案</summary>

**C。** `new int[3]` 回傳 `int*`，所以能編譯；但 `unique_ptr<int>` 預設的 deleter 是 `delete`，與 `new[]` 不配對，是**未定義行為**，即使 `int` 是 trivial，標準也不允許。AddressSanitizer 實測報 `alloc-dealloc-mismatch (operator new [] vs operator delete)`。

正確寫法是 `std::unique_ptr<int[]> p(new int[3]);`（或 `std::make_unique<int[]>(3)`，C++14），它的 deleter 是 `delete[]`。

</details>

---

#### MC15：同一個裸指標交給兩個 `shared_ptr`〔L2〕

```cpp
auto* raw = new int(1);
std::shared_ptr<int> p(raw), q(raw);
```

會發生什麼事？

- A. 編譯錯誤
- B. `p`、`q` 共用同一個 control block，沒有問題
- C. 第二個建構會拋出 `std::bad_alloc`
- D. 各自有獨立的 control block（use_count 都是 1），離開 scope 時 `raw` 被 delete 兩次

<details>
<summary>答案</summary>

**D。** 每次用裸指標建構 `shared_ptr` 都會建立**新的 control block**，兩個 `shared_ptr` 互相不知道對方，各自在 count 歸零時 delete 一次，**double free**。AddressSanitizer 實測報 `attempting double-free`。

規則：用 `std::make_shared` 建立；如果一定要從已有的 `shared_ptr` 拿到另一個，要用複製（`auto q = p;`），不要從 `.get()` 重新包一個。需要「在成員函式裡取得 `shared_ptr<this>`」時，用 `std::enable_shared_from_this`。

</details>

---

#### MC16：`weak_ptr` 之後的狀態〔L2〕

```cpp
auto sp = std::make_shared<int>(1);
std::weak_ptr<int> w = sp;
std::cout << sp.use_count() << " " << w.use_count() << " " << w.expired() << "\n";
sp.reset();
std::cout << w.use_count() << " " << w.expired() << " " << (w.lock() == nullptr) << "\n";
```

兩行輸出是？（`bool` 印成 `0` / `1`）

- A. `1 1 0` 和 `0 1 1`
- B. `1 2 0` 和 `0 1 1`
- C. `1 1 0` 和 `1 0 0`
- D. `2 1 0` 和 `0 1 1`

<details>
<summary>答案</summary>

**A。** `weak_ptr` 不增加 strong count，所以 `sp.use_count()` 和 `w.use_count()` 都是 1（`use_count` 數的是 strong reference），`expired()` 是 `false`（0）。`sp.reset()` 之後物件釋放，strong count 歸零：`w.use_count()` 是 0、`expired()` 是 `true`（1）、`w.lock()` 回傳空的 `shared_ptr`（`== nullptr` 為 1）。實測輸出 `1 1 0` 和 `0 1 1`。

</details>

---

#### MC17：lambda 的 `mutable`〔L2〕

```cpp
int x = 0;
auto f = [x]() mutable { return ++x; };
int r1 = f();   // 拆成獨立語句：C++14 的 << 串接中，各 f() 的求值順序未定
int r2 = f();
std::cout << r1 << " " << r2 << " " << x << "\n";
auto g = f;
int r3 = g();
int r4 = f();
std::cout << r3 << " " << r4 << "\n";
```

兩行輸出是？

- A. `1 2 2` 和 `3 3`
- B. `1 2 0` 和 `1 3`
- C. `1 1 0` 和 `1 1`
- D. `1 2 0` 和 `3 3`

<details>
<summary>答案</summary>

**D。** 值捕獲的 `x` 是 lambda 內部自己的一份複本，預設 `operator()` 是 `const`，不能改它，要加 `mutable`（沒加會編譯錯誤，實測 `increment of read-only variable 'x'`）。修改的是內部那份，外面的 `x` 仍是 0。`f()` 兩次得到 1、2；`auto g = f;` **複製整個 closure，連內部狀態（目前是 2）一起複製**，所以 `g()` 得到 3，`f()` 也得到 3。這就是為什麼「有狀態的 lambda 被複製」會出乎意料。

   題目的寫法若直接寫成 `std::cout << f() << " " << f()`，在 C++14 `<<` 串接中兩個 `f()` 的求值順序未定（C++17 才定序），所以改成獨立語句。拆開後實測輸出仍是 `1 2 0` 和 `3 3`，與答案一致，不依賴 g++ 的實作順序。

</details>

---

#### MC18：range-for 遍歷 `std::map` 的隱藏複製〔L2〕

```cpp
std::map<K, int> m;   // K 是一個會計算 copy 次數的型別，m 裡有 3 個元素

for (const auto& kv : m) { }                          // (1)
for (const std::pair<K, int>& kv : m) { }             // (2)
for (const std::pair<const K, int>& kv : m) { }       // (3)
```

三種寫法分別發生幾次 `K` 的複製？

- A. (1) 0 次、(2) 3 次、(3) 0 次
- B. 都是 0 次
- C. (1) 3 次、(2) 3 次、(3) 0 次
- D. (1) 0 次、(2) 0 次、(3) 3 次

<details>
<summary>答案</summary>

**A。** `std::map` 的元素型別是 `std::pair<const K, int>`，key 是 `const`。(2) 寫成 `std::pair<K, int>`，型別不同，編譯器要把每個元素**轉換成一個新的暫時 pair**，每次迭代複製一次 `K`（3 個元素 = 3 次），然後 `const&` 綁到那個暫時物件上，編譯通過，沒有任何警告。(1) 用 `auto` 自動推出正確型別、(3) 寫對了，都不會複製。實測 `copies=0`、`3`、`0`。

建議：遍歷 map 用 `const auto&`，不要手寫 pair 型別。

</details>

---

#### MC19：沒有 `virtual` 解構子〔L2〕

```cpp
struct Base    { ~Base()    { std::cout << "~Base\n"; } };
struct Derived : Base { ~Derived() { std::cout << "~Derived\n"; } };

Base* b = new Derived;
delete b;
```

哪個敘述正確？

- A. 印 `~Derived`、`~Base`
- B. 未定義行為（g++ 上通常只印 `~Base`，`Derived` 的成員沒有被解構）
- C. 只印 `~Base`，這是定義明確的行為
- D. 編譯錯誤

<details>
<summary>答案</summary>

**B。** 透過基底類別的指標 delete 衍生類別的物件，而基底的解構子不是 `virtual`，標準規定是**未定義行為**。g++ 實測只印 `~Base`，衍生類別的部分沒有被解構，資源洩漏。把 `Base` 的解構子改成 `virtual ~Base()`，就會印 `~Derived`、`~Base`；`unique_ptr<VBase>` 持有 `new VDerived` 時也需要 `VBase` 有 virtual 解構子（實測有 virtual 時兩個都有印）。

規則：只要類別有 `virtual` 函式、而且會被當基底用，解構子就要是 `virtual`。

</details>

---

### 進階（L3）

#### MC20：`vector` 擴容時會 copy 還是 move？〔L3〕

```cpp
struct A { A(){} A(const A&){ std::cout << "copy "; } A(A&&)          { std::cout << "move "; } };
struct B { B(){} B(const B&){ std::cout << "copy "; } B(B&&) noexcept { std::cout << "move "; } };

std::vector<A> va; va.reserve(1); va.emplace_back(); va.emplace_back();
std::vector<B> vb; vb.reserve(1); vb.emplace_back(); vb.emplace_back();
```

第二次 `emplace_back` 需要重新配置，各印什麼？

- A. `A` 印 `move`，`B` 印 `move`
- B. `A` 印 `copy`，`B` 印 `copy`
- C. `A` 印 `move`，`B` 印 `copy`
- D. `A` 印 `copy`，`B` 印 `move`

<details>
<summary>答案</summary>

**D。** 搬移元素到新記憶體時，`std::vector` 用 `std::move_if_noexcept`：move constructor 如果不是 `noexcept`、而且有可用的 copy constructor，就**選擇 copy**，才能維持 strong exception guarantee（搬到一半拋例外，舊的資料還在）。`A` 的 move 沒標 `noexcept`，所以印 `copy`；`B` 標了，所以印 `move`。實測 `A(no noexcept): copy`、`B(noexcept): move`。

這就是 Q5「move constructor 為什麼一定要標 `noexcept`」的實驗版本：忘了寫 `noexcept`，程式不會錯，只是悄悄變慢。

</details>

---

#### MC21：宣告了解構子，move 就沒了？〔L3〕

```cpp
struct X { std::vector<int> v; ~X() {} };
struct Y { std::vector<int> v; };

X a{{1,2,3}}; X b = std::move(a);
Y c{{1,2,3}}; Y d = std::move(c);
```

`a.v.size()` 和 `c.v.size()` 各是多少？

- A. `0` 和 `0`
- B. `3` 和 `0`
- C. `0` 和 `3`
- D. `3` 和 `3`

<details>
<summary>答案</summary>

**B。** 只要自己宣告了 destructor（即使 `{}`），編譯器就**不會隱含產生 move constructor / move assignment**，`std::move(a)` 退回到 copy constructor，`a.v` 仍是 3。`Y` 什麼都沒宣告（Rule of Zero），move 自動產生，`c.v` 被搬空變 0。實測 `X: a.v.size=3`、`Y: c.v.size=0`。

規則：要嘛什麼都不寫（Rule of Zero），要嘛 5 個一起寫或 `= default`（Rule of Five）。

</details>

---

#### MC22：init capture 搬進 lambda，能放進 `std::function` 嗎？〔L3〕

```cpp
auto p = std::make_unique<int>(5);
auto f = [q = std::move(p)] { return *q; };
std::function<int()> h = std::move(f);
```

結果是？

- A. 編譯通過，`h()` 回傳 5
- B. 編譯通過，但 `h()` 執行時當掉
- C. 編譯錯誤：`std::function` 要求可呼叫物件可以複製，而 `f` 只能 move
- D. 編譯錯誤：init capture 不能搬移 `unique_ptr`

<details>
<summary>答案</summary>

**C。** init capture（C++14）可以把 `unique_ptr` 搬進 closure，沒有問題（D 錯）；closure 因此變成 move-only（可以 `auto g = std::move(f);`）。但 `std::function` 要求存進去的物件 **CopyConstructible**，實測報 `std::function target must be copy-constructible`。

如果一定要型別擦除又只能 move，C++23 才有 `std::move_only_function`；C++14 可以改用 `std::shared_ptr` 捕獲，或自己寫一個 task wrapper，或用 template 參數接收 callable 而不經過 `std::function`。

</details>

---

#### MC23：generic lambda 的回傳型別〔L3〕

```cpp
auto add = [](auto a, auto b) { return a + b; };
```

哪一個型別對應是正確的？

- A. `add(1, 2)` 是 `int`；`add(1, 2.5f)` 是 `double`
- B. `add(1, 2)` 是 `int`；`add(1, 2.5f)` 是 `float`；`add('a', 'b')` 是 `char`
- C. 三者都是 `auto`，沒有確定型別
- D. `add(1, 2)` 是 `int`；`add(1, 2.5f)` 是 `float`；`add('a', 'b')` 是 `int`

<details>
<summary>答案</summary>

**D。** generic lambda 是個有 template `operator()` 的 closure，每種引數型別組合會實例化一份，回傳型別就是 `a + b` 的型別：`int + int = int`、`int + float = float`（算術轉換）、`char + char`：整數提升後是 `int`，不是 `char`。實測用 `static_assert` 確認；`add(1, 2.5)` 是 `double`，`add(std::string("a"), "b")` 是 `std::string`。

</details>

---

#### MC24：`constexpr` 函式內可以寫迴圈嗎？〔L3〕

```cpp
constexpr int fact(int n) {
  int r = 1;
  for (int i = 2; i <= n; ++i) r *= i;
  return r;
}
static_assert(fact(5) == 120, "");
```

這段在哪個標準下開始可以編譯？

- A. C++11
- B. C++14
- C. C++17
- D. C++20

<details>
<summary>答案</summary>

**B. C++14。** C++11 的 `constexpr` 函式**只能有一個 return 敘述**（要寫遞迴），不能有區域變數、迴圈；C++14 放寬為可以有區域變數、`if`、迴圈。實測 `-std=c++11` 報 `body of 'constexpr' function ... not a return-statement`，`-std=c++14` 通過。

</details>

---

#### MC25：`volatile` 能讓多執行緒計數安全嗎？〔L3〕

```cpp
volatile int vc = 0;
std::atomic<int> ac{0};
// 兩個 thread 各執行 100 萬次：
//   vc = vc + 1;
//   ac.fetch_add(1);
```

結果是？

- A. `vc` 和 `ac` 都保證是 2000000
- B. `vc` 保證 2000000，`ac` 不保證
- C. `ac` 保證 2000000，`vc` 不保證（data race，未定義行為）
- D. 兩者都不保證

<details>
<summary>答案</summary>

**C。** `volatile` 只告訴編譯器「每次都要真的讀寫記憶體、不要把這個存取最佳化掉」，它**不提供原子性**（`vc = vc + 1` 是 load、加、store 三步，兩個 thread 會互相覆蓋），也不保證 thread 之間的記憶體順序；多個 thread 沒同步地存取同一個非 atomic 變數是 data race，屬未定義行為。`std::atomic` 才提供原子性與記憶體順序。

在本機（`-O2`、兩個 thread）跑三次，`vc` 分別是 1954002、1884501、1933205，`ac` 每次都是 2000000。`volatile` 的正確用途是 memory-mapped I/O 暫存器之類（不是 thread 同步）。

</details>

---

### 補充題（MC26–MC43）：array、noexcept、forwarding、lambda、智慧指標與 constexpr

這一段對應上面的教學導讀 G1–G11。每題程式碼都在本機 g++ 11.4 實際編譯、執行過（`-std=c++11` 與 `-std=c++14` 都跑過，有標明的除外）。

---

#### MC26：`std::array` 的大小與初始化〔L1〕

```cpp
#include <array>
#include <iostream>
int main() {
  std::array<int, 4> a{1, 2};
  std::cout << a.size() << " " << sizeof(a) << " " << a[2] << " " << a[3] << "\n";
  std::array<int, 3> b{};
  std::cout << b.front() << b.back() << "\n";
}
```

輸出是？

- A. `4 16 0 0` 與 `00`
- B. `2 8 0 0` 與 `00`
- C. `4 16 2 0` 與 `10`
- D. 編譯錯誤

<details>
<summary>答案</summary>

**A。** `std::array<int, 4>` 是固定大小的聚合型別，大小寫在型別裡，不會退化成指標。只給了前兩個初值，其餘元素做值初始化成 `0`。`sizeof(a)` 是 `4 * sizeof(int)`，在這個平台是 16。實測輸出 `4 16 0 0` 與 `00`。

</details>

---

#### MC27：`enum class` 直接用 `|`〔L1〕

```cpp
enum class Flags : unsigned { A = 1u, B = 2u };
int main() { Flags f = Flags::A | Flags::B; }
```

結果是？

- A. 編譯通過，`f` 的值是 `3`
- B. 編譯錯誤：找不到可用的 `operator|`
- C. 編譯通過，`f` 是 `Flags::A`
- D. 編譯通過，但執行期有未定義行為

<details>
<summary>答案</summary>

**B。** `enum class` 不會隱式轉成整數，也不會自動提供位元運算子。實測 `no match for 'operator|' (operand types are 'Flags' and 'Flags')`，`-std=c++11` 與 `c++14` 相同。要用的話，自己寫 `constexpr Flags operator|(Flags, Flags)`（見 G7）。

</details>

---

#### MC28：陣列大小要求常數〔L1〕

```cpp
#include <array>
int main() {
  int n = 4;
  std::array<int, n> a{};    // (1)
  const int m = 4;
  std::array<int, m> b{};    // (2)
}
```

(1) 與 (2) 的情況是？

- A. 兩個都可以編譯
- B. 兩個都是編譯錯誤
- C. (1) 錯誤，(2) 可以
- D. (1) 可以，(2) 錯誤

<details>
<summary>答案</summary>

**C。** `std::array` 的大小是模板參數，必須是常數表達式（constant expression）。`n` 是一般變數，實測 `the value of 'n' is not usable in a constant expression`；`const int m = 4;` 是整數常數，可以。`-std=c++11` 與 `c++14` 結果相同。

</details>

---

#### MC29：`std::move_if_noexcept` 的回傳型別〔L3〕

```cpp
#include <type_traits>
#include <utility>
struct NoCopyThrowMove { NoCopyThrowMove(NoCopyThrowMove&&) {} NoCopyThrowMove(const NoCopyThrowMove&) = delete; };
struct CopyThrowMove { CopyThrowMove(CopyThrowMove&&) {} CopyThrowMove(const CopyThrowMove&) {} };
struct CopyNoexceptMove { CopyNoexceptMove(CopyNoexceptMove&&) noexcept {} CopyNoexceptMove(const CopyNoexceptMove&) {} };
```

下列哪一個敘述是**錯誤**的？

- A. `std::move_if_noexcept` 作用在 `NoCopyThrowMove&` 上，回傳型別是 `NoCopyThrowMove&&`
- B. 作用在 `CopyThrowMove&` 上，回傳 `const CopyThrowMove&`，所以 `vector` 擴容時會複製
- C. 作用在 `CopyNoexceptMove&` 上，回傳型別是 `CopyNoexceptMove&&`
- D. 只要 move constructor 是 `noexcept`，回傳型別一定是 `const T&`

<details>
<summary>答案</summary>

**D。** 依 [util.move_if_noexcept]，只有「move 不是 `noexcept`」**且**「有可用的 copy constructor」時回傳 `const T&`，否則回傳 `T&&`。`noexcept` move 的情況回傳 `T&&`。A、B、C 三個 `static_assert` 都實測通過。

</details>

---

#### MC30：從 `noexcept` 函式丟出例外〔L2〕

```cpp
#include <iostream>
void thrower() { throw 1; }
void f() noexcept { std::cout << "in f" << std::endl; thrower(); }
int main() {
  std::cout << "start" << std::endl;
  try { f(); } catch (...) { std::cout << "caught" << std::endl; }
  std::cout << "end" << std::endl;
}
```

輸出是？

- A. `start`、`in f`、`caught`、`end`
- B. `start`、`in f`、`caught`
- C. `start`、`in f`，然後程式呼叫 `std::terminate` 中止，不會印出 `caught` 與 `end`
- D. 編譯錯誤

<details>
<summary>答案</summary>

**C。** 例外離開 `noexcept` 函式時，標準規定呼叫 `std::terminate`（[except.spec]）。`main` 的 `catch` 接不到它。實測 exit code 134（SIGABRT），stderr 印 `terminate called after throwing an instance of 'int'`。這題用 `std::endl` 讓前兩行在中止前刷出；如果用 `\n`，在 pipe 下這些字可能被丟失。

</details>

---

#### MC31：`std::vector<std::string>{2, "ab"}`〔L2〕

```cpp
#include <iostream>
#include <string>
#include <vector>
int main() {
  std::vector<std::string> a{2, "ab"};
  std::vector<std::string> b(2, "ab");
  std::cout << a.size() << " " << a[0] << " " << b.size() << " " << b[1] << "\n";
}
```

輸出是？

- A. `2 ab 2 ab`
- B. `1 ab 2 ab`
- C. 編譯錯誤
- D. `1 2 2 ab`

<details>
<summary>答案</summary>

**A。** `{2, "ab"}` 先試 `std::initializer_list<std::string>`，但 `2` 不能隱式轉成 `std::string`，這條路不成立，於是退回一般建構子 `vector(size_type, const T&)`，結果等同 `b`。實測 `2 ab 2 ab`。

提醒：不要用字面值 `0` 做這個實驗。`0` 是 null pointer constant，可以轉成 `const char*`，會讓 initializer_list 路徑成立，之後的行為不要依賴。

</details>

---

#### MC32：有 `std::forward` 與沒有的差別〔L2〕

```cpp
#include <iostream>
#include <utility>
void target(int&) { std::cout << "lvalue "; }
void target(int&&) { std::cout << "rvalue "; }
template <class T> void fwd(T&& x) { target(std::forward<T>(x)); }
template <class T> void nofwd(T&& x) { target(x); }
int main() {
  int a = 1;
  fwd(a); fwd(2); fwd(std::move(a)); std::cout << "\n";
  nofwd(a); nofwd(2); nofwd(std::move(a)); std::cout << "\n";
}
```

輸出是？

- A. `lvalue rvalue rvalue` / `lvalue lvalue lvalue`
- B. `lvalue lvalue lvalue` / `lvalue lvalue lvalue`
- C. `lvalue rvalue rvalue` / `lvalue rvalue rvalue`
- D. 編譯錯誤

<details>
<summary>答案</summary>

**A。** `fwd` 用 `std::forward<T>(x)` 保留原本的值類別；`nofwd` 的 `x` 有名字，永遠是 lvalue。實測輸出如 A 所示，`-std=c++11` 與 `c++14` 相同。

</details>

---

#### MC33：forwarding reference 的推導結果〔L3〕

```cpp
#include <type_traits>
template <class T> struct tag {};
template <class T> tag<T> deduce(T&&);
int main() {
  int x = 0; const int cx = 0;
  static_assert(std::is_same<decltype(deduce(x)), tag<int&>>::value, "A");
  static_assert(std::is_same<decltype(deduce(cx)), tag<const int&>>::value, "B");
  static_assert(std::is_same<decltype(deduce(0)), tag<int>>::value, "C");
}
```

下列哪一個敘述正確？

- A. 三個 `static_assert` 全部通過
- B. A 會失敗，因為 lvalue 推導出的是 `int`
- C. B 會失敗，因為 `const` 會被丟掉
- D. C 會失敗，因為右值推導出的是 `int&&`

<details>
<summary>答案</summary>

**A。** 這是 forwarding reference 的推導規則：lvalue `x` 推出 `T = int&`，`const int` 的 lvalue 推出 `T = const int&`，右值 `0` 推出 `T = int`（參數型別是 `int&&`）。實測三個 `static_assert` 都通過，`-std=c++11` 與 `c++14` 相同。

</details>

---

#### MC34：`std::function` 什麼時候會 heap 配置？〔L3〕

```cpp
#include <cstdlib>
#include <functional>
#include <iostream>
#include <new>
static int g_allocs = 0;
void* operator new(std::size_t n) { ++g_allocs; void* p = std::malloc(n ? n : 1); if (!p) throw std::bad_alloc(); return p; }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
struct NT { int* p; NT(int* q) : p(q) {} NT(const NT& o) : p(o.p) {} ~NT() {} };  // 8 bytes，非 trivially copyable
struct Big { char buf[64]; };
int main() {
  int x = 1; int* ptr = &x; NT nt(&x); Big big{};
  int before, used[3];
  before = g_allocs; std::function<int()> a = [ptr] { return *ptr; };       used[0] = g_allocs - before;
  before = g_allocs; std::function<int()> b = [nt] { return *nt.p; };       used[1] = g_allocs - before;
  before = g_allocs; std::function<int()> c = [big] { return big.buf[0]; }; used[2] = g_allocs - before;
  std::cout << used[0] << " " << used[1] << " " << used[2] << "\n";
  std::cout << a() << b() << c() << "\n";
}
```

下列哪一個敘述正確？（本題的結論是 libstdc++ 的實作行為）

- A. 只要捕獲的物件小於 16 bytes，`std::function` 就不會 heap 配置
- B. 小且 trivially copyable 的捕獲不配置；小但**不是** trivially copyable（即使只有 8 bytes）的捕獲仍會配置
- C. 只有超過 64 bytes 的捕獲才會配置
- D. `std::function` 永遠會 heap 配置

<details>
<summary>答案</summary>

**B。** 實測第一行輸出 `0 1 1`，第二行 `110`（`operator new` 的呼叫次數）。`int*` 的 lambda 不配置；`NT` 只有 8 bytes，但因為不是 trivially copyable 也配置了；`Big` 是 64 bytes 所以配置。判斷條件不只是大小，這是 libstdc++ 的 SBO 實作細節，libc++ 或 MSVC 不要假設相同。

</details>

---

#### MC35：`[=]` 與 `[m = m]`（C++14）〔L2〕

```cpp
#include <functional>
#include <iostream>
struct S {
  int m = 1;
  std::function<int()> by_this()  { return [=] { return m; }; }
  std::function<int()> by_value() { return [m = m] { return m; }; }
};
int main() {
  S s;
  auto a = s.by_this();
  auto b = s.by_value();
  s.m = 5;
  std::cout << a() << " " << b() << "\n";
}
```

輸出是？（本題用 `-std=c++14`）

- A. `1 1`
- B. `5 5`
- C. `5 1`
- D. `1 5`

<details>
<summary>答案</summary>

**C。** `[=]` 在成員函式中實際捕獲的是 `this`，所以 `a()` 讀到修改後的 `s.m`，得到 5。`[m = m]` 在建立 lambda 時複製一份 `m`，之後的修改看不到，得到 1。實測 `5 1`。C++20 下 `-Wall` 還會對 `[=]` 給 deprecated 警告（見 G1）。

</details>

---

#### MC36：每個 lambda 都有自己的型別〔L2〕

```cpp
#include <iostream>
#include <type_traits>
int main() {
  auto f = [] { return 1; };
  auto g = [] { return 1; };
  static_assert(std::is_same<decltype(f), decltype(g)>::value, "same closure type?");
  std::cout << f() << g() << "\n";
  g = f;
}
```

下列哪一個敘述正確？

- A. `f` 與 `g` 的型別相同，所以 `g = f;` 可以編譯
- B. 每個 lambda 運算式都有獨一無二的 closure type，即使函式本體一模一樣；兩者型別不同，`g = f;` 也不能編譯
- C. 無捕獲的 lambda 不能轉成函式指標
- D. `auto` 會把 lambda 型別抹掉，所以 `decltype(f)` 與 `decltype(g)` 一定相同

<details>
<summary>答案</summary>

**B。** 實測兩件事：`static_assert` 失敗（closure type 不同），`g = f;` 報 `no match for 'operator='`。這也是 `std::function` 存在的原因之一：把不同 closure 統一成同一個型別。`-std=c++11` 與 `c++14` 相同。

</details>

---

#### MC37：建構子中呼叫 `shared_from_this()`〔L3〕

```cpp
#include <iostream>
#include <memory>
struct N : std::enable_shared_from_this<N> {
  N() {
    try { auto p = shared_from_this(); (void)p; std::cout << "ok\n"; }
    catch (const std::bad_weak_ptr&) { std::cout << "bad_weak_ptr\n"; }
  }
};
int main() {
  auto n = std::make_shared<N>();
  auto m = n->shared_from_this();
  std::cout << m.use_count() << "\n";
}
```

在 libstdc++ 上，輸出是？

- A. `ok` 與 `1`
- B. `ok` 與 `2`
- C. `bad_weak_ptr` 與 `2`
- D. 編譯錯誤

<details>
<summary>答案</summary>

**C。** 建構子執行時，還沒有任何 `shared_ptr` 擁有這個物件。C++11/14 的 [util.smartptr.enab] 把 `shared_from_this()` 的前提寫成「`*this` 已被 `shared_ptr` 擁有」，不滿足就是前置條件違反，標準層面不該依賴。libstdc++ 的實作會丟 `std::bad_weak_ptr`，實測如 C。正確做法是物件被 `shared_ptr` 接管之後才呼叫。`-std=c++11` 與 `c++14` 結果相同。

</details>

---

#### MC38：只有 `unique_ptr` 成員的類別〔L2〕

```cpp
#include <memory>
#include <type_traits>
struct Z { std::unique_ptr<int> p; };
static_assert(std::is_move_constructible<Z>::value, "A");
static_assert(!std::is_copy_constructible<Z>::value, "B");
static_assert(std::is_nothrow_move_constructible<Z>::value, "C");
```

關於 `Z`，下列哪一個敘述正確？

- A. `Z` 不能 move，因為沒有宣告 move constructor
- B. `Z` 可以 move、不能 copy，而且 move constructor 是 `noexcept`
- C. `Z` 可以 copy，因為 `unique_ptr` 會自動深拷貝
- D. `Z` 不能放進 `std::vector`

<details>
<summary>答案</summary>

**B。** `Z` 沒有宣告任何特殊成員，編譯器自動生成 move constructor（[class.copy]），而且成員都是 `noexcept` move，所以結果也是 `noexcept`。copy 會被刪除。三個 `static_assert` 都通過。D 錯：move-only 型別可以放進 `vector`。

</details>

---

#### MC39：自己寫了解構子的 `unique_ptr` 類別〔L3〕

```cpp
#include <memory>
#include <utility>
struct D { std::unique_ptr<int> p; ~D() {} };
int main() { D d1; D d2(std::move(d1)); }
```

結果是？

- A. 編譯通過，`d2` 接管了 `p`
- B. 編譯錯誤：選到被刪除的 copy constructor，因為宣告解構子後不會生成 move constructor
- C. 編譯通過，`d2` 是用 copy 建構的
- D. 編譯通過，但 `d1.p` 仍然持有資源，會有兩個 owner

<details>
<summary>答案</summary>

**B。** 自己宣告了解構子，就不會隱式生成 move constructor（[class.copy]）。而 copy constructor 因為 `unique_ptr` 成員而被定義為 deleted，`D d2(std::move(d1));` 會選到它，實測 `use of deleted function 'D::D(const D&)'`。把 `~D() {}` 拿掉後，同一段程式就能編譯（見 G3）。

</details>

---

#### MC40：`constexpr` 函式的兩種呼叫〔L2〕

```cpp
#include <iostream>
constexpr int sq(int x) { return x * x; }
int main() {
  int n = 3;
  int a = sq(n);            // (1)
  constexpr int b = sq(4);  // (2)
  std::cout << a << " " << b << "\n";
}
```

下列哪一個敘述正確？

- A. (1) 和 (2) 都在編譯期計算
- B. (1) 在執行期呼叫，(2) 在編譯期計算；若把 (1) 改成 `constexpr int c = sq(n);`，會編譯錯誤
- C. (1) 和 (2) 都一定在執行期計算，因為 `sq` 有 `constexpr`
- D. (1) 會編譯錯誤

<details>
<summary>答案</summary>

**B。** `constexpr` 函式「可以」在編譯期執行。(1) 的參數 `n` 不是常數，所以是執行期呼叫，完全合法；(2) 的結果必須是編譯期常數，`sq(4)` 滿足。實測輸出 `9 16`，`-std=c++11` 與 `c++14` 相同。改成 `constexpr int c = sq(n);` 時報 `the value of 'n' is not usable in a constant expression`。

</details>

---

#### MC41：`constexpr void` 成員函式〔L3〕

```cpp
struct P {
  int v = 0;
  constexpr void set(int x) { v = x; }
};
int main() { P p; p.set(3); }
```

關於這段程式，下列哪一個敘述正確？

- A. `-std=c++11` 與 `-std=c++14` 都能編譯
- B. `-std=c++11` 不能編譯（`void` 回傳與隱含的 `const`），`-std=c++14` 可以
- C. `-std=c++11` 可以，`-std=c++14` 不行
- D. 兩個標準都不能編譯，因為 `constexpr` 不能用在成員函式

<details>
<summary>答案</summary>

**B。** C++11 的 `constexpr` 函式不能回傳 `void`，而且非 static 成員函式隱含 `const`，所以 `v = x` 會報 `assignment of member 'P::v' in read-only object`。C++14 放寬這兩點（見 Q12）。實測 C++11 失敗、C++14 通過。

</details>

---

#### MC42：`override` 與 `final`〔L2〕

三段程式各自獨立：

```cpp
// (A)
struct B { virtual void f() const {} };
struct D : B { void f() override {} };

// (B)
struct B2 { virtual void g() {} };
struct D2 final : B2 { void g() override {} };
struct E2 : D2 {};

// (C)
struct B3 { virtual void h() {} };
struct D3 : B3 { void h() override final {} };
struct E3 : D3 { void h() override {} };
```

哪些會編譯失敗？

- A. 只有 (A)
- B. 只有 (A) 和 (B)
- C. (A)、(B)、(C) 都會失敗
- D. 三段都能編譯

<details>
<summary>答案</summary>

**C。** (A) `marked 'override', but does not override`，少了 `const`，不是覆寫。(B) `cannot derive from 'final' base`。(C) `overriding final function`。實測三段在 `-std=c++11` 與 `c++14` 都失敗。

</details>

---

#### MC43：`decltype(x)` 與 `decltype((x))`〔L3〕

```cpp
#include <type_traits>
int main() {
  int x = 0;
  static_assert(std::is_same<decltype(x), int>::value, "A");
  static_assert(std::is_same<decltype((x)), int&>::value, "B");
}
```

下列哪一個敘述正確？

- A. `decltype(x)` 與 `decltype((x))` 都是 `int`
- B. `decltype(x)` 是 `int`，`decltype((x))` 是 `int&`
- C. `decltype(x)` 是 `int&`，`decltype((x))` 是 `int`
- D. 兩者都是 `int&`

<details>
<summary>答案</summary>

**B。** 未加括號的名稱，`decltype` 回傳宣告時的型別。加了括號的 `(x)` 是 lvalue 運算式，依 [dcl.type.decltype] 推導成 `int&`。實測兩個 `static_assert` 都通過，`-std=c++11` 與 `c++14` 相同。這也是 Q11 中 `decltype(auto)` 懸空陷阱的根源。

</details>

---

### 選擇題驗證紀錄（2026-10-21）

- 環境：`g++ -std=c++14 -Wall`（MC4、MC24 另用 `-std=c++11` 對照）；MC14、MC15 用 `-fsanitize=address`；MC25 用 `-O2 -pthread`，本機 12 核心。
- 每題的程式碼與輸出都實際執行過，答案裡引用的錯誤訊息與數字都是實測。MC25 的數字每次執行會不同，只代表「會少於 2000000」。
- MC12 的「`std::vector` move construction 後保證為空」引用 C++ 標準對容器的規定，沒有查標準原文，本機只驗證了 libstdc++ 的行為。MC13 的 `auto y{1}` 結果依賴編譯器版本（g++ 5 以上）。

---

### 口頭練習紀錄（2026-11-03，tutor 模式，L1→L2）

用 `auto`/`const`、`std::move`、`unique_ptr`、lambda 四個主題各幾題口頭問答，非逐題對應 MC。

**上次的弱點：**

- `auto` 對 `const` 的處理：`auto a = ci;` 會剝掉最上層 const（答成 `const int`）；`auto&` 與 `decltype` 則保留。描述型別時漏寫 `&`（`auto& z = cr` 的 `z` 是 `const int&`，答成 `const int`）。
- `std::move` 本身只是轉型成右值，搬資料的是 move constructor。答成「搬移 address」只對有堆積資源的型別成立；短字串走 SSO，搬移後 `data()` 指標不同（本機實測：`"hello"` 不同、100 字元相同）。對 `const` 物件 `std::move` 會悄悄退化成 copy（答對）。
- `unique_ptr` 被 move 後保證是 null（答成 undefined）；`*p` 才是 UB。
- lambda 語法一開始不熟（`[]` 捕獲列表、`[x]` 複製 vs `[&x]` 參考），L1 補完後能推出回傳區域變數參考的懸空問題與 `mutable` 去掉的是 `operator()` 的 `const`。
- 傾向只給結果、不寫理由，容易混的題要請他一句話寫出為什麼。

**答對：** `auto` 型別推導（MC1 對應）、`auto&` 保留 const、copy 與綁定的輸出預測、`unique_ptr` 不可複製與 `std::move` 轉移所有權、lambda 值捕獲 vs 參考捕獲、`mutable` lambda 輸出 `3 0`。

**複習輪（2026-11-05，回顧上述前三個弱點）：**

- `auto` 與 const（已用 g++ `static_assert` 驗證）：`const int ci; const int& cr = ci;` 下 `auto a = ci` 答對 `int`；`auto& b = ci` 漏 `&`（應為 `const int&`）；`auto c = cr` 答成 `int&`（應為 `int`，`auto` 先剝 `&` 再剝頂層 const）；`decltype(cr) d` 答對 `const int&`。追問 `const int* p; auto q = p;` 答成 `int*`（應為 `const int*`，底層 const 不剝）；`int* const pc; auto r = pc;` 的 `r` 答對 `int*`，但答成 `*r = 1` 不能編譯（兩行都能編譯，把 `r` 當成 `pc`）。
- `std::move`：仍先答「move address」（錯，它只是轉型）；搬資料的是 move constructor（答對）。SSO 在兩層提示後推出長字串 move 位址相同（對），但短字串答成位址相同（應為不同，字元複製到 `s2` 自己的內部 buffer）。
- `unique_ptr` move 後：答對是 null、`if (p)` 為 false、`*p` 是 UB；但答成 `p.get()` 是 UB（應為回傳 `nullptr`），且把 `*p` 的原因說成 dangling（應為解參考 null，dangling 是指向已釋放物件）。
- 本輪每題都有附理由，有進步；但理由常只講類別（「because short string」），沒推導。
- 三塊都還沒穩，下一個 session 開頭再抽問：頂層 vs 底層 const、`auto` 剝 `&`、SSO move 的位址、null vs dangling。

**新主題（2026-11-05，先教再考）：G1 lambda 與隱式 `this`、G2 `shared_ptr` 循環與 `weak_ptr`**（程式碼均已用 g++ 實跑）

- G1：`[=]{ return ++n; }`（`n` 是成員）答對印出 `2`，並知道改的是 `this->n`；但把原因說成「改了 this 指標」（應為：捕獲的是 `this` 指標，`operator()` 的 const 只擋指標本身，指向的物件不是 const，所以 `++n` 能過，與頂層 const 同一概念）。懸空題答對（物件已解構，`this` dangling，UB）。改成不依賴 `this`：能說出要 init capture 加 `mutable`，但寫成 `[m=m]`（抄範例變數名，應為 `[n = n]() mutable { return ++n; }`）。實測：`f()` 得 `1 2`、`c.n` 仍為 0；不加 `mutable` 報 `increment of read-only variable 'n'`。
- G2：A/B 循環參考印出 `22` 無解構（答對，理由為 count 不為 0）；`B::a` 改 `weak_ptr` 後印 `12`，輸出 `~A`、`~B`（順序答對，但需補推導：決定順序的是 count 何時歸零，不是宣告順序）。`lock()` 之後 `p` 為空、`if (p)` 為 false（答對）；答不出為什麼不能直接 `*w`（缺：`lock()` 回傳 `shared_ptr` 讓物件在使用期間保活，`weak_ptr` 沒有 `operator*`，`expired()` 後再用在多執行緒下有競態）。
- 這輪的錯多是抄寫對照不仔細與「只給結果、理由只講類別」，不是觀念空白。下一輪抽問：G1 的 `this` 捕獲與頂層 const 的關係、`weak_ptr::lock()` 的設計理由。
- G3（Rule of Zero，先教再考）：`struct D { unique_ptr<int> p; ~D(){} }; D d2(std::move(d1));` 答對不能編譯；原因的第二句說成「destructor can't be moved」（應為：自己宣告 destructor 就不隱式生成 move ctor，右值退到 copy ctor，而 copy 因 `unique_ptr` 是 deleted）。修法一：刪掉 `~D()`（答對，未附理由）。修法二：第一次答「不知道」，給 `= default` 提示後先寫成 `~D(const&)=default`（destructor 不能有參數，`const&` 是 copy），第二層提示後寫出 `D(D&&) = default;` 並正確說明理由。實測：只加 move ctor 時，`d3 = std::move(d2)` 仍報 `use of deleted function 'D::operator=(const D&)'`，要連 `D& operator=(D&&) = default;` 一起寫才過（宣告 move ctor 會讓 move assignment 不再隱式生成）。
- **L2-4（RegBank 改 Rule of Zero）已出題、Alan 尚未交稿**。已給第一層提示（`std::vector<uint32_t>(n)` 自動填 0）；待他貼稿 review，不先給解。review 時問他：為什麼頂部四個 `static_assert`（move-only、noexcept）不用自己寫任何東西就會通過。

**下一輪可以加考：** 上次的四項已轉成題目：lambda `[=]` 與隱式 `this`（MC35、MC36、Q16、G1）、`shared_ptr` 循環與 `weak_ptr`（L2-3、Q17、MC37、G2）、Rule of Zero（L2-4、MC38、MC39、Q18、G3）、`std::function` 開銷（MC34、Q19、G4）。下一輪口頭先問 MC35、MC39、Q16、Q19 各一題，不先給答案；E1、E2 等 Alan 交稿後再 review。MC29、MC33、Q20 是 forwarding 與 noexcept 的補強，可排在 Q4、Q5 之後。

---

## 問答題與手寫題（從這裡開始）

下面是 L1–L2 的問答 / 動手題（第零模組），以及 L3–L4 的面試問答與白板題（第一模組以後）。選擇題熟了再做這一段。

---

## 第零模組：L1 入門 與 L2 應用

先從這裡開始。L1 是「看懂為什麼」，每題附提示，先自己想再看答案；L2 給程式碼，要你預測輸出、找錯或動手改。這一段的程式碼都在本機用 `g++ -std=c++14` 實際編譯、執行過，輸出以實測為準（驗證紀錄在文末）。

### L1-1：`auto` 與 range-based `for`：什麼時候會偷偷複製？〔L1〕

```cpp
std::vector<std::string> names{"a", "b"};
auto n1 = names[0];
auto& n2 = names[0];
const auto& n3 = names[0];

for (auto s : names)  s += "!";
for (auto& s : names) s += "!";
```

1. `n1`、`n2`、`n3` 的型別各是什麼？哪一個是複製？
2. 兩個 `for` 跑完，`names` 的內容各變成什麼？
3. 為什麼 `auto` 會「丟掉」`const` 和參考？只想讀取每個元素時，迴圈該怎麼寫？

<details>
<summary>提示</summary>

- `auto` 推導的規則跟「值傳遞的函式參數」一樣：頂層的 `const` 和 `&` 會被丟掉。
- 想要參考就自己寫 `&`；想要唯讀就自己寫 `const`。

</details>

<details>
<summary>參考答案</summary>

1. `n1` 是 `std::string`（**複製**）、`n2` 是 `std::string&`、`n3` 是 `const std::string&`。
2. 第一個迴圈的 `s` 是每個元素的**複本**，改的是複本，`names` 仍是 `a`、`b`。第二個迴圈的 `s` 是參考，之後 `names` 變成 `a!`、`b!`。
3. `auto` 的目的是「得到一個新的物件」，所以會去掉 `const` 和 `&`；你要的語意要自己寫出來。只讀的迴圈用 `for (const auto& s : names)`，避免複製大物件；元素是 `int` 這類小型別時，`for (auto x : v)` 就可以。

延伸：`std::vector<bool>` 的 `operator[]` 回傳 proxy 物件，`auto b = v[0]` 拿到的不是 `bool`。看到 `auto` 行為奇怪時先想 proxy。

</details>

---

### L1-2：`nullptr`、`enum class`、`override`：它們各自在防什麼？〔L1〕

下面三段程式都能編譯（或只有警告），指出各自藏的問題，並說明 C++11 的哪個關鍵字能擋掉：

```cpp
// (a)
void f(int);
void f(char*);
f(NULL);

// (b)
enum Color { RED, GREEN };
enum Light { RED, YELLOW };   // 兩個 enum 都想用 RED

// (c)
struct Base { virtual void f() const; };
struct Derived : Base { void f(); };   // 想覆寫 Base::f
```

<details>
<summary>提示</summary>

- (a) `NULL` 本質上是整數 0。想一想 `0` 能轉成什麼。
- (b) 傳統 `enum` 的名稱放在哪個作用域？它能不能被當成 `int` 用？
- (c) `Derived::f` 跟 `Base::f` 的簽名完全一樣嗎？

</details>

<details>
<summary>參考答案</summary>

- (a) `NULL` 是整數常數，`f(NULL)` 在 GCC 上實測是 **ambiguous（不明確）編譯錯誤**；在別的編譯器或把 `NULL` 換成 `0` 時，則會悄悄呼叫 `f(int)`，而你想呼叫的是指標版本。改用 `nullptr`（型別 `std::nullptr_t`，只能轉成指標）：`f(nullptr)` 一定選 `f(char*)`。
- (b) 傳統 `enum` 的列舉值洩漏到外層作用域，`RED` 重複定義，GCC 實測報 `'RED' conflicts with a previous declaration`；它也能隱含轉成 `int`，所以 `RED == RED2` 這種跨 enum 比較只會得到警告。改用 `enum class Color { RED, GREEN };`：名稱在 `Color::` 底下，且不會隱含轉成整數，要轉就 `static_cast<int>`。
- (c) `Base::f` 是 `const` 成員函式，`Derived::f` 不是，簽名不同，所以 `Derived::f` 是**另一個新函式**，把 `Base::f` 藏起來而不是覆寫。實測 `-Wall -Wextra` 完全沒有警告。在 `Derived::f` 後面加 `override`，編譯器就會報 `marked 'override', but does not override`。

共通觀念：這三個特性都是把「你的意圖」寫進程式，讓編譯器替你檢查。

</details>

---

### L1-3：左值、右值，以及 `std::move` 到底做了什麼？〔L1〕

```cpp
std::string s = "hello";
const std::string cs = "const";
std::string a = std::move(s);
std::string b = std::move(cs);
std::string t = "keep";
std::move(t);
```

1. 用一句話說明左值與右值的差別。
2. `std::move` 本身有沒有搬移任何資料？
3. 這 3 行執行完，`s`、`cs`、`a`、`b`、`t` 各是什麼？`cs` 為什麼是那個結果？

<details>
<summary>提示</summary>

- `std::move` 是一個函式，看它的回傳型別（`T&&`）想一想它只做什麼。
- 真正搬資料的是 move constructor。它能不能接受 `const std::string&&`？

</details>

<details>
<summary>參考答案</summary>

1. 左值有名字、有固定位址、可以取址（`s`）；右值是即將消失的暫時值（`std::string("x")`、函式回傳的暫存物件）。一般的規則：能對它取 `&` 的就是左值。
2. **沒有。** `std::move` 只做一件事：把引數 `static_cast` 成右值參考（`T&&`），告訴編譯器「這個物件可以被搬走」。真正搬資料的是接到右值之後被選中的 move constructor / move assignment。單獨一行 `std::move(t);` 什麼事都沒有，`t` 仍是 `keep`。
3. 實測（libstdc++）：`a = hello`、`s` 變成空字串、`b = const`、`cs` **仍是 `const`**、`t = keep`。`cs` 是 `const`，`std::move(cs)` 得到 `const std::string&&`，move constructor 的參數 `std::string&&` 收不下，只好選 copy constructor `const std::string&`。所以「對 `const` 物件 `std::move`」會悄悄變成複製。

注意：標準只保證 moved-from 的物件處於「有效但未指定」的狀態。`s` 在 GCC 上剛好是空的，但不要依賴；只能對它賦值或解構。

</details>

---

### L1-4：`unique_ptr` 基本用法與所有權轉移〔L1〕

```cpp
struct W { void use(); };
void take(std::unique_ptr<W> p);
std::unique_ptr<W> make();

auto p = std::make_unique<W>();
auto q = p;                    // (1)
auto r = std::move(p);         // (2)
take(r);                       // (3)
take(std::move(r));            // (4)
auto w = make();               // (5)
p->use();                      // (6)
```

1. 這六行哪些編譯不過？為什麼？
2. 編譯得過但有問題的是哪一行？問題是什麼？
3. `get()`、`release()`、`reset()` 各自做什麼？哪一個會讓你自己負責 `delete`？

<details>
<summary>提示</summary>

- `unique_ptr` 的 copy constructor 是 `= delete`。
- 被 `std::move` 走之後的 `unique_ptr` 是什麼值？

</details>

<details>
<summary>參考答案</summary>

1. (1) 和 (3) 編譯錯誤，實測是 `use of deleted function ... unique_ptr(const unique_ptr&)`：獨佔所有權不能複製；(3) 是以傳值把 `r` 複製進參數。(2)、(4)、(5) 都是轉移所有權，合法；(5) 回傳暫時值本來就是 move，（且通常被省略，見 L2-1）。
2. (6) 能編譯，執行時 `p` 在 (2) 被搬走已經是 `nullptr`，`p->use()` 是 **null pointer dereference（未定義行為）**。編譯器不會警告。規矩：被 `std::move` 走的智慧指標就當它已經失效，除非重新賦值。
3. `get()` 回傳裸指標但**不放棄**所有權（只給人暫時借用，別拿去 `delete`）；`release()` **放棄**所有權並回傳裸指標，之後由你負責 `delete`；`reset(p)` 釋放目前持有的物件並改持有 `p`，`reset()` 等於釋放並設成 `nullptr`。

</details>

---

### L2-1：預測輸出：copy / move 的建構與解構順序〔L2〕

先在紙上寫出完整輸出，再展開答案對照。

```cpp
struct T {
  std::string n;
  explicit T(std::string s) : n(std::move(s)) { std::cout << "ctor " << n << "\n"; }
  T(const T& o) : n(o.n + "'") { std::cout << "copy " << o.n << " -> " << n << "\n"; }
  T(T&& o) noexcept : n(std::move(o.n)) { std::cout << "move -> " << n << "\n"; o.n = "(moved)"; }
  T& operator=(const T& o) { std::cout << "copy= " << o.n << " -> " << n << "\n"; n = o.n; return *this; }
  T& operator=(T&& o) noexcept { std::cout << "move= " << o.n << " -> " << n << "\n"; n = std::move(o.n); o.n = "(moved)"; return *this; }
  ~T() { std::cout << "dtor " << n << "\n"; }
};
T make() { T t("m"); return t; }
void take(T t) { std::cout << "in take " << t.n << "\n"; }

int main() {
  T a("a");
  T b = a;
  T c = std::move(a);
  b = c;
  c = std::move(b);
  T d = make();
  take(std::move(d));
  const T e("e");
  T f = std::move(e);
  std::cout << "end\n";
}
```

特別回答：(1) `make()` 那行有沒有 copy 或 move？(2) `const T e` 被 `std::move` 後是哪個建構子？(3) 最後的解構順序為什麼是那樣？

<details>
<summary>提示</summary>

- 區域變數的解構順序，跟宣告順序相反。
- `T d = make();` 想一想回傳值最佳化（copy elision）。
- 物件的 `n` 欄位會被改名，輸出裡出現的名字要追蹤「現在這個物件叫什麼」。

</details>

<details>
<summary>參考答案</summary>

編譯指令 `g++ -std=c++14`，實測輸出：

```
ctor a              # T a("a")
copy a -> a'        # T b = a
move -> a           # T c = std::move(a)，a 被改成 (moved)
copy= a -> a'       # b = c（b 的 n 是 a'，c 的 n 是 a）
move= a -> a        # c = std::move(b)
ctor m              # make() 裡的 t，直接建在 d 的位置
move -> m           # take(std::move(d))：參數 t 用 move 建構
in take m
dtor m              # take 結束，參數解構
ctor e
copy e -> e'        # T f = std::move(e)：e 是 const
end
dtor e'             # f
dtor e              # e
dtor (moved)        # d
dtor a              # c
dtor (moved)        # b
dtor (moved)        # a
```

1. **沒有**。`T d = make();` 沒有 copy / move 輸出，因為 `return t;` 被 NRVO 省略，`t` 直接建在 `d` 的位置（C++14 是允許省略、GCC 預設會做；C++17 起，回傳的暫時值省略是保證的）。`-fno-elide-constructors` 可以關掉看差別。
2. 是 copy constructor（`copy e -> e'`），因為 `std::move(e)` 是 `const T&&`，move constructor 收不下（對應 L1-3）。
3. 同一 scope 的區域變數按宣告的**相反順序**解構：`f, e, d, c, b, a`。每個 dtor 印的是「該物件當下的 `n`」：`f` 是 `e'`，`d` 被搬走所以是 `(moved)`，`c` 最後拿到 `a`，`b`、`a` 都被搬空。

</details>

---

### L2-2：找錯：lambda 捕獲的懸空參考〔L2〕

```cpp
std::function<int()> make_counter() {
  int count = 0;
  return [&count]() { return ++count; };
}

int main() {
  auto c = make_counter();
  int r1 = c();   // 拆成獨立語句，不依賴 << 串接的求值順序
  int r2 = c();
  std::cout << r1 << " " << r2 << "\n";
}
```

1. 這段程式有什麼問題？執行會發生什麼事？
2. 為什麼編譯器不報錯？
3. 給出兩種修法，並說明各自的語意差別。

<details>
<summary>提示</summary>

- `count` 在 `make_counter` 回傳之後還活著嗎？
- 修法一：改變捕獲方式。修法二：把狀態放進 lambda 自己（C++14 init capture，見 Q8）。

</details>

<details>
<summary>參考答案</summary>

1. lambda 以參考捕獲區域變數 `count`，`make_counter` 返回後 `count` 的 stack 空間已失效，`c()` 讀寫的是**懸空參考（dangling reference）**，屬於未定義行為。本機實測直接 segmentation fault；用 `-fsanitize=address` 並設定 `ASAN_OPTIONS=detect_stack_use_after_return=1`，會報 `stack-use-after-return`。「剛好跑出 1 2」也是 UB 可能的表現，不代表正確。
2. 編譯器只看語法與型別：`[&count]` 是合法語法，lambda 也確實合法回傳。它不分析參考會不會比被參考的物件活得更久，需要靠 sanitizer 或 code review 抓。
3. 修法：
   - **值捕獲 + `mutable`**：`return [count]() mutable { return ++count; };`，lambda 內有自己的一份 `count`，每個 `std::function` 複本各有各的計數。
   - **C++14 init capture**：`return [count = 0]() mutable { return ++count; };`，寫法最乾淨，不需要區域變數。

   若真的要多個 lambda 共用同一個計數，改成 `std::shared_ptr<int>` 捕獲；不要用 `[&]` 把區域變數借出去。

   經驗規則：lambda 會離開目前 scope（回傳、存進成員、丟給別的 thread）就不要用參考捕獲。

</details>

---

### L2-3：找錯：`shared_ptr` 循環參考〔L2〕

```cpp
struct B;
struct A { std::shared_ptr<B> b; ~A() { std::cout << "~A\n"; } };
struct B { std::shared_ptr<A> a; ~B() { std::cout << "~B\n"; } };

int main() {
  {
    auto a = std::make_shared<A>();
    auto b = std::make_shared<B>();
    a->b = b;
    b->a = a;
    std::cout << a.use_count() << " " << b.use_count() << "\n";
  }
  std::cout << "after scope\n";
}
```

1. 預測輸出，`~A`、`~B` 會不會印出來？
2. 改哪裡可以修好？修好之後 `use_count()` 會印什麼？
3. 用什麼工具可以抓到這類問題？

<details>
<summary>提示</summary>

- `a`、`b` 離開 scope 時各自減 1，物件的 count 會歸零嗎？
- 把迴圈裡「不擁有」的那一邊改成 `weak_ptr`。

</details>

<details>
<summary>參考答案</summary>

1. 實測輸出：

   ```
   2 2
   after scope
   ```

   `~A`、`~B` **都沒有印**。每個物件的 count 都是 2（區域變數 + 對方的成員）。離開 scope 時區域變數各減 1，兩邊都剩 1，彼此持有對方，永遠不會歸零，造成**記憶體洩漏**。
2. 把「反向」那邊改成 `std::weak_ptr`，例如 `struct B { std::weak_ptr<A> a; ... };`。修好後實測輸出（題目 `main` 只印兩個數字，所以對應的是 `1 2`）：

   ```
   1 2
   ~A
   ~B
   after scope
   ```

   `a.use_count()` 是 1（`weak_ptr` 不計入 strong count），`b.use_count()` 是 2（區域變數與 `a->b`）。若另外加印 `b->a.use_count()`，實測是 1。離開 scope 時區域變數反向銷毀：`b` 先離開（count 由 2 變 1），`a` 歸零釋放（`~A`），釋放 `A::b` 之後 `b` 指向的物件也歸零（`~B`）。
3. LeakSanitizer：用 `g++ -fsanitize=address` 編譯，程式結束時會報 `LeakSanitizer: detected memory leaks`（實測有抓到）；valgrind 的 `--leak-check=full` 也可以。設計上先想「誰擁有誰」：有明確的擁有者用 `unique_ptr`，從屬方用裸指標或 `weak_ptr`。

</details>

---

### L2-4：動手題：改成 Rule of Zero〔L2〕

這題是動手練習，只給規格和測試，不提供完成版。請自己改完，編譯、跑過測試，再貼上來我看。

**規格**

下面的 `RegBank` 是手寫資源管理的舊版：用 `new[]` 管暫存器陣列、用裸指標管 `Logger`，而且 destructor 忘了釋放 `Logger`（leak）。請把它改成 **Rule of Zero**：

1. 成員改成 `std::vector<uint32_t>`、`std::string`、`std::unique_ptr<Logger>`。`size()` 由 `regs_` 推得（回傳 `regs_.size()`），不要另存 `n_`；另存的話，moved-from 物件的 `a.size()` 不會是 0，測試會失敗。
2. 類別裡**不要自己宣告**任何 destructor、copy / move constructor、copy / move assignment。
3. 對外介面（`write`、`read`、`size`、`name`、建構子）不變。
4. 改完以後測試要全部通過，包含 AddressSanitizer / UBSan 乾淨。

**起始程式碼與測試**（存成 `r0_test.cpp`）

```cpp
// g++ -std=c++14 -Wall -Wextra -fsanitize=address,undefined r0_test.cpp -o r0 && ./r0
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

struct Logger {
  static int live;
  Logger()  { ++live; }
  ~Logger() { --live; }
};
int Logger::live = 0;

// ---- 舊版：請重寫 ----
class RegBank {
 public:
  RegBank(std::size_t n, const std::string& name)
      : regs_(new uint32_t[n]()), n_(n), name_(name), log_(new Logger) {}
  ~RegBank() { delete[] regs_; }  // 忘了 delete log_

  void write(std::size_t i, uint32_t v) { regs_[i] = v; }
  uint32_t read(std::size_t i) const { return regs_[i]; }
  std::size_t size() const { return n_; }
  const std::string& name() const { return name_; }
 private:
  uint32_t* regs_;
  std::size_t n_;
  std::string name_;
  Logger* log_;
};

// ---- 測試（不要改） ----
static_assert(!std::is_copy_constructible<RegBank>::value, "RegBank 應為 move-only");
static_assert(!std::is_copy_assignable<RegBank>::value, "RegBank 應為 move-only");
static_assert(std::is_nothrow_move_constructible<RegBank>::value, "move ctor 應為 noexcept");
static_assert(std::is_nothrow_move_assignable<RegBank>::value, "move assign 應為 noexcept");

int main() {
  {
    RegBank a(4, "uart");
    a.write(1, 0xABCD);
    RegBank b(std::move(a));
    assert(b.read(1) == 0xABCD && b.size() == 4 && b.name() == "uart");
    assert(a.size() == 0);          // moved-from：空
    assert(Logger::live == 1);      // 只剩 b 擁有的那一個

    RegBank c(2, "spi");
    assert(Logger::live == 2);
    c = std::move(b);               // c 原本的資源必須被釋放
    assert(Logger::live == 1);
    assert(c.size() == 4 && c.name() == "uart");

    std::vector<RegBank> v;
    v.push_back(std::move(c));
    v.emplace_back(8, "dma");
    assert(v.size() == 2 && Logger::live == 2);
  }
  assert(Logger::live == 0);        // 離開 scope 後沒有 leak
  std::cout << "all passed\n";
}
```

**提示**

- 舊版目前編譯就失敗（`static_assert`）。從哪一行失敗，可以看出缺了什麼。
- 改完之後想一想：為什麼不用寫任何特殊成員，move 操作也自動是 `noexcept`？每個成員的 move 各自是什麼性質？
- 想一想：為什麼 `RegBank` 變成 move-only？如果業務需要可複製，要怎麼辦（Rule of Five，見 C1）？
- `assert(a.size() == 0)`：moved-from 的 `std::vector` 為什麼是空的？

**驗收**：`all passed`，且 sanitizer 沒有任何報告。

---

## 第一模組：記憶體管理與智慧指標

### Q1：`unique_ptr`、`shared_ptr`、`weak_ptr` 的核心機制與所有權語意〔L3〕

1. 三種智慧指標的所有權（ownership）語意分別為何？在什麼情境下選用哪一個？
2. `shared_ptr` 的 Control Block 內部包含哪些欄位？copy 和 move 一個 `shared_ptr` 分別會付出什麼成本？
3. `weak_ptr` 如何解決循環引用（circular reference）？使用 `weak_ptr` 存取物件時為何必須呼叫 `.lock()`？

<details>
<summary>參考答案</summary>

**1. 所有權語意與選用情境**
- `std::unique_ptr`：**獨佔所有權（Exclusive Ownership）**。禁止 Copy（copy constructor/assignment 為 `= delete`），只允許 Move。零執行期負擔（Zero-overhead abstraction，不自訂 deleter 時大小等同裸指標）。**預設優先選用**（例如 factory function 回傳物件、物件內部的私有成員資源管理）。
- `std::shared_ptr`：**共享所有權（Shared Ownership）**。透過 Reference Counting 管理生命週期，最後一個持有者解構時釋放託管資源。適用於生命週期不明確、或多個獨立模組共同持有且無明確從屬關係的物件（例如 shared cache、bus interconnect 的共用 routing table）。
- `std::weak_ptr`：**弱引用 / 不擁有所有權（Non-owning Reference）**。不增加 strong reference count，不阻止受管物件被銷毀。用於觀察者模式（Observer pattern）、快取（Cache）、打破循環引用。

**2. Control Block 結構與操作成本**
Control Block 包含：
- **Strong Reference Count**（`std::atomic<long>`，決定受管物件何時解構）。
- **Weak Reference Count**（`std::atomic<long>`，決定 Control Block 本身何時被 `free`）。
- **Custom Deleter**（若有指定）。
- **Custom Allocator**（若有指定）。
- （若使用 `std::make_shared`，受管物件本身也直接內嵌在 Control Block 記憶體中）。

指標結構與成本：
- `sizeof(std::shared_ptr)` 在 64-bit 下為 **16 bytes（2 個指標）**：一個指向受管物件（Stored Pointer，用於 `*` 與 `->`），另一個指向 Control Block。
- **Aliasing Constructor**：允許指標指向物件的某個成員，而 Control Block 守護整個父物件生命週期（`std::shared_ptr<Member>(parent_ptr, &parent_ptr->member)`）。
- **Copy `shared_ptr`**：需要 atomic increment strong ref count（跨核心快取一致性開銷，比一般暫存器操作昂貴）。
- **Move `shared_ptr`**：將指標與 control block 指標移交給新物件，並將原物件清空為 `nullptr`。**不修改原子計數**，成本幾乎等同指標賦值，遠低於 copy。
- **執行緒安全邊界**：原子計數保證 Reference Counting 本身 thread-safe，但**同一個 `shared_ptr` 實例的並行讀寫並非 thread-safe**（需透過 `std::atomic_load/store` 自由函式）；指向之物件內部方法的並行存取亦非 thread-safe。
**3. 循環引用與 `.lock()` 機制**
- 若兩個物件彼此以 `shared_ptr` 互相指向，strong count 永遠 $\ge 1$，導致 destructor 永遠不會被觸發，造成記憶體洩漏。將其中一方改為 `weak_ptr` 即可打破依賴鏈。
- **為何需要 `.lock()`**：`weak_ptr` 不保證物件存活。`.lock()` 以原子方式檢查 strong count：若物件仍存活，則原子增加 strong count 並回傳合法的 `std::shared_ptr<T>`；若已被釋放，則回傳空 `shared_ptr`。這防止了「檢查時物件還在，正要存取時卻在另一 thread 被解構」的 TOCTOU（Time-of-check to time-of-use）Race Condition。

</details>

**上次的弱點：** 尚未考過。

---

### Q2：`std::make_shared` vs `std::make_unique` 的底層配置差異與陷阱〔L4〕

1. 比較 `std::shared_ptr<T>(new T())` 與 `std::make_shared<T>()` 在記憶體配置上的差異與優缺點。
2. 搭配 `std::weak_ptr` 時，`std::make_shared` 可能導致什麼潛在的記憶體問題？
3. 為什麼 C++11 有 `std::make_shared` 卻沒有 `std::make_unique`？C++14 補上它的主要原因是什麼？

<details>
<summary>參考答案</summary>

**1. 記憶體配置差異**
- `shared_ptr<T>(new T())`：**兩次獨立 heap 配置**。第一次是 `new T`，第二次是配置 Control Block。缺點是配置開銷大、破壞 CPU cache locality、可能在函式引數求值時發生 exception 導致記憶體洩漏（C++17 前求值順序未完全嚴格定義）。
- `std::make_shared<T>()`：**一次連續 heap 配置**。將 `sizeof(T)` 與 Control Block 打包在同一塊記憶體中配置。優點是配置速度快、記憶體局部性佳、保證 exception safety。

**2. `weak_ptr` 導致的延遲釋放陷阱**
- 因為 `make_shared` 將物件與 Control Block 分配在同一塊 heap block：
  - 當 strong count 降為 0 時，會呼叫 `T` 的 destructor。
  - 但是，**整塊 heap 記憶體必須等到 weak count 也降為 0 時才會被 `free()` 歸還給系統**！
- 若 `T` 是非常龐大的物件（例如 50MB 的 memory model buffer），而有一個長生命週期的 `weak_ptr` 仍然指著它，儘管物件已解構，那 50MB 記憶體直到 `weak_ptr` 銷毀前都無法被釋放。此時應改用 `shared_ptr<T>(new T())`。

**3. 歷史原因與 C++14 `std::make_unique` 的價值**
- C++11 漏掉純粹是標準委員會的疏忽（遺漏提案），而非技術不可行。
- C++14 補上 `std::make_unique` 的兩大原因：
  1. **Exception Safety**：在 C++17 之前，若呼叫 `f(std::unique_ptr<T>(new T()), g())`，編譯器可能先 `new T()`，再執行 `g()`，若 `g()` 丟出 exception，`T` 就洩漏了。使用 `f(std::make_unique<T>(), g())` 則絕對安全。
  2. **避免裸 `new`**：符合 Modern C++ 的理念（No naked `new`），代碼更乾淨且不必重複型別名稱。
- **`std::make_shared` 的三大固有缺陷（面試常見追問）**：
  1. **無法自訂 Deleter**：`make_shared` 無法指定 custom deleter，需要自訂釋放邏輯時必須用 `shared_ptr(p, deleter)`。
  2. **無法存取私有建構子**：若 class 建構子為 `private`（如 Singleton 或 Factory），`make_shared` 在外部無法建構。**把 `friend std::make_shared<T>()` 加進 class 不可行**：`make_shared` 是由 allocator 呼叫 `T` 的建構子，友元宣告不會延伸到它（本機 g++ 11 `-std=c++14` 實測報 `T::T() is private`）。可行的做法有兩種：
     - **Passkey Idiom（保留單次配置）**：建構子仍是 public，但第一個參數是只有 `Widget` 能建立的 `Key`，工廠函式內以 `std::make_shared<Widget>(Key(), v)` 建立。最小示範（`-std=c++14 -Wall -Wextra -fsanitize=address,undefined` 編譯執行通過）：
       ```cpp
       #include <cassert>
       #include <memory>
       #include <iostream>
       class Widget {
        public:
         class Key {                       // Passkey：只有 Widget 能建立 Key
           Key() {}
           friend class Widget;
          public:
           Key(const Key&) = default;
         };
         // 建構子是 public，但需要 Key 參數，外部拿不到 Key 就無法呼叫
         explicit Widget(Key, int v) : v_(v) {}
         static std::shared_ptr<Widget> create(int v) {
           return std::make_shared<Widget>(Key(), v);   // 單次配置
         }
         int value() const { return v_; }
        private:
         int v_;
       };
       int main() {
         auto w = Widget::create(42);
         assert(w->value() == 42 && w.use_count() == 1);
         // Widget bad(Widget::Key(), 1);  // 外部無法取得 Key() 的 private 建構子
         std::cout << "passkey ok: " << w->value() << "\n";
       }
       ```
     - **Static factory + `new`**：`static std::shared_ptr<T> create(int v) { return std::shared_ptr<T>(new T(v)); }`（同樣可編譯通過）。代價是失去 `make_shared` 的單次配置：物件與 Control Block 變成兩次獨立 heap 配置，記憶體局部性較差，兩塊記憶體也無法再一起釋放（與第 2 點 weak_ptr 陷阱的取捨相反）。
  3. **動態陣列支援**：C++14 引入了 `std::make_unique<T[]>(size)`，但 `std::make_shared<T[]>` 直到 **C++20** 才被納入標準。
</details>

**上次的弱點：** 尚未考過。

---

### Q3：Custom Deleter 在 `unique_ptr` 與 `shared_ptr` 的設計差異〔L4〕

1. 說明 `std::unique_ptr` 與 `std::shared_ptr` 在指定自訂刪除器（Custom Deleter）時的語法與型別簽章差異。
2. 為什麼兩者的設計不同？這對物件大小（`sizeof`）與執行期多型有什麼影響？

<details>
<summary>參考答案</summary>

**1. 型別簽章與語法差異**
- `std::unique_ptr<T, Deleter>`：Deleter 是 **template 型別參數的一部分**。
  ```cpp
  auto file_deleter = [](FILE* fp) { if (fp) fclose(fp); };
  std::unique_ptr<FILE, decltype(file_deleter)> u_fp(fopen("test.txt", "r"), file_deleter);
  ```
- `std::shared_ptr<T>`：Deleter **不是 template 型別參數**，僅在建構函式傳入。
  ```cpp
  std::shared_ptr<FILE> s_fp(fopen("test.txt", "r"), [](FILE* fp) { if (fp) fclose(fp); });
  ```

**2. 設計哲學與底層影響**
- **`unique_ptr` 追求零開銷（Zero Overhead）**：
  - 刪除器被靜態綁定在型別中，通常以 Empty Base Optimization (EBO) 儲存無狀態（stateless）的 functor/lambda。
  - 若 deleter 是無狀態的，`sizeof(unique_ptr)` 等同於裸指標（8 bytes in 64-bit）。且呼叫 deleter 時可直接 inline，沒有 indirect call 開銷。
  - **C++11/C++14 Lambda Deleter 陷阱**：在 C++11/C++14 中，無狀態 lambda 仍無 default constructor（C++20 才放寬），因此宣告 `unique_ptr<FILE, decltype(file_deleter)> u_fp(fp, file_deleter);` 時**第二個參數實體不能省略**。
  - **函式指標 Deleter 陷阱**：若宣告為 `unique_ptr<FILE, decltype(&fclose)> u_fp(fp, fclose);`，Deleter 佔 8 bytes 且無法使用 EBO，導致 `sizeof(unique_ptr)` 膨脹為 **16 bytes** 且無法 inline。零開銷最佳解是使用無狀態 struct functor：
    ```cpp
    struct FileCloser { void operator()(FILE* fp) const { if (fp) fclose(fp); } };
    std::unique_ptr<FILE, FileCloser> u_fp(fopen("test.txt", "r")); // sizeof == 8 bytes, auto-inline
    ```
  - 代價是型別不同就無法放入同一個 container 或相互賦值。
- **`shared_ptr` 採用型別擦除（Type Erasure）**：
  - 刪除器儲存在 Control Block 內部（以函式指標或虛擬函式封裝）。
  - 無論自訂刪除器是什麼型別，指標本身的型別永遠是 `std::shared_ptr<T>`，可以任意放入 `std::vector<std::shared_ptr<T>>` 或互相賦值。
  - `std::shared_ptr<void>` 可藉由 Control Block 內擦除的 deleter 正確呼叫解構；但 `std::unique_ptr<void>` 是確定的編譯錯誤（實測 `can't delete pointer to incomplete type`，來自 `default_delete` 的 static_assert）。
  - 代價是 Control Block 較大，且觸發釋放時存在 indirect function call 開銷。
</details>

**上次的弱點：** 尚未考過。

---

## 第二模組：Move Semantics、右值與生命週期

### Q4：值類別（Value Categories）、`std::move` 與 `std::forward`〔L3〕

1. 簡述 C++11 的三大核心值類別：lvalue、prvalue、xvalue。
2. `std::move(x)` 到底做了什麼？它會在執行期搬移任何位元組嗎？
3. 何謂 Universal Reference（或 C++ 標準稱的 Forwarding Reference `T&&`）？`std::forward` 如何實現完美轉發（Perfect Forwarding）？

<details>
<summary>參考答案</summary>

**1. 值類別分類（ISO C++ 集合定義）**
- **glvalue (generalized lvalue)**：具有物件識別位址（has identity）的運算式。
- **rvalue**：可被移動（can be moved from）的運算式。
- 兩者集合劃分出三種獨立類別：
  - **lvalue**（`glvalue \ rvalue`）：有 identity、且不可被移動（例如：具名變數 `int a;`、回傳 lvalue reference 的函式 `int& foo();`）。
    - **高頻陷阱**：**字串字面常數（String Literals，如 `"hello"`）是 lvalue**（型別為 `const char[6]`，儲存於 static storage，具有具體記憶體位址）；數值字面常數（如 `42`、`3.14`）才是 prvalue。
  - **prvalue (pure rvalue)**（`rvalue \ glvalue`）：無 identity、純粹臨時求值產生的值（例如：`a + b`、回傳值型別的函式呼叫 `std::string("hi")`、非字串字面常數）。
  - **xvalue (eXpiring value)**（`glvalue ∩ rvalue`）：既有 identity，又標記為可被移動的即將過期物件（例如：`std::move(var)` 的回傳值）。

**2. `std::move` 的本質與標準實作**
- `std::move` 在執行期**不發出任何 CPU 指令，也不移動任何記憶體**！
- **實作關鍵**：`std::move` 不能單純寫成 `static_cast<T&&>`。因為傳入 lvalue 時，`T` 會被推導為引用型別（如 `Widget&`），根據引用折疊規則 `Widget& &&` 依然會折疊為 lvalue reference `Widget&`，完全無法轉成右值！
- **標準庫實作**：必須先以 `std::remove_reference` 剝除引用：
  ```cpp
  template <typename T>
  constexpr typename std::remove_reference<T>::type&& move(T&& t) noexcept {
      return static_cast<typename std::remove_reference<T>::type&&>(t);
  }
  ```
- 它的唯一功能是將傳入的運算式無條件轉型為 xvalue，通知編譯器優先配對到 Move Constructor 或 Move Assignment。

**3. Forwarding Reference 與 `std::forward`**
- **條件**：只有當 `T&&` 處於**需要型別推導（type deduction）的情境**時，它才是 Forwarding Reference（例如 `template<typename T> void func(T&& arg)` 或 `auto&& var`）。
  - **不是 Forwarding Reference 的常見反例**：
    1. `const T&&`（加上 `const` 就失去推導彈性，純屬 const rvalue reference）。
    2. `std::vector<T>::push_back(T&& x)`（在宣告 class `vector<T>` 時 `T` 已經確定，函式本身沒有 template 參數推導，純屬單純 rvalue reference）。
- **引用折疊規則（Reference Collapsing）**：
  - `& + & -> &`、`& + && -> &`、`&& + & -> &`、`&& + && -> &&`（只有兩者皆為 `&&` 時才折疊為 `&&`）。
- **完美轉發**：`std::forward<T>(arg)` 本質是條件轉型 `static_cast<T&&>(arg)`。當引數是 lvalue 時 `T` 被推為 `T&`，折疊後維持 `T&`；當引數是 rvalue 時 `T` 被推為 `T`，轉型為 `T&&` 保持右值屬性。
</details>

**上次的弱點：** 尚未考過。

---

### Q5：Move Constructor 為什麼一定要標記 `noexcept`？〔L4〕

1. 如果一個 class 的 Move Constructor 沒有標記 `noexcept`，當它被放入 `std::vector` 並觸發容量擴充（reallocate / resize）時，會發生什麼事？
2. 說明 C++ 標準程式庫在此處依賴的機制（`std::move_if_noexcept`）與 Strong Exception Guarantee。

<details>
<summary>參考答案</summary>

**1. `std::vector` resize 的行為變化**
- 若 class 宣告了 Move Constructor 但**未加上 `noexcept`**：
  - **情境 A（類別同時擁有 Copy Constructor）**：當 `std::vector` 需要重新分配記憶體擴容時，它會**放棄使用 move，倒退回去使用 copy constructor**，產生額外深拷貝開銷！
  - **情境 B（類別為 Move-Only，如擁有 `unique_ptr`，Copy 被 delete）**：`std::vector` **依然會編譯通過並執行 move**，但會**喪失 Strong Exception Guarantee，降級為 Basic Exception Guarantee**（搬移中途若丟出例外，容器維持在合法但部分元素已被掠奪的狀態，無法完全 rollback）。

**2. 原理：強烈異常保證（Strong Exception Guarantee）與 `std::move_if_noexcept`**
- `std::vector::push_back` 承諾具備 Strong Exception Guarantee：若操作拋出 exception，vector 的狀態必須完全回滾到操作前的狀態（commit or rollback）。
- **核心矛盾**：
  - 若在搬移舊元素到新記憶體時，搬到一半某個物件的 move constructor 拋出 exception：舊物件已經被掠奪（資源變空），新物件尚未完全建構，此時既無法繼續，也無法還原舊元素狀態！
  - 相反地，如果使用 copy constructor，即使中途拋出 exception，舊記憶體的元素依然完整未被修改，vector 可以安全釋放新配置的記憶體並百分之百還原原狀。
- **標準庫判斷標準（ISO C++ `[util.move_if_noexcept]`）**：
  - 判斷條件是：`!std::is_nothrow_move_constructible<T>::value && std::is_copy_constructible<T>::value`。
  - 只有在「Move 不是 noexcept **且** 具有 Copy Constructor」時，才會退化為 Copy。
  - 因此自訂 class 的 move constructor/assignment **務必宣告 `noexcept`**，才能在保有高效 Move 的同時享有完整的 Strong Exception Guarantee。
</details>

**上次的弱點：** 尚未考過。

---

### Q6：Rule of Three / Five / Zero 與現代資源管理〔L3〕

1. 解釋什麼是 Rule of Three、Rule of Five、Rule of Zero。
2. 只要使用者自訂了 Destructor，編譯器對 Copy/Move 成員函式的合成規則（implicit generation）會發生什麼變化？
3. 為什麼現代 C++ 強烈建議遵循 Rule of Zero？

<details>
<summary>參考答案</summary>

**1. 定義與演進**
- **Rule of Three (C++98)**：若 class 需要自訂下列三者之一，通常三者都必須自訂：
  1. Destructor
  2. Copy Constructor
  3. Copy Assignment Operator
- **Rule of Five (C++11)**：因引入 Move Semantics，擴展為五個特殊成員函式：
  1. Destructor
  2. Copy Constructor
  3. Copy Assignment Operator
  4. Move Constructor
  5. Move Assignment Operator
- **Rule of Zero (Modern C++)**：設計 class 時，**盡量不要自訂上述五個函式中的任何一個**。所有底層資源的管理都委派給現有的 RAII 類別（例如 `std::unique_ptr`、`std::vector`、`std::string`）。

**2. 編譯器合成規則陷阱**
- 若使用者**自訂了 Destructor**（哪怕只是寫了 `~MyClass() = default;` 或自訂解構印 log）：
  - 編譯器**不會自動生成 Move Constructor 和 Move Assignment**！
  - 編譯器仍會生成 Copy Constructor / Copy Assignment（屬於 deprecated 行為），這會導致本該 move 的地方默默退化成深拷貝，產生隱蔽的效能地雷。
- 若宣告了任何 Copy 操作，Move 操作不會生成；宣告了任何 Move 操作，Copy 操作會被 `= delete`。

**3. 為何倡導 Rule of Zero**
- 減少手寫易出錯的樣板代碼（boilerplate）。
- 讓編譯器自動合成最佳且正確的 copy/move/destruct 行為。
- 物件生命週期與所有權單純化，消滅手動 `delete` 或 leak 的風險。

</details>

**上次的弱點：** 尚未考過。

---

## 第三模組：Lambda 表達式與函式物件

### Q7：Lambda 捕獲機制與生命週期陷阱〔L3〕

1. 比較 `[=]`、`[&]`、`[this]` 的捕獲行為差異。
2. 在非同步工作（thread、event callback、TLM delayed callback）中使用 Lambda 時，最常見的 Memory / Lifetime 陷阱是什麼？如何避免？
3. 為什麼 C++20 開始強烈不建議（甚至 deprecate）在 `[=]` 中隱式捕獲 `this`？

<details>
<summary>參考答案</summary>

**1. 捕獲行為**
- `[=]`：以 **by-value（複製）** 捕獲當前 scope 中所有被 **odr-used**（在 lambda 內部實質使用到）的區域變數；未使用到的變數不會被複製或封裝進 closure。
- `[&]`：以 **by-reference（引用）** 捕獲當前 scope 中所有被 **odr-used** 的區域變數。
- `[this]`：以 **指標值傳遞** 捕獲當前物件的 `this` 指標，使得 lambda 內部可直接存取 class 成員變數。

**2. 生命週期陷阱：Dangling Reference / Use-After-Free**
- **陷阱 1：引用捕獲已消亡的 stack 變數**
  - 當 lambda 被傳遞給非同步執行緒、註冊為事件回呼、或存放在長生命週期的 container 時，若使用了 `[&]`，引用的區域變數在離開函式 scope 時就解構了。Lambda 執行時將引發 Undefined Behavior。
- **陷阱 2：隱式捕獲 `this` 導致物件提早解構**
  - 在成員函式中寫 `[=]() { return m_val; }`，很多人誤以為 `m_val` 是 by-value 複製進 lambda。實際上它等同於 `[this]() { return this->m_val; }`！若外層的 class instance 先被釋放，執行 lambda 時存取 `this->m_val` 就會造成 Segmentation fault。
- **解決方式**：
  - 避免盲目使用預設捕獲 `[&]` 或 `[=]`，明確列出欲捕獲的變數。
  - C++14 可用 Init Capture 複製成員：`[val = m_val]`，或在 C++17 使用 `[*this]` 複製整個物件本體。

**3. C++20 deprecate `[=]` 隱式捕獲 `this`**
- 就是為了消除上述「誤以為物件被 value 複製，實則是指標存取」的直覺誤區，要求程式員若要捕獲 `this` 必須顯式寫出 `[=, this]` 或 `[*this]`。

</details>

**上次的弱點：** 尚未考過。

---

### Q8：C++14 Generalized Lambda Capture (Init Capture) 與 Generic Lambda〔L4〕

1. 寫出一段代碼，展示如何利用 C++14 的 Init Capture 將一個不可複製的 `std::unique_ptr` 搬移進 Lambda closure 中。
2. C++14 Generic Lambda（例如 `[](auto x, auto y) { return x + y; }`）在編譯器底層是如何被實現的？
3. 若需要限制 Generic Lambda 兩個參數必須是同一型別，C++14 該如何做到？

<details>
<summary>參考答案</summary>

**1. Init Capture 移動 `unique_ptr`**
C++11 無法在 capture list 中進行 move 操作。C++14 引入 Init Capture（語法：`[var = expr]`），在 closure 內部建立新欄位並以 move 初始化：
```cpp
auto ptr = std::make_unique<Buffer>(1024);
auto task = [p = std::move(ptr)]() {
    p->process();
};
// 此時外部的 ptr 已經為 nullptr，所有權成功移入 lambda closure
```

**2. Generic Lambda 的編譯器底層實現**
- 編譯器會為 lambda 生成一個匿名的 functor class（closure type）。
- 對於一般 lambda，其 `operator()` 是一個普通的成員函式。
- 對於 Generic Lambda，編譯器會將 `operator()` 直接生成為 **member function template**：
```cpp
// 概念等價結構：
class __Lambda_xy {
public:
    template<typename T1, typename T2>
    auto operator()(T1 x, T2 y) const {
        return x + y;
    }
};
```

**3. 限制同型別的作法**
- **Hard Error 做法（若只需阻擋編譯）**：在函式體內使用 `static_assert`。但注意這在具現化時引發硬編譯錯誤，**不具備 SFINAE 特性**（無法用於 template 多載決策）：
  ```cpp
  auto add_same = [](auto x, auto y) {
      static_assert(std::is_same<typename std::decay<decltype(x)>::type,
                                 typename std::decay<decltype(y)>::type>::value, "Types must match!");
      return x + y;
  };
  ```
- **SFINAE 做法（C++14 條件具現化）**：利用尾置回傳型別與 `std::enable_if_t`：
  ```cpp
  auto add_same_sfinae = [](auto x, auto y) -> std::enable_if_t<
      std::is_same<typename std::decay<decltype(x)>::type,
                   typename std::decay<decltype(y)>::type>::value, decltype(x + y)> {
      return x + y;
  };
  ```
- **底層函式指標轉型**：無捕獲的 Generic Lambda 會生成 conversion function template，因此可以轉成具體的函式指標：`int (*fp)(int, int) = add;`（`add` 是 `[](auto a, auto b) { return a + b; }`）。實測 `-std=c++14` 通過；`-std=c++11` 連 generic lambda 本身都不合法。

</details>

**上次的弱點：** 尚未考過。

---

### Q9：Lambda vs `std::function` vs 函式指標的開銷與比較〔L3〕

1. 比較無捕獲 Lambda、有捕獲 Lambda、`std::function`、一般 C 函式指標在大小、間接呼叫開銷與 inline 能力上的差異。
2. 說明 `std::function` 的底層機制（Type Erasure 與 Small Buffer Optimization）。在高效能模擬環境（如 TLM model）中濫用 `std::function` 會帶來什麼瓶頸？

<details>
<summary>參考答案</summary>

**1. 性能與大小比較表**

| 特性 | C 函式指標 (`void(*)()`) | 裸 Lambda（無 capture） | 裸 Lambda（有 capture） | `std::function` |
|---|---|---|---|---|
| **大小 (64-bit)** | 8 bytes | 1 byte (空類別) | 等於捕獲變數對齊總和 | 通常為 32–48 bytes |
| **可否 Inline** | 難（除非常數傳遞） | 極高（編譯期直接 inline） | 極高（編譯期直接 inline） | 否（透過函式指標間接呼叫） |
| **間接呼叫開銷** | 1 次 indirect call | 0 次（直接展開） | 0 次（直接展開） | 1~2 次 indirect call |
| **記憶體配置** | 無 | 無（在 stack 或物件內） | 無（在 stack 或物件內） | 若超過 SBO 容量會觸發 heap `malloc` |

- **無捕獲 Lambda** 可隱式轉型為 C 函式指標：編譯器會自動生成一個轉型運算子函式 `operator conversion-type-id() const noexcept`（例如 `operator void(*)()()`）。
  - **工程慣用語註記**：工程師常寫的 `+[](){}`，是利用 C++ 內建的 unary `+` 運算子強制觸發此轉型運算子轉為函式指標，`+` 本身並非編譯器生成的 operator。
- **有捕獲 Lambda** 是一個獨立型別的 closure object，不能轉成 C 函式指標。
- **`std::function` 實作大小參考**：libstdc++ 實作通常為 32 bytes（內建 16 bytes SBO buffer）；libc++ 為 48 bytes（24 bytes buffer）；MSVC STL 為 64 bytes（40 bytes buffer）。（libstdc++ 的 32 為本機 g++ 11 實測：`sizeof(std::function<void()>)` 輸出 32；libc++ 與 MSVC 的數字未在本機驗證，依實作可能不同。）

**2. `std::function` 機制與在模擬模型中的瓶頸**
- **Type Erasure（型別擦除）**：`std::function` 是一個萬用容器，能包裝任何可呼叫物件（lambda、functor、成員函式指標）。為了抹除具體型別，它內部維護一個虛擬函式表或函式指標（呼叫器與釋放器）。
- **Small Buffer Optimization (SBO)**：內部通常提供約 16–32 bytes 的本機緩衝區。若捕獲的物件小於此容量，就直接放在物件內；一旦超過，就必須在 heap 動態配置記憶體！
- **TLM / 效能模型中的地雷**：
  - 在每秒執行數百萬次 transaction 的 simulation loop 中，如果每個 payload 回呼都包一層 `std::function`，將面臨：
    1. **無法 inline**：嚴重的 instruction cache miss 與 branch misprediction。
    2. **潛在 heap allocation**：若捕獲變數稍大，每次綁定 callback 都觸發 `malloc/free`，直接摧毀模擬速度。
  - **解法**：在 TLM 框架中優先使用 template 參數靜態綁定。SystemC 的兩條路徑要分開看：（a）標準 socket（`tlm_target_socket` 等）不用 callback，而是綁定 pure virtual 介面 `tlm_fw_transport_if`（`nb_transport_fw` 等宣告為 `= 0`，見 `src/tlm_core/tlm_2/tlm_2_interfaces/tlm_fw_bw_ifs.h`），由 module 實作該介面；（b）`tlm_utils` 的 convenience socket（如 `simple_target_socket`）內部才用成員函式指標：`register_nb_transport_fw(MODULE*, NBTransportPtr)` 把 `MODULE::*` 存入 `fw_process`，再由 `fw_process` 這個適配器實作 `tlm_fw_transport_if` 並轉呼叫（見 `src/tlm_utils/simple_target_socket.h`）。成員函式指標不做 type erasure、不 heap 配置，但仍是間接呼叫。

</details>

**上次的弱點：** 尚未考過。

---

## 第四模組：物件導向、型別推導與編譯期計算

### Q10：`override`、`final` 與虛擬函式去虛化（Devirtualization）〔L3〕

1. `override` 與 `final` 關鍵字分別解決了 C++ 繼承體系中的什麼問題？
2. 為什麼在 Base Class 中宣告了 `virtual` 函式時，Destructor 也必須是 `virtual`？
3. 編譯器在什麼情況下能夠對虛擬函式呼叫進行「去虛化（Devirtualization）」優化？`final` 如何協助這項優化？

<details>
<summary>參考答案</summary>

**1. `override` 與 `final` 的用途**
- `override`：顯式告知編譯器此函式意在覆寫 base class 的虛擬函式。若 base class 簽名改變（例如多了一個 `const`、參數型別不同），編譯器會直接噴錯，防止意外變成「隱藏（hiding）」或「新增多載」的致命 bug。
- `final`：
  - 用於 class 時：禁止其他類別繼承它（如 `class Derived final : public Base`）。
  - 用於虛擬函式時：禁止後續衍生類別再次覆寫該函式。

**2. Virtual Destructor 的必要性**
- 當我們透過 base class pointer 刪除衍生類別物件時（`Base* p = new Derived(); delete p;`）：
  - 若 `Base::~Base()` 不是 `virtual`，C++ 標準規範此行為是 **Undefined Behavior (UB)**！
  - 實際表現通常是編譯器只進行靜態綁定，僅呼叫 `Base` 的解構函式，而 `Derived` 的解構函式完全不會被執行，造成衍生類別的成員資源洩漏。

**3. 去虛化（Devirtualization）與 `final`**
- **去虛化**：將原本需要查 vtable 的間接呼叫（indirect call），在編譯期優化成直接函式呼叫（direct call），甚至進一步進行 inline。
- **`final` 的幫助**：
  - 當指標或引用的靜態型別是指向標記為 `final` 的類別（例如 `Derived*`），或呼叫的成員函式本身被宣告為 `final` 時，編譯器確定不可能再有更深層的衍生類別覆寫該函式，因此可以 100% 安全地去除 vtable 查找，轉為直接呼叫並進行 inline 優化。
- **C++14 Sized Deallocation 陷阱**：若 Base class destructor 缺少 `virtual`，除了衍生類別資源無法釋放外，C++14 引入 Sized Deallocation（`operator delete(void*, std::size_t)`）後，還會把 Base 的較小 size 傳遞給 allocator，導致底層記憶體釋放器結構毀損。

</details>

**上次的弱點：** 尚未考過。

---

### Q11：型別推導規則：`auto` vs `decltype` vs `decltype(auto)`〔L4〕

1. 說明 `auto` 推導變數型別時的衰減（decay）規則（對 `const` 與 reference 的處理）。
2. `decltype(expr)` 的推導規則與 `auto` 有何不同？特別是 `decltype(x)` 與 `decltype((x))` 的差異。
3. C++14 引入的 `decltype(auto)` 解決了什麼問題？請舉一個函式轉發回傳值的例子。

<details>
<summary>參考答案</summary>

**1. `auto` 的推導規則（等同 Template 引數推導）**
- 當不加 `&` 或 `*` 時（值傳遞），`auto` 會發生 **decay**：
  - 忽略頂層（top-level）`const`（但保留底層 low-level `const` 指標）。
  - 忽略 reference 屬性。
  ```cpp
  const int x = 10;
  const int& rx = x;
  auto a = rx;        // a 的型別是 int（const 和 & 都被拔除，複製一份）
  const auto& b = rx; // b 的型別是 const int&
  ```

**2. `decltype` 的推導規則**
- `decltype` 不做 decay，保留完全精確的型別（包含頂層 const 與 reference）。
- **重大陷阱 `decltype(x)` vs `decltype((x))`**：
  - 若 `x` 是未括號的變數名稱：回傳該變數宣告時的實體型別。
  - 若加上括號 `(x)`，它變成了一個 lvalue expression！依據規則，任何回傳 lvalue 的運算式都會被推導為引用型別（`T&`）：
  ```cpp
  int x = 0;
  decltype(x)   a = x; // a 是 int
  decltype((x)) b = x; // b 是 int&（非常容易踩雷的細節！）
  ```

**3. C++14 `decltype(auto)` 的價值與致命陷阱**
- **演進歷史**：C++11 函式若要推導回傳型別，必須使用尾置型別宣告 `auto func() -> decltype(expr)`。**C++14 同時引入了兩大回傳值推導機制**：
  1. `auto func()`：依據 `auto` 規則推導，會發生 decay（丟棄頂層 const 與 reference）。
  2. `decltype(auto) func()`：依據 `decltype` 規則推導，原汁原味保留運算式的精確型別（包含引用與 const）。
- **原汁原味轉發容器存取**：
  ```cpp
  std::vector<int> v = {1, 2, 3};
  // auto get_elem(int i) { return v[i]; }            // 錯誤：推導為 int，發生拷貝且無法修改容器！
  decltype(auto) get_elem(int i) { return v[i]; }     // 正確：v[i] 是 lvalue reference，推導出 int&
  ```
- **致命懸空引用陷阱（面試極高頻陷阱）**：
  ```cpp
  decltype(auto) dangerous() {
      int x = 10;
      return (x); // 致命陷阱！(x) 加上括號後變成 lvalue expression，推導為 int&！
                  // 函式回傳了區域變數 x 的懸空引用（Dangling Reference），引發 UB！
  }
  ```
</details>

**上次的弱點：** 尚未考過。

---

### Q12：`constexpr` 在 C++11 與 C++14 的限制放寬〔L3〕

1. `constexpr` 與 `const` 的核心區別是什麼？
2. C++11 的 `constexpr` 函式有哪些嚴苛限制？
3. C++14 放寬了哪些限制？這些改進對暫存器設定或數學查表計算有什麼好處？

<details>
<summary>參考答案</summary>

**1. `constexpr` vs `const`**
- `const`：表示**唯讀（Read-only）**，不代表一定能在編譯期確定。例如 `const int x = rand();` 是合法的執行期 const。
- `constexpr`：表示**編譯期常數（Compile-time Constant）**。凡是宣告為 `constexpr` 的變數，必須在編譯期就能計算出數值，可用於 array size、template argument、`case` 標籤。

**2. C++11 `constexpr` 函式的限制**
- 函式本體實質上**只能包含一條 `return` 敘述**。
- 不能包含區域變數宣告（除了 `typedef`、`using`）。
- 不能包含迴圈（`for`、`while`），任何重複計算必須強制用遞迴（recursion）實現。
- 不能有 `if-else` 分支（只能用三元運算子 `? :`）。
- 成員函式預設被隱式加上 `const`。

**3. C++14 的放寬與好處**
- **放寬**：
  - 允許多個 statement。
  - 允許回傳型別為 `void`（C++11 強制 `constexpr` 函式不可為 `void`）。
  - 允許宣告非 static 的區域變數，且可以在函式內修改它。
  - 允許使用條件分支（`if`、`switch`）與迴圈（`for`、`while`）。
  - 成員函式不再強制預設為 `const`。
  - 在硬體建模中，常常需要做位址解碼查表（CRC 表、bit reverse 表、register offset 計算）。在 C++14 中可以直接寫一個直觀的 `for` 迴圈在編譯期填表，代碼可讀性極高且具備零執行期開銷。

</details>

**上次的弱點：** 尚未考過。

---

### Q13：`enum class`（強型別列舉）的優勢〔L3〕

1. 說明傳統 C++ `enum` 存在哪三大缺陷？
2. C++11 的 `enum class` 如何解決這些問題？底層儲存型別（underlying type）預設是什麼？

<details>
<summary>參考答案</summary>

**1. 傳統 `enum` 的三大缺陷**
1. **Scope 污染（Namespace Pollution）**：列舉值名稱直接洩漏到外層 scope。若有兩個 enum 同時定義了 `ERROR` 或 `IDLE`，會發生名稱衝突。
2. **隱式型別轉型（Implicit Conversion）**：列舉值會自動無條件降級轉型為 `int`，導致不同語意的 enum（例如 `Color::RED` 與 `State::IDLE`）可以直接用 `==` 比較而編譯不報錯。
3. **無法前置宣告（Forward Declaration）**：C++98 不能預先指定底層整數型別，編譯器必須看完所有列舉值才能決定配置大小，因此無法 forward declare，增加了標頭檔相依性。

**2. C++11 `enum class` 的解決方案**
- **具備獨立 Scope**：必須透過 `Color::RED` 存取，徹底消滅命名衝突。
- **強型別檢查**：禁止隱式轉型為整數。若要轉成整數必須顯式 `static_cast<int>(val)`。
- **可指定底層型別與 Forward Declaration**：
  ```cpp
  enum class RegAddr : uint16_t; // 合法前置宣告
  enum class RegAddr : uint16_t {
      STATUS = 0x00,
      DATA   = 0x04
  };
  ```
  - 未特別指定時，`enum class` 的預設底層型別是 **`int`**。

</details>

**上次的弱點：** 尚未考過。

---

## 第五模組：底層系統、並行與 Bit 操作

### Q14：`std::atomic` vs `volatile` 的本質差別〔L4〕

1. 在 C/C++ 中，`volatile` 的確切作用是什麼？它能保證多執行緒安全嗎？
2. `std::atomic` 提供了什麼保證？說明它如何防止編譯器與 CPU 的指令重排（Instruction Reordering）。
3. 在 Virtual Platform / 硬體暫存器建模與 Embedded FW 中，這兩者應如何正確分工？

<details>
<summary>參考答案</summary>

**1. `volatile` 的真實作用**
- `volatile` 是對**編譯器**的指示：告知該變數可能被編譯器不可見的外部因素修改（例如硬體暫存器、中斷服務常式 ISR、非同步 signal handler）。
- **效果**：強制編譯器每次存取該變數時，都必須發出真實的 load/store 記憶體讀寫指令，禁止快取在 CPU 暫存器中，也禁止將重複的讀寫優化刪除。
- **不能保證 thread safety**：`volatile` **不保證操作的原子性（Atomicity）**，也**不包含任何 CPU 硬體 Memory Barrier**，無法阻止 CPU 執行期的亂序執行（Out-of-Order Execution）！在多執行緒環境中使用 `volatile` 是標準的 Bug。
  - **MSVC 歷史陷阱**：在 MSVC 編譯器中，歷史選項 `/volatile:ms` 會非標準地為 `volatile` 變數加上 acquire/release 語義；但在跨平台 Linux/GCC/Clang 或 `/volatile:iso` 下此假設完全崩潰。

**2. `std::atomic` 的保證**
- 保證操作的**原子性**（無 data race）。
- 依據指定的 **Memory Order**（預設為最強的 `std::memory_order_seq_cst`），編譯器會插入相應的硬體記憶體屏障指令（Memory Barrier / Fence，如 x86 的 `mfence` 或 ARM 的 `dmb`），保證多核心 CPU 之間的可見性（visibility）與同步順序，徹底防止 CPU 與編譯器亂序。

**3. 分工準則**
- **Memory-Mapped I/O (MMIO) 暫存器指標 / 硬體暫存器**：使用 `volatile`（告知編譯器不可優化掉任何硬體 read/write）。
  - **底層驅動細節**：在 ARM/RISC-V 等弱記憶體架構實體晶片中，除了 `volatile` 阻止編譯器優化，通常還需搭配匯流排硬體屏障（如 Linux `readl()`/`writel()` 內部的 `dsb`），防止 CPU Store Buffer 合併寫入。
- **多執行緒（Multi-threaded）共享旗標、計數器、狀態同步**：使用 `std::atomic`。

</details>

**上次的弱點：** 尚未考過。

---

### Q15：C++14 二進位字面值（Binary Literals）與數字分隔符〔L3〕

1. C++14 引入的二進位字面值與數字分隔符語法為何？
2. 在硬體建模（暫存器遮罩、位址對齊）中，請寫出使用此特性的範例，並說明可讀性優勢。

<details>
<summary>參考答案</summary>

**1. 語法**
- 二進位字面值：前綴 `0b` 或 `0B`（例如 `0b1011`）。
- 數字分隔符：單引號 `'`（可以放在任何數字字面值中，完全被編譯器忽略，不影響數值）。

**2. 暫存器遮罩範例**
```cpp
// 定義 32-bit 控制暫存器欄位遮罩
constexpr uint32_t CTRL_ENABLE_BIT = 0b0000'0001;
constexpr uint32_t CTRL_MODE_MASK  = 0b0000'1110;
constexpr uint32_t CTRL_BURST_EN   = 0b1000'0000;

// 定義記憶體位址與大數
constexpr uintptr_t DRAM_BASE_ADDR = 0x8000'0000;
constexpr size_t    BUFFER_SIZE    = 1'048'576; // 1MB
```
- **優勢**：在晶片規格書（datasheet）核對 bit field 時，直接對應二進位 bit 排列，不易數錯 0 的個數，大幅降低暫存器建模與 bit mask 計算出錯的機率。

</details>

**上次的弱點：** 尚未考過。

---

## 第六模組：白板手寫實作題

### C1：手寫實作 RAII 動態陣列 `Buffer`（Rule of Five + `noexcept`）〔L3〕

**題目要求：**
實作一個管理動態配置 `uint8_t` 陣列的 `Buffer` 類別：
1. 包含指標 `uint8_t* data_` 與長度 `size_t size_`。
2. 實作建構函式、解構函式。
3. 實作 Copy Constructor 與 Copy Assignment Operator。
4. 實作 Move Constructor 與 Move Assignment Operator，並務必加上 `noexcept`。
5. 確保無記憶體洩漏與 double-free。

<details>
<summary>參考答案</summary>

```cpp
#include <cstddef>
#include <cstdint>
#include <algorithm>
#include <utility>

class Buffer {
public:
    // 一般建構函式
    explicit Buffer(size_t size = 0)
        : size_(size), data_(size > 0 ? new uint8_t[size]() : nullptr) {}

    // 解構函式
    ~Buffer() {
        delete[] data_;
    }

    // Copy Constructor (深拷貝)
    Buffer(const Buffer& other)
        : size_(other.size_), data_(other.size_ > 0 ? new uint8_t[other.size_] : nullptr) {
        if (data_) {
            std::copy(other.data_, other.data_ + size_, data_);
        }
    }

    // Move Constructor (資源移交，noexcept 極關鍵)
    Buffer(Buffer&& other) noexcept
        : size_(other.size_), data_(other.data_) {
        other.size_ = 0;
        other.data_ = nullptr; // 將來源物件置於合法但空的狀態
    }

    // 支援非成員 swap
    friend void swap(Buffer& a, Buffer& b) noexcept {
        using std::swap;
        swap(a.size_, b.size_);
        swap(a.data_, b.data_);
    }

    // Copy Assignment Operator 寫法 A：現代推薦 Copy-and-Swap 慣用法
    // (傳值呼叫 copy/move constructor，天然具備強例外安全與自我指派安全)
    Buffer& operator=(Buffer other) noexcept {
        swap(*this, other);
        return *this;
    }

    /* Copy Assignment Operator 寫法 B：傳統分別實作
    Buffer& operator=(const Buffer& other) {
        if (this != &other) {
            uint8_t* new_data = other.size_ > 0 ? new uint8_t[other.size_] : nullptr;
            if (new_data) {
                std::copy(other.data_, other.data_ + other.size_, new_data);
            }
            delete[] data_; // 先配置成功再釋放舊資源，保證 Exception Safety
            data_ = new_data;
            size_ = other.size_;
        }
        return *this;
    }
    Buffer& operator=(Buffer&& other) noexcept {
        if (this != &other) {
            delete[] data_;
            data_ = other.data_;
            size_ = other.size_;
            other.data_ = nullptr;
            other.size_ = 0;
        }
        return *this;
    }
    */

    // 陣列下標存取
    uint8_t& operator[](size_t index) noexcept { return data_[index]; }
    const uint8_t& operator[](size_t index) const noexcept { return data_[index]; }

    // 輔助存取函式
    size_t size() const noexcept { return size_; }
    uint8_t* data() noexcept { return data_; }
    const uint8_t* data() const noexcept { return data_; }

private:
    size_t size_{0};
    uint8_t* data_{nullptr};
};
```

**白板面試評分要點：**
- 自我指派檢查（或使用 Copy-and-Swap 自然免除自我指派問題）。
- Move 之後是否有清空 `other.data_ = nullptr`（沒清會 double-free）。
- Copy assignment 是否具備 Exception Safety（若先 `delete[] data_`，之後 `new` 拋出例外，物件內部狀態會損壞）。
- Move 系列是否有加 `noexcept`。
- 是否提供 `operator[]` 與 const 多載。
</details>

**上次的弱點：** 尚未考過。

---

### C2：代碼找錯與現代 C++ 盲點分析（Code Review 題）〔L4〕

請指出下列代碼中的 **3 處嚴重設計缺陷或 Bug**（參考答案另列 1 處次要項目），並提供修正方式：

```cpp
class DeviceDriver {
public:
    DeviceDriver(std::string name) : dev_name_(name) {}
    ~DeviceDriver() { cleanup(); }

    void async_read(int timeout_ms) {
        std::thread([=]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(timeout_ms));
            std::cout << "Device: " << dev_name_ << " read done\n";
        }).detach();
    }

private:
    std::string dev_name_;
    void cleanup() { /* release hw */ }
};
```

<details>
<summary>參考答案</summary>

**缺陷 1：Lambda 中的 Dangling Pointer (`[=]` 隱式捕獲 `this`) 與 Race Condition**
- **問題**：`async_read` 啟動了一個 detached thread。Lambda 雖然寫了 `[=]`，但它捕獲的是 `this` 指標的拷貝，而不是 `dev_name_` 的拷貝！若呼叫 `async_read` 的 `DeviceDriver` 實體先一步解構，背景執行緒存取 `dev_name_` 時就是典型的 Use-After-Free，必定 crash。此外，主執行緒解構時呼叫 `cleanup()` 釋放硬體，與背景執行緒讀取硬體形成嚴重的競態條件（Race Condition）。
- **修正**：(1) 用 C++14 Init Capture 複製字串本體 `[name = dev_name_, timeout_ms]`，lambda 不再捕獲 `this`；(2) 不 `detach()`，改把 `std::thread` 存成成員 `worker_`，在解構函式中 `join()`，確保背景執行緒結束後才釋放硬體資源。完整修正版見本題末尾（`-pthread` 編譯、ASan/UBSan 乾淨）。
**缺陷 2：Base Class Destructor 缺少 `virtual`（若有繼承需求）**
- **問題**：`DeviceDriver` 這類驅動或硬體模型通常作為 base class。若衍生類別透過 `DeviceDriver*` 刪除，由於 destructor 不是 virtual，會造成 undefined behavior 與衍生類別未清理。
- **修正**：宣告為 `virtual ~DeviceDriver()`。

**缺陷 3：未處理 Rule of Five（或應禁用 Copy）**
- **問題**：此類別持有硬體資源（解構函式呼叫了 `cleanup()`），但沒有定義 Copy Constructor 與 Copy Assignment。一旦被複製，解構時會觸發兩次 `cleanup()`（重複釋放硬體/雙重釋放）。
- **修正**：此類別應為 move-only 或禁止複製/移動：
  ```cpp
  DeviceDriver(const DeviceDriver&) = delete;
  DeviceDriver& operator=(const DeviceDriver&) = delete;
  ```

**缺陷 4（額外加分項）：Pass-by-value 未利用 `std::move`**
- **問題**：建構函式 `DeviceDriver(std::string name) : dev_name_(name) {}` 進行了傳值，但在初始化列表中再次進行了一次深拷貝（copy initialization）。
- **修正**：改為 `dev_name_(std::move(name))`。

**修正後完整版**（下為 class 本體；另寫一個 `main` 呼叫 `DeviceDriver d("uart0"); d.async_read(10);`，以 `g++ -std=c++14 -Wall -Wextra -pthread -fsanitize=address,undefined` 編譯，實測輸出 `main continues` 與 `Device: uart0 read done`，無 sanitizer 報告）：

```cpp
#include <chrono>
#include <iostream>
#include <string>
#include <thread>

class DeviceDriver {
public:
    explicit DeviceDriver(std::string name) : dev_name_(std::move(name)) {}
    virtual ~DeviceDriver() {                      // 缺陷 2：virtual 解構
        if (worker_.joinable()) worker_.join();    // 解構前等待背景執行緒結束
        cleanup();
    }
    DeviceDriver(const DeviceDriver&) = delete;    // 缺陷 3：禁止複製
    DeviceDriver& operator=(const DeviceDriver&) = delete;

    void async_read(int timeout_ms) {
        if (worker_.joinable()) worker_.join();    // 重新啟動前先等舊的執行緒
        // 缺陷 1 修正：init capture 複製名稱，lambda 不捕獲 this
        worker_ = std::thread([name = dev_name_, timeout_ms]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(timeout_ms));
            std::cout << "Device: " << name << " read done\n";
        });
    }

private:
    std::string dev_name_;
    std::thread worker_;
    void cleanup() { /* release hw */ }
};
```

</details>

**上次的弱點：** 尚未考過。

---

## 第七模組：補充問答（Q16–Q22）

這一模組對應教學導讀 G1–G10，並補上 `std::array`、forwarding 與 callback 設計的開放式題。Q16–Q18 的程式碼可以直接編譯；Q19–Q22 偏設計與面試追問，答案以本機實測與條文名稱為準。

### Q16：找錯：lambda 捕獲 `this` 與 callback 的生命週期〔L2〕

```cpp
#include <functional>
#include <iostream>
#include <memory>
#include <vector>
struct Scheduler { std::vector<std::function<void()>> cbs; };
struct Device {
  int count = 0;
  void arm(Scheduler& s) {
    s.cbs.push_back([=] { std::cout << "tick " << ++count << "\n"; });   // 寫法 A
  }
};
int main() {
  Scheduler s;
  {
    Device d;
    d.arm(s);
  }                              // d 解構
  for (auto& cb : s.cbs) cb();   // 執行期會怎樣？
}
```

1. 這段程式在執行期會發生什麼事？編譯器為什麼不報錯？
2. 有人把寫法 A 改成 `[this]`，這樣能解決問題嗎？
3. 給出一個能讓 callback 在 `Device` 已經消失時安全結束的修法（`Device` 要用 `shared_ptr` 管理）。

<details>
<summary>提示</summary>

- `Device d` 離開 scope 之後，`cbs` 裡的 lambda 還留著什麼？
- `[this]` 與 `[=]` 捕獲的是同一種東西嗎？
- 回呼保存的應該是「強」還是「弱」的參照？

</details>

<details>
<summary>參考答案</summary>

1. `d` 解構後，lambda 內保存的 `this` 變成懸空指標，執行時寫入已釋放的 `count`，屬於未定義行為。本機實測 segmentation fault（exit 139）。編譯器只看語法，不分析物件的生命週期。
2. 不能。`[this]` 與 `[=]`（隱式捕獲 `this`）捕獲的都是同一個指標，生命週期問題一樣（見 G1）。
3. 修法：`Device` 繼承 `std::enable_shared_from_this<Device>`，由 `make_shared` 建立；回呼只保存 `std::weak_ptr<Device>`，執行時 `lock()`，拿不到就跳過。

   ```cpp
   struct Device : std::enable_shared_from_this<Device> {
     int count = 0;
     void arm(Scheduler& s) {
       std::weak_ptr<Device> w = shared_from_this();
       s.cbs.push_back([w] {
         if (auto d = w.lock()) std::cout << "tick " << ++d->count << "\n";
         else std::cout << "device gone, skip\n";
       });
     }
   };
   // main: auto d = std::make_shared<Device>(); d->arm(s); ... 離開 scope 後再執行 cbs
   ```

   實測輸出 `tick 1`、`device gone, skip`、`done`，`-std=c++11` 與 `c++14` 相同。如果 callback 一定比物件先結束，也可以改成由 owner 持有 callback，而不是反過來；但那是設計上的保證，不是編譯器能幫你檢查的。

</details>

**上次的弱點：** 尚未考過。

---

### Q17：設計題：parent / child 樹的所有權〔L3〕

設計一個樹狀結構 `Node`，每個節點有 `name`、子節點清單、父節點指標。

1. 寫出成員的型別，並說明誰擁有誰。
2. 如果 parent 也改用 `std::shared_ptr`，會發生什麼事？用哪個工具抓得到？
3. 父節點被 `reset()` 之後，子節點還能不能取得父節點？

<details>
<summary>參考答案</summary>

1. `std::vector<std::shared_ptr<Node>> kids`（父擁有子），`std::weak_ptr<Node> parent`（子不擁有父）。父節點由 `root` 的 `shared_ptr` 擁有，子節點由父節點的 `kids` 擁有。實測範例：

   ```cpp
   struct Node {
     std::string name;
     std::weak_ptr<Node> parent;
     std::vector<std::shared_ptr<Node>> kids;
     explicit Node(std::string n) : name(std::move(n)) {}
     ~Node() { std::cout << "~" << name << "\n"; }
   };
   // root->kids.push_back(child); child->parent = root;
   // root.use_count() == 1，child.use_count() == 2
   // child.reset(); root.reset(); 依序印 ~root、~child
   ```

   `-std=c++11` 與 `c++14` 輸出相同：`1 2`、`parent=root`、`~root`、`~child`、`end`。

2. 如果 `child->parent` 也是 `shared_ptr`，父與子互相持有，兩邊的 count 都不會歸零，形成循環（見 L2-3）。用 `-fsanitize=address` 編譯後，程式結束時 LeakSanitizer 會報 leak。
3. 不行。`weak_ptr::lock()` 會回傳空的 `shared_ptr`，所以子節點要先檢查 `if (auto p = child->parent.lock())`。

</details>

**上次的弱點：** 尚未考過。

---

### Q18：設計題：用 Rule of Zero 包住 C 的 `FILE*`〔L3〕

規格：把 `std::FILE*` 包成 `LogFile` 類別。要求：destructor 會 `fclose`；類別是 move-only；**不要自己寫任何 destructor、copy 或 move 成員**。

1. 成員型別與 deleter 要怎麼選？struct functor 與 lambda 的差別是什麼（對應 Q3）？
2. 為什麼 `LogFile` 會變成 move-only？如果業務需要 copy，能不能只靠 Rule of Zero 做到？

<details>
<summary>參考答案</summary>

1. `std::unique_ptr<std::FILE, FcloseFn>`，其中 `FcloseFn` 是無狀態的 struct（`void operator()(std::FILE* f) const noexcept { if (f) std::fclose(f); }`）。這樣 `sizeof` 與裸指標相同（實測 `sizeof(std::unique_ptr<std::FILE, FcloseFn>) == sizeof(void*)`），而函式指標 deleter 會變成兩個指標大小（實測 `2 * sizeof(void*)`）。
2. `unique_ptr` 的 copy constructor 被刪除，所以 `LogFile` 也隱式地不能 copy，而 move 會自動生成且是 `noexcept`（實測 `is_move_constructible`、`is_nothrow_move_constructible` 為真，`is_copy_constructible` 為假）。如果業務真的需要 copy，要改成 `std::shared_ptr<std::FILE>`（語意改變：多個擁有者，最後一個關檔），而不是手寫 copy。

   實測程式：`static_assert` 三項通過，`LogFile b(std::move(a));` 可以編譯執行，`-std=c++11` 與 `c++14` 相同。

</details>

**上次的弱點：** 尚未考過。

---

### Q19：設計題：callback 用 `std::function` 還是模板參數？〔L3〕

情境：一個 TLM 風格的模型，每個 transaction 完成時要通知一次，模擬跑到每秒數百萬次 transaction。

1. 用 `std::function<void(Payload&)>` 當 callback 與用模板參數 `template <class CB> void run(CB&& cb)` 各有什麼優缺點？
2. 什麼情況下 `std::function` 仍然是合理選擇？

<details>
<summary>參考答案</summary>

1. 模板參數：沒有 type erasure，呼叫可以 inline，沒有 heap 配置；代價是每種 callable 會實例化一份程式碼，而且要把型別存進 class 時必須再加一個模板參數。`std::function`：型別統一，可以放進容器或成員；代價是間接呼叫（通常不能 inline）、捕獲大時 heap 配置（MC34）、而且必須是 copy-constructible（MC22）。
2. 在初始化時註冊一次、不在每個 transaction 的熱路徑上，或是需要在執行期替換 callback 的情況。SystemC 的 standard socket 本身就不用 `std::function`，而是綁 pure virtual 介面（見 Q9）。

   本機實測的基準：`run_fast` 與 `run_slow` 都能正確呼叫（輸出 `2`），但 `run_slow` 的成本是否可接受，要用 profiler 量，不是靠直覺。

</details>

**上次的弱點：** 尚未考過。

---

### Q20：寫一個 `make` 工廠（完美轉發）〔L3〕

規格：`template <class T, class... Args> std::unique_ptr<T> make(Args&&... args)`，內部用 `new T(...)` 轉交參數。

1. 為什麼參數要寫成 `Args&&...`，而不是 `Args...`？
2. 把 `std::forward<Args>(args)...` 拿掉，改成 `args...`，會發生什麼事？
3. 給定 `S` 有 `explicit S(std::string&&)` 與 `explicit S(const std::string&)` 兩個建構子，`make<S>(std::string("x"))` 與 `make<S>(y)`（`y` 是 `std::string` 的左值）各會選哪個？

<details>
<summary>參考答案</summary>

1. `Args&&` 是 forwarding reference，可以接受 lvalue 與 rvalue，不會多做一次 copy 或 move。用值傳遞 `Args...` 會先複製一份，再交給 `new`。
2. 參數在 `make` 內都有名字，全部變成 lvalue，所以 rvalue 也會選 `const std::string&` 的建構子，失去移動的機會。實測：

   ```text
   make_good<S>(std::string("x"))  -> rvalue ctor
   make_bad<S>(std::string("x"))   -> lvalue ctor
   make_good<S>(y)                 -> lvalue ctor
   ```

3. `make<S>(std::string("x"))` 選 `explicit S(std::string&&)`（rvalue ctor）；`make<S>(y)` 選 `explicit S(const std::string&)`（lvalue ctor）。這就是 forwarding 的效果。`Args&&...`（variadic template）與 `std::forward` 都是 C++11 語法，`-std=c++11` 可以直接編譯。

</details>

**上次的弱點：** 尚未考過。

---

### Q21：`std::array`、C 陣列與參數傳遞〔L2〕

```cpp
#include <array>
#include <iostream>
void raw(int a[4]) { std::cout << "raw param sizeof=" << sizeof(a) << "\n"; }
void by_value(std::array<int, 4> a) { std::cout << "copy size=" << a.size() << "\n"; }
int main() {
  int arr[4] = {1, 2, 3, 4};
  std::array<int, 4> sa = {{1, 2, 3, 4}};
  std::cout << "C array sizeof=" << sizeof(arr) << " std::array sizeof=" << sizeof(sa) << "\n";
  raw(arr);
  by_value(sa);
}
```

1. 三個 `sizeof` 各是多少？為什麼 `raw` 裡的 `sizeof(a)` 不是 16？
2. `by_value(sa)` 會發生什麼事？改成 `const std::array<int, 4>&` 有什麼差別？
3. 暫存器庫應該用 `std::array` 還是 `std::vector`？各說一個理由。

<details>
<summary>參考答案</summary>

1. 本平台（`int` 4 bytes）：C 陣列 `sizeof(arr) == 16`、`std::array` 也是 16。`raw` 的參數 `int a[4]` 會退化成 `int*`，所以 `sizeof(a) == 8`；g++ 會給 `-Wsizeof-array-argument` 警告。實測輸出與此相同。
2. 傳值會整個複製 16 bytes 的陣列（實測 `copy size=4`）。改成 `const std::array<int, 4>&` 就沒有複製，只傳參考。
3. `std::array`：大小在編譯期已知，不需要 heap，`at()` 可以做邊界檢查，適合固定數量的暫存器。`std::vector`：大小要在執行期才決定、或需要改變大小時使用。
   補充：`static_assert(ca[1] == 2)` 與 `static_assert(ca.size() == 3)` 在 libstdc++ 的 `-std=c++11` 與 `c++14` 都通過；這是實作行為，標準上 `constexpr` 的條件沒有逐條核對。

</details>

**上次的弱點：** 尚未考過。

---

### Q22：設計題：`noexcept`、move 與封包池〔L4〕

情境：一個 `Packet` 類別有 `std::string name` 與 `std::vector<uint8_t> payload`，放在 `std::vector<Packet>` 裡，模擬器會 `push_back` 與 `reserve`。

1. 如果 `Packet` 的 move constructor 沒有 `noexcept`，而且 `Packet` 有 copy constructor，`vector` 擴容時會發生什麼事？
2. 如果 `Packet` 改成只有 move（例如成員含 `unique_ptr`），`noexcept` 還重要嗎？
3. 在本機 libstdc++ 上，`std::vector<int>` 與 `std::string` 的 move constructor 是否為 `noexcept`？你會怎麼把這個假設寫進程式碼？

<details>
<summary>參考答案</summary>

1. `vector` 擴容時改用 copy（[util.move_if_noexcept]），實際上每次擴容都做深拷貝，效能變差但不出錯（見 Q5、MC20）。
2. 還是重要。沒有 copy 時 `vector` 仍會 move，但 move 途中若丟出例外，`vector` 只能保證 basic exception guarantee（見 Q5 情境 B）。
3. 實測 `std::is_nothrow_move_constructible<std::vector<int>>` 與 `<std::string>` 都為真（`-std=c++11` 與 `c++14` 相同）。寫進程式碼的方式是 `static_assert(std::is_nothrow_move_constructible<Packet>::value, "...")`，讓 `Packet` 的 move 被編譯器檢查。`Packet` 的 move 只要成員都是 `noexcept` move，就會自動是 `noexcept`（Rule of Zero，見 G3）。

   注意：這些只是 libstdc++ 的實測結果，標準的對應條文（[vector] 與 [string] 的 move constructor 規定）沒有逐條核對。

</details>

**上次的弱點：** 尚未考過。

---

## 第八模組：手寫練習（E1–E2，只給規格與骨架）

這一模組是**你自己寫**的練習：只給規格、測試骨架與提示，**不附完成版**。寫完貼上來，我再做 review（符合 Alan 的練習規則）。驗收方式一律是：骨架中的 `main` 與 `assert` 全部通過，且 `-fsanitize=address,undefined` 沒有報告。

---

### E1：用 `weak_ptr` 寫一個不延長壽命的觀察者中心（Hub）〔L3〕

**規格**

1. `Sink` 已給在骨架裡：`total` 與 `on(int)`（累加）。
2. `Hub` 只記住觀察者，**不能**因為訂閱而延長 `Sink` 的壽命（訂閱前後 `use_count()` 不變）。
3. `void subscribe(const std::shared_ptr<Sink>& s)`：加入清單。
4. `void notify(int v)`：對每個仍活著的 `Sink` 呼叫 `on(v)`；已過期的要從清單移除。
5. `std::size_t live_count() const`：目前仍活著的 `Sink` 數量。
6. 只用 C++11 語法（不要用 init capture、generic lambda）。

**測試骨架（存成 `e1_test.cpp`）**

```cpp
// g++ -std=c++11 -Wall -Wextra -fsanitize=address,undefined e1_test.cpp -o e1 && ./e1
#include <cassert>
#include <cstddef>
#include <iostream>
#include <memory>
#include <vector>

struct Sink {
  int total = 0;
  void on(int v) { total += v; }
};

class Hub {
 public:
  void subscribe(const std::shared_ptr<Sink>& s);  // TODO 1
  void notify(int v);                              // TODO 2
  std::size_t live_count() const;                  // TODO 3
 private:
  std::vector</* TODO 0 */> subs_;                 // 選擇正確的成員型別
};

int main() {
  Hub h;
  auto a = std::make_shared<Sink>();
  {
    auto b = std::make_shared<Sink>();
    h.subscribe(a);
    h.subscribe(b);
    assert(h.live_count() == 2);
    h.notify(3);
    assert(b->total == 3);
  }                                  // b 離開 scope
  h.notify(4);                       // b 已過期，應被移除
  assert(h.live_count() == 1);
  assert(a->total == 7);
  assert(a.use_count() == 1);        // Hub 不能增加 strong count
  std::cout << "all passed\n";
}
```

**提示**

- 清單的元素應該是哪一種智慧指標？為什麼？（對應 Q1）
- 要使用物件之前，要用哪個成員函式確認它還活著？它回傳什麼型別？
- `expired()` 與 `lock()` 有什麼不同？`live_count()` 需要 `lock()` 嗎？
- 一次移除多個元素可以用 erase-remove idiom（`std::remove_if` 加上 `erase`）。

**驗收**：印出 `all passed`，sanitizer 沒有報告。

（參考解不放在檔案裡，請自己寫；寫完貼上來我看。）

---

### E2：`enum class` 權限位元 + `std::array` 暫存器庫（RegBank）〔L3〕

**規格**

1. `enum class Access : std::uint8_t`，值為 `None = 0`、`Read = 0b01`、`Write = 0b10`。
2. 寫 `constexpr Access operator|(Access, Access)` 與 `constexpr bool allows(Access have, Access need)`（`have` 包含 `need` 的所有位元時為 `true`）。
3. `RegBank`：`static constexpr std::size_t kCount = 4;`。成員用 `std::array<Access, kCount>`（權限）與 `std::array<std::uint32_t, kCount>`（值）。**不要宣告任何 destructor、copy 或 move 成員**（Rule of Zero）。
4. `set_access(i, a)`：越界丟 `std::out_of_range`（用 `at()`）。
5. `write(i, v)`：越界丟 `std::out_of_range`；沒有 `Write` 權限丟 `std::logic_error`。
6. `read(i)`：越界丟 `std::out_of_range`；沒有 `Read` 權限丟 `std::logic_error`。
7. 骨架中的兩個 `static_assert` 必須通過（move 建構與指派都是 `noexcept`）。
8. `-std=c++11` 與 `-std=c++14` 都要通過。

**測試骨架（存成 `e2_test.cpp`）**

```cpp
// g++ -std=c++11 -Wall -Wextra -fsanitize=address,undefined e2_test.cpp -o e2 && ./e2
#include <array>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <type_traits>

// TODO 1：enum class Access : std::uint8_t { None = 0, Read = 0b01, Write = 0b10 };
// TODO 2：constexpr Access operator|(Access, Access)
// TODO 3：constexpr bool allows(Access have, Access need)

class RegBank {
 public:
  static constexpr std::size_t kCount = 4;
  // TODO 4：不要宣告 destructor / copy / move。成員只用標準程式庫型別。
  void set_access(std::size_t i, Access a);    // 越界 -> std::out_of_range（用 at()）
  void write(std::size_t i, std::uint32_t v);  // 越界 -> out_of_range；無 Write -> std::logic_error
  std::uint32_t read(std::size_t i) const;     // 越界 -> out_of_range；無 Read -> std::logic_error
 private:
  // TODO 5：std::array<Access, kCount> 與 std::array<std::uint32_t, kCount>
};

static_assert(std::is_nothrow_move_constructible<RegBank>::value, "move ctor 應為 noexcept");
static_assert(std::is_nothrow_move_assignable<RegBank>::value, "move assign 應為 noexcept");

int main() {
  RegBank rb;
  rb.set_access(0, Access::Read | Access::Write);
  rb.set_access(1, Access::Read);
  rb.write(0, 42);
  assert(rb.read(0) == 42);
  rb.set_access(2, Access::Read);
  assert(rb.read(2) == 0);                 // 未寫入的暫存器讀出 0
  bool threw = false;
  try { rb.write(1, 5); } catch (const std::logic_error&) { threw = true; }
  assert(threw);
  threw = false;
  try { rb.read(4); } catch (const std::out_of_range&) { threw = true; }
  assert(threw);
  RegBank moved(std::move(rb));
  assert(moved.read(0) == 42);
  std::cout << "all passed\n";
}
```

**提示**

- `enum class` 的 `|` 不會自動存在。operator 要宣告在 enum 所在的 namespace，才找得到（ADL）。
- 轉成底層整數做位元運算（`static_cast<std::uint8_t>`），結果再轉回 `Access`。
- `allows` 可以寫成「`(have & need) == need`」的形式，注意兩邊都要先轉成整數。
- `std::array::at()` 越界時丟 `std::out_of_range`，`operator[]` 越界是 UB。
- 「不寫特殊成員」成立的前提，是每個成員本身都能正確 move。`std::array<Access, 4>` 滿足嗎？（對應 G3、G10）

**驗收**：印出 `all passed`，sanitizer 沒有報告，`-std=c++11` 與 `-std=c++14` 都能編譯。

（參考解不放在檔案裡，請自己寫；寫完貼上來我看。）

---

## 核對紀錄與審查修正（2026-10-21）

1. **標準依據**：
   - ISO/IEC 14882:2011 (C++11) & ISO/IEC 14882:2014 (C++14)。
   - *Effective Modern C++* (Scott Meyers): Items 7–17 (Smart pointers, Move semantics, Lambda).
2. **Subagent 專業審查後修正項（依標準核對修正）**：
   - **Q4**：修正值類別集合劃分，補強「字串字面常數 `"str"` 為 lvalue」之常考陷阱；補充 `std::move` 需以 `std::remove_reference` 剝除引用的標準實作，而非單純 `static_cast<T&&>`。
   - **Q5**：修正 Move-only 類別無 `noexcept` 的真實行為：編譯依然能過並執行 move，但 `std::vector` 會失去 Strong Exception Guarantee 並降級為 Basic Exception Guarantee（只有具備 Copy Ctor 且 Move 非 noexcept 時才會退化回 Copy）。
   - **Q9**：更正 `+[](){}` 描述：編譯器生成的是轉型為函式指標的運算子，`+` 是工程師利用內建 unary `+` 觸發隱式轉型的慣用語。
   - **Q11**：更正歷史版本事實錯誤：普通函式回傳值推導 `auto func()` 與 `decltype(auto)` 均為 **C++14** 同步引入；補入 `decltype(auto)` 搭配 `return (x);` 回傳懸空引用的經典面試陷阱。
   - **Q12**：補入 C++14 放寬允許 `void` 回傳型別之 `constexpr` 函式。
   - **Q14**：補充 MSVC 歷史選項 `/volatile:ms` 陷阱與 ARM/RISC-V 實體晶片 MMIO 需搭配匯流排屏障之細節。
   - **C1**：加入標準推薦之 **Copy-and-Swap** 慣用法，補充 `operator[]` 與非成員 `swap` 支援。
3. **與 SystemC/TLM Virtual Platform 的連結點**：
   - Q1/Q2/Q9：TLM payload 與 callback 儲存機制、memory manager 生命週期、`std::function` 開銷。
   - Q5/Q6/C1：SystemC custom transaction buffer 與 internal queue 重分配安全性。
   - Q12/Q14/Q15：硬體暫存器建模、MMIO access、bit-field 遮罩定義。

### 第零模組驗證紀錄（2026-10-21）

- 環境：`g++ -std=c++14`，`-Wall -Wextra`；sanitizer 題另加 `-fsanitize=address`。
- L1-1：實跑，`n1/n2/n3` 的型別以 `static_assert` + `std::is_same` 確認，兩個迴圈後 `names` 分別是 `ab`、`a!b!`。
- L1-2：`f(NULL)` 在 GCC 為 ambiguous 錯誤；`f(0)`、`f(nullptr)` 分別呼叫 `f(int)`、`f(char*)`；重複的 `RED` 報 `conflicts with a previous declaration`；`Derived::f()` 少了 `const` 時 `-Wall -Wextra` 無警告，加 `override` 後報錯。
- L1-3：實跑，`s` 為空、`cs` 保持 `const`、`t` 保持 `keep`、`std::unique_ptr` 被搬走後為 null。
- L1-4：(1)、(3) 報 `use of deleted function`，(6) 可編譯。
- L2-1 ~ L2-3：輸出為實跑結果；L2-2 實測 segfault 與 ASan `stack-use-after-return`，L2-3 實測 `2 2`、修正後 `1 2`（`~A`、`~B` 依序印出）與 LeakSanitizer 報告。
- L2-4：測試對舊版會觸發 4 個 `static_assert` 失敗；另以私下寫的參考解驗證測試可通過（ASan + UBSan 乾淨）。參考解不放在檔案裡，請自己寫。

### 事實修正（2026-11-03）

環境：g++ 11.4.0（Ubuntu 22.04），`-std=c++11` / `-std=c++14`；SystemC 2.3.3 原始碼（`/home/alan/cpp_practice/side_project/uArch/systemc-2.3.3`）。下列每項先重新驗證，與文件不符才改。

1. **Q2（private 建構子與 friend）**
   - 原敘述：`make_shared` 無法建構 private 建構子，「除非設為 friend 或使用 Passkey Idiom」。
   - 實測：`friend std::make_shared<T>()` 報 `T::T() is private`；Passkey 版 `make_shared` 編譯執行通過（ASan/UBSan 乾淨）；static factory + `new` 亦通過。
   - 修改：改為「friend 不可行」，給 Passkey（保留單次配置）與 static factory（失去單次配置）兩種做法，附可編譯示範。
2. **C2（修法與題數）**
   - 原敘述：修法寫「join 執行緒」，程式碼用 `detach()`；題目寫「3 處」，參考答案實列 4 項。
   - 實測：detach 後無法 join；改為 init capture + `std::thread` 成員 + 解構時 join 的版本，`-pthread` 編譯，ASan/UBSan 乾淨。
   - 修改：修法敘述、新增完整修正版程式碼；題目改為「3 處嚴重 + 1 處次要」，與參考答案一致。
3. **L2-3（輸出）**
   - 原敘述：修好後輸出 `1 2 1`。
   - 實測：原版輸出 `2 2`；修好版 `main` 只印兩個數，輸出 `1 2`、`~A`、`~B`、`after scope`。另加印 `b->a.use_count()` 為 1。
   - 修改：答案改為 `1 2`，註明 `b->a.use_count()` 未被印出；核對紀錄同步更正。
4. **MC17、L2-2（`<<` 串接內多次呼叫）**
   - 原敘述：`cout << f() << " " << f()` 直接寫，答案以實測順序為準。
   - 實測：C++14 的 `<<` 串接中，各 `f()` 求值順序未定；拆成獨立語句後，MC17 輸出 `1 2 0` / `3 3`、L2-2 輸出 `1 2`，與原答案一致。
   - 修改：兩題的程式碼拆成獨立語句，MC17 答案補一句說明。全檔 grep：MC16（`w.use_count() << w.expired() << (w.lock() == nullptr)`）同一串接內含 `w.lock()`，但物件已 `reset()`，`lock()` 回傳空指標、不改變計數，結果與順序無關，未改動。
5. **Q9（標準 socket 的 callback 機制）**
   - 原敘述：「SystemC standard socket 採用成員函式指標 callback」。
   - 實測：`tlm_fw_bw_ifs.h` 中 `nb_transport_fw` 等宣告為 `= 0`（pure virtual）；`simple_target_socket.h` 的 `register_nb_transport_fw(MODULE*, NBTransportPtr)` 把 `MODULE::*` 存入 `fw_process` 適配器。
   - 修改：區分標準 socket（綁 pure virtual 介面）與 `tlm_utils` convenience socket（成員函式指標 + 適配器）。
6. **Q9（`sizeof(std::function)`）**
   - 原敘述：libstdc++ 32、libc++ 48、MSVC 64 bytes。
   - 實測：本機 libstdc++ 下 `sizeof(std::function<void()>)` 為 32（`-std=c++11`、`c++14` 皆同）；libc++ 與 MSVC 未在本機驗證。
   - 修改：補註「libstdc++ 實測，libc++/MSVC 可能不同」。
7. **L2-4（`size()` 來源）**
   - 原敘述：規格未指定 `size()` 的資料來源。
   - 實測：`size()` 回傳 `regs_.size()` 的參考解通過 harness（`all passed`，ASan/UBSan 乾淨）；另存 `n_` 的版本在 `assert(a.size() == 0)` 處 abort。
   - 修改：規格第 1 點補上「`size()` 由 `regs_` 推得，不另存 `n_`」。

### 補充題驗證紀錄（2026-11-05）

- 環境：g++ 11.4.0（Ubuntu 22.04），`-std=c++11` 與 `-std=c++14`，`-Wall -Wextra`；sanitizer 題另加 `-fsanitize=address,undefined`。每題一支 `.cpp`，同時編譯兩個標準、執行、記錄 exit code 與 stdout/stderr。答案裡的輸出與錯誤訊息都是實測結果。
- 教學導讀：G1（`[=]`、`[m = m]`）、G2（`this` 二次 control block）、G3（Rule of Zero 與 `D d2(std::move(d1))`）、G4（`run_fast`/`run_slow` 輸出 `2`，MC34 計數）、G5（forwarding 輸出）、G6（`fib`/`fact` 在 C++11/14 的差異，`sq(n)` 錯誤訊息）、G7（`Perm` 輸出 `10 1`、`2`）、G8（`override` 錯誤訊息）、G9（`sizeof == 64` 通過）、G10（`terminate`，exit 134）、G11（`3 1 3`、`2 ab`；`init_dangle` 的 `-Winit-list-lifetime` 警告與垃圾值）。
- 選擇題：
  - MC26、MC28、MC31、MC32、MC33、MC35、MC36、MC37、MC38、MC39、MC40、MC41、MC42、MC43：編譯與輸出如答案所述，`-std=c++11` 與 `c++14` 都跑過。
  - MC27：`no match for 'operator|'`。
  - MC29：三個 `static_assert` 通過（A、B、C 為真；D 為假）。
  - MC30：程式 exit 134，stdout 為 `start`、`in f`。為避免 `-Wterminate` 警告把答案提前洩漏，`f` 內改為呼叫 `thrower()`，警告消失。
  - MC34：輸出 `0 1 1` 與 `110`（libstdc++ 行為，`-std=c++11`、`c++14` 相同）。
  - MC35：`5 1`（`-std=c++14`）。`-std=c++11` 下 GCC 對 `[m = m]` 只給警告 `lambda capture initializers only available with '-std=c++14'`，不是錯誤，所以題目標 C++14，不以 C++11 錯誤作為判準。`-std=c++20 -Wall` 對 `[=]` 有 `implicit capture of 'this' via '[=]' is deprecated in C++20` 警告（實測）。
  - MC36：`static_assert` 失敗、`g = f` 報 `no match for 'operator='`。
  - MC37：`bad_weak_ptr` 與 `2`（libstdc++ 行為，見下方未驗證項）。
  - MC39：加上 `~D() {}` 時 `use of deleted function 'D::D(const D&)'`；不加解構子時通過。
- 問答題：
  - Q3：`std::unique_ptr<void>` 實測 `can't delete pointer to incomplete type`（`/usr/include/c++/11/bits/unique_ptr.h`，`default_delete` 的 static_assert），C++11/14 都是編譯錯誤。
  - Q8：`int (*fp)(int, int) = add;` 在 `-std=c++14` 通過；`-std=c++11` 連 generic lambda 本身都不合法。
  - Q16：buggy 版未加 sanitizer 時 segfault（exit 139）；加 `-fsanitize=address` 時報 `stack-use-after-scope`；修正版輸出 `tick 1`、`device gone, skip`、`done`。
  - Q17：`1 2`、`parent=root`、`~root`、`~child`、`end`。
  - Q18：三個 `static_assert` 通過；`LogFile b(std::move(a));` 編譯執行通過。
  - Q19：`run_fast` 與 `run_slow` 輸出 `2`（見 G4）。
  - Q20：`rvalue ctor`、`lvalue ctor`、`lvalue ctor`（第二行是 `make_bad` 的輸出）。
  - Q21：C 陣列與 `std::array` 的 `sizeof` 都是 16；`raw` 參數 `sizeof` 是 8（`-Wsizeof-array-argument`）；`copy size=4`；`static_assert(ca[1] == 2)` 與 `static_assert(ca.size() == 3)` 在兩個標準都通過。
  - Q22：`std::vector<int>` 與 `std::string` 的 move ctor 為 `is_nothrow_move_constructible` 真（libstdc++）；`unique_ptr<FILE, FcloseFn>` 為 1 個指標大小，函式指標 deleter 為 2 個指標大小。
- 手寫練習（E1、E2）：參考解放在 scratchpad（不在檔案裡），在 `-std=c++11` 與 `c++14`、`-fsanitize=address,undefined` 下輸出 `all passed`。骨架本身不能編譯（預期，TODO 尚未完成）。
- 事實修正（2026-11-05）：
  1. Q3：`unique_ptr<void>` 原本寫「未定義行為或編譯錯誤」，實測是確定的編譯錯誤，已改寫。
  2. Q8：`operator auto(*)(T1, T2)() const` 的寫法不合法，改成實測可用的函式指標轉換敘述。
- 未驗證或只有實作行為（需要標準原文或其他編譯器才能確認）：
  - 條文名稱：本檔引用的 [dcl.init.list]、[except.spec]、[class.copy]、[util.move_if_noexcept]、[util.smartptr.enab]、[dcl.type.decltype] 等，**只對照名稱，未核對標準全文**，本機沒有 ISO 原文。
  - MC37 的 `shared_from_this()` 結果是 libstdc++ 行為，標準層面屬前置條件，未核對條文細節。
  - MC34 的 SBO 門檻與 trivially copyable 規則是 libstdc++ 實作，libc++ 與 MSVC 未驗證。
  - MC31 的 `{2, "ab"}` 退回一般建構子，是 libstdc++ 實測；未核對 [dcl.init.list] 的逐步規則。
  - Q21 / Q22 的 `constexpr` 與 `noexcept` 結論只代表 libstdc++ 行為。
  - MC12（既有題）本輪未更動，仍只驗證了 libstdc++ 的行為。
- 範圍決定：
  - 「structured use in SystemC-style code」若指 structured bindings，那是 C++17，不在本檔範圍；G12 只說明為何不教。
