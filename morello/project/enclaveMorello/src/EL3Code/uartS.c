/*
 ============================================================================
 Name        : uartS.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : secure UART header file for both non capability & capability modes
 ============================================================================
 */

// standard includes
#include <common/capfuncs.h>
#include <EL3Code/uartS.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
struct uart_struct_cap uartScap;


//-----------------------------------
// Define UART structure - for normal uart
// registers are defined in order to give correct offset
//-----------------------------------
struct uart_struct {
	    //define registers and there offset addr -  see Tech Ref Manual 3.2 Summary of registers
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
struct uart_struct* uartS;

//--------------------------------------------------------------------
// UART functions - purecap
//--------------------------------------------------------------------
//--------------------------------------------------------------------
// uartScapSetup - set up uart with capabilities
// for capability uart
//--------------------------------------------------------------------
void uartScapSetup(void* UARTrootCap)

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
	uartScap.UARTDR = UARTrootCap;
    // +0x04 - Error clear register
	uartScap.UARTECR = UARTrootCap+UARTECR_offset; //can just increase pointer offset like this in purecap
    // +0x18 - RO
	uartScap.UARTFR = UARTrootCap+UARTFR_offset;
    // +0x24 - integer baud rate register
	uartScap.UARTIBRD = UARTrootCap+UARTIBRD_offset;
    // +0x28 - fractional baud rate register
	uartScap.UARTFBRD = UARTrootCap+UARTFBRD_offset;
    // +0x2C - line control register
	uartScap.UARTLCR_H = UARTrootCap+UARTLCR_H_offset;
    // +0x30
	uartScap.UARTCR = UARTrootCap+UARTCR_offset;
    // +0x38 - Interrupt mask set/clear register
	uartScap.UARTIMSC =UARTrootCap+UARTIMSC_offset;
    // +0x44 - WO - Interrupt Clear Register
	uartScap.UARTICR = UARTrootCap+UARTICR_offset;
	//--------------------------------------------------------------------

	//--------------------------------------------------------------------
	//write to uart registers to set them up
	//--------------------------------------------------------------------
	// Reset the control register and disable the UART.
	*uartScap.UARTCR  = 0x0;
	// Reset the error-clear register
	*uartScap.UARTECR   = 0x0;
	// Reset UARTLCR_H register, and then set the word length to 8 bits
	*uartScap.UARTLCR_H = 0x0 | LCR_H_WLEN ;
	// Set the integer baud rate register
	*uartScap.UARTIBRD = IBRD_DIV;
	// Set the fractional baud rate register
	*uartScap.UARTFBRD = FBRD_DIV;
	// Clear the interrupt mask set/clear register
	*uartScap.UARTIMSC = 0x0;
	// Clear all the interrupts in the interrupt clear register
	*uartScap.UARTICR  = ICR_CLR_ALL;  // Clear interrupts
	//Enable the transmit and receive, and the UART
	*uartScap.UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  #endif
}

//--------------------------------------------------------------------
// uartScapTransmitString - write a string of characters to uart terminal
// for capability uart
//--------------------------------------------------------------------
void uartScapTransmitString(const char* uartstr)
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
		   while ((*uartScap.UARTFR & FR_TXFF) != 0x0) {}

		   // Write character into transmit holding register
		   *uartScap.UARTDR = uartstr[i];

		   // Write a carriage return at the end
		   if ((char)uartstr[i] == '\n')
		   {
			 //need to move to start of row because \n just goes onto next line
			 //under same point finished
		     while ((*uartScap.UARTFR & FR_TXFF) != 0x0) {}
		     *uartScap.UARTDR = '\r';
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
void uartSSetup(void* addr)
{
  // Create UART
  uartS = (struct uart_struct*) addr;
  // Reset the control register and disable the UART.
  uartS->UARTCR  = 0x0;
  // Reset the error-clear register
  uartS->UARTECR   = 0x0;
  // Reset UARTLCR_H register, and then set the word length to 8 bits
  uartS->UARTLCR_H = 0x0 | LCR_H_WLEN ;
  // Set the integer baud rate register
  uartS->UARTIBRD = IBRD_DIV;
  // Set the fractional baud rate register
  uartS->UARTFBRD = FBRD_DIV;
  // Clear the interrupt mask set/clear register
  uartS->UARTIMSC = 0x0;
  // Clear all the interrupts in the interrupt clear register
  uartS->UARTICR  = ICR_CLR_ALL;  // Clear interrupts
  //Enable the transmit and receive, and the UART
  uartS->UARTCR  = 0x0 | CR_UARTEN | CR_TXE | CR_RXE;
  return;
}
//--------------------------------------------------------------------
// uartSTransmitString - write a string of characters to uart terminal
// for normal uart
//--------------------------------------------------------------------
void uartSTransmitString(const char* uartstr)
{
int i; // index
int lengthstr; //length of string

   //output string
   lengthstr = strlen(uartstr);
   for( i = 0 ; i <= lengthstr; i++ )
   {
	   // Wait until transmit holding register has space
	   while ((uartS->UARTFR & FR_TXFF) != 0x0) {}

	   // Write character into transmit holding register
	   uartS->UARTDR = uartstr[i];

	   // Write a carriage return at the end
	   if ((char)uartstr[i] == '\n')
	   {
		 //need to move to start of row because \n just goes onto next line
		 //under same point finished
	     while ((uartS->UARTFR & FR_TXFF) != 0x0) {}
	     uartS->UARTDR = '\r';
	   }
   }

return;
}
