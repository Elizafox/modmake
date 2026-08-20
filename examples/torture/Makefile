# SPDX-License-Identifier: 0BSD

# Select libc++ for Clang because it ships the standard-library module source.
# GCC's adapter adds -fmodules and builds libstdc++'s std module automatically.
cxx_is_clang := $(findstring __clang__,$(shell $(CXX) -dM -E -x c++ /dev/null 2>/dev/null))
CXXFLAGS := -std=c++23 -Wall -Wextra -pedantic $(if $(cxx_is_clang),-stdlib=libc++)
CXX_MODULE_PATHS := modules
CXX_SOURCES := src/engine.cpp src/main.cpp

include ../../cxx-modules.mk

.DEFAULT_GOAL := all
.PHONY: all check clean
all: build/torture

build/torture: $(CXX_MODULE_OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@

check: build/torture
	@output=`./build/torture`; test "$$output" = '[trace] left:42/cfg | right:42/cfg' || { echo "unexpected output: $$output"; exit 1; }

clean:
	rm -rf build
