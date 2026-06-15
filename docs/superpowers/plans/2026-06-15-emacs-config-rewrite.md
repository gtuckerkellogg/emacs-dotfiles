# Modular Literate Emacs Configuration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2,259-line `gtk.org` monolith with a modular literate config — many small `literate/*.org` files tangling to committed `modules/gtk-*.el` — that loads robustly on native Ubuntu GUI, WSL2, and terminal Emacs.

**Architecture:** `early-init.el` + `init.el` bootstrap `straight.el`/`use-package`, load a gitignored `local.el` for machine specifics, then load each module from an explicit ordered manifest, each inside `condition-case`. Modules are pre-tangled `.el` (startup never depends on org/babel). Editing a `literate/*.org` re-tangles its module on save. Pure helpers (path, platform predicates, the loader) are unit-tested with ERT; declarative modules are verified by a clean batch load to a sentinel.

**Tech Stack:** GNU Emacs 30.2, `straight.el`, `use-package`, Vertico stack (vertico/consult/marginalia/orderless/corfu/cape), `eglot`, `flycheck`, org-mode, ERT, GNU Make.

---

## Conventions used in this plan

- **Repo root** is `/home/gtk/src/emacs-dotfiles` (the isolated dev checkout). The live `~/.emacs.d` is NOT touched until the cutover task.
- **`make` runs from repo root.** All `emacs` invocations use that cwd.
- **Load test command** (used as the integration check throughout):
  ```bash
  emacs -q --init-directory="$PWD" --batch -l "$PWD/early-init.el" -l "$PWD/init.el" --eval '(message "INIT-OK")'
  ```
  First run downloads packages via straight (slow, minutes); later runs are fast. "Pass" = output ends with `INIT-OK` and no `Error`/`Warning (error)` lines.
- **Interactive smoke test:** `emacs --init-directory="$PWD"` — launches a real session using this config without affecting `~/.emacs.d`.
- **"Port from legacy/…" steps** reference files committed under `legacy/` in Task 1 — a stable, committed artifact, not a placeholder. Reproduce the referenced block verbatim, then apply the explicitly listed edits. These exist because the user's bespoke elisp (export backends, capture templates, R window rules) is already correct and retyping risks transcription bugs; the modern-replacement code is always given in full.
- Every `modules/gtk-NAME.el` ends with `(provide 'gtk-NAME)`. Every `literate/NAME.org` ends with a `# Local Variables:` block enabling tangle-on-save (shown in Task 5; identical pattern in each literate file thereafter).
- Commit after every task. Commit messages use Conventional Commits and end with the `Co-Authored-By` trailer.

---

## File Structure

```
early-init.el                     # GC/native-comp/UI-suppression, before GUI
init.el                           # bootstrap straight+use-package, load local.el, run module manifest
local.example.el                  # committed template for machine-specific values
local.el                          # GITIGNORED machine values (created from template)
custom.el                         # GITIGNORED Customize scratchpad
Makefile                          # tangle / compile / test-units / test-load / test / lint
lisp/gtk-loader.el                # standalone, unit-testable module loader + manifest
literate/core.org      → modules/gtk-core.el
literate/platform.org  → modules/gtk-platform.el
literate/completion.org→ modules/gtk-completion.el
literate/ui.org        → modules/gtk-ui.el
literate/editing.org   → modules/gtk-editing.el
literate/org.org       → modules/gtk-org.el
literate/org-gtd.org   → modules/gtk-org-gtd.el
literate/org-export.org→ modules/gtk-org-export.el
literate/writing.org   → modules/gtk-writing.el
literate/vc.org        → modules/gtk-vc.el
literate/shells.org    → modules/gtk-shells.el
literate/prog.org      → modules/gtk-prog.el
literate/langs.org     → modules/gtk-langs.el
test/gtk-core-test.el             # ERT for path helpers
test/gtk-platform-test.el         # ERT for platform predicates
test/gtk-loader-test.el           # ERT for module loader error handling
legacy/                           # frozen copy of the old config, for porting reference
docs/superpowers/specs/2026-06-15-emacs-config-rewrite-design.md
docs/superpowers/plans/2026-06-15-emacs-config-rewrite.md   # this file
```

---

## Phase 0 — Scaffolding

### Task 1: Freeze legacy, create skeleton, gitignore, Makefile

**Files:**
- Create: `legacy/` (populated), `lisp/`, `literate/`, `modules/`, `test/`
- Modify: `.gitignore`
- Create: `Makefile`

- [ ] **Step 1: Freeze the current config as a porting reference**

The authoritative current config is the live `~/.emacs.d`. Copy its source files (not runtime artifacts) into `legacy/` for reference:

```bash
cd /home/gtk/src/emacs-dotfiles
mkdir -p legacy
for f in init.el gtk.org code-functions.org shells-and-terminals.org \
         system-settings.org exwm.org hunspell.org; do
  [ -f "$HOME/.emacs.d/$f" ] && cp "$HOME/.emacs.d/$f" "legacy/$f"
done
for d in insert lisp exwm; do
  [ -d "$HOME/.emacs.d/$d" ] && cp -r "$HOME/.emacs.d/$d" "legacy/$d"
done
ls -la legacy
```
Expected: `legacy/` contains `gtk.org`, `init.el`, the supporting `.org` files, and `insert/` (letter templates).

- [ ] **Step 2: Remove the now-duplicated old config from repo root**

The root-level org/init files are superseded by `legacy/` + the new layout:

```bash
cd /home/gtk/src/emacs-dotfiles
git rm -q init.el gtk.org code-functions.org shells-and-terminals.org \
       system-settings.org exwm.org 2>/dev/null
rm -rf exwm vterm
mkdir -p lisp literate modules test
```
(README.org stays; it is rewritten in Task 19.)

- [ ] **Step 3: Write `.gitignore`**

```gitignore
# Runtime / build artifacts
/straight/
/eln-cache/
/elpa/
/auto-save-list/
/backups/
/transient/
/var/
/.cache/
*.elc

# Machine-local and Customize state
/local.el
/custom.el
/bookmarks
/projectile-bookmarks.eld
/.org-id-locations
/.lsp-session-v1
/.mc-lists.el
/places
```

- [ ] **Step 4: Write the `Makefile`**

