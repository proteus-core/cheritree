#!/usr/bin/env python3

import sys
import argparse
import hashlib
import shutil
from pathlib import Path

from elftools.elf.elffile import ELFFile

#Assumptions on enclave labels
ENCLAVE_START = "enclave"
ENCLAVE_END = "end_enclave"
ID_LABEL = "expected_hash"

parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('-o', '--output', type=Path)
args = parser.parse_args()

def find_offset(elf, sym):
    file_offset = None
    for seg in elf.iter_segments():
        if seg.header['p_type'] != 'PT_LOAD':
            continue
        # If the symbol is inside the range of a LOADed segment, calculate the file
        # offset by subtracting the virtual start address and adding the file offset
        # of the loaded section(s)
        if sym['st_value'] >= seg['p_vaddr'] and sym['st_value'] <= seg['p_vaddr'] + seg['p_filesz']: #allow final address to coincide if label is at the very end
            file_offset = sym['st_value'] - seg['p_vaddr'] + seg['p_offset']
            break
    return file_offset

with args.input.open('rb') as f:
    elf = ELFFile(f)

    #Read offsets to read and write
    # https://github.com/eliben/pyelftools/issues/227

    symtab = elf.get_section_by_name('.symtab')
    if not symtab:
        print('No symbol table available!')
        sys.exit(1)

    sym_start = symtab.get_symbol_by_name(ENCLAVE_START)[0]
    sym_end = symtab.get_symbol_by_name(ENCLAVE_END)[0]
    sym_id = symtab.get_symbol_by_name(ID_LABEL)[0]
    if not sym_start or not sym_end or not ID_LABEL:
        print('Some symbol not found')
        sys.exit(1)

    start_offset = find_offset(elf,sym_start)
    end_offset = find_offset(elf,sym_end)
    id_offset = find_offset(elf,sym_id)
    if not start_offset or not end_offset or not id_offset:
        print('Error getting file offset from ELF data')
        sys.exit(1)

    #Read data
    elf.stream.seek(start_offset)
    enclave_code = elf.stream.read(end_offset - start_offset)

hasher = hashlib.sha256()
hasher.update(enclave_code)
enclave_id = hasher.digest()

shutil.copy(args.input, args.output)

with args.output.open('r+b') as f:
    f.seek(id_offset)
    f.write(enclave_id)
