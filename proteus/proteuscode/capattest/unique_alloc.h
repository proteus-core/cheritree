#ifndef UNIQUE_ALLOC_H
#define UNIQUE_ALLOC_H

#include "cheri.h"

#include <stddef.h>

void unique_alloc_init(const capability* heap);
void unique_alloc(capability* dst, size_t size);

#endif
