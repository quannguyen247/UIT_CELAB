`timescale 1ns / 1ps

// =========================================================================
// Module: sort3
// Chuc nang: So sanh va sap xep 3 phan tu 8-bit su dung mach to hop.
// Khong su dung xung clock, tin hieu dau ra se thay doi ngay lap tuc theo dau vao.
// =========================================================================
module sort3 (
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    output wire [7:0] out_max,
    output wire [7:0] out_mid,
    output wire [7:0] out_min
);
    // Buoc 1: Tao ra cac co so sanh de kiem tra quan he giua cac cap tin hieu
    wire c12 = (in1 > in2); 
    wire c13 = (in1 > in3); 
    wire c23 = (in2 > in3); 

    // Buoc 2: Su dung khoi multiplexer 3 ngo vao de chon gia tri phu hop
    assign out_max = (c12 && c13) ? in1 : (!c12 && c23) ? in2 : in3;
    assign out_min = (!c12 && !c13) ? in1 : (c12 && !c23) ? in2 : in3;
    assign out_mid = (c12 != c13) ? in1 : (c12 == c23) ? in2 : in3;
endmodule

// ============================================================================================
// Module: median
// Chuc nang: Thuc hien thuat toan loc trung vi cho ma tran 3x3 pixel.
// Tich hop FSM de nap 32 pixel mau vien vao thanh ghi 256-bit trong 8 chu ky.
// Tich hop Pipeline 3 tang de toi uu hoa tan so hoat dong.
// ============================================================================================
module median (
    input  wire clk,
    input  wire rst_n,
    
    // Nhom tin hieu dieu khien FSM
    input  wire start_load,           // Xung kich hoat de bat dau qua trinh nap data vien
    input  wire [31:0] border_data_in,// Bus du lieu 32-bit nap mau vien (Moi chu ky nap 4 pixel x 8-bit)
    output reg  load_done,            // Co bao hieu da nap hoan tat toan bo 256-bit vien
    
    // Nhom tin hieu du lieu hinh anh dau vao
    input  wire in_valid,             // Co bao hieu du lieu cua so ma tran 3x3 (p00 den p22) da san sang
    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,
    input  wire [15:0] row,           // Toa do hang (y) hien tai cua pixel trung tam trong buc anh
    input  wire [15:0] col,           // Toa do cot (x) hien tai cua pixel trung tam trong buc anh
    input  wire [15:0] width,         // Chieu rong tong the cua buc anh
    input  wire [15:0] height,        // Chieu cao tong the cua buc anh
    input  wire [7:0] border,         // Do day cua lop vien

    // Nhom tin hieu dau ra
    output reg out_valid,             // Co bao hieu du lieu pixel dau ra da hop le 
    output reg [7:0] out_pixel        // Gia tri 8-bit cua pixel sau khi da qua bo loc trung vi
);

    // ============================================================================================
    // PHAN 1: FSM NAP BORDER PATTERN
    // ============================================================================================
    
    // Khai bao cac ma trang thai cua FSM
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam RUN  = 2'b10;

    reg [1:0] state, next_state;    // Thanh ghi luu trang thai hien tai va trang thai tiep theo
    reg [2:0] load_count;           // Bo dem 3-bit, dung de dem 8 chu ky nap
    reg [255:0] border_pattern_reg; // Thanh ghi dich 256-bit de luu du 32 pixel vien

    // Khoi tuan tu: Cap nhat trang thai va cac thanh ghi theo xung clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset toan bo he thong ve trang thai mac dinh
            state <= IDLE;
            load_count <= 3'd0;
            border_pattern_reg <= 256'd0;
            load_done <= 1'b0;
        end else begin
            // Chuyen sang trang thai tiep theo
            state <= next_state;
            
            case (state)
                IDLE: begin
                    load_done <= 1'b0; // Keo co done xuong muc thap
                    if (start_load) load_count <= 3'd0; // Neu co lenh start, reset bo dem de chuan bi nap
                end
                LOAD: begin
                    // Qua trinh nap: Dung phuong phap ghi dich
                    // Dua 32-bit (4 pixel) moi vao MSB
                    // Dong thoi day cac bit cu xuong LSB
                    border_pattern_reg <= {border_data_in, border_pattern_reg[255:32]};
                    load_count <= load_count + 1'b1; // Tang bo dem chu ky len 1
                end
                RUN: begin
                    load_done <= 1'b1; // Dat co len 1 de bao hieu he thong san sang tiep nhan in_valid va chay pipeline
                end
            endcase
        end
    end

    // Khoi to hop: Xac dinh dieu kien de chuyen trang thai tiep theo
    always @(*) begin
        next_state = state; // Mac dinh la giu nguyen trang thai
        case (state)
            // Dang o IDLE, co tin hieu start_load thi nhay sang LOAD
            IDLE: if (start_load) next_state = LOAD; 
            // Dang o LOAD, neu da dem du 8 chu ky thi nhay sang RUN
            LOAD: if (load_count == 3'd7) next_state = RUN;
            // Dang o RUN, neu muon nap lai vien thi quay lai LOAD
            RUN:  if (start_load) next_state = LOAD; 
            default: next_state = IDLE; // Phong ngua loi state
        endcase
    end

    // ============================================================================================
    // PHAN 2: PIPELINE 3 TANG (LOC TRUNG VI VA XU LY TOA DO VIEN)
    // ============================================================================================

    // Thanh ghi dung de day tin hieu 'valid' di qua tung tang cua pipeline de dong bo hoa
    reg valid_s1, valid_s2;

    // ----------------------------------------------------------------------------
    // TANG PIPELINE 1 (STAGE 1): Sap xep tung hang rieng biet va Tinh khoang cach
    // ----------------------------------------------------------------------------
    
    // Khai bao cac day (wire) nhan ket qua to hop tu cac bo sort3
    wire [7:0] w_r0_max, w_r0_mid, w_r0_min;
    wire [7:0] w_r1_max, w_r1_mid, w_r1_min;
    wire [7:0] w_r2_max, w_r2_mid, w_r2_min;
    
    // Thuc hien sap xep 3 pixel tren cung 1 hang
    sort3 r0_sort (.in1(p00), .in2(p01), .in3(p02), .out_max(w_r0_max), .out_mid(w_r0_mid), .out_min(w_r0_min));
    sort3 r1_sort (.in1(p10), .in2(p11), .in3(p12), .out_max(w_r1_max), .out_mid(w_r1_mid), .out_min(w_r1_min));
    sort3 r2_sort (.in1(p20), .in2(p21), .in3(p22), .out_max(w_r2_max), .out_mid(w_r2_mid), .out_min(w_r2_min));

    // Tinh toan khoang cach tu pixel hien tai den bien duoi va bien phai cua buc anh
    // Tuong duong voi: khoang_cach = chieu_dai_toi_da - toa_do_hien_tai - 1
    wire [15:0] w_dist_bottom = height - 16'd1 - row;
    wire [15:0] w_dist_right  = width  - 16'd1 - col;

    // Khai bao cac thanh ghi (reg) de chot (latch) du lieu o cuoi Tang 1, sang dau Tang 2
    reg [7:0] s1_r0_max, s1_r1_max, s1_r2_max;
    reg [7:0] s1_r0_mid, s1_r1_mid, s1_r2_mid;
    reg [7:0] s1_r0_min, s1_r1_min, s1_r2_min;
    reg [15:0] s1_row, s1_col, s1_dist_bottom, s1_dist_right;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0; // Chi can reset tin hieu dieu khien
                              // Khong reset thanh ghi du lieu de tiet kiem tai nguyen (giam fanout)
        end else if (state == RUN) begin
            // Chi nhan du lieu vao pipeline khi FSM dang o trang thai RUN
            valid_s1 <= in_valid;
            if (in_valid) begin
                // Chot du lieu da sap xep tung hang vao thanh ghi cua Tang 1
                s1_r0_max <= w_r0_max; s1_r0_mid <= w_r0_mid; s1_r0_min <= w_r0_min;
                s1_r1_max <= w_r1_max; s1_r1_mid <= w_r1_mid; s1_r1_min <= w_r1_min;
                s1_r2_max <= w_r2_max; s1_r2_mid <= w_r2_mid; s1_r2_min <= w_r2_min;
                
                // Chot du lieu toa do va khoang cach bien
                s1_row <= row;
                s1_col <= col;
                s1_dist_bottom <= w_dist_bottom;
                s1_dist_right <= w_dist_right;
            end
        end
    end

    // ----------------------------------------------------------------------------
    // TANG PIPELINE 2 (STAGE 2): Sap xep theo cot va Tim khoang cach toi thieu 
    // ----------------------------------------------------------------------------
    
    // Theo thuat toan loc trung vi nhan: Ta nhom cac max, mid, min thanh cac cot rieng biet de sap xep
    wire [7:0] w_min_max;
    wire [7:0] w_mid_mid;
    wire [7:0] w_max_min;
    
    // Chu y cac chan bi bo trong (de trong giua hai dau ngoac): Viec nay co nghia la ta khong can lay tin hieu o output do ra de xai, giup trinh tong hop (synthesizer) bo qua logic thua.
    sort3 c_max_sort (.in1(s1_r0_max), .in2(s1_r1_max), .in3(s1_r2_max), .out_max(), .out_mid(), .out_min(w_min_max));
    sort3 c_mid_sort (.in1(s1_r0_mid), .in2(s1_r1_mid), .in3(s1_r2_mid), .out_max(), .out_mid(w_mid_mid), .out_min());
    sort3 c_min_sort (.in1(s1_r0_min), .in2(s1_r1_min), .in3(s1_r2_min), .out_max(w_max_min), .out_mid(), .out_min());

    // Tim ra khoang cach gan nhat theo truc Y (so sanh khoang cach tren cung va duoi cung)
    wire [15:0] w_min_y = (s1_row < s1_dist_bottom) ? s1_row : s1_dist_bottom;
    // Tim ra khoang cach gan nhat theo truc X (so sanh khoang cach ben trai va ben phai)
    wire [15:0] w_min_x = (s1_col < s1_dist_right)  ? s1_col : s1_dist_right;

    // Khai bao cac thanh ghi de chot du lieu o cuoi Tang 2, sang dau Tang 3
    reg [7:0] s2_min_max, s2_mid_mid, s2_max_min;
    reg [15:0] s2_min_y, s2_min_x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
        end else if (state == RUN) begin
            // Day tin hieu valid tu Tang 1 sang Tang 2
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                // Chot 3 gia tri trung gian vao thanh ghi de chuan bi cho luot sap xep cuoi
                s2_min_max <= w_min_max;
                s2_mid_mid <= w_mid_mid;
                s2_max_min <= w_max_min;
                
                // Chot khoang cach truc X va Y nho nhat
                s2_min_y <= w_min_y;
                s2_min_x <= w_min_x;
            end
        end
    end

    // ----------------------------------------------------------------------------
    // TANG PIPELINE 3 (STAGE 3): Xuat ket qua Median va xu ly vien
    // ----------------------------------------------------------------------------
    
    wire [7:0] w_median_val; // Ket qua gia tri trung vi cuoi cung cua cua so 3x3
    
    // De tim gia tri trung vi cua 9 phan tu theo thuat toan nay, ta chi can tim gia tri nam giua
    // cua 3 phan tu duoc rut ra tu tang 2 (min cua max, mid cua mid, max cua min)
    sort3 final_sort (.in1(s2_min_max), .in2(s2_mid_mid), .in3(s2_max_min), .out_max(), .out_mid(w_median_val), .out_min());

    // w_d: Tim khoang cach gan nhat thuc su tu pixel den bat ky ria (mep) nao cua buc anh.
    wire [15:0] w_d = (s2_min_y < s2_min_x) ? s2_min_y : s2_min_x;
    
    // Kiem tra xem khoang cach w_d co nho hon do day cua vien hay khong
    // Neu nho hon, chung to pixel nay dang nam trong khu vuc can ve vien
    wire w_is_border = (w_d < {8'b0, border}); // Mo rong gia tri 'border' tu 8-bit thanh 16-bit de so sanh
    
    // Xac dinh chi so (index) de lay mau sac vien tu thanh ghi border_pattern_reg
    // Thiet ke gioi han toi da la 32 pixel vien (tu 0 den 31).
    // Neu khoang cach w_d >= 32 thi ep no lay phan tu cuoi cung (index = 31).
    wire [4:0] safe_idx = (w_d < 16'd32) ? w_d[4:0] : 5'd31; 
    
    // Trich xuat gia tri mau vien 8-bit tu thanh ghi 256-bit dua vao chi so 'safe_idx'.
    // {safe_idx, 3'b000} la phep dich trai 3 bit de chi den dung byte can lay
    wire [7:0] w_border_color = border_pattern_reg[{safe_idx, 3'b000} +: 8];

    // Chot du lieu xuat ra khoi IP
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_pixel <= 8'd0;
        end else if (state == RUN) begin
            // Xac nhan du lieu o dau ra da san sang
            out_valid <= valid_s2;
            if (valid_s2) begin
                // Neu pixel nam trong vung vien thi xuat mau vien ra out_pixel
                // Neu khong nam trong vung vien thi xuat gia tri loc trung vi (w_median_val)
                out_pixel <= w_is_border ? w_border_color : w_median_val;
            end
        end
    end

endmodule