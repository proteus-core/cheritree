/*
 ============================================================================
 Name        : uartN_redirect.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : UART functions containing re-direct for printf
 ============================================================================
 */

//*************************************************************
// INCLUDES
//**************************************************************

//need to put into non secure memory region
#define LOCATE_FUNC  __attribute__((__section__(".NONSECUREuartFuncSection_c")))
//check this because gives warnings when included by the compiler
#define LOCATE_STRUCT  __attribute__((__section__(".NONSECUREuartStructSection_c")))

// standard includes
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// uart includes
#include <uartN_redirect.h>

//capability mode includes
#ifdef __CHERI_PURE_CAPABILITY__
	//#include <cheriintrin.h>
#endif

#ifdef __CHERI_PURE_CAPABILITY__
//--------------------------------------------------------------------
// Define UART structure of capabilities
//--------------------------------------------------------------------
// set up structure of capabilities - do not need to rely on position, each reg set seperately
struct uart_struct_cap {
	    //define registers and there offset addr -  see Tech Ref Manual 3.2 Summary of registers
        volatile unsigned int* UARTDR;        // +0x00 - Data register
        volatile unsigned int* UARTECR;       // +0x04 - Error clear register
//  const volatile unsigned int* reserved0[4];  // +0x08 to +0x14 reserved
  const volatile unsigned int* UARTFR;        // +0x18 - RO
// const volatile unsigned int* reserved1;     // +0x1C reserved
// 	  	volatile unsigned int* UARTILPR;      //NOT USED +0x20
        volatile unsigned int* UARTIBRD;      // +0x24 - integer baud rate register
        volatile unsigned int* UARTFBRD;      // +0x28 - fractional baud rate register
        volatile unsigned int* UARTLCR_H;     // +0x2C - line control register
        volatile unsigned int* UARTCR;        // +0x30
//        volatile unsigned int* UARTIFLS;      //NOT USED +0x34
        volatile unsigned int* UARTIMSC;      // +0x38 - Interrupt mask set/clear register
//        volatile unsigned int* UARTRIS;       //NOT USED +0x3C - RO
//  const volatile unsigned int* UARTMIS;       //NOT USED +0x40 - RO
        volatile unsigned int* UARTICR;       // +0x44 - WO - Interrupt Clear Register
        volatile unsigned int* UARTDMACR;     // +0x48
};
//not a pointer - this is an instance
struct uart_struct_cap uartNcap LOCATE_STRUCT;
#endif

//-----------------------------------
// Define UART structure - for normal uart
// registers are defined in order to give correct offset
//-----------------------------------
struct uart_struct {
	    //define registers and there offset addr -  see Tech Ref Manual 3.2 Summary of registers
        // names are as defined in the table
		volatile unsigned int UARTDR;        // +0x00 - Data register
        volatile unsigned int UARTECR;       // +0x04 - Error clear register
  const volatile unsigned int reserved0[4];  // +0x08 to +0x14 reserved
  const volatile unsigned int UARTFR;        // +0x18 - RO
  const volatile unsigned int reserved1;     // +0x1C reserved
  	  	volatile unsigned int UARTILPR;      //NOT USED +0x20
        volatile unsigned int UARTIBRD;      // +0x24 - integer baud rate register
        volatile unsigned int UARTFBRD;      // +0x28 - fractional baud rate register
        volatile unsigned int UARTLCR_H;     // +0x2C - line control register
        volatile unsigned int UARTCR;        // +0x30
        volatile unsigned int UARTIFLS;      //NOT USED +0x34
        volatile unsigned int UARTIMSC;      // +0x38 - Interrupt mask set/clear register
        volatile unsigned int UARTRIS;       //NOT USED +0x3C - RO
  const volatile unsigned int UARTMIS;       //NOT USED +0x40 - RO
        volatile unsigned int UARTICR;       // +0x44 - WO - Interrupt Clear Register
        volatile unsigned int UARTDMACR;     // +0x48
};
//this is a pointer
struct uart_struct* uartN LOCATE_STRUCT;


//*************************************************************
// Functions
//*************************************************************

