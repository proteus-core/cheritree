/*
 ============================================================================
 Name        : uartEL2N.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : non secure UART functions for EL2 non secure memory
 ============================================================================
 */

//*************************************************************
// INCLUDES
//**************************************************************
#include <common/capfuncs.h>
#include <stdio.h>
#include <string.h>
#include <uartEL2N.h>

//*************************************************************
// DEFINES
//*************************************************************

//define attributes for non secure memory sections
// this is used by the linker script to place non secure program code into non secure memory
// attributes can be assigned to functions and global variables
#define UART_FUNC  __attribute__((__section__(".NONSECUREuartFuncSection_c_el2")))
#define UART_STRUCT  __attribute__((__section__(".NONSECUREuartStructSection_c_el2")))

//--------------------------------------------------------------------
// Define UART structure of capabilities
//--------------------------------------------------------------------
// set up structure of capabilities - do not need to rely on position, each reg set seperately
struct uartEL2N_struct_cap {
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
struct uartEL2N_struct_cap uartEL2Ncap UART_STRUCT;


//-----------------------------------
// Define UART structure - for normal uart
// registers are defined in order to give correct offset
//-----------------------------------
struct uartEL2N_struct {
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

//use the UART_STRUCT attribute to make sure the variable is put in non secure memory
struct uartEL2N_struct* uartEL2N UART_STRUCT;

//*************************************************************
// FUNCTIONS
//*************************************************************

//--------------------------------------------------------------------
// UART functions - purecap
//--------------------------------------------------------------------
//--------------------------------------------------------------------
// uartScapSetup - set up uart with capabilities
// for capability uart
//--------------------------------------------------------------------
void UART_FUNC uartEL2NcapSetup(void* UARTrootCap)

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
	uartEL2Ncap.UARTDR = UARTrootCap;
    // +0x04 - Error clear register
	uartEL2Ncap.UARTECR = UARTrootCap+UARTECR_offset; //can just increase pointer offset like this in purecap
    // +0x18 - RO;
	uartEL2Ncap.UARTFR = UARTrootCap+UARTFR_offset;
    // +0x24 - integer baud rate register
	uartEL2Ncap.UARTIBRD = UARTrootCap+UARTIBRD_offset;
    // +0x28 - fractional baud rate register
	uartEL2Ncap.UARTFBRD = UARTrootCap+UARTFBRD_offset;
    // +0x2C - line control register
	uartEL2Ncap.UARTLCR_H = UARTrootCap+UARTLCR_H_offset;
    // +0x30
	uartEL2Ncap.UARTCR = UARTrootCap+UARTCR_offset;
    // +0x38 - Interrupt mask set/clear register
	uartEL2Ncap.UARTIMSC =UARTrootCap+UARTIMSC_offset;
    // +0x44 - WO - Interrupt Clear Register
	uartEL2Ncap.UARTICR = UARTrootCap+UARTICR_offset;
	//--------------------------------------------------------------------

	//--------------------------------------------------------------------
	//write to uart registers to set them up
	//--------------------------------------------------------------------
	// Reset the control register and disable the UART.
	*uartEL2Ncap.UARTCR  = 0x0;
	// Reset the error-clear register
	*uartEL2Ncap.UARTECR   = 0x0;
	// Reset UARTLCR_H register, and then set the word length to 8 bits
//	*uartEL2Ncap.UARTLCR_H = 0x0 | LCR_H_WLEN ;
	// Set the integer baud rate register
//	*uartEL2Ncap.UARTIBRD = IBRD_DIV;
	// Set the fractional baud rate register
//	*uartEL2Ncap.UARTFBRD = FBRD_DIV;
	// Clear the interrupt mask set/clear register
	*uartEL2Ncap.UARTIMSC = 0x0;
	// Clear all the interrupts in the interrupt clear register
	*uartEL2Ncap.UARTICR  = ICR_CLR_ALL;  // Clear interrupts
	//Enable the transmit and receive, and the UART
	*uartEL2Ncap.UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  #endif
}

//--------------------------------------------------------------------
// uartScapTransmitString - write a string of characters to uart terminal
// for capability uart
//--------------------------------------------------------------------
void UART_FUNC uartEL2NcapTransmitString(const char* uartstr)
{
  #ifdef __CHERI_PURE_CAPABILITY__
	//--------------------------------------------------------------------
	// write string
	//--------------------------------------------------------------------
	int i; // index
	int lengthstr; //length of string

	   //output string
	   lengthstr = strlen(uartstr);
	   for( i = 0 ; i <= lengthstr; i++ )
	   {
		   // Wait until transmit holding register has space
		   while ((*uartEL2Ncap.UARTFR & FR_TXFF) != 0x0) {}

		   // Write character into transmit holding register
		   *uartEL2Ncap.UARTDR = uartstr[i];

		   // Write a carriage return at the end
		   if ((char)uartstr[i] == '\n')
		   {
			 //need to move to start of row because \n just goes onto next line
			 //under same point finished
		     while ((*uartEL2Ncap.UARTFR & FR_TXFF) != 0x0) {}
		     *uartEL2Ncap.UARTDR = '\r';
		   }
	   }
  #endif
}

//--------------------------------------------------------------------
// UART functions - for normal uart
//--------------------------------------------------------------------
// ------------------------------------------------------------
// Functions
//-------------------------------------------------------------
//--------------------------------------------------------------------
// uartSSetup
// This function sets up the UART
// for normal uart
//--------------------------------------------------------------------
void UART_FUNC uartEL2NSetup(void* addr)
{
  // Create UART
  uartEL2N = (struct uartEL2N_struct*) addr;
  // Reset the control register and disable the UART.
  uartEL2N->UARTCR  = 0x0;
  // Reset the error-clear register
  uartEL2N->UARTECR   = 0x0;
  // Reset UARTLCR_H register, and then set the word length to 8 bits
  uartEL2N->UARTLCR_H = 0x0 | LCR_H_WLEN ;
  // Set the integer baud rate register
  uartEL2N->UARTIBRD = IBRD_DIV;
  // Set the fractional baud rate register
  uartEL2N->UARTFBRD = FBRD_DIV;
  // Clear the interrupt mask set/clear register
  uartEL2N->UARTIMSC = 0x0;
  // Clear all the interrupts in the interrupt clear register
  uartEL2N->UARTICR  = ICR_CLR_ALL;  // Clear interrupts
  //Enable the transmit and receive, and the UART
  uartEL2N->UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  return;
}

//-----------------------------------------------------------
// uartTransmitString
// This function transmits a string of characters to the UART
// We can not use any c lib functions such as strlen when using a
// single executable
//-----------------------------------------------------------
void UART_FUNC uartEL2NTransmitString(const char* uartstrN)
{
int i; // index

i=0;
// can't use strlen so look for null character instead
while (uartstrN[i] != '\0')
	{
	  //make sure holding register ready
	  while ((uartEL2N->UARTFR & FR_TXFF) != 0x0) {}
	  //write char
	  uartEL2N->UARTDR = uartstrN[i];
	  // Write a carriage return at the end
	  if ((char)uartstrN[i] == '\n')
	     {
		   //need to move to start of row because \n just goes onto next line
		   //under same point finished
	       while ((uartEL2N->UARTFR & FR_TXFF) != 0x0) {}
	       uartEL2N->UARTDR = '\r';
	     }
	  i=i+1;
	}

return;
}

