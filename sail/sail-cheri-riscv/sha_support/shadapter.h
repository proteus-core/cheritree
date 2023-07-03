#ifndef SHA_H
#define SHA_H

#include <gmp.h>

//Replicate types from `sail.h` header
#include "sail.h"

unit SHA256_reset(unit);
unit SHA256_append(const lbits);
void SHA256_finish(lbits *, unit);

#endif
