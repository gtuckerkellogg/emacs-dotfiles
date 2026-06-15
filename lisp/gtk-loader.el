;;; gtk-loader.el --- ordered, fault-tolerant module loader  -*- lexical-binding: t; -*-
;;; Commentary:
;; Standalone (no package deps) so it is unit-testable in `-q --batch'.
;;; Code:
(require 'cl-lib)

(defvar gtk/modules
  '(gtk-core
    gtk-platform
    gtk-completion
    gtk-ui
    gtk-editing
    gtk-org
    gtk-org-gtd
    gtk-org-export
    gtk-writing
    gtk-vc
    gtk-shells
    gtk-prog
    gtk-langs)
  "Ordered list of configuration modules to load.")

(defun gtk/load-module (feature)
  "Require FEATURE, warning instead of erroring on failure.
Return non-nil on success, nil on failure."
  (condition-case err
      (progn (require feature) t)
    (error
     (display-warning 'gtk
                      (format "Failed to load %s: %s"
                              feature (error-message-string err))
                      :error)
     nil)))

(defun gtk/load-all-modules ()
  "Load every module in `gtk/modules', tolerating individual failures."
  (dolist (m gtk/modules) (gtk/load-module m)))

(provide 'gtk-loader)
;;; gtk-loader.el ends here
