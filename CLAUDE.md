# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal LaTeX resume (Feng-An "Alan" Hsieh), forked from the dphang/resume Lato-font template (MIT). There is no application code, only `.tex` sources and their compiled PDFs. The repo is under git on branch `main`, with remote `origin` at https://github.com/leisurecodog/my-resume.git. LaTeX build artifacts are listed in `.gitignore`.

## Build

Local TeX Live is available (`pdflatex`, `latexmk`). Compile in place; output PDF/aux/log land beside the source:

```
latexmk -pdf resume.tex
latexmk -pdf mediatek/resume-mediatek-vdk.tex   # run from the file's directory or use -outdir
```

Requires the `lato`, `fontawesome`, `mdwlist`, `enumitem`, `newunicodechar` packages. `fontawesome` icons are used in the header, so a missing package fails the build.

## Layout

- `resume.tex`: the canonical one-page resume (A4, 0.5in margins, 11pt). Sections: Summary, Experience, Skills, Education.
- `resume.old.tex`, `resume.2page.tex`: earlier/longer variants kept for reference. Don't edit unless asked.
- `credo/`, `mediatek/`: per-employer tailored copies (`resume-<company>*.tex`) derived from `resume.tex`. Each has its own compiled PDF and LaTeX logs. Tailoring means reworking the Summary, bullets and Skills ordering to match that company's job description, not changing the template macros.
- `mediatek/prep-notes.md`: interview prep notes (Traditional Chinese) tied to the MediaTek JD.
- `JD/`: saved 104.com.tw job postings (PDFs, mostly semiconductor/ESL/SystemC/NPU modeling roles). Use these as the source of truth when tailoring a resume to a role.
- `tasks/`: working notes for the current job. `task.md` (goal, scope, acceptance criteria, steps), `progress.md` (done / in progress / blocked), `handoff.md` (state, files touched, next steps, gotchas for the next session), `lesson.md` (lessons learned). Read `handoff.md` and `progress.md` at the start of a session and update them when work changes state.
- `resume-example.pdf`, `README.md`, `LICENSE`: upstream template artifacts.
- `*.aux`, `*.log`, `*.fls`, `*.fdb_latexmk`, `pdflatex*.fls`, `resume.zip`: build artifacts, safe to ignore or delete.

## Conventions in the `.tex` files

- Shared macros are defined in each file's preamble (`\headerrow{left}{right}` for two-column left/right lines, `\CPP` for the styled C++, `indentsection`/`unindentsection`). Variants copy the preamble rather than `\input` it, so a macro change must be repeated in each file.
- Experience entries use nested `itemize*` (mdwlist) inside an `itemize`, with `\labelitemi` blanked. Keep that structure to preserve spacing.
- Resumes are meant to stay on one page. After any content edit, recompile and confirm the PDF is still one page.
- Content is bilingual-context: resumes are in English, JDs and prep notes are partly in Traditional Chinese. LaTeX source uses `\newunicodechar` only for full-width parentheses; other CJK text would need an engine/package change (xeCJK).
