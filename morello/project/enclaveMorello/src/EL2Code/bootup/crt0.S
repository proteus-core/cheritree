/*MODIFIED SCRIPT FOR EL2*/
 //****************************************************************************
 // SECTION AND DEFINES
 //****************************************************************************
 // need to put into non secure memory region by linker script
 .section .NONSECUREel2entrysection_ass_el2, "ax"

/* Copyright (c) 2009, 2010, 2011, 2012 ARM Ltd.  All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. The name of the company may not be used to endorse or promote
    products derived from this software without specific prior written
    permission.

 THIS SOFTWARE IS PROVIDED BY ARM LTD ``AS IS'' AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL ARM LTD BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

 //Modified by CAP-TEE 2021

#include "newlib.h"
#include "svc.h"


/* ANSI concatenation macros.  */
#define CONCAT(a, b) CONCAT2(a, b)
#define CONCAT2(a, b) a ## b

#ifdef __USER_LABEL_PREFIX__
#define FUNCTION( name ) CONCAT (__USER_LABEL_PREFIX__, name)
#else
#error __USER_LABEL_PREFIX is not defined
#endif

#ifdef HAVE_INITFINI_ARRAY
#define _init	__libc_init_array
#define _fini	__libc_fini_array
#endif

/* In ELF64, the large addressing model is used and R_AARCH64_ABS64
   reloc is generated to relocate a 64-bit address.  Since 64-bit
   relocation is not available in ELF32, in order to have
   a single code path for both ELF64 and ELF32 classes, we synthesize
   a 64-bit relocation by using R_AARCH64_P32_ABS32 on one of the two
   .word directives, depending on the endianness.  */

.macro GEN_DWORD name
#if defined(__ILP32__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	.word \name
	.word 0
#elif defined(__ILP32__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	.word 0
	.word \name
#else
	.dword \name
#endif
.endm

#ifdef __CHERI__
#define SETPTR scvalue
#define GETPTR gcvalue
#define READSYS mrs
#define WRITESYS msr
#endif

/* Help tackle the pointer size difference between ELF64 and ELF32.  */
#ifdef __ILP32__
#define PTR_REG(n)	w##n
#define PTR_SIZE	4
#define PTR_LOG_SIZE	2
#elif __CHERI_PURE_CAPABILITY__
#define PTR_REG(n)  c##n
#define PTR_SIZE    16
#define PTR_LOG_SIZE    4
#else
#define PTR_REG(n)	x##n
#define PTR_SIZE	8
#define PTR_LOG_SIZE	3
#endif

#define PCC_PERMS_EXCLUDE ( __CHERI_CAP_PERMISSION_PERMIT_STORE__ | \
                   __CHERI_CAP_PERMISSION_PERMIT_STORE_CAPABILITY__ )

	.text
.macro FUNC_START name
	.global \name
\name:
.endm

	.align	2

#if defined(__CHERI__)
.arch armv8-a+a64c
#endif
	FUNC_START	_mainCRTStartup
	FUNC_START	_start
        .type  _start,@function

/* Start by setting up a stack */

	/*  Issue Angel SVC to read memory info.

	    ptr to ptr to 4 words to receive data.  */
	NOP //MODIFIED***added so I know this is my program and not default
	adr	x1, .LC0
	//MODIFIED*** SEMIHOSTING
	//if semihosting do this
	#ifndef NO_SEMIHOSTING
	mov	w0, #AngelSVC_Reason_HeapInfo
	AngelSVCAsm AngelSVC
	#endif

