/*
 * rtl/control_slave.v
 * Control slave for DMA: register file, start/stop pulse, status and IRQ.
 *
 * Register map (word offsets):
 * 0x0 CONTROL  : [0]=START (write 1), [1]=STOP (write 1), [2]=IRQ_EN
 * 0x1 SRC_ADDR : 32-bit source base
 * 0x2 DST_ADDR : 32-bit destination base
 * 0x3 LENGTH   : transfer length (lower LEN_WIDTH bits)
 * 0x4 STATUS   : [0]=DONE (R/W-clear), [1]=RUNNING, [2]=IRQ
 */

`timescale 1ns/1ps

module control_slave #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer LEN_WIDTH  = 16
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Avalon-like slave interface (word offsets)
    input  wire [3:0]               avs_addr,
    input  wire                     avs_write,
    input  wire                     avs_read,
    input  wire [(DATA_WIDTH/8)-1:0] avs_byteenable,
    input  wire [DATA_WIDTH-1:0]    avs_writedata,
    output reg  [DATA_WIDTH-1:0]    avs_readdata,
    output wire                     avs_waitrequest,

    // Control outputs to DMA engines
    output reg                      start,      // one-cycle pulse when start written
    output reg                      stop,       // level (write 1 to request stop)
    output reg  [ADDR_WIDTH-1:0]    src_addr,
    output reg  [ADDR_WIDTH-1:0]    dst_addr,
    output reg  [LEN_WIDTH-1:0]     length,

    // Input from DMA engines (transfer finished)
    input  wire                     done_in,

    // Status outputs
    output reg                      running,
    output reg                      done,
    output reg                      irq
);

assign avs_waitrequest = 1'b0; // zero-wait control slave for simplicity

// Internal registers
reg [DATA_WIDTH-1:0] reg_control;
reg [DATA_WIDTH-1:0] reg_status;

// Start pulse generation (single-cycle when software writes CONTROL[0]=1)
wire start_write = avs_write && (avs_addr == 4'h0) && (avs_writedata[0]);

// Write handling (byte-enable aware)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_control <= {DATA_WIDTH{1'b0}};
        src_addr   <= {ADDR_WIDTH{1'b0}};
        dst_addr   <= {ADDR_WIDTH{1'b0}};
        length     <= {LEN_WIDTH{1'b0}};
        reg_status <= {DATA_WIDTH{1'b0}};
        start <= 1'b0;
        stop  <= 1'b0;
        running <= 1'b0;
        done <= 1'b0;
        irq  <= 1'b0;
    end else begin
        // default: clear single-cycle start pulse each clock
        start <= 1'b0;

        if (avs_write) begin
            case (avs_addr)
                4'h0: begin // CONTROL
                    // store byte lanes
                    if (avs_byteenable[0]) reg_control[7:0]   <= avs_writedata[7:0];
                    if (avs_byteenable[1]) reg_control[15:8]  <= avs_writedata[15:8];
                    if (avs_byteenable[2]) reg_control[23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) reg_control[31:24] <= avs_writedata[31:24];

                    // generate start/stop pulses/levels
                    if (avs_writedata[0]) start <= 1'b1; // one-cycle pulse
                    if (avs_writedata[1]) stop  <= 1'b1; // set stop (software controlled)
                end
                4'h1: begin // SRC_ADDR
                    if (avs_byteenable[0]) src_addr[7:0]   <= avs_writedata[7:0];
                    if (avs_byteenable[1]) src_addr[15:8]  <= avs_writedata[15:8];
                    if (avs_byteenable[2]) src_addr[23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) src_addr[31:24] <= avs_writedata[31:24];
                end
                4'h2: begin // DST_ADDR
                    if (avs_byteenable[0]) dst_addr[7:0]   <= avs_writedata[7:0];
                    if (avs_byteenable[1]) dst_addr[15:8]  <= avs_writedata[15:8];
                    if (avs_byteenable[2]) dst_addr[23:16] <= avs_writedata[23:16];
                    if (avs_byteenable[3]) dst_addr[31:24] <= avs_writedata[31:24];
                end
                4'h3: begin // LENGTH (lower LEN_WIDTH bits)
                    length <= avs_writedata[LEN_WIDTH-1:0];
                end
                4'h4: begin // STATUS (write-to-clear low byte)
                    if (avs_byteenable[0]) begin
                        reg_status[7:0] <= reg_status[7:0] & ~avs_writedata[7:0];
                        // clear done if written
                        if (avs_writedata[0]) done <= 1'b0;
                        // clear irq if bit1 of writedata set
                        if (avs_writedata[1]) irq <= 1'b0;
                    end
                end
                default: ;
            endcase
        end

        // Start triggers running state
        if (start_write && !running) begin
            running <= 1'b1;
            done    <= 1'b0;
            reg_status[1] <= 1'b1; // running bit
        end

        // Stop request clears running immediately
        if (avs_write && (avs_addr == 4'h0) && avs_writedata[1]) begin
            running <= 1'b0;
            reg_status[1] <= 1'b0;
            stop <= 1'b1;
        end

        // External completion (from master)
        if (done_in) begin
            done <= 1'b1;
            running <= 1'b0;
            reg_status[0] <= 1'b1; // done bit
            reg_status[1] <= 1'b0; // clear running bit
            // Generate IRQ if enabled in CONTROL[2]
            irq <= reg_control[2];
        end
    end
end

// Readback (combinational)
always @(*) begin
    case (avs_addr)
        4'h0: avs_readdata = reg_control;
        4'h1: avs_readdata = src_addr;
        4'h2: avs_readdata = dst_addr;
        4'h3: avs_readdata = {{(DATA_WIDTH-LEN_WIDTH){1'b0}}, length};
        4'h4: avs_readdata = { {(DATA_WIDTH-3){1'b0}}, irq, 1'b0, running, done } | reg_status;
        default: avs_readdata = {DATA_WIDTH{1'b0}};
    endcase
end

endmodule
