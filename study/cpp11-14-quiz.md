# C++11 / C++14 面試與核心觀念複習題

對應 `tasks/learning-plan.md` 第 1 項（C++14）與 `mediatek/prep-notes.md` 第一部分，目標：能說明類別設計、手寫 C++11/14 常考語法，並應對 SystemC / Modeling / 底層系統軟體職缺的面試追問。

用法：先看題目，嘗試在紙上或白板口頭作答/手寫，再展開 `<details><summary>參考答案</summary>` 對照。每題標記常考公司/類型（觀念題、手寫題、陷阱題）。

**難度分級**（標在每題標題後）：L1 學習（看懂概念，附提示）→ L2 應用（預測輸出、找錯、動手改）→ L3 面試（開放式問答與白板題）→ L4 深入（陷阱、效能、原理）。建議順序：先做選擇題（MC1–MC25，由淺到深），再做「問答題與手寫題」：第零模組（L1–L2），最後是第一模組之後的 L3、L4 題。

---

## 目錄
- [選擇題：先建立直覺 (MC1–MC25)](#選擇題先建立直覺mc1mc25)（先做這一段，再做下面的問答題）
- [第零模組：L1 入門 與 L2 應用 (L1-1–L1-4、L2-1–L2-4)](#第零模組l1-入門-與-l2-應用)
- [第一模組：記憶體管理與智慧指標 (Q1–Q3)](#第一模組記憶體管理與智慧指標)
- [第二模組：Move Semantics、右值與生命週期 (Q4–Q6)](#第二模組move-semantics右值與生命週期)
- [第三模組：Lambda 表達式與函式物件 (Q7–Q9)](#第三模組lambda-表達式與函式物件)
- [第四模組：物件導向、型別推導與編譯期計算 (Q10–Q13)](#第四模組物件導向型別推導與編譯期計算)
- [第五模組：底層系統、並行與 Bit 操作 (Q14–Q15)](#第五模組底層系統並行與-bit-操作)
- [第六模組：白板手寫實作題 (C1–C2)](#第六模組白板手寫實作題)

---

## 選擇題：先建立直覺（MC1–MC25）

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
std::cout << f() << " " << f() << " " << x << "\n";
auto g = f;
std::cout << g() << " " << f() << "\n";
```

兩行輸出是？

- A. `1 2 2` 和 `3 3`
- B. `1 2 0` 和 `1 3`
- C. `1 1 0` 和 `1 1`
- D. `1 2 0` 和 `3 3`

<details>
<summary>答案</summary>

**D。** 值捕獲的 `x` 是 lambda 內部自己的一份複本，預設 `operator()` 是 `const`，不能改它，要加 `mutable`（沒加會編譯錯誤，實測 `increment of read-only variable 'x'`）。修改的是內部那份，外面的 `x` 仍是 0。`f()` 兩次得到 1、2；`auto g = f;` **複製整個 closure，連內部狀態（目前是 2）一起複製**，所以 `g()` 得到 3，`f()` 也得到 3。這就是為什麼「有狀態的 lambda 被複製」會出乎意料。

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

### 選擇題驗證紀錄（2026-10-21）

- 環境：`g++ -std=c++14 -Wall`（MC4、MC24 另用 `-std=c++11` 對照）；MC14、MC15 用 `-fsanitize=address`；MC25 用 `-O2 -pthread`，本機 12 核心。
- 每題的程式碼與輸出都實際執行過，答案裡引用的錯誤訊息與數字都是實測。MC25 的數字每次執行會不同，只代表「會少於 2000000」。
- MC12 的「`std::vector` move construction 後保證為空」引用 C++ 標準對容器的規定，沒有查標準原文，本機只驗證了 libstdc++ 的行為。MC13 的 `auto y{1}` 結果依賴編譯器版本（g++ 5 以上）。

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
  std::cout << c() << " " << c() << "\n";
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
2. 把「反向」那邊改成 `std::weak_ptr`，例如 `struct B { std::weak_ptr<A> a; ... };`。修好後實測輸出：

   ```
   1 2 1
   ~A
   ~B
   after scope
   ```

   `a.use_count()` 是 1（`weak_ptr` 不計入 strong count），`b.use_count()` 是 2（區域變數與 `a->b`）；`b->a.use_count()` 也是 1。離開 scope 時 `a` 先歸零釋放（`~A`），釋放 `A::b` 之後 `b` 歸零（`~B`）。
3. LeakSanitizer：用 `g++ -fsanitize=address` 編譯，程式結束時會報 `LeakSanitizer: detected memory leaks`（實測有抓到）；valgrind 的 `--leak-check=full` 也可以。設計上先想「誰擁有誰」：有明確的擁有者用 `unique_ptr`，從屬方用裸指標或 `weak_ptr`。

</details>

---

### L2-4：動手題：改成 Rule of Zero〔L2〕

這題是動手練習，只給規格和測試，不提供完成版。請自己改完，編譯、跑過測試，再貼上來我看。

**規格**

下面的 `RegBank` 是手寫資源管理的舊版：用 `new[]` 管暫存器陣列、用裸指標管 `Logger`，而且 destructor 忘了釋放 `Logger`（leak）。請把它改成 **Rule of Zero**：

1. 成員改成 `std::vector<uint32_t>`、`std::string`、`std::unique_ptr<Logger>`。
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
  2. **無法存取私有建構子**：若 class 建構子為 `private`（如 Singleton 或 Factory），`make_shared` 在外部無法建構，除非設為 friend 或使用 Passkey Idiom。
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
  - `std::shared_ptr<void>` 可藉由 Control Block 內擦除的 deleter 正確呼叫解構；但 `std::unique_ptr<void>` 屬於未定義行為或編譯錯誤。
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
- **底層函式指標轉型**：無捕獲的 Generic Lambda，編譯器同樣會生成泛型的函式指標轉換模板：`template<typename T1, typename T2> operator auto(*)(T1, T2)() const;`。

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
- **`std::function` 實作大小參考**：libstdc++ 實作通常為 32 bytes（內建 16 bytes SBO buffer）；libc++ 為 48 bytes（24 bytes buffer）；MSVC STL 為 64 bytes（40 bytes buffer）。

**2. `std::function` 機制與在模擬模型中的瓶頸**
- **Type Erasure（型別擦除）**：`std::function` 是一個萬用容器，能包裝任何可呼叫物件（lambda、functor、成員函式指標）。為了抹除具體型別，它內部維護一個虛擬函式表或函式指標（呼叫器與釋放器）。
- **Small Buffer Optimization (SBO)**：內部通常提供約 16–32 bytes 的本機緩衝區。若捕獲的物件小於此容量，就直接放在物件內；一旦超過，就必須在 heap 動態配置記憶體！
- **TLM / 效能模型中的地雷**：
  - 在每秒執行數百萬次 transaction 的 simulation loop 中，如果每個 payload 回呼都包一層 `std::function`，將面臨：
    1. **無法 inline**：嚴重的 instruction cache miss 與 branch misprediction。
    2. **潛在 heap allocation**：若捕獲變數稍大，每次綁定 callback 都觸發 `malloc/free`，直接摧毀模擬速度。
  - **解法**：在 TLM 框架中優先使用 template 參數靜態綁定，或使用純成員函式指標 callback（如 SystemC standard socket 採用的方式）。

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

請指出下列代碼中的 **3 處嚴重設計缺陷或 Bug**，並提供修正方式：

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
- **修正**：利用 C++14 Init Capture 明確複製字串本體：`[name = dev_name_, timeout_ms]() { ... }`，並在解構前等待（join）執行緒或通知中止。
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

</details>

**上次的弱點：** 尚未考過。

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
- L2-1 ~ L2-3：輸出為實跑結果；L2-2 實測 segfault 與 ASan `stack-use-after-return`，L2-3 實測 `2 2`、修正後 `1 2 1` 與 LeakSanitizer 報告。
- L2-4：測試對舊版會觸發 4 個 `static_assert` 失敗；另以私下寫的參考解驗證測試可通過（ASan + UBSan 乾淨）。參考解不放在檔案裡，請自己寫。

