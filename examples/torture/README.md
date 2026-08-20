# Make module-graph torture test

This example deliberately stresses the generated Make DAG with:

- ten module interface units spread through nested directories;
- a primary module, two exported partitions, and one internal partition;
- multiple independent roots that can compile in parallel;
- overlapping diamonds through `foundation.config`, `foundation.trace`, and
  `engine:core`;
- a dotted module name and relative partition imports;
- a separate module implementation unit; and
- the toolchain-provided `std` module in every branch.

The approximate shape is:

```text
std -> config -----> model ---\
  |       |                    +-> engine:core -> engine:left -\
  |       +--> calc:ops --\    |       |                       |
  +-> trace -> calc:format -> calc     +-----> engine:right ---+-> engine -> implementation -> main
       |                       |                  |            |
       +-----> app.support ----+------------------+------------+
```

Run it with either supported compiler:

```sh
make -j check CXX=clang++
make clean
make -j check CXX=g++
```
