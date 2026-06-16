;;; gtk-completion.el --- minibuffer and in-buffer completion  -*- lexical-binding: t; -*-
;;; Commentary:
;; Vertico stack: vertico + orderless + marginalia + consult (minibuffer) and
;; corfu + cape (in-buffer).  Replaces the legacy ivy/counsel/swiper/icomplete.
;; savehist is enabled in gtk-core, so it is not repeated here.
;;; Code:

(use-package vertico
  :init (vertico-mode)
  :custom (vertico-cycle t))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-s r" . consult-ripgrep)))

(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-cycle t))

(use-package cape
  :init
  ;; `add-to-list' prepends, so the function added LAST ends up first.  Intended
  ;; final order: cape-file (specific, path contexts) before cape-dabbrev
  ;; (general word-completion fallback).
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

(provide 'gtk-completion)
;;; gtk-completion.el ends here
