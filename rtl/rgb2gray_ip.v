`timescale 1ns / 1ps

// =========================================================================
// Module: rgb2gray_ip
// Mo ta:
//   Wrapper co clock/reset cho rgb2gray de chay theo frame.
//   Moi chu ky nhan 1 pixel RGB khi in_valid=1 va in_ready=1.
//   IP tu dong dem du so pixel (width*height) roi assert done.
// =========================================================================
module rgb2gray_ip (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [15:0]  width,
    input  wire [15:0]  height,
    input  wire signed [7:0] brightness,

    input  wire         in_valid,
    input  wire [7:0]   in_r,
    input  wire [7:0]   in_g,
    input  wire [7:0]   in_b,
    output wire         in_ready,

    output reg          out_valid,
    output reg  [7:0]   out_gray,

    output reg          busy,
    output reg          done
);
    wire [7:0] gray_comb;
    wire [31:0] total_pixels = width * height;

    reg [31:0] pixel_count;

    assign in_ready = busy && (pixel_count < total_pixels);

    rgb2gray u_rgb2gray (
        .r(in_r),
        .g(in_g),
        .b(in_b),
        .brightness(brightness),
        .gray(gray_comb)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 32'd0;
            out_valid   <= 1'b0;
            out_gray    <= 8'd0;
            busy        <= 1'b0;
            done        <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done      <= 1'b0;

            if (!busy) begin
                if (start) begin
                    pixel_count <= 32'd0;
                    if (total_pixels == 32'd0) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        busy <= 1'b1;
                    end
                end
            end else if (in_valid && in_ready) begin
                out_valid <= 1'b1;
                out_gray  <= gray_comb;

                if (pixel_count == (total_pixels - 1'b1)) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    pixel_count <= pixel_count + 1'b1;
                end
            end
        end
    end
endmodule
