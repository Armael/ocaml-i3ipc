# OASIS_START
# DO NOT EDIT (digest: b2ac72b97ac10c57bd1c0d74a664b293)

SETUP = ./setup.exe

build: setup.data $(SETUP)
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data $(SETUP) build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data $(SETUP) build
	$(SETUP) -test $(TESTFLAGS)

all: $(SETUP)
	$(SETUP) -all $(ALLFLAGS)

install: setup.data $(SETUP)
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data $(SETUP)
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data $(SETUP)
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean: $(SETUP)
	$(SETUP) -clean $(CLEANFLAGS)

distclean: $(SETUP)
	$(SETUP) -distclean $(DISTCLEANFLAGS)
	$(RM) $(SETUP)

setup.data: $(SETUP)
	$(SETUP) -configure $(CONFIGUREFLAGS)

configure: $(SETUP)
	$(SETUP) -configure $(CONFIGUREFLAGS)

setup.exe: setup.ml
	ocamlfind ocamlopt -o $@ setup.ml || ocamlfind ocamlc -o $@ setup.ml || true
	$(RM) setup.cmi setup.cmo setup.cmx setup.o setup.cmt

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

docs: doc
	cp doc/style.css i3ipc.docdir

gh-pages: docs
	git checkout gh-pages
	rm -rf dev/*
	cp -r i3ipc.docdir/* dev/
	git add dev/*
	git commit -m "update docs"
	git push
	git checkout master
