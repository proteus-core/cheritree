/*
 ============================================================================
 Name        : capattest.c
 Description : Adapted to work on Morello by CAP-TEE 2021
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

//*****************************************
// INCLUDES
//*****************************************

//program includes
#include "capattest.h"
#include "unique_alloc.h"
#include "cheri_extra.h" //uses in-line #defines added by CAP-TEE

#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#endif
#include <EL1Code/uartN_redirect.h>

//for performance measurements
#include <EL1Code/performance_EL1.h>

//*****************************************
// FUNCTIONS
//*****************************************

//---------------------------------------------------
//enclave_init
//---------------------------------------------------
//include numcycles for performance measurements
int LOCATE_FUNC enclave_init(void* code_cap,
                 void* data_cap,
                 struct enclave* enclave, unsigned long int* numcycles)


{

    //debug print
    #ifdef DEBUG_EL1
		disable_cycle_counter_EL1();//stop counter for print output
		printf("......................................\n");
		printf("enclave_init before..........\n");
        print_cap_debug_EL1(code_cap, "code_cap");
        print_cap_debug_EL1(data_cap, "data_cap");
        print_cap_debug_EL1(&enclave->code_cap, "&enclave->code_cap");
        print_cap_debug_EL1(&enclave->data_cap, "&enclave->data_cap");
        print_cap_debug_EL1(&enclave->enc_seal, "&enclave->enc_seal");
        print_cap_debug_EL1(&enclave->sign_seal, "&enclave->sign_seal");
        printf("enclave structure\n");
        print_enclave_debug_EL1(enclave);
        printf("......................................\n");
        enable_cycle_counter_EL1(); //restart counter for print output
    #endif


    //asm volatile WARNING!
    //need to do this first - assign locally because the llvm asm compiler just can't
    //cope with doing a & and -> at the same time.
    void* local_code_cap_addr=&enclave->code_cap;
    void* local_data_cap_addr=&enclave->data_cap;
    void* local_enc_seal_addr=&enclave->enc_seal;
    void* local_sign_seal_addr=&enclave->sign_seal;

    //  cheri_clear_all_gpcr(); //NOTE:llvm doesn't place "inline" in function

    //For performance testing -----------
  	//measure length of time taken for EINIT_CODE to run instruction
     unsigned long int startval, endvalcode, endvaldata;

	#if defined(BENCHMARK2)
     //measuring t1
     //If we are measuring t1 in EL2 only we need to disable the timer here
     //until we get to the bit we want to measure in EL2
     disable_cycle_counter_EL1(); //stop counter
	#endif

      	startval = read_cycle_counter_EL1();

    asm volatile(
    	//-------------------------------------
    	// set up code capability for c0
    	//-------------------------------------
        //"LC ca0, (%[code_cap_in])\n\t"//(riscv)
    	// Load code capability into first func arg c0
    	// (set ca0 (c0) to the enclave's code section)
    	"LDR c0, [%x[code_cap_in]]\n\t"

    	//Todo - need to include automatic remaining in capability mode on a branch
    	//modify codecap value so that lsb is 1
    	//this is needed to tell the hardware that we
    	// wish to remain in c64 mode
    	//following a domain transition via the BRS instruction later
    	//"GCVALUE x13, c0\n\t"
    	//"ORR x13, x13, #(0x1 << 0)\n\t"
    	//"SCVALUE c0, c0, x13\n\t"

        // Clear the given code capability
        //"SC cnull, (%[code_cap_in])\n\t"//(riscv)
        "STR xzr, [%x[code_cap_in]]\n\t"

    	//-------------------------------------
	  	//NEW EINIT_CODE INSTRUCTION TO GO HERE
	  	//-------------------------------------
    	//ca0 (c0), code capability - is passed as an argument
    	//"EInitCode ca0, ca0\n\t"//(riscv)
    	//perform a Morello HVC call to replace riscv instruction
	  	"HVC #%[hvc_call_einitcode]\n\t"

        //return back here
    	//ca0 (c0), processed code capability (sealed) - is returned as an argument
    	//check seal
    	//"GCSEAL x1, c0\n\t"

    	//get performance measurement
    	//read count value
    	"MRS  %x[countValcode_ass], PMCCNTR_EL0\n\t"

    	//-------------------------------------
        // set up data capability
        //-------------------------------------
    	// Set ca1 (c1) to the enclave's data section
        //"LC ca1, (%[data_cap_in])\n\t"//(riscv)
    	"LDR c1, [%x[data_cap_in]]\n\t"
        // Clear the data capability on the stack
        //"SC cnull, (%[data_cap_in])\n\t"//(riscv)
    	"STR xzr, [%x[data_cap_in]]\n\t"
        // The data capability shouldn't be executable or CInvoke will fail
        //"CAndPerm ca1, ca1, %[data_perms]\n\t"//(riscv)
    	//(Morello does a clear of the bit selected so doesn't need the invert)
       "MOV x13, #(%x[data_perms])\n\t"
    	//(reduce permissions and clear)
    	"CLRPERM c1, c1, x13 \n\t"

	  	//-------------------------------------
	  	//NEW EINIT_DATA INSTRUCTION TO GO HERE
	  	//-------------------------------------
    	// (c0), sealed code capability - is passed as an argument
    	// (c1), data capability - is passed as second argument
	  	"HVC #%[hvc_call_einitdata]\n\t"

        //return back here
        //(c0), processed data capability (sealed) - is returned as an argument
    	//(c1) has the old c0 value in it - code capability
    		//check seal
    		//"GCSEAL x4, c0\n\t"
    		//"GCSEAL x4, c1\n\t"

        //-------------------------------------
        // Store the results of EInitCode (c1) /EInitData ca1 (c0)
        // in the enclave structure
    	//-------------------------------------
    	//"SC ca0, (%[code_cap])\n\t"//(riscv)
        //"SC ca1, (%[data_cap])\n\t"//(riscv)
    	"STR c0, [%x[data_cap]]\n\t"
    	"STR c1, [%x[code_cap]]\n\t"
    	//swap back over otherwise will need to change enclave code
        "LDR c0, [%x[code_cap]]\n\t"
        "LDR c1, [%x[data_cap]]\n\t"

    	//get performance measurement
        //read count value
    	"MRS  %x[countValdata_ass], PMCCNTR_EL0\n\t"

        //-------------------------------------
    	//set up CInvoke / BRS
    	//-------------------------------------
        //store return address on stack, otherwise this function looses where to return to
    	"STP c0, c1, [csp, #-32]!\n\t"
    	"STP c29, c30, [csp, #-32]!\n\t"//C30 RETURN ADDR
        // Set the return address for the enclave invocation
        //"CSpecialR ct0, ddc\n\t"//(riscv)
        //"la t0, 1f\n\t"//(riscv)
        //"CSetAddr cra, ct0, t0\n\t"//(riscv)
    	//do not need ddc in Morello, and is already nulled
    	"ADR c30, back\n\t"

        //set up argument a7 (X7)=0 to run enclave_init code
        //"mv a7, zero\n\t"//(riscv)
    	 "MOV x7, #0\n\t"
    	//CInvoke ------------------------
        // Invoke to get the seals.
    	//This also passes the sealed entry capabilities in ca0 (c0)code /ca1(c1)data.
        //"CInvoke ca0, ca1\n\t"//(riscv)
    	//c0 sealed code_cap
    	//c1 sealed data_cap

    	//NEED TO SAVE REGISTERS ON THE STACK
    	//ELSE LOOSES ADDRESS OF LOCAL ENCLAVE STRUCTURE
    	"STP c20, c21, [csp, #-32]!\n\t"
    	"STP c18, c19, [csp, #-32]!\n\t"
    	"STP c16, c17, [csp, #-32]!\n\t"
    	"STP c14, c15, [csp, #-32]!\n\t"
    	"STP c12, c13, [csp, #-32]!\n\t"
    	"STP c10, c11, [csp, #-32]!\n\t"
    	"STP c8, c9, [csp, #-32]!\n\t"
    	"STP c6, c7, [csp, #-32]!\n\t"
    	"STP c4, c5, [csp, #-32]!\n\t"
    	"STP c2, c3, [csp, #-32]!\n\t"

    	"MOV c20, csp\n\t" //save stack pointer in saved register

    	"BRS c29, c0, c1\n\t" //(must include C29)
    	//The seals are returned:
    	//ca0 (c0) enc seal
    	//ca1 (c1) sign seal
    	//--------------------------------
    	//this is the return address
        "back:\n\t"
    	"NOP\n\t"
    	"BX#4\n\t" //on entry hardware defaults to a64, so need to tell it to switch to c64
    	"MOV csp, c20\n\t" //restore stack pointer before continuing
    	//this instruction fails if enters on a64 mode
        "LDP c2, c3, [csp], #32\n\t"
        "LDP c4, c5, [csp], #32\n\t"
        "LDP c6, c7, [csp], #32\n\t"
    	"LDP c8, c9, [csp], #32\n\t"
    	"LDP c10, c11, [csp], #32\n\t"
    	"LDP c12, c13, [csp], #32\n\t"
    	"LDP c14, c15, [csp], #32\n\t"
    	"LDP c16, c17, [csp], #32\n\t"
    	"LDP c18, c19, [csp], #32\n\t"
    	"LDP c20, c21, [csp], #32\n\t"
    	//retrieve return address off stack
    	"LDP c29, c30, [csp], #32\n\t"
        // Store the seals
        //"SC ca0, (%[enc_seal])\n\t"//(riscv)
        //"SC ca1, (%[sign_seal])\n\t"//(riscv)
    	"STR c0,[%x[enc_seal]]\n\t"
    	"STR c1,[%x[sign_seal]]\n\t"

    	"LDP c0, c1, [csp], #32\n\t"

        : [code_cap_in] "+r"(code_cap), //CAP-TEE added + for read write and move to output (in and out)
          [data_cap_in] "+r"(data_cap),  //CAP-TEE added + for read write and move to output (in and out)
          [code_cap]    "+r"(local_code_cap_addr),//CAP-TEE added + for read write and move to output (in and out)
          [data_cap]    "+r"(local_data_cap_addr),//CAP-TEE added + for read write and move to output (in and out)
          [enc_seal]    "+r"(local_enc_seal_addr),//CAP-TEE added + for read write and move to output (in and out)
          [sign_seal]   "+r"(local_sign_seal_addr),//CAP-TEE added + for read write and move to output (in and out)
		  [countValcode_ass] "+r"(endvalcode),//CAP-TEE added to get performance measurement
		  [countValdata_ass] "+r"(endvaldata)//CAP-TEE added to get performance measurement
		: [data_perms]  "I"((1 << PERM_PERMIT_EXECUTE)),
		  [hvc_call_einitcode]"I" (HVC_EINITCODE), // (I - means immediate value)
		  [hvc_call_einitdata]"I" (HVC_EINITDATA) // (I - means immediate value)
		: "x13", "x7", "c0", "c1", "c9", "c20", "c30", "memory"

    );

    //For performance testing of EINITCODE-----------
    //get time
    numcycles[0] = endvalcode-startval;
	#if defined(BENCHMARK1)
         //measuring t4
         disable_cycle_counter_EL1();//stop counter for print output
    	 printf("t4_hvc_code : %llu\n", numcycles[0]);
    	 enable_cycle_counter_EL1();
	#endif
    #if defined(BENCHMARK2)
		 //measuring t1
         disable_cycle_counter_EL1();//stop counter for print output
    	 printf("t1_code : %llu\n", numcycles[0]);
    	 enable_cycle_counter_EL1();
	#endif
    #if !defined(BENCHMARK1) && !defined(BENCHMARK2)
    // disable_cycle_counter_EL1();//stop counter for print output
    //	printf("number of cycles to do HVC_EINITCODE instruction from capatest : %llu\n", numcycles);
    //	printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
    //	printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point
    // enable_cycle_counter_EL1();
    	 //-----------------------------------
	#endif

    //For performance testing of EINITDATA-----------
    numcycles[1] = endvaldata-endvalcode;
	#if defined(BENCHMARK1)
         disable_cycle_counter_EL1();//stop counter for print output
    	 printf("t5_hvc_data : %llu\n", numcycles[1]);
    	 enable_cycle_counter_EL1();
	#endif
	#if defined(BENCHMARK2)
    	 //measuring t2
    	 disable_cycle_counter_EL1();//stop counter for print output
    	 printf("t2_data : %llu\n", numcycles[1]);
    	 enable_cycle_counter_EL1();
	#endif
    //added by CAP-TEE
    #ifdef DEBUG_EL1
    disable_cycle_counter_EL1();//stop counter for print output
    printf("......................................\n");
	printf("enclave_init after..........\n");
        print_cap_debug_EL1(code_cap,"code_cap");
        print_cap_debug_EL1(data_cap,"data_cap");
        print_cap_debug_EL1(&enclave->enc_seal,"&enclave->enc_seal"); //code
        print_cap_debug_EL1(&enclave->sign_seal,"&enclave->sign_seal");//data
        printf("enclave structure\n");
        print_enclave_debug_EL1(enclave);
        printf("......................................\n");
    enable_cycle_counter_EL1();//restart counter
    #endif

    return 1;
}

//---------------------------------------------------
//enclave_store_id
// retrieve and store hash
//---------------------------------------------------
int LOCATE_FUNC enclave_store_id(const struct enclave* enclave, struct enclave_id* id,unsigned long int* numcyclesA)
{
    int result;

    //asm volatile warning!
    //need to do this first - assign locally because the llvm asm compiler just can't
    //cope with doing a & and -> at the same time.
    void* local_hash_addr=&id->hash;
    void* const* local_code_cap_addr=&enclave->code_cap;

    //BENCHMARK
    //For performance testing -----------
	//measure length of time taken for ESTORE_ID to run instruction
	//set up cycle counter
    #if defined(BENCHMARK1)
        //measuring t6 (inc hvc)
    	unsigned long int startval, endval, numcycles;
    	startval = read_cycle_counter_EL1();
    #endif
    #if defined(BENCHMARK2)
     //measuring t3 (ex hvc)
     unsigned long int startval, endval, numcycles;
     //If we are measuring t3 in EL2 only we need to disable the timer here
     //until we get to the bit we want to measure in EL2
     disable_cycle_counter_EL1(); //stop counter
     startval = read_cycle_counter_EL1();
	#endif


    //-----------------------------------
    asm volatile(
        //"CSpecialR ct0, ddc\n\t"//(riscv)
    	//"MRS c9, DDC\n\t" //DONT NEED THIS AS ALREADY A CAPABILITY
        // Set ct1 to the hash
        //"CSetAddr ct1, ct0, %[hash]\n\t"//(riscv)
    	"MOV c1, %x[hash]\n\t" //SCVALUE expects an x register, but hash is a pointer, i.e cap, so MOV first
    	"GCLEN x2, c1\n\t"
    	//"SCVALUE c10, c9, x13\n\t"//then use addr
        // Load the code capability to get its type
        //"LC ct2, (%[code_cap])\n\t"//(riscv)
        //"CGetType t0, ct2\n\t"//(riscv)
    	"LDR c2, [%x[code_cap]]\n\t"
    	"GCTYPE x0, c2\n\t"
    	//NEW INSTRUCTION TO GO HERE---------------
	    //pass in t0(x13) code cap type
    	//pass in ct1(c10) capability to the hash
        //"EStoreId %[result], t0, ct1\n\t"//riscv
	  	//-------------------------------------
	  	//NEW ESTORE_ID INSTRUCTION TO GO HERE
	  	//-------------------------------------
    	//Inputs:
    	//x0 otype
    	//c1 memhashcap
	  	"HVC #%[hvc_call_estoreid]\n\t"
    	//output: x0 boolean success/failure

    	//-----------------------------------------
		//return result (integer) in ca0 (c0) so need to move to result
		"MOV %w[result], w0\n\t"
    	//return result, but does'nt go anywhere, stays in this func
    	//----------------------------------------
        //: [result]   "=r"(result)
        //: [hash]     "r"(&id->hash),
        //  [code_cap] "r"(&enclave->code_cap)
        //: "x13", "memory"
        : [result]   "=r"(result) //in/out
        : [hash]     "r"(local_hash_addr),
          [code_cap] "r"(local_code_cap_addr),//in only
		  [hvc_call_estoreid]"I" (HVC_ESTOREID) // (I - means immediate value)
		: "x0", "w0", "c1", "c2", "memory"// stuff change
    );
    //BENCHMARK
    //For performance testing -----------
	//get time
     #if defined(BENCHMARK1)
	    endval = read_cycle_counter_EL1();
	    numcycles = endval-startval;
	    disable_cycle_counter_EL1();//stop counting while print
	    printf("t6_estoreid_hvc: %lu\n", numcycles);
	    numcyclesA[2] = numcycles; //save in init_t array pos 3
	    enable_cycle_counter_EL1(); //restart counting
	  #endif
	#if defined(BENCHMARK2)
	    endval = read_cycle_counter_EL1();
	    numcycles = endval-startval;
	    disable_cycle_counter_EL1();//stop counting while print
	    printf("t3_estoreid: %lu\n\n", numcycles);
	    numcyclesA[2]=numcycles; //save in init_t array pos 3
	    enable_cycle_counter_EL1(); //restart counting
 	 #endif
	//  disable_cycle_counter_EL1();//stop counting while print
	//    printf("number of cycles to do HVC_ESTOREID instruction from capatest : %llu\n", numcycles);
	//  printf("number of micro seconds (2000MHz processor) : %f\n", ((float)numcycles)/2000);
	//  printf("number of seconds (2000MHz processor) : %f\n\n", (((float)numcycles)/2000000000)); //change to floating point
    // enable_cycle_counter_EL1(); //restart counting
    //-----------------------------------

    return result;
}

//---------------------------------------------------
//enclave_invoke
//
//---------------------------------------------------
//added return for performance measurement
unsigned long int LOCATE_FUNC enclave_invoke(const struct enclave* enclave,
                    const void* input,
                    unsigned entry_index,
                    void* result)
{
	DG1(disable_cycle_counter_EL1();)//stop counter for print output
	DG1(printcapabilityPar_EL1(result, "result");)
	DG1(enable_cycle_counter_EL1();)

    //asm volatile warning!
    //need to do this first - assign locally because the llvm asm compiler just can't
    //cope with doing a & and -> at the same time.
    void* const* local_code_cap_addr=&enclave->code_cap;
    void* const* local_data_cap_addr=&enclave->data_cap;

    //-------------------------------------------------
    //BENCHMARK testing
    //For measuring t8 and t9
    unsigned long int endval;
#if defined(BENCHMARK2)
    //counter in
    //user_enclave.S (set_sensor_enclave and use_sensor
    //unsigned long int endval;
    enable_cycle_counter_EL1();
    reset_cycle_counter_EL1(); //so start from 0
#endif

    asm volatile(
        // load code/data capabilities in ct0/ct1
        //"LC ct0, (%[code_cap])\n\t"//(riscv)
        //"LC ct1, (%[data_cap])\n\t"//(riscv)
    	"LDR c9, [%x[code_cap]]\n\t"
    	"LDR c10, [%x[data_cap]]\n\t"

        // load arguments capability in ca0
        //"LC ca0, (%[args_cap])\n\t"//(riscv)
    	"LDR c0, [%x[args_cap]]\n\t"

        // entry index is passed in a7 (x7) unsigned 32 bit
        //"mv a7, %[entry]\n\t"//(riscv)
    	"MOV x7, %x[entry]\n\t"

        // Set the return address for the enclave invocation
        //"la t0, 1f\n\t"
        //"CSpecialR cra, ddc\n\t"
        //"CSetAddr cra, cra, t0\n\t"
       // "MRS c30, DDC\n\t"
       // "LDR x13, =1\n\t"
       // "SCVALUE c30, c30, x13\n\t" //DONT need to do this in Morello
       //store return address on stack, otherwise this function looses where to return to
       //CHECK NEED THIS
       "STP c0, c1, [csp, #-32]!\n\t"
       "STP c29, c30, [csp, #-32]!\n\t"//C30 RETURN ADDR
       //set c9 with PCC address offset by label
       //do do not need ddc which is nulled
       "ADR c30, back2\n\t"

       //NEED TO SAVE SOME REGISTERS ON THE STACK
       //ELSE LOOSES ADDRESS OF LOCAL ENCLAVE STRUCTURE
        "STP c20, c21, [csp, #-32]!\n\t"
        "STP c18, c19, [csp, #-32]!\n\t"
        "STP c16, c17, [csp, #-32]!\n\t"
    	"STP c14, c15, [csp, #-32]!\n\t"
    	"STP c12, c13, [csp, #-32]!\n\t"
    	"STP c10, c11, [csp, #-32]!\n\t"
    	"STP c8, c9, [csp, #-32]!\n\t"
    	"STP c6, c7, [csp, #-32]!\n\t"
    	"STP c4, c5, [csp, #-32]!\n\t"
    	"STP c2, c3, [csp, #-32]!\n\t"

    	"MOV c20, csp\n\t" //save stack pointer in saved register

    	//CInvoke ------------------------
    	//This also passes the sealed entry capabilities in ca0 (c0)code /ca1(c1)data.
        // invoke enclave
        //"CInvoke ct0, ct1\n\t"
    	"BRS c29, c9, c10\n\t" //(must include C29)
    	//returns ca0 (c0) result which is cap
    	//--------------------------------------------
        "back2:\n\t"
    	"NOP\n\t"
    	"BX#4\n\t" //on entry hardware defaults to a64, so need to tell it to switch to c64
    	"MOV csp, c20\n\t" //restore stack pointer before continuing

        "LDP c2, c3, [csp], #32\n\t"
        "LDP c4, c5, [csp], #32\n\t"
        "LDP c6, c7, [csp], #32\n\t"
        "LDP c8, c9, [csp], #32\n\t"
        "LDP c10, c11, [csp], #32\n\t"
        "LDP c12, c13, [csp], #32\n\t"
        "LDP c14, c15, [csp], #32\n\t"
        "LDP c16, c17, [csp], #32\n\t"
        "LDP c18, c19, [csp], #32\n\t"
    	"LDP c20, c21, [csp], #32\n\t"
        //retrieve return address off stack
        "LDP c29, c30, [csp], #32\n\t"

        // store return value ca0 (c0)
        //"SC ca0, (%[result])\n\t"
    	"STR c0, [%x[result_asm]]\n\t"

    	//load old c0 value	(args_cap) (&sensor_cap on first invoke)
    	"LDP c0, c1, [csp], #32\n\t"

       // :
       // : [code_cap] "r"(local_code_cap_addr),
       //   [data_cap] "r"(local_data_cap_addr),
       //   [args_cap] "r"(input),
       //   [entry]    "r"(entry_index),
       //   [result]   "r"(result)
       // : "x13", "x7", "c30", "memory"
	    : [result_asm]   "+r"(result) //output list
	    : [code_cap] "r"(local_code_cap_addr),
	      [data_cap] "r"(local_data_cap_addr),
	      [args_cap] "r"(input),
	      [entry]    "r"(entry_index)
	     : "x13", "x7", "c0", "c1", "c9", "c10", "c20", "c29", "c30", "memory"
    );

    //-------------------------------------------------
    //BENCHMARK testing
    //For measuring t8 and t9
    //including this invalidates t10 so do BENCHMARK 1 and 2 separately
#if defined(BENCHMARK2)
    //t8 the end value is determined by when the counter is disabled in enclave code
    //it is set up to be disabled on entry to use_sensor_enclave in user enclave.S
    //this will measure the number of clks to invoke entry into a typical enclave function including
    //setup of the registers before the invoke
    //t9 the end value is read here because it is reset from enclave before a return
    endval = read_cycle_counter_EL1();
	disable_cycle_counter_EL1();//stop counter for print output
	printf("t9_return_t8_entry: %lu\n", endval); //first output t9, second t8
	enable_cycle_counter_EL1();
#endif
	return endval;
}



