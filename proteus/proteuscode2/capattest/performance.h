#ifndef PERFORMANCE_H
#define PERFORMANCE_H

#include <stdint.h>

uint64_t rdcycle();
uint64_t rdinstret();
void sleep(uint64_t sleep_time);

#endif