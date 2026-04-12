`timescale 1ns / 1ps

// =========================================================================
// Module: rgb2gray
// Chuc nang: Chuyen doi ma tran anh RGB sang anh xam (Grayscale)
// Kien truc: Pipeline 4 tang, toi uu hoa tai nguyen bang phuong phap dich bit
// =========================================================================
module rgb2gray (
    input  wire         clk,
    input  wire         rst_n,
    
    input  wire         in_valid,
    input  wire [7:0]   in_r,
    input  wire [7:0]   in_g,
    input  wire [7:0]   in_b,
    input  wire signed [7:0] brightness,
    
    output reg          out_valid,
    output reg  [7:0]   out_gray
);

    // --- STAGE 1: Tinh toan tich phan (Shift and Add) ---
    reg [15:0] p_r, p_g, p_b;
    reg signed [7:0] b_s1;
    reg v_s1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r <= 16'd0; p_g <= 16'd0; p_b <= 16'd0;
            b_s1 <= 8'sd0; v_s1 <= 1'b0;
        end else begin
            // Tinh toan he so chieu sang: R*77, G*150, B*29
            p_r <= ((in_r << 6) + (in_r << 3)) + ((in_r << 2) + in_r);
            p_g <= ((in_g << 7) + (in_g << 4)) + ((in_g << 2) + (in_g << 1));
            p_b <= ((in_b << 5) - (in_b << 2)) + in_b;
            
            b_s1 <= brightness;
            v_s1 <= in_valid;
        end
    end

    // --- STAGE 2: Cong tich phan kenh R va G ---
    reg [15:0] sum_rg; 
    reg [15:0] p_b_s2; 
    reg signed [7:0] b_s2;
    reg v_s2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_rg <= 16'd0; p_b_s2 <= 16'd0;
            b_s2 <= 8'sd0; v_s2 <= 1'b0;
        end else begin
            // Thuc hien cong 2 toan hang de giam thoi gian tre cua mach
            sum_rg <= p_r + p_g; 
            p_b_s2 <= p_b;       
            b_s2 <= b_s1;
            v_s2 <= v_s1;
        end
    end

    // --- STAGE 3: Hoan thanh tong RGB ---
    reg [15:0] sum_rgb; 
    reg signed [7:0] b_s3;
    reg v_s3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_rgb <= 16'd0;
            b_s3 <= 8'sd0; v_s3 <= 1'b0;
        end else begin
            // Cong don kenh B de hoan tat cong thuc RGB
            sum_rgb <= sum_rg + p_b_s2;
            b_s3 <= b_s2;
            v_s3 <= v_s2;
        end
    end

    // --- STAGE 4: Xu ly Clipping va xuat ket qua ---
    // Trich xuat 8 bit cao nhat (tuong duong phep chia 256)
    wire [7:0] gray_base = sum_rgb[15:8];
    wire signed [9:0] gray_calc = $signed({2'b00, gray_base}) + $signed({{2{b_s3[7]}}, b_s3});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_gray <= 8'd0;
        end else begin
            out_valid <= v_s3;
            if (v_s3) begin
                // Kiem tra trang thai cua bit dau va bit tran de thuc hien giay han gia tri anh
                if (gray_calc[9])         
                    out_gray <= 8'd0;
                else if (gray_calc[8])    
                    out_gray <= 8'd255;
                else                      
                    out_gray <= gray_calc[7:0];
            end
        end
    end

endmodule