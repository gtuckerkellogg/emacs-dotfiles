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

;; AUCTeX PDF viewer command (%o expands to the output file).  Default xdg-open.
;; For SyncTeX forward/inverse search, use a dedicated viewer, e.g. "zathura %o"
;; (see AUCTeX's TeX-view-program-list for the full synctex form).
(setq gtk/latex-pdf-viewer "xdg-open %o")

(provide 'local)
;;; local.example.el ends here
