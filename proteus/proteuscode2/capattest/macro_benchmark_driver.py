#!/usr/bin/env python3

import sys
import subprocess
import os

SIM_PATH = "../../ProteusCore/"
OUT_PATH = "results.txt"

# Some constants used in the calculation of the overheads and the number of loops we should take
SENSOR_USE0_CYC = 497
SENSOR_USE_NO_ENC_CYC = 79
SENSOR_ENC_INIT_CYC = 9181
SENSOR_ENC_ATT_CYCLES = 403

MAX_SENSOR_WORK = 5000
CYCLES_PER_LOOP = 7
NB_LOOPS = MAX_SENSOR_WORK // CYCLES_PER_LOOP
LOOP_STEP = 10

def run_in_subprocess(cmd_str,cwd=None):
    return subprocess.run(cmd_str,cwd=cwd,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE,
                          text=True)

def find_sensor_overhead(output):
    for l in output.splitlines():
        if l.startswith("user.use_sensor took"):
            return int(l.split()[2])
    raise Exception("No information provided about sensor usage")

def sensor_to_relative_overhead(sensor_cycles):
    sensor_work = sensor_cycles - SENSOR_USE0_CYC
    use_relative_overhead = (SENSOR_USE0_CYC - SENSOR_USE_NO_ENC_CYC) / (SENSOR_USE_NO_ENC_CYC + sensor_work)
    full_relative_overhead = (SENSOR_USE0_CYC + SENSOR_ENC_ATT_CYCLES + SENSOR_ENC_INIT_CYC - SENSOR_USE_NO_ENC_CYC) / (SENSOR_USE_NO_ENC_CYC + sensor_work)
    return sensor_work,use_relative_overhead,full_relative_overhead

def output_data(results):
    with open(OUT_PATH, 'w') as f:
            f.write("\n".join('{} {} {}'.format(row[0],row[1],row[2]) for row in results))

def run_sim(loop_value):
    to_remove = ["sensor_enclave.d","sensor_enclave.o"]
    for name in to_remove:
        try:
            os.remove(name)
        except OSError: #ignore if file does not exist
            pass

    make_cmd = ["make", "all",'EXPERIMENTS_FLAGS="-D NB_ITERATIONS=%s"' % loop_value]
    proc = run_in_subprocess(make_cmd)
    if proc.returncode != 0:
        raise Exception("Error while making:\n {}".format(proc.stderr))

    prot_core_dir = os.path.join(os.path.abspath(sys.path[0]), SIM_PATH)
    main_bin_path = os.path.join(os.path.abspath(sys.path[0]), "main.bin")
    sim_bin_path = os.path.join(prot_core_dir, "sim/build/sim")
    sim_cmd =  [sim_bin_path, main_bin_path]
    proc = run_in_subprocess(sim_cmd,cwd=prot_core_dir)

    if proc.returncode == 0:
        return proc.stdout
    else:
        raise Exception("Error while simulating:\n {}".format(proc.stderr))


if __name__ == "__main__":
    results = []
    for loop_value in range(0,NB_LOOPS,LOOP_STEP):
         output = run_sim(loop_value)
         sensor_cycles = find_sensor_overhead(output)
         relative_overheads = sensor_to_relative_overhead(sensor_cycles)
         results += [relative_overheads]
         print(loop_value,": ",relative_overheads)
    output_data(results)
