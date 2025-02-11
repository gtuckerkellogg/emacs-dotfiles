(setq native-comp-async-report-warnings-errors nil)
;; don't use package, use straight.el

(defconst gtk/system-type (replace-regexp-in-string "/" "-" (format "%s" system-type)))
(defconst gtk/system-string (concat gtk/system-type "-emacs-" emacs-version))

(setq straight-use-package-by-default t  
      straight-recipes-gnu-elpa-use-mirror t
      straight-build-dir (expand-file-name
			  (concat "straight/build" "-" gtk/system-string)
			  user-emacs-directory)
      straight-repository-branch "develop")

(setq package-enable-at-startup nil)

;; (unless (package-installed-p 'vc-use-package)
;;   (package-vc-install "https://github.com/slotThe/vc-use-package"))
;; (require 'vc-use-package)

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'org)
;; Configure use-package to use straight.el by default
(use-package straight
  :custom (straight-use-package-by-default t))

(use-package exec-path-from-shell)

(org-reload)


(org-babel-load-file (expand-file-name (concat (getenv "USER") ".org") user-emacs-directory))

(put 'narrow-to-region 'disabled nil)
(put 'set-goal-column 'disabled nil)

(put 'dired-find-alternate-file 'disabled nil)

(provide 'init);; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-vc-selected-packages
   '((vc-use-package :vc-backend Git :url "https://github.com/slotThe/vc-use-package"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
