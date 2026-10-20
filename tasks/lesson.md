# Lessons

<!-- One entry per lesson: what happened, why, what to do next time. -->

- 2026-10-20: 憑記憶寫的 TLM 參考答案，對照本機 SystemC 2.3.3 原始碼（`~/cpp_practice/side_project/uArch/systemc-2.3.3`）後找到漏洞：streaming width 預設是 0 不是 data length、`is_response_error()` 對 INCOMPLETE 也成立、simple target socket 是雙向 b/nb 轉換。下次寫 TLM/SystemC 的參考答案時，寫完就直接 grep 這份原始碼核對，不要先交出去再補。
- 2026-10-20: 評分 JD 前要先確認 PDF 是否真的被截斷，並區分「條件區的資格」與「工作內容的職責」。初評把 Performance 驗證的 sign-off、cycle approximate model（只在職責）當成核心門檻，條件區其實只寫「Familiar with」，分數低估 12 分；也誤報了哪幾份被截斷。下次評分直接 `pdftotext` 讀全文並檢查「顯示全部」，不要憑記憶或舊註記。
- 2026-10-13: 備戰筆記裡「待確認」的項目，使用者回答後要同步回 `mediatek/prep-notes.md` 的缺口表，不要只留在 `tasks/progress.md`。否則兩處的說法會不一致（例如文件類先前寫「三種都寫過」，實際只有 msg IP）。