```makefile
EMACS ?= emacs
ROOT  := $(CURDIR)

.PHONY: tangle test-units test-load test compile lint clean

## Tangle every literate/*.org to its module (targets declared in each file).
tangle:
	$(EMACS) -Q --batch --eval "(require 'org)" \
	  --eval "(setq org-confirm-babel-evaluate nil)" \
	  --eval "(dolist (f (directory-files (expand-file-name \"literate\" \"$(ROOT)\") t \"\\\\.org\\\\'\")) (org-babel-tangle-file f))"

## Fast ERT unit tests for pure helpers (no package install, no network).
test-units:
	$(EMACS) -q --batch -L $(ROOT)/lisp -L $(ROOT)/modules \
	  -l $(ROOT)/lisp/gtk-loader.el \
	  -l $(ROOT)/modules/gtk-core.el \
	  -l $(ROOT)/modules/gtk-platform.el \
	  -l $(ROOT)/test/gtk-loader-test.el \
	  -l $(ROOT)/test/gtk-core-test.el \
	  -l $(ROOT)/test/gtk-platform-test.el \
	  -f ert-run-tests-batch-and-exit

## Full startup in batch against this config dir; must reach the sentinel.
test-load:
	$(EMACS) -q --init-directory=$(ROOT) --batch \
	  -l $(ROOT)/early-init.el -l $(ROOT)/init.el \
	  --eval "(message \"INIT-OK\")"

test: test-units test-load

## Byte-compile modules using the real, fully-initialized environment.
compile:
	$(EMACS) -q --init-directory=$(ROOT) --batch \
	  -l $(ROOT)/early-init.el -l $(ROOT)/init.el \
	  --eval "(byte-recompile-directory (expand-file-name \"modules\" user-emacs-directory) 0 t)"

clean:
	rm -f $(ROOT)/modules/*.elc $(ROOT)/lisp/*.elc
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: scaffold modular layout, freeze legacy config, add Makefile

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 1 — Bootstrap & loader

### Task 2: The module loader (`lisp/gtk-loader.el`) — TDD

**Files:**
- Create: `lisp/gtk-loader.el`
- Test: `test/gtk-loader-test.el`

- [ ] **Step 1: Write the failing test**

`test/gtk-loader-test.el`:
```elisp
;;; gtk-loader-test.el --- tests for the module loader  -*- lexical-binding: t; -*-
(require 'ert)
(require 'gtk-loader)

(ert-deftest gtk-loader-returns-t-on-success ()
  "Loading an already-available feature returns non-nil."
  (should (gtk/load-module 'gtk-loader)))

(ert-deftest gtk-loader-returns-nil-on-missing ()
  "A missing feature is caught: returns nil, does not signal."
  (should-not (gtk/load-module 'gtk-no-such-module-xyzzy)))

(ert-deftest gtk-loader-manifest-is-symbol-list ()
  "The manifest is a non-empty list of symbols."
  (should (consp gtk/modules))
  (should (cl-every #'symbolp gtk/modules)))

(provide 'gtk-loader-test)
```

- [ ] **Step 2: Run it, verify it fails**

Run: `emacs -q --batch -L lisp -L test -l test/gtk-loader-test.el -f ert-run-tests-batch-and-exit`
Expected: FAIL — `Cannot open load file: gtk-loader`.

- [ ] **Step 3: Implement `lisp/gtk-loader.el`**

```elisp
;;; gtk-loader.el --- ordered, fault-tolerant module loader  -*- lexical-binding: t; -*-
;;; Commentary:
;; Standalone (no package deps) so it is unit-testable in `-q --batch'.
;;; Code:
(require 'cl-lib)

(defvar gtk/modules
  '(gtk-core
    gtk-platform
    gtk-completion
    gtk-ui
    gtk-editing
    gtk-org
    gtk-org-gtd
    gtk-org-export
    gtk-writing
    gtk-vc
    gtk-shells
    gtk-prog
    gtk-langs)
  "Ordered list of configuration modules to load.")

(defun gtk/load-module (feature)
  "Require FEATURE, warning instead of erroring on failure.
Return non-nil on success, nil on failure."
  (condition-case err
      (progn (require feature) t)
    (error
     (display-warning 'gtk
                      (format "Failed to load %s: %s"
                              feature (error-message-string err))
                      :error)
     nil)))

(defun gtk/load-all-modules ()
  "Load every module in `gtk/modules', tolerating individual failures."
  (dolist (m gtk/modules) (gtk/load-module m)))

(provide 'gtk-loader)
;;; gtk-loader.el ends here
```

- [ ] **Step 4: Run tests, verify pass**

Run: `emacs -q --batch -L lisp -L test -l test/gtk-loader-test.el -f ert-run-tests-batch-and-exit`
Expected: `Ran 3 tests ... 3 passed`.

- [ ] **Step 5: Commit**

```bash
git add lisp/gtk-loader.el test/gtk-loader-test.el
git commit -m "feat: fault-tolerant module loader with ordered manifest

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 3: `early-init.el`

**Files:**
- Create: `early-init.el`

- [ ] **Step 1: Write `early-init.el`**

```elisp
;;; early-init.el --- pre-GUI startup tuning  -*- lexical-binding: t; -*-
;;; Commentary:
;; Runs before the GUI and before package.el. Keep it minimal and dep-free.
;;; Code:

;; Raise GC ceiling during startup; restored to a sane value after init.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;; We manage packages with straight.el; disable package.el at startup.
(setq package-enable-at-startup nil)

;; Quiet native-comp; let it run async without nagging.
(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t)

;; Suppress GUI chrome early to avoid a flash of toolbars.
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(scroll-bar-width . 0) default-frame-alist)
(setq inhibit-startup-message t
      frame-inhibit-implied-resize t)

(provide 'early-init)
;;; early-init.el ends here
```

- [ ] **Step 2: Verify it loads cleanly**

Run: `emacs -q --batch -l "$PWD/early-init.el" --eval '(message "EARLY-OK")'`
Expected: prints `EARLY-OK`, no errors.

- [ ] **Step 3: Commit**

```bash
git add early-init.el
git commit -m "feat: early-init with GC and native-comp tuning

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 4: `init.el` — straight bootstrap, local.el, manifest run

**Files:**
- Create: `init.el`
- Create: `local.example.el`

- [ ] **Step 1: Write `local.example.el`**

```elisp
;;; local.example.el --- machine-specific values  -*- lexical-binding: t; -*-
;;; Commentary:
;; Copy to local.el (gitignored) and edit per machine. Loaded early by init.el
;; inside condition-case, so a missing or broken file only warns.
;;; Code:

;; Root of your synced files (Dropbox, Syncthing, etc.).
(setq gtk/dropbox-root (expand-file-name "~/Dropbox/"))

;; Conda / mamba install prefix, or nil to skip conda integration.
(setq gtk/conda-home (expand-file-name "~/miniforge3"))

;; Preferred fonts; each falls back gracefully if unavailable (see gtk-ui).
(setq gtk/fixed-font    "Input Mono Narrow"
      gtk/variable-font "Open Sans")

;; Bibliography directory (used by citations); nil to skip.
(setq gtk/bib-dir nil)

;; Org publish targets appended to org-publish-project-alist; nil for none.
(setq gtk/extra-publish-projects nil)

(provide 'local)
;;; local.example.el ends here
```

- [ ] **Step 2: Write `init.el`**

```elisp
;;; init.el --- entry point  -*- lexical-binding: t; -*-
;;; Commentary:
;; Bootstraps straight.el + use-package, loads machine-local settings, then
;; loads each configuration module from an ordered, fault-tolerant manifest.
;;; Code:

;; Make our own elisp discoverable.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "modules" user-emacs-directory))

;; Per-system build dir keeps multiple machines/Emacs versions from clashing.
(defconst gtk/system-string
  (concat (replace-regexp-in-string "/" "-" (format "%s" system-type))
          "-emacs-" emacs-version))

;; --- straight.el bootstrap -------------------------------------------------
(setq straight-use-package-by-default t
      straight-recipes-gnu-elpa-use-mirror t
      straight-repository-branch "develop"
      straight-build-dir (concat "straight/build-" gtk/system-string))

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         user-emacs-directory))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(require 'use-package)
(setq use-package-always-defer nil)

;; exec-path-from-shell early so GUI/daemon sessions see the user's PATH.
(use-package exec-path-from-shell
  :if (or (memq window-system '(mac ns x pgtk)) (daemonp))
  :config (exec-path-from-shell-initialize))

;; --- machine-local settings ------------------------------------------------
(let ((local (expand-file-name "local.el" user-emacs-directory)))
  (if (file-exists-p local)
      (condition-case err
          (load local nil 'nomessage)
        (error (display-warning 'gtk
                 (format "local.el failed to load: %s"
                         (error-message-string err)) :error)))
    (display-warning 'gtk "No local.el; copy local.example.el and edit it." :warning)))

;; Customize writes to a gitignored scratch file, never to init.el.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil 'nomessage))

;; --- load all modules ------------------------------------------------------
(require 'gtk-loader)
(gtk/load-all-modules)

(provide 'init)
;;; init.el ends here
```

- [ ] **Step 3: Verify bootstrap reaches the manifest**

At this point all 13 modules are missing, so the loader will emit 13 warnings but must NOT error out, and startup must complete.

Run the load test command (first run installs straight + use-package; minutes):
```bash
emacs -q --init-directory="$PWD" --batch -l "$PWD/early-init.el" -l "$PWD/init.el" --eval '(message "INIT-OK")'
```
Expected: warnings `Failed to load gtk-core ...` etc., then `INIT-OK`. No uncaught error, exit status 0.

- [ ] **Step 4: Commit**

```bash
git add init.el local.example.el
git commit -m "feat: init.el — straight bootstrap, local.el loader, module manifest

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 2 — Core modules (pure-function TDD)

### Task 5: `core` module + path-helper tests

**Files:**
- Create: `literate/core.org`, tangles to `modules/gtk-core.el`
- Test: `test/gtk-core-test.el`

- [ ] **Step 1: Write the failing test**

`test/gtk-core-test.el`:
```elisp
;;; gtk-core-test.el --- tests for core helpers  -*- lexical-binding: t; -*-
(require 'ert)
(require 'gtk-core)

(ert-deftest gtk-core-emacs-path-expands-under-ued ()
  (let ((user-emacs-directory "/tmp/ued/"))
    (should (equal (gtk/emacs-path "foo/bar")
                   "/tmp/ued/foo/bar"))))

(ert-deftest gtk-core-emacs-path-handles-trailing ()
  (let ((user-emacs-directory "/tmp/ued/"))
    (should (string-prefix-p "/tmp/ued/" (gtk/emacs-path "x")))))

(provide 'gtk-core-test)
```

- [ ] **Step 2: Run it, verify it fails**

Run: `emacs -q --batch -L modules -L test -l test/gtk-core-test.el -f ert-run-tests-batch-and-exit`
Expected: FAIL — `Cannot open load file: gtk-core`.

- [ ] **Step 3: Write `literate/core.org`**

````org
#+title: Core defaults and helpers
#+property: header-args:emacs-lisp :tangle ../modules/gtk-core.el :results silent

* Header
#+begin_src emacs-lisp
;;; gtk-core.el --- core defaults and helpers  -*- lexical-binding: t; -*-
;;; Commentary:
;; Built-in settings and pure helpers. No external packages, no use-package,
;; so this file loads standalone (and is unit-testable in -q --batch).
;;; Code:
(require 'cl-lib)
#+end_src

* Path helpers
#+begin_src emacs-lisp
(defun gtk/emacs-path (path)
  "Expand PATH relative to `user-emacs-directory'."
  (expand-file-name path user-emacs-directory))
#+end_src

* Identity
#+begin_src emacs-lisp
(setq user-full-name "Greg Tucker-Kellogg"
      user-mail-address "dbsgtk@gmail.com")
#+end_src

* Sane defaults
#+begin_src emacs-lisp
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq sentence-end-double-space nil
      visible-bell t
      ring-bell-function #'ignore
      inhibit-startup-message t
      require-final-newline t)
(setq-default fill-column 110
              indent-tabs-mode nil)
(menu-bar-mode 1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)
(show-paren-mode 1)
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)
(setq scroll-step 0 scroll-conservatively 10000 auto-window-vscroll nil)
(setq diff-switches "-u")
(auto-compression-mode 1)
#+end_src

* Backups, autosave, recent files, places, history
#+begin_src emacs-lisp
(let ((backup-dir (gtk/emacs-path "backups/"))
      (auto-dir   (gtk/emacs-path "auto-save/")))
  (make-directory backup-dir t)
  (make-directory auto-dir t)
  (setq backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-dir t))
        backup-by-copying t
        delete-old-versions t
        version-control t))
(add-to-list 'completion-ignored-extensions ".los")
(recentf-mode 1)
(save-place-mode 1)
(savehist-mode 1)
#+end_src

* Server (interactive sessions only)
#+begin_src emacs-lisp
(unless noninteractive
  (require 'server)
  (unless (server-running-p) (server-start)))
#+end_src

* Disabled-command unlocks
#+begin_src emacs-lisp
(put 'narrow-to-region 'disabled nil)
(put 'set-goal-column 'disabled nil)
(put 'dired-find-alternate-file 'disabled nil)
#+end_src

* Footer
#+begin_src emacs-lisp
(provide 'gtk-core)
;;; gtk-core.el ends here
#+end_src

# Local Variables:
# eval: (add-hook 'after-save-hook (lambda () (when (eq major-mode 'org-mode) (org-babel-tangle))) nil t)
# End:
````

- [ ] **Step 4: Tangle and run tests**

Run:
```bash
make tangle
emacs -q --batch -L modules -L test -l test/gtk-core-test.el -f ert-run-tests-batch-and-exit
```
Expected: `modules/gtk-core.el` created; `Ran 2 tests ... 2 passed`.

- [ ] **Step 5: Commit**

```bash
git add literate/core.org modules/gtk-core.el test/gtk-core-test.el
git commit -m "feat(core): defaults, path helpers, backups, server

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 6: `platform` module + predicate tests

**Files:**
- Create: `literate/platform.org` → `modules/gtk-platform.el`
- Test: `test/gtk-platform-test.el`

- [ ] **Step 1: Write the failing test**

`test/gtk-platform-test.el`:
```elisp
;;; gtk-platform-test.el --- tests for platform detection  -*- lexical-binding: t; -*-
(require 'ert)
(require 'gtk-platform)

(ert-deftest gtk-platform-wsl-marker-positive ()
  (should (gtk//string-has-wsl-marker-p
           "Linux version 5.15.0-microsoft-standard-WSL2"))
  (should (gtk//string-has-wsl-marker-p "... Microsoft ...")))

(ert-deftest gtk-platform-wsl-marker-negative ()
  (should-not (gtk//string-has-wsl-marker-p
               "Linux version 5.15.0-176-generic"))
  (should-not (gtk//string-has-wsl-marker-p "")))

(provide 'gtk-platform-test)
```

- [ ] **Step 2: Run it, verify it fails**

Run: `emacs -q --batch -L modules -L test -l test/gtk-platform-test.el -f ert-run-tests-batch-and-exit`
Expected: FAIL — `Cannot open load file: gtk-platform`.

- [ ] **Step 3: Write `literate/platform.org`**

````org
#+title: Platform detection and per-system behavior
#+property: header-args:emacs-lisp :tangle ../modules/gtk-platform.el :results silent

* Header
#+begin_src emacs-lisp
;;; gtk-platform.el --- OS/WSL/GUI detection and per-system glue  -*- lexical-binding: t; -*-
;;; Commentary:
;; Pure marker predicate plus thin wrappers, then branch browser/PDF/clipboard.
;;; Code:
#+end_src

* Pure marker predicate (unit-tested)
#+begin_src emacs-lisp
(defun gtk//string-has-wsl-marker-p (s)
  "Return non-nil if S contains a WSL/Microsoft kernel marker."
  (and (stringp s) (string-match-p "[Mm]icrosoft" s) t))
#+end_src

* Detection predicates
#+begin_src emacs-lisp
(defvar gtk/wsl-p
  (and (eq system-type 'gnu/linux)
       (file-readable-p "/proc/version")
       (gtk//string-has-wsl-marker-p
        (with-temp-buffer (insert-file-contents "/proc/version") (buffer-string))))
  "Non-nil when running under WSL.")

(defun gtk/gui-p () "Non-nil in a graphical frame." (display-graphic-p))
(defun gtk/linux-p () (eq system-type 'gnu/linux))
(defun gtk/macos-p () (eq system-type 'darwin))
#+end_src

* Browser, PDF viewer, file apps
#+begin_src emacs-lisp
(setq browse-url-browser-function 'browse-url-default-browser)
(when gtk/wsl-p
  (setq browse-url-generic-program "wslview"
        browse-url-browser-function 'browse-url-generic))

(setq org-file-apps
      '((auto-mode . emacs)
        (directory . "setsid xdg-open \"%s\"")
        ("\\.x?html?\\'" . default)
        ("\\.pdf\\'" . "xdg-open \"%s\"")
        ("\\.pdf::\\([0-9]+\\)\\'" . "xdg-open \"%s\"")
        ("\\.docx?\\'" . "xdg-open \"%s\"")))
#+end_src

* Clipboard
#+begin_src emacs-lisp
;; In TTY frames on Linux, route kill/yank through the system clipboard when a
;; helper exists (xclip in X, clip.exe under WSL). Guarded; never fatal.
(when (and (gtk/linux-p) (not (display-graphic-p)))
  (cond
   (gtk/wsl-p
    (when (executable-find "clip.exe")
      (setq interprogram-cut-function
            (lambda (text)
              (let ((p (make-process :name "clip" :command '("clip.exe")
                                     :connection-type 'pipe)))
                (process-send-string p text) (process-send-eof p))))))
   ((executable-find "xclip")
    (when (require 'xclip nil t) (xclip-mode 1)))))
#+end_src

* Footer
#+begin_src emacs-lisp
(provide 'gtk-platform)
;;; gtk-platform.el ends here
#+end_src

# Local Variables:
# eval: (add-hook 'after-save-hook (lambda () (when (eq major-mode 'org-mode) (org-babel-tangle))) nil t)
# End:
````

Note: `xclip` is the only package referenced and it is loaded with `(require 'xclip nil t)`. Add it to straight by inserting near the top of the "Clipboard" block, before use: `(straight-use-package 'xclip)`. (Kept out of the pure section so unit tests stay package-free.)

- [ ] **Step 4: Tangle and run tests**

Run:
```bash
make tangle
emacs -q --batch -L modules -L test -l test/gtk-platform-test.el -f ert-run-tests-batch-and-exit
```
Expected: `Ran 2 tests ... 2 passed`.

- [ ] **Step 5: Full unit suite + load test**

Run: `make test-units` → all tests pass.
Run: `make test-load` → ends with `INIT-OK` (now only 11 modules warn as missing).

- [ ] **Step 6: Commit**

```bash
git add literate/platform.org modules/gtk-platform.el test/gtk-platform-test.el
git commit -m "feat(platform): WSL/GUI detection, browser/PDF/clipboard glue

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 3 — Declarative modules (verified by clean load)

For every task in this phase the verification loop is identical:
1. Write/extend the `literate/NAME.org` file (full code given below, or port-from-legacy with explicit edits).
2. `make tangle`
3. `make test-load` → must end with `INIT-OK`, no new error/warning lines for this module.
4. Commit.

The tangle `header-args` line in each file is
`#+property: header-args:emacs-lisp :tangle ../modules/gtk-NAME.el :results silent`,
each file opens with the standard `;;; gtk-NAME.el ...` header and closes with
`(provide 'gtk-NAME)` + the Local Variables tangle-on-save block (as in Task 5).

### Task 7: `completion` — Vertico stack

**Files:** Create `literate/completion.org` → `modules/gtk-completion.el`

- [ ] **Step 1: Write the module body** (between header and footer):

```elisp
(use-package vertico
  :init (vertico-mode)
  :custom (vertico-cycle t))

(use-package savehist :straight (:type built-in) :init (savehist-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-s r" . consult-ripgrep)))

(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-cycle t))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))
```

Replaces the legacy `icomplete-mode` and the entire ivy/counsel/swiper section — do not port those.

- [ ] **Step 2: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/completion.org modules/gtk-completion.el
git commit -m "feat(completion): vertico/consult/marginalia/orderless/corfu/cape

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 8: `ui` — theme, modeline, fonts, which-key, icons

**Files:** Create `literate/ui.org` → `modules/gtk-ui.el`

- [ ] **Step 1: Module body — fonts with fallback (full code):**

```elisp
(defun gtk/font-available-p (name) (and name (find-font (font-spec :name name))))

(defun gtk/apply-fonts ()
  "Apply fonts from local.el when present and available."
  (when (display-graphic-p)
    (when (and (boundp 'gtk/variable-font) (gtk/font-available-p gtk/variable-font))
      (set-face-attribute 'default nil :font gtk/variable-font :weight 'light)
      (set-face-attribute 'variable-pitch nil :font gtk/variable-font))
    (when (and (boundp 'gtk/fixed-font) (gtk/font-available-p gtk/fixed-font))
      (set-face-attribute 'fixed-pitch nil :font gtk/fixed-font :weight 'light :height 1.0))))
(add-hook 'emacs-startup-hook #'gtk/apply-fonts)
;; Re-apply for daemon clients when the first graphical frame appears.
(add-hook 'server-after-make-frame-hook #'gtk/apply-fonts)
```

- [ ] **Step 2: Module body — theme + switcher (full code):**

Port `fresh-load-theme` and `disable-all-themes` verbatim from `legacy/gtk.org` (section "Mode line behaviour", the `defun disable-all-themes` and `defun fresh-load-theme` forms). Then add the modus config and activation:

```elisp
(use-package modus-themes
  :custom
  (modus-themes-italic-constructs t)
  (modus-themes-bold-constructs t)
  (modus-themes-mixed-fonts t)
  (modus-themes-org-blocks 'gray-background)
  :config
  (load-theme 'modus-operandi :no-confirm))
```

Drop `zenburn-theme` and `doom-themes` (do not port).

- [ ] **Step 3: Module body — modeline + icons + which-key + visual-fill (full code):**

```elisp
(use-package nerd-icons)
(use-package minions :config (minions-mode 1))
(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 15)
  (doom-modeline-minor-modes t)
  (doom-modeline-buffer-file-name-style 'truncate-except-project))

(use-package which-key
  :init (which-key-mode)
  :custom (which-key-idle-delay 0.3))

(use-package visual-fill-column
  :init (setq visual-fill-column-width 110 visual-fill-column-center-text t)
  :config
  (defun turn-on-visual-fill-column () (interactive)
         (visual-fill-column-mode 1) (visual-line-mode 1))
  (defun turn-off-visual-fill-column () (interactive)
         (visual-fill-column-mode 0) (visual-line-mode 0)))
```

Drop `smart-mode-line`, `all-the-icons`, `command-log-mode`, `posframe` (not ported).

- [ ] **Step 4: tangle → load test → interactive check → commit**

```bash
make tangle && make test-load
```
Then interactively confirm the theme and modeline render: `emacs --init-directory="$PWD"`. Run `(all-the-icons-install-fonts)`'s nerd equivalent once per machine if glyphs are missing: `M-x nerd-icons-install-fonts`.
```bash
git add literate/ui.org modules/gtk-ui.el
git commit -m "feat(ui): modus theme + switcher, doom-modeline, fonts, which-key

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 9: `editing` — prog hook, parens, keys

**Files:** Create `literate/editing.org` → `modules/gtk-editing.el`

- [ ] **Step 1: Port the combined coding hook** from `legacy/code-functions.org` verbatim, with these edits:
  - Keep `gtk/local-column-number-mode`, `gtk/local-comment-auto-fill`, `gtk/turn-on-whitespace`, `gtk/run-prog-hook`, and the `add-hook` wiring.
  - DROP `gtk/pretty-lambdas` and its `add-hook` (replaced by `prettify-symbols-mode` below).
  - DROP `gtk/turn-on-save-place-mode` (global `save-place-mode` is enabled in core).

- [ ] **Step 2: Module body — misc editing helpers + global keys (full code):**

```elisp
(defun turn-on-visual-line-mode () (interactive) (visual-line-mode 1))
(defun turn-off-visual-line-mode () (interactive) (visual-line-mode -1))
(defun turn-off-cua-mode () (cua-mode -1))

(defun switch-to-minibuffer-window ()
  "Select the active minibuffer window, if any."
  (interactive)
  (when (active-minibuffer-window) (select-window (active-minibuffer-window))))

(defun unfill-paragraph (&optional region)
  "Turn a multi-line paragraph into a single line; act on REGION if given."
  (interactive (progn (barf-if-buffer-read-only) '(t)))
  (let ((fill-column (point-max)) (emacs-lisp-docstring-fill-column t))
    (fill-paragraph nil region)))

(add-hook 'prog-mode-hook #'prettify-symbols-mode)

(global-set-key (kbd "<f7>") #'switch-to-minibuffer-window)
(global-set-key (kbd "C-z") #'undo)
(global-set-key (kbd "C-c C-w") #'copy-region-as-kill)
(global-set-key (kbd "C-c q") #'auto-fill-mode)
(global-set-key (kbd "M-+") #'count-words)
(global-set-key (kbd "C-+") #'text-scale-increase)
(global-set-key (kbd "C--") #'text-scale-decrease)
(global-set-key (kbd "M-/") #'hippie-expand)
(global-set-key (kbd "C-x ^") #'join-line)
(global-set-key (kbd "C-x C-m") #'execute-extended-command)
(global-set-key (kbd "C-x \\") #'align-regexp)
```

- [ ] **Step 3: Module body — structural editing + regions (full code):**

```elisp
(use-package paredit
  :hook ((emacs-lisp-mode lisp-mode clojure-mode cider-repl-mode) . enable-paredit-mode)
  :bind (("M-[" . paredit-wrap-square) ("M-{" . paredit-wrap-curly)))

(use-package smartparens
  :hook ((org-mode text-mode markdown-mode) . smartparens-mode)
  :config (require 'smartparens-config))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package multiple-cursors
  :bind (("C-M-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package expand-region
  :bind ("C-=" . er/expand-region))

(global-hl-line-mode 1)
```

- [ ] **Step 4: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/editing.org modules/gtk-editing.el
git commit -m "feat(editing): prog hooks, paredit/smartparens, mc, keybindings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 10: `org` — core, babel, visuals, org-modern, typo

**Files:** Create `literate/org.org` → `modules/gtk-org.el`

- [ ] **Step 1: Module body — org core + babel-confirm + visual-line (full code):**

```elisp
(defun gtk/org-confirm-babel-evaluate (lang _body)
  (not (member lang '("latex" "emacs-lisp"))))
(setq org-confirm-babel-evaluate #'gtk/org-confirm-babel-evaluate)

(use-package org
  :straight (:type built-in)
  :hook ((org-mode . turn-off-auto-fill)
         (org-mode . turn-on-visual-line-mode))
  :custom
  (org-startup-indented nil)
  (org-startup-folded 'nofold)
  (org-insert-mode-line-in-empty-file t)
  (org-outline-path-complete-in-steps nil)
  (org-latex-prefer-user-labels t)
  (org-hide-leading-stars t)
  (org-pretty-entities nil)
  (org-use-property-inheritance '("PRIORITY" "STYLE" "CATEGORY"))
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (R . t) (shell . t) (dot . t)
     (python . t) (latex . t)))
  :bind (("C-c l" . org-store-link)
         ("C-c a" . org-agenda)
         ("C-c c" . org-capture)))
```

- [ ] **Step 2: Module body — org-modern + typo (full code):**

```elisp
(use-package org-modern
  :hook (org-mode . org-modern-mode)
  :custom
  (org-auto-align-tags nil)
  (org-tags-column 0)
  (org-catch-invisible-edits 'show-and-error)
  (org-special-ctrl-a/e t)
  (org-insert-heading-respect-content t)
  (org-hide-emphasis-markers t)
  (org-pretty-entities t))

(use-package typo
  :hook (org-mode . typo-mode)
  :init (setq-default typo-language "English")
  :config
  (add-hook 'typo-disable-electricity-functions #'org-in-src-block-p))
```

Drop `org-superstar` (replaced by org-modern). Do not port the duplicate org-modern/themes "Draft" blocks from legacy.

- [ ] **Step 3: Module body — org face attributes:** Port the `dolist`/`set-face-attribute` block from `legacy/gtk.org` section "Org visuals" verbatim, with one edit: wrap the whole block in `(when (display-graphic-p) ...)` so TTY startup is unaffected.

- [ ] **Step 4: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/org.org modules/gtk-org.el
git commit -m "feat(org): core, babel, org-modern, typo, faces

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 11: `org-gtd` — agenda, capture, journal, refile

**Files:** Create `literate/org-gtd.org` → `modules/gtk-org-gtd.el`

- [ ] **Step 1: Module body — directories from local.el (full code):**

```elisp
(defvar gtk/dropbox-root (expand-file-name "~/Dropbox/")) ; overridden by local.el
(setq org-directory (expand-file-name "_support/org" gtk/dropbox-root))
(defun gtk/org-path (p) (expand-file-name p org-directory))
(defvar my/inbox (expand-file-name "_inbox/inbox.org" gtk/dropbox-root))
(defvar my/organizer (gtk/org-path "organizer.org"))
(setq org-default-notes-file my/inbox)
```

- [ ] **Step 2: Module body — TODO keywords, tags, areas of focus:** Port verbatim from `legacy/gtk.org` sections "My Next Action list setup", "Categories as Areas of focus", and "Context in tags" (the `org-todo-keywords`, `org-todo-state-tags-triggers`, `org-log-into-drawer`, `org-global-properties`, `org-columns-default-format`, `org-tag-persistent-alist`, `org-tags-exclude-from-inheritance` forms). No edits.

- [ ] **Step 3: Module body — agenda + super-agenda:** Port verbatim from `legacy/gtk.org` sections "The agenda" and the `org-super-agenda` block (the `org-agenda-files`, `org-agenda-*` settings, `use-package org-super-agenda`, and `org-super-agenda-groups`). Edit: change `(setq diary-file ...)` to read from `gtk/dropbox-root`.

- [ ] **Step 4: Module body — capture, journal, refile:** Port verbatim from `legacy/gtk.org` sections "Org capture behavior" and "Archiving and refiling" (the `use-package org-journal`, `org-journal-find-location`, `org-capture-templates`, and `org-refile-*` forms). No edits.

- [ ] **Step 5: Module body — org keybindings (full code):**

```elisp
(global-set-key (kbd "C-c j") #'org-clock-goto)
(global-set-key (kbd "C-c '") #'org-cycle-agenda-files)
(global-set-key (kbd "C-c x") (lambda () (interactive) (org-capture nil "i")))
(setq org-clock-into-drawer "CLOCKING"
      org-log-into-drawer "LOGBOOK")
```

- [ ] **Step 6: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/org-gtd.org modules/gtk-org-gtd.el
git commit -m "feat(org-gtd): agenda, super-agenda, capture, journal, refile

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 12: `org-export` — LaTeX/beamer/minted/memoir, citations, filters

**Files:** Create `literate/org-export.org` → `modules/gtk-org-export.el`

- [ ] **Step 1: Module body — export backends + classes:** Port verbatim from `legacy/gtk.org` section "Org mode → Org modules and backends" the `org-export-define-derived-backend 'beamer` form, the `org-beamer-bold` defun, the `mapcar ... org-export-backends` form, and the `org-latex-image-default-*` customizations. Then port "General export → Latex", "org-memoir", "Minted for code", "Removing captions in Beamer", and "Other exporters" (`ox-md`) verbatim. Edits:
  - Replace `(org-add-link-type ...)` calls (legacy "Link types") with `org-link-set-parameters` (the modern API), one per link type (`cite`, `TERM`, `Figure`, `Table`), preserving each `:export` lambda body.
  - Remove `org-reload` calls (not needed at load time).

- [ ] **Step 2: Module body — citations (full code):**

```elisp
(use-package org-ref)
(require 'oc-biblatex)
(setq org-ref-insert-cite-function (lambda () (org-cite-insert nil)))
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c ]") #'org-ref-insert-link)
  (define-key org-mode-map (kbd "C-c C-x C-2") #'org-cite-insert))
```

- [ ] **Step 3: Module body — export filters + ox-extra:** Port verbatim from `legacy/gtk.org` the `org-contrib`/`ox-extra` setup and the three `add-to-list ... org-export-filter-*` forms (`gtk/unnumbered-beamer-caption`, `gtk/unnumbered-latex-captions`, `org-export-ignore-headlines`). Ensure `gtk/unnumbered-beamer-caption` (from "Removing captions in Beamer") is defined before it is added. If `gtk/unnumbered-latex-captions` is not defined in legacy, define it analogously:
```elisp
(defun gtk/unnumbered-latex-captions (contents backend _info)
  (when (eq backend 'latex)
    (replace-regexp-in-string "\\\\caption{" "\\\\caption*{" contents)))
```

- [ ] **Step 4: tangle → load test → export smoke test → commit**

```bash
make tangle && make test-load
```
Interactive: open a small `.org`, `C-c C-e l P` (beamer→PDF) needs `latexmk`+`minted`; confirm it builds on a machine that has them. Skip gracefully elsewhere.
```bash
git add literate/org-export.org modules/gtk-org-export.el
git commit -m "feat(org-export): latex/beamer/minted/memoir, citations, filters, links

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 13: `writing` — spelling, AUCTeX, reftex, markdown, pandoc, autoinsert

**Files:** Create `literate/writing.org` → `modules/gtk-writing.el`

- [ ] **Step 1: Module body — spelling (full code, guarded):**

```elisp
(use-package flyspell
  :straight (:type built-in)
  :if (executable-find "hunspell")
  :init (bind-key "S-<f8>" 'flyspell-mode)
  :config
  (defun gtk/flyspell-check-next-error ()
    (interactive) (flyspell-goto-next-error) (ispell-word))
  (bind-keys :map flyspell-mode-map
             ("<f8>" . gtk/flyspell-check-next-error)
             ("M-S-<f8>" . flyspell-prog-mode))
  (setq ispell-program-name "hunspell"
        ispell-dictionary "en_GB"
        ispell-personal-dictionary (expand-file-name "~/.hunspell_personal"))
  (ispell-set-spellchecker-params))
```

- [ ] **Step 2: Module body — AUCTeX + reftex:** Port verbatim from `legacy/gtk.org` sections "LaTeX", "RefTeX" (the `TeX-*`, `reftex-*`, `getpackage`, `org-mode-reftex-setup` forms). Edits: in `TeX-view-program-list` replace the macOS `"open %o"` PDF entry with `("PDF Viewer" "xdg-open %o")`; wrap with `(use-package auctex :defer t)` so AUCTeX is installed via straight.

- [ ] **Step 3: Module body — markdown/pandoc/autoinsert:** Port verbatim from `legacy/gtk.org` section "handle text mode and markdown" (the `use-package markdown-mode`, the flyspell predicate functions, `use-package pandoc-mode`, `use-package autoinsert`, and the `markdown-mode-hook` additions). Edits:
  - Set `auto-insert-directory` to `(gtk/emacs-path "insert/")` and ensure `legacy/insert/letter-template.tex` is copied to `insert/` (committed): `mkdir -p insert && cp legacy/insert/letter-template.tex insert/ 2>/dev/null`.
  - Replace the two `my-buffer-face-mode-*` font families with `gtk/variable-font`/`gtk/fixed-font` (fall back to current behavior if unbound).
  - DROP the `[s-mouse-4]`/`[s-mouse-5]` macOS-super mouse bindings.

- [ ] **Step 4: tangle → load test → commit**

```bash
mkdir -p insert && cp legacy/insert/letter-template.tex insert/ 2>/dev/null || true
make tangle && make test-load
git add literate/writing.org modules/gtk-writing.el insert/
git commit -m "feat(writing): hunspell, auctex/reftex, markdown, pandoc, autoinsert

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 14: `vc` — magit + git-gutter

**Files:** Create `literate/vc.org` → `modules/gtk-vc.el`

- [ ] **Step 1: Module body (full code, fixes the `magiett` typo):**

```elisp
(use-package with-editor)
(use-package magit
  :bind (("C-c m" . magit-status)
         ("C-c g" . magit-file-dispatch)))
(use-package git-gutter
  :config (global-git-gutter-mode 1))
```

Drop `gist` (not ported).

- [ ] **Step 2: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/vc.org modules/gtk-vc.el
git commit -m "feat(vc): magit + git-gutter (fix magit-file-dispatch typo)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 15: `shells` — vterm + eshell

**Files:** Create `literate/shells.org` → `modules/gtk-shells.el`

- [ ] **Step 1: Module body (full code):**

```elisp
(use-package vterm
  :if (executable-find "cmake")
  :commands vterm
  :config
  (setq vterm-max-scrollback 10000
        term-prompt-regexp "^[^#$%>\n]*[#$%>] *"))

(use-package eshell-git-prompt)
(defun gtk/configure-eshell ()
  (add-hook 'eshell-pre-command-hook 'eshell-save-some-history)
  (add-to-list 'eshell-output-filter-functions 'eshell-truncate-buffer)
  (setq eshell-history-size 10000
        eshell-buffer-maximum-lines 10000
        eshell-hist-ignoredups t
        eshell-scroll-to-bottom-on-input t))
(use-package eshell
  :straight (:type built-in)
  :hook (eshell-first-time-mode . gtk/configure-eshell)
  :config (eshell-git-prompt-use-theme 'multiline2))
```

Drop `term`/`eterm-256color` (not ported). `vterm` is guarded on `cmake` so machines without a compiler still start.

- [ ] **Step 2: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/shells.org modules/gtk-shells.el
git commit -m "feat(shells): vterm (guarded) + eshell

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 16: `prog` — eglot, flycheck, project, yasnippet

**Files:** Create `literate/prog.org` → `modules/gtk-prog.el`

- [ ] **Step 1: Module body (full code):**

```elisp
(use-package eglot
  :straight (:type built-in)
  :commands eglot eglot-ensure)

(use-package flycheck
  :init
  (defun gtk/disable-flycheck-in-org-src ()
    (setq-local flycheck-disabled-checkers '(emacs-lisp-checkdoc)))
  (add-hook 'org-src-mode-hook #'gtk/disable-flycheck-in-org-src)
  :config
  (global-flycheck-mode)
  (setq flycheck-keymap-prefix (kbd "C-c f"))
  (define-key flycheck-mode-map (kbd "C-c f") flycheck-command-map))

;; Bridge eglot diagnostics into flycheck so there is one diagnostics UI.
(use-package flycheck-eglot
  :after (flycheck eglot)
  :config (global-flycheck-eglot-mode 1))

;; Prose linting via vale, when installed.
(use-package flycheck-vale
  :if (executable-find "vale")
  :config (flycheck-vale-setup))

(use-package yasnippet
  :hook (prog-mode . yas-minor-mode))
(use-package yasnippet-snippets :after yasnippet)

(use-package projectile
  :bind-keymap ("C-c p" . projectile-command-map)
  :custom (projectile-create-missing-test-files t)
  :config
  (projectile-mode 1)
  (projectile-register-project-type
   'r '("DESCRIPTION")
   :project-file "DESCRIPTION"
   :compile "R CMD INSTALL --with-keep.source ."
   :test "R CMD check -o /tmp/ ."
   :src-dir '("R/" "src/") :test-dir "tests/" :test-prefix "test-"))
```

Drop `company` (replaced by corfu in completion module) and the legacy commented-out `lsp-mode` block.

- [ ] **Step 2: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/prog.org modules/gtk-prog.el
git commit -m "feat(prog): eglot, flycheck (+eglot/vale bridges), projectile, yasnippet

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 17: `langs` — per-language modes

**Files:** Create `literate/langs.org` → `modules/gtk-langs.el`

- [ ] **Step 1: Module body — elisp (full code):**

```elisp
(use-package elisp-slime-nav
  :hook (emacs-lisp-mode . turn-on-elisp-slime-nav-mode))
(add-hook 'emacs-lisp-mode-hook #'turn-on-eldoc-mode)
(add-hook 'emacs-lisp-mode-hook #'gtk/run-prog-hook)
(with-eval-after-load 'elisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-c v") #'eval-buffer)
  (define-key emacs-lisp-mode-map (kbd "C-c C-c") #'eval-defun))
```

- [ ] **Step 2: Module body — R/ess:** Port verbatim from `legacy/gtk.org` section "R" (the `use-package ess`, `ess-R-font-lock-keywords`, the `ess-r-mode-hook`/`ess-rdired-mode-hook` `<f9>` bindings, the `display-buffer-alist` for R/Help windows, the projectile R registration, `poly-R`, `quarto-mode`). No edits. (The projectile R type is also registered in `prog`; keep ess's `with-eval-after-load 'projectile` form — `projectile-register-project-type` is idempotent.)

- [ ] **Step 3: Module body — python (full code):**

```elisp
(use-package conda
  :if (and (boundp 'gtk/conda-home) gtk/conda-home (file-directory-p gtk/conda-home))
  :custom
  (conda-anaconda-home gtk/conda-home)
  (conda-env-home-directory gtk/conda-home))
(use-package pet
  :hook (python-base-mode . pet-mode))
```

- [ ] **Step 4: Module body — clojure/cider:** Port verbatim from `legacy/gtk.org` section "Clojure" (the `use-package cider` with eval-overlay advice). No edits.

- [ ] **Step 5: Module body — rust/stan/snakemake/groovy + misc (full code):**

```elisp
(use-package rustic
  :mode ("\\.rs\\'" . rustic-mode)
  :custom (rustic-format-on-save t)
  :config (setq rustic-lsp-client 'eglot))

(use-package stan-mode)
(use-package snakemake-mode)
(use-package groovy-mode)
(use-package yaml-mode :hook (yaml-mode . (lambda () (auto-fill-mode -1))))
(use-package dockerfile-mode)
```

Drop julia, lua, sparql, js2-mode (not ported). The legacy rustic block's `lsp-ui`/`lsp-*` bindings are replaced by eglot defaults; do not port them.

- [ ] **Step 6: tangle → load test → commit**

```bash
make tangle && make test-load
git add literate/langs.org modules/gtk-langs.el
git commit -m "feat(langs): elisp, R, python, clojure, rust(eglot), stan, snakemake, groovy

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 4 — Integration, reproducibility, docs, cutover

### Task 18: Full integration + lockfile

**Files:** Create `straight/versions/default.el` (via command)

- [ ] **Step 1: Clean full load + compile**

```bash
make clean && make tangle && make test && make compile
```
Expected: unit tests pass, `INIT-OK` printed, byte-compile finishes (warnings acceptable; no errors).

- [ ] **Step 2: Interactive multi-environment smoke test**

Run `emacs --init-directory="$PWD"` and confirm in each available environment (native GUI, then a `-nw` run `emacs -nw --init-directory="$PWD"`, then WSL when on that machine):
  - theme + modeline render; `M-x` shows vertico; `C-s` is consult-line.
  - `C-c a` opens the agenda; `C-c c` capture works.
  - `M-x magit-status` works; an R file opens with ess and the side-window layout.
  - No `*Warnings*` errors at startup.

Record any failures as follow-up fixes before proceeding.

- [ ] **Step 3: Freeze the lockfile**

In the running Emacs: `M-x straight-freeze-versions`. Then:
```bash
git add straight/versions/default.el
git commit -m "chore: freeze straight package versions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 19: Documentation

**Files:** Modify `README.org`

- [ ] **Step 1: Rewrite `README.org`** to cover: the module layout, how to bootstrap on a new machine (`git clone` to `~/.emacs.d`, copy `local.example.el`→`local.el`, start Emacs, run `M-x nerd-icons-install-fonts`), the `make` targets, the tangle-on-save workflow, and `straight-thaw-versions` for reproducing package versions. Keep it concise.

- [ ] **Step 2: Verify `local.example.el` lists every variable** referenced via `gtk/` in `modules/` (grep to confirm none are missing):
```bash
grep -rhoE 'gtk/(dropbox-root|conda-home|fixed-font|variable-font|bib-dir|extra-publish-projects)' modules | sort -u
```
Every name printed must appear in `local.example.el`. Add any missing.

- [ ] **Step 3: Commit**

```bash
git add README.org local.example.el
git commit -m "docs: README for modular config + complete local.example.el

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task 20: Cutover (manual, user-confirmed)

> Do not run this until the user has used the new config from the dev directory and is satisfied. This step changes the live `~/.emacs.d`.

- [ ] **Step 1: Back up the live config**

```bash
mv ~/.emacs.d ~/.emacs.d.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Clone/move the new config into place**

```bash
git clone git@github.com:gtuckerkellogg/emacs-dotfiles.git ~/.emacs.d
cd ~/.emacs.d && git checkout rewrite/modular-literate
```

- [ ] **Step 3: Create the machine-local file**

```bash
cp ~/.emacs.d/local.example.el ~/.emacs.d/local.el
$EDITOR ~/.emacs.d/local.el   # set dropbox-root, conda-home, fonts for THIS machine
```

- [ ] **Step 4: First real launch**

Start Emacs normally; let straight install (uses the committed lockfile). Run `M-x nerd-icons-install-fonts`. Confirm parity against the smoke-test checklist from Task 18.

- [ ] **Step 5: Merge and tag**

Once stable on at least one machine:
```bash
cd ~/.emacs.d
git checkout main && git merge --no-ff rewrite/modular-literate
git tag config-v2-modular
git push origin main --tags
```
Keep `~/.emacs.d.bak-*` until the new config has run cleanly on every machine. Remove `legacy/` in a follow-up commit once parity is confirmed everywhere.

---

## Self-Review

**Spec coverage:**
- Loading architecture (early-init/init/manifest/condition-case, pre-tangled .el) → Tasks 2–4. ✓
- Module map (13 modules) → Tasks 5–17 (one per module). ✓
- Conflict resolutions (modeline, corfu-not-company, vertico-not-ivy/icomplete, nerd-icons, org-modern-not-superstar, flycheck+vale+eglot bridge) → Tasks 7, 8, 10, 16. ✓
- Drops (EXWM, julia/lua/sparql, dired+/popwin/gist/command-log/bm/term/pretty-lambdas/zenburn/doom-themes/org-roam) → called out as "do not port" in Tasks 8, 9, 14, 15, 16, 17. ✓ (dired+ → built-in dired: the legacy dired+ block is simply not ported; built-in dired needs no config task. Noted here so it isn't mistaken for a gap.)
- Machine handling (predicates + local.el + executable-find guards) → Tasks 4, 6, and guards in 13/15/17. ✓
- Build/test/deploy (Makefile, --init-directory isolation, lockfile, cutover) → Tasks 1, 18, 20. ✓
- Success criteria (clean start in 3 environments, no hardcoded secrets, make test passes, modular) → Tasks 18, 19. ✓

**Placeholder scan:** Port-from-legacy steps reference committed `legacy/` files with explicit edit lists — not placeholders. Modern-replacement code is given in full. No "TBD"/"add error handling"/"similar to Task N".

**Type/name consistency:** `gtk/load-module`/`gtk/load-all-modules`/`gtk/modules` (Task 2) used consistently in init.el (Task 4). `gtk/emacs-path` (Task 5) used in Tasks 13. `gtk//string-has-wsl-marker-p`/`gtk/wsl-p` (Task 6) used in platform branches. `gtk/run-prog-hook` defined in editing (Task 9), used in langs elisp (Task 17). `gtk/dropbox-root`/`gtk/conda-home`/`gtk/fixed-font`/`gtk/variable-font` defined in local.example (Task 4), consumed in Tasks 8, 11, 13, 17, and audited in Task 19. Tangle target naming `gtk-NAME` consistent throughout.
