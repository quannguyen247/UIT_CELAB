`ifndef DMA_DEFS
`define DMA_DEFS

// Register map
`define REG_SRC 3'h0
`define REG_DST 3'h1
`define REG_LEN 3'h2
`define REG_CTRL 3'h3
`define REG_STAT 3'h7

// Bit Control
`define CTRL_GO 3
`define CTRL_IRQ 4

// Bit Status
`define STAT_DONE 0
`define STAT_BUSY 1
`define STAT_IRQ 2

`endif