/*
 ============================================================================
 Name        : test_EL1Nentry.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL1 main non secure (normal world) code
               Some tests to test instructions and memory access from EL1

 	 	 	   el1nmain contains the main tests with the following selections:
 	 	 	   (Turn off semi-hosting and EL2 debug)

 	 	 	   tests == 1  check the HVC calls work and return, values are not set up correct and may return an error
 	 	 	   tests == 2  Run tests on memory modifications by EL1
 	 	 	   	   	run_memtests(1)function to change MAIR reg - try to change memory properties. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
					run_memtests(2)function to modify the translation table in memory using the register. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
					run_memtests(3)function to modify the translation table in memory knowing the address. This should fail if ddc is null, otherwise will cause exception to EL1, and in turn exception to EL2.
					run_memtests(4)function to modify VBAR_EL1 register, if test passes, whilst VBAR access is disabled, its because the nested virtualisation feature is not implemented.
					run_memtests(5)function to modify the vector table in memory knowing the address. This should fail if ddc is null, otherwise will cause exception to EL1, and in turn exception to EL2.
					run_memtests(6)function to change TCR reg - control reg. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
					run_memtests(7)function to change SCTLR reg - try to turn on or off mmu. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
			   tests == 3  Run tests on instructions
					testNumber = 1 - Test register sweep only
					testNumber = 2 - Test memory sweep only
					testNumber = 3 - Test memory and register sweep only
					testNumber = 4 - EInitCode tests

Assumptions: THIS PROJECT MUST BE COMPILED FOR PURECAP ONLY

 ============================================================================
 */

//*****************************************
// DEFINES
//*****************************************
//Need to put all non secure code into non secure memory regions
//Attributes are used to define memory sections.
//The linker script places the memory sections into the correct regions.
//Note: Attributes can only be assigned to global variables and functions
#define LOCATE_FUNC  __attribute__((__section__(".NONSECUREsection_c_el1")))
#define LOCATE_STR  __attribute__((__section__(".NONSECUREStringSection_c_el1")))


//*****************************************
// INCLUDES
//*****************************************

//cheri built-in includes
#include <cheriintrin.h>

// C Functions to include
//program cheri defines to include
#include <common/cheri_extra.h>
//debug printing
#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#endif
//output at EL1 to uart, some critical output is sent to the uart, even when debug switched off
#include <EL1Code/uartN_redirect.h> //non secure uart functions
//program C functions / enclave code to include
#include <EL1Code/enclavecode/unique_alloc.h>
#include <EL1Code/performance_EL1.h>
#include <EL1Code/enclavecode/capattest.h>

// Assembly functions to include
//extern void el1nmmu(void); //mmu set up
// function to change MAIR reg
extern void el1MAIRmod(void);
// function to modify the translation table in memory using register
extern void el1TTmod(void);
// function to modify the translation table in memory knowing the memory address
extern void el1TTMemMod(void);
// function to modify the vector table in memory using register
extern void el1VTmod(void);
// function to modify the vector table in memory knowing the memory address
extern void el1VTMemMod(void);
// function to change TCR reg
extern void el1TCRmod(void);
// function to change SCTLR reg
extern void el1SCTLRmod(void);

// extern capabilities
//capability covering uart space
extern void* GLOBAL_UART_CAP_EL1N;
//label signifying the end of the linker script, and is used to define the start of the enclave memory
extern uintptr_t __end__;

