
;; don't use package, use straight.el 
(setq package-enable-at-startup nil)
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

(straight-use-package 'use-package)
;; Configure use-package to use straight.el by default
(use-package straight
  :custom (straight-use-package-by-default t))

(use-package exec-path-from-shell)

(when (memq system-type '(gnu/linux darwin gnu))
  (exec-path-from-shell-initialize))

(use-package org)


(org-babel-load-file (expand-file-name (concat (getenv "USER") ".org") user-emacs-directory))

(put 'narrow-to-region 'disabled nil)
(put 'set-goal-column 'disabled nil)

(put 'dired-find-alternate-file 'disabled nil)

(provide 'init);; init.el ends here
