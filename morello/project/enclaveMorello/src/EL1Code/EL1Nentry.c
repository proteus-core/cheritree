/*
 ============================================================================
 Name        : EL1Nentry.c
   	   	   	 : Adapted to work on Morello by CAP-TEE 2021
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL1 main non secure (normal world) code

 	 	 	   This is the main code that initiates the creation of the enclaves.
 	 	 	   Output at EL1 is redirected to the UART via the embedded printf function.
 	 	 	   Extra debug can be switched on by modifying the EL1Debug.h file, specifically
 	 	 	   include the line "#define DEBUG_EL1 1". Debug is turned off by default.

 	 	 	   EL2 control:
 	 	 	   In this set up, the EL2 hypervisor controls EL1 memory and page tables.
 	 	 	   If EL1 tries to make changes to the memory set up, eg by an adversary,
 	 	 	   an exception will occur as follows:
 	 	 	   When the EL2 hypervisor disables EL1 from making changes to the mmu
 	 	 	   registers, an exception occurs which is routed to the EL2 vector table.
 	 	 	   When the EL2 hypervisor disables EL1 from making changes to the memory
 	 	 	   region where the page tables / vector table is stored, an exception
 	 	 	   occurs which is routed to the EL1 vector table. Because the exception
 	 	 	   handler tries to read ESR_EL1, this subsequently becomes trapped to EL2.


 Limitations : The c function library is initialised by the default compile/
 	 	 	   linker to reside in the lower section of DRAM0, which is set
 	 	 	   up as the secure memory location for EL3 in this setup.
 	 	 	   Currently EL2 also resides in the lower half of DRAM0 memory,
 	 	 	   so that EL1N mostly occupies upper DRAM0 memory, except for the page
 	 	 	   tables and vector tables which can be access read only if this is set.

 	 	 	   It appears that the nested virtualisation feature is not present in Morello
 	 	 	   meaning that there is no option to trap a VBAR_EL1 access from EL1 to EL2.
 	 	 	   This means that EL1 could change where the Vector Table register is
 	 	 	   pointing to in memory, and thus change the exception handlers when
 	 	 	   a write occurs to a read only memory location.

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
//standard includes - don't use these at EL1, use embedded printf
//#include <stdio.h>
//#include <stdlib.h>

//cheri built-in includes
#include <cheriintrin.h>

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

// extern capabilities
//capability covering uart space
extern void* GLOBAL_UART_CAP_EL1N;
//global capability pointing to the enclave code (both user & Sensor) in memory to be copied
//note this is not the run-time code, it is the code to be copied, ToDo set to read only
extern void* CODE_SECTION_CAP;
//label signifying the end of the linker script, and is used to define the start of the enclave memory
extern uintptr_t __end__;

//Define string as a global variable to give it an attribute
//can't do this!! as only stores the pointer in non secure memory,
//the string still gets stored in the secure .bss region!!!
//const char* uartStr LOCATE_STR = "hello world to uart at EL1N\n";
//ToDo ensure strings are in the el1 memory space

//*****************************************
// FUNCTIONS
//*****************************************
  //-------------------------------------------
  //init_capabilities:
  // Initialise capabilities that have not already
  // been set up in the boot code.
  // Null the DDC as soon as possible
  //-------------------------------------------
  static void LOCATE_FUNC init_capabilities()
  {

	  //bounds of pcc
	  //set in boot code already

	  //---------------------------------------------------------------
	  //Unique alloc - to initialise a unique memory space for the enclaves
	  //---------------------------------------------------------------
	  //we want the unique allocation for enclave memory to come after end of linker script
	  //to avoid rogue capability bounds from overlapping enclave memory
	  //e.g the extern char labels (sensor_code_start, sensor_code_end, user_code_start, user_code_end)
	  //are bounded to the end of the linker by the build tools
	  //this means we can't include the enclave memory in the linker script without causing an overlap
	  //instead the enclave memory must start from the end of the linker script.

	  //ENCLAVE MEMORY SIZE
	  //BENCHMARK -need bigger memory size for an internal benchmark loop
	  //include in preprocessor settings for assembler and compiler with -D
	  //BENCHMARK1 - measures from el1 only t4,t5,t6,t7,t10,t11
	  //BENCHMARK2 - measures operations for el2 that causes conflicts above in
	  //             starting and stopping the timer t1,t2,t3,t8,t9
	#if defined(BENCHMARK1) || defined(BENCHMARK2)
	  //bigger memory size to accommodate more enclaves being generated in a loop
	  unsigned long int cap_len = 66560; //falls over if bigger than 65k because of bounds compression, 65k
	#else
	  unsigned long int cap_len = 10240; //fixed size enclave memory same as proteus, 10k
	#endif
	  //we need the root capability to define a memory space after the linker script
	  void* root = cheri_ddc_get(); //ddc can't be nulled in boot code for this to work
	  //create unique memory space
	  //(uintptr_t) - we just want an address value, not a capability, hence the conversion
	  void* uniqueMem = cheri_address_set(root,(uintptr_t)&__end__);
	  uniqueMem = cheri_bounds_set_exact(uniqueMem, cap_len);
	  //if cheri_is_invalid(uniqueMem) {puts ("invalid uniqueMem!!!\n");}

	  unique_alloc_init(&uniqueMem);//same as proteus set up

	  //now null the ddc as soon as possible
	  asm volatile("MSR	ddc, czr\n\t":::);
	  //clear caps
	  root = cheri_tag_clear(root);
	  uniqueMem = cheri_tag_clear(uniqueMem);
  }

  //-------------------------------------------
  //print functions using printf for EL1N
  //-------------------------------------------

  void LOCATE_FUNC print_bytes(uint8_t* bytes, size_t len)
  {
      for (size_t i = 0; i < len; ++i)
          printf(" %02x", bytes[i]);
  }

  void LOCATE_FUNC print_cap(const void* cap)
  {
      printf("tag=%d, base=%08x, offset=%06x, len=%06x, perm=%03x, type=%03x",
             cheri_tag_get(cap),
             cheri_base_get(cap),
             cheri_offset_get(cap),
             cheri_length_get(cap),
             cheri_perms_get(cap),
             cheri_type_get(cap)
      );
  }

  void LOCATE_FUNC print_named_cap(const char* name, const void* cap)
  {
      printf("[%s] ", name);
      print_cap(cap);
  }

  void LOCATE_FUNC print_enclave(const struct enclave* enclave)
  {
      print_named_cap("code", &enclave->code_cap);
      printf("\n");
      print_named_cap("data", &enclave->data_cap);
      printf("\n");
      print_named_cap("enc ", &enclave->enc_seal);
      printf("\n");
      print_named_cap("sign", &enclave->sign_seal);
      printf("\n");
  }

  void LOCATE_FUNC print_enclave_content(const struct enclave* enclave)
  {
      print_named_cap("code", enclave->code_cap);
      printf("\n");
      print_named_cap("data", enclave->data_cap);
      printf("\n");
      print_named_cap("enc ", enclave->enc_seal);
      printf("\n");
      print_named_cap("sign", enclave->sign_seal);
      printf("\n");
  }

  //-------------------------------------------
  //copy_code:
  //copy code section given by source address value src, to destination pointed to by dst
  //rootEnclaveCode_cap is the root capability of the enclave code, defined in the boot up code for EL1
  //-------------------------------------------
  static void LOCATE_FUNC copy_code(void** dst, const void* src, size_t len, void* rootEnclaveCode_cap)
  {
	  //create source capability from the root enclave code capability
      void* src_cap;
      src_cap = cheri_address_set(rootEnclaveCode_cap, (uintptr_t)src);
      src_cap = cheri_bounds_set_exact(src_cap, len);

      //debug print
      DG1(disable_cycle_counter_EL1();)//stop counter for print output
      DG1(printcapabilityPar_EL1(rootEnclaveCode_cap, "rootEnclaveCode_cap");) //all enclave code to be copied
      DG1(printcapabilityPar_EL1(src_cap, "src_cap");) //source
      DG1(printcapabilityPar_EL1(*dst, "*dst");) //destination
	  DG1(enable_cycle_counter_EL1();)//stop counter for print output

      //---------------------------------------------------------------------------
      //Copy code section from source to destination
      //cheri_memcpy(dst, &src_cap, len); //proteus
      //cheri_memcpy(const capability* dst, const capability* src, size_t len) //proteus
      //printf("copying code section..........\n");
      // Check that we can copy the full buffer
        if(!(len % 4 == 0)) {printf("copy length size error!\n");}
        if(!(cheri_address_get(src_cap) % 4 == 0)) {printf("copy source size error!\n");}
        if(!(cheri_address_get(*dst) % 4 == 0)){printf("copy destination size error!\n");}

        asm volatile(
        		"LDR c0, [%x[dst_asm]]\n\t" //load to get the cap because we are passing address
        		"MOV c1, %x[src_asm]\n\t" //move because we have the cap already
        		"MOV x2, %x[len_asm]\n\t" //length
        		"loop: \n\t"
        		"CMP x2, XZR\n\t"// check length (compare x2 len to zero)
				"B.EQ exit\n\t" //(branch if x2=0)
        		"LDR w3, [c1]\n\t" //load contents from source 4bytes at a time (w register)
        		"STR w3, [c0]\n\t"//store contents to destination 4bytes at a time (w register)
        		//source -increment source by 4 bytes
        		"GCOFF x4, c1\n\t" //(get current offset)
				"ADD x4, x4, #4\n\t" //(add offset - 4 bytes)
				"SCOFF c1, c1, x4\n\t" //(set offset)
				//destination -increment dst by 4 bytes
        		"GCOFF x4, c0\n\t" //(get current offset)
				"ADD x4, x4, #4\n\t" //(add offset - 4 bytes)
				"SCOFF c0, c0, x4\n\t" //(set offset)
        		"SUB x2,x2,#4\n\t" //decrement length by 4 bytes
        		"B loop\n\t" //loop round until done
        		"exit:\n\t"
        		: [dst_asm] "+r"(dst)
        		: [src_asm] "r"(src_cap),
				  [len_asm] "r"(len)
				: "c0", "c1", "x2", "w3", "x4", "cc", "memory"
				);
        //------------------------------------------------------------------------------
  }

  //-------------------------------------------
  //load_enclave:
  //uniquely allocate memory for code and data section
  //initialise the enclave, and record the number of cycles taken
  //store the enclave id and print the hash
  //-------------------------------------------
  /*void LOCATE_FUNC load_enclave(const void* code_start, const void* code_end, size_t data_length,
                    struct enclave* enclave, void* rootEnclaveCode_cap)*/

  unsigned long int LOCATE_FUNC load_enclave(const void* code_start, const void* code_end, size_t data_length,
                    struct enclave* enclave, void* rootEnclaveCode_cap, unsigned long int* init_t)
  {
	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
      //use %08x and not %p to limit number of digits displayed, use typecast (uintptr_t)
	  disable_cycle_counter_EL1();//stop counter for print output
      printf("load_enclave [%08x, %08x)\n", (uintptr_t)code_start, (uintptr_t)code_end);
      enable_cycle_counter_EL1();
	#endif

      size_t code_len = (uintptr_t)code_end - (uintptr_t)code_start;

      //capability code_cap, data_cap;
      void* code_cap;
      void* data_cap;
      unique_alloc(&code_cap, code_len);
      unique_alloc(&data_cap, data_length);

      //debug print
      DG1(disable_cycle_counter_EL1();)//stop counter for print output
      DG1(printcapabilityPar_EL1((void*)code_start, "code_start");)
      DG1(printcapabilityPar_EL1((void*)code_end, "code_end");)
      DG1(printcapabilityPar_EL1(code_cap, "code_cap");)
      DG1(printcapabilityPar_EL1(data_cap, "data_cap");)
	  DG1(enable_cycle_counter_EL1();)//stop counter for print output

	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
	  disable_cycle_counter_EL1();//stop counter for print output
	  //use %08x and not %p to limit number of digits displayed, use typecast (uintptr_t)
      printf("relocating enclave from %08x to %08x\n\n",(uintptr_t)code_start, (uintptr_t)(cheri_address_get(code_cap)));
      enable_cycle_counter_EL1();
    #endif

      //copy enclave code from memory to the actual enclave code section
      copy_code(&code_cap, code_start, code_len, rootEnclaveCode_cap);

      //performance measurements--------------------
      //set up cycle counter
      unsigned long int startval, endval, numcycles;
      //reset_cycle_counter_EL1();
      //measure length of time taken to do enclave_init
      startval = read_cycle_counter_EL1();
      //---------------------------------------------

      //enclave_init(&code_cap, &data_cap, enclave);
      enclave_init(&code_cap, &data_cap, enclave, init_t); //capatest.c
      //performance measurements--------------------
      //get time
      endval = read_cycle_counter_EL1();
      numcycles = endval-startval;
      //---------------------------------------------

  	//---------------------------------------------------------------
  	//BENCHMARK
  	#if defined(BENCHMARK1)
      disable_cycle_counter_EL1();//stop counter for print output
      printf("t_enclave_init: %lu cycles\n", numcycles);
      enable_cycle_counter_EL1();
    #endif
	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
      disable_cycle_counter_EL1();//stop counter for print output
      printf("\nenclave_init took %lu cycles\n", numcycles);
      printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
      printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point

      printf("enclave structure.....\n");
      print_enclave(enclave);
      printf("\nenclave contents.....\n");
      print_enclave_content(enclave);
      printf("\n");
      enable_cycle_counter_EL1();
	#endif
     //---------------------------------------------------------------

      struct enclave_id id;

      //performance measurements--------------------
      //measure length of time taken to do enclave_id
      startval = read_cycle_counter_EL1();
      //---------------------------------------------

      enclave_store_id(enclave, &id, init_t);

      //performance measurements--------------------
      //get time
      endval = read_cycle_counter_EL1();
      numcycles = endval-startval;
      //---------------------------------------------
   //---------------------------------------------------------------
   #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
      disable_cycle_counter_EL1();//stop counter for print output
      printf("\nenclave_store_id took %lu cycles\n", numcycles);
      printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
      printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point

      //printf("struct enclave_id address in memory: 0x%lx\n", &id);
      printf("id hash address in memory: 0x%lx\n", &id.hash);
      printf("id: ");
      print_bytes(id.hash, ENCLAVE_ID_LEN);
      printf("\n\n");
      enable_cycle_counter_EL1();
   #endif
      return 1;
  }

  //-------------------------------------------
  //el1nmain:
  //Main program code of non secure EL1
  //-------------------------------------------
  int LOCATE_FUNC el1nmain(void)
  {
	//create a flag for the wait loop - to stop program
	volatile uint32_t flag = 1;

	//*****STRINGS***********************************************************
	//even though inside LOCATE_FUNC, string still stored in secure .bss region!!!
	//so can't do this!
	//const char* uartStr = "hello world to uart at EL1N\n"

	//These three ways seem to be able to assign a string locally in the same non secure memory region
	//(for the current set up - where you have one program trying to switch EL)
	// Todo - need to find better method - create a string table for EL1
	//Remember can't use c lib funcs to find the string length
	//char uartstr[24] = {'H', 'e', 'l', 'l', 'o',' ', 'W','o', 'r','l', 'd',' ', 'f','r', 'o','m', ' ', 'E', 'L', '1', 'N','\n', '\0'};
	//char uartstr[24] = "Hello World from EL1N\n";
	//char uartstr[] = "Hello World from EL1N\n\0";
	//*************************************************************************

	// uart fixed strings
	char uartstr[8] = {'E', 'L', '1', 'N', '\n', '\0'};
	char uartstr1[8] = {'T', 'E', 'S', 'T', ' ', '\0'};
	char uartstr2[8] = {'D', 'O', 'N', 'E', '\n', '\0'};

	//EL1N mmu already set up by EL2
	//EL1 UART not yet set up

	//---------------------------------------------------------------
	// set up the memory mapped UART
	//---------------------------------------------------------------
	// check for invalid capability UART tag
	if (cheri_tag_get(GLOBAL_UART_CAP_EL1N) == 0) {return -1;} //GLOBAL_UART_CAP_EL1N capability not valid!
	uartNcapSetup(GLOBAL_UART_CAP_EL1N);
	// write a string to the capability uart without printf
	uartNcapTransmitString(uartstr);

	//---------------------------------------------------------------
	// check other extern global capabilities
	//---------------------------------------------------------------
	//check enclave code capability for copying
	if (cheri_tag_get(CODE_SECTION_CAP) == 0)
	{
		// write to uart with embedded printf
		printf("Warning! - Enclave code section memory capability not valid!");
		return -1;
	}
	//---------------------------------------------------------------
	//Set up Unique alloc memory space
	//---------------------------------------------------------------
	init_capabilities();

	//setup and enable performance counter for measuring no. of clk cycles
	//count clks in EL1 and EL2
	//(this is needed with and without benchmark)
    setup_cycle_counterEL1and2_EL1();
    enable_cycle_counter_EL1();

	//---------------------------------------------------------------
	//BENCHMARK PROGRAM LOOP IF DEFINED
	//benchmark - internal loop max 38 with standard 65k enclave memory
    #if defined(BENCHMARK1)
    printf("\nBENCHMARK1");
    #endif
	#if defined(BENCHMARK2)
    printf("\nBENCHMARK2");
	#endif

	#if defined(BENCHMARK1) || defined(BENCHMARK2)
		int numIterations = 38;
		//save data to print at end - better for exporting to graph
		unsigned long int t1_t4_1[numIterations]; //code1
		unsigned long int t2_t5_1[numIterations]; //data1
		unsigned long int t3_t6_1[numIterations]; //estore1
		unsigned long int t7_1[numIterations];//load enclave 1
		unsigned long int t1_t4_2[numIterations]; //code3
		unsigned long int t2_t5_2[numIterations]; //data2
		unsigned long int t3_t6_2[numIterations]; //estore2
		unsigned long int t7_2[numIterations];//load enclave 2
		int currentIteration = 0;
		while (currentIteration<numIterations)
		{
			printf("\nPROGRAM ITERATION: %i\n\n",currentIteration);
	#endif
	//---------------------------------------------------------------

#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
			printf("\ncapattest demo on Morello\n"); // write to uart with embedded printf
	//---------------------------------------------------------------
	//Set up Sensor enclave
	//---------------------------------------------------------------
	printf("\nloading sensor enclave.....\n");
#endif

	//Sensor_code_start comes from the assembly file, sensor code_end comes from the linker
	//Todo but there is currently a cap reloc warning on the end address taken from the linker
	extern char sensor_code_start, sensor_code_end;
	unsigned long int init_t1[3];

#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
	printf("sensor_code start: %08x",&sensor_code_start);
	printf(" end: %08x\n",&sensor_code_end);
#endif

	struct enclave sensor;

	#if defined(BENCHMARK1)
		unsigned long int startvalb, endvalb, numcyclesb;
		startvalb = read_cycle_counter_EL1();
	#endif

		load_enclave(&sensor_code_start, &sensor_code_end, 256, &sensor, CODE_SECTION_CAP, init_t1);

	#if defined(BENCHMARK1)
		endvalb = read_cycle_counter_EL1();
	    numcyclesb = endvalb-startvalb;
	    disable_cycle_counter_EL1();//stop counter for print output
	    printf("t7_1_loadEnclave: %lu\n\n", numcyclesb);
	    //load enclave
	    t7_1[currentIteration]=numcyclesb;
	    enable_cycle_counter_EL1();
	#endif
    #if defined(BENCHMARK1) || defined(BENCHMARK2)
	    disable_cycle_counter_EL1();//stop counter for print output
	    //code
	    t1_t4_1[currentIteration]=init_t1[0];
	    //data
	    t2_t5_1[currentIteration]=init_t1[1];
	    //estoreid
	    t3_t6_1[currentIteration]=init_t1[2];
	    enable_cycle_counter_EL1();
    #endif
	//---------------------------------------------------------------
	//Set up User enclave
	//---------------------------------------------------------------
	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
	    printf("\nloading user enclave.....\n");
	#endif

	//User_code_start comes from the assembly file, user code_end comes from the linker
	//Todo but there is currently a cap reloc warning on the end address taken from the linker
	extern char user_code_start, user_code_end;
	unsigned long int init_t2[3];

	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
		printf("user_code start: %08x",&user_code_start);
		printf(" end: %08x\n",&user_code_end);
	#endif

	struct enclave user;

    #if defined(BENCHMARK1)
		startvalb = read_cycle_counter_EL1();
	#endif

		load_enclave(&user_code_start, &user_code_end, 256, &user, CODE_SECTION_CAP, init_t2);

	#if defined(BENCHMARK1)
		endvalb = read_cycle_counter_EL1();
		numcyclesb = endvalb-startvalb;
		disable_cycle_counter_EL1();//stop counter for print output
		printf("t7_2_loadEnclave: %lu\n", numcyclesb);
		//load enclave
	    t7_2[currentIteration]=numcyclesb;
		enable_cycle_counter_EL1();
	#endif
	#if defined(BENCHMARK1) || defined(BENCHMARK2)
		disable_cycle_counter_EL1();//stop counter for print output
		//code
		t1_t4_2[currentIteration]=init_t2[0];
		//data
		t2_t5_2[currentIteration]=init_t2[1];
	    //estoreid
	    t3_t6_2[currentIteration]=init_t2[2];
	    enable_cycle_counter_EL1();
	#endif


	//---------------------------------------------------------------
	//Do first invoke
	//---------------------------------------------------------------
	unsigned long int startval, endval, numcycles;
	unsigned long int t9c;
		//---------------------------------------------------------------
		//BENCHMARK ATTESTATION INNER LOOP IF DEFINED
	    #if defined(BENCHMARK1)
	    printf("\nBENCHMARK1 ATTESTATION LOOP\n");
	    #endif
		#if defined(BENCHMARK2)
	    printf("\nBENCHMARK2 ATTESTATION LOOP\n");
		#endif
		#if defined(BENCHMARK1) || defined(BENCHMARK2)
			int numOuterIterations = 1;
			//setup min / max / total (find average)
			int t10[3];
		    t10[0] = 0; t10[1] = 0; t10[2]= 0;
			//setup min / max / total (find average)
			int t9[3];
		    t9[0] = 0; t9[1] = 0; t9[2]= 0;
			int currentOuterIteration = 0;
			while (currentOuterIteration<numOuterIterations)
			{
				printf("INNER ITERATION: %i ",currentOuterIteration);
		#endif
		//---------------------------------------------------------------

	//---------------------------------------------------------------
	//invoke
	//---------------------------------------------------------------
	//create capability to the sensor enclave
	void* sensor_cap;
	sensor_cap = &sensor;

	//unsigned long int startval, endval, numcycles;

	//debug print
	DG1(printcapabilityPar_EL1(sensor_cap, "sensor_cap");)
	DG1(printcapabilityPar_EL1(&sensor, "&sensor");)

    #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
	printf("invoking user.set_sensor_enclave.....\n\n");
    #endif

	//output result is a pointer, same as sensor_cap (second argument to enclave_invoke)
	//but the tag bit is cleared if
	//function unsuccessful, otherwise returns structure
	void* result1;
	result1 = sensor_cap;

	//performance measurements--------------------
    //measure length of time taken to do enclave_invoke for attestation
    reset_cycle_counter_EL1();
    startval = read_cycle_counter_EL1();
    //--------------------------------------------

    //The 1 in func arg gets put in a7 (argument) and used for enclave_entry for two purposes
    //first purpose to direct to a7==others part of code to create entry pointer to enclave
    //second part to select correct pointer
    // when a7 =1, entry pointer=enclave_entries_start+0 = 1st pointer = relative jump to set_sensor_enclave
    t9c = enclave_invoke(&user, &sensor_cap, 1, &result1);

    //performance measurements--------------------
    //get time
    endval = read_cycle_counter_EL1();
    numcycles = endval - startval;
    //--------------------------------------------

	#if defined(BENCHMARK1)
    	printf("t10_attestation: %lu\n", numcycles);
        //min
        if (t10[0]==0){t10[0] = numcycles;}
        else {if (numcycles < t10[0]) {t10[0] = numcycles;}}
        //max
        if (numcycles > t10[1])	{t10[1] = numcycles;}
        //total
        t10[2] = t10[2] + numcycles;
	#endif
	#if defined(BENCHMARK2)
        //t9_return
        //min
        if (t9[0]==0){t9[0] = t9c;}
        else {if (t9c < t9[0]) {t9[0] = t9c;}}
        //max
        if (t9c > t9[1])	{t9[1] = t9c;}
        //total
        t9[2] = t9[2] + t9c;
	#endif
	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
    	printf("\nuser.set_sensor_enclave took %llu cycles\n", numcycles);
    	printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
    	printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point
    	printf("checking result1.....\n");
	#endif


	if (cheri_tag_get(result1))//remember Morello call by value
	{
         #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
		 printf("done 1st enclave invoke ok.....\n");
		 printf("\n");
         #endif
	}
	else
	{
	    printf("failed 1st enclave invoke.....\n");
	    DG1(printcapabilityPar_EL1(result1, "result1");)
	    printf("stopping program.....\n");
	    return 1;
	 }

    //---------------------------------------------------------------

	//---------------------------------------------------------------
    //BENCHMARK ATTESTATION LOOP END IF DEFINED
   	#if defined(BENCHMARK1) || defined(BENCHMARK2)
        currentOuterIteration++;
   	} //benchmark iterations
    #endif
    #if defined(BENCHMARK1)
			printf("t10_min: %lu\n", t10[0]);
			printf("t10_max: %lu\n", t10[1]);
			printf("t10_av: %lu\n", t10[2]/currentOuterIteration);
   	#endif
	#if defined(BENCHMARK2)
			printf("t9_min: %lu\n", t9[0]);
			printf("t9_max: %lu\n", t9[1]);
			printf("t9_av: %lu\n", t9[2]/currentOuterIteration);
	#endif
   //---------------------------------------------------------------



	//---------------------------------------------------------------
	//Do second invoke
	//---------------------------------------------------------------

	//---------------------------------------------------------------
	//BENCHMARK SENSOR ENCLAVE LOOP IF DEFINED
	#if defined(BENCHMARK1)
	printf("\nBENCHMARK1 SENSOR - ENCLAVE LOOP\n");
	#endif
    #if defined(BENCHMARK2)
	printf("\nBENCHMARK2 SENSOR - ENCLAVE LOOP\n");
	#endif
	//----------------------------------------------------------
	//Iteration to get time for different amounts of enclave processing
	#if defined(BENCHMARK1) || defined(BENCHMARK2)
	int numSensorIterations = 1;
	unsigned long int t11_sensor_loops[numSensorIterations];
	unsigned long int t11_min[numSensorIterations];
	unsigned long int t11_max[numSensorIterations];
	unsigned long int t11_av[numSensorIterations];
	int currentSensorIteration = 0;
	//use nonce to control amount of processing sensor enclave does
	uint32_t nonce = 1;
	while (currentSensorIteration<numSensorIterations)
	{
		printf("SENSOR ITERATION: %i ",currentSensorIteration);

	#else
		uint32_t nonce = 42;
	#endif
	//---------------------------------------------------------------


	unsigned long int t8c;
	//---------------------------------------------------------------
	//BENCHMARK DATA PROCESSING INNER LOOP IF DEFINED
    #if defined(BENCHMARK1)
    printf("\nBENCHMARK1 DATA PROCESSING LOOP\n");
    #endif
	#if defined(BENCHMARK2)
    printf("\nBENCHMARK2 DATA PROCESSING LOOP\n");
	#endif
    //----------------------------------------------------------
	#if defined(BENCHMARK1) || defined(BENCHMARK2)
		int numInnerIterations = 1;
		//setup min / max / total (find average)
		int t11[3];
	    t11[0] = 0; t11[1] = 0; t11[2]= 0;
		//setup min / max / total (find average)
		int t8[3];
	    t8[0] = 0; t8[1] = 0; t8[2]= 0;
		int currentInnerIteration = 0;
		while (currentInnerIteration<numInnerIterations)
		{
			printf("INNER ITERATION: %i ",currentInnerIteration);
	#endif
	//---------------------------------------------------------------




     uint32_t args[] = {nonce, 0};

     //create capability to args
     void* args_cap;
     args_cap = &args;

 	//output result is a pointer, same as args_cap (second argument to enclave_invoke)
 	//but the tag bit is cleared if
 	//function unsuccessful, otherwise returns structure
    uint32_t args2[] = {0, 0};
 	void* result2;
 	result2 = &args2;

	#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
     printf("invoking user.use_sensor(nonce=%u).....\n", nonce);
    #endif

     //performance measurements--------------------
     //measure length of time taken to do enclave_invoke to process data
     reset_cycle_counter_EL1();
     startval = read_cycle_counter_EL1();
     //--------------------------------------------

     t8c = enclave_invoke(&user, &args_cap, 2, &result2);

     //performance measurements--------------------
     //get time
     endval = read_cycle_counter_EL1();
     numcycles = endval - startval;
     //--------------------------------------------
#if defined(BENCHMARK1)
    printf("t11_process: %lu\n", numcycles);
    //min
    if (t11[0]==0){t11[0] = numcycles;}
    else {if (numcycles < t11[0]) {t11[0] = numcycles;}}
    //max
    if (numcycles > t11[1])	{t11[1] = numcycles;}
    //total
    t11[2] = t11[2] + numcycles;
#endif
#if defined(BENCHMARK2)
    //min
    if (t8[0]==0){t8[0] = t8c;}
    else {if (t8c < t8[0]) {t8[0] = t8c;}}
    //max
    if (t8c > t8[1])	{t8[1] = t8c;}
    //total
    t8[2] = t8[2] + t8c;
#endif
#if !defined(BENCHMARK1) && !defined(BENCHMARK2)
     printf("\nuser.set_sensor_enclave took %llu cycles\n", numcycles);
     printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
     printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point
     printf("checking result2.....\n");
#endif

     if (cheri_tag_get(result2))//remember Morello call by value
     {
         #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
    	 printf("done 2nd enclave invoke ok.....\n\n");
         #endif

    	 //extra debug
    	/* DG1(printcapabilityPar_EL1(result2, "result2");)
    	 DG1(printcapabilityPar_EL1(&result2, "&result2");)
    	 DG1(printcapabilityPar_EL1(args_cap, "args_cap");)
    	 DG1(printcapabilityPar_EL1(&args_cap, "&args_cap");)
    	 DG1(printcapabilityPar_EL1(user.sign_seal, "user.sign_seal");)
    	 DG1(printcapabilityPar_EL1(&user.sign_seal, "&user.sign_seal");)*/

    	 //--------------------------------------------
    	 //unseal result
    	 //--------------------------------------------
    	 //cheri_unseal(&result, &user.sign_seal); //riscv call by ref
    	 result2 = cheri_unseal(result2, user.sign_seal); //Morello call by value

    	 //--------------------------------------------
    	 //get and print result2
    	 //--------------------------------------------
    	 //uint32_t nonce = cheri_lw(&result);//proteus
    	 //uint32_t value = cheri_lw(&result);
    	     uint32_t nonce;
    	     uint32_t value;
    	     asm volatile(
    	         "LDR %w[word1_asm], [%x[result_asm]]\n\t" //get first word
    	    	 "GCOFF x2, %x[result_asm]\n\t"	 //inc offset by 4 bytes
    	         "ADD x2, x2, #4\n\t"
    	    	 "SCOFF %x[result_asm], %x[result_asm], x2\n\t"
    	         "LDR %w[word2_asm], [%x[result_asm]]\n\t"	 //get second word
    	         : [word1_asm] "+r"(nonce), //output
				   [word2_asm] "+r"(value), //output
    	           [result_asm] "+r"(result2) //input/output
				 :
				 : "x2", "cc"//clobber
    	     );
    	  //-------------------------------------------
          #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
    	  printf("ok: nonce=%u, ", nonce);
    	  printf(" value=%u\n", value);
          #endif
    	  //-------------------------------------------
     }
    	     else
    	     {
    	    	 printf("failed 2nd enclave invoke.....\n");
    	    	 DG1(printcapabilityPar_EL1(result2, "result2");)
    	    	 printf("stopping program.....\n");
    	         return 1;
    	     }

     //---------------------------------------------------------------
         //BENCHMARK DATA PROCESSING INNER LOOP END IF DEFINED
    	#if defined(BENCHMARK1) || defined(BENCHMARK2)
         currentInnerIteration++;
    	} //benchmark iterations
        #endif
        #if defined(BENCHMARK1)
		printf("t11_min: %lu\n", t11[0]);
		printf("t11_max: %lu\n", t11[1]);
		printf("t11_av: %lu\n", t11[2]/currentInnerIteration);
		//save data
		t11_sensor_loops[currentSensorIteration]=nonce;
		t11_min[currentSensorIteration]=t11[0];
		t11_max[currentSensorIteration]=t11[1];
		t11_av[currentSensorIteration]=t11[2];
    	#endif
		#if defined(BENCHMARK2)
		printf("t8_min: %lu\n", t8[0]);
		printf("t8_max: %lu\n", t8[1]);
		printf("t8_av: %lu\n", t8[2]/currentInnerIteration);
		#endif
    	//---------------------------------------------------------------

		//---------------------------------------------------------------
	    //BENCHMARK SENSOR ENCLAVE LOOP END IF DEFINED
	    #if defined(BENCHMARK1) || defined(BENCHMARK2)
	      currentSensorIteration++;
			//use nonce to control amount of processing sensor enclave does
			nonce = nonce+10;
	    } //benchmark iterations
	    #endif
        #if defined(BENCHMARK1)
	//t11_sensor_loops
	printf("\nt11_sensor_loops: ");
			for (currentSensorIteration = 0; currentSensorIteration<numSensorIterations; currentSensorIteration++)
			{
			printf("%lu ", t11_sensor_loops[currentSensorIteration]);
			}
	//processing lines, 7 instructions is one loop
	printf("\nt11_sensor_instructions: ");
			for (currentSensorIteration = 0; currentSensorIteration<numSensorIterations; currentSensorIteration++)
			{
			printf("%lu ", t11_sensor_loops[currentSensorIteration]*7);
			}
	//t11_min
	printf("\nt11_min: ");
			for (currentSensorIteration = 0; currentSensorIteration<numSensorIterations; currentSensorIteration++)
			{
			printf("%lu ", t11_min[currentSensorIteration]);
			}
	//t11_max
	printf("\nt11_max: ");
		   for (currentSensorIteration = 0; currentSensorIteration<numSensorIterations; currentSensorIteration++)
			{
			printf("%lu ", t11_max[currentSensorIteration]);
			}
	//t11_av
	printf("\nt11_av: ");
		   for (currentSensorIteration = 0; currentSensorIteration<numSensorIterations; currentSensorIteration++)
			{
			printf("%lu ", t11_av[currentSensorIteration]);
			}

    	#endif

	    //---------------------------------------------------------------

     //---------------------------------------------------------------
     //BENCHMARK PROGRAM LOOP END IF DEFINED
	#if defined(BENCHMARK1) || defined(BENCHMARK2)
     currentIteration++;
	} //benchmark iterations
	#endif


	//---------------------------------------------------------------
	printf("stopping program.....\n");
    //for better data output for importing to graphs
    #if defined(BENCHMARK1)|| defined(BENCHMARK2)
	//code1
	printf("t1_t4_1: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t1_t4_1[currentIteration]);
			}
	//data1
	printf("\nt2_t5_1: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t2_t5_1[currentIteration]);
			}
	//estore1
	printf("\nt3_t6_1: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t3_t6_1[currentIteration]);
			}
	//code2
	printf("\nt1_t4_2: ");
		for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t1_t4_2[currentIteration]);
			}
	//data2
	printf("\nt2_t5_2: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t2_t5_2[currentIteration]);
			}
	//estore1
	printf("\nt3_t6_2: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t3_t6_2[currentIteration]);
			}
    #endif
    #if defined(BENCHMARK1)
	//load enclave
	printf("\nt7_1: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t7_1[currentIteration]);
			}
	printf("\nt7_2: ");
			for (currentIteration = 0; currentIteration<numIterations; currentIteration++)
			{
			printf("%lu ", t7_2[currentIteration]);
			}
    #endif
	//----------------------------------------------------------------
	printf("\ndone2.....\n");
	// loop here
	while(flag==1){}

	// We never get here
	return EXIT_SUCCESS;
  }
