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
  (concat (replace-regexp-in-string "/" "-" (symbol-name system-type))
          "-emacs-" emacs-version))

;; --- straight.el bootstrap -------------------------------------------------
(setq straight-use-package-by-default t
      straight-recipes-gnu-elpa-use-mirror t
      straight-repository-branch "develop" ; track straight.el's develop branch (long-standing choice)
      straight-build-dir (concat "build-" gtk/system-string))

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

;; exec-path-from-shell early so GUI/daemon sessions see the user's PATH.
;; In a -nw terminal Emacs PATH is inherited from the launching shell, so this
;; is intentionally skipped there.
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
