//SHA adapter
#define _GNU_SOURCE
#include<assert.h>
#include<inttypes.h>
#include<stdbool.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<time.h>
#include "sha-2/sha-256.h"

#include "shadapter.h"

//Copied from source of `sail.c`
/*
 * Temporary mpzs for use in functions below. To avoid conflicts, only
 * use in functions that do not call other functions in this file.
 */
static sail_int sail_lib_tmp1;

static void normalize_lbits(lbits *rop) {
  /* TODO optimisation: keep a set of masks of various sizes handy */
  mpz_set_ui(sail_lib_tmp1, 1);
  mpz_mul_2exp(sail_lib_tmp1, sail_lib_tmp1, rop->len);
  mpz_sub_ui(sail_lib_tmp1, sail_lib_tmp1, 1);
  mpz_and(*rop->bits, *rop->bits, sail_lib_tmp1);
}


static struct Sha_256 sha_256;
static uint8_t hash[32];

unit SHA256_reset(unit u)
{
  //Reset global variables
  sha_256_init(&sha_256, hash);
  return UNIT;
}

unit SHA256_append(const lbits op1)
{
  size_t nb_bytes = (op1.len + CHAR_BIT - 1) / CHAR_BIT; //`op1.len` is number of bits
  assert(nb_bytes * 8 == op1.len); // no half-byte length

  //Variable to store the number of written bytes into
  size_t written_bytes;

  //Let `mpz_export` allocate for us; easier to avoid problems with leading 0 bytes
  uint8_t* array = mpz_export(NULL,&written_bytes,1,sizeof(uint8_t), 1, 0, *op1.bits);

  size_t nb_leading_zerob = nb_bytes - written_bytes;
  assert(written_bytes + nb_leading_zerob == nb_bytes);

  //Write leading 0's first
  if (nb_leading_zerob > 0) {
      uint8_t* leading_0_array = calloc(nb_leading_zerob, sizeof(uint8_t));
      sha_256_write(&sha_256, leading_0_array, sizeof(uint8_t) * nb_leading_zerob);
      free(leading_0_array);
   }

  sha_256_write(&sha_256, array, sizeof(uint8_t) * written_bytes);
  free(array);
  return UNIT;
}

void SHA256_finish(lbits *rop, unit u)
{
  sha_256_close(&sha_256);

  rop->len = 256;
  mpz_import(*rop->bits, 32, 1, sizeof(uint8_t), 1, 0, hash);
  normalize_lbits(rop);
}
