# SPDX-License-Identifier: 0BSD

.DEFAULT_GOAL := all
.PHONY: all clean check

EXAMPLES := examples/make-hello-simple examples/make-hello-complex examples/make-std-compat examples/make-torture

all:
	@for example in $(EXAMPLES); do $(MAKE) -C $$example all || exit; done

check:
	@for example in $(EXAMPLES); do $(MAKE) -C $$example check || exit; done

clean:
	@for example in $(EXAMPLES); do $(MAKE) -C $$example clean || exit; done
