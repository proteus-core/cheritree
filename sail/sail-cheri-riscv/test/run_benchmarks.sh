#!/bin/bash

last_benchmark=0

run_benchmark () {
    if timeout 15 ../../c_emulator/cheri_riscv_sim_RV64 -p $1.elf > ${1%.elf}.cout 2>&1 && grep -q SUCCESS ${1%.elf}.cout
    then
        insts=$(grep "Instructions" $1.cout)
        last_benchmark=${insts#*: }
    else
        echo "A benchmark failed!"
        exit 1
    fi
}

compare () {
    run_benchmark $1
    first=$last_benchmark
    run_benchmark $2
    second=$last_benchmark
    diff=$(( $first - $second ))
    printf "%s (%d instructions), %s (%d instructions), difference: %d\n" $1 $first $2 $second $diff
}

cd benchmarks

compare init no-init
compare deinit full
compare full no-caller-attestation
compare full no-callee-attestation
compare no-hash-full no-caller-attestation-no-hash
compare no-hash-full no-callee-attestation-no-hash
compare deinit only-fac
