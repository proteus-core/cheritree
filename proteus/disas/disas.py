#!/usr/bin/env python3

# The purpose of this file is to allow disassembly of Attestation-related instructions by using a custom version of `llvm-objdump`

import sys
import subprocess
import tempfile
from pathlib import Path

GCC_OBJDUMP_PATH = "riscv32-unknown-elf-objdump"
LLVM_OBJDUMP_PATH = "/home/thomas/cheri/output/sdk/bin/llvm-objdump" #CHANGE to your path
SKELETON_PATH = str(Path(__file__).resolve().parent / "single-instruction-skeleton.elf")

def output(line):
  print(line, flush=True)

def proc_show(proc):
  print(proc)
  print(proc.stdout)
  print(proc.stderr,end="\n\n")

###########################################################################
#                                GCC                                      #
###########################################################################

import time
def gnu_objcopy(f1, f2):
  objcopy  = "riscv32-unknown-elf-objcopy"
  objcopy += " -I binary"
  objcopy += " -O elf32-littleriscv"
  objcopy += " %s" % f1.name
  objcopy += " %s" % f2.name

  proc = subprocess.run(objcopy.split(),
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)

def gnu_objdump(f):
  objdump  = GCC_OBJDUMP_PATH
  objdump += " -D"
  objdump += " -b binary"
  objdump += " -m riscv"
  objdump += " -M no-aliases"
  objdump += " %s" % f.name

  return subprocess.run(objdump.split(),
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True)

def gnu_disassemble(bytez):
  with tempfile.NamedTemporaryFile() as f:
    f.write(bytez)
    f.flush()

    proc = gnu_objdump(f)

    if proc.returncode == 0:
      for line in proc.stdout.split('\n'):
        parts = line.split()
        if len(parts) >= 3 and parts[0] == '0:':
          return ' '.join(parts[2:])

    return bytez.hex()

###########################################################################
#                                LLVM                                     #
###########################################################################

# Steps required to create skeleton `single-instruction-skeleton.elf`:
# 1. copy section `.riscv.attributes` from an existing CHERI-ELF file that was compiled using clang. This section is needed to have the llvm disassembler interpret the result as CHERI assembly. Alternatively, it is possible to set the correct ABI flags on an assembly file. Store this section in a binary file `attributes-section.bin`, e.g. as follows:
#  `riscv32-unknown-elf-objcopy --set-section-flags .riscv.attributes=alloc -O binary --only-section=.riscv.attributes <input-elf> attributes-section.bin`
# 2. Convert a single instruction to an elf file `single-instruction-skeleton.elf`, e.g. using the `gnu_objcopy` method above. This will result in an `elf` file with a single instruction data section.
# 3. Add the `.riscv.attributes` section to the freshly created elf file. This can be done through the following command:
#   `riscv32-unknown-elf-objcopy --add-section .riscv.attributes=attributes-section.bin single-instruction-skeleton.elf single-instruction-skeleton.elf`
# 4. This section will have the wrong type (`PROGBITS` = 0x00000001 instead of `RISCV_ATTRIBUTES` = 0x70000003). Open up a hexeditor to make the necessary adjustment in the metadata of the `.riscv.attributes` section.
# 5. Happy disassembling by replacing the single instruction using the below function.

def skeleton_replace_data(f_bytez,f_out):
    replace_cmd  = "riscv32-unknown-elf-objcopy"
    replace_cmd += " --update-section .data=%s" % f_bytez.name
    replace_cmd += " %s" % SKELETON_PATH
    replace_cmd += " %s" % f_out.name

    proc = subprocess.run(replace_cmd.split(),
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE,
                          universal_newlines=True)


def llvm_objdump(f):
  with tempfile.NamedTemporaryFile() as f2:
    skeleton_replace_data(f, f2)

    objdump  = LLVM_OBJDUMP_PATH
    objdump += " -D"
    objdump += " --section .data"
    objdump += " %s" % f2.name

    proc = subprocess.run(objdump.split(),
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE,
                          universal_newlines=True)
    return proc

def llvm_disassemble(bytez):
  with tempfile.NamedTemporaryFile() as f:
    f.write(bytez)
    f.flush()

    proc = llvm_objdump(f)

    if proc.returncode == 0:
      for line in proc.stdout.split('\n'):
        parts = line.split()
        if len(parts) >= 3 and parts[0] == '0:':
          return ' '.join(parts[5:])

    return bytez.hex()

###########################################################################
#                                MAIN                                     #
###########################################################################

def disassemble(bytez):
  assert len(bytez) == 4
  # result = gnu_disassemble(bytez)
  result = llvm_disassemble(bytez)

  if result.find("unknown") > 0:
    result = bytez.hex()
  return result

if __name__ == "__main__":
    for line in sys.stdin:
        try:
            hexstring = line.strip()
            instr = bytes(reversed(bytes.fromhex(hexstring)))
            output(disassemble(instr))
        except:
            output('???')