#if defined(__CHERI__)
    /* Enable capabilities. */
    mrs    x0, CPACR_EL1
    orr    x0, x0, #(3 << 18) /* set CEN */
    msr    CPACR_EL1, x0
    //MODIFIED***comment out for EL2
    //BUILD WITH ENABLE_MORELLO_CAP=1 to ensure this is set at EL3
    //mrs    x0, CPTR_EL3
    //orr    x0, x0, #(1 << 9) /* set EC */
    //msr    CPTR_EL3, x0
    //MODIFIED***changed
    //dont set, as we don't want Morello instructions to be trapped
    mrs    x0, CPTR_EL2
    mov    x1, #0xFDFF
    movk   x1, #0xFFFF, LSL #16
    and    x0, x0, x1 /* clear TC */
    msr    CPTR_EL2, x0
    //***
    mrs    x0, SCTLR_EL1
    bic    x0, x0, #(1 << 20) /* clear CD0 */
    bic    x0, x0, #(1 << 22) /* clear CD */
    msr    SCTLR_EL1, x0
    mrs    x0, SCTLR_EL2
    bic    x0, x0, #(1 << 20) /* clear CD0 */
    bic    x0, x0, #(1 << 22) /* clear CD */
    msr    SCTLR_EL2, x0
    //MODIFIED***comment out for EL2
    //mrs    x0, SCTLR_EL3
    //bic    x0, x0, #(1 << 20) /* clear CD0 */
    //bic    x0, x0, #(1 << 22) /* clear CD */
    //msr    SCTLR_EL3, x0

    //ISB NEEDED TO FLUSH CACHE AND STOP CPU HANG IN WIFI B
    isb

	//MODIFIED***modify for EL2
    /* Use c28 as the adrdp base, no DDC/PCC offsetting and seal CLR */
    mov    x0, #(1 << 4) | (1 << 7)
    msr    CCTLR_EL2, x0

    //ISB NEEDED TO FLUSH CACHE AND STOP CPU HANG IN WIFI B
    isb

#endif
    //MODIFIED***comment out for EL2
    //mrs    x0, CPTR_EL3
    //bic    x0, x0, #(1 << 10) /* clear TFP */
    //msr    CPTR_EL3, x0

#ifdef __ARM_FEATURE_C64
    /* Switch to C64 mode. */
    READSYS     c1, DDC    /* Default data capability */
    adr x0, .pure+1
    SETPTR c0, c1, x0
    mov    x1, #0
    orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE__
    orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE_CAPABILITY__
    clrperm c0, c0, x1
    br c0
.pure:
.arch armv8-a+c64
#endif