//--------------------------------------------------------------------
// UART functions - purecap
//--------------------------------------------------------------------
//--------------------------------------------------------------------
// uartNcapSetup - set up uart with capabilities
// for capability uart
//--------------------------------------------------------------------
void LOCATE_FUNC uartNcapSetup(void* UARTrootCap)

{
  #ifdef __CHERI_PURE_CAPABILITY__
	//--------------------------------------------------------------------
	// set up a capability for each uart register derived from the
	// root uart capability memory space
	// it is assumed that UARTrootCap is set up to point to the base address
	// of the UART memory space, and it's bound spans all the necessary
	// contiguous UART registers
	//--------------------------------------------------------------------
	// +0x00 - Data register
	uartNcap.UARTDR = UARTrootCap;
    // +0x04 - Error clear register
	uartNcap.UARTECR = UARTrootCap+UARTECR_offset; //just increment to get offset
    // +0x18 - RO
	uartNcap.UARTFR = UARTrootCap+UARTFR_offset;
    // +0x24 - integer baud rate register
	uartNcap.UARTIBRD = UARTrootCap+UARTIBRD_offset;
    // +0x28 - fractional baud rate register
	uartNcap.UARTFBRD = UARTrootCap+UARTFBRD_offset;
    // +0x2C - line control register
	uartNcap.UARTLCR_H = UARTrootCap+UARTLCR_H_offset;
    // +0x30
	uartNcap.UARTCR = UARTrootCap+UARTCR_offset;
    // +0x38 - Interrupt mask set/clear register
	uartNcap.UARTIMSC = UARTrootCap+UARTIMSC_offset;
    // +0x44 - WO - Interrupt Clear Register
	uartNcap.UARTICR = UARTrootCap+UARTICR_offset;
	//--------------------------------------------------------------------

	//--------------------------------------------------------------------
	//write to uart registers to set them up
	//--------------------------------------------------------------------
	// Reset the control register and disable the UART.
	*uartNcap.UARTCR  = 0x0;
	// Reset the error-clear register
	*uartNcap.UARTECR   = 0x0;
//Already setup when reach EL2 by normal boot
//values (baud rate) defined here probably not correct because doesn't work when used
	// Reset UARTLCR_H register, and then set the word length to 8 bits
//	*uartNcap.UARTLCR_H = 0x0 | LCR_H_WLEN ;
	// Set the integer baud rate register
//	*uartNcap.UARTIBRD = IBRD_DIV;
	// Set the fractional baud rate register
//	*uartNcap.UARTFBRD = FBRD_DIV;
	// Clear the interrupt mask set/clear register
	*uartNcap.UARTIMSC = 0x0;
	// Clear all the interrupts in the interrupt clear register
	*uartNcap.UARTICR  = ICR_CLR_ALL;  // Clear interrupts
	//Enable the transmit and receive, and the UART
	*uartNcap.UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  #endif
}

//--------------------------------------------------------------------
// uartNcapTransmitString - write a string of characters to uart terminal
// for capability uart
//--------------------------------------------------------------------
void LOCATE_FUNC uartNcapTransmitString(const char* uartstr)
{
#ifdef __CHERI_PURE_CAPABILITY__
	//--------------------------------------------------------------------
	// write string
	// do not use any c lib functions such as strlen
	//--------------------------------------------------------------------
	int i; // index
	FILE *dummyfile;
	i=0;
	while (uartstr[i] != '\0')
	   {
		   // use fputc redirection to uart
		   fputccap(uartstr[i], dummyfile);
		   i=i+1;
	   }
#endif
}


//-----------------------------------------------------------
// fputccap
//-----------------------------------------------------------
int LOCATE_FUNC fputccap(int c, FILE *f)
{
#ifdef __CHERI_PURE_CAPABILITY__

   // Wait until transmit holding register has space
   while ((*uartNcap.UARTFR & FR_TXFF) != 0x0) {}

   // Write character into transmit holding register
   *uartNcap.UARTDR = c;

  // Write a carriage return at the end
  if ((char)c == '\n')
  {
	//need to move to start of row because \n just goes onto next line
	//under same point finished
	while ((*uartNcap.UARTFR & FR_TXFF) != 0x0) {}
	*uartNcap.UARTDR = '\r';
  }
#endif
return 0;
}

