This folder contains the Proteus artifact for our EuroS&amp;P 2023 paper "CHERI-TrEE: Flexible enclaves on capability machines".
This file briefly discusses the contents of the different subfolders present in this artifact, and how they interrelate.

# `ProteusCore` 
Contains the implementation of the proteus core, along with its CHERI extensions, and the extensions to support attestation.
The README in this folder provides further information on how to build the core.
The microbenchmarks are spread throughout various `test` subfolders within this folder, the main one being `src/main/scale/riscv/plugins/capattest/tests`

# `proteuscode`
Contains the attestation macrobenchmark, to be run on the generated image of the Proteus core.
These test
The README in this folder provides further information on how to run the tests.

# `SpinalCrypto`
Clone of the SpinalCrypto package containing the SHA implementation. 
Clone present because this package is no longer properly hosted on Maven, and we pinned the right version for compatibility reasons.

# `disas`
This folder is only relevant for disassembly (in gtkwave) of the current instruction of the waveforms output by ProteusCore. `disas.py` can be run by gtkwave to allow you to disassemble our new enclave instructions.
