# Org → Typst export — design

Date: 2026-06-23

## Goal

Enable exporting Org buffers to Typst markup (and to PDF via the Typst CLI)
through the standard `org-export-dispatch` menu, accepting all of the
`ox-typst` package's defaults.

## Package

[`jmpunkt/ox-typst`](https://github.com/jmpunkt/ox-typst), available on MELPA.
It is pulled through the existing straight.el / use-package pipeline
(`straight-use-package-by-default` is enabled in `init.el`, so no custom recipe
is required).

## Placement

The configuration lives in `modules/gtk-org-export.el`, the dedicated Org
export module, alongside the existing backend registrations (beamer, odt).
ox-typst is conceptually "another export backend," so it belongs with the
export pipeline rather than with editor/language tooling.

Typst *editing* support (`typst-ts-mode`, tinymist/eglot, compile/preview/watch
keys) remains in `gtk-langs.el` and is unchanged by this work.

## Change

A single declarative form:

```elisp
(use-package ox-typst
  :after org)
```

Loading the package executes its `org-export-define-backend`, which
self-registers the backend on the export dispatcher under the `y` key,
providing:

- `?F` — As Typst buffer (`org-typst-export-as-typst`)
- `?f` — As Typst file, `.typ` (`org-typst-export-to-typst`)
- `?p` — As PDF file (`org-typst-export-to-pdf`)
- `?o` — As PDF file and open

## Accepted defaults

No overrides are configured. For reference, the relevant ox-typst defaults are:

- `org-typst-process` = `"typst c \"%s\""` (PDF compile command; `typst` is on PATH)
- `org-typst-from-latex-fragment` = `#'org-typst-from-latex-with-naive`
- `org-typst-from-latex-environment` = `#'org-typst-from-latex-with-naive`

The naive math converters require no external dependency (no Pandoc).

## Out of scope

Deliberately excluded, to be revisited only if a concrete need arises:

- Overriding the LaTeX-math conversion variables (Pandoc path).
- Customizing or making `org-typst-process` overridable via `local.el`.
- Custom Typst export branches for the existing `cite` / `TERM` / `Figure` /
  `Table` `org-link-set-parameters` definitions.
- Custom Typst template / preamble / class (no analog to the
  `memoir-article` LaTeX class).

Citations, if ever needed, use Typst-native `#+BIBLIOGRAPHY:` and
`#+CITE_EXPORT: typst <style>`.

## Verification

1. Byte-compiles cleanly (no new warnings from `gtk-org-export.el`).
2. After loading, `C-c C-e` shows the `y` "Export to Typst" entry.
3. `y f` on an Org buffer produces a `.typ` file.
4. `y p` produces a PDF (requires `typst` on PATH).
