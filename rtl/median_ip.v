`timescale 1ns / 1ps

// =========================================================================
// Module: median_ip
// Mo ta:
//   Wrapper tich hop Line Buffer stream pixel va FSM cho median 3x3.
//   Tu dong dong bo do tre pipeline 3 tang bang shift register cho row/col.
// =========================================================================
module median_ip #(
    parameter integer MAX_WIDTH = 4096
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,

    // Tin hieu giao tiep FSM tu Top-level xuong Median core
    input  wire         start_load,
    input  wire [31:0]  border_data_in,
    output wire         load_done,

    input  wire [15:0]  width,
    input  wire [15:0]  height,
    input  wire [7:0]   border,

    input  wire         in_valid,
    input  wire [7:0]   in_pixel,
    output wire         in_ready,

    output reg          out_valid,
    output reg  [7:0]   out_pixel,
    output reg  [15:0]  out_row,
    output reg  [15:0]  out_col,

    output reg          busy,
    output reg          done
);
    localparam integer MAX_PAD_WIDTH = MAX_WIDTH + 2;

    // 2 line buffer de tao cua so 3x3 theo stream
    reg [7:0] linebuf1 [0:MAX_PAD_WIDTH-1];
    reg [7:0] linebuf2 [0:MAX_PAD_WIDTH-1];

    // Cua so 3x3 hien tai
    reg [7:0] w00, w01, w02;
    reg [7:0] w10, w11, w12;
    reg [7:0] w20, w21, w22;

    reg [15:0] in_row;
    reg [15:0] in_col;
    reg [31:0] input_count;
    reg [31:0] output_count;

    reg        pending_valid;
    reg [15:0] pending_row;
    reg [15:0] pending_col;

    reg [7:0] row1_pix;
    reg [7:0] row2_pix;

    wire [15:0] padded_width  = width + 16'd2;
    wire [15:0] padded_height = height + 16'd2;
    wire [31:0] total_in      = padded_width * padded_height;
    wire [31:0] total_out     = width * height;

    wire can_accept = busy && (input_count < total_in);
    assign in_ready = can_accept;

    wire median_out_valid;
    wire [7:0] median_out;

    // Khoi tao Core IP
    median u_median (
        .clk(clk),
        .rst_n(rst_n),
        .start_load(start_load),
        .border_data_in(border_data_in),
        .load_done(load_done),
        .in_valid(pending_valid),
        .p00(w00), .p01(w01), .p02(w02),
        .p10(w10), .p11(w11), .p12(w12),
        .p20(w20), .p21(w21), .p22(w22),
        .row(pending_row),
        .col(pending_col),
        .width(width),
        .height(height),
        .border(border),
        .out_valid(median_out_valid),
        .out_pixel(median_out)
    );

    // =========================================================================
    // SHIFT REGISTER 3 TANG CHO TOA DO X/Y
    // Dong bo hoa row/col hien tai voi do tre cua module median 
    // =========================================================================
    reg [15:0] s1_row, s2_row, s3_row;
    reg [15:0] s1_col, s2_col, s3_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_row <= 16'd0; s2_row <= 16'd0; s3_row <= 16'd0;
            s1_col <= 16'd0; s2_col <= 16'd0; s3_col <= 16'd0;
        end else begin
            s1_row <= pending_row;
            s2_row <= s1_row;
            s3_row <= s2_row;
            
            s1_col <= pending_col;
            s2_col <= s1_col;
            s3_col <= s2_col;
        end
    end

    // =========================================================================
    // LOGIC DIEU KHIEN CHINH VA LINE BUFFER
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
            w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
            w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;

            in_row <= 16'd0; in_col <= 16'd0;
            input_count  <= 32'd0;
            output_count <= 32'd0;
            pending_valid <= 1'b0;
            pending_row   <= 16'd0; pending_col   <= 16'd0;

            out_valid <= 1'b0; out_pixel <= 8'd0;
            out_row   <= 16'd0; out_col   <= 16'd0;

            busy <= 1'b0; done <= 1'b0;
        end else begin
            // Reset co tung chu ky
            done <= 1'b0;
            pending_valid <= 1'b0;
            
            // Dong bo tin hieu output tu pipeline tang 3 vao thanh ghi ngo ra chot
            out_valid <= median_out_valid;
            
            if (median_out_valid) begin
                out_pixel <= median_out;
                out_row   <= s3_row;
                out_col   <= s3_col;
                
                // Kiem tra hoan thanh viec ket xuat toan bo anh
                if (output_count == (total_out - 1'b1)) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    output_count <= output_count + 1'b1;
                end
            end

            // Khoi dong bo may stream data
            if (!busy) begin
                if (start) begin
                    w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
                    w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
                    w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;
                    in_row <= 16'd0; in_col <= 16'd0;
                    input_count  <= 32'd0;
                    output_count <= 32'd0;
                    pending_valid <= 1'b0;
                    
                    if ((width == 16'd0) || (height == 16'd0) || (width > MAX_WIDTH[15:0])) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        busy <= 1'b1;
                    end
                end
            end else if (can_accept && in_valid) begin
                row1_pix = linebuf1[in_col];
                row2_pix = linebuf2[in_col];

                linebuf2[in_col] <= row1_pix;
                linebuf1[in_col] <= in_pixel;

                w00 <= w01; w01 <= w02; w02 <= row2_pix;
                w10 <= w11; w11 <= w12; w12 <= row1_pix;
                w20 <= w21; w21 <= w22; w22 <= in_pixel;

                if ((in_row >= 16'd2) && (in_col >= 16'd2) &&
                    (in_row <= (height + 16'd1)) && (in_col <= (width + 16'd1))) begin
                    pending_valid <= 1'b1;
                    pending_row   <= in_row - 16'd2;
                    pending_col   <= in_col - 16'd2;
                end

                input_count <= input_count + 1'b1;
                if (in_col == (padded_width - 1'b1)) begin
                    in_col <= 16'd0;
                    in_row <= in_row + 1'b1;
                end else begin
                    in_col <= in_col + 1'b1;
                end
            end
        end
    end
endmodule