# Demo code for the Proteus Core

This repo contains some demos for the [Proteus Core](https://gitlab.com/ProteusCore/ProteusCore).

This repo requires nn RV32IM [toolchain](https://github.com/riscv/riscv-gnu-toolchain), which can be built like this (check the toolchain README for dependencies on different OSes):

```
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
 ./configure --prefix=/opt/riscv-toolchain --with-abi=ilp32 --with-arch=rv32im
sudo make
```

You then need to add `/opt/riscv-toolchain` to your path. Once done, you should (tm) be able to compile the examples.