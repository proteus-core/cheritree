#include "unprotected.h"
#include "performance.h"

#include <stdint.h>
#include <stdio.h>

struct args
{
    uintptr_t nonce;
    uintptr_t result;
};

static struct args* __attribute__((noinline)) sensor(struct args* args)
{
    args->result = 123;
    return args;
}

static void __attribute__((noinline)) user(struct args* args)
{
    struct args sensor_args;
    sensor_args.nonce = args->nonce;
    struct args* sensor_result = sensor(&sensor_args);

    if (sensor_result->nonce != args->nonce)
    {
        puts("error");
        return;
    }

    args->result = sensor_result->result * 2;
}

void unprotected_benchmark_start()
{
    struct args args;
    args.nonce = 42;

    uint64_t start = rdcycle();
    user(&args);
    uint64_t end = rdcycle();

    printf("unprotect: user result %u, took %llu cycles\n", args.result, end - start);
}
