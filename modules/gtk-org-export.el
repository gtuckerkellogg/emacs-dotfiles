;;; gtk-org-export.el --- LaTeX/beamer/minted export, citations, links -*- lexical-binding: t; -*-
;;; Commentary:
;; Declarative export pipeline: org-contrib/ox-extra, LaTeX image defaults,
;; memoir class, minted code, beamer derived backend, caption filters,
;; citations (citar + native org-cite; oc-biblatex/oc-csl export), and
;; custom link types.
;; Loaded after gtk-org; does NOT redefine org core settings.
;;; Code:

(use-package org-contrib)
(use-package ox-extra
  :straight nil
  :after org-contrib
  :config (ox-extras-activate '(latex-header-blocks ignore-headlines)))
(with-eval-after-load 'org
  (require 'ox-md)
  (require 'ox-odt nil t))

(setq org-latex-image-default-option "keepaspectratio,height=0.9\\textheight"
      org-latex-image-default-width "0.8\\linewidth"
      org-latex-image-default-height "0.75\\textheight")

(setq org-latex-pdf-process
      '("latexmk -f -pdf -%latex -interaction=nonstopmode -shell-escape -output-directory=%o %f"))

(add-to-list 'org-latex-classes
             `("memoir-article"
               (,@ (concat "\\documentclass[11pt,article,oneside,a4paper,x11names]{memoir}\n"
                           "% -- DEFAULT PACKAGES \n[DEFAULT-PACKAGES]\n"
                           "% -- PACKAGES \n[PACKAGES]\n"
                           "% -- EXTRA \n[EXTRA]\n"
                           "\\counterwithout{section}{chapter}\n"
                           ))
               ("\\section{%s}" . "\\section{%s}")
               ("\\subsection{%s}" . "\\subsection{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection{%s}")
               ("\\paragraph{%s}" . "\\paragraph{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph{%s}")))

(setq org-latex-src-block-backend 'minted)

(setq org-latex-packages-alist '())
(add-to-list 'org-latex-packages-alist '("table" "xcolor"))
(add-to-list 'org-latex-minted-langs '(groovy "groovy"))
(add-to-list 'org-latex-minted-langs '(R "r"))
(add-to-list 'org-latex-minted-langs '(clojure "clojure"))

(setq org-latex-minted-options
      '(("linenos" "true")
        ("fontsize" "\\scriptsize")
        ("stepnumber" "1")))

;; Load stock ox-beamer first so our derived backend and org-beamer-bold
;; override (not race with) the stock definitions.
(require 'ox-beamer)
(org-export-define-derived-backend 'beamer 'latex
  :menu-entry
  '(?l 1
       ((?B "As LaTeX buffer (Beamer)" org-beamer-export-as-latex)
	(?b "As LaTeX file (Beamer)" org-beamer-export-to-latex)
	(?P "As PDF file (Beamer)" org-beamer-export-to-pdf)
	(?O "As PDF file and open (Beamer)"
	    (lambda (a s v b)
	      (if a (org-beamer-export-to-pdf t s v b)
		(org-open-file (org-beamer-export-to-pdf nil s v b)))))))
  :options-alist
  '((:headline-levels nil "H" org-beamer-frame-level)
    (:latex-class "LATEX_CLASS" nil "beamer" t)
    (:beamer-subtitle-format nil nil org-beamer-subtitle-format)
    (:beamer-column-view-format "COLUMNS" nil org-beamer-column-view-format)
    (:beamer-theme "BEAMER_THEME" nil org-beamer-theme)
    (:beamer-color-theme "BEAMER_COLOR_THEME" nil nil t)
    (:beamer-font-theme "BEAMER_FONT_THEME" nil nil t)
    (:beamer-inner-theme "BEAMER_INNER_THEME" nil nil t)
    (:beamer-outer-theme "BEAMER_OUTER_THEME" nil nil t)
    (:beamer-header "BEAMER_HEADER" nil nil newline)
    (:beamer-environments-extra nil nil org-beamer-environments-extra)
    (:beamer-frame-default-options nil nil org-beamer-frame-default-options)
    (:beamer-outline-frame-options nil nil org-beamer-outline-frame-options)
    (:beamer-outline-frame-title nil nil org-beamer-outline-frame-title))
  :translate-alist '((strike-through . org-beamer-bold)
		     (export-block . org-beamer-export-block)
		     (export-snippet . org-beamer-export-snippet)
		     (headline . org-beamer-headline)
		     (item . org-beamer-item)
		     (keyword . org-beamer-keyword)
		     (link . org-beamer-link)
		     (plain-list . org-beamer-plain-list)
		     (radio-target . org-beamer-radio-target)
		     (template . org-beamer-template)))

(defun org-beamer-bold (bold contents _info)
  "Transcode BLOCK object into Beamer code.
CONTENTS is the text being bold.  INFO is a plist used as
a communication channel."
  (format "\\textbf%s{%s}"
	  (or (org-beamer--element-has-overlay-p bold) "")
	  contents))

(mapcar (lambda (x) (add-to-list 'org-export-backends x :append))
        '(beamer odt))

(defun gtk/unnumbered-beamer-caption (contents backend info)
  "Make Beamer captions unnumbered in CONTENTS when BACKEND is beamer."
  (when (eq backend 'beamer)
    (replace-regexp-in-string "\\\\caption\{" "\\\\caption*{" contents)))

(setq org-beamer-environments-extra
      '(("ponly" "P" "\\begin{ponly}%a{%h}" "\\end{ponly}")
	("fill" "D" "{\\molochset{block=fill}\\noop \\\\ \\begin{block}%a{%h}" "\\end{block}}")))

(defun my/unnumbered-captions-p ()
  "Non-nil when the buffer opts into unnumbered captions.
Checks for a #+PROPERTY: unnumbered-captions <truthy-value> keyword."
  (let* ((props (org-collect-keywords '("PROPERTY")))
         (entries (cdr (assoc "PROPERTY" props)))
         val)
    (dolist (entry entries)
      (when (string-match "\\`unnumbered-captions\\s-+\\([^ \t\r\n]+\\)" entry)
        (setq val (match-string 1 entry))))
    (and val (not (member (downcase val) '("nil" "no" "false" "0"))))))

(defun gtk/unnumbered-latex-captions (contents backend _info)
  "Unnumber LaTeX captions in CONTENTS for opted-in buffers.
Applies only for the latex BACKEND when `my/unnumbered-captions-p' is non-nil."
  (when (and (my/unnumbered-captions-p) (eq backend 'latex))
    (replace-regexp-in-string "\\\\caption{" "\\\\caption*{" contents)))

(with-eval-after-load 'org
  (require 'org-checklist nil t)
  (add-to-list 'org-export-filter-final-output-functions #'gtk/unnumbered-beamer-caption)
  (add-to-list 'org-export-filter-final-output-functions #'gtk/unnumbered-latex-captions)
  (add-to-list 'org-export-filter-parse-tree-functions #'org-export-ignore-headlines))

;; Citations: native org-cite (`[cite:@key]') with citar as the
;; completing-read UI for insert / follow / activate.  Per-document
;; bibliographies are read from each file's `#+bibliography:' keyword,
;; so no global bibliography is configured here.
(use-package citar
  :custom
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  :bind (:map org-mode-map
              ("C-c ]"       . org-cite-insert)
              ("C-c C-x C-2" . org-cite-insert)))

;; citeproc-el backs CSL export for the non-LaTeX backends.
(use-package citeproc)

(with-eval-after-load 'org
  (require 'oc-biblatex)        ; LaTeX/Beamer -> biblatex + biber
  (require 'oc-csl)             ; HTML/ODT/Markdown -> CSL via citeproc
  ;; Choose the export processor per backend so citations render without
  ;; a per-document #+cite_export keyword.  Beamer derives from latex but
  ;; is listed explicitly because backend resolution does not reliably
  ;; walk to the parent backend.
  (setq org-cite-export-processors
        '((latex  biblatex)
          (beamer biblatex)
          (html   csl)
          (odt    csl)
          (md     csl)
          (t      csl))))

(with-eval-after-load 'org
  (org-link-set-parameters
   "cite"
   :export (lambda (path desc format)
             (cond ((eq format 'html)
                    (if (and desc (string-match "(\\(.*\\))" desc))
                        (format "(<cite>%s</cite>)" (match-string 1 desc))
                      (format "<cite>%s</cite>" (or desc path))))
                   ((eq format 'latex) (format "\\cite{%s}" path)))))
  (org-link-set-parameters
   "TERM"
   :export (lambda (path desc format)
             (let ((d (or desc path)))
               (cond ((eq format 'html) d)
                     ((eq format 'latex)
                      (format "%s\\nomenclature{%s}{%s}" d path d))))))
  (org-link-set-parameters
   "Figure"
   :export (lambda (path _desc format)
             (cond ((eq format 'html) path)
                   ((eq format 'latex) (format "Figure~\\ref{fig:%s}" path)))))
  (org-link-set-parameters
   "Table"
   :export (lambda (path _desc format)
             (cond ((eq format 'html) path)
                   ((eq format 'latex) (format "Table~\\ref{tbl:%s}" path))))))

;; ox-typst: export Org to Typst markup (and PDF via the `typst' CLI).
;; Loading it registers the `typst' backend in the export dispatcher
;; (C-c C-e t ...).  File/PDF export needs the `typst' binary on PATH;
;; that is distinct from `tinymist', which is only the editor LSP.
(use-package ox-typst
  :after org)

(provide 'gtk-org-export)
;;; gtk-org-export.el ends here
