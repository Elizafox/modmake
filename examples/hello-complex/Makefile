# SPDX-License-Identifier: 0BSD

CXXFLAGS := -std=c++20 -Wall -Wextra -pedantic
CXX_MODULE_PATHS := modules
CXX_SOURCES := src/hello.cpp src/main.cpp

include ../../cxx-modules.mk

.DEFAULT_GOAL := all
.PHONY: all check clean
all: build/hello

build/hello: $(CXX_MODULE_OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@

check: build/hello
	@output=`./build/hello`; test "$$output" = 'Hello, modules!' || { echo "unexpected output: $$output"; exit 1; }

clean:
	rm -rf build
