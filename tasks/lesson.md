# Lessons

<!-- One entry per lesson: what happened, why, what to do next time. -->

- 2026-10-21: 整理 C++11/14 考題時，初稿出現兩處標準細節失準：(1) 誤將普通函式回傳值推導 `auto func()` 當作 C++11 就有，實則與 `decltype(auto)` 皆為 C++14 引入（C++11 僅有尾置型別 `-> decltype(...)`）；(2) `std::move_if_noexcept` 判定條件為 `!is_nothrow_move && is_copy`，對 move-only 物件依然會 move 並通過編譯，代價是 `std::vector` 失去 Strong Exception Guarantee 降級為 Basic。撰寫核心觀念題庫時，應嚴格對照 ISO 標準標準庫規範與 cppreference，區分簡化口訣與真實編譯器行為。
- 2026-10-20: 憑記憶寫的 TLM 參考答案，對照本機 SystemC 2.3.3 原始碼（`~/cpp_practice/side_project/uArch/systemc-2.3.3`）後找到漏洞：streaming width 預設是 0 不是 data length、`is_response_error()` 對 INCOMPLETE 也成立、simple target socket 是雙向 b/nb 轉換。下次寫 TLM/SystemC 的參考答案時，寫完就直接 grep 這份原始碼核對，不要先交出去再補。
- 2026-10-20: 評分 JD 前要先確認 PDF 是否真的被截斷，並區分「條件區的資格」與「工作內容的職責」。初評把 Performance 驗證的 sign-off、cycle approximate model（只在職責）當成核心門檻，條件區其實只寫「Familiar with」，分數低估 12 分；也誤報了哪幾份被截斷。下次評分直接 `pdftotext` 讀全文並檢查「顯示全部」，不要憑記憶或舊註記。
- 2026-10-13: 備戰筆記裡「待確認」的項目，使用者回答後要同步回 `mediatek/prep-notes.md` 的缺口表，不要只留在 `tasks/progress.md`。否則兩處的說法會不一致（例如文件類先前寫「三種都寫過」，實際只有 msg IP）。
- 2026-10-21: 寫「預測輸出」題前先在本機實跑再寫答案。這次發現本機 SystemC library 用 C++11 編，直接用 c++14 會連結失敗；也發現 `sc_start(6,SC_NS)` 不跑 6 ns 當下的 process、wait(time, event) 參數順序是時間、單位、事件。這些憑記憶容易寫錯。給使用者的動手練習題，用私下寫的參考解驗證測試，但不放進檔案（見記憶：不給完整解）。
- 2026-10-21: 在本機跑 SystemC 實驗時，`sc_start()` 配上永遠重排 `next_trigger` 的 `SC_METHOD` 不會結束，背景輸出檔一度暴增到 2.7GB。以後跑沒把握會停的 SystemC 程式，一律用 `sc_start(時間)` 加 `timeout`，並把輸出接到 `head`。
- 2026-10-21: 寫 AT（nb_transport）示範程式時，initiator 的 thread 在交易還沒結束就離開，堆疊上的 payload 被銷毀，target 稍後存取就 segfault（沒有任何 SystemC 錯誤訊息）。非阻塞交易的 payload 與資料緩衝區必須活到交易結束；範例要等 `done` 事件才離開，真實專案用 memory manager 或 pool。另外 `tlm_quantumkeeper` 在第一次 `reset()` 之前 `need_sync()` 永遠是 true，且全域 quantum 預設為 0，兩者都不會報錯，只會讓 temporal decoupling 失效。
- 2026-10-21: 寫 AT 題時發現三個「不會報錯、只是悄悄出錯」的陷阱，題目與 `study/tlm-quiz.md` 已收錄：(1) `peq_with_get` 的 consumer 每次醒來只呼叫一次 `get_next_transaction()`，同時到期的第二筆之後再也不會被送出；(2) 對經 nb→b 轉換的 target 在 `BEGIN_RESP` 回 `TLM_ACCEPTED` 卻不送 `END_RESP`，下一筆回應永遠卡住；(3) `simple_target_socket` 對有註冊 `nb_transport_fw` 的 target 不檢查 phase 方向。寫範例前先在原始碼裡找這類「靜默失敗」的路徑，題目價值最高。
