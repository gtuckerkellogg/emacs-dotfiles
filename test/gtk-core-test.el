;;; gtk-core-test.el --- tests for core helpers  -*- lexical-binding: t; -*-
(require 'ert)
(require 'gtk-core)

(ert-deftest gtk-core-emacs-path-expands-under-ued ()
  (let ((user-emacs-directory "/tmp/ued/"))
    (should (equal (gtk/emacs-path "foo/bar")
                   "/tmp/ued/foo/bar"))))

(ert-deftest gtk-core-emacs-path-handles-trailing ()
  (let ((user-emacs-directory "/tmp/ued/"))
    (should (string-prefix-p "/tmp/ued/" (gtk/emacs-path "x")))))

(provide 'gtk-core-test)
