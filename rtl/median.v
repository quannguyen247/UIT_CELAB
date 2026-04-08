`timescale 1ns / 1ps

// =========================================================================
// Module: sort3
// Chuc nang: So sanh va sap xep 3 phan tu su dung mach to hop
// Dau vao: 3 gia tri 8-bit (in1, in2, in3)
// Dau ra: 3 gia tri 8-bit da duoc sap xep (out_max, out_mid, out_min)
// =========================================================================
module sort3 (
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    output wire [7:0] out_max,
    output wire [7:0] out_mid,
    output wire [7:0] out_min
);
    // Buoc 1: So sanh tung cap tin hieu dau vao de tao ra cac tin hieu dieu khien (co)
    wire c12 = (in1 > in2);
    wire c13 = (in1 > in3);
    wire c23 = (in2 > in3);

    // Buoc 2: Su dung bo ghep kenh (multiplexer) de chon gia tri phu hop cho tung ngo ra
    assign out_max = (c12 && c13) ? in1 : (!c12 && c23) ? in2 : in3;
    assign out_min = (!c12 && !c13) ? in1 : (c12 && !c23) ? in2 : in3;
    assign out_mid = (c12 != c13) ? in1 : (c12 == c23) ? in2 : in3;
endmodule

// =========================================================================
// Module: median
// Chuc nang: Thuc hien thuat toan loc trung vi (median filter) cho cua so 3x3 
//            va tao vien (border) chong nhieu cho anh dau ra
// =========================================================================
module median (
    input  wire [7:0] p00, p01, p02, // Hang 0 cua ma tran
    input  wire [7:0] p10, p11, p12, // Hang 1 cua ma tran
    input  wire [7:0] p20, p21, p22, // Hang 2 cua ma tran
    input  wire [15:0] row,          // Toa do Y hien tai cua pixel dang xet
    input  wire [15:0] col,          // Toa do X hien tai cua pixel dang xet
    input  wire [15:0] width,        // Chieu rong cua buc anh (so cot)
    input  wire [15:0] height,       // Chieu cao cua buc anh (so hang)
    input  wire [7:0] border,        // Do day cua vien anh can tao
    input  wire [511:0] border_pattern_flat, // Mang luu tru mau vien (gom 64 pixel x 8-bit)
    output wire [7:0] out_pixel      // Gia tri pixel dau ra sau khi da tinh toan
);
    // =========================================================================
    // PHAN 1: THUAT TOAN LOC TRUNG VI MA TRAN 3x3
    // Su dung mang luoi sap xep toi uu voi 7 node sort
    // Phuong phap nay tiet kiem tai nguyen phan cung hon rat nhieu so voi 
    // viec tao array va sap xep tuan tu toan bo 9 phan tu.
    // =========================================================================

    wire [7:0] r0_max, r0_mid, r0_min;
    wire [7:0] r1_max, r1_mid, r1_min;
    wire [7:0] r2_max, r2_mid, r2_min;

    // Node 1, 2, 3: Sap xep cac phan tu tang dan theo tung hang rieng biet
    // Moi hang doc lap tim ra 3 gia tri: lon nhat, o giua, nho nhat cua hang do
    sort3 row0_sort (.in1(p00), .in2(p01), .in3(p02), .out_max(r0_max), .out_mid(r0_mid), .out_min(r0_min));
    sort3 row1_sort (.in1(p10), .in2(p11), .in3(p12), .out_max(r1_max), .out_mid(r1_mid), .out_min(r1_min));
    sort3 row2_sort (.in1(p20), .in2(p21), .in3(p22), .out_max(r2_max), .out_mid(r2_mid), .out_min(r2_min));

    wire [7:0] min_of_maxes, mid_of_mids, max_of_mins;

    // Node 4: Tim gia tri nho nhat trong 3 gia tri lon nhat cua 3 hang (min_of_maxes)
    sort3 col_max_sort (.in1(r0_max), .in2(r1_max), .in3(r2_max), .out_max(), .out_mid(), .out_min(min_of_maxes));
    
    // Node 5: Tim gia tri trung vi trong 3 gia tri trung vi cua 3 hang (mid_of_mids)
    sort3 col_mid_sort (.in1(r0_mid), .in2(r1_mid), .in3(r2_mid), .out_max(), .out_mid(mid_of_mids), .out_min());
    
    // Node 6: Tim gia tri lon nhat trong 3 gia tri nho nhat cua 3 hang (max_of_mins)
    sort3 col_min_sort (.in1(r0_min), .in2(r1_min), .in3(r2_min), .out_max(max_of_mins), .out_mid(), .out_min());

    wire [7:0] median_val;

    // Node 7: Buoc chung ket sap xep 3 ung vien cuoi cung de lay trung vi cua toan ma tran 3x3
    sort3 final_sort (.in1(min_of_maxes), .in2(mid_of_mids), .in3(max_of_mins), .out_max(), .out_mid(median_val), .out_min());

    // =========================================================================
    // PHAN 2: XU LY VIEN VA KHOANG CACH
    // Muc dich: Xac dinh xem pixel hien tai co nam can sat cac mep cua anh khong
    // =========================================================================
    
    // Tinh khoang cach tu pixel hien tai den canh duoi va canh phai cua buc anh
    // Phai tru di 1 vi he toa do row/col bat dau tu 0 (VD: neu height=1080 thi row lon nhat la 1079)
    wire [15:0] dist_bottom   = height - 16'd1 - row;
    wire [15:0] dist_right = width  - 16'd1 - col;  
    
    // Tim khoang cach ngan nhat xet theo truc Y (so sanh khoang cach den canh tren 'row' va canh duoi)
    wire [15:0] min_y = (row < dist_bottom) ? row : dist_bottom;
    
    // Tim khoang cach ngan nhat xet theo truc X (so sanh khoang cach den canh trai 'col' va canh phai)
    wire [15:0] min_x = (col < dist_right) ? col : dist_right;
    
    // So sanh min_x va min_y de tim ra khoang cach ngan nhat 'd' den bat ky canh nao trong 4 canh
    wire [15:0] d = (min_y < min_x) ? min_y : min_x;
    
    // Kiem tra xem khoang cach ngan nhat 'd' co nho hon quy dinh chieu day vien 'border' hay khong
    wire is_border = (d < {8'b0, border});

    // =========================================================================
    // PHAN 3: TRICH XUAT MAU VIEN TU BORDER PATTERN
    // Muc dich: Lay dung gia tri mau tai vi tri d trong mang flat 512 bit
    // =========================================================================
    
    // Gioi han lai chi so d de tranh loi truy cap vuot qua mang (out-of-bounds)
    // Neu d >= 64, ep gia tri ve vi tri index 63 cuoi cung
    wire [5:0] safe_idx = (d < 8'd64) ? d[5:0] : 6'd63; 

    // Tinh toan vi tri bit bat dau de lay ra khoi mang 512 bit
    // De toi uu phan cung, thay vi dung phep nhan (safe_idx * 8), ta dung phep dich bit trai 3 bit 
    wire [8:0] bit_offset = {safe_idx, 3'b000};

    // Su dung toan tu indexed part-select (+:) de trich xuat dung 8 bit du lieu
    // Vi du: d = 2 -> safe_idx = 2 -> bit_offset = 16 -> lay tu bit [23:16] trong border_pattern_flat
    wire [7:0] border_color = border_pattern_flat[bit_offset +: 8];
    
    // =========================================================================
    // PHAN 4: MUX TINH TOAN DAU RA
    // =========================================================================
    
    // Bo MUX cuoi cung:
    // - Neu pixel dang nam o vung vien (is_border = 1) -> xuat ra mau vien (border_color)
    // - Neu khong nam o vien (is_border = 0) -> xuat ra gia tri sau khi da loc trung vi (median_val)
    assign out_pixel = is_border ? border_color : median_val;

endmodule