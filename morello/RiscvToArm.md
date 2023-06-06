# CHERI Proteus RISCV To CHERI Morello Arm
This document contains information related to converting CHERI Proteus RISCV assembly to CHERI Morello Arm assembly for CHERI-TrEE.

## Proteus to Morello register mapping

**Important:** CHERI proteus is designed with two register files so that the integer registers and capability registers are separate, whereas in Morello there is only one register file and the capability registers are extended integer registers. THEREFORE WE NEED TO BE CAREFUL ABOUT MAPPING OF REGISTERS FROM RISCV TO MORELLO SO THAT REGISTERS USED LATER IN THE CODE ARE NOT OVERWRITTEN BEFORE THEY ARE USED. CANNOT DO DIRECT MAPPING, ONLY SENSIBLE MAPPING!!

**Note:**  In RISCV the saved registers s0 to s11 are preserved across function calls, while the argument registers a0 to a7 and the temporary registers t0 to t6 are not. 

**Register mapping:**
This mapping is based on both the Integer and Capability register tables below, and the fact that Morello has a single register file.

| Proteus register | Morello Register | Description |
|----------------|------------------|-------------|
| ct0            | c9               | temp reg    |
| ct1            | c10              | temp reg    |
| ct2            | c11              | temp reg    |
| ct3            | c12              | temp reg    |
| ct4            | c4               | temp reg    |
| ct5            | c5               | temp reg    |
|----------------|------------------|-------------|
| t0             | x13              | temp reg    |
| t1             | x14              | temp reg    |
| t2             | x15              | temp reg    |
| t3             | x6               | temp reg    |
| t4             | x3               | temp reg    |
|----------------|------------------|-------------|
| a7             | x7               | argument    |
| ca0            | c0               | argument    |
| ca1            | c1               | argument    |
|----------------|------------------|-------------|
| cra            | c30              | return addr |
| c31            | c29              | CInvoke/BRS data cap    |
| cs0            | c19              | saved reg    |




**Integer Register Table**

