#!/usr/bin/env python3
#
# Copyright (C) 2017  Clifford Wolf <clifford@symbioticeda.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

print("// Generated by rvfi_macros.py")
print("")
print("`ifdef YOSYS")
print("`define rvformal_rand_reg rand reg")
print("`define rvformal_const_rand_reg const rand reg")
print("`else")
print("`ifdef SIMULATION")
print("`define rvformal_rand_reg reg")
print("`define rvformal_const_rand_reg reg")
print("`else")
print("`define rvformal_rand_reg wire")
print("`define rvformal_const_rand_reg reg")
print("`endif")
print("`endif")
print("")
print("`ifndef RISCV_FORMAL_VALIDADDR")
print("`define RISCV_FORMAL_VALIDADDR(addr) 1")
print("`endif")
print("")
print("`define rvformal_addr_valid(a) (`RISCV_FORMAL_VALIDADDR(a))")
print("`define rvformal_addr_eq(a, b) ((`rvformal_addr_valid(a) == `rvformal_addr_valid(b)) && (!`rvformal_addr_valid(a) || (a == b)))")

csrs_xlen = list()
csrs_xlen += "fflags frm fcsr".split()
csrs_xlen += "misa".split()

csrs_64 = list()
csrs_64 += "time mcycle minstret".split()

all_csrs = csrs_xlen + csrs_64

for csr in csrs_xlen:
    print("")
    print("`ifdef RISCV_FORMAL_CSR_%s" % csr.upper())

    print("`define rvformal_csr_%s_wires \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rmask; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wmask; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rdata; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wdata;" % csr)

    print("`define rvformal_csr_%s_outputs , \\" % csr)
    print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rmask, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wmask, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rdata, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wdata" % csr)

    print("`define rvformal_csr_%s_inputs , \\" % csr)
    print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rmask, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wmask, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_rdata, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN - 1 : 0] rvfi_csr_%s_wdata" % csr)

    print("`define rvformal_csr_%s_channel(_idx) \\" % csr)
    print("wire [`RISCV_FORMAL_XLEN - 1 : 0] csr_%s_rmask  = rvfi_csr_%s_rmask  [(_idx)*`RISCV_FORMAL_XLEN  +: `RISCV_FORMAL_XLEN]; \\" % (csr, csr))
    print("wire [`RISCV_FORMAL_XLEN - 1 : 0] csr_%s_wmask  = rvfi_csr_%s_wmask  [(_idx)*`RISCV_FORMAL_XLEN  +: `RISCV_FORMAL_XLEN]; \\" % (csr, csr))
    print("wire [`RISCV_FORMAL_XLEN - 1 : 0] csr_%s_rdata  = rvfi_csr_%s_rdata  [(_idx)*`RISCV_FORMAL_XLEN  +: `RISCV_FORMAL_XLEN]; \\" % (csr, csr))
    print("wire [`RISCV_FORMAL_XLEN - 1 : 0] csr_%s_wdata  = rvfi_csr_%s_wdata  [(_idx)*`RISCV_FORMAL_XLEN  +: `RISCV_FORMAL_XLEN];" % (csr, csr))

    print("`define rvformal_csr_%s_conn , \\" % csr)
    print(".rvfi_csr_%s_rmask (rvfi_csr_%s_rmask), \\" % (csr, csr))
    print(".rvfi_csr_%s_wmask (rvfi_csr_%s_wmask), \\" % (csr, csr))
    print(".rvfi_csr_%s_rdata (rvfi_csr_%s_rdata), \\" % (csr, csr))
    print(".rvfi_csr_%s_wdata (rvfi_csr_%s_wdata)" % (csr, csr))

    print("`else")
    print("`define rvformal_csr_%s_wires" % csr)
    print("`define rvformal_csr_%s_outputs" % csr)
    print("`define rvformal_csr_%s_inputs" % csr)
    print("`define rvformal_csr_%s_channel(_idx)" % csr)
    print("`define rvformal_csr_%s_conn" % csr)
    print("`endif")

