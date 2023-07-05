#include "performance.h"
#include <stdint.h>


uint64_t rdcycle()
{
    uint32_t rdcycleh;
    uint32_t rdcycle;
    uint32_t rdcycleh_check;
    do
    {
        asm volatile ("rdcycleh %0" : "=r"(rdcycleh));
        asm volatile ("rdcycle %0" : "=r"(rdcycle));
        asm volatile ("rdcycleh %0" : "=r"(rdcycleh_check));
    }while(rdcycleh != rdcycleh_check);
    uint64_t cycles = (uint64_t) rdcycleh << 32 | rdcycle;
    return cycles;
}

uint64_t rdinstret()
{
    uint32_t rdinstreth_check;
    uint32_t rdinstret;
    uint32_t rdinstreth;
    do
    {
        asm volatile ("rdinstreth %0" : "=r"(rdinstreth));
        asm volatile ("rdinstret %0" : "=r"(rdinstret));
        asm volatile ("rdinstreth %0" : "=r"(rdinstreth_check));
    }while(rdinstreth != rdinstreth_check);
    uint64_t instret = (uint64_t) rdinstreth << 32 | rdinstret;
    return instret;
}

void sleep(uint64_t sleep_time)
{   
    uint64_t end_time = rdcycle() + sleep_time;
    uint64_t current_time = rdcycle();
    while(current_time < end_time)
    {
        current_time = rdcycle();
    }
}