#ifdef __CHERI_PURE_CAPABILITY__
    /* create a capability to represent the heap. This will be used as part
       of sbrk() which supports malloc(). Note this 'heap' covers most of
       memory*/
    ldr     x0, .LC0
    READSYS     c4, DDC
    SETPTR  c0, c4, x0

    /* Clear the execute permission bit*/
    mov x2, __CHERI_CAP_PERMISSION_PERMIT_EXECUTE__
    clrperm c1, c4, x2

    ldr     x2, [c0, #0]        /* heap base */
    SETPTR  c1, c1, x2
    ldr     x3, [c0, #8]    /* heap limit */
    sub     x3, x3, x2
    scbndse c1, c1, x3
    ldr     x2, .Lend
    SETPTR  c1, c1, x2      /* set the heap pointer just past the image */
    ldr     x2, .Lheapcap
    SETPTR  c2, c4, x2
    /* Save capabilities to avoid storing to device memory now */
    mov     c27, c1
    mov     c28, c2

     //MODIFIED*** SEMIHOSTING
    /* and another capability to represent the stack */
    /* Clear the execute permission bit*/
    mov x2, __CHERI_CAP_PERMISSION_PERMIT_EXECUTE__
    clrperm c1, c4, x2

   #ifndef NO_SEMIHOSTING
   //do this if semihosting on
	//----------------------------------------
    ldr     x2, [c0, #24]   /* stack limit */
    SETPTR  c1, c1, x2
    ldr     x3, [c0, #16]   /* stack base */
    sub     x3, x3, x2      /* stack grows down from base */
    scbndse c1, c1, x3
    add     c1, c1, x3      /* put the stack pointer at the base */
    ldr     x2, .Lstackcap
    SETPTR  c2, c4, x2
    /* Save capabilities to avoid storing to device memory now */
    mov     c25, c2
    mov     c26, c1
	//----------------------------------------
	#else
	//do this if semihosting turned off
   	//----------------------------------------
    ldr     x2, =_stack_el2n_limit   /* stack limit */
    SETPTR  c1, c1, x2
    ldr     x3, =_stack_el2n_base   /* stack base */
    sub     x3, x3, x2      /* stack grows down from base */
    scbndse c1, c1, x3
    add     c1, c1, x3      /* put the stack pointer at the base */
    ldr     x2, .Lstackcap
    SETPTR  c2, c4, x2
    /* Save capabilities to avoid storing to device memory now */
    mov     c25, c2
    mov     c26, c1
    //-----------------------------------------
   #endif

    /* Setup an initial dummy frame with saved cfp=0 and saved clr=0 */
    mov     csp, c1
    mov     x29, #0         /* c29 <- nullptr */
    str     c29, [csp, #-16]!
    str     c29, [csp, #-16]!
    mov     c29, csp

    mov     c0, c1
    mov     csp, c0

    /* Initialize exception vector table, flatmap, etc.  */
    bl      FUNCTION (_cpu_init_hook)

    str     c26, [c25, #0]   /* stack capability */
    str     c27, [c28, #0]   /* heap capability */

    READSYS c1, DDC
    clrperm c1, c1, wx
    adrp c0, __unwinding_cap
    add c0, c0, :lo12:__unwinding_cap
    str c1, [x0]

    /* Zero the memory in the .bss section.  */
    ldr     x0, .LC1        /* First arg: start of memory block */
    mov     w1, #0          /* Second arg: fill value */
    ldr     x2, .LC2
    sub     x2, x2, x0      /* Third arg: length of block */
    READSYS     c3, DDC         /* first arg needs to be a capability */
    SETPTR  c0, c3, x0
    bl      FUNCTION (memset)

    /* Initialize global capabilities. */
    bl FUNCTION(__init_global_caps)

    /* Tighten the PCC */
    adrp c0, pcc_tighten
    add c0, c0, :lo12:pcc_tighten
    ldr c0, [c0]
    br c0
.tightened:
    /* Add a dummy .size in order to silence a linker warning.
       The capability for .tightened will have the same size
       as any executable capabilities created by the linker. */
    .size  .tightened, 1

    /* Need to set up standard file handles */
    //MODIFIED*** SEMIHOSTING
    #ifndef NO_SEMIHOSTING
    //semihosting on
    bl      FUNCTION (initialise_monitor_handles)
    #else
    //semihosting off
    //don't do
    #endif

    /* .init and .fini sections are used to create constructors
       and destructors.  Here we call the _init function and arrange
       for _fini to be called at program exit.  */
    ldr     x1, .Lfini
1:
    /* convert to a PCC based capability */
    READSYS     c0, DDC
    SETPTR  c0, c0, x1
    mov    x1, #0
    orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE__
    orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE_CAPABILITY__
    clrperm  c0, c0, x1 /* clear the storecap, storelocalcap  */

    READSYS     c24, DDC
#ifdef __ARM_FEATURE_C64
    /* A64 code generation for uses integer pointers when accessing
       things like the GOT. We therefore can't (yet) set the DDC to zero
       for it. */
    //MODIFIED*** keep DDC for now
    //WRITESYS     DDC, czr
#endif

    bl      FUNCTION (atexit)
    bl      FUNCTION (_init)

#ifdef __CHERI_PURE_CAPABILITY__
    READSYS     c1, DDC
    /* Clear the execute permission bit */
    gcperm x2, c1
    mov x2, __CHERI_CAP_PERMISSION_PERMIT_EXECUTE__
    //MODIFIED*** keep execute bit, otherwise exception on EL1 entry, perms fault
    //clrperm c1, c1, x2
    WRITESYS    DDC, c1
#endif

#else
    /* Initialise the stack pointer */

    /* We currently choose to use the heap_limit field rather than
       stack_base because the AEM validation model
       returns sane values in the heap fields, but 0 in the stack
       fields.  Note on the VE AEM model it is necessary to pass
       command line options to the AEM in order to define the values
       exposed here in the HeapInfo Angel call.  */
        //MODIFIED*** SEMIHOSTING
    #ifndef NO_SEMIHOSTING
    //semihosting on
    ldr x0, .LC0        /* point at returned values */
    ldur x1, [x0, #8]        /* get heap_limit */
    #else
    //semihosting off
    LDR x1, =_stack_el2n_limit
    #endif
#ifdef __ILP32__
    /* Sanity check on the heap base.  */
    ldr x0, [x0]        /* get heap_base */
    tst x0, #0xffffffff00000000
    beq 1f
    /* Exit with 1 if the heap base is not within the 32-bit address
       space.  */
    mov x0, ADP_Stopped_ApplicationExit & 0xff
    movk    x0, ADP_Stopped_ApplicationExit >> 16, lsl #16
    adrp    x1, HeapBase    /* Reuse to construct the parameter block.  */
    add x1, x1, #:lo12:HeapBase
    str x0, [x1]
    mov x0, 1
    str x0, [x1, #8]
    //MODIFIED*** SEMIHOSTING
    #ifndef NO_SEMIHOSTING
    //semihosting on
    mov w0, #AngelSVC_Reason_ReportException
    AngelSVCAsm AngelSVC
    #endif
1:
    /* For the sake of safety, set the stack base to the top end of
       the 32-bit address space if the returned value from the
       Angel API call is larger than or equal to 4 GiB.  */
    tst x1, #0xffffffff00000000
    csinv   w1, w1, wzr, eq
#endif

	/* Ensure quad-word stack alignment.  */
	and	x0, x1, #~15
	mov	sp, x0

	/* Setup an initial dummy frame with saved fp=0 and saved lr=0 */
#ifdef __CHERI__
	mov	x30, #0
	mov	x29, #0
#ifndef __ARM_FEATURE_C64
	stp	c29, c30, [sp, #-32]!
#else
    str c30, [sp, #-16]!
    str c29, [sp, #-16]!
#endif

#else
	mov	x29, 0
	stp	x29, x29, [sp, #-16]!
#endif
	mov	x29, sp

/* Initialize exception vector table, flatmap, etc.  */
    bl      FUNCTION (_cpu_init_hook)

    /* Zero the memory in the .bss section.  */
    ldr x0, .LC1        /* First arg: start of memory block */
    mov w1, #0          /* Second arg: fill value */
    ldr x2, .LC2
    sub x2, x2, x0      /* Third arg: length of block */
    bl  FUNCTION (memset)

#if defined(__CHERI__)
    bl FUNCTION(__init_global_caps)
#endif

    /* Need to set up standard file handles */
    //MODIFIED*** SEMIHOSTING
    #ifndef NO_SEMIHOSTING
    //semihosting on
    bl  FUNCTION (initialise_monitor_handles)
	#endif

    /* .init and .fini sections are used to create constructors
       and destructors.  Here we call the _init function and arrange
       for _fini to be called at program exit.  */
    ldr x0, .Lfini
    bl  FUNCTION (atexit)

    bl  FUNCTION (_init)
#endif

	/* Fetch and parse the command line.  */
#if defined(__CHERI_PURE_CAPABILITY__)
        adr     c1, .Lcmdline
#else
	adr	x1, .Lcmdline		/* Command line descriptor.  */
#endif

    //MODIFIED*** SEMIHOSTING
     #ifndef NO_SEMIHOSTING
    //semihosting on
	mov	w0, #AngelSVC_Reason_GetCmdLine
	AngelSVCAsm AngelSVC
	#endif

#ifdef __CHERI_PURE_CAPABILITY__
    // This should really be done in C
	ldr	x26, .Lcmdline
	SETPTR  c26, c24, x26

	mov	x0, #0	    /* argc */
	mov	c1, csp	    /* argv */
	ldr     x2, .Lenvp  /* envp */
	SETPTR  c2, c25, x2

	/* Put NULL at end of argv array.  */
	str	czr, [c1, #-PTR_SIZE]!

	/* Skip leading blanks.  */
.Lnext: ldrb	w3, [c26], #1
	cbz	w3, .Lendstr
	cmp	w3, #' '
	b.eq	.Lnext

	mov	w4, #' '	/* Terminator is space.  */

	/* See whether we are scanning a quoted string by checking for
	   opening quote (" or ').  */
	subs	w9, w3, #'\"'
	sub	c26, c26, #1	/* Backup if no match.  */
	ccmp	w9, #('\'' - '\"'), 0x4 /* FLG_Z */, ne
	csel	w4, w3, w4, eq	/* Terminator = quote if match.  */
	bne     1f
	add     c26, c26, #1
1:

	/* Push arg pointer to argv, and bump argc.  */
	str	PTR_REG (26), [c1, #-PTR_SIZE]!
	add	x0, x0, #1

	/* Find end of arg string.  */
1:	ldrb	w3, [c26], #1
	cbz	w3, .Lendstr
	cmp	w4, w3		/* Reached terminator?  */
	b.ne	1b

	/* Terminate the arg string with NUL char.  */
	mov	w4, #0
	sturb	w4, [c26, #-1]
	b	.Lnext

	/* Reverse argv array.  */
.Lendstr:
	add	c3, c1, #0			/* sp = &argv[0] */
	add	c4, c1, w0, uxtw #PTR_LOG_SIZE	/* ep = &argv[argc] */
	cmp	c4, c3
	b.lo	2f
1:
	ldr	PTR_REG (5), [c4, #-PTR_SIZE]	/* PTR_REG (5) = ep[-1] */
	ldr	PTR_REG (24), [c3, #0]		/* PTR_REG (6) = *sp */
	str	PTR_REG (24), [c4, #-PTR_SIZE]!	/* *--ep = PTR_REG (6) */
	str	PTR_REG (5), [c3], #PTR_SIZE	/* *sp++ = PTR_REG (5) */
	cmp	c4, c3
	b.hi	1b
2:
	/* Move sp to the 16B boundary below argv.  */

	GETPTR   x4, c1
	and     x4, x4, ~15
	SETPTR  c4, c1, x4
	mov	csp, c4

#else /* !__CHERI_PURE_CAPABILITY__ */
    ldr x26, .Lcmdline

    mov x0, #0      /* argc */
    mov x1, sp      /* argv */
    ldr x2, .Lenvp  /* envp */

    /* Put NULL at end of argv array.  */
    str PTR_REG (0), [x1, #-PTR_SIZE]!

    /* Skip leading blanks.  */
.Lnext: ldrb    w3, [x26], #1
    cbz w3, .Lendstr
    cmp w3, #' '
    b.eq    .Lnext

    mov w4, #' '    /* Terminator is space.  */

    /* See whether we are scanning a quoted string by checking for
       opening quote (" or ').  */
    subs    w9, w3, #'\"'
    sub x26, x26, #1  /* Backup if no match.  */
    ccmp    w9, #('\'' - '\"'), 0x4 /* FLG_Z */, ne
    csel    w4, w3, w4, eq  /* Terminator = quote if match.  */
    cinc    x26, x26, eq

    /* Push arg pointer to argv, and bump argc.  */
    str PTR_REG (26), [x1, #-PTR_SIZE]!
    add x0, x0, #1

    /* Find end of arg string.  */
1:  ldrb    w3, [x26], #1
    cbz w3, .Lendstr
    cmp w4, w3      /* Reached terminator?  */
    b.ne    1b

    /* Terminate the arg string with NUL char.  */
    mov w4, #0
    sturb    w4, [x26, #-1]
    b   .Lnext

    /* Reverse argv array.  */
.Lendstr:
    add x3, x1, #0          /* sp = &argv[0] */
    add x4, x1, w0, uxtw #PTR_LOG_SIZE  /* ep = &argv[argc] */
    cmp x4, x3
    b.lo    2f
1:  ldur PTR_REG (5), [x4, #-PTR_SIZE]   /* PTR_REG (5) = ep[-1] */
    ldur PTR_REG (24), [x3, #0]       /* PTR_REG (6) = *sp */
    str PTR_REG (24), [x4, #-PTR_SIZE]!  /* *--ep = PTR_REG (6) */
    str PTR_REG (5), [x3], #PTR_SIZE    /* *sp++ = PTR_REG (5) */
    cmp x4, x3
    b.hi    1b
2:
    /* Move sp to the 16B boundary below argv.  */
    and x4, x1, ~15
    mov sp, x4
#endif
//MODIFIED*** go to start of EL2 own setup
//bl	FUNCTION (main)
//to keep in c64mode +1 to addr
	bl	FUNCTION (EL2N_hypervisor_entry+1)


	b	FUNCTION (exit)		/* Cannot return.  */
.Lfunc_end0:
        .size  _start, .Lfunc_end0-_start

/* Function initializing exception vector table, flatmap, etc.
   Declared as weak symbol so that user can override this definition
   by linking in their own version of the function.  */
	.weak FUNCTION (_cpu_init_hook)
FUNCTION (_cpu_init_hook):
	ret

#if defined(__CHERI__)
    .weak __cap_relocs_start
    .weak __cap_relocs_end
FUNCTION (__init_global_caps):
    READSYS     c2, DDC    /* Default data capability */
#if !defined(__CHERI_PURE_CAPABILITY__)
    adrp    x0, __cap_relocs_start
    add     x0, x0, #:lo12:__cap_relocs_start
    adrp    x1, __cap_relocs_end
    add     x1, x1, #:lo12:__cap_relocs_end
#else
    adrp    c0, __cap_relocs_start
    add     c0, c0, #:lo12:__cap_relocs_start
    adrp    c1, __cap_relocs_end
    add     c1, c1, #:lo12:__cap_relocs_end
    GETPTR  x1, c1
    GETPTR  x0, c0
#endif
    cmp     x0, x1
    b.eq    .CapInitEnd
    sub     x5, x1, x0     /* __cap_relocs_size */
    SETPTR  c0, c2, x0
    SETPTR  c1, c2, x1
    /* Clear permissions that we're not going to want on global
       capabilities. */
    ldr x5, =(__ARM_CAP_PERMISSION_COMPARTMENT_ID__  |  \
              __ARM_CAP_PERMISSION_BRANCH_SEALED_PAIR__   |  \
              __CHERI_CAP_PERMISSION_PERMIT_UNSEAL__ |  \
              __CHERI_CAP_PERMISSION_PERMIT_SEAL__)
    clrperm c2, c2, x5
.CapInit:
#if defined(__ARM_FEATURE_C64)
    ldr     x5, [c0], #8    /* Capability location */
    ldr     x24, [c0], #8    /* Object refered by the capability */
#else
    ldr     x5, [c0]         /* Capability location */
    ldr     x24, [c0, #8]    /* Object refered by the capability */
    add c0, c0, 16
#endif
    cbnz    x24, .CapNonNull
    add     c0, c0, #24
    mov     x4, #0          /* c4 <- nullptr */
    b       .CapCont
.CapNonNull:
#if defined(__ARM_FEATURE_C64)
    ldr     x25, [c0], #8    /* Offset in the object */
    ldr     x26, [c0], #8    /* Size */
    ldr     x9, [c0], #8     /* Permissions */
#else
    ldr     x25, [c0]        /* Offset in the object */
    ldr     x26, [c0, #8]    /* Size */
    add     c0, c0, #24
    ldr     x9, [c0, #-8]
#endif
    /* Set the executive permission for executable capabilities */
    SETPTR  c4, c2, x24      /* Set capability base */
    scbndse c4, c4, x26      /* Set size */
    scoff   c4, c4, x25      /* Add offset */
    clrperm c4, c4, x9
    tbnz     x9, #15, .CapCont
    seal    c4, c4, rb       /* Seal executable capabilities */
.CapCont:
    str    c4, [x5, #0]
    cmp     c0, c1
    b.ne    .CapInit
.CapInitEnd:
    ret
#endif

#if defined(__CHERI_PURE_CAPABILITY__)
    .weak FUNCTION (__get_eh_frame_capability)
    .type  __get_eh_frame_capability,@function
FUNCTION (__get_eh_frame_capability):
    adrp c0, __unwinding_cap_ptr
    ldr c0, [c0, :lo12:__unwinding_cap_ptr]
    ldr c0, [c0]
    ret

    .weak FUNCTION (__get_eh_frame_hdr_capability)
    .type  __get_eh_frame_hdr_capability,@function
FUNCTION (__get_eh_frame_hdr_capability):
    adrp c0, __unwinding_cap_ptr
    ldr c0, [c0, :lo12:__unwinding_cap_ptr]
    ldr c0, [c0]
    ret
#endif

	.align 3
.LC0:
	GEN_DWORD HeapBase
.LC1:
	GEN_DWORD __bss_start__
.LC2:
	GEN_DWORD __bss_end__
#ifdef __CHERI_PURE_CAPABILITY__
.Lend:
    GEN_DWORD __end__
.Lheapcap:
    GEN_DWORD HeapCap
.Lstackcap:
    GEN_DWORD StackCap
#endif

#ifdef __ARM_FEATURE_C64
.Lfini:
	GEN_DWORD FUNCTION(_fini+1)
#else
.Lfini:
	GEN_DWORD FUNCTION(_fini)
#endif

.Lenvp:
	GEN_DWORD env
.Lcmdline:
	GEN_DWORD CommandLine
	.dword	255
#if defined(__CHERI_PURE_CAPABILITY__)
    .data.rel.ro
    .align 4
__unwinding_cap_ptr:
    .capinit __unwinding_cap
    .xword  0
    .xword  0
    .size   __unwinding_cap_ptr, 16
#endif

/*  Workspace for Angel calls.  */
	.data
	.align 3
/*  Data returned by monitor SVC.  */
#if defined(__ILP32__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	.set __stack_base__, StackBase + 4
#elif defined(__CHERI_PURE_CAPABILITY__)
    .set __stack_base__, StackCap
#else
	.set __stack_base__, StackBase
#endif
	.global	__stack_base__
HeapBase:	.dword	0
HeapLimit:	.dword	0
StackBase:	.dword	0
StackLimit:	.dword	0

#ifdef __CHERI_PURE_CAPABILITY__
pcc_tighten:
#ifdef __ARM_FEATURE_C64
    .capinit .tightened+1
#else
    .capinit .tightened
#endif
    .xword  0
    .xword  0
    .size   pcc_tighten, 16

#if defined(__CHERI_PURE_CAPABILITY__)
__unwinding_cap:
    .xword  0
    .xword  0
    .size   __unwinding_cap, 16
#endif

StackCap:   .dword  0
            .dword  0
    .global HeapCap
HeapCap:    .dword  0
            .dword  0
    .size   HeapCap, 16
#endif
	.global __dso_handle
	.weak   __dso_handle
__dso_handle:
	.dword	0
#ifdef __CHERI_PURE_CAPABILITY__
	.dword	0
#endif
#if defined(__CHERI_PURE_CAPABILITY__)
	.size   __dso_handle, 16
#else
	.size   __dso_handle, 8
#endif

env:		.dword	0	/* Dummy environment array */
CommandLine:	.space	256,0	/*  Maximum length of 255 chars handled.  */
