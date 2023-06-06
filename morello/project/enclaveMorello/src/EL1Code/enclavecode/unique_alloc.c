/*
 ============================================================================
 Name        : unique_alloc.c
 Description : Adapted to work on Morello by CAP-TEE 2021
 	 	 	 : unique allocation of enclave memory
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
#define LOCATE_BSS  __attribute__((__section__(".NONSECUREsection_el1_bss")))

#include <stdio.h>
#include <stdlib.h>
#define CAP_LEN 16 //16 bytes

#include <cheriintrin.h>

//printing debug output
#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#include <EL1Code/uartN_redirect.h> //uart functions
#endif

#include <EL1Code/enclavecode/unique_alloc.h>

//This is a global variable and needs to be placed in a non secure section
static void* heap_cap LOCATE_BSS;

//*****************************************
// FUNCTIONS
//*****************************************

//---------------------------------------------------
//unique_alloc_init:
//Initialistion of unique enclave memory
//---------------------------------------------------
int LOCATE_FUNC unique_alloc_init(void** heap)
{
	//first check the heap parameters to avoid invalid capabilities being produced
	//when in debug print output
	DG1(printf("*********************************************\n");)
	DG1(printf("Initialising unique_alloc ...................\n");)
	DG1(if (capabilityValidCheck_EL1((void*)*heap, "heap") == -1) {return -1;})
    //check for invalid capability tag WHEN NOT IN DEBUG
	nDG1(if (cheri_tag_get((void*)*heap) == 0){return -1;})

	//get full bounds of heap capability and set global variable heap_cap
	//cheri_move(&heap_cap, heap);  //proteus
	heap_cap = (void*)*heap;//same as proteus set up

	//when in debug print output
	DG1(printcapabilityPar_EL1(heap_cap,"heap_cap");)
	DG1(printf("Finished Initialising unique_alloc ..........\n");)
	DG1(printf("*********************************************\n\n");)

	return 0;
}


//---------------------------------------------------
//unique_alloc:
//allocate unique enclave memory and then shrink capability
//---------------------------------------------------
int LOCATE_FUNC unique_alloc(void** dst, size_t size)
{
    // Round-up size to a multiple of CAP_LEN. This ensures that all allocations
    // stay CAP_LEN aligned.
    size = (size + CAP_LEN - 1) & ~(CAP_LEN - 1);

    //when in debug print output
	DG1(printf("*********************************************\n");)
	DG1(printf("Running unique_alloc.........................\n");)
	DG1(printf("Size to allocate: %lu\n",(unsigned long int)size);)
	DG1(printf("Size to allocate hex: %08lx\n",(unsigned long int)size);)

    // Allocate space from the beginning of heap_cap.
    //Set length of bounds
    *dst = cheri_bounds_set_exact(heap_cap, (unsigned long int)size);//same as proteus

	//when in debug print output
	DG1(printf("Checking allocated enclave capability parameters:\n");)
	DG1(printcapabilityPar_EL1(*dst, "*dst");)//same as proteus
	DG1(if (capabilityValidCheck_EL1(*dst, "*dst") == -1) {return -1;})
    //check for invalid capability tag WHEN NOT IN DEBUG
	nDG1(if (cheri_tag_get((void*)*dst) == 0){return -1;})

    // Shrink heap_cap.
	DG1(printf("Shrinking enclave heap ................\n");)
	//set new address
	// get the new heap starting address - increase by size
	unsigned long int heap_end = cheri_address_get(heap_cap) + size;
	//get the new heap bounds - reduce by size
	unsigned long int heap_cap_len = cheri_length_get(heap_cap) - size;
	// get the new heap starting address
	heap_cap = cheri_address_set(heap_cap, heap_end);
    heap_cap = cheri_bounds_set_exact(heap_cap, heap_cap_len);

    //when in debug print output
	DG1(printf("Checking shrunk heap_cap parameters:\n");)
	DG1(printcapabilityPar_EL1(heap_cap, "heap_cap");)
	DG1(if (capabilityValidCheck_EL1((void*)heap_cap, "heap_cap") == -1) {printf("\ncouldn't shrink heap capability!\n"); return -1;})
	DG1(printf("Finished running unique_alloc.........................\n");)
	DG1(printf("*********************************************\n");)
    //check for invalid capability tag WHEN NOT IN DEBUG
	nDG1(if (cheri_tag_get((void*)heap_cap) == 0){return -1;})

    return 0; //same as proteus

}

