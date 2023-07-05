# Blink demo

This demo has a single assembly file that does one thing: it counts (from 0 to 255 and then wrapping around) on the byteio port. If LEDs are connected on this port, it will display a blinky pattern.

## Building

A simple `make` should suffice, assuming that the `riscv32-unknown-elf` toolchain is installed.
