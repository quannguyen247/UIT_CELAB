// ============================================================================
// Ten file : rgb2gray.v
// Mo ta    : Core chuyen doi RGB sang Grayscale su dung pipeline 4 tang.
//            Toi uu hoa bang phuong phap dich bit va kiem soat bao hoa.
// ============================================================================
`timescale 1ns / 1ps

module rgb2gray (
    input  wire               clk,
    input  wire               rst_n,
    
    input  wire               in_valid,
    input  wire [7:0]         in_r,
    input  wire [7:0]         in_g,
    input  wire [7:0]         in_b,
    input  wire signed [7:0]  brightness,
    
    output reg                out_valid,
    output reg  [7:0]         out_gray
);

    // ========================================================================
    // STAGE 1: Tinh tich cac kenh R, G, B thong qua cong va dich bit
    // He so chieu sang gan dung: R*0.299 ~ R*77 >> 8, 
    //                            G*0.587 ~ G*150 >> 8, 
    //                            B*0.114 ~ B*29 >> 8
    // ========================================================================
    reg [15:0]       p_r, p_g, p_b;
    reg              v_s1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r  <= 16'd0;
            p_g  <= 16'd0; 
            p_b  <= 16'd0;
            v_s1 <= 1'b0;
        end else begin
            p_r  <= ((in_r << 6) + (in_r << 3)) + ((in_r << 2) + in_r);
            p_g  <= ((in_g << 7) + (in_g << 4)) + ((in_g << 2) + (in_g << 1));
            p_b  <= ((in_b << 5) - (in_b << 2)) + in_b;
            
            v_s1 <= in_valid;
        end
    end

    // ========================================================================
    // STAGE 2: Cong ket qua 2 kenh R va G
    // ========================================================================
    reg [15:0]       sum_rg;
    reg [15:0]       p_b_s2; 
    reg              v_s2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_rg <= 16'd0;
            p_b_s2 <= 16'd0;
            v_s2   <= 1'b0;
        end else begin
            sum_rg <= p_r + p_g;
            p_b_s2 <= p_b;       
            v_s2   <= v_s1;
        end
    end

    // ========================================================================
    // STAGE 3: Hoan thanh ket qua tinh RGB sang Grayscale 
    // ========================================================================
    reg [15:0]       sum_rgb;
    reg              v_s3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_rgb <= 16'd0;
            v_s3    <= 1'b0;
        end else begin
            sum_rgb <= sum_rg + p_b_s2;
            v_s3    <= v_s2;
        end
    end

    // ========================================================================
    // STAGE 4: Xu ly bien vung gia tri tran & xuat ket qua
    // ========================================================================
    // Chi 8 bit cao MSB = >> 8
    wire [7:0]       gray_base = sum_rgb[15:8];
    
    // Cong do sang co dau truc tiep vao stage cuoi
    wire signed [9:0] gray_calc = $signed({2'b00, gray_base}) + $signed({{2{brightness[7]}}, brightness});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_gray  <= 8'd0;
        end else begin
            out_valid <= v_s3;
            if (v_s3) begin
                // Kiem soat bao hoa: gia tri phai nam trong khoang [0, 255]
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