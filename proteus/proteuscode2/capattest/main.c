#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "performance.h"
#include "capattest.h"
#include "unique_alloc.h"

void print_cap(const capability* cap)
{
    printf("tag=%d, base=%08x, offset=%08x, len=%08x, perm=%03x, type=%08x",
           cheri_get_tag(cap),
           cheri_get_base(cap),
           cheri_get_offset(cap),
           cheri_get_len(cap),
           cheri_get_perm(cap),
           cheri_get_type(cap)
    );
}

void print_named_cap(const char* name, const capability* cap)
{
    printf("[%s] ", name);
    print_cap(cap);
}

void print_enclave(const struct enclave* enclave)
{
    print_named_cap("code", &enclave->code_cap);
    putchar('\n');
    print_named_cap("data", &enclave->data_cap);
    putchar('\n');
    print_named_cap("enc ", &enclave->enc_seal);
    putchar('\n');
    print_named_cap("sign", &enclave->sign_seal);
    putchar('\n');
}

void print_bytes(uint8_t* bytes, size_t len)
{
    for (size_t i = 0; i < len; ++i)
        printf("%02x", bytes[i]);
}

static void copy_code(capability* dst, const void* src, size_t len)
{
    capability src_cap;
    cheri_read_ddc(&src_cap);
    cheri_set_addr(&src_cap, (uintptr_t)src);
    cheri_memcpy(dst, &src_cap, len);
}

void load_enclave(const void* code_start, const void* code_end,
                  size_t data_length,
                  struct enclave* enclave)
{
    printf("load_enclave [%p, %p)\n", code_start, code_end);
    size_t code_len = (uintptr_t)code_end - (uintptr_t)code_start;

    capability code_cap, data_cap;
    unique_alloc(&code_cap, code_len);
    unique_alloc(&data_cap, data_length);


    printf("relocating enclave from %p to %p\n",
           code_start, (void*)cheri_get_addr(&code_cap));
    copy_code(&code_cap, code_start, code_len);

    printf("Initializing enclave\n");
    uint64_t start = rdcycle();
    enclave_init(&code_cap, &data_cap, enclave);
    uint64_t end = rdcycle();

    printf("enclave_init took %llu cycles\n", end - start);
    print_enclave(enclave);

    struct enclave_id id;

    start = rdcycle();
    enclave_store_id(enclave, &id);
    end = rdcycle();

    printf("enclave_store_id took %llu cycles\n", end - start);
    printf("id: ");
    print_bytes(id.hash, ENCLAVE_ID_LEN);
    putchar('\n');
}

int main()
{
    extern void trusted_init();
    trusted_init();

    printf("capattest demo booted in %llu cycles\n", rdcycle());

    puts("loading sensor enclave");
    extern char sensor_code_start, sensor_code_end;
    struct enclave sensor;
    load_enclave(&sensor_code_start, &sensor_code_end, 1024, &sensor);

    puts("loading user enclave");
    extern char user_code_start, user_code_end;
    struct enclave user;
    load_enclave(&user_code_start, &user_code_end, 1024, &user);

    capability sensor_cap;
    cheri_read_ddc(&sensor_cap); // FIXME root capability
    cheri_set_addr(&sensor_cap, (uintptr_t)&sensor);
    cheri_set_bounds_exact(&sensor_cap, sizeof(sensor));

    puts("invoking user.set_sensor_enclave");
    capability result;

    uint64_t start = rdcycle();
    enclave_invoke(&user, &sensor_cap, 1, &result);
    uint64_t end = rdcycle();

    printf("user.set_sensor_enclave took %llu cycles\n", end - start);

    if (cheri_get_tag(&result))
        puts("ok");
    else
    {
        puts("failed");
        return 1;
    }

    uint32_t nonce = 42;
    uint32_t args[] = {nonce, 0};

    capability args_cap;
    cheri_read_ddc(&args_cap); // FIXME root capability
    cheri_set_addr(&args_cap, (uintptr_t)&args);
    cheri_set_bounds_exact(&args_cap, sizeof(args));

    printf("invoking user.use_sensor(nonce=%u)\n", nonce);

    start = rdcycle();
    enclave_invoke(&user, &args_cap, 2, &result);
    end = rdcycle();

    printf("user.use_sensor took %llu cycles\n", end - start);

    if (cheri_get_tag(&result))
    {
        cheri_unseal(&result, &user.sign_seal);
        uint32_t nonce = cheri_lw(&result);
        cheri_inc_offset(&result, 4);
        uint32_t value = cheri_lw(&result);
        printf("ok: nonce=%u, value=%u\n", nonce, value);
    }
    else
    {
        puts("failed");
        return 1;
    }
}
