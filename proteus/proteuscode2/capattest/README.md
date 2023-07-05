# Prerequisites

- riscv-gnu-toolchain: see [this](https://gitlab.com/ProteusCore/proteuscode/-/blob/main/README.md)
- llvm-cheri toolchain: https://gitlab.com/ProteusCore/llvm-cheri
```shell
mkdir build; cd build
cmake -DCMAKE_INSTALL_PREFIX=/path/to/llvm/install/dir -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_ENABLE_PROJECTS=clang CMAKE_BUILD_TYPE=Release -GNinja ../llvm/
ninja # Be very, very patient. When you get out-of-memory errors, rerun with "ninja -j1"
```
- Proteus core with capability attestation extension: https://gitlab.com/ProteusCore/ProteusCore
```shell
git checkout capattest
make -C sim CORE=riscv.plugins.capattest.CoreExtMem
```
- Python 3
- [pyelftools](https://github.com/eliben/pyelftools) (`pip install pyelftools`)

# Building

- Make sure riscv-gnu-toolchain and llvm-cheri are in your `PATH`
- Run `make` from this directory

# Running

From the ProteusCore top-level directory (`THIS_DIR` refers to the directory of this readme):
```shell
./sim/build/sim $THIS_DIR/main.bin
```

This will generate a file called `sim.vcd` containing the waves.
