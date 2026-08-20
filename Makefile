# SPDX-License-Identifier: 0BSD

.DEFAULT_GOAL := all
EXAMPLES := hello-simple hello-complex std-compat torture
.PHONY: all clean check $(EXAMPLES)

all: $(EXAMPLES)

$(EXAMPLES):
	$(MAKE) -C examples/$@ all

check:
	@for example in $(EXAMPLES); do $(MAKE) -C examples/$$example check || exit; done

clean:
	@for example in $(EXAMPLES); do $(MAKE) -C examples/$$example clean || exit; done