for csr in csrs_64:
    print("")
    print("`ifdef RISCV_FORMAL_CSR_%s" % csr.upper())

    print("`define rvformal_csr_%s_wires \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rmask; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wmask; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rdata; \\" % csr)
    print("(* keep *) wire [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wdata;" % csr)

    print("`define rvformal_csr_%s_outputs , \\" % csr)
    print("output [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rmask, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wmask, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rdata, \\" % csr)
    print("output [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wdata" % csr)

    print("`define rvformal_csr_%s_inputs , \\" % csr)
    print("input [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rmask, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wmask, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_rdata, \\" % csr)
    print("input [`RISCV_FORMAL_NRET * 64 - 1 : 0] rvfi_csr_%s_wdata" % csr)

    print("`define rvformal_csr_%s_channel(_idx) \\" % csr)
    print("wire [64 - 1 : 0] csr_%s_rmask  = rvfi_csr_%s_rmask  [(_idx)*64 +: 64]; \\" % (csr, csr))
    print("wire [64 - 1 : 0] csr_%s_wmask  = rvfi_csr_%s_wmask  [(_idx)*64 +: 64]; \\" % (csr, csr))
    print("wire [64 - 1 : 0] csr_%s_rdata  = rvfi_csr_%s_rdata  [(_idx)*64 +: 64]; \\" % (csr, csr))
    print("wire [64 - 1 : 0] csr_%s_wdata  = rvfi_csr_%s_wdata  [(_idx)*64 +: 64];" % (csr, csr))

    print("`define rvformal_csr_%s_conn , \\" % csr)
    print(".rvfi_csr_%s_rmask (rvfi_csr_%s_rmask), \\" % (csr, csr))
    print(".rvfi_csr_%s_wmask (rvfi_csr_%s_wmask), \\" % (csr, csr))
    print(".rvfi_csr_%s_rdata (rvfi_csr_%s_rdata), \\" % (csr, csr))
    print(".rvfi_csr_%s_wdata (rvfi_csr_%s_wdata)" % (csr, csr))

    print("`else")
    print("`define rvformal_csr_%s_wires" % csr)
    print("`define rvformal_csr_%s_outputs" % csr)
    print("`define rvformal_csr_%s_inputs" % csr)
    print("`define rvformal_csr_%s_channel(_idx)" % csr)
    print("`define rvformal_csr_%s_conn" % csr)
    print("`endif")

print("")
print("`ifdef RISCV_FORMAL_EXTAMO")
print("`define rvformal_extamo_wires          (* keep *) wire [`RISCV_FORMAL_NRET-1:0] rvfi_mem_extamo;")
print("`define rvformal_extamo_outputs        , output [`RISCV_FORMAL_NRET-1:0] rvfi_mem_extamo")
print("`define rvformal_extamo_inputs         , input [`RISCV_FORMAL_NRET-1:0] rvfi_mem_extamo")
print("`define rvformal_extamo_channel(_idx)  wire mem_extamo  = rvfi_mem_extamo [_idx];")
print("`define rvformal_extamo_conn           , .rvfi_mem_extamo(rvfi_mem_extamo)")
print("`else")
print("`define rvformal_extamo_wires")
print("`define rvformal_extamo_outputs")
print("`define rvformal_extamo_inputs")
print("`define rvformal_extamo_channel(_idx)")
print("`define rvformal_extamo_conn")
print("`endif")

print("")
print("`define RVFI_WIRES                                                                   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_valid;      \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                 64   - 1 : 0] rvfi_order;      \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_ILEN   - 1 : 0] rvfi_insn;       \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_trap;       \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_halt;       \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_intr;       \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_mode;       \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_ixl;        \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs1_addr;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs2_addr;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs1_rdata;  \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs2_rdata;  \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rd_addr;    \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rd_wdata;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_rdata;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_wdata;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_addr;   \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_rmask;  \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_wmask;  \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_rdata;  \\")
print("(* keep *) wire [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_wdata;  \\")
print("`rvformal_extamo_wires \\")
for csr in all_csrs:
    print("`rvformal_csr_%s_wires%s" % (csr, "" if csr == all_csrs[-1] else " \\"))

