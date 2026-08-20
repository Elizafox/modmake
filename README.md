# modmake

[![Examples](https://github.com/Elizafox/modmake/actions/workflows/examples.yml/badge.svg)](https://github.com/Elizafox/modmake/actions/workflows/examples.yml)

A proof of concept for building C++ modules with GNU Make and one embeddable Make
fragment. It auto-detects Clang or GCC, asks the selected toolchain for standard
P1689 dependency facts, and uses `jq` to turn those facts into an included Make
DAG.

```make
CXX := clang++ # or g++
CXXFLAGS := -std=c++20
CXX_MODULE_PATHS := modules
CXX_SOURCES := src/main.cpp src/my_module_impl.cpp

include path/to/cxx-modules.mk

app: $(CXX_MODULE_OBJECTS)
 $(CXX) $(CXXFLAGS) $^ -o $@
```

Alternatively, list interface sources explicitly with `CXX_MODULE_SOURCES`.
`CXX_MODULE_PATHS` recursively discovers `.cppm`, `.ixx`, and `.mpp` files.
External prebuilt modules can be registered as whitespace-separated
`name=path` entries in `CXX_MODULE_EXTERNAL`. Dependencies between external
modules can be registered as `name=dependency[,dependency...]` entries in
`CXX_MODULE_EXTERNAL_REQUIRES`.

The fragment exports:

- `CXX_MODULE_BMIS`: locally built BMI/CMI files;
- `CXX_MODULE_OBJECTS`: every configured source's object file; and
- `CXX_MODULE_OUTPUT_GROUPS`: `bmi=object` pairs for interface units.

Most projects only need `CXX_MODULE_OBJECTS` for a library or executable target.
Individual generated object paths can also be used as ordinary prerequisites.

The standalone examples cover progressively more involved module graphs:

- `examples/make-hello-simple` has one interface and one consumer.
- `examples/make-hello-complex` adds a partition and implementation unit.
- `examples/make-std-compat` imports the standard-library compatibility module.
- `examples/make-torture` stresses a deep, parallel, diamond-shaped graph and
  builds the toolchain's `std` module.

Build and run all examples with:

```sh
make check
```

Select GCC for all examples with `make check CXX=g++`.

## Scope and caveats

It handles named modules, exported and internal partitions, relative partition
imports, implementation units, external BMIs, and the transitive mappings needed
while loading a BMI. Clang gets explicit `-fmodule-file=name=path` mappings. GCC
gets per-target mapper files and grouped targets because one interface compilation
produces both its CMI and object.

Dependency discovery comes from the compiler rather than a source-level
approximation. The module dependency graph must be acyclic. Source paths and
flags containing JSON special characters are not yet escaped when the
compilation database is written. Ordinary Unix project paths and flags work.

Useful overrides include `CXX_MODULE_BUILD_DIR`, `CXX_MODULE_BMI_DIR`,
`CXX_MODULE_OBJECT_DIR`, `CXX_MODULE_FLAGS`, `CXX_MODULE_SCANNER`, and
`CXX_MODULE_JQ`.

### The existence of this is an abomination

Ma'am, that is a 250-line GNU Make fragment. It has no build-system generator,
dependency manager, or bespoke graph library. It is an amalgamation of Make
functions, P1689 dependency metadata, compiler invocations, and `jq`, expanded,
evaluated, recursively included, and ultimately inexorably joined into an
unholy build-system artifact. God had no hand in the creation of this
abhorrence. The fact that this Make fragment builds C++20 modules proves that
God is either impotent to alter his universe or ignorant to the horrors taking
place in His kingdom. This module of Make is more than a build system. It is a
physical declaration of mankind's contempt for the natural order. It is hubris
manifest.

CMake can also do this if you would prefer that.

## Dependencies

This make fragment needs `jq` and GNU Make 4.3 or newer.

In addition, a P1689-capable toolchain is required: Clang with
`clang-scan-deps`, or GCC 16 or newer. Compiler detection uses the macros
reported by `$(CXX)`; wrappers can set `CXX_MODULE_COMPILER := clang` or `gcc`
explicitly.

## Contributing

Contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md) and agree to
submit contributions pursuant to the
[Developer's Certificate of Origin](DCO).

## License

The fragment is available under the [0BSD license](LICENSE).
