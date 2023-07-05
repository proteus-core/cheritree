#ifndef MTIMER_H
#define MTIMER_H

#include <stdint.h>

#define MTIME    *(volatile uint64_t*)0x02000000
#define MTIMECMP *(volatile uint64_t*)0x02000008

#endif
