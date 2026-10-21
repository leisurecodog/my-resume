# Task

## Goal
為半導體廠（聯發科 VDK / SystemC / Virtual Platform、耐能、群聯等）面試整理 C++11 / C++14 高頻核心考題與參考答案。

## Scope
- 記憶體管理與智慧指標（unique_ptr, shared_ptr, weak_ptr, make_unique, custom deleter）
- Move Semantics、右值引用、Rule of Five / Zero、noexcept 原理
- Lambda 表達式、捕獲陷阱、C++14 Init capture、Generic lambda、std::function 成本
- 物件導向、override / final、型別推導（auto / decltype / decltype(auto)）、C++14 放寬之 constexpr、enum class
- 底層系統與並行（std::atomic vs volatile、C++14 binary literals 與數字分隔符）
- 白板手寫實作題（Buffer rule of five、Code review 找錯題）
- 漸進式難度（2026-10-21 加入）：題目分 L1 學習 → L2 應用 → L3 面試 → L4 深入；`cpp11-14-quiz.md` 新增第零模組（L1-1–L1-4、L2-1–L2-4）並為舊題補級別標籤；新增 `study/systemc-core-quiz.md`（L1-1–L1-3、L2-1–L2-3、L3-1、L4-1）。

## Acceptance criteria
- 考題分門別類，包含觀念題、情境分析題、白板手寫題與陷阱題。
- 每題具備折疊式參考答案，包含底層原理、編譯器機制與系統建模關聯。
- 檔案納入 `study/cpp11-14-quiz.md`，同步更新 `tasks/` 狀態。

## Steps
- [x] 整理 C++11/14 考題與參考答案，建立 `study/cpp11-14-quiz.md`
- [x] 更新 `tasks/task.md`、`tasks/progress.md`、`tasks/handoff.md`、`CLAUDE.md`
- [x] 輸出考題架構與重點解析給使用者
- [x] 加入 L1–L2 入門與應用題（C++11/14 與 SystemC 核心），預測輸出題實跑驗證
- [x] `cpp11-14-quiz.md` 加選擇題 MC1–MC25（先選擇、後問答）
- [ ] 使用者做完 L1–L2 後，再補 TLM-2.0 的 L1–L2（入門與 AT）
