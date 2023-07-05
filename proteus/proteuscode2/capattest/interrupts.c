#include "interrupts.h"

#include "mtimer.h"
#include "chardev.h"

#include <stdio.h>

static void ignore_irq()
{
    puts("IRQ ignored");
}

static isr_callback callbacks[12] = {
    ignore_irq, ignore_irq, ignore_irq, ignore_irq,
    ignore_irq, ignore_irq, ignore_irq, ignore_irq,
    ignore_irq, ignore_irq, ignore_irq, ignore_irq
};

void register_isr(irq_cause cause, isr_callback callback)
{
    callbacks[cause] = callback;
}

void enable_interrupts()
{
    asm("csrs mstatus, 0x8");
}

void disable_interrupts()
{
    asm("csrc mstatus, 0x8");
}

void enable_irq(irq_cause cause)
{
    asm("csrs mie, %0" : : "r"(1 << cause));
}

void disable_irq(irq_cause cause)
{
    asm("csrc mie, %0" : : "r"(1 << cause));
}

void isr(long code)
{
    callbacks[code]();
}