//--------------------------------------------------------------------
// UART functions - for normal uart
//--------------------------------------------------------------------
// ------------------------------------------------------------
// Functions
//-------------------------------------------------------------
//--------------------------------------------------------------------
// uartNSetup
// This function sets up the UART
// for normal uart
//--------------------------------------------------------------------
void LOCATE_FUNC uartNSetup(void* addr)
{
  // Create UART
  uartN = (struct uart_struct*) addr;
  // Reset the control register and disable the UART.
  uartN->UARTCR  = 0x0;
  // Reset the error-clear register
  uartN->UARTECR   = 0x0;
  // Reset UARTLCR_H register, and then set the word length to 8 bits
  uartN->UARTLCR_H = 0x0 | LCR_H_WLEN ;
  // Set the integer baud rate register
  uartN->UARTIBRD = IBRD_DIV;
  // Set the fractional baud rate register
  uartN->UARTFBRD = FBRD_DIV;
  // Clear the interrupt mask set/clear register
  uartN->UARTIMSC = 0x0;
  // Clear all the interrupts in the interrupt clear register
  uartN->UARTICR  = ICR_CLR_ALL;  // Clear interrupts
  //Enable the transmit and receive, and the UART
  uartN->UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  return;
}

//-----------------------------------------------------------
// uartNTransmitString
// This function transmits a string of characters
//-----------------------------------------------------------
void LOCATE_FUNC uartNTransmitString(const char* uartstr)
{
int i; // index
FILE *dummyfile;
   //output string
	i=0;
	while (uartstr[i] != '\0')
  {
	   // use fputc redirection to uart
	   fputc(uartstr[i], dummyfile);
	   i=i+1;
   }

return;
}

//-----------------------------------------------------------
// fputc
// re-direct c library fputc function to uart
// FILE not used
// Warning! - default printf doesn't use fputc so doesn't redirect
//-----------------------------------------------------------
int LOCATE_FUNC fputc(int c, FILE *f)
{

   // Wait until transmit holding register has space
   while ((uartN->UARTFR & FR_TXFF) != 0x0) {}

   // Write character into transmit holding register
  uartN->UARTDR = c;

  // Write a carriage return at the end
  if ((char)c == '\n')
  {
	//need to move to start of row because \n just goes onto next line
	//under same point finished
	while ((uartN->UARTFR & FR_TXFF) != 0x0) {}
	uartN->UARTDR = '\r';
  }
  return 0;
}

//-----------------------------------------------------------
// Joint function - redirect function for printf
//-----------------------------------------------------------

//-----------------------------------------------------------
// _putchar
// used to re-direct printf to uart (embedded version of printf),
// which uses _putchar function
// Warning! - default printf doesn't use fputc
//-----------------------------------------------------------
void LOCATE_FUNC _putchar(char character)
{
	int c = (int)character;

	#ifdef __CHERI_PURE_CAPABILITY__
	   // Wait until transmit holding register has space
	   while ((*uartNcap.UARTFR & FR_TXFF) != 0x0) {}

	   // Write character into transmit holding register
	   *uartNcap.UARTDR = c;

	  // Write a carriage return at the end
	  if ((char)c == '\n')
	  {
		//need to move to start of row because \n just goes onto next line
		//under same point finished
		while ((*uartNcap.UARTFR & FR_TXFF) != 0x0) {}
		*uartNcap.UARTDR = '\r';
	  }
	#else
	   // Wait until transmit holding register has space
	   while ((uartN->UARTFR & FR_TXFF) != 0x0) {}

	   // Write character into transmit holding register
	  uartN->UARTDR = c;

	  // Write a carriage return at the end
	  if ((char)c == '\n')
	  {
		//need to move to start of row because \n just goes onto next line
		//under same point finished
		while ((uartN->UARTFR & FR_TXFF) != 0x0) {}
		uartN->UARTDR = '\r';
	  }
#endif
}

