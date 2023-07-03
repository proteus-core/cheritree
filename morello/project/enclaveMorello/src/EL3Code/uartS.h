/*
 ============================================================================
 Name        : uartS.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : secure UART header file for both non capability & capability modes
 ============================================================================
 */
#ifndef __uartS_h
#define __uartS_h

//------------------------------------------
// Define values for the UART register bits
//-------------------------------------------
//UARTLCR_H - line control register bits used
//Note: bit[4] FIFO not set, so disabled, this means TXFF is set to one when the transmit holding register is full.
//number of data bits transmitted or received in a frame as follows:
#define LCR_H_WLEN   (0x60) //value b11 = 8 bits, bit[6:5] WLEN of UARTLCR_H

//UARTFR - UART flag register bits used
#define FR_TXFF        (0x20) //BIT[5] TXFF - If the FIFO is disabled, this bit is set when the transmit holding register is full.

//UARTICR - UART interrupt clear register bits used
#define ICR_CLR_ALL    (0x07FF) //bits[10:0] - clears all the interrupts

//UARTIBRD - UART integer baud rate register
//38400 bits per second (baud rate)
//See uart technical reference manual for calculations
//used by ARM with 38400 baud rate
#define IBRD_DIV      (0x27) //value - integer part of the baud rate divisor value.
//UARTFBRD - UART fractional baud rate register
#define FBRD_DIV      (0x09) //value - fractional part of the baud rate divisor value.

//UARTCR - UART Control register bits used
#define CR_UARTEN      (0x01) // bit[0] UARTEN - UART enable
#define CR_TXE        (0x0100) //bit[8] TXE - Transmit enable
#define CR_RXE        (0x0200) //bit[9] RXE - Receive enable


//------------------------------------------
// Define values for the UART register offsets
// used in capability mode
//-------------------------------------------

#define UARTECR_offset 0x04  // +0x04 - Error clear register offset
#define reserved0_offset 0x08// +0x08 to +0x14 reserved
#define UARTFR_offset 0x18       // +0x18 - RO
#define reserved1_offset 0x1c   // +0x1C reserved
#define UARTILPR_offset 0x20     //NOT USED +0x20
#define UARTIBRD_offset 0x24    // +0x24 - integer baud rate register
#define UARTFBRD_offset 0x28     // +0x28 - fractional baud rate register
#define UARTLCR_H_offset 0x2c    // +0x2C - line control register
#define UARTCR_offset 0x30       // +0x30
#define UARTIFLS_offset 0x34     //NOT USED +0x34
#define UARTIMSC_offset 0x38     // +0x38 - Interrupt mask set/clear register
#define UARTRIS_offset 0x3c      //NOT USED +0x3C - RO
#define UARTMIS_offset 0x40      //NOT USED +0x40 - RO
#define UARTICR_offset 0x44      // +0x44 - WO - Interrupt Clear Register
#define UARTDMACR_offset 0x48    // +0x48


//------------------------------------------
// UART functions
//-------------------------------------------

//capability based uart functions
//set up the uart from the given uart root capability
void uartScapSetup(void* UARTrootCap);
//print strings to uart
void uartScapTransmitString(const char* uartstr);

//normal uart functions
//set up the uart from a given address
void uartSSetup(void* addr);
//print strings to uart
void uartSTransmitString(const char* uartstr);

#endif
