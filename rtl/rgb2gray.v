`timescale 1ns / 1ps

// =========================================================================
// Module: rgb2gray
// Mo ta: Chuyen doi anh RGB sang anh xam voi do chinh xac 8-bit (chia 256).
//        Do sang duoc dieu chinh tu -128 den +127 (signed 8-bit).
// =========================================================================
module rgb2gray (
    input  wire         [7:0] r,
    input  wire         [7:0] g,
    input  wire         [7:0] b,
    input  wire signed  [7:0] brightness,
    output wire         [7:0] gray
);

    // =========================================================================
    // PHAN 1: Tinh toan tung kenh mau su dung phep dich bit (He so 8-bit)
    // =========================================================================
    // He so 8-bit de toi uu phan cung: (R*77, G*150, B*29) >> 8 
    //                                ≈ (R*0.299, G*0.587, B*0.114)
    wire [15:0] r_mult = (r << 6) + (r << 3) + (r << 2) + r;
    wire [15:0] g_mult = (g << 7) + (g << 4) + (g << 2) + (g << 1);
    wire [15:0] b_mult = (b << 4) + (b << 3) + (b << 2) + b;

    // =========================================================================
    // PHAN 2: Tong hop ket qua va lay phan nguyen
    // =========================================================================
    wire [15:0] sum = r_mult + g_mult + b_mult;
    
    // Dich phai 8 bit (tuong duong chia cho 256) de trich xuat nhan gia tri 8-bit cua anh xam
    wire [7:0] gray_base = sum[15:8];

    // =========================================================================
    // PHAN 3: Xu ly do sang va chong tran so (Saturation)
    // ========================================================================= 
    // - `gray_base` la pixel xam goc, luon nam trong khoang: 0 den 255.
    // - `brightness` la dai bu tru do sang (cong/tru them), nam trong khoang: -128 den 127.
    // Mo rong len 10 bit co dau (signed) de cong tru an toan (khong bi tran bit):
    // Max tam thoi: 255 (pixel trang nhat) + 127 (max sang) = 382.
    // Min tam thoi: 0 (pixel toi nhat) - 128 (max toi) = -128.
    // - gray_base: zero-extension them 2 bit o dau de phu hop chieu dai 10 bit
    // - brightness: sign-extension bit dau de giu nguyen dau am/duong khi mo rong len 10 bit
    wire signed [9:0] gray_calc = $signed({2'b00, gray_base}) + $signed({{2{brightness[7]}}, brightness});

    // Kep gia tri (Clipping/Saturation): 
    // Vi dau ra cuoi cung `gray` la moi pixel 8-bit tieu chuan nen chi duoc phep nam trong [0, 255]
    // - Neu ket qua < 0: Bi am thi chot ve 0 (Den tuyet doi)
    // - Neu ket qua > 255: Vuot qua nguong trang thi chot ve 255 (Trang tuyet doi)
    // - Nam giua [0, 255]: Lay gia tri binh thuong
    assign gray = (gray_calc < 10'sd0)   ? 8'd0 :
                  (gray_calc > 10'sd255) ? 8'd255 : gray_calc[7:0]; 

endmodule