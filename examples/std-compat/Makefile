# SPDX-License-Identifier: 0BSD

cxx_is_clang := $(findstring __clang__,$(shell $(CXX) -dM -E -x c++ /dev/null 2>/dev/null))
CXXFLAGS := -std=c++23 -Wall -Wextra -pedantic $(if $(cxx_is_clang),-stdlib=libc++)
CXX_SOURCES := src/main.cpp

include ../../cxx-modules.mk

.DEFAULT_GOAL := all
.PHONY: all check clean
all: build/std-compat

build/std-compat: $(CXX_MODULE_OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@

check: build/std-compat
	@output=`./build/std-compat`; test "$$output" = 'Hello from std.compat!' || { echo "unexpected output: $$output"; exit 1; }

clean:
	rm -rf build
