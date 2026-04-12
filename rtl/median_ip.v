// ============================================================================
// Ten file : median_ip.v
// Mo ta    : IP wrapper tich hop Line Buffer de quan ly du lieu dang stream 
//            cho core median. Dong bo hoa pipeline delay cho toa do.
// ============================================================================
`timescale 1ns / 1ps

module median_ip #(
    parameter integer MAX_WIDTH = 4096 // Xac dinh RAM size cho Line Buffer
) (
    input  wire         clk,   
    input  wire         rst_n, 
    input  wire         start,

    // Nhom giao tiep dieu khien FSM
    input  wire         start_load,     
    input  wire [31:0]  border_data_in, 
    output wire         load_done,      

    // Nhom cau hinh khung anh va vien
    input  wire [15:0]  width,  
    input  wire [15:0]  height, 
    input  wire [7:0]   border, 

    // Nhom giao thuc stream dau vao
    input  wire         in_valid, 
    input  wire [7:0]   in_pixel, 
    output wire         in_ready, 

    // Nhom giao thuc stream dau ra
    output reg          out_valid, 
    output reg  [7:0]   out_pixel, 
    output reg  [15:0]  out_row,   
    output reg  [15:0]  out_col,   

    // Nhom tin hieu kiem soat toan cuc
    output reg          busy, 
    output reg          done  
);

    // Kich thuoc dong tinh ca 2 pixel padding
    localparam integer MAX_PAD_WIDTH = MAX_WIDTH + 2;

    // Line Buffer luu tru 2 hang pixel gan nhat
    reg [7:0] linebuf1 [0:MAX_PAD_WIDTH-1];
    reg [7:0] linebuf2 [0:MAX_PAD_WIDTH-1];

    // Tap thanh ghi cua so 3x3
    reg [7:0] w00, w01, w02;
    reg [7:0] w10, w11, w12;
    reg [7:0] w20, w21, w22;

    // Toa do va bo dem in/out
    reg [15:0] in_row;
    reg [15:0] in_col;
    reg [31:0] input_count;
    reg [31:0] output_count;

    // Tin hieu trung gian truoc khi vao core
    reg        pending_valid;
    reg [15:0] pending_row;
    reg [15:0] pending_col;

    // Thong so anh co tinh ca 2 pixel padding
    wire [15:0] padded_width  = width + 16'd2;
    wire [15:0] padded_height = height + 16'd2;
    
    wire [31:0] total_out = width * height;
    
    // Tai su dung total_out, thay phep nhan bang dich bit va phep cong
    wire [31:0] total_in  = total_out + {15'b0, width, 1'b0} + {15'b0, height, 1'b0} + 32'd4;

    // Chi cho data vao khi he thong dang busy va chua doc du so luong
    wire can_accept = busy && (input_count < total_in);
    assign in_ready = can_accept;

    // Doc truc tiep tu Line Buffer bang non-blocking assign ra ben ngoai
    wire [7:0] read_line1 = linebuf1[in_col];
    wire [7:0] read_line2 = linebuf2[in_col];

    // Ket noi core median ra ben ngoai IP wrapper
    wire       median_out_valid;
    wire [7:0] median_out;

    median u_median (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_load     (start_load),
        .border_data_in (border_data_in),
        .load_done      (load_done),
        .in_valid       (pending_valid),
        .p00(w00), .p01(w01), .p02(w02),
        .p10(w10), .p11(w11), .p12(w12),
        .p20(w20), .p21(w21), .p22(w22),
        .row            (pending_row),
        .col            (pending_col),
        .width          (width),
        .height         (height),
        .border         (border),
        .out_valid      (median_out_valid),
        .out_pixel      (median_out)
    );

    // ========================================================================
    // TAP THANH GHI DICH DONG BO VOI PIPELINE CORE
    // Core loc co pipeline 3 tang -> ket qua tre 3 chu ky clk
    // ========================================================================
    reg [15:0] s1_row, s2_row, s3_row;
    reg [15:0] s1_col, s2_col, s3_col;

    always @(posedge clk) begin
        s1_row <= pending_row; s2_row <= s1_row; s3_row <= s2_row;      
        s1_col <= pending_col; s2_col <= s1_col; s3_col <= s2_col;
    end

    // ========================================================================
    // LOGIC DIEU KHIEN CHINH VA LINE BUFFER
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_count   <= 32'd0;
            output_count  <= 32'd0;
            pending_valid <= 1'b0;
            out_valid     <= 1'b0;
            busy          <= 1'b0;
            done          <= 1'b0;
        end else begin
            done          <= 1'b0;
            pending_valid <= 1'b0; // Auto-clear tung chu ky
            
            // Xac nhan data tu pipeline ra port chinh cua IP
            out_valid <= median_out_valid;
            if (median_out_valid) begin
                out_pixel <= median_out;
                out_row   <= s3_row;
                out_col   <= s3_col;
                if (output_count == (total_out - 1'b1)) begin
                    busy <= 1'b0;
                    done <= 1'b1; // Ket thuc xu ly toan khung hinh
                end else begin
                    output_count <= output_count + 1'b1;
                end
            end

            if (!busy) begin
                if (start) begin
                    in_row        <= 16'd0;
                    in_col        <= 16'd0;
                    input_count   <= 32'd0;
                    output_count  <= 32'd0;
                    pending_valid <= 1'b0;
                    
                    // Bat loi cau hinh sai
                    if ((width == 16'd0) || (height == 16'd0) || (width > MAX_WIDTH[15:0])) begin
                        busy <= 1'b0;
                        done <= 1'b1; 
                    end else begin
                        busy <= 1'b1;
                    end
                end
            end else if (can_accept && in_valid) begin
                
                // Cap nhat Line Buffer (FIFO theo hang)
                linebuf2[in_col] <= read_line1;
                linebuf1[in_col] <= in_pixel;

                // Dich cua so 3x3 sang trai, day cot moi vao ben phai
                w00 <= w01; w01 <= w02; w02 <= read_line2;
                w10 <= w11; w11 <= w12; w12 <= read_line1;
                w20 <= w21; w21 <= w22; w22 <= in_pixel;

                // Kiem tra cua so 3x3 da tich luy vao sau trong vung anh that hay chua
                if ((in_row >= 16'd2) && (in_col >= 16'd2) &&
                    (in_row <= (height + 16'd1)) && (in_col <= (width + 16'd1))) begin
                    pending_valid <= 1'b1;
                    pending_row   <= in_row - 16'd2; // Bu tru offset de ra toa do center
                    pending_col   <= in_col - 16'd2;
                end

                // Tien trinh quet ma tran theo raster scan
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