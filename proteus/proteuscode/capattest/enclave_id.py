#!/usr/bin/env python3

import argparse
import hashlib
import shutil
from pathlib import Path

from elftools.elf.elffile import ELFFile


class Enclave:
    def __init__(self, name):
        self.text_section = f'.enclave.{name}.text'
        self.id_section = f'.enclave.{name}.id'


parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('-o', '--output', type=Path)
parser.add_argument('--enclave', type=Enclave)
args = parser.parse_args()

with args.input.open('rb') as f:
    enclave_elf = ELFFile(f)
    enclave_section = enclave_elf.get_section_by_name(args.enclave.text_section)
    enclave_code = enclave_section.data()

    id_section = enclave_elf.get_section_by_name(args.enclave.id_section)
    id_offset = id_section['sh_offset']

hasher = hashlib.sha256()
hasher.update(enclave_code)
enclave_id = hasher.digest()

shutil.copy(args.input, args.output)

with args.output.open('r+b') as f:
    f.seek(id_offset)
    f.write(enclave_id)
