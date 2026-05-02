`timescale 1ns/1ps

module FIFO (
    input  wire        iClk,
    input  wire        iReset_n,
    output wire        FF_empty,
    output wire        FF_almostfull,
    input  wire [31:0] FF_data,
    output wire [31:0] FF_q,
    input  wire        FF_readrequest,
    input  wire        FF_writerequest
);

    localparam integer DEPTH = 256;
    localparam integer ADDR_BITS = 8; // log2(256)

    reg [31:0] buffer [0:DEPTH-1];
    reg [ADDR_BITS-1:0] pos_read, pos_write;

    wire fifo_wr = (~FF_almostfull) & FF_writerequest;
    wire fifo_rd = (~FF_empty) & FF_readrequest;

    assign FF_q = buffer[pos_read];

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            pos_write <= {ADDR_BITS{1'b0}};
        end else if (fifo_wr) begin
            buffer[pos_write] <= FF_data;
            pos_write <= pos_write + 1'b1;
        end
    end

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            pos_read <= {ADDR_BITS{1'b0}};
        end else if (fifo_rd) begin
            pos_read <= pos_read + 1'b1;
        end
    end

    wire compare = pos_write[ADDR_BITS-1] ^ pos_read[ADDR_BITS-1];
    wire equal = (pos_write[ADDR_BITS-2:0] == pos_read[ADDR_BITS-2:0]);

    assign FF_almostfull = compare & equal; // half-full threshold
    assign FF_empty = (~compare) & equal;

endmodule