/*
 * rtl/fifo.v
 * Simple synchronous FIFO (parameterizable) intended for easy debugging
 * - DATA_WIDTH: width of each word
 * - DEPTH: number of entries (prefer power-of-two for efficiency)
 * - ALMOST_FULL: threshold for the `almost_full` flag
 *
 * Behavior notes:
 * - `wr_en` writes when FIFO is not full; `rd_en` reads when FIFO is not empty.
 * - `overflow`/`underflow` are asserted for one cycle when invalid ops attempted.
 * - `count` reports current occupancy (0..DEPTH).
 */

`timescale 1ns/1ps

module fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer DEPTH = 256,
    parameter integer ALMOST_FULL = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Write side
    input  wire                     wr_en,
    input  wire [DATA_WIDTH-1:0]    din,

    // Read side
    input  wire                     rd_en,
    output reg  [DATA_WIDTH-1:0]    dout,

    // Status
    output reg                      empty,
    output reg                      almost_full,
    output reg                      full,
    output reg                      overflow,
    output reg                      underflow,
    output reg  [( $clog2(DEPTH) ) : 0] count
);

// Local sizing
localparam integer ADDR_BITS = ($clog2(DEPTH) == 0) ? 1 : $clog2(DEPTH);

// Memory array
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// Pointers and internal registers
reg [ADDR_BITS-1:0] wr_ptr;
reg [ADDR_BITS-1:0] rd_ptr;

// Internal control signals
wire wr_allowed = (count < DEPTH);
wire rd_allowed = (count > 0);

integer i;

// Reset and main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= {ADDR_BITS{1'b0}};
        rd_ptr <= {ADDR_BITS{1'b0}};
        count  <= {(ADDR_BITS+1){1'b0}};
        dout   <= {DATA_WIDTH{1'b0}};
        empty  <= 1'b1;
        full   <= 1'b0;
        almost_full <= 1'b0;
        overflow <= 1'b0;
        underflow <= 1'b0;
        // Initialize memory to zero for deterministic simulation
        for (i = 0; i < DEPTH; i = i + 1) mem[i] <= {DATA_WIDTH{1'b0}};
    end else begin
        // Clear single-cycle error flags by default
        overflow <= 1'b0;
        underflow <= 1'b0;

        // Write (if allowed)
        if (wr_en) begin
            if (wr_allowed) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1'b1;
            end else begin
                // Attempted write when full
                overflow <= 1'b1;
            end
        end

        // Read (if allowed)
        if (rd_en) begin
            if (rd_allowed) begin
                dout <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1'b1;
            end else begin
                // Attempted read when empty
                underflow <= 1'b1;
            end
        end

        // Update count: handle four cases to be explicit
        if (wr_en && !rd_en) begin
            if (wr_allowed) count <= count + 1'b1;
        end else if (!wr_en && rd_en) begin
            if (rd_allowed) count <= count - 1'b1;
        end else if (wr_en && rd_en) begin
            // both asserted: if both allowed, occupancy keeps same
            // if one allowed and other not, treat as allowed case above
            if (wr_allowed && !rd_allowed) count <= count + 1'b1;
            else if (!wr_allowed && rd_allowed) count <= count - 1'b1;
        end

        // Flags
        empty <= (count == 0);
        full  <= (count >= DEPTH);

        // almost_full threshold (guard threshold to sensible range)
        if (ALMOST_FULL >= DEPTH)
            almost_full <= (count >= (DEPTH-1));
        else
            almost_full <= (count >= (DEPTH - ALMOST_FULL));
    end
end

endmodule
