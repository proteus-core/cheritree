#!/bin/bash

# Copyright (c) 2020, Arm Limited.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The script produces an image that can run on the Morello
# model from a user supplied ELF binary.

# This file has been modified by CAP-TEE project 2022
#edit tool path

cleanup () {
  if [ ! -z $LOADER_TMP ]; then
    rm -rf $LOADER_TMP
  fi
}

error() {
  echo "Failed to build image"
  exit 1
}

usage () {
local PROG=`basename $0`
cat <<EOF

Usage: $PROG [options]

Options:
 -i input_file     The input_file is the input ELF binary
 -o output_file    The output_file is the output image
 -h                Print this help message

EOF
}

while getopts ":hi:o:" opt; do
  case $opt in
    i)
      INPUT=${OPTARG}
      ;;
    o)
      OUTPUT=${OPTARG}
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Unknown option '$OPTARG'"
      usage
      exit 1
      ;;
  esac
done

if [ -z "${INPUT}" ] || [ -z "${OUTPUT}" ]; then
    echo "Input and output images need to be specified"
    usage
    exit 1
fi

if [ ! -f "${INPUT}" ]; then
    echo "Input file $INPUT does not exist"
    exit 1
fi

# Make a temporary build folder
LOADER_TMP=$(mktemp -d)
if [ $? -ne 0 ]; then
  echo "Could not create temporary folder"
  exit 1
fi

trap cleanup EXIT
trap error ERR

# Generate embed.s
echo 	".globl elf_start, elf_end
	.section .rodata
	.balign 16
elf_start:
	.incbin \"$LOADER_TMP/input\"
elf_end:
" > $LOADER_TMP/embed.s

# Copy the input to LOADER_TMP
cp $INPUT $LOADER_TMP/input

SRC=`dirname "$(readlink -f "$0")"`
BIN_PATH=$SRC/loader

# Copy start.ld, init.o and loader.o to the temporary folder
for F in start_el2.ld  init.o loader.o; do
  if [ ! -f "$BIN_PATH/$F" ]; then
      echo "Error: $BIN_PATH/$F does not exist"
      exit 1
  fi
  cp $BIN_PATH/$F $LOADER_TMP/$F
done

#TOOL_PATH=$SRC/bin
TOOL_PATH="/home/projects/baremetalsources/llvm-project-releases/bin"
CLANG=$TOOL_PATH/clang
LLD=$TOOL_PATH/ld.lld
OBJCOPY=$TOOL_PATH/llvm-objcopy

# Assemble embed.o
$CLANG -target aarch64-none-elf $LOADER_TMP/embed.s -c -o $LOADER_TMP/embed.o 

# Link image
$LLD -o $LOADER_TMP/image.elf -entry __init $LOADER_TMP/init.o $LOADER_TMP/loader.o $LOADER_TMP/embed.o -T $LOADER_TMP/start_el2.ld

# Produce the image (invoke objcopy)
$OBJCOPY $LOADER_TMP/image.elf $LOADER_TMP/output --output-target binary
cp $LOADER_TMP/output $OUTPUT
