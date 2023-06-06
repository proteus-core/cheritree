/*
 ============================================================================
 Name        : exceptionHandlerFuncsEL2N.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL2N hypervisor exception handler functions
 	 	 	   Contains a SYNC exception handler for when
 	 	 	   the hypervisor disables EL1N from modifying
 	 	 	   MMU registers
 ============================================================================
 */

//*************************************************
// DEFINES
//*************************************************
// define attributes for non secure memory sections
// this is used by the linker script to place non secure program code into non secure memory
// attributes can be assigned to functions and global variables
#define HANDLER_FUNC  __attribute__((__section__(".NONSECUREhandlerFuncSectionEL2_c_el2")))

#define ILLEGAL_EL1NMMU_ACCESS (0x60000000) //exception ID for an MSR MRS exception [0110 0000 0000...]
#define HVC_CALL (0x58000000) //bits 31 to 26 [0101 1000]	HVC instruction execution in AArch64 state, when HVC is not disabled.)


//*************************************************
// INCLUDES
//*************************************************
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false

// Program defined headers
#include <uartEL2N.h> 						// uart non secure functions
#include <exceptionHandlerFuncsEL2N.h>
#include <common/cheri_extra.h>
#include <common/capfuncs.h> //for debug printing
#include <EL2Code/instructions/hash.h>

// performance measurements
#include <common/performance.h>

// READ REG functions
extern uint32_t readESREL2(void);	//regForEL2N
//instruction funcs
extern int reg_sweep(void* code_cap, void* data_cap, void* cspReg); //regsweep.c
extern int mem_sweep(void* code_cap, void* data_cap, void* EL1mem_cap); //regsweep.c
extern void sweep(void* code_cap, void* data_cap, void* cspReg, void* EL1mem_cap); //regsweep.c
extern void* EINIT_CODE(void* code_cap); //EINIT_CODE.c
extern void* EINIT_DATA(void* sealed_code_cap, void* data_cap, void* cspReg); //EINIT_DATA.c
extern bool ESTORE_ID(size_t any_otype, hashValType* memHash_cap);

extern void* MEM_EL1N_AT_EL2N; //capability to EL1 memory

