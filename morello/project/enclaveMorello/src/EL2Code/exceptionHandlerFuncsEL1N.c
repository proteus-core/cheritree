/*
 ============================================================================
 Name        : exceptionHandlerFuncsEL1N.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL1N hypervisor exception handler functions
 	 	 	   Contains a SYNC exception handler for when
 	 	 	   the hypervisor disables EL1N from modifying
 	 	 	   a read only memory location
 ============================================================================
 */

//*************************************************
// DEFINES
//*************************************************
// define attributes for non secure memory sections
// this is used by the linker script to place non secure program code into non secure memory
// attributes can be assigned to functions and global variables
#define HANDLER_FUNC  __attribute__((__section__(".NONSECUREhandlerFuncSectionEL1_c_el2")))

#define ILLEGAL_EL1NMMU_ACCESS (0x60000000) //exception ID for an MSR MRS exception [0110 0000 0000...]
#define ILLEGAL_EL1N_DATA_ABORT (0x94000000) //exception ID for a data abort exception [1001 0100 0000...]
#define ILLEGAL_EL1N_DATA_ABORT_MEM (0x40) //exception ID for a data abort exception writing to a memory location [0[1]00 0000]
#define ILLEGAL_EL1N_DATA_ABORT_PERM (0x0D) //exception ID for a data abort exception permission fault  [00[00 1101]]

//*************************************************
// INCLUDES
//*************************************************
#include <stdio.h>
#include <stdlib.h>

// Program defined headers
#include <uartN_redirect.h> 						// uart non secure functions
//#include "uartEL2N.h" //use EL2 uart funcs as located in EL2 memory
#include <exceptionHandlerFuncsEL1N.h>

// READ REG functions
extern uint32_t readESREL1N(void);	//regForEL1N


//************************************
// FUNCTIONS
//************************************
//------------------------------------
// syncHandlerEL1N
//------------------------------------
// SYNC exception handler for EL2,
// This is called by the vector table
// checks for the MSR MRS exception if EL1 tries to modify the MMU/memory translation registers
void HANDLER_FUNC syncHandlerEL1N(void)
{
	uint32_t esr;     //esr register - exception register
	uint32_t esr_ec;  //ESR.EC[31:26] type of exception
	uint32_t esr_wnr;  //ESR.WnR[6] type of exception
	uint32_t esr_dfsc;  //ESR.EC[5:0] type of exception

	//create a flag for the wait loop - to stop program
	volatile uint32_t flag = 1;

	// memory message strings
	char mesgReadText[8] = { 'S', 'Y', 'N', 'C', ' ', '\0'};
	char mesgReadText2[8] = { ' ', 'A', 'B', 'O', 'R', 'T', '\0'};
	char mesgReadText4[8] = { ' ', 'M', 'E', 'M', ' ', '\0'};
	char mesgReadText5[8] = { 'P', 'E', 'R', 'M', '\n', '\0'};
	char mesgReadText3[8] = { ' ', '?', '?', '?', '\n', '\0'};


    //NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
	#ifdef	__CHERI_PURE_CAPABILITY__
	  uartNcapTransmitString(mesgReadText);
	  uartNcapTransmitString("(EL1): ");
    #else
	  uartNTransmitString(mesgReadText);
	  uartNTransmitString("(EL1): ");
    #endif

	// read exception information

	esr = readESREL1N();  //regForEL1N.s
	// mask bits 31:26 ESR.EC to check type of SYNC exception
	//       [1111][1100]00 0000
	esr_ec = esr & 0xFC000000;

	// mask bits 6 ESR.WnR to check write to memory problem
	//       0000 0[1]00 0000
	esr_wnr = esr & 0x40;

	// mask bits 5:0 ESR.DFSC to check permission fault
	//       00[11 1111]
	esr_dfsc = esr & 0x3F;

    // Check what type of SYNC exception it is
	switch (esr_ec)
	{
		// Check if its a  data abort
		case ILLEGAL_EL1N_DATA_ABORT:
		// send message to uart
		//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
		#ifdef	__CHERI_PURE_CAPABILITY__
	      uartNcapTransmitString(mesgReadText2);
        #else
		  uartNTransmitString(mesgReadText2);
        #endif
		switch (esr_wnr)
		{
		// then check if its due to writing to a memory location
		case ILLEGAL_EL1N_DATA_ABORT_MEM:
			//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
			#ifdef	__CHERI_PURE_CAPABILITY__
			  uartNcapTransmitString(mesgReadText4);
			#else
			  uartNTransmitString(mesgReadText4);
			#endif
			switch (esr_dfsc)
			{
			// then check if its because of a permission fault
			case ILLEGAL_EL1N_DATA_ABORT_PERM:
				//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
				#ifdef	__CHERI_PURE_CAPABILITY__
				  uartNcapTransmitString(mesgReadText5);
				#else
				  uartNTransmitString(mesgReadText5);
				#endif
				break;
			default:
				//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
				#ifdef	__CHERI_PURE_CAPABILITY__
				  uartNcapTransmitString(mesgReadText3);
				#else
				  uartNTransmitString(mesgReadText3);
				#endif
				break;
			}
			break;
		default:
			//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
			#ifdef	__CHERI_PURE_CAPABILITY__
			  uartNcapTransmitString(mesgReadText3);
			#else
			  uartNTransmitString(mesgReadText3);
			#endif
			break;
		}
		break;

		default:
		// send message to uart
		//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
		#ifdef	__CHERI_PURE_CAPABILITY__
		  uartNcapTransmitString(mesgReadText3);
		#else
		  uartNTransmitString(mesgReadText3);
		#endif
		break;
	}


	// loop here and stop program
	while(flag==1){}
	return;
}
