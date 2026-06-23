;;; gtk-writing.el --- spelling, LaTeX, markdown, autoinsert -*- lexical-binding: t; -*-
;;; Commentary:
;; Spelling via hunspell/flyspell, AUCTeX/RefTeX for LaTeX editing,
;; markdown-mode with pandoc backend, pandoc-mode, autoinsert for
;; letter templates, and text-mode auto-fill.
;;; Code:

(use-package flyspell
  :straight (:type built-in)
  :if (executable-find "hunspell")
  :init (bind-key "S-<f8>" 'flyspell-mode)
  :config
  (defun gtk/flyspell-check-next-error ()
    "Go to the next flyspell error and correct it."
    (interactive) (flyspell-goto-next-error) (ispell-word))
  (bind-keys :map flyspell-mode-map
             ("<f8>" . gtk/flyspell-check-next-error)
             ("M-S-<f8>" . flyspell-prog-mode)
             ("C-<f8>" . flyspell-buffer))
  (setq ispell-program-name "hunspell"
        ispell-dictionary "en_GB"
        ispell-personal-dictionary (expand-file-name "~/.hunspell_personal"))
  (ispell-set-spellchecker-params))

;; AUCTeX installs from the `auctex' recipe but provides the feature `tex',
;; so we track `tex' and tell straight to use the auctex recipe.
(use-package tex
  :straight auctex
  :defer t
  :init
  (setq-default TeX-master t)
  (setq TeX-PDF-mode t
        reftex-plug-into-AUCTeX t)
  :hook ((LaTeX-mode . LaTeX-math-mode)
         (LaTeX-mode . turn-on-reftex))
  :config
  (setq TeX-view-program-selection
        '((output-dvi "DVI Viewer") (output-pdf "PDF Viewer") (output-html "Browser"))
        TeX-view-program-list
        '(("DVI Viewer" "xdg-open %o")
          ("PDF Viewer" "xdg-open %o")
          ("Browser" "xdg-open %o"))))

(defun getpackage ()
  "Open the .sty file for the LaTeX package name at point (via kpsewhich)."
  (interactive)
  (search-backward "\\")
  (re-search-forward "usepackage[^{}]*{" nil t)
  (while (looking-at "\\s-*,*\\([a-zA-Z0-9]+\\)")
    (re-search-forward "\\s-*,*\\([a-zA-Z0-9]+\\)" nil 1)
    (save-excursion
      (find-file-other-window
       (replace-regexp-in-string
        "[\n\r ]*" ""
        (shell-command-to-string (concat "kpsewhich " (match-string 1) ".sty")))))))

(defun org-mode-reftex-setup ()
  "Enable RefTeX-style citation insertion in the current org buffer."
  (load-library "reftex")
  (and (buffer-file-name)
       (file-exists-p (buffer-file-name))
       (reftex-parse-all))
  (define-key org-mode-map (kbd "C-c )") #'reftex-citation))
(add-hook 'org-mode-hook #'org-mode-reftex-setup)

(defvar markdown-cite-format)
(setq markdown-cite-format
      '(
        (?\C-m . "[@%l]")
        (?p . "[@%l]")
        (?t . "@%l")
        ))

(use-package markdown-mode
  :straight t
  :commands (markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :init
  (setq markdown-command "pandoc"))

(add-hook 'markdown-mode-hook 'flyspell-mode)
(add-hook 'markdown-mode-hook 'turn-on-visual-line-mode)
(add-hook 'markdown-mode-hook 'turn-off-auto-fill)

(add-hook 'markdown-mode-hook 'orgtbl-mode)

(defun my-buffer-face-mode-variable ()
  "Set font to a variable-width (proportional) font in current buffer."
  (interactive)
  (setq buffer-face-mode-face
        (list :family (if (boundp 'gtk/variable-font) gtk/variable-font "Sans")))
  (buffer-face-mode))

(defun my-buffer-face-mode-fixed ()
  "Set font to a fixed-width (monospace) font in current buffer."
  (interactive)
  (setq buffer-face-mode-face
        (list :family (if (boundp 'gtk/fixed-font) gtk/fixed-font "Monospace")))
  (buffer-face-mode))

;; use a variable font for markdown mode
(add-hook 'markdown-mode-hook 'my-buffer-face-mode-variable)

;; Shift + scroll to change font size
(global-set-key [C-mouse-4] 'text-scale-increase)
(global-set-key [C-mouse-5] 'text-scale-decrease)
(global-set-key [mouse-8] #'my-buffer-face-mode-fixed)
(global-set-key [mouse-9] #'my-buffer-face-mode-variable)

(defun markdown-citation-at-point-p ()
  "Return non-nil if point is inside a pandoc-style citation key."
  (save-excursion
    (thing-at-point-looking-at "@[-A-Za-z0-9]+")))

(defun markdown-flyspell-check-word-p ()
  "Return t if `flyspell' should check word just before point.
Used for `flyspell-generic-check-word-predicate'."
  (save-excursion
    (goto-char (1- (point)))
    (not (or (markdown-code-block-at-point-p)
             (markdown-inline-code-at-point-p)
             (markdown-citation-at-point-p)
             (markdown-in-comment-p)
             (let ((faces (get-text-property (point) 'face)))
               (if (listp faces)
                   (or (memq 'markdown-reference-face faces)
                       (memq 'markdown-markup-face faces)
                       (memq 'markdown-url-face faces))
                 (memq faces '(markdown-reference-face
                               markdown-markup-face
                               markdown-url-face))))))))

(add-hook 'markdown-mode-hook
          (lambda ()
            (setq flyspell-generic-check-word-predicate
                  'markdown-flyspell-check-word-p)))

(use-package pandoc-mode
  :straight t
  :hook (latex-mode . pandoc-mode))

(add-hook 'text-mode-hook 'turn-on-auto-fill)

(use-package autoinsert
  :straight (:type built-in)
  :config
  (setq auto-insert-directory (gtk/emacs-path "insert/"))
  (add-to-list 'auto-insert-alist
               '(("letter\\.tex" . "a letter") . "letter-template.tex"))
  (auto-insert-mode 1))

(provide 'gtk-writing)
;;; gtk-writing.el ends here
