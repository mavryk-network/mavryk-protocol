KSYS:=$(shell find . -name \*.ksy -print)
HTMLS:=$(patsubst %.ksy,doc/%.html,$(KSYS))
RSS:=$(patsubst %.ksy,rust/src/%.rs,$(KSYS))

all: $(HTMLS) $(RSS)

doc/:
	mkdir -p doc/

doc/%.html: %.ksy doc/
	kaitai-struct-compiler -t html $< --outdir=doc/

rust/src/%.rs: %.ksy
	kaitai-struct-compiler -t rust $< --outdir=rust/src/
