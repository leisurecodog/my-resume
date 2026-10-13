# Handoff

## Current state
- 針對聯發科 SystemC/TLM Modeling Engineer (VDK) 備戰，學習順序見 `mediatek/prep-notes.md`。
- 使用者已回答缺口問題，結論在 `progress.md`，並已寫進 `mediatek/prep-notes.md` 第三部分（缺口表）與第四部分（學習方向與建議）。
- 已完成：四份履歷的 AMBA 措辭改為整合與 spec 閱讀層級（見 `progress.md`）；`prep-notes.md` 第三部分 CI/CD 說法已改為「個人專案自己架過 CI，工作上沒用過」。

## Files touched
- `credo/resume-credo.tex`、`credo/resume-credo-fw.tex`（只改 AMBA 措辭，未加 simulation speed bullet）
- `mediatek/prep-notes.md`（缺口表更新、新增第四部分）
- `tasks/lesson.md`
- `CLAUDE.md`（Build / Layout 路徑改為 `base/`、`misc/`）
- `tasks/progress.md`、`tasks/handoff.md`
- `base/resume.tex`（加同一條 bullet）與重新編譯的 `base/resume.pdf`
- `mediatek/resume-mediatek-vdk.tex`（加一條 bullet）與重新編譯的 `mediatek/resume-mediatek-vdk.pdf`

## Next steps
- 若使用者有個人專案的 CI，可考慮在履歷補一行（先確認專案名稱與工具）。
- Bullet 已加入 MediaTek 版（無數字）。若找回加速倍數再補。
- 面試準備：為何變快（context switch / scheduler 事件變少）、精度取捨、如何確認功能一致。
- 文件只限 msg IP，履歷不要寫成平台層文件。

## Gotchas
- 已加到 MediaTek 版與 `base/resume.tex`；`credo/` 尚未加，使用者要求才動。
- `resume.tex` 已搬到 `base/`，CLAUDE.md 的 Build / Layout 已於 2026-10-13 更新（含 `misc/`）。
- 該 bullet 放在 Chief Engineer（2026/7 起）底下，因 messaging IP 出現在該職稱；實際優化發生的時期若不同需調整。
