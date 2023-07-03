/*
 ============================================================================
 Name        : performance.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL2/EL3 functions to measure number of cycles using the cycle counter register
 ============================================================================
 */
#ifndef PERFORMANCE_H
#define PERFORMANCE_H

void setup_cycle_counterEL1(void); //count cycles in EL1 only
void setup_cycle_counterEL1and2(void); //count cycles in EL1 and EL2
unsigned long int read_cycle_counter(void);
void enable_cycle_counter(void);
void disable_cycle_counter(void);
void reset_cycle_counter(void); //reset

#endif
