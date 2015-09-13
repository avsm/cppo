VERSION = 1.2.2

ifeq "$(shell ocamlc -config |grep os_type)" "os_type: Win32"
EXE=.exe
else
EXE=
endif

ifndef OCAMLYACC
  OCAMLYACC = ocamlyacc
  #OCAMLYACC = menhir
endif
export OCAMLYACC

ifndef PREFIX
  PREFIX = /usr/local
endif
export PREFIX

ifndef BINDIR
  BINDIR = $(PREFIX)/bin
endif
export BINDIR



BEST = $(shell if ocamlopt 2>/dev/null; then echo .native; else echo .byte; fi)
NATDYNLINK ?= $(shell if [ -f `ocamlc -where`/dynlink.cmxa ]; then \
                        echo YES; \
                      else \
                        echo NO; \
                      fi)

OCAMLBUILD_IMPL := ocamlbuild_cppo.cma

ifeq "${BEST}" ".native"
OCAMLBUILD_IMPL += ocamlbuild_cppo.cmxa ocamlbuild_cppo.a
ifeq "${NATDYNLINK}" "YES"
OCAMLBUILD_IMPL += ocamlbuild_cppo.cmxs
endif
endif

OCAMLBUILD_INSTALL = ocamlbuild_plugin/_build/ocamlbuild_cppo.cmi \
                     $(addprefix ocamlbuild_plugin/_build/,$(OCAMLBUILD_IMPL))


.PHONY: default all opt toplib install clean test

default: opt ocamlbuild

ML = cppo_version.ml cppo_types.ml \
     cppo_parser.mli cppo_parser.ml \
     cppo_lexer.ml \
     cppo_command.ml \
     cppo_eval.ml cppo_main.ml

OCAMLBUILD_ML = ocamlbuild_cppo.ml

all: $(ML)
	ocamlc -o cppo$(EXE) -dtypes unix.cma str.cma $(ML)

opt: $(ML)
	ocamlopt -o cppo$(EXE) -dtypes unix.cmxa str.cmxa $(ML)

# For debugging; not installed.
toplib: $(ML)
	ocamlc -a -o cppo.cma -dtypes unix.cma str.cma $(ML)

ocamlbuild:
	cd ocamlbuild_plugin && ocamlbuild -use-ocamlfind $(OCAMLBUILD_IMPL)

install: install-bin install-lib

install-bin:
	install -m 0755 cppo $(BINDIR) || \
		install -m 0755 cppo.exe $(BINDIR)

install-lib:
	ocamlfind install -patch-version ${VERSION} "cppo_ocamlbuild" \
		META $(OCAMLBUILD_INSTALL)

cppo_version.ml: Makefile
	echo 'let cppo_version = "$(VERSION)"' > cppo_version.ml


cppo_lexer.ml: cppo_lexer.mll cppo_types.ml cppo_parser.ml
	ocamllex cppo_lexer.mll


ifeq ($(DEV),true)
cppo_parser.mli cppo_parser.ml: cppo_parser.mly cppo_types.ml
	menhir -v cppo_parser.mly
else
cppo_parser.mli cppo_parser.ml: cppo_parser.mly cppo_types.ml
	$(OCAMLYACC) cppo_parser.mly
endif

test:
	$(MAKE) -C test

clean:
	rm -f *.cm[iox] *.o *.annot *.conflicts *.automaton \
		cppo \
		cppo_parser.mli cppo_parser.ml cppo_lexer.ml cppo_version.ml
	$(MAKE) -C examples clean
	$(MAKE) -C test clean
	cd ocamlbuild_plugin; ocamlbuild -clean