extern int LOCATE_FUNC test_EINIT_CODE(void** code_cap);
extern int LOCATE_FUNC test_EINIT_DATA(void** code_cap, void** data_cap);
extern int LOCATE_FUNC test_ESTORE_ID(void** code_cap, void** data_cap);

  static void LOCATE_FUNC init_capabilities()
  {
	  unsigned long int cap_len = 10240; //fixed size enclave memory, 10k
	  //we need the root capability to define a memory space after the linker script
	  void* root = cheri_ddc_get(); //ddc can't be nulled in boot code for this to work
	  //create unique memory space
	  //(uintptr_t) - we just want an address value, not a capability, hence the conversion
	  void* uniqueMem = cheri_address_set(root,(uintptr_t)&__end__);
	  uniqueMem = cheri_bounds_set_exact(uniqueMem, cap_len);

	  unique_alloc_init(&uniqueMem);//same as proteus set up

	  //now null the ddc as soon as possible
	  asm volatile("MSR	ddc, czr\n\t":::);
	  //clear caps
	  root = cheri_tag_clear(root);
	  uniqueMem = cheri_tag_clear(uniqueMem);
  }
  //llvm doesn't seem to place "inline" in function, need to specify "static inline", or need a copy of definition without inline?
  static inline void LOCATE_FUNC cheri_clear_all_gpcr()
  {
  #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)

	CLEAR_GPCR(c0); //need to do c0 in Morello, c0 hard wired to zero in riscv
	CLEAR_GPCR(c1);
      	CLEAR_GPCR(c2);
      	CLEAR_GPCR(c3);
      	CLEAR_GPCR(c4);
      	CLEAR_GPCR(c5);
      	CLEAR_GPCR(c6);
      	CLEAR_GPCR(c7);
      	CLEAR_GPCR(c8);
      	CLEAR_GPCR(c9);
      	CLEAR_GPCR(c10);
      	CLEAR_GPCR(c11);
      	CLEAR_GPCR(c12);
      	CLEAR_GPCR(c13);
      	CLEAR_GPCR(c14);
      	CLEAR_GPCR(c15);
      	CLEAR_GPCR(c16);
      	CLEAR_GPCR(c17);
      	CLEAR_GPCR(c18);
      	CLEAR_GPCR(c19);
      	CLEAR_GPCR(c20);
      	CLEAR_GPCR(c21);
      	CLEAR_GPCR(c22);
      	CLEAR_GPCR(c23);
      	CLEAR_GPCR(c24);
      	CLEAR_GPCR(c25);
      	CLEAR_GPCR(c26);
      	CLEAR_GPCR(c27);
      	CLEAR_GPCR(c28);
      	CLEAR_GPCR(c29);
     	// CLEAR_GPCR(c30); //this is the return address
      	//CLEAR_GPCR(c31); there is not a gp c31 in Morello

      #undef CLEAR_GPCR
  }

  int LOCATE_FUNC reg_sweep_test(void** code_cap, void** data_cap)
    {
  	  // clear tag bits of all capability registers
	  //WARNING!
	  //llvm doesn't seem to place "inline" in function
	   cheri_clear_all_gpcr();

	   //clear return address separately
       	  #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)
	   CLEAR_GPCR(c30);

  	  //--------------------------------------------------
  	  //Test register sweep only
  	  	asm volatile(
  	  			//-------------------------------------
  	  	    		// set up code capability
  	  	    		//-------------------------------------
  	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
  	  	    		// Load code capability into first func arg c0
  	  	    		// (set ca0 (c0) to the enclave's code section)
  	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
  	  			// Clear the given code capability
  	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
  	  			"STR xzr, [%x[code_cap_in]]\n\t"

  	  			//-------------------------------------
  	  			// set up data capability
  	  			//-------------------------------------
  	  			// Set ca1 (c1) to the enclave's data section
  	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
  	  			"LDR c1, [%x[data_cap_in]]\n\t"
  	  			// Clear the data capability on the stack
  	  			//"SC cnull, (%[data_cap_in])\n\t"//(riscv)
  	  			"STR xzr, [%x[data_cap_in]]\n\t"

  	  			//-------------------------------------
  	  			//NEW INSTRUCTION TO GO HERE
  	  			//-------------------------------------
  	  			"HVC #%[hvc_call_regsweep]\n\t"

  	  			:[code_cap_in]"+r"	(code_cap),			/* this is &code_cap (address, so use load instruction) */
  	  			 [data_cap_in]"+r"	(data_cap)			/* this is &data_cap (address, so use load instruction) */
  	  			:[hvc_call_regsweep]"I" (HVC_REGSWEEP) /*, (I - means immediate value)*/
  	  			:
  	  			);
    return 0;
    }

    int LOCATE_FUNC mem_sweep_test(void** code_cap, void** data_cap)
      {
  	   cheri_clear_all_gpcr();

         #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)
  	   CLEAR_GPCR(c30);

    	  //--------------------------------------------------
    	  //Test mem sweep only
    	  	asm volatile(
    	  			//-------------------------------------
    	  	    		// set up code capability
    	  	    		//-------------------------------------
    	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
    	  	    		// Load code capability into first func arg c0
    	  	    		// (set ca0 (c0) to the enclave's code section)
    	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
    	  			// Clear the given code capability
    	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
    	  			"STR xzr, [%x[code_cap_in]]\n\t"

    	  			//-------------------------------------
    	  			// set up data capability
    	  			//-------------------------------------
    	  			// Set ca1 (c1) to the enclave's data section
    	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
    	  			"LDR c1, [%x[data_cap_in]]\n\t"
    	  			// Clear the data capability on the stack
    	  			//"SC cnull, (%[data_cap_in])\n\t"//(riscv)
    	  			"STR xzr, [%x[data_cap_in]]\n\t"

    	  			//-------------------------------------
    	  			//NEW INSTRUCTION TO GO HERE
    	  			//-------------------------------------
    	  			"HVC #%[hvc_call_memsweep]\n\t"

    	  			:[code_cap_in]"+r"	(code_cap),			/* this is &code_cap (address, so use load instruction) */
    	  			 [data_cap_in]"+r"	(data_cap)			/* this is &data_cap (address, so use load instruction) */
    	  			:[hvc_call_memsweep]"I" (HVC_MEMSWEEP) /*, (I - means immediate value)*/
    	  			:
    	  			);

      return 0;
      }


      int LOCATE_FUNC sweep_test(void** code_cap, void** data_cap)
        {
    	   cheri_clear_all_gpcr();

           #define CLEAR_GPCR(gpcr) asm volatile("CLRTAG " #gpcr ", " #gpcr)
    	   CLEAR_GPCR(c30);

      	  //--------------------------------------------------
      	  //Test register and mem sweep
      	  	asm volatile(
      	  			//-------------------------------------
      	  	    		// set up code capability
      	  	    		//-------------------------------------
      	  	        	//"LC ca0, (%[code_cap_in])\n\t"//(riscv)
      	  	    		// Load code capability into first func arg c0
      	  	    		// (set ca0 (c0) to the enclave's code section)
      	  			"LDR c0, [%x[code_cap_in]]\n\t" /*put code cap in c0 */
      	  			// Clear the given code capability
      	  			//"SC cnull, (%[code_cap_in])\n\t"//(riscv)
      	  			"STR xzr, [%x[code_cap_in]]\n\t"

      	  			//-------------------------------------
      	  			// set up data capability
      	  			//-------------------------------------
      	  			// Set ca1 (c1) to the enclave's data section
      	  			//"LC ca1, (%[data_cap_in])\n\t"//(riscv)
      	  			"LDR c1, [%x[data_cap_in]]\n\t"
      	  			// Clear the data capability on the stack
      	  			//"SC cnull, (%[data_cap_in])\n\t"//(riscv)
      	  			"STR xzr, [%x[data_cap_in]]\n\t"

      	  			//-------------------------------------
      	  			//NEW INSTRUCTION TO GO HERE
      	  			//-------------------------------------
      	  			"HVC #%[hvc_call_sweep]\n\t"

      	  			:[code_cap_in]"+r"	(code_cap),			/* this is &code_cap (address, so use load instruction) */
      	  			 [data_cap_in]"+r"	(data_cap)			/* this is &data_cap (address, so use load instruction) */
      	  			:[hvc_call_sweep]"I" (HVC_SWEEP) /*, (I - means immediate value)*/
      	  			:
      	  			);

        return 0;
        }


  void LOCATE_FUNC run_tests(int testNumber,const size_t code_start, const size_t code_end, size_t data_length)
  {

	  //-------------------------------------------------------
	  //Load enclave setup to generate a valid dummy code_cap and data_cap to run tests
	  //-------------------------------------------------------
	  printf("load_enclave [0x%lx, 0x%lx)\n", code_start, code_end);

	  size_t code_len = code_end - code_start;

	  printf(".............................................\n");
	  printf("code_len in hex: 0x%lx\n", code_len);

	  void* code_cap;
	  void* data_cap;
	  unique_alloc(&code_cap, code_len);
	  unique_alloc(&data_cap, data_length);

	  printcapabilityPar_EL1(code_cap, "code_cap");

	  printcapabilityPar_EL1(data_cap,"data_cap");

	  //TESTS
	  //--------------------------------------------------
	  //1. Test register sweep only
	  //--------------------------------------------------
	  if (testNumber == 1)
	  {
		  reg_sweep_test(&code_cap, &data_cap);
	  }
	  //--------------------------------------------------
	  //2. Test memory sweep only
	  //--------------------------------------------------
	  if (testNumber == 2)
	  {
		  //measure length of time taken to do memory sweep
		  //set up cycle counter
		  unsigned long int startval, endval, numcycles;
		  setup_cycle_counterEL1and2_EL1();
		  enable_cycle_counter_EL1();
		  startval = read_cycle_counter_EL1();

		  mem_sweep_test(&code_cap, &data_cap);

		  //get time
		  endval = read_cycle_counter_EL1();
		  disable_cycle_counter_EL1();
		  numcycles = endval-startval;
		  printf("number of cycles : %lu\n", numcycles);
		  printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
		  printf("number of seconds (2000MHz processor) : %f\n", (((float)numcycles)/2000000000));
	  }

      //--------------------------------------------------
      //3. Test register and memory sweep together
      //--------------------------------------------------
	  if (testNumber == 3)
	  {
		  //measure length of time taken to do memory sweep
		  //set up cycle counter
		  unsigned long int startval, endval, numcycles;
		  setup_cycle_counterEL1and2_EL1();
		  enable_cycle_counter_EL1();
		  startval = read_cycle_counter_EL1();

		  sweep_test(&code_cap, &data_cap);

		  //get time
		  endval = read_cycle_counter_EL1();
		  disable_cycle_counter_EL1();
		  numcycles = endval-startval;
		  printf("number of cycles : %lu\n", numcycles);
		  printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
		  printf("number of seconds (2000MHz processor) : %f\n", (((float)numcycles)/2000000000));
	  }

      //--------------------------------------------------
      //4. Test EINIT_CODE instruction
      //--------------------------------------------------
	  if (testNumber == 4)
	  {
		  int result = test_EINIT_CODE(&code_cap);
	  }

      //--------------------------------------------------
      //5. Test EINIT_DATA instruction
      //--------------------------------------------------
      //Used for initial testing when overlap check fail did not fail instruction - test does not clear code/data caps off stack because of way do test - test should fail on an overlap check, TEST NOT UPDATED
      if (testNumber == 5)
	  {
    	  int result = test_EINIT_DATA(&code_cap, &data_cap);
	  }

      //--------------------------------------------------
      //6. Test ESTORE_ID instruction
      //--------------------------------------------------
      //Used for initial testing when overlap check fail did not fail instruction - test does not clear code/data caps off stack because of way do test - test should fail on an overlap check, TEST NOT UPDATED
      if (testNumber == 6)
	  {
    	  int result = test_ESTORE_ID(&code_cap, &data_cap);
	  }

  }

