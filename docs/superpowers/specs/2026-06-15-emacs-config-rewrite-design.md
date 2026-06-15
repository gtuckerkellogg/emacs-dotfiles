# Design: Modular Literate Emacs Configuration

**Date:** 2026-06-15
**Author:** Greg Tucker-Kellogg (with Claude)
**Status:** Draft for review

## Problem

The current Emacs configuration is a literate org-mode setup that tangles to
Emacs Lisp, uses `straight.el`, and runs across several machines. Two things
work well and must be preserved: the literate org + tangle workflow, and the
`straight.el` package manager. But the configuration has decayed:

- **It is a monolith.** `gtk.org` is 2,259 lines covering everything from themes
  to ~15 language modes. It is not modular and is hard to reason about or change
  safely.
- **It carries real bugs and cruft.** Typos that silently break behavior
  (`(org.mode . turn-off-cua-mode)`, `magiett-file-dispatch`, a bare floating
  `'gtk/run-prog-hook`), duplicate blocks (`org-modern`, `org-ref`,
  `modus-themes`, and the themes section all appear twice), and large amounts of
  commented-out dead code.
- **Conflicting stacks run simultaneously.** Both `ivy`/`counsel`/`swiper` and
  `icomplete` are active; both `smart-mode-line` and `doom-modeline`; both
  `company` (would conflict with a modern corfu).
- **System-specific dependencies are hardcoded into committed code.** `~/Dropbox`,
  `~/miniforge3`, an NUS FTP publish target, a macOS-ism (`"open %o"` as PDF
  viewer), and specific font names with no fallback. There is no handling for
  WSL vs native Linux vs terminal use.
- **Startup depends on org/babel health.** `init.el` calls
  `org-babel-load-file` on `gtk.org`, which itself chains
  `org-babel-load-file` into other org files. A problem in org or babel breaks
  the entire startup.

The goal is a clean, modular, robust replacement that represents modern Emacs
Lisp practice and runs well on native Ubuntu (GUI), WSL2 on Windows, and in a
terminal (`-nw`).

## Environment

- GNU Emacs 30.2.
- Live config currently *is* `~/.emacs.d` (a checkout of
  `git@github.com:gtuckerkellogg/emacs-dotfiles.git`, at the time of writing on
  commit `419ef02`, containing extra files such as `hunspell.org`, `lisp/`,
  `insert/`). The working checkout `~/src/emacs-dotfiles` is a *separate,
  slightly diverged* clone (HEAD `e74998c`). This divergence is reconciled as
  part of cutover (see "Build, test, deploy").

## Decisions (settled with the user)

| Question | Decision |
|---|---|
| Authoring model | **Modular literate org**: many small `.org` files, one concern each, each tangling to a matching `.el`. Preserves prose+code, fixes the monolith. |
| Package manager | **Keep `straight.el`** + `use-package`, with a committed lockfile for reproducible multi-machine installs. |
| Completion/UI stack | **Vertico stack**: vertico, consult, marginalia, orderless, corfu, cape. Removes the ivy+icomplete conflict. |
| Feature scope | **Curate**: port active features cleanly, drop dead/duplicate code, drop explicitly-unwanted features. |
| Machine differences | **Runtime detection + gitignored `local.el`** (with committed `local.example.el` template). |
| Target environments | Native Ubuntu GUI, WSL2 on Windows, terminal `-nw`. **EXWM dropped.** |
| Languages kept | Core: R, Python, Emacs Lisp, LaTeX, Markdown/Quarto, shell. Plus: Clojure, Rust, Stan, Snakemake, Groovy. |
| Languages dropped | Julia, Lua, SPARQL. |
| LSP client | **eglot** (built-in). |
| Checker | **Keep `flycheck` + `flycheck-vale`** as the unified checker UI; bridge eglot diagnostics into flycheck via `flycheck-eglot`. |
| Knowledge base | **Drop `org-roam`** (currently disabled anyway). |

## Loading Architecture

```
~/.emacs.d/  (the repository)
├── early-init.el          # GC tuning, native-comp settings, UI suppression,
│                          #   disable package.el, straight prep — before the GUI
├── init.el                # bootstrap straight + use-package; load local.el;
│                          #   load each module from an explicit ordered manifest
├── local.el               # GITIGNORED — machine paths, fonts, secrets (per machine)
├── local.example.el       # committed template documenting every local variable
├── custom.el              # GITIGNORED — Customize scratchpad; loaded, never hand-edited
├── literate/              # SOURCE OF TRUTH the user edits
│   ├── core.org
│   ├── platform.org
│   ├── ui.org
│   ├── completion.org
│   ├── editing.org
│   ├── org.org
│   ├── org-gtd.org
│   ├── org-export.org
│   ├── writing.org
│   ├── vc.org
│   ├── shells.org
│   ├── prog.org
│   └── langs.org
├── modules/               # COMMITTED, pre-tangled .el — what init.el LOADS
│   ├── gtk-core.el
│   ├── gtk-platform.el
│   └── ...one per literate file
├── straight/versions/default.el   # COMMITTED lockfile (reproducible installs)
├── Makefile               # tangle / compile / test / lint
├── legacy/                # old gtk.org etc., kept for reference until parity confirmed
└── docs/superpowers/specs/        # this document and future specs
```

### Core reliability decisions

1. **`init.el` loads the committed, pre-tangled `.el` files, not the org files.**
   Startup never depends on org-mode or babel being healthy. This is the biggest
   reliability gain over today's `org-babel-load-file`-at-startup chain.

2. **Editing a `literate/NAME.org` re-tangles `modules/gtk-NAME.el` on save**
   (a buffer-local `after-save-hook` enabled in the literate files), and
   `make tangle` rebuilds everything. The committed `.el` is always the
   authoritative loaded artifact.

3. **Loading order is an explicit manifest** — a list in `init.el` — not an
   implicit chain of `org-babel-load-file` calls buried inside other files.

4. **Each module is loaded inside `condition-case`.** One broken module emits a
   warning and is skipped; it does not abort the rest of init.

5. **`local.el` is loaded early, inside `condition-case`.** A missing or broken
   local file warns rather than breaking startup. It is loaded before modules so
   machine values are available to them.

6. **External-binary features are guarded with `executable-find`** (hunspell,
   vale, pandoc, latexmk, the vterm compiler). A machine missing a binary still
   starts cleanly; the dependent feature is simply not enabled.

## Module Map

Each module is `literate/NAME.org` tangling to `modules/gtk-NAME.el`. Each file
`(provide 'gtk-NAME)` at its end.

| Module | Responsibility |
|---|---|
| `core` | sane defaults, UTF-8, backup/autosave directories, recentf, save-place, savehist, `server-start`, path helpers (`gtk/emacs-path`) |
| `platform` | OS/WSL/GUI/TTY detection predicates; browser, clipboard (WSL interop), PDF viewer, font selection with fallbacks |
| `ui` | modus themes + theme switcher, `doom-modeline` + `minions`, fonts/faces, `visual-fill-column`, which-key, `nerd-icons` |
| `completion` | vertico, consult, marginalia, orderless, corfu, cape |
| `editing` | prog-mode hook stack (from `code-functions.org`), smartparens/paredit base, multiple-cursors, expand-region, hippie-expand, global keybindings |
| `org` | org core, babel languages, visuals, org-modern, typo (smart quotes) |
| `org-gtd` | agenda, org-super-agenda, capture, org-journal, refile, TODO keywords, areas-of-focus, tags |
| `org-export` | latex/beamer/minted/memoir classes, odt, md, publishing, citations (`org-ref`/`oc-biblatex`), custom export filters and link types |
| `writing` | flyspell/hunspell, AUCTeX/LaTeX, reftex, markdown, pandoc, autoinsert |
| `vc` | magit, git-gutter, with-editor |
| `shells` | vterm, eshell |
| `prog` | eglot, flycheck (+ flycheck-eglot, flycheck-vale), project/projectile, rainbow-delimiters, yasnippet — shared programming setup |
| `langs` | per-language: elisp, R/ess (+ display-buffer rules + projectile R type), python (conda/pet), clojure/cider, rust/rustic, stan, snakemake, groovy, yaml, dockerfile, quarto/poly |

Thirteen focused files replace the single 2,259-line monolith.

## Conflict Resolutions and Curation

### Resolving doubled-up / fighting configuration

- **Modeline:** keep `doom-modeline` + `minions`; drop `smart-mode-line`.
- **Completion-at-point:** `corfu` + `cape`; drop `company`.
- **Minibuffer:** vertico/consult; drop `ivy`/`counsel`/`swiper` and `icomplete`.
- **Icons:** migrate `all-the-icons` → `nerd-icons`.
- **Org stars:** `org-modern`; drop `org-superstar`.
- **Checker:** `flycheck` is the single checker UI. `flycheck-vale` for prose;
  `flycheck-eglot` bridges eglot/LSP diagnostics into flycheck so there is one
  consistent diagnostics interface across languages.

### Dropped (cruft / superseded / explicitly unwanted)

- EXWM; Julia, Lua, SPARQL language modes.
- `dired+` → built-in `dired` + `dired-x` + `diredfl` (`dired+` is unmaintained).
- `popwin` → `display-buffer-alist` (already hand-rolled for R buffers).
- `gist`, `command-log-mode` + `posframe`, `bm`, `term`/`eterm-256color`.
- `pretty-lambdas` → `prettify-symbols-mode`.
- `zenburn-theme`, `doom-themes` (modus is the primary theme).
- `org-roam` (currently disabled).

### Kept (curated clean)

R/ess plus its `display-buffer-alist` rules and projectile R project types;
python conda/pet; projectile; yasnippet; magit + git-gutter; org GTD (agenda,
super-agenda, capture, journal, refile, TODO keywords, areas-of-focus);
org-ref / citations; LaTeX/beamer/minted/memoir export and custom export
filters/link types; markdown/pandoc/quarto; flyspell/hunspell; vterm/eshell;
multiple-cursors; expand-region; typo; autoinsert (letter template);
org-present; org-modern; the `fresh-load-theme` theme switcher (targeting modus
light/dark).

## Machine-Specific Handling

- `platform.org` defines runtime predicates: `gtk/wsl-p` (via `/proc/version`),
  `gtk/gui-p`, `gtk/macos-p`, `gtk/linux-p`, used to branch behavior (clipboard,
  browser, PDF viewer, font choice).
- `local.el` (gitignored) holds the *values*: `dropbox-root`, conda home, font
  family names, bibliography paths, publish targets. `local.example.el`
  documents each one. Init loads `local.el` in `condition-case`.
- The NUS FTP publish target and all `~/Dropbox`/`~/miniforge3` paths move out of
  committed code into `local.el`.
- WSL specifics handled in `platform`: clipboard integration with Windows,
  `browse-url` pointed at the Windows browser, PDF viewer appropriate to the
  environment.

## Build, Test, Deploy

- **Isolated testing.** Development and testing happen in `~/src/emacs-dotfiles`
  using `emacs --init-directory ~/src/emacs-dotfiles` (Emacs 29+). The live
  `~/.emacs.d` is never at risk during the rebuild.
- **Makefile targets:**
  - `make tangle` — tangle all `literate/*.org` → `modules/*.el`.
  - `make compile` — byte- and native-compile modules; warnings are taken
    seriously.
  - `make test` — batch-load each module (`emacs --batch`) to catch load errors.
  - `make lint` — checkdoc / package-lint over the modules.
- **Reproducibility.** Commit the `straight` lockfile
  (`straight/versions/default.el`). Document `straight-freeze-versions` /
  `straight-thaw-versions` for syncing package versions across machines.
- **Cutover.** Once parity is confirmed in the isolated directory, reconcile the
  `~/.emacs.d`-vs-`~/src/emacs-dotfiles` divergence and switch `~/.emacs.d` to
  the new layout. The old configuration is preserved on a git branch and under
  `legacy/` as a safety net until the new config has been used across all
  machines without regression.

## Incremental Build Order

A bootable, useful Emacs should exist early and grow:

1. `early-init.el` + `init.el` skeleton + module loader + `local.el` mechanism.
2. `core`
3. `platform`
4. `completion`
5. `ui`
6. `editing`
7. `org`
8. `org-gtd`, `org-export`
9. `writing`
10. `vc`, `shells`
11. `prog`, `langs`

Each module is verified loadable (via `make test`) before the next is added.

## Out of Scope

- Reorganizing org-content files (the actual `organizer.org`, journal, agenda
  data) — only the configuration that references them changes.
- Migrating away from `straight.el` or `projectile` (kept by decision).
- Any new feature not present in the current configuration; this is a
  modularization and cleanup, not a feature-expansion project.

## Success Criteria

- `emacs --init-directory ~/src/emacs-dotfiles` starts cleanly on native Ubuntu
  GUI, WSL2, and `-nw` with no errors and no missing-binary crashes.
- All curated-"kept" features work as they do today (or better), verified by
  smoke test.
- No committed file contains a machine-specific path, secret, or font hardcode;
  all such values live in `local.el`.
- `make tangle && make compile && make test` succeeds with no errors.
- The configuration is modular: every concern lives in a single small file that
  can be understood and tested on its own.
