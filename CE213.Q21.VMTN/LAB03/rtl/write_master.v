`timescale 1ns/1ps
`include "dma_defs.vh"

module write_master(
    input wire iClk,
    input wire iReset_n,
    input wire iStart,
    input wire [31:0] iWM_startaddress,
    input wire [31:0] iLength,
    input wire iWM_waitrequest,
    input wire iFF_empty,
    input wire [31:0] iFF_q,
    output wire oFF_readrequest,
    output reg oWM_done,
    output reg oWM_write,
    output reg [31:0] oWM_writeaddress,
    output reg [31:0] oWM_writedata
);

    localparam [1:0] ST_IDLE = 2'h0;
    localparam [1:0] ST_WRITE = 2'h1;
    localparam [1:0] ST_DONE = 2'h2;

    reg [1:0] state;
    reg [31:0] WM_lastwriteaddress;

    assign oFF_readrequest = (iReset_n) && (!iFF_empty) && (state == ST_IDLE);

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            state <= ST_IDLE;
            oWM_write <= 1'b0;
            oWM_done <= 1'b0;
            oWM_writedata <= 32'h0;
            oWM_writeaddress <= 32'h0;
            WM_lastwriteaddress <= 32'h0;
        end else begin
            if (iStart) begin
                oWM_writeaddress <= iWM_startaddress;
                WM_lastwriteaddress <= iWM_startaddress + iLength;
            end else if ((!iFF_empty && (oWM_writeaddress != WM_lastwriteaddress)) || (state != ST_IDLE)) begin
                case (state)
                    ST_IDLE: begin
                        state <= ST_WRITE;
                        oWM_write <= 1'b1;
                        oWM_writedata <= iFF_q;
                    end
                    ST_WRITE: begin
                        if (!iWM_waitrequest) begin
                            if (WM_lastwriteaddress == (oWM_writeaddress + 32'd4)) begin
                                state <= ST_DONE;
                                oWM_done <= 1'b1;
                            end else begin
                                state <= ST_IDLE;
                            end
                            oWM_writeaddress <= oWM_writeaddress + 32'd4;
                            oWM_write <= 1'b0;
                        end
                    end
                    ST_DONE: begin
                        oWM_done <= 1'b0;
                        state <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule