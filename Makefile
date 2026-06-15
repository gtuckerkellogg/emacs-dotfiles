EMACS ?= emacs
ROOT  := $(CURDIR)

.PHONY: tangle test-units test-load test compile lint clean

## Tangle every literate/*.org to its module (targets declared in each file).
tangle:
	$(EMACS) -Q --batch --eval "(require 'org)" \
	  --eval "(setq org-confirm-babel-evaluate nil)" \
	  --eval "(dolist (f (directory-files (expand-file-name \"literate\" \"$(ROOT)\") t \"\\\\.org\\\\'\")) (org-babel-tangle-file f))"

## Fast ERT unit tests for pure helpers (no package install, no network).
test-units:
	$(EMACS) -q --batch -L $(ROOT)/lisp -L $(ROOT)/modules \
	  -l $(ROOT)/lisp/gtk-loader.el \
	  -l $(ROOT)/modules/gtk-core.el \
	  -l $(ROOT)/modules/gtk-platform.el \
	  -l $(ROOT)/test/gtk-loader-test.el \
	  -l $(ROOT)/test/gtk-core-test.el \
	  -l $(ROOT)/test/gtk-platform-test.el \
	  -f ert-run-tests-batch-and-exit

## Full startup in batch against this config dir; must reach the sentinel.
test-load:
	$(EMACS) -q --init-directory=$(ROOT) --batch \
	  -l $(ROOT)/early-init.el -l $(ROOT)/init.el \
	  --eval "(message \"INIT-OK\")"

test: test-units test-load

## Byte-compile modules using the real, fully-initialized environment.
compile:
	$(EMACS) -q --init-directory=$(ROOT) --batch \
	  -l $(ROOT)/early-init.el -l $(ROOT)/init.el \
	  --eval "(byte-recompile-directory (expand-file-name \"modules\" user-emacs-directory) 0 t)"

clean:
	rm -f $(ROOT)/modules/*.elc $(ROOT)/lisp/*.elc
