`timescale 1ns/1ps
`include "dma_defs.vh"

module control_slave (
    input  wire        iClk,
    input  wire        iReset_n,
    input  wire        iChipselect_n,
    input  wire        iWrite,
    input  wire        iRead,
    input  wire        iMW_done,
    input  wire [2:0]  iAddress,
    input  wire [31:0] iWritedata,
    output reg         oStart,
    output reg  [31:0] oReaddata,
    output reg  [31:0] oRM_startaddress,
    output reg  [31:0] oWM_startaddress,
    output reg  [31:0] oLength,
    output reg         oIRQ
);

    reg [31:0] control;
    reg        busy;
    reg        done;

    wire write_en = (~iChipselect_n) && iWrite;
    wire read_en  = (~iChipselect_n) && iRead;

    wire go_write = write_en && (iAddress == `DMA_ADDR_CONTROL) && iWritedata[`DMA_CTRL_GO_BIT];
    wire irq_en   = control[`DMA_CTRL_IRQ_EN_BIT];

    wire [31:0] status = {29'b0, oIRQ, busy, done};

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            oRM_startaddress <= 32'h0;
            oWM_startaddress <= 32'h0;
            oLength          <= 32'h0;
            control          <= 32'h0;
            oReaddata        <= 32'h0;
            oStart           <= 1'b0;
            busy             <= 1'b0;
            done             <= 1'b0;
            oIRQ             <= 1'b0;
        end else begin
            oStart <= 1'b0; // one-cycle pulse

            if (write_en && !busy) begin
                case (iAddress)
                    `DMA_ADDR_RM_START: oRM_startaddress <= iWritedata;
                    `DMA_ADDR_WM_START: oWM_startaddress <= iWritedata;
                    `DMA_ADDR_LENGTH:   oLength          <= iWritedata;
                    `DMA_ADDR_CONTROL:  control          <= iWritedata;
                    default: ;
                endcase
            end

            if (read_en) begin
                case (iAddress)
                    `DMA_ADDR_STATUS: oReaddata <= status;
                    default: oReaddata <= 32'h0;
                endcase
            end

            // Write-1-to-clear for DONE/IRQ via STATUS register
            if (write_en && (iAddress == `DMA_ADDR_STATUS)) begin
                if (iWritedata[`DMA_STATUS_DONE_BIT]) done <= 1'b0;
                if (iWritedata[`DMA_STATUS_IRQ_BIT])  oIRQ <= 1'b0;
            end

            if (go_write && !busy) begin
                oStart <= 1'b1;
                busy   <= 1'b1;
                done   <= 1'b0;
                oIRQ   <= 1'b0;
            end

            if (iMW_done && busy) begin
                busy <= 1'b0;
                done <= 1'b1;
                if (irq_en) begin
                    oIRQ <= 1'b1;
                end
                control <= 32'h0;
            end
        end
    end

endmodule
