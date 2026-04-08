`timescale 1ns / 1ps

// =========================================================================
// Module: median_ip
// Mo ta:
//   Wrapper co clock/reset cho median 3x3.
//   Dau vao la stream pixel DA PADDING 1 lop (kich thuoc (width+2) x (height+2)).
//   Moi chu ky nhan 1 pixel khi in_valid=1 va in_ready=1.
//   IP tu tao cua so 3x3 bang line-buffer, tu dem row/col va assert done.
// =========================================================================
module median_ip #(
    parameter integer MAX_WIDTH = 4096
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,

    input  wire [15:0]  width,
    input  wire [15:0]  height,
    input  wire [7:0]   border,
    input  wire [511:0] border_pattern_flat,

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

    // Dem toa do stream input tren anh da padding
    reg [15:0] in_row;
    reg [15:0] in_col;

    reg [31:0] input_count;
    reg [31:0] output_count;

    // Hang doi 1 chu ky de dong bo output voi cua so vua cap nhat
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

    wire [7:0] median_out;

    median u_median (
        .p00(w00), .p01(w01), .p02(w02),
        .p10(w10), .p11(w11), .p12(w12),
        .p20(w20), .p21(w21), .p22(w22),
        .row(pending_row),
        .col(pending_col),
        .width(width),
        .height(height),
        .border(border),
        .border_pattern_flat(border_pattern_flat),
        .out_pixel(median_out)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
            w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
            w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;

            in_row <= 16'd0;
            in_col <= 16'd0;
            input_count  <= 32'd0;
            output_count <= 32'd0;

            pending_valid <= 1'b0;
            pending_row   <= 16'd0;
            pending_col   <= 16'd0;

            out_valid <= 1'b0;
            out_pixel <= 8'd0;
            out_row   <= 16'd0;
            out_col   <= 16'd0;

            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done      <= 1'b0;

            // Xuat ket qua cho cua so da tao o chu ky truoc
            if (busy && pending_valid) begin
                out_valid <= 1'b1;
                out_pixel <= median_out;
                out_row   <= pending_row;
                out_col   <= pending_col;

                if (output_count == (total_out - 1'b1)) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    output_count <= output_count + 1'b1;
                end
            end

            // Mac dinh khong co cua so moi cho chu ky tiep theo
            pending_valid <= 1'b0;

            if (!busy) begin
                if (start) begin
                    w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
                    w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
                    w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;

                    in_row <= 16'd0;
                    in_col <= 16'd0;
                    input_count  <= 32'd0;
                    output_count <= 32'd0;

                    pending_valid <= 1'b0;
                    pending_row   <= 16'd0;
                    pending_col   <= 16'd0;

                    if ((width == 16'd0) || (height == 16'd0) || (width > MAX_WIDTH[15:0])) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        busy <= 1'b1;
                    end
                end
            end else if (can_accept && in_valid) begin
                // Doc gia tri theo cot hien tai tu line-buffer
                row1_pix = linebuf1[in_col];
                row2_pix = linebuf2[in_col];

                // Cap nhat line-buffer
                linebuf2[in_col] <= row1_pix;
                linebuf1[in_col] <= in_pixel;

                // Dich cua so 3x3 theo chieu ngang
                w00 <= w01; w01 <= w02; w02 <= row2_pix;
                w10 <= w11; w11 <= w12; w12 <= row1_pix;
                w20 <= w21; w21 <= w22; w22 <= in_pixel;

                // Cua so hop le khi da co du 3 hang x 3 cot tu anh da padding
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
