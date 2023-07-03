/*
 ============================================================================
 Name        : capfuncs.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : supporting DEBUG functions for purecap mode in trusted EL2/EL3
 ============================================================================
 */

//need to put into EL2 memory region
//!!Warning!! cheriintrin is not included more than once unless compiled as separate program for each EL
//CURRENTLY AUTOMATICALLY PLACED FOR EL2/3 - NOT YET PLACED IN LINKER SCRIPT
#define LOCATE_FUNC  __attribute__((__section__(".NONSECURECapssection_c")))


#include <stdio.h>
#include <stdlib.h>
#ifdef __CHERI_PURE_CAPABILITY__
#include <cheriintrin.h>
#endif

//-----------------------------------------------------------------
// print out capability parameters using printf
//-----------------------------------------------------------------

void LOCATE_FUNC printcapabilityPar(void * cap, const char* cap_str)
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
// capability validity check
//-----------------------------------------------------------------
int LOCATE_FUNC capabilityValidCheck(void * cap, const char* cap_str)
{
  #ifdef __CHERI_PURE_CAPABILITY__
	//first check tag to avoid invalid capabilities being produced
	printf(".............................................\n");
	printf("checking validity of capability: %s\n", cap_str);
    //check for invalid capability tag
	if (cheri_tag_get(cap) == 0)
		{
		printf("Warning! - capability not valid!\n");
		printcapabilityPar(cap,cap_str);
		return -1;
		}
	else
	{
		printf("capability check ok....\n");
	};
  #endif
  return 0;
}
