/*
 ============================================================================
 Name        : EL3entry.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL3 main c code
 	 	 	   This example sets up the mmu, and uart and performs an ERET
			   to EL2
 ============================================================================
 */

#include <EL3Code/uartS.h>
#include <stdio.h>
#include <stdlib.h>

#include <common/capfuncs.h>//contains option to turn debug on and off

//*****************************************
// DEFINES
//*****************************************
#define LOCATE_FUNC  __attribute__((__section__(".SECUREsection_c_el3")))

//Functions to include
extern void ERETtoEL2N(void);
extern void el3mmu(void);

// these two funcs should be run in boot code
extern void el3DDCset(void);
extern void setGLOBAL_UART_CAP(void);

extern void* GLOBAL_UART_CAP;


//Main program code of secure EL3
int LOCATE_FUNC main(void)
{
	// uart strings
	char uartstr[8] = {'E', 'L', '3', ' ', '\n', '\0'};

	#ifdef __CHERI_PURE_CAPABILITY__
		//GLOBAL CAPABILITY SET UP FROM BOOT CODE
		//-------------------------------------------------
		//This would be in boot code before DDC is NULLED
		el3DDCset(); //set ddc //this would be in boot code so not needed
		setGLOBAL_UART_CAP(); //this would go in boot code
		//-------------------------------------------------
	#endif

		//MMU - set up translation tables to use DRAM0, and device memory
		//-------------------------------------------------
		//This would be in boot code before DDC is NULLED for capability mode
		//-------------------------------------------------
		DG(puts("default mmu setup in EL3");)
		//el3mmu change translation tables so can access device memory where uart space is
		el3mmu();
		DG(puts("new mmu setup in EL3");)

		// start of main code
		#ifdef	__CHERI_PURE_CAPABILITY__
			// capability uart
			// set up the memory mapped uart pl011 standard setup defined by
			// global capability GLOBAL_UART_CAP
			uartScapSetup(GLOBAL_UART_CAP);
			// write a string to the capability uart
			//uartScapTransmitString("hello world to capability UART at EL3");
			uartScapTransmitString(uartstr);
		#else
			//non capability uart
			//set up the memory mapped uart pl011 standard setup at 0x1C090000
			uartSSetup((void*)(0x1C090000));
			// write a string to the standard uart
			uartSTransmitString(uartstr);
		#endif


	// Perform an ERET to EL2 hypervisor (non secure)
	ERETtoEL2N();

	// Never get here
	while(1);
	return EXIT_SUCCESS;
}
