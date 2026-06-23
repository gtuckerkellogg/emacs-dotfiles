;;; gtk-prog.el --- shared programming setup  -*- lexical-binding: t; -*-
;;; Commentary:
;; LSP (eglot), diagnostics (flycheck + eglot/vale bridges), snippets, projects.
;;; Code:

(use-package eglot
  :straight (:type built-in)
  :commands (eglot eglot-ensure))

;; Prefer *-ts-mode for these languages when the grammar is built, falling back
;; to the classic mode otherwise.  Deliberately selective: R (ESS), LaTeX
;; (AUCTeX), Clojure (CIDER), Rust (rustic), and Markdown stay on their
;; specialized modes.  Semantics come from eglot regardless.
(use-package treesit-auto
  :if (treesit-available-p)
  :custom
  (treesit-auto-install 'prompt)
  :config
  (setq treesit-auto-langs '(python yaml dockerfile json toml bash typst))
  (treesit-auto-add-to-auto-mode-alist treesit-auto-langs)
  (global-treesit-auto-mode))

(use-package flycheck
  :init
  (defun gtk/disable-flycheck-in-org-src ()
    "Disable the elisp-checkdoc checker inside org src edit buffers."
    (setq-local flycheck-disabled-checkers '(emacs-lisp-checkdoc)))
  (add-hook 'org-src-mode-hook #'gtk/disable-flycheck-in-org-src)
  :config
  (global-flycheck-mode)
  (customize-set-variable 'flycheck-keymap-prefix (kbd "C-c f")))

;; Bridge eglot/LSP diagnostics into flycheck for one consistent UI.
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

(provide 'gtk-prog)
;;; gtk-prog.el ends here
