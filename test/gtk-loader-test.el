;;; gtk-loader-test.el --- tests for the module loader  -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'gtk-loader)

(ert-deftest gtk-loader-returns-t-on-success ()
  "Loading an already-available feature returns non-nil."
  (should (gtk/load-module 'gtk-loader)))

(ert-deftest gtk-loader-returns-nil-on-missing ()
  "A missing feature is caught: returns nil, does not signal."
  (should-not (gtk/load-module 'gtk-no-such-module-xyzzy)))

(ert-deftest gtk-loader-manifest-is-symbol-list ()
  "The manifest is a non-empty list of symbols."
  (should (consp gtk/modules))
  (should (cl-every #'symbolp gtk/modules)))

(provide 'gtk-loader-test)
