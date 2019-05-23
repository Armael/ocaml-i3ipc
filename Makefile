all:
	dune build @install

clean:
	dune clean

docs:
	dune build @doc

gh-pages: docs
	git checkout gh-pages
	git rm -rf dev/*
	mkdir dev
	cp -r _build/default/_doc/_html/* dev/
	git add dev/*
	git commit -m "update docs"
	git push
	git checkout master

.PHONY: all clean docs gh-pages
