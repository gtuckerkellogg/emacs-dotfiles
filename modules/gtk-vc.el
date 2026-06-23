;;; gtk-vc.el --- magit and git-gutter  -*- lexical-binding: t; -*-
;;; Commentary:
;; Version-control UI: magit (with with-editor) and git-gutter.
;;; Code:

(use-package with-editor)
(use-package magit
  :bind (("C-c m" . magit-status)
         ("C-c g" . magit-file-dispatch)))

(use-package git-gutter
  :config (global-git-gutter-mode 1))

(provide 'gtk-vc)
;;; gtk-vc.el ends here
