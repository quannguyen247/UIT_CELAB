// ============================================================================
// Ten file : median.v
// Mo ta    : Core loc trung vi 3x3 tich hop FSM nap vien va pipeline 3 tang.
//            Thuc hien thuat toan sap xep de tim trung vi cua ma tran.
// ============================================================================
`timescale 1ns / 1ps

// ============================================================================
// Module: sort3
// Chuc nang: Sap xep 3 phan tu 8-bit ban dau theo thu tu giam dan (max, mid, min).
// Day la mach to hop thuan tuy khong can xung clk.
// ============================================================================
module sort3 (
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    output wire [7:0] out_max,
    output wire [7:0] out_mid,
    output wire [7:0] out_min
);
    // Tao cac co so sanh de danh gia quan he do lon giua cac cap tin hieu
    wire c12 = (in1 > in2);
    wire c13 = (in1 > in3); 
    wire c23 = (in2 > in3);

    // Dung mux de xac dinh max, mid, min
    assign out_max = (c12 && c13)   ? in1 : (!c12 && c23) ? in2 : in3;
    assign out_min = (!c12 && !c13) ? in1 : (c12 && !c23) ? in2 : in3;
    assign out_mid = (c12 != c13)   ? in1 : (c12 == c23)  ? in2 : in3;
endmodule

// ============================================================================
// Module: median
// Chuc nang: Loc trung vi cho ma tran 3x3 pixel kem co che xu ly vien anh.
// Kien truc: 
// - FSM nap 32 pixel mau vien vao thanh ghi 256-bit (mat 8 chu ky clk).
// - Pipeline 3 tang giup tang fmax cho core.
// ============================================================================
module median (
    input  wire         clk,
    input  wire         rst_n,
    
    // Nhom giao tiep dieu khien FSM
    input  wire         start_load,     // Xung kich hoat nap data vien
    input  wire [31:0]  border_data_in, // Bus data 32-bit (4 pixel/chu ky x 8-bit)
    output reg          load_done,      // Co hoan thanh nap 256-bit vien
    
    // Nhom data hinh anh dau vao (cua so 3x3)
    input  wire         in_valid,       // Co bao hieu ma tran 3x3 da san sang
    input  wire [7:0]   p00, p01, p02,
    input  wire [7:0]   p10, p11, p12,
    input  wire [7:0]   p20, p21, p22,
    
    // Nhom toa do va thong so khung hinh
    input  wire [15:0]  row,            // Toa do Y hien tai cua pixel trung tam
    input  wire [15:0]  col,            // Toa do X hien tai cua pixel trung tam
    input  wire [15:0]  width,          // Chieu rong thuc te cua buc anh
    input  wire [15:0]  height,         // Chieu cao thuc te cua buc anh
    input  wire [7:0]   border,         // Do day cua lop vien

    // Nhom tin hieu xuat ket qua
    output reg          out_valid,      // Co bao hieu out_pixel da hop le
    output reg  [7:0]   out_pixel       // Gia tri pixel sau khi qua bo loc
);

    // ========================================================================
    // PHAN 1: FSM NAP BORDER PATTERN
    // ========================================================================
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam RUN  = 2'b10;

    reg [1:0]   state, next_state;
    reg [2:0]   load_count;             // Dem 8 chu ky nap data
    reg [255:0] border_pattern_reg;     // Thanh ghi dich chua du 32 pixel vien

    // Khoi tuan tu: Cap nhat state va thanh ghi dong bo voi clk
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            load_count <= 3'd0;
            load_done  <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    load_done <= 1'b0;
                    if (start_load) load_count <= 3'd0;
                end

                LOAD: begin
                    // Nap data kieu ghi dich: day 32-bit moi vao MSB, dich phan cu xuong LSB
                    border_pattern_reg <= {border_data_in, border_pattern_reg[255:32]};
                    load_count         <= load_count + 1'b1;
                end

                RUN: begin
                    load_done <= 1'b1; // He thong san sang nhan in_valid vao pipeline
                end
            endcase
        end
    end

    // Khoi to hop: Giai ma trang thai tiep theo va chuyen doi trang thai
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start_load)          next_state = LOAD;
            LOAD: if (load_count == 3'd7)  next_state = RUN;
            RUN:  if (start_load)          next_state = LOAD;
            default:                       next_state = IDLE;
        endcase
    end

    // ========================================================================
    // PHAN 2: PIPELINE 3 TANG DATAPATH (LOC TRUNG VI & TINH KHOANG CACH VIEN)
    // ========================================================================
    reg valid_s1, valid_s2; // Co bao hieu du lieu hop le o tang 1 va tang 2 
                            // cua pipeline
    // ------------------------------------------------------------------------
    // STAGE 1: Sap xep 3 hang rieng biet va tinh toan khoang cach vien
    // ------------------------------------------------------------------------
    wire [7:0] w_r0_max, w_r0_mid, w_r0_min;
    wire [7:0] w_r1_max, w_r1_mid, w_r1_min;
    wire [7:0] w_r2_max, w_r2_mid, w_r2_min;

    sort3 r0_sort (.in1(p00), .in2(p01), .in3(p02), .out_max(w_r0_max), .out_mid(w_r0_mid), .out_min(w_r0_min));
    sort3 r1_sort (.in1(p10), .in2(p11), .in3(p12), .out_max(w_r1_max), .out_mid(w_r1_mid), .out_min(w_r1_min));
    sort3 r2_sort (.in1(p20), .in2(p21), .in3(p22), .out_max(w_r2_max), .out_mid(w_r2_mid), .out_min(w_r2_min));

    // Tinh toan truoc khoang cach bien theo truc X, Y de giam logic delay cho cac stage sau
    wire [15:0] w_dist_bottom = (height - 16'd1) - row;
    wire [15:0] w_dist_right  = (width  - 16'd1) - col;
    
    wire [15:0] w_min_y_comb  = (row < w_dist_bottom) ? row : w_dist_bottom;
    wire [15:0] w_min_x_comb  = (col < w_dist_right)  ? col : w_dist_right;

    // Bao hoa khoang cach xuong 8 bit de tiet kiem thanh ghi pipeline
    wire [7:0] w_min_y_sat = (w_min_y_comb > 16'd255) ? 8'd255 : w_min_y_comb[7:0];
    wire [7:0] w_min_x_sat = (w_min_x_comb > 16'd255) ? 8'd255 : w_min_x_comb[7:0];

    // Tap thanh ghi chot data tu Stage 1 sang Stage 2
    reg [7:0]  s1_r0_max, s1_r1_max, s1_r2_max;
    reg [7:0]  s1_r0_mid, s1_r1_mid, s1_r2_mid;
    reg [7:0]  s1_r0_min, s1_r1_min, s1_r2_min;
    reg [7:0]  s1_min_y, s1_min_x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
        end else if (state == RUN) begin
            valid_s1 <= in_valid;
            if (in_valid) begin
                s1_r0_max <= w_r0_max; s1_r0_mid <= w_r0_mid; s1_r0_min <= w_r0_min;
                s1_r1_max <= w_r1_max; s1_r1_mid <= w_r1_mid; s1_r1_min <= w_r1_min;
                s1_r2_max <= w_r2_max; s1_r2_mid <= w_r2_mid; s1_r2_min <= w_r2_min;
                
                s1_min_y <= w_min_y_sat;
                s1_min_x <= w_min_x_sat;
            end
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 2: Sap xep theo cot va rut trich mau vien thong qua bo MUX
    // ------------------------------------------------------------------------
    wire [7:0] w_min_max, w_mid_mid, w_max_min;

    sort3 c_max_sort (.in1(s1_r0_max), .in2(s1_r1_max), .in3(s1_r2_max), .out_max(),           .out_mid(),           .out_min(w_min_max));
    sort3 c_mid_sort (.in1(s1_r0_mid), .in2(s1_r1_mid), .in3(s1_r2_mid), .out_max(),           .out_mid(w_mid_mid),  .out_min());
    sort3 c_min_sort (.in1(s1_r0_min), .in2(s1_r1_min), .in3(s1_r2_min), .out_max(w_max_min),  .out_mid(),           .out_min());

    // Khoang cach thuc su ngan nhat tu pixel toi bat ky mep nao cua anh
    wire [7:0] w_d = (s1_min_y < s1_min_x) ? s1_min_y : s1_min_x;
    
    // Su dung MUX tai stage 2 de ngan chan critical path lan truyen sang stage 3
    wire w_is_border_comb = (w_d < border);
    wire [4:0] safe_idx   = (w_d < 8'd32) ? w_d[4:0] : 5'd31;
    
    wire [7:0] w_border_color_comb = border_pattern_reg[{safe_idx, 3'b000} +: 8];

    // Tap thanh ghi chot data tu Stage 2 sang Stage 3
    reg [7:0] s2_min_max, s2_mid_mid, s2_max_min;
    reg       s2_is_border;
    reg [7:0] s2_border_color;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
        end else if (state == RUN) begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                s2_min_max <= w_min_max;
                s2_mid_mid <= w_mid_mid;
                s2_max_min <= w_max_min;
                
                s2_is_border    <= w_is_border_comb;
                s2_border_color <= w_border_color_comb;
            end
        end
    end

    // ------------------------------------------------------------------------
    // STAGE 3: Sap xep lay trung vi va lua chon pixel xuat
    // ------------------------------------------------------------------------
    wire [7:0] w_median_val;

    sort3 final_sort (.in1(s2_min_max), .in2(s2_mid_mid), .in3(s2_max_min), .out_max(), .out_mid(w_median_val), .out_min());

    // Xac nhan data dau ra thong qua MUX 2:1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
        end else if (state == RUN) begin
            out_valid <= valid_s2;
            if (valid_s2) begin
                out_pixel <= s2_is_border ? s2_border_color : w_median_val;
            end
        end
    end

endmodule