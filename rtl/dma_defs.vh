`ifndef DMA_DEFS
`define DMA_DEFS

// Register map (word offsets)
`define DMA_ADDR_RM_START 3'h0
`define DMA_ADDR_WM_START 3'h1
`define DMA_ADDR_LENGTH   3'h2
`define DMA_ADDR_CONTROL  3'h3
`define DMA_ADDR_STATUS   3'h7

// CONTROL register bit positions
`define DMA_CTRL_BYTE_BIT   0
`define DMA_CTRL_HW_BIT     1
`define DMA_CTRL_WORD_BIT   2
`define DMA_CTRL_GO_BIT     3
`define DMA_CTRL_IRQ_EN_BIT 4

// STATUS register bit positions
`define DMA_STATUS_DONE_BIT 0
`define DMA_STATUS_BUSY_BIT 1
`define DMA_STATUS_IRQ_BIT  2

// Default widths
`define DMA_ADDR_WIDTH 32
`define DMA_DATA_WIDTH 32
`define DMA_LEN_WIDTH  32

// Word size (bytes)
`define DMA_WORD_BYTES 4

`endif