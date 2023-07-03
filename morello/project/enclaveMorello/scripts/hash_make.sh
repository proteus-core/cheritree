#!/bin/bash

SCRDIR=$(dirname "$0")

ENCLAVE_ID=${SCRDIR}/enclave_id.py

INFILE=${SCRDIR}/../build/enclaveMorello.elf
OUTFILE=${SCRDIR}/../build/enclaveMorello_out.elf
NOID_INFILE=${SCRDIR}/../build/enclaveMorello_noid.elf
${ENCLAVE_ID} --enclave sensor ${INFILE} -o ${OUTFILE}

mv ${INFILE} ${NOID_INFILE}
mv ${OUTFILE} ${INFILE}
