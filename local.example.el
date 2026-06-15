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