//************************************
// FUNCTIONS
//************************************
//------------------------------------
// syncHandlerEL2N
//------------------------------------
// SYNC exception handler for EL2,
// This is called by the vector table
// checks for the MSR MRS exception if EL1 tries to modify the MMU/memory translation registers
void* HANDLER_FUNC syncHandlerEL2N(void* code_cap, void* data_cap, void* cspReg)
{
	uint32_t esr;     //esr register - exception register
	uint32_t esr_ec;  //ESR.EC[31:26] type of exception
	uint32_t esr_hvc; //hvc exception ID

	//create a flag for the wait loop - to stop program
	volatile uint32_t flag = 1;
	// performance measurements
	unsigned long int startval, endval, numcycles;
	void* sealed_code_cap;
	void* sealed_data_cap;
	bool estore_result;

	// memory message strings
	char mesgReadText[8] = { 'S', 'Y', 'N', 'C', ' ', '\0'};
	char mesgReadText2[8] = { ' ', 'M', 'M', 'U', ' ', '\0'};
	char mesgReadText4[8] = { 'R', 'E', 'G', '\n', '\0'};
	char mesgReadText3[8] = { ' ', '?', '?', '?', '\n', '\0'};
	//hvc
	char mesgReadText5[8] = { ' ', 'H', 'V', 'C', ' ', '\0'}; 		 //HVC call
	char mesgReadText6[8] = { 'C', 'o', 'd', 'e', '\n', '\0'};  	 //EInitCode
	char mesgReadText7[8] = { 'D', 'a', 't', 'a', '\n', '\0'};		 //EinitData
	char mesgReadText8[8] = { 'S', 't', 'o', 'r', 'e', '\n', '\0'};	 //EStoreID
	char mesgReadText9[8] = { 'S', 'W', 'P', 'r', 'e', 'g', '\0'};  //sweep reg only
	char mesgReadText10[8] = { 'S', 'W', 'P', 'm', 'e', 'm', '\0'}; //sweep mem only
	char mesgReadText11[8] = { 'S', 'W', 'E', 'E', 'P', ' ', '\0'}; //sweep all
	char mesgReadText12[8] = { ' ', 'D', 'O', 'N', 'E', '\n', '\0'}; //done

	//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
	#ifdef	__CHERI_PURE_CAPABILITY__
     #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
	  uartEL2NcapTransmitString(mesgReadText);
	  uartEL2NcapTransmitString("(EL2): ");
     #endif
    #else
	  uartEL2NTransmitString(mesgReadText);
	  uartEL2NTransmitString("(EL2): ");
    #endif

	// read exception information
	esr = readESREL2();  //regForEL2N.s
	// mask bits 31:26 ESR.EC to check type of SYNC exception
	//       [1111][1100]00 0000
	esr_ec = esr & 0xFC000000;

	// mask lower 16 bits to get HVC ID
	esr_hvc = esr & 0xFFFF; // mask off lower 16 bits

    // Check what type of SYNC exception it is
	switch (esr_ec)
	{
		// Check if its an MSR MRS exception - EL1 trying to mess with mmu registers
		case ILLEGAL_EL1NMMU_ACCESS:
           #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
			// send message to uart
			//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
			#ifdef	__CHERI_PURE_CAPABILITY__
			  uartEL2NcapTransmitString(mesgReadText2);
			  uartEL2NcapTransmitString(mesgReadText4);
			#else
			  uartEL2NTransmitString(mesgReadText2);
			  uartEL2NTransmitString(mesgReadText4);
			#endif
           #endif
			while(flag==1){} // loop here and stop program
			break;


		// Check if its a HVC exception for processing special instructions
		case HVC_CALL:
			#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
			//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
			#ifdef	__CHERI_PURE_CAPABILITY__
			  uartEL2NcapTransmitString(mesgReadText5);
			#else
			  uartEL2NTransmitString(mesgReadText5);
			#endif
            #endif
			// Check what type of HVC exception it is
				switch (esr_hvc)
					{
						//New instructions
					    //-------------------------------------
						case HVC_EINITCODE:

							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
                              #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText6);
							  #else
                              #endif
							  //For BENCHMARK testing t1-----------
                              #if defined(BENCHMARK2)
							     enable_cycle_counter();
							  #endif
							  //--------------------------------------
							  sealed_code_cap = EINIT_CODE(code_cap);
							    //For BENCHMARK testing t1-----------
                                 #if defined(BENCHMARK2)
							        disable_cycle_counter();
								 #endif
							    //-----------------------------------
							  #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText12);
							  #endif
							  //------------------------------------
							  return sealed_code_cap;
							#else
							  uartEL2NTransmitString(mesgReadText6);
							#endif
							break;
						case HVC_EINITDATA:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
							//----------------------------------------
                              #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText7);
                              #endif
							  //---------------------------------------
							  //the code_cap input in this case, is the sealed code_cap
							  //For BENCHMARK testing t2-----------
                              #if defined(BENCHMARK2)
							    enable_cycle_counter();
							  #endif
							  sealed_data_cap = EINIT_DATA(code_cap, data_cap, cspReg);
							  //For BENCHMARK testing t2-----------
							  #if defined(BENCHMARK2)
							  	disable_cycle_counter();
							  #endif
							  //--------------------------
                              #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText12);
                              #endif
							  return sealed_data_cap;
							#else
							  uartEL2NTransmitString(mesgReadText7);
							#endif
							break;
						case HVC_ESTOREID:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
                              #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText8);
                              #endif
							  //code_cap arg is any_otype, just need the value don't care about the tag being cleared on a typecast
							  //data_cap arg is hashValType* memHashCap, which is already a capability
							  //For BENCHMARK testing t3-----------
                              #if defined(BENCHMARK2)
							    enable_cycle_counter();
							  #endif
							    //--------------------------------------
							  estore_result = ESTORE_ID((size_t)code_cap, data_cap);
							  //For BENCHMARK testing t3-----------
							  #if defined(BENCHMARK2)
							  	disable_cycle_counter();
							  #endif
							  #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
							  uartEL2NcapTransmitString(mesgReadText12);
							  #endif
							  return (void*)(estore_result);//don't need a valid tag, just the result
							#else
							  uartEL2NTransmitString(mesgReadText8);
							#endif
							break;
						//-----------------------------------------
						//part instructions for testing
						// sweep registers only
						case HVC_REGSWEEP:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
							  uartEL2NcapTransmitString(mesgReadText9);
							  int resultreg = reg_sweep(code_cap, data_cap, cspReg);
							  uartEL2NcapTransmitString(mesgReadText12);
							  return code_cap;
							#else
							  uartEL2NTransmitString(mesgReadText9);
							#endif
							break;
						// sweep memory only
						case HVC_MEMSWEEP:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
							  uartEL2NcapTransmitString(mesgReadText10);
							  int resultmem = mem_sweep(code_cap, data_cap, MEM_EL1N_AT_EL2N);
							  uartEL2NcapTransmitString(mesgReadText12);
							  return code_cap;
							#else
							  uartEL2NTransmitString(mesgReadText10);
							#endif
							break;
						// sweep registers and memory
						case HVC_SWEEP:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
							  uartEL2NcapTransmitString(mesgReadText11);
							  sweep(code_cap, data_cap, cspReg, MEM_EL1N_AT_EL2N);
							  uartEL2NcapTransmitString(mesgReadText12);
							  return code_cap;
							#else
							  uartEL2NTransmitString(mesgReadText11);
							#endif
							break;
						//-----------------------------------------
						default:
							//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
							#ifdef	__CHERI_PURE_CAPABILITY__
							uartEL2NcapTransmitString(mesgReadText3);
							#else
							  uartEL2NTransmitString(mesgReadText3);
							#endif
							break;
					}
				break;


		default:
		//NEEDS FIXING SO DON'T NEED TO DO CHECK AT THIS LEVEL
		#ifdef	__CHERI_PURE_CAPABILITY__
		  uartEL2NcapTransmitString(mesgReadText3);
		#else
		  uartEL2NTransmitString(mesgReadText3);
		#endif
		  while(flag==1){} // loop here and stop program
		break;
	}

return (void*)(-1); //invalid
}
