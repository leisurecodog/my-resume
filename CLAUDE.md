# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Alan's (Feng-An Hsieh) job-hunt workspace, currently in **study mode**: interview prep for SystemC/TLM/C++ modeling roles (target: MediaTek VDK, see `mediatek/prep-notes.md`). It also holds his LaTeX resume, forked from the dphang/resume Lato-font template (MIT). There is no application code, only `.tex` sources, their compiled PDFs, and Markdown study material. The repo is under git on branch `main`, with remote `origin` at git@github.com:leisurecodog/my-resume.git (SSH). LaTeX build artifacts are listed in `.gitignore`.

## Study mode

Treat this repo as Alan's study desk. Act as his tutor and mock interviewer. Resume edits happen only when he asks.

**Default assumption: he does not know the topic yet.** Teach each new concept first (plain explanation, a small code example, the common pitfall), then check understanding with questions. Skip the teaching and go straight to quizzing only when he says he already knows that topic. Once taught, he does the thinking in the quiz and exercises, and you steer it.

1. **Review last session first** (every session, before anything new): read `tasks/handoff.md`, `tasks/progress.md`, and the latest practice record and weak-points section of the relevant `study/` file. Recap in a few lines what he learned last time and where he slipped, then ask 2–3 short review questions on those weak points. Re-teach anything he misses. Only then move on to the next topic they point to.
2. **Teach, then quiz**: for a new topic, teach it (see the default assumption above), then ask one question at a time, at his current level (L1 to L4). Wait for his answer, then grade it: what was right, the exact gap, one follow-up. Raise the level after a clean answer; drop back and re-teach after a miss.
3. **Hint ladder**: when he is stuck, give a nudge, then a narrower hint, then the explanation. Reveal the full answer after he has attempted or asked for it.
4. **Practice exercises** (rule-of-five, scheduler drills, anything he plans to hand-write): give the spec, a test harness or skeleton with TODOs, and hints. Show reference code after he has written his own attempt and asked for review.
5. **Verify first**: run predict-the-output and API claims against local SystemC 2.3.3 / g++ (`-std=c++11`) or the SystemC source before stating them. Cite the standard clause or source file for behavior claims.
6. **Record**: add each round's results, weak points and next-round questions to the matching `study/` file; update `tasks/` per the Layout rules below.

Study material is Traditional Chinese with English code and terms; reply in the language Alan writes in.

## Build

Local TeX Live is available (`pdflatex`, `latexmk`). Compile in place; output PDF/aux/log land beside the source:

```
latexmk -pdf base/resume.tex
latexmk -pdf mediatek/resume-mediatek-vdk.tex   # run from the file's directory or use -outdir
```

Requires the `lato`, `fontawesome`, `mdwlist`, `enumitem`, `newunicodechar` packages. `fontawesome` icons are used in the header, so a missing package fails the build.

## Layout

- `base/`: the canonical resume and its variants, each with its compiled PDF and LaTeX logs.
  - `base/resume.tex`: the canonical one-page resume (A4, 0.5in margins, 11pt). Sections: Summary, Experience, Skills, Education.
  - `base/resume.old.tex`, `base/resume.2page.tex`: earlier/longer variants kept for reference. Don't edit unless asked.
- `credo/`, `mediatek/`: per-employer tailored copies (`resume-<company>*.tex`) derived from `base/resume.tex`. Each has its own compiled PDF and LaTeX logs. Tailoring means reworking the Summary, bullets and Skills ordering to match that company's job description, not changing the template macros.
- `mediatek/prep-notes.md`: interview prep notes (Traditional Chinese) tied to the MediaTek VDK JD (review checklists, gap table, VDK-related study steps).
- `study/`: company-independent study material (Traditional Chinese). `study/tlm-quiz.md` holds TLM-2.0 LT/quantum/DMI review questions; `study/cpp11-14-quiz.md` holds C++11/14 core interview questions and coding exercises with collapsible reference answers; `study/systemc-core-quiz.md` holds SystemC core (process, event, delta cycle, scheduler) questions; all three quiz files start with a multiple-choice section (MC) before the open-ended questions; `study/tlm-quiz.md` MC code builds with the same `-std=c++11` SystemC flags. Questions are tagged by level L1 (learning) to L4 (deep), and the L1–L2 sections come first. Predict-the-output answers are run against the local SystemC 2.3.3 (build with `-std=c++11`) or g++. Add new rounds' results there; put future quiz/review files for other topics in `study/` too.
- `JD/`: saved 104.com.tw job postings (PDFs, mostly semiconductor/ESL/SystemC/NPU modeling roles). Use these as the source of truth when tailoring a resume to a role. `JD/fit-ranking.md` holds the fit scores and apply order for all of them.
- `tasks/`: working notes for the current job. `task.md` (goal, scope, acceptance criteria, steps), `progress.md` (done / in progress / blocked), `handoff.md` (state, files touched, next steps, gotchas for the next session), `lesson.md` (lessons learned), `learning-plan.md` (cross-JD study order, derived from the gap statistics in `JD/fit-ranking.md`). Read `handoff.md` and `progress.md` at the start of a session. Always update the files in `tasks/` before finishing any piece of work: `progress.md` when status changes, `handoff.md` with files touched and next steps, `task.md` if scope or steps change, and `lesson.md` when you learn something worth keeping.
- `README.md`, `LICENSE`: upstream template files.
- `misc/`: upstream `resume-example.pdf` plus stray build artifacts (`pdflatex*.fls`, `resume.zip`), safe to ignore or delete.
- `*.aux`, `*.log`, `*.fls`, `*.fdb_latexmk`: build artifacts, safe to ignore or delete.

## Conventions in the `.tex` files

- Shared macros are defined in each file's preamble (`\headerrow{left}{right}` for two-column left/right lines, `\CPP` for the styled C++, `indentsection`/`unindentsection`). Variants copy the preamble rather than `\input` it, so a macro change must be repeated in each file.
- Experience entries use nested `itemize*` (mdwlist) inside an `itemize`, with `\labelitemi` blanked. Keep that structure to preserve spacing.
- Resumes are meant to stay on one page. After any content edit, recompile and confirm the PDF is still one page.
- Content is bilingual-context: resumes are in English, JDs and prep notes are partly in Traditional Chinese. LaTeX source uses `\newunicodechar` only for full-width parentheses; other CJK text would need an engine/package change (xeCJK).
