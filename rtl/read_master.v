`timescale 1ns/1ps
`include "dma_defs.vh"

module read_master(
    input  wire        iClk,
    input  wire        iReset_n,
    input  wire        iStart,
    input  wire [31:0] iLength,
    input  wire [31:0] iRM_startaddress,
    input  wire        iRM_readdatavalid,
    input  wire        iRM_waitrequest,
    output reg         oRM_read,
    output reg  [31:0] oRM_readaddress,
    input  wire [31:0] iRM_readdata,
    input  wire        iFF_almostfull,
    output wire        oFF_writerequest,
    output wire [31:0] oFF_data
);

    localparam [1:0] ST_IDLE = 2'h0;
    localparam [1:0] ST_REQ  = 2'h1;
    localparam [1:0] ST_WAIT = 2'h2;

    reg [1:0]  state;
    reg [31:0] RM_lastwriteaddress;
    reg        pending_read;

    wire read_accepted = (state == ST_WAIT) && !iRM_waitrequest;

    assign oFF_writerequest = iReset_n && iRM_readdatavalid && (pending_read || read_accepted);
    assign oFF_data = iRM_readdata;

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            state <= ST_IDLE;
            oRM_readaddress <= 32'h0;
            oRM_read <= 1'b0;
            RM_lastwriteaddress <= 32'h0;
            pending_read <= 1'b0;
        end else begin
            if (iStart) begin
                oRM_readaddress <= iRM_startaddress;
                RM_lastwriteaddress <= iRM_startaddress + iLength;
                oRM_read <= 1'b0;
                state <= ST_IDLE;
                pending_read <= 1'b0;
            end else begin
                case (state)
                    ST_IDLE: begin
                        oRM_read <= 1'b0;
                        if (!pending_read && !iFF_almostfull && (oRM_readaddress != RM_lastwriteaddress)) begin
                            state <= ST_REQ;
                        end
                    end
                    ST_REQ: begin
                        if (oRM_readaddress == RM_lastwriteaddress) begin
                            state <= ST_IDLE;
                        end else begin
                            oRM_read <= 1'b1;
                            state <= ST_WAIT;
                        end
                    end
                    ST_WAIT: begin
                        if (!iRM_waitrequest) begin
                            oRM_readaddress <= oRM_readaddress + 32'd4;
                            oRM_read <= 1'b0;
                            state <= ST_IDLE;
                        end
                    end
                    default: state <= ST_IDLE;
                endcase

                if (iRM_readdatavalid && (pending_read || read_accepted)) begin
                    pending_read <= 1'b0;
                end else if (read_accepted) begin
                    pending_read <= 1'b1;
                end
            end
        end
    end

endmodule