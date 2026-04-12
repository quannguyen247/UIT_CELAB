`timescale 1ns / 1ps

// =========================================================================
// Module: sort3
// Chuc nang: So sanh va sap xep 3 phan tu su dung mach to hop
// Khong doi vi day la khoi to hop co ban cho mang luoi sap xep
// =========================================================================
module sort3 (
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    output wire [7:0] out_max,
    output wire [7:0] out_mid,
    output wire [7:0] out_min
);
    wire c12 = (in1 > in2);
    wire c13 = (in1 > in3);
    wire c23 = (in2 > in3);

    assign out_max = (c12 && c13) ? in1 : (!c12 && c23) ? in2 : in3;
    assign out_min = (!c12 && !c13) ? in1 : (c12 && !c23) ? in2 : in3;
    assign out_mid = (c12 != c13) ? in1 : (c12 == c23) ? in2 : in3;
endmodule

// =========================================================================
// Module: median
// Chuc nang: Thuc hien thuat toan loc trung vi (median filter) 3x3 
//            FSM nap vien 32-bit x 8 chu ky & Pipeline 3 tang
// =========================================================================
module median (
    input  wire clk,
    input  wire rst_n,
    
    // Tin hieu dieu khien FSM
    input  wire start_load,           // Xung trigger bat dau nap vien
    input  wire [31:0] border_data_in,// Bus 32-bit nap mau vien (4 pixel/chu ky)
    output reg  load_done,            // Co bao hieu da nap xong 256-bit
    
    // Tin hieu du lieu anh
    input  wire in_valid,             // Tin hieu cho biet p00->p22 da hop le
    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,
    input  wire [15:0] row,
    input  wire [15:0] col,
    input  wire [15:0] width,
    input  wire [15:0] height,
    input  wire [7:0] border,

    // Tin hieu ngo ra (da qua pipeline)
    output reg out_valid,             // Co bao hieu data ngo ra hop le
    output reg [7:0] out_pixel
);

    // =========================================================================
    // PHAN 1: FSM NAP BORDER PATTERN (256 bit = 32 pixel)
    // =========================================================================
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam RUN  = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] load_count; // Dem 8 chu ky (0->7)
    reg [255:0] border_pattern_reg; // Thanh ghi chua 32 pixel vien

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_count <= 3'd0;
            border_pattern_reg <= 256'd0;
            load_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    load_done <= 1'b0;
                    if (start_load) load_count <= 3'd0;
                end
                LOAD: begin
                    // Dich bit nap dan bus 32-bit vao MSB (nap tu vi tri 0 len dan)
                    border_pattern_reg <= {border_data_in, border_pattern_reg[255:32]};
                    load_count <= load_count + 1'b1;
                end
                RUN: begin
                    load_done <= 1'b1; // Bao hieu co the chay pipeline
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start_load) next_state = LOAD;
            LOAD: if (load_count == 3'd7) next_state = RUN;
            RUN:  if (start_load) next_state = LOAD; // Cho phep nap lai neu can
            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // PHAN 2: DATAPATH - PIPELINE 3 TANG LOC TRUNG VI VA XU LY VIEN
    // =========================================================================

    // Cờ dieu khien valid qua 3 tang
    reg valid_s1, valid_s2;

    // --- DAY TO HOP TANG 1 ---
    wire [7:0] w_r0_max, w_r0_mid, w_r0_min;
    wire [7:0] w_r1_max, w_r1_mid, w_r1_min;
    wire [7:0] w_r2_max, w_r2_mid, w_r2_min;
    
    sort3 r0_sort (.in1(p00), .in2(p01), .in3(p02), .out_max(w_r0_max), .out_mid(w_r0_mid), .out_min(w_r0_min));
    sort3 r1_sort (.in1(p10), .in2(p11), .in3(p12), .out_max(w_r1_max), .out_mid(w_r1_mid), .out_min(w_r1_min));
    sort3 r2_sort (.in1(p20), .in2(p21), .in3(p22), .out_max(w_r2_max), .out_mid(w_r2_mid), .out_min(w_r2_min));

    wire [15:0] w_dist_bottom = height - 16'd1 - row;
    wire [15:0] w_dist_right  = width  - 16'd1 - col;

    // --- REGISTERS TANG 1 ---
    reg [7:0] s1_r0_max, s1_r1_max, s1_r2_max;
    reg [7:0] s1_r0_mid, s1_r1_mid, s1_r2_mid;
    reg [7:0] s1_r0_min, s1_r1_min, s1_r2_min;
    reg [15:0] s1_row, s1_col, s1_dist_bottom, s1_dist_right;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
            // Cac thanh ghi data khong can reset de giam fanout, chi can valid
        end else if (state == RUN) begin
            valid_s1 <= in_valid;
            if (in_valid) begin
                s1_r0_max <= w_r0_max; s1_r0_mid <= w_r0_mid; s1_r0_min <= w_r0_min;
                s1_r1_max <= w_r1_max; s1_r1_mid <= w_r1_mid; s1_r1_min <= w_r1_min;
                s1_r2_max <= w_r2_max; s1_r2_mid <= w_r2_mid; s1_r2_min <= w_r2_min;
                
                s1_row <= row;
                s1_col <= col;
                s1_dist_bottom <= w_dist_bottom;
                s1_dist_right <= w_dist_right;
            end
        end
    end

    // --- DAY TO HOP TANG 2 ---
    wire [7:0] w_min_max, w_mid_mid, w_max_min;
    
    sort3 c_max_sort (.in1(s1_r0_max), .in2(s1_r1_max), .in3(s1_r2_max), .out_max(), .out_mid(), .out_min(w_min_max));
    sort3 c_mid_sort (.in1(s1_r0_mid), .in2(s1_r1_mid), .in3(s1_r2_mid), .out_max(), .out_mid(w_mid_mid), .out_min());
    sort3 c_min_sort (.in1(s1_r0_min), .in2(s1_r1_min), .in3(s1_r2_min), .out_max(w_max_min), .out_mid(), .out_min());

    wire [15:0] w_min_y = (s1_row < s1_dist_bottom) ? s1_row : s1_dist_bottom;
    wire [15:0] w_min_x = (s1_col < s1_dist_right)  ? s1_col : s1_dist_right;

    // --- REGISTERS TANG 2 ---
    reg [7:0] s2_min_max, s2_mid_mid, s2_max_min;
    reg [15:0] s2_min_y, s2_min_x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s2 <= 1'b0;
        end else if (state == RUN) begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                s2_min_max <= w_min_max;
                s2_mid_mid <= w_mid_mid;
                s2_max_min <= w_max_min;
                s2_min_y <= w_min_y;
                s2_min_x <= w_min_x;
            end
        end
    end

    // --- DAY TO HOP TANG 3 ---
    wire [7:0] w_median_val;
    sort3 final_sort (.in1(s2_min_max), .in2(s2_mid_mid), .in3(s2_max_min), .out_max(), .out_mid(w_median_val), .out_min());

    wire [15:0] w_d = (s2_min_y < s2_min_x) ? s2_min_y : s2_min_x;
    wire w_is_border = (w_d < {8'b0, border});
    
    // Gioi han 32 pixel vien (thay vi 64 nhu cu)
    wire [4:0] safe_idx = (w_d < 16'd32) ? w_d[4:0] : 5'd31; 
    wire [7:0] w_border_color = border_pattern_reg[{safe_idx, 3'b000} +: 8];

    // --- REGISTERS TANG 3 (NGO RA) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_pixel <= 8'd0;
        end else if (state == RUN) begin
            out_valid <= valid_s2;
            if (valid_s2) begin
                out_pixel <= w_is_border ? w_border_color : w_median_val;
            end
        end
    end

endmodule