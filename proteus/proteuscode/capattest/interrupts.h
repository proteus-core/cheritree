#ifndef INTERRUPTS_H
#define INTERRUPTS_H

typedef enum
{
    IRQ_USI = 0,
    IRQ_SSI = 1,
    IRQ_MSI = 3,
    IRQ_UTI = 4,
    IRQ_STI = 5,
    IRQ_MTI = 7,
    IRQ_UEI = 8,
    IRQ_SEI = 9,
    IRQ_MEI = 11
} irq_cause;

typedef void (*isr_callback)(void);

void register_isr(irq_cause cause, isr_callback callback);
void enable_interrupts(void);
void disable_interrupts(void);
void enable_irq(irq_cause cause);
void disable_irq(irq_cause cause);

#endif
