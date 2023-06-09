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

#ifdef __CHERI__
#define SETPTR scvalue
#define GETPTR gcvalue
#define READSYS mrs
#define WRITESYS msr
#endif

#define PCC_PERMS_EXCLUDE ( __CHERI_CAP_PERMISSION_PERMIT_STORE__ | \
                   __CHERI_CAP_PERMISSION_PERMIT_STORE_CAPABILITY__ )

	.text
	.align 2
_init_vectors:
        /* Installs a table of exception vectors to catch and handle all
           exceptions by terminating the process with a diagnostic.  */
#if defined(__CHERI_PURE_CAPABILITY__)
	adr	c0, vectors
        GETPTR  x0, c0
#else
	adr	x0, vectors
#endif
    //MODIFIED***comment out for EL2
	//msr	vbar_el3, x0
	msr	vbar_el2, x0
	msr	vbar_el1, x0

#if defined(__CHERI__)
#if defined(__CHERI_PURE_CAPABILITY__)
	adr	c1, vectors
	GETPTR	x1, c1
#else
	adr	x1, vectors
#endif
	READSYS c0, DDC
	SETPTR	c0, c0, x1
	mov    x1, #0
        orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE__
        orr    x1, x1, __CHERI_CAP_PERMISSION_PERMIT_STORE_CAPABILITY__
	clrperm  c0, c0, x1 /* clear the storecap, storelocalcap  */
    //MODIFIED***comment out for EL2
	//WRITESYS	cvbar_el3, c0
	WRITESYS	cvbar_el2, c0
	WRITESYS	cvbar_el1, c0
#endif
	ret

curr_sp0_sync:
curr_sp0_irq:
curr_sp0_fiq:
curr_sp0_serror:
curr_spx_sync:
curr_spx_irq:
curr_spx_fiq:
curr_spx_serror:
lower_a64_sync:
lower_a64_irq:
lower_a64_fiq:
lower_a64_serror:
lower_a32_sync:
lower_a32_irq:
lower_a32_fiq:
lower_a32_serror:
#if defined(__ARM_FEATURE_C64)
        bx #4
#endif
	mov	x0, 2
#if defined(__ARM_FEATURE_C64)
	adr	c1, .LC3
#else
	adr	x1, .LC3
#endif
	mov	x2, 26
	bl	FUNCTION (write)

	mov	x0,  126
	b	FUNCTION (exit)		/* Cannot return.  */
.LC3:
	.string "Terminated by exception.\n"

	.macro	ventry	label
	.align	7
	b	\label
	.endm

	/* AArch64 Exception Model -- 3.5.5 Exception Vectors.  */

	.align	12
vectors:
	/* Current EL with SP0.  */
	ventry	curr_sp0_sync		/* Synchronous  */
	ventry	curr_sp0_irq		/* Irq/vIRQ  */
	ventry	curr_sp0_fiq		/* Fiq/vFIQ  */
	ventry	curr_sp0_serror		/* SError/VSError  */

	/* Current EL with SPx.  */
	ventry	curr_spx_sync		/* Synchronous  */
	ventry	curr_spx_irq		/* IRQ/vIRQ  */
	ventry	curr_spx_fiq		/* FIQ/vFIQ  */
	ventry	curr_spx_serror		/* SError/VSError  */

	/* Lower EL using AArch64.  */
	ventry	lower_a64_sync		/* Synchronous  */
	ventry	lower_a64_irq		/* IRQ/vIRQ  */
	ventry	lower_a64_fiq		/* FIQ/vFIQ  */
	ventry	lower_a64_serror	/* SError/VSError  */

	/* Lower EL using AArch32.  */
	ventry	lower_a32_sync		/* Synchronous  */
	ventry	lower_a32_irq		/* IRQ/vIRQ  */
	ventry	lower_a32_fiq		/* FIQ/vFIQ  */
	ventry	lower_a32_serror	/* SError/VSError  */

	.text
	.align 2
_flat_map:
	/* Page table setup (identity mapping).  */
#if defined(__ARM_FEATURE_C64)
	adrp	c0, ttb
	add	c0, c0, :lo12:ttb
        GETPTR  x0, c0
#else
	adrp	x0, ttb
	add	x0, x0, :lo12:ttb
#endif
    //MODIFIED***change for EL2
	msr	ttbr0_el2, x0
#if defined(__ARM_FEATURE_C64)
	adr	c1, .
	GETPTR	x1, c1				/* phys address */
#else
	adr	x1, .				/* phys address */
#endif
	bic	x1, x1, #(1 << 30) - 1		/* 1GB block alignment */
	add	x2, x0, x1, lsr #(30 - 3)	/* offset in level 1 page
						   table */
#if defined(__CHERI_PURE_CAPABILITY__)
        READSYS c4, DDC
        SETPTR c2, c4, x2
#endif
	mov	x3, #0x401			/* page table attributes
						   (AF, block) */
#if defined(__CHERI__)
	bic	x1, x1, #(1 << 59)		/* clear CDBM */
	orr	x1, x1, #(1 << 60)		/* set LC */
	orr	x1, x1, #(1 << 61)		/* set SC[0] */
	bic	x1, x1, #(1 << 62)		/* clear SC[1] */
#endif
	orr	x1, x1, x3
	mov	x3, #(1 << 30)			/* 1GB block */
#if defined(__CHERI_PURE_CAPABILITY__)
	str	x1, [c2]			/* 1st GB */
        add     c2, c2, #8
	add	x1, x1, x3
	stur	x1, [c2, #0]			/* 2nd GB */
#else
	str	x1, [x2], #8			/* 1st GB */
	add	x1, x1, x3
	stur	x1, [x2, #0]			/* 2nd GB */
#endif

	/* Setup/enable the MMU.  */

	/* RES1, RES1, 40-bit PA, 39-bit VA, inner/outer cacheable WB */
        ldr     x0, =(1 << 31) | (1 << 28) | (1 << 27) | (1 << 26) | (1 << 25) | (1 << 24) | (1 << 23) | (2 << 16) | 25 | (3 << 10) | (3 << 8)
	//MODIFIED***change to EL2
	msr	tcr_el2, x0

	mov	x0, #0xee			/* Inner/outer cacheable WB */
	//MODIFIED***change to EL2
	msr	mair_el2, x0
	isb

    //MODIFIED***change to EL2
	mrs	x0, sctlr_el2
	ldr	x1, =0x100d			/* bits I(12) SA(3) C(2) M(0) */
	bic	x0, x0, #(1 << 1)		/* clear bit A(1) */
	bic	x0, x0, #(1 << 19)		/* clear WXN */
	orr	x0, x0, x1			/* set bits */

	dsb	sy
	//MODIFIED***change to EL2
	msr	sctlr_el2, x0
	isb
	ret

	.data
	.align	12
ttb:
	.space	4096, 0


	.text
	.align 2
	.global	FUNCTION (_cpu_init_hook)
	.type	FUNCTION (_cpu_init_hook), %function
FUNCTION (_cpu_init_hook):
#if defined(__CHERI_PURE_CAPABILITY__)
        mov c24, c30
#elif defined(__CHERI__)
	str	c30, [sp, #-32]!
#else
	str	x30, [sp, #-16]!
#endif
	bl	_init_vectors
	bl	_flat_map
#if defined(__CHERI_PURE_CAPABILITY__)
        mov c30, c24
#elif defined(__CHERI__)
	ldr	c30, [sp], #32
#else
	ldr	x30, [sp], #16
#endif
	ret
	.size	FUNCTION (_cpu_init_hook), .-FUNCTION (_cpu_init_hook)
