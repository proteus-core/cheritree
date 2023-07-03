#!/bin/bash

RED='\033[0;91m'
GREEN='\033[0;92m'
NC='\033[0m'

pass=0
fail=0


function green {
    (( pass += 1 ))
    printf "$1: ${GREEN}$2${NC}\n"
}

function red {
    (( fail += 1 ))
    printf "$1: ${RED}$2${NC}\n"
}

cd unit-tests
if ! make; then
    echo "Set the CLANG environment variable to the custom clang binary."
    exit 1
else
    for test in *.elf; do
        if timeout 15 ../../c_emulator/cheri_riscv_sim_RV64 -p $test > ${test%.elf}.cout 2>&1 && grep -q SUCCESS ${test%.elf}.cout
        then
        green "C-64 $(basename $test)" "ok"
        else
        red "C-64 $(basename $test)" "fail"
        fi
    done
    printf "Passed ${pass} out of $(( pass + fail )) tests \n\n"
fi
