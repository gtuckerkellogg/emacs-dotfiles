;;; gtk-platform-test.el --- tests for platform detection  -*- lexical-binding: t; -*-
(require 'ert)
(require 'gtk-platform)

(ert-deftest gtk-platform-wsl-marker-positive ()
  (should (gtk//string-has-wsl-marker-p
           "Linux version 5.15.0-microsoft-standard-WSL2"))
  (should (gtk//string-has-wsl-marker-p "... Microsoft ...")))

(ert-deftest gtk-platform-wsl-marker-negative ()
  (should-not (gtk//string-has-wsl-marker-p
               "Linux version 5.15.0-176-generic"))
  (should-not (gtk//string-has-wsl-marker-p "")))

(provide 'gtk-platform-test)