print("")
print("`define RVFI_OUTPUTS                                                        \\")
print("output [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_valid,      \\")
print("output [`RISCV_FORMAL_NRET *                 64   - 1 : 0] rvfi_order,      \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_ILEN   - 1 : 0] rvfi_insn,       \\")
print("output [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_trap,       \\")
print("output [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_halt,       \\")
print("output [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_intr,       \\")
print("output [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_mode,       \\")
print("output [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_ixl,        \\")
print("output [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs1_addr,   \\")
print("output [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs2_addr,   \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs1_rdata,  \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs2_rdata,  \\")
print("output [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rd_addr,    \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rd_wdata,   \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_rdata,   \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_wdata,   \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_addr,   \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_rmask,  \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_wmask,  \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_rdata,  \\")
print("output [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_wdata   \\")
print("`rvformal_extamo_outputs \\")
for csr in all_csrs:
    print("`rvformal_csr_%s_outputs%s" % (csr, "" if csr == all_csrs[-1] else " \\"))

print("")
print("`define RVFI_INPUTS                                                        \\")
print("input [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_valid,      \\")
print("input [`RISCV_FORMAL_NRET *                 64   - 1 : 0] rvfi_order,      \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_ILEN   - 1 : 0] rvfi_insn,       \\")
print("input [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_trap,       \\")
print("input [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_halt,       \\")
print("input [`RISCV_FORMAL_NRET                        - 1 : 0] rvfi_intr,       \\")
print("input [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_mode,       \\")
print("input [`RISCV_FORMAL_NRET *                  2   - 1 : 0] rvfi_ixl,        \\")
print("input [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs1_addr,   \\")
print("input [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rs2_addr,   \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs1_rdata,  \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rs2_rdata,  \\")
print("input [`RISCV_FORMAL_NRET *                  5   - 1 : 0] rvfi_rd_addr,    \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_rd_wdata,   \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_rdata,   \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_pc_wdata,   \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_addr,   \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_rmask,  \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN/8 - 1 : 0] rvfi_mem_wmask,  \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_rdata,  \\")
print("input [`RISCV_FORMAL_NRET * `RISCV_FORMAL_XLEN   - 1 : 0] rvfi_mem_wdata   \\")
print("`rvformal_extamo_inputs \\")
for csr in all_csrs:
    print("`rvformal_csr_%s_inputs%s" % (csr, "" if csr == all_csrs[-1] else " \\"))

