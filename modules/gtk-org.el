;;; gtk-org.el --- org core, babel, org-modern, typo, faces  -*- lexical-binding: t; -*-
;;; Commentary:
;; Core org configuration: behavior, babel languages, org-modern, smart quotes,
;; and org-specific face tuning.  Agenda/GTD and export are separate modules.
;;; Code:

(defun gtk/org-confirm-babel-evaluate (lang _body)
  "Don't prompt before evaluating LANG blocks we trust."
  (not (member lang '("latex" "emacs-lisp"))))
(setq org-confirm-babel-evaluate #'gtk/org-confirm-babel-evaluate)

(use-package org
  :straight (:type built-in)
  :hook ((org-mode . turn-off-auto-fill)
         (org-mode . turn-on-visual-line-mode))
  :custom
  (org-startup-indented nil)
  (org-startup-folded 'nofold)
  (org-insert-mode-line-in-empty-file t)
  (org-outline-path-complete-in-steps nil)
  (org-latex-prefer-user-labels t)
  (org-hide-leading-stars t)
  (org-pretty-entities nil)
  (org-use-property-inheritance '("PRIORITY" "STYLE" "CATEGORY"))
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (R . t) (shell . t) (dot . t)
     (python . t) (latex . t)))
  :bind (("C-c l" . org-store-link)
         ("C-c a" . org-agenda)
         ("C-c c" . org-capture)))

(use-package org-modern
  :hook (org-mode . org-modern-mode)
  :custom
  (org-auto-align-tags nil)
  (org-tags-column 0)
  (org-catch-invisible-edits 'show-and-error)
  (org-special-ctrl-a/e t)
  (org-insert-heading-respect-content t)
  (org-hide-emphasis-markers t)
  (org-pretty-entities t))

(use-package typo
  :hook (org-mode . typo-mode)
  :init (setq-default typo-language "English")
  :config
  (add-hook 'typo-disable-electricity-functions #'org-in-src-block-p))

;; Heading sizes and fixed-pitch for code/structural elements.  Font *families*
;; are owned by gtk-ui / local.el; here we only adjust heights and pitch so this
;; stays font-agnostic and never errors on a missing face.
(when (display-graphic-p)
  (dolist (spec '((org-level-1 . 1.3)
                  (org-level-2 . 1.2)
                  (org-level-3 . 1.1)
                  (org-level-4 . 1.1)
                  (org-level-5 . 1.1)
                  (org-level-6 . 1.1)
                  (org-level-7 . 1.1)))
    (set-face-attribute (car spec) nil :weight 'regular :height (cdr spec)))
  (set-face-attribute 'org-level-1 nil :weight 'normal)
  (set-face-attribute 'org-level-2 nil :weight 'bold)
  (dolist (face '(org-block org-table org-formula org-code org-verbatim
                  org-special-keyword org-meta-line org-checkbox
                  org-block-begin-line org-block-end-line org-drawer))
    (when (facep face)
      (set-face-attribute face nil :inherit 'fixed-pitch))))

(provide 'gtk-org)
;;; gtk-org.el ends here
