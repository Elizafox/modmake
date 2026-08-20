# `std.compat` Make example

This project imports the toolchain-provided `std.compat` module and uses a C
standard-library name from the global namespace. From this directory:

```sh
make check CXX=clang++
make clean
make check CXX=g++
```