print("")
print("`define RVFI_CHANNEL(_name, _idx) \\")
print("generate if(1) begin:_name \\")
print("wire [                 1   - 1 : 0] valid      = rvfi_valid      [(_idx)*(                 1  )  +:                  1  ]; \\")
print("wire [                64   - 1 : 0] order      = rvfi_order      [(_idx)*(                64  )  +:                 64  ]; \\")
print("wire [`RISCV_FORMAL_ILEN   - 1 : 0] insn       = rvfi_insn       [(_idx)*(`RISCV_FORMAL_ILEN  )  +: `RISCV_FORMAL_ILEN  ]; \\")
print("wire [                 1   - 1 : 0] trap       = rvfi_trap       [(_idx)*(                 1  )  +:                  1  ]; \\")
print("wire [                 1   - 1 : 0] halt       = rvfi_halt       [(_idx)*(                 1  )  +:                  1  ]; \\")
print("wire [                 1   - 1 : 0] intr       = rvfi_intr       [(_idx)*(                 1  )  +:                  1  ]; \\")
print("wire [                 2   - 1 : 0] mode       = rvfi_mode       [(_idx)*(                 2  )  +:                  2  ]; \\")
print("wire [                 2   - 1 : 0] ixl        = rvfi_ixl        [(_idx)*(                 2  )  +:                  2  ]; \\")
print("wire [                 5   - 1 : 0] rs1_addr   = rvfi_rs1_addr   [(_idx)*(                 5  )  +:                  5  ]; \\")
print("wire [                 5   - 1 : 0] rs2_addr   = rvfi_rs2_addr   [(_idx)*(                 5  )  +:                  5  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] rs1_rdata  = rvfi_rs1_rdata  [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] rs2_rdata  = rvfi_rs2_rdata  [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [                 5   - 1 : 0] rd_addr    = rvfi_rd_addr    [(_idx)*(                 5  )  +:                  5  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] rd_wdata   = rvfi_rd_wdata   [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] pc_rdata   = rvfi_pc_rdata   [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] pc_wdata   = rvfi_pc_wdata   [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] mem_addr   = rvfi_mem_addr   [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN/8 - 1 : 0] mem_rmask  = rvfi_mem_rmask  [(_idx)*(`RISCV_FORMAL_XLEN/8)  +: `RISCV_FORMAL_XLEN/8]; \\")
print("wire [`RISCV_FORMAL_XLEN/8 - 1 : 0] mem_wmask  = rvfi_mem_wmask  [(_idx)*(`RISCV_FORMAL_XLEN/8)  +: `RISCV_FORMAL_XLEN/8]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] mem_rdata  = rvfi_mem_rdata  [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("wire [`RISCV_FORMAL_XLEN   - 1 : 0] mem_wdata  = rvfi_mem_wdata  [(_idx)*(`RISCV_FORMAL_XLEN  )  +: `RISCV_FORMAL_XLEN  ]; \\")
print("`rvformal_extamo_channel(_idx) \\")
for csr in all_csrs:
    print("`rvformal_csr_%s_channel(_idx) \\" % csr)
print("end endgenerate")

print("")
print("`define RVFI_CONN                  \\")
print(".rvfi_valid     (rvfi_valid    ),  \\")
print(".rvfi_order     (rvfi_order    ),  \\")
print(".rvfi_insn      (rvfi_insn     ),  \\")
print(".rvfi_trap      (rvfi_trap     ),  \\")
print(".rvfi_halt      (rvfi_halt     ),  \\")
print(".rvfi_intr      (rvfi_intr     ),  \\")
print(".rvfi_mode      (rvfi_mode     ),  \\")
print(".rvfi_ixl       (rvfi_ixl      ),  \\")
print(".rvfi_rs1_addr  (rvfi_rs1_addr ),  \\")
print(".rvfi_rs2_addr  (rvfi_rs2_addr ),  \\")
print(".rvfi_rs1_rdata (rvfi_rs1_rdata),  \\")
print(".rvfi_rs2_rdata (rvfi_rs2_rdata),  \\")
print(".rvfi_rd_addr   (rvfi_rd_addr  ),  \\")
print(".rvfi_rd_wdata  (rvfi_rd_wdata ),  \\")
print(".rvfi_pc_rdata  (rvfi_pc_rdata ),  \\")
print(".rvfi_pc_wdata  (rvfi_pc_wdata ),  \\")
print(".rvfi_mem_addr  (rvfi_mem_addr ),  \\")
print(".rvfi_mem_rmask (rvfi_mem_rmask),  \\")
print(".rvfi_mem_wmask (rvfi_mem_wmask),  \\")
print(".rvfi_mem_rdata (rvfi_mem_rdata),  \\")
print(".rvfi_mem_wdata (rvfi_mem_wdata)   \\")
print("`rvformal_extamo_conn \\")
for csr in all_csrs:
    print("`rvformal_csr_%s_conn%s" % (csr, "" if csr == all_csrs[-1] else " \\"))