//memory tests
void  run_memtests(int testNumber)
{
    //------------------------------------------------------
	//MESS ABOUT WITH MEMORY - TESTING
	// Try to mess with the EL1 MMU memory registers
	// Try to write to page table memory locations
	char uartstr1[8] = {'T', 'E', 'S', 'T', ' ', '\0'};
	char uartstr2[8] = {'D', 'O', 'N', 'E', '\n', '\0'};

if (testNumber == 1)
{
	// Test1
	// function to change MAIR reg - try to change memory properties
	// this will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("1\n\0");
	el1MAIRmod();
	  uartNcapTransmitString(uartstr2);
}

if (testNumber == 2)
{
	//Test2
	// function to modify the translation table in memory using the register
	// Purecap: If access is not disabled in EL2, and in Morello-purecap, test only works if DDC_EL1 is not nulled in boot code
	// this will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("2\n\0");
	// Purecap: If access is not disabled in EL2, and in Morello-purecap, test only works if DDC_EL1 is not nulled in boot code
	el1TTmod();
	  uartNcapTransmitString(uartstr2); //only get here if not disabled
}
if (testNumber == 3)
{
	//Test3
	// function to modify the translation table in memory knowing the address.
	// This function will only complete if the memory region is set to read/write.
	// Otherwise this will cause a data abort on trying to write to a memory location (see ESR_EL1)
	// because the section of memory where the page tables are stored are set to read only to
	// prevent EL1N from writing to them.
	// The data abort synchronous exception goes to the EL1N vector table.
	// However the exception handler reads the ESR register, and if the EL1 registers
	// are disabled as well this will then be trapped to EL2 before the exception handler can
	// complete, causing exception handler code in EL2 to be run instead.
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("3\n\0");
	// Purecap: If access is not disabled in EL2, and in Morello-purecap, test only works if DDC_EL1 is not nulled in boot code
	el1TTMemMod();
	  uartNcapTransmitString(uartstr2); //only get here if not disabled
}
if (testNumber == 4)
{
	//Test4
	// try to modify VBAR_EL1 register
	// if this test passes, whilst VBAR access is disabled, its
	// because the nested virtualisation feature is not implemented.
	// Trying to set NV1 bit to 1 to create an exception for VBAR_EL1
	// doesn't cause a change in NV1 bit in the register, it stays at zero
	// This implies the nested virtualisation feature is not implemented.
	// We can therefore not prevent VBAR from being modified to point to a different memory location
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("4\n\0");
	el1VTmod();
	  uartNcapTransmitString(uartstr2); //gets here even if try to disable
}
if (testNumber == 5)
{
	//Test5
	// try to modify the vector table in memory
	// This function will only complete if the memory region is set to read/write.
	// Otherwise this will cause a data abort on trying to write to a memory location (see ESR_EL1)
	// because the section of memory where the vector table is stored is set to read only
	// to prevent EL1N from writing to them.
	// The data abort synchronous exception goes to the EL1N vector table.
	// However the exception handler reads the ESR register, and if the EL1 registers
	// are disabled as well this will then be trapped to EL2 before the exception handler can
	// complete, causing exception handler code in EL2 to be run instead.
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("5\n\0");
	// Purecap: If access is not disabled in EL2, and in Morello-purecap, test only works if DDC_EL1 is not nulled in boot code
	el1VTMemMod();
	  uartNcapTransmitString(uartstr2); //only get here if not disabled
}
if (testNumber == 6)
{
	//Test6
	// function to change TCR reg - control reg
	// this will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("6\n\0");
	el1TCRmod();
	  uartNcapTransmitString(uartstr2); //only get here if not disabled
}
if (testNumber == 7)
{
	//Test7
	// function to change SCTLR reg - try to turn on or off mmu
	// this will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
	  uartNcapTransmitString(uartstr1);
	  uartNcapTransmitString("7\n\0");
	el1SCTLRmod();
	  uartNcapTransmitString(uartstr2); //only get here if not disabled
}
    //------------------------------------------------------
}



