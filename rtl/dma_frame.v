`timescale 1ns/1ps

module dma_frame #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter LEN_WIDTH  = 16
) (
    input wire clk,
    input wire rst_n,

    // Simple control slave (word-offset register file)
    input wire [3:0]               ctrl_addr,        // word offset
    input wire                     ctrl_write,
    input wire                     ctrl_read,
    input wire [(DATA_WIDTH/8)-1:0] ctrl_byteenable,
    input wire [DATA_WIDTH-1:0]    ctrl_writedata,
    output reg  [DATA_WIDTH-1:0]    ctrl_readdata,
    output reg                      ctrl_waitrequest,

    // Read master (memory -> DMA)
    input wire avm_rd_waitrequest,
    input wire [DATA_WIDTH-1:0] avm_rd_readdata,
    output reg  [ADDR_WIDTH-1:0] avm_rd_address,
    output reg                      avm_rd_read,

    // Write master (DMA -> memory)
    output reg  [ADDR_WIDTH-1:0]    avm_wr_address,
    output reg                      avm_wr_write,
    output reg  [DATA_WIDTH-1:0]    avm_wr_writedata,
    input  wire                     avm_wr_waitrequest,

    // Status / interrupt
    output wire                     dma_done,
    output wire                     dma_irq
);

localparam BYTEEN = DATA_WIDTH/8;

// -----------------------------------------------------------------------------
// Register map (word offsets)
// 0x0 CONTROL  (bit0=start, bit1=stop)
// 0x1 SRC_ADDR (32-bit)
// 0x2 DST_ADDR (32-bit)
// 0x3 LENGTH   (lower LEN_WIDTH bits used)
// 0x4 STATUS   (bit0=done, bit1=running)
// -----------------------------------------------------------------------------

reg [DATA_WIDTH-1:0] reg_control;
reg [ADDR_WIDTH-1:0] reg_src_addr;
reg [ADDR_WIDTH-1:0] reg_dst_addr;
reg [LEN_WIDTH-1:0]  reg_length;
reg [DATA_WIDTH-1:0] reg_status;

// One-cycle pulse when software writes CONTROL[0]=1
wire start_pulse = (ctrl_write && (ctrl_addr == 4'h0) && ctrl_writedata[0]);

// -----------------------------------------------------------------------------
// Register writes (byte-enable aware). This implementation assumes 32-bit
// words (4 byte lanes) which matches typical Nios/AVM usage in the lab.
// -----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_control <= {DATA_WIDTH{1'b0}};
        reg_src_addr <= {ADDR_WIDTH{1'b0}};
        reg_dst_addr <= {ADDR_WIDTH{1'b0}};
        reg_length <= {LEN_WIDTH{1'b0}};
        reg_status <= {DATA_WIDTH{1'b0}};
    end else begin
        if (ctrl_write) begin
            case (ctrl_addr)
                4'h0: begin // CONTROL
                    if (ctrl_byteenable[0]) reg_control[7:0]   <= ctrl_writedata[7:0];
                    if (ctrl_byteenable[1]) reg_control[15:8]  <= ctrl_writedata[15:8];
                    if (ctrl_byteenable[2]) reg_control[23:16] <= ctrl_writedata[23:16];
                    if (ctrl_byteenable[3]) reg_control[31:24] <= ctrl_writedata[31:24];
                end
                4'h1: begin // SRC_ADDR
                    if (ctrl_byteenable[0]) reg_src_addr[7:0]   <= ctrl_writedata[7:0];
                    if (ctrl_byteenable[1]) reg_src_addr[15:8]  <= ctrl_writedata[15:8];
                    if (ctrl_byteenable[2]) reg_src_addr[23:16] <= ctrl_writedata[23:16];
                    if (ctrl_byteenable[3]) reg_src_addr[31:24] <= ctrl_writedata[31:24];
                end
                4'h2: begin // DST_ADDR
                    if (ctrl_byteenable[0]) reg_dst_addr[7:0]   <= ctrl_writedata[7:0];
                    if (ctrl_byteenable[1]) reg_dst_addr[15:8]  <= ctrl_writedata[15:8];
                    if (ctrl_byteenable[2]) reg_dst_addr[23:16] <= ctrl_writedata[23:16];
                    if (ctrl_byteenable[3]) reg_dst_addr[31:24] <= ctrl_writedata[31:24];
                end
                4'h3: begin // LENGTH (store lower LEN_WIDTH bits)
                    reg_length <= ctrl_writedata[LEN_WIDTH-1:0];
                end
                4'h4: begin // STATUS: write-to-clear for low byte
                    if (ctrl_byteenable[0]) reg_status[7:0] <= reg_status[7:0] & ~ctrl_writedata[7:0];
                end
                default: ;
            endcase
        end
    end
end

// -----------------------------------------------------------------------------
// Register readback
// -----------------------------------------------------------------------------
always @(*) begin
    ctrl_readdata = {DATA_WIDTH{1'b0}};
    case (ctrl_addr)
        4'h0: ctrl_readdata = reg_control;
        4'h1: ctrl_readdata = reg_src_addr;
        4'h2: ctrl_readdata = reg_dst_addr;
        4'h3: ctrl_readdata = {{(DATA_WIDTH-LEN_WIDTH){1'b0}}, reg_length};
        4'h4: ctrl_readdata = reg_status;
        default: ctrl_readdata = {DATA_WIDTH{1'b0}};
    endcase
end

// -----------------------------------------------------------------------------
// Minimal start/running/done handshake (skeleton)
// - start_pulse is asserted when CONTROL[0] is written to 1 by software.
// - running flag is set locally; finished/done should be set by masters.
// -----------------------------------------------------------------------------
reg running;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        running <= 1'b0;
        reg_status <= {DATA_WIDTH{1'b0}};
    end else begin
        if (start_pulse && !running) begin
            running <= 1'b1;
            reg_status[1] <= 1'b1; // running
            reg_status[0] <= 1'b0; // clear done
        end

        // Allow software to stop by writing CONTROL[1]=1
        if (ctrl_write && (ctrl_addr == 4'h0) && ctrl_writedata[1]) begin
            running <= 1'b0;
            reg_status[1] <= 1'b0;
        end

        // Note: set reg_status[0]=1 when transfer completes (by masters)
    end
end

wire fifo_wr_en;
wire fifo_rd_en;
wire [DATA_WIDTH-1:0] fifo_din;
wire [DATA_WIDTH-1:0] fifo_dout;
wire fifo_empty;
wire fifo_almost_full;

assign dma_done = reg_status[0];
assign dma_irq  = reg_status[0];

// Safe default drives for AVM outputs until submodules are connected
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        avm_rd_address <= {ADDR_WIDTH{1'b0}};
        avm_rd_read    <= 1'b0;
        avm_wr_address <= {ADDR_WIDTH{1'b0}};
        avm_wr_write   <= 1'b0;
        avm_wr_writedata <= {DATA_WIDTH{1'b0}};
        ctrl_waitrequest <= 1'b0;
    end else begin
        avm_rd_read  <= 1'b0;
        avm_wr_write <= 1'b0;
    end
end

endmodule
