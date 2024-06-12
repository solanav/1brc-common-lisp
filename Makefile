LISP ?= sbcl

build:
	rm -rf build/

	$(LISP) --load 1brc.asd \
		--eval '(ql:quickload :1brc)' \
		--eval '(push :deploy-console *features*)' \
		--eval '(asdf:make :1brc)' \
		--eval '(quit)'

run: build
	bin/1brc > results.txt
