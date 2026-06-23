# Org → Typst export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register the `ox-typst` Org export backend so Org buffers can be exported to Typst markup and to PDF via the Typst CLI from the standard export dispatcher.

**Architecture:** Add a single `use-package ox-typst` form to the existing `modules/gtk-org-export.el` module. The package self-registers its backend on the export dispatcher (key `y`) when loaded; all package defaults are accepted, so no further configuration is needed.

**Tech Stack:** Emacs Lisp, straight.el + use-package, Org export framework, `ox-typst` (MELPA), the `typst` CLI.

## Global Constraints

- `modules/gtk-org-export.el` is the only source file modified; it is already listed in `lisp/gtk-loader.el` and requires no manifest change.
- Accept all `ox-typst` defaults verbatim: `org-typst-process` = `"typst c \"%s\""`, and both `org-typst-from-latex-fragment` / `org-typst-from-latex-environment` = `#'org-typst-from-latex-with-naive`. Do **not** set these variables.
- No custom Typst template/preamble, no `org-typst-process` override, no Typst branches added to existing `cite`/`TERM`/`Figure`/`Table` link definitions.
- Match the existing file's style: declarative `use-package` forms, lexical binding, concise comments.

---

### Task 1: Register the ox-typst export backend

**Files:**
- Modify: `modules/gtk-org-export.el` (add a `use-package ox-typst` form near the existing backend registrations around line 99–100)

**Interfaces:**
- Consumes: the Org export framework (`org`, already required by this module's `with-eval-after-load 'org` blocks and by `gtk-org` earlier in the load order).
- Produces: a registered Org export backend named `typst`, discoverable via `(org-export-get-backend 'typst)` and shown in `org-export-dispatch` under the `y` key. Adds no new public functions of our own; the backend supplies `org-typst-export-as-typst`, `org-typst-export-to-typst`, and `org-typst-export-to-pdf`.

- [ ] **Step 1: Write the failing check**

This change is a backend registration, verified by a batch assertion against a full config load (the project has no package-installing unit-test harness; `make test-units` deliberately avoids loading org/packages). Run this one-liner, which loads the full init and checks whether the `typst` backend is registered:

```bash
emacs -q --init-directory=$PWD --batch \
  -l $PWD/early-init.el -l $PWD/init.el \
  --eval "(kill-emacs (if (org-export-get-backend 'typst) 0 1))" \
  && echo TYPST-BACKEND-PRESENT || echo TYPST-BACKEND-ABSENT
```

- [ ] **Step 2: Run it to verify it fails**

Run the command from Step 1 from the repo root (`/home/gtk/.emacs.d`).
Expected: prints `TYPST-BACKEND-ABSENT` (the backend is not yet registered; exit code 1).

- [ ] **Step 3: Add the use-package form**

In `modules/gtk-org-export.el`, immediately after the `(mapcar (lambda (x) (add-to-list 'org-export-backends x :append)) '(beamer odt))` form (currently lines 99–100), insert:

```elisp
;; Org -> Typst export.  ox-typst self-registers its backend on the export
;; dispatcher (key `y') when loaded; we accept all package defaults (naive
;; LaTeX-math conversion, `typst c' for PDF).  Typst *editing* lives in
;; gtk-langs.el.
(use-package ox-typst
  :after org)
```

- [ ] **Step 4: Run the check to verify it passes**

Run the command from Step 1 again.
Expected: prints `TYPST-BACKEND-PRESENT` (exit code 0).

- [ ] **Step 5: Byte-compile and full-load cleanly**

Run:

```bash
make compile && make test-load
```

Expected: `make compile` byte-compiles `modules/` with no new errors/warnings attributable to `gtk-org-export.el`; `make test-load` prints `INIT-OK`.

- [ ] **Step 6: Commit**

```bash
git add modules/gtk-org-export.el
git commit -m "feat(org): org->typst export via ox-typst

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual smoke test (optional, after Task 1)

In an interactive Emacs session with this config:

1. Open any `.org` file.
2. `C-c C-e` → confirm an `[y] Export to Typst` entry appears.
3. `y f` → confirm a sibling `.typ` file is written.
4. `y p` → confirm a PDF is produced (requires `typst` on PATH).
