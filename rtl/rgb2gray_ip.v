`timescale 1ns / 1ps

// =========================================================================
// Module: rgb2gray_ip
// Chuc nang: Wrapper giao tiep muc he thong cho module rgb2gray
// Kien truc: Dieu khien luong du lieu (Stream) ket hop tien tinh toan
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
    reg [31:0] total_pixels; 
    reg [31:0] total_pixels_m1; 
    
    reg [31:0] input_count;
    reg [31:0] output_count;

    wire core_out_valid;
    wire [7:0] core_out_gray;

    // Kiem soat tin hieu san sang nhan du lieu vao
    assign in_ready = busy && (input_count < total_pixels);

    // Khoi tao module xu ly chinh
    rgb2gray u_rgb2gray (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid && in_ready),
        .in_r(in_r),
        .in_g(in_g),
        .in_b(in_b),
        .brightness(brightness),
        .out_valid(core_out_valid),
        .out_gray(core_out_gray)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_count     <= 32'd0;
            output_count    <= 32'd0;
            total_pixels    <= 32'd0;
            total_pixels_m1 <= 32'd0;
            out_valid       <= 1'b0;
            out_gray        <= 8'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (start) begin
                    input_count  <= 32'd0;
                    output_count <= 32'd0;
                    out_valid    <= 1'b0;
                    out_gray     <= 8'd0;
                    
                    // Tien tinh toan thong so de giam tai cho bo so sanh o trang thai hoat dong
                    total_pixels <= width * height; 
                    total_pixels_m1 <= (width * height) - 1'b1;
                    
                    // Kiem tra tinh hop le cua do phan giai
                    if ((width == 16'd0) || (height == 16'd0)) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        busy <= 1'b1;
                    end
                end
            end else begin
                // Giam sat tin hieu luong dau vao
                if (in_valid && in_ready) begin
                    input_count <= input_count + 1'b1;
                end

                // Giam sat tin hieu luong dau ra
                out_valid <= core_out_valid;
                if (core_out_valid) begin
                    out_gray <= core_out_gray;
                    
                    // Kiem tra dieu kien ket thuc khung anh
                    if (output_count == total_pixels_m1) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        output_count <= output_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule