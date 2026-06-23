# CLAUDE.md

Personal, literate Emacs configuration (Emacs 30+). straight.el + use-package; Vertico completion stack.

## Critical: this is a literate config — never edit `modules/*.el` directly

The committed `modules/gtk-*.el` files are **tangled artifacts**. The source of
truth is `literate/<name>.org`. Editing a `.el` file directly will be silently
**overwritten** the next time the corresponding org file is tangled.

- Source: `literate/<name>.org`  →  tangles to  →  `modules/gtk-<name>.el`
- The tangle target is set per-file via:
  `#+property: header-args:emacs-lisp :tangle ../modules/gtk-<name>.el :results silent`
- Each org file has a Local Variables block that runs `org-babel-tangle` on save.

**Always make changes in the `.org` file, then re-tangle.** After editing an org
file, regenerate the `.el`:

```sh
make tangle            # tangle all literate/*.org
```

Or tangle a single file in batch (no Emacs session needed):

```sh
emacs -Q --batch --eval "(require 'org)" \
  --eval "(setq org-confirm-babel-evaluate nil)" \
  --eval "(org-babel-tangle-file \"literate/langs.org\")"
```

Verify after tangling that the `.el` actually changed (`git diff modules/`).

## Layout

| Path | Purpose |
|------|---------|
| `early-init.el` | Pre-GUI tuning (GC, package.el disabled) |
| `init.el` | Bootstrap straight.el, load `local.el`, invoke loader |
| `lisp/gtk-loader.el` | Ordered, fault-tolerant module load list |
| `literate/<name>.org` | **Literate source — edit here** |
| `modules/gtk-<name>.el` | Tangled output — do not edit by hand |
| `local.el` | Machine-specific vars, gitignored (`local.example.el` is the template) |
| `legacy/` | Previous monolithic config, reference only |
| `tree-sitter/` | Compiled grammars — **gitignored**, must be built per machine |

Module load order and the full module list live in `lisp/gtk-loader.el`. A module
that fails to load warns rather than aborting the session.

## Make targets

| Target | What it does |
|--------|--------------|
| `make tangle` | Tangle all `literate/*.org` to modules |
| `make test` | `test-units` + `test-load` |
| `make test-units` | Fast ERT tests for pure helpers (no packages/network) |
| `make test-load` | Full batch startup; verifies session reaches sentinel |
| `make compile` | Byte-compile modules against a live init |
| `make lint` | checkdoc over `modules/*.el` |

## Gotchas

- **Emacs is the Ubuntu snap.** Its `treesit.el` is patched to compile grammars
  with a snap-only `gcc` resolved via the `EMACS_SNAP_DIR` env var. That var is
  not reliably set, so `treesit-install-language-grammar` can fail with a cryptic
  `wrong-type-argument stringp nil`. Build tree-sitter grammars directly with
  `cc -shared -fPIC -O2 -I. parser.c [scanner.c] -o libtree-sitter-<lang>.so`
  into `tree-sitter/` instead.
- `tree-sitter/` is gitignored, so grammars don't survive a fresh checkout — any
  grammar-dependent mode needs a build step that self-heals when the `.so` is
  missing.
- The `.org` files are never evaluated at runtime; Emacs only loads the tangled
  `.el`. So a change isn't live until it is tangled (and the module reloaded /
  Emacs restarted).
