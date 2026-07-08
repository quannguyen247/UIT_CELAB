#include "io.h"
#include "stdio.h"
#include "system.h"
#include "sys/alt_irq.h"

#define DMA_BASE       DMA_0_BASE
#define DMA_REG_RM     0
#define DMA_REG_WM     4
#define DMA_REG_LEN    8
#define DMA_REG_CTRL   12
#define DMA_REG_STATUS 28

#define DMA_CTRL_GO_BIT     3
#define DMA_CTRL_IRQ_EN_BIT 4

#define DMA_STATUS_DONE_BIT 0
#define DMA_STATUS_IRQ_BIT  2

static volatile int dma_done = 0;

static void dma_isr(void *context)
{
    volatile int status = IORD_32DIRECT(DMA_BASE, DMA_REG_STATUS);
    if (status & (1 << DMA_STATUS_DONE_BIT)) {
        dma_done = 1;
        IOWR_32DIRECT(DMA_BASE, DMA_REG_STATUS,
                      (1 << DMA_STATUS_DONE_BIT) | (1 << DMA_STATUS_IRQ_BIT));
    }
}

static void handlerStatus(char *pdata1)
{
    int i;
    for (i = 0; i < 32; i++) {
        printf("Byte %d = %d\n", i, pdata1[i]);
    }
}

int main(void)
{
    char pdata0[32] = {
        0, 1, 2, 3, 4, 5, 6, 7,
        8, 9, 10, 11, 12, 13, 14, 15,
        16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31
    };
    char *pdata1 = (char *)(ONCHIP_MEMORY2_1_BASE);

#if (DMA_0_IRQ < 0)
    printf("DMA IRQ not connected. Update Qsys and regenerate BSP.\n");
    return 0;
#else
#ifdef ALT_ENHANCED_INTERRUPT_API_PRESENT
    alt_ic_isr_register(DMA_0_IRQ_INTERRUPT_CONTROLLER_ID, DMA_0_IRQ, dma_isr, NULL, NULL);
#else
    alt_irq_register(DMA_0_IRQ, NULL, dma_isr);
#endif
#endif

    IOWR_32DIRECT(DMA_BASE, DMA_REG_RM, (int)pdata0);
    IOWR_32DIRECT(DMA_BASE, DMA_REG_WM, (int)pdata1);
    IOWR_32DIRECT(DMA_BASE, DMA_REG_LEN, 32);
    IOWR_32DIRECT(DMA_BASE, DMA_REG_CTRL,
                  (1 << DMA_CTRL_GO_BIT) | (1 << DMA_CTRL_IRQ_EN_BIT));

    while (!dma_done) {
        __asm__ volatile ("nop");
    }

    handlerStatus(pdata1);
    return 0;
}
