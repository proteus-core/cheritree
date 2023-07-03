/*
 ============================================================================
 Name        : performance_EL1.h
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL1 functions to measure number of cycles using the cycle counter register
 ============================================================================
 */
#ifndef PERFORMANCE_EL1_H
#define PERFORMANCE_EL1_H

void setup_cycle_counterEL1_EL1(void); //count cycles in EL1 only
void setup_cycle_counterEL1and2_EL1(void); //count cycles in EL1 and EL2
unsigned long int read_cycle_counter_EL1(void);
void enable_cycle_counter_EL1(void);
void disable_cycle_counter_EL1(void);
void reset_cycle_counter_EL1(void); //reset

#endif
