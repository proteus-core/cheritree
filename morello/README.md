# Morello
Our project is funded by the Digital Security by Design (DsDb) Programme delivered by UKRI to support the DSbD ecosystem.

This folder contains experimental code for Morello and ports the CHERI Proteus RISCV enclave design to Morello.

This is a prototype only to assess the viability of the design on a commercial CHERI processor, and comes with no guarantees. 

The project was devloped for the Morello platform only and built using the **LLVM pre built binaries for Morello bare metal**. It is recommended to use this to build the project.

## Prerequisites

* LLVM pre built binaries for Morello bare metal (Tested with version release-1.3)
    * https://git.morello-project.org/morello/llvm-project-releases/-/tree/morello/baremetal-release-1.3
* Morello Platform Model FVP (Tested with version FVP_Morello_0.11_33) or access to the Morello hardware.
    * https://developer.arm.com/downloads/-/arm-ecosystem-fvps

* Build tools and kowledge of how to build the firmware and create mcp / scp and FIP binaries for the FVP and hardware. (Tested with version release-1.3)

    * https://git.morello-project.org/morello/docs/-/blob/morello/release-1.3/user-guide.rst#firmware-only
    * https://git.morello-project.org/morello/docs
* Some experience of building and running bare metal programs on Morello is assumed.


## File Structure

* **morello/libs** - submodules - libtomcrypt to do the instruction hashing. 
* **morello/project/enclaveMorello/src** - source code.
* **morello/project/enclaveMorello/scripts** - script files to calculate the hash of the code section and insert the hash into the elf file.
* **morello/project/enclaveMorello/build** - make file to build the project to an elf binary.
* **morello/exampleScripts/fromElf/enclaveMorello/scripts** - scripts to make a FIP binary of the project from the elf file to run directly on the FVP or SOC hardware. Assumes the build tools to build the firmware have been installed (release-1.3).

## Acknowledgements and Licenses
* The license file for the project is in LICENSE.md. 
* Libtomcrypt library was used to do the instruction hashing and is included as a submodule. 
* An embedded printf function developed by Marco Paland has been included under an MIT License (MIT). The license is included with the function code. This printf function is used to print to the UART at EL1.
* An image loader file from Arm was modified to load FIP files at EL2. This is included under Apache-2.0 license in the file.
* Boot-up files have been modified and included at EL2. The license notice is included in the files. The original unmodified boot source files (For EL3) are from `morello/release-1.3` of the Newlib source repository. https://git.morello-project.org/morello/newlib/-/tree/morello/release-1.3

## Build Options

The following build options are available:

* Build to elf using a makefile, and then build binaries for FIP FVP to run as a self-contained program on the FVP. 
* Build to elf using a makefile, and then build binaries for FIP SOC (hardware) to run as a self-contained program on the hardware.

## Clone the Repository
Clone the repository with submodules.
```
git clone --recurse-submodules https://github.com/proteus-core/cheritree.git
```

## Running the Code - Starting from EL2

The code runs from **EL2** after the trusted firmware has been loaded and this makes it easier to port to the hardware as a FIP. Starting from EL3 is no longer supported and EL3 code is not included in the build. When the program is running output is printed to the UART. 

To build the project to an elf binary navigate to `morello/project/enclaveMorello/build` directory and run the make file. It may be necessary to change the path to LLVM clang by modifying `CC` depending upon where the LLVM binaries have been installed.
```
make
```

Once the `enclaveMorello.elf` binary has been created, the project can be built into the FIP for downloading directly onto the FVP or hardware. Navigate to `morello/exampleScripts/fromElf/enclaveMorello/scripts`. First prepare the program for the loader which is used to load the program into EL1 and EL2 memory areas.
```
./createprogbinWithCap.sh
```
Then create the FIP and mcp/scp firmware files for either the FVP or hardware. These scripts need to be run from the morello firmware build directory which should be located at `morello_workspace`. It may be necessary to modify the path in the script depending upon where the firmware build directory has been installed.
```
./createfvpbinWithCap.sh #For FVP
./createsocbinWithCap.sh #For hardware
```
For the hardware the FIP can then be loaded onto the Morello SD card and the hardware should be re-booted. For the FVP a script can be used to load the FIP and run the program. It may be necessary to edit the path to the FVP.
```
./runfvpEL2.sh
``` 


## Extra Debug Information at EL1

Extra information can be output to the UART at EL1. To turn this on include `#define DEBUG_EL1 1` in EL1Debug.h and rebuild. The embedded printf function is redirected to the UART at EL1. Debug is turned off by default.

## Benchmark Settings

There are two benchmark settings to gather measurements using the performance timer. Measurements are output via the UART. 
Include `-DBENCHMARK1` or `-DBENCHMARK2` in the CFLAGS of the makefile.

## Tests

Some additional tests can be built and run:

* Basic HVC tests
* Tests on memory modifications by EL1
* Tests on instructions

Select the test number to run in `test_EL1NEntry.c`, and then build the project by navigating to `morello/project/enclaveMorello/build` directory and run the make file. This produces an `enclaveMorello_test.elf` binary.
```
make test
```

