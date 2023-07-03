/*
 ============================================================================
 Name        : EL1Debug.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : supporting EL1 DEBUG functions for purecap mode debugging at EL1
 ============================================================================
 */

//need to put into non secure memory region
#define LOCATE_FUNC  __attribute__((__section__(".NONSECUREsection_c_el1")))

#ifdef __CHERI_PURE_CAPABILITY__
#include <cheriintrin.h>
#endif

#include <EL1Code/enclavecode/capattest.h> //defines enclave structure used below

#include <EL1Code/EL1Debug.h>//contains PRINTF_TO_UART_EL1 def so needs to come first
#ifdef PRINTF_TO_UART_EL1
#include <EL1Code/printf.h> //embedded printf function to redirect all printf in this file to uart
#include <EL1Code/uartN_redirect.h>
#endif

//-----------------------------------------------------------------
// print out capability parameters using printf
//-----------------------------------------------------------------

void LOCATE_FUNC printcapabilityPar_EL1(void * cap, const char* cap_str)
{
  #ifdef __CHERI_PURE_CAPABILITY__
	 printf(".............................................\n");
	 printf("Checking capability: %s\n",cap_str);
	 printf("base address of capability is: 0x%lx\n", cheri_base_get(cap));
	 printf("length of capability is: 0x%lx\n", cheri_length_get(cap));
	 printf("offset from base address of capability is: 0x%lx\n", cheri_offset_get(cap));
	 printf("value of capability is: 0x%lx\n", cheri_address_get(cap));
	 printf("limit address of capability is: 0x%lx\n", cheri_base_get(cap)+cheri_length_get(cap));
	 printf("permissions of capability is: 0x%x\n", cheri_perms_get(cap));
	 printf("otype of capability is: 0x%lx\n", cheri_type_get(cap));
	 printf("capability is sealed if 0x1: 0x%i\n",cheri_is_sealed(cap));
	 printf("tag of capability is: 0x%01x\n", cheri_tag_get(cap));
	 printf(".............................................\n");
  #endif
}

//-----------------------------------------------------------------
// capability print in different format
//-----------------------------------------------------------------
void LOCATE_FUNC print_cap_debug_EL1(void * cap, const char* cap_str)
{
#ifdef __CHERI_PURE_CAPABILITY__
	printf(".............................................\n");
	printf("Checking capability: %s\n",cap_str);
	printf("tag=%d, base=%08lx, offset=%08lx, len=%08lx,\n perm=%03x, type=%08lx, value=%08lx, limit=%08lx\n",
			cheri_tag_get(cap),
			cheri_base_get(cap),
			cheri_offset_get(cap),
			cheri_length_get(cap),
			cheri_perms_get(cap),
			cheri_type_get(cap),
			cheri_address_get(cap),
			cheri_base_get(cap)+cheri_length_get(cap));
	printf(".............................................\n");
#endif
}

//-----------------------------------------------------------------
// capability validity check
//-----------------------------------------------------------------
int LOCATE_FUNC capabilityValidCheck_EL1(void * cap, const char* cap_str)
{
  #ifdef __CHERI_PURE_CAPABILITY__
	//first check tag to avoid invalid capabilities being produced
	printf(".............................................\n");
	printf("checking validity of capability: %s\n", cap_str);
    //check for invalid capability tag
	if (cheri_tag_get(cap) == 0)
		{
		printf("Warning! - capability not valid!\n");
		printcapabilityPar_EL1(cap,cap_str);
		return -1;
		}
	else
	{
		printf("capability check ok....\n");
	};
  #endif
  return 0;
}

//-----------------------------------------------------------------
// enclave validity check
//-----------------------------------------------------------------
void LOCATE_FUNC print_enclave_debug_EL1(struct enclave* enclave)
{

printf("&enclave->code_cap=%p, &enclave->data_cap=%p, &enclave->enc_seal=%p, &enclave->sign_seal=%p, enc_seal=%p, sign_seal=%p\n",
           &enclave->code_cap,
           &enclave->data_cap,
           &enclave->enc_seal,
           &enclave->sign_seal,
           enclave->enc_seal,
           enclave->sign_seal
    );
}


