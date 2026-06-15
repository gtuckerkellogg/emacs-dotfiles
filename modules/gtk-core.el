;;; gtk-core.el --- core defaults and helpers  -*- lexical-binding: t; -*-
;;; Commentary:
;; Built-in settings and pure helpers. No external packages, no use-package,
;; so this file loads standalone (and is unit-testable in -q --batch).
;;; Code:

(defun gtk/emacs-path (path)
  "Expand PATH relative to `user-emacs-directory'."
  (expand-file-name path user-emacs-directory))

(setq user-full-name "Greg Tucker-Kellogg"
      user-mail-address "dbsgtk@gmail.com")

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(setq sentence-end-double-space nil
      visible-bell t
      inhibit-startup-message t
      require-final-newline t)
(setq-default fill-column 110
              indent-tabs-mode nil)
(menu-bar-mode 1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)
(setq scroll-conservatively 10000 auto-window-vscroll nil)
(setq diff-switches "-u")

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

(unless noninteractive
  (require 'server)
  (unless (server-running-p) (server-start)))

(put 'narrow-to-region 'disabled nil)
(put 'set-goal-column 'disabled nil)
(put 'dired-find-alternate-file 'disabled nil)

(provide 'gtk-core)
;;; gtk-core.el ends here
