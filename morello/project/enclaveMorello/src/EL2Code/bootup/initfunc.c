/*
 ============================================================================
 Name        : initfunc.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : init and fini stubs
 ============================================================================
 */
//*****************************************
// DEFINES
//*****************************************
#define LOCATE_FUNC  __attribute__((__section__(".NONSECUREsection_c_el2")))

void LOCATE_FUNC _init (void)
{
}

void LOCATE_FUNC _fini (void)
{
}

