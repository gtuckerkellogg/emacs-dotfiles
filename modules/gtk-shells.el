;;; gtk-shells.el --- vterm and eshell  -*- lexical-binding: t; -*-
;;; Commentary:
;; Terminal/shell setup: vterm (guarded on a compiler) and eshell.
;;; Code:

(use-package vterm
  :if (executable-find "cmake")
  :commands vterm
  :config
  (setq vterm-max-scrollback 10000
        term-prompt-regexp "^[^#$%>\n]*[#$%>] *"))

(use-package eshell-git-prompt)

(defun gtk/configure-eshell ()
  "Sensible eshell history and scrolling defaults."
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

(provide 'gtk-shells)
;;; gtk-shells.el ends here