//Main program code of non secure EL1
int LOCATE_FUNC el1nmain(void)
{

	// uart strings
	char uartstr[8] = {'E', 'L', '1', 'N', '\n', '\0'};
	char uartstr1[8] = {'T', 'E', 'S', 'T', ' ', '\0'};
	char uartstr2[8] = {'D', 'O', 'N', 'E', '\n', '\0'};
	// EL1N mmu already set up

	//---------------------------------------------------------------
	// set up the memory mapped uart
	//---------------------------------------------------------------
	// capability uart
	// set up the memory mapped uart pl011 standard setup defined by
	// global capability GLOBAL_UART_CAP
	uartNcapSetup(GLOBAL_UART_CAP_EL1N);
	// write a string to the capability uart
	uartNcapTransmitString(uartstr);

	//---------------------------------------------------------------
	//Set up Unique alloc memory space
	//---------------------------------------------------------------
	init_capabilities();

	//---------------------------------------------------------------
	//get code and data size
	//---------------------------------------------------------------
	//extern char sensor_code_start, sensor_code_end;
	//these are addresses defined in the linker script in proteus/riscv
	//just write something here for now to test
	size_t sensor_code_start = (size_t)0x80000100;
	size_t sensor_code_end = (size_t)0x80000110;

	//---------------------------------------------------------------
	//RUN SOME TESTS
	//---------------------------------------------------------------
	//Select which set of tests to run
	int tests = 3;
	//--------------------------------------------------
	//Basic HVC tests
	//--------------------------------------------------
	//Just check the HVC calls work and return, values are not set up / correct
	if (tests == 1)
		{
		//define HVC macro for new instruction calls
    		#define HVC_INSTRUCTION(iname) asm volatile("HVC #%[hvc_ass]\n\t" ::[hvc_ass]"I" (iname):) //(I - means immediate value)
		HVC_INSTRUCTION(HVC_EINITCODE); //EInitCode
		HVC_INSTRUCTION(HVC_EINITDATA); //EInitData
		HVC_INSTRUCTION(HVC_ESTOREID); //EIStoreID

		//or
		//asm volatile("HVC #1\n\t" :::); //EInitCode
		//asm volatile("HVC #2\n\t" :::); //EInitData
		//asm volatile("HVC #3\n\t" :::); //EIStoreID

		//or
		//asm volatile("HVC #%[hvc_code]\n\t" ::[hvc_code]"I" (HVC_EINITCODE):); //EInitCode, (I - means immediate value)
		//asm volatile("HVC #%[hvc_data]\n\t" ::[hvc_data]"I" (HVC_EINITDATA):); //EInitData, (I - means immediate value)
		//asm volatile("HVC #%[hvc_store]\n\t" ::[hvc_store]"I" (HVC_ESTOREID):); //EIStoreID, (I - means immediate value)
		}
	//--------------------------------------------------
	//Run tests on memory modifications by EL1
	//--------------------------------------------------
	if (tests == 2)
		{
		//(1)function to change MAIR reg - try to change memory properties. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
		//(2)function to modify the translation table in memory using the register. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
		//(3)function to modify the translation table in memory knowing the address. This should fail if ddc is null, otherwise will cause exception to EL1, and in turn exception to EL2.
		//(4)function to modify VBAR_EL1 register, if test passes, whilst VBAR access is disabled, its because the nested virtualisation feature is not implemented.
		//(5)function to modify the vector table in memory knowing the address. This should fail if ddc is null, otherwise will cause exception to EL1, and in turn exception to EL2.
		//(6)function to change TCR reg - control reg. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
		//(7)function to change SCTLR reg - try to turn on or off mmu. This will cause an MSR MRS exception in EL2 hypervisor if mmu register access is disabled in EL2
		run_memtests(7);
		}
	//--------------------------------------------------
	//Run tests on instructions
	//--------------------------------------------------
	if (tests == 3)
		{
			//(1)Test register sweep only
			//(2)Test memory sweep only
			//(3)Test memory and register sweep only
			//(4)EInitCode tests

			int testNumber = 4;
			run_tests(testNumber,sensor_code_start, sensor_code_end, 256);
		}

	printf("Done all tests\n");
	while(1);

	// We never get here
	return EXIT_SUCCESS;
}
