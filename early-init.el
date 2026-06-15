;;; early-init.el --- pre-GUI startup tuning  -*- lexical-binding: t; -*-
;;; Commentary:
;; Runs before the GUI and before package.el. Keep it minimal and dep-free.
;;; Code:

;; Raise GC ceiling during startup; restored to a sane value after init.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;; We manage packages with straight.el; disable package.el at startup.
(setq package-enable-at-startup nil)

;; Quiet native-comp; let it run async without nagging.
(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t)

;; Suppress GUI chrome early to avoid a flash of toolbars.
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(scroll-bar-width . 0) default-frame-alist)
(setq inhibit-startup-message t
      frame-inhibit-implied-resize t)

(provide 'early-init)
;;; early-init.el ends here