| Proteus Register | Proteus assembly name (ABI) | Proteus Description         | Proteus Saver | Arm Morello v8a Register / assembly name | ARM Morello v8a Description       |
| -------------- | ------------------------- | ------------------------- | ----------- | ---------------------------------|-------------------------- |
|   x0           |        zero               |  hardwired zero           |      -      |         XZR / WZR                | zero register             |             
|   x1           |         ra                |  return address           |   Caller (calls other funcs)   |         x30                      | return address            | 
|   x2           |         sp                |  stack pointer            |   Callee (called by another func)   |         sp                       | dedicated stack pointer   |
|   x3           |         gp                |  global pointer           |      -      |                                  |                           |
|   x4           |         tp                |  thread pointer           |      -      |                                  |                           |
|   x5-7         |       t0-t2               |  temporary registers      |   Caller    |        x9-x11                    | temporary Registers       |
|   x8           |       s0/fp               | saved reg / frame ptr     |   Callee    |         x29                      | frame ptr                 |
|   x9           |       s1                  | saved reg                 |   Callee    |         x19                      | saved reg (save stack first, then restore before returning from func. |
|   x10-11       |       a0-1                | func args / return values |   Caller    |  x0-x1(64bit)/w0-w1(32bit)       | func args / return values |
|   x12-17       |       a2-7                | func args                 |   Caller    |  x2-x7(64bit)/w2-w7(32bit)       | func args                 |
|     -          |        -                  |        -                  |             |  x8 (XR)                         | indirect result register, i.e pointer to memory for struct | 
|   x18-27       |       s2-11               | saved reg                 |   Callee    |  x20-x28                         | saved reg (save stack first, then restore before returning from func. |
|   x28-31       |       t3-6                | temporary reg             |   Caller    |  x12-x15                         | temporary Registers       |
|                |                           |                           |    -        |                                  |                           |
|                |       pc                  | program counter           |    -        |       pc                         |  program counter          |


**Capability register Table**
| Proteus Register | Proteus assembly name (ABI) | Proteus Description         | Proteus Saver | Morello Register / assembly name | Morello capability Description       |
| -------------- | ------------------------- | ------------------------- | ----------- | ---------------------------------| -------------------------- |
|   c0           |         zero              |  hardwired zero           |      -      |      CZR                         | zero register             | 
|   c1           |         cra               |  return address           |   Caller    |      c30                         | return address            | 
|   c2           |         csp               |  stack pointer            |   Callee    |      csp                         | dedicated stack pointer   |
|   c3           |         cgp               |  global pointer           |      -      |                                  | |
|   c4           |         ctp               |  thread pointer           |      -      |                                  | |
|   c5-7         |       ct0-ct2             |  temporary registers      |   Caller    |     c9-c11                       | temporary Registers       |
|   c8           |       cs0/cfp             | saved reg / frame ptr     |   Callee    |        c29                       | frame ptr                 |
|   c9           |        cs1                | saved reg                 |   Callee    |        c19                       | saved reg (save stack first, then restore before returning from func. |
|   c10-11       |        ca0-1              | func args / return values |   Caller    |    c0-c1(64bit)/w0-w1(32bit)                               | func args / return values |
|   c12-17       |      ca2-7                | func args                 |   Caller    |    c2-c7(64bit)/w0-w1(32bit)     | func args                 |
|     -          |        -                  |        -                  |             |     c8 (XR)                      | indirect result register, i.e pointer to memory for struct |
|   c18-27       |       cs2-11              | saved reg                 |   Callee    |    c20-c28                       | saved reg (save stack first, then restore before returning from func. |
|   c28-30       |       ct3-ct5             | temporary reg             |   Caller    |    c12-c15                       | temporary Registers       |
|   c31          |       ct6/c31             | temp reg / data capability|             |     c29                          | set equal to capability register cs2 (data capability) and unsealed during CInvoke (RISCV) / BRS (Morello) |
|                |                           |                           |             |                                  |                           |
|                |        pcc                | program counter           |     -       |       PCC                        | program counter          |


 ## CHERI Proteus to Morello ARM instruction mapping


| Proteus instruction        | Morello (ARM) instruction (sometimes two instructions needed) | Proteus Instruction Meaning                                                                                                                             |
|--------------------------|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| bne  (bne x1, x2, label) | CMP x1, x2 (compare x1 to x2, or use SUBS XZR, x1, x2) B.NE label (branch if x1-x2!=0)                          | Branch If Not Equal - source register 1, is compared with source register 2, if not equal, jump to label.         |
| beqz  (beqz x1, label)    |  CMP x1, XZR (compare x1 to zero) B.EQ label (branch if x1=0)                       | Branch if Equal to Zero - jumps to label if register value equal to zero.                             |
| beq  (beq x1, x2, label)  | CMP x1, x2 (compare x1 to x2) B.EQ label (branch if x1-x2=0)                          | Branch If Equal - source register 1 is compared with source register 2, if equal, control is transferred to label.                  |
| bge (bge x1, x2, label)  | CMP x1, x2 (compare x1 to x2) B.PL label (branch if x1-x2=+ve or 0)                          | Branch If Greater Than or Equal (signed) - source register 1 is compared with source register 2, if x1 >= x2 jump to label.|
| blt (blt x1, x2, label)  | CMP x1, x2 (compare x1 to x2) B.MI label (branch if x1-x2=-ve )                          | Branch If Less Than - source register 1 is compared with source register 2. If x1 is less than x2, jump to label.   |
| j (j label)               | B label                                    | Jump - uses Jump and Link (JAL) instead and sets the destination register to zero to discard return address.                        |
| jr (jr x1)               | BR x1                          | Jump Register -uses Jump and Link Register (JALR) which jumps and places the return address in a general purpose register.          |
| li (li x1,100)           | MOV x1, #100                  | Load Immediate - loads a register with an immediate value                                                                           |
| la (la x5, label)        | LDR x1, =label                | Load Address - loads the location address of the specified SYMBOL                                                                   |
| sub (sub x1, x2, x3)     | SUB x1, x2, x3                | subtracts contents of one register from another  x1=x2-x3                                                                           |
| add (add x1, x2, x3)     | ADD x1, x2, x3                | adds the contents of two registers and stores the result in another register  x1=x2+x3                                              |
| addi (addi x1, x2, 2)    | ADD x1, x2, #2                |  add immediate value  x1=x2+2                                                                                                       |
| slli (slli x1, x1, 3)    | LSL x1, x1, #3                | Shift Logical Left - shift left on the value in register by the shift immediate value.                                              |

**Capabilities**
| Proteus instruction | Morello (ARM) instruction | Proteus Meaning |
|-------------------|---------------------------|---------|
|   CSpecialR (CSpecialR ct2, pcc)     | ADR c2, #0 (get PCC)  or  MRS c1, DDC (get DDC) | Get special register capabilities.        |
|   lw.cap  (lw.cap x5, 40(x6))        | LDR w5, [x6,#40] (word in armv8a is 32 bit) |   Load word - moves a word, 32-bit signed value, from memory to register. with offset.     |
|   lc.cap  (lc.cap csp, (ct1))        | LDR csp, [c10]                          | Load capability.       |
|   sc.cap (sc.cap ca0, (csp)) |  STR c2, [csp]  | Store capability.        |
|   sw.cap  (sw x1, 0(x5)) | STR w2, [csp,#0] (word in armv8a is 32 bit) | Store Word - stores 32-bit signed value from a register to memory. with offset.       |
|   CGetLen  (CGetLen t0, c31) | GCLEN x9, c15  | Get bound length of capability.  |
|   CGetTag (CGetTag t0, csp) | GCTAG x9, csp | Get tag of capability.        |
|   CGetBase (CGetBase t0, ct2) | GCBASE x9, c2 | Get bound base of capability.        |
|   CSetAddr (CSetAddr cra, ct0, t0) | SCVALUE c30, c9, x13 | Set capability address for cra, based on ct0 properties and actual address in x13. |
|   CSetOffset (CSetOffset ct1, ct1, t1)      | SCOFF c1, c1, x2 (no immediate, reg only)   |  Set offset of capability.       |
|   CSetBoundsExact (CSetBoundsExact csp, csp, t2) | SCBNDSE CSP,CSP,C11 | Set exact bounds length |
|   CSetBoundsImm (CSetBoundsImm ct3, ct3, 32)   | MOV X2, #32 (Immediate to reg first) SCBNDSE c3, c3, x2 (no immediate, reg only)                         | Set exact bounds length with immediate. |
|   CIncOffsetImm (CIncOffsetImm csp, csp, -CAP_LEN)  |   GCOFF x3, csp (get current offset) ADD x3, x3, #-CAP_LEN (add offset)	SCOFF csp, csp, x3 (set offset)| Increment offset by an immediate amount.        |
|   CAndPerm (CAndPerm ct3, ct3, t0 (this does an AND mask so needs to invert)       | MOV x2, #(1 << PERM_PERMIT_STORE) (Morello does a clear of the bit selected so doesn't need the invert) 	CLRPERM c1, c1, x2 (reduce permissions and clear load)                          | Remove a permission from the capability.   |
|   CClearTag ( CClearTag ct0, ct0)  | CLRTAG C9, C9| Clear tag bit.        |
|   CJALR (CJALR c0, ct2)         | BLR c1 (calls a subroutine at an address in c1, setting C30 to PCC+4) | Jump (and Link) Capability Register. used for subroutine calls. |
|   CInvoke (CInvoke cs1, cs2)        | BRS c29, c2, c3 (must include C29)  | Branch to sealed capability pair. cs1 providing the target domain’s code and cs2 providing the target domain’s data. The capabilities must have a matching otype to ensure the right data is provided for the given jump target. c31 in RISCV is set equal to capability register cs2 (data capability) and unsealed during CInvoke. In Morello BRS branches to an address in the first Capability register and writes the second Capability register to C29.       |
|   CUnseal (CUnseal ct2, ca0, ct2) |  UNSEAL c2, c0, c2                         | Unseal a capability.        |
|   CSeal (CSeal ct2, ca0, ct2) | CSEAL c2, c0, c2                          | Seal a capability.        |
|   CMove (CMove ca1, ca0)          |     MOV c2, c1                      |  Copy one capability register to another.       |
| **New instruction: EstoreId** (called in capatest.c (enclave_store_id)) |  **New sw function: ESTORE_ID** in ESTORE_ID.c  |         |
| **New instruction: EInitData** (called in capatest.c (enclave_init))         | **New sw function: EINIT_DATA** in EINIT_DATA.c |         |
| **New instruction: EInitCode** (called in capatest.c (enclave_init))         | **New sw function: EINIT_CODE**  in EINIT_CODE.c  |      |
