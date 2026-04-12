`timescale 1ns / 1ps

// =========================================================================
// Module: median_ip
// Mo ta:
//   Wrapper tich hop Line Buffer de nhan du lieu
//   pixel dang stream va FSM cho bo loc trung vi 3x3.
//   Tu dong dong bo hoa do tre (delay) cua pipeline 3 tang trong bo loc
//   de dam bao pixel va toa do (row/col) xuat ra tu IP
// =========================================================================
module median_ip #(
    // Tham so xac dinh chieu rong toi da cua buc anh de cap phat RAM cho Line Buffer
    parameter integer MAX_WIDTH = 4096
) (
    input  wire         clk,   
    input  wire         rst_n, 
    input  wire         start,

    // Nhom tin hieu giao tiep FSM tu he thong truyen xuong loi Median
    input  wire         start_load,     // Xung bat dau nap du lieu vien
    input  wire [31:0]  border_data_in, // Bus du lieu 32-bit nap mau vien
    output wire         load_done,      // Co bao hieu FSM da nap xong mau vien

    // Nhom tin hieu cau hinh kich thuoc anh va vien
    input  wire [15:0]  width,  // Chieu rong thuc te cua buc anh
    input  wire [15:0]  height, // Chieu cao thuc te cua buc anh
    input  wire [7:0]   border, // Do day cua lop vien xung quanh

    // Nhom giao thuc Stream de Nhan du lieu
    input  wire         in_valid, // Co bao hieu du lieu pixel dau vao dang hop le
    input  wire [7:0]   in_pixel, // Gia tri pixel dau vao
    output wire         in_ready, // Tin hieu IP phan hoi cho biet da san sang nhan in_pixel chua

    // Nhom giao thuc Stream de Xuat du lieu
    output reg          out_valid, // Co bao hieu du lieu pixel dau ra da qua xu ly va hop le
    output reg  [7:0]   out_pixel, // Gia tri pixel sau khi loc trung vi
    output reg  [15:0]  out_row,   // Toa do hang (Y) tuong ung voi out_pixel
    output reg  [15:0]  out_col,   // Toa do cot (X) tuong ung voi out_pixel

    // Nhom tin hieu trang thai chung
    output reg          busy, // Co bao hieu IP dang trong qua trinh xu ly anh
    output reg          done  // Co bao hieu IP da hoan thanh xu ly toan bo khung hinh
);
    // Kich thuoc dong toi da sau khi them 2 pixel padding o 2 ben
    localparam integer MAX_PAD_WIDTH = MAX_WIDTH + 2;

    // Khoi tao 2 Line Buffer de luu tru tam thoi 2 hang pixel gan nhat.
    // Ket hop voi hang pixel dang chay vao (in_pixel), ta se co du 3 hang de tao cua so 3x3.
    reg [7:0] linebuf1 [0:MAX_PAD_WIDTH-1];
    reg [7:0] linebuf2 [0:MAX_PAD_WIDTH-1];

    // Khai bao 9 thanh ghi chua cac diem anh cua cua so 3x3 hien tai
    reg [7:0] w00, w01, w02;
    reg [7:0] w10, w11, w12;
    reg [7:0] w20, w21, w22;

    // Cac bien dem va toa do dau vao
    reg [15:0] in_row; // Toa do hang cua pixel dang nap vao
    reg [15:0] in_col; // Toa do cot cua pixel dang nap vao
    reg [31:0] input_count;  // Tong so diem anh da duoc nap vao he thong
    reg [31:0] output_count; // Tong so diem anh da duoc xuat ra khoi he thong

    // Cac bien tam de giu trang thai chuan bi nap vao bo loc (Median Core)
    reg        pending_valid; // Co bao hieu cua so 3x3 da day du va san sang day vao bo loc
    reg [15:0] pending_row;   // Toa do hang cua pixel trung tam cua so 3x3
    reg [15:0] pending_col;   // Toa do cot cua pixel trung tam cua so 3x3

    // Thanh ghi tam de doc du lieu tu Line Buffer ra truoc khi ghi vao cua so 3x3
    reg [7:0] row1_pix;
    reg [7:0] row2_pix;

    // Tinh toan kich thuoc anh sau khi da them vien ao (padding)
    // Moi chieu cong them 2 (1 cho vien truoc, 1 cho vien sau)
    wire [15:0] padded_width  = width + 16'd2;
    wire [15:0] padded_height = height + 16'd2;
    
    // Tong so pixel can nap vao (bao gom ca vien) va tong so pixel xuat ra (chi lay anh that)
    wire [31:0] total_in      = padded_width * padded_height;
    wire [31:0] total_out     = width * height;

    // IP chi san sang nhan du lieu neu dang trong trang thai ban (busy) va chua nhan du so pixel
    wire can_accept = busy && (input_count < total_in);
    assign in_ready = can_accept;

    // Day (wire) ket noi tu output cua bo loc (Median Core) len Wrapper nay
    wire median_out_valid;
    wire [7:0] median_out;

    // Khoi tao Core IP thuc hien thuat toan loc trung vi (Module median da comment o file truoc)
    median u_median (
        .clk(clk),
        .rst_n(rst_n),
        .start_load(start_load),
        .border_data_in(border_data_in),
        .load_done(load_done),
        .in_valid(pending_valid), // Cap tin hieu valid khi cua so 3x3 tao xong
        .p00(w00), .p01(w01), .p02(w02), // Trach xuat cua so 3x3 truyen vao core
        .p10(w10), .p11(w11), .p12(w12),
        .p20(w20), .p21(w21), .p22(w22),
        .row(pending_row),               // Truyen toa do hien tai vao
        .col(pending_col),
        .width(width),
        .height(height),
        .border(border),
        .out_valid(median_out_valid),    // Nhan co valid tu core sau 3 chu ky pipeline
        .out_pixel(median_out)           // Nhan pixel ket qua da loc
    );

    // =========================================================================
    // SHIFT REGISTER 3 TANG CHO TOA DO X/Y (DONG BO HOA PIPELINE DELAY)
    // Do bo loc median co pipeline 3 tang, no mat 3 chu ky clock
    // de tinh toan xong 1 pixel. Chung ta phai cho toa do
    // Y (row) va X (col) cung bi "tre" di 3 chu ky.
    // =========================================================================
    reg [15:0] s1_row, s2_row, s3_row;
    reg [15:0] s1_col, s2_col, s3_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset toan bo cac thanh ghi dich ve 0
            s1_row <= 16'd0; s2_row <= 16'd0; s3_row <= 16'd0;
            s1_col <= 16'd0; s2_col <= 16'd0; s3_col <= 16'd0;
        end else begin
            // Dich toa do qua tung tang mot moi khi co xung nhip
            s1_row <= pending_row;
            s2_row <= s1_row;      
            s3_row <= s2_row;      
            
            s1_col <= pending_col;
            s2_col <= s1_col;
            s3_col <= s2_col;
        end
    end

    // =========================================================================
    // LOGIC DIEU KHIEN CHINH VA CAP NHAT LINE BUFFER
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset toan bo he thong khi co tin hieu rst_n muc thap
            w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
            w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
            w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;

            in_row <= 16'd0; in_col <= 16'd0;
            input_count  <= 32'd0;
            output_count <= 32'd0;
            pending_valid <= 1'b0;
            pending_row   <= 16'd0; pending_col   <= 16'd0;

            out_valid <= 1'b0; out_pixel <= 8'd0;
            out_row   <= 16'd0; out_col   <= 16'd0;

            busy <= 1'b0; done <= 1'b0;
        end else begin
            // Mac dinh keo cac co valid ve 0 tung chu ky, no chi bang 1 trong 1 chu ky nhat dinh
            done <= 1'b0;
            pending_valid <= 1'b0;
            
            // Dong bo tin hieu output tu pipeline tang 3 cua core vao thanh ghi xuat cua Wrapper
            out_valid <= median_out_valid;
            
            // Kiem tra neu bo loc bao co ket qua, cap nhat pixel va toa do ra ngoai
            if (median_out_valid) begin
                out_pixel <= median_out;
                out_row   <= s3_row;
                out_col   <= s3_col;
                
                // Kiem tra xem da ket xuat du toan bo so pixel cua anh chua
                if (output_count == (total_out - 1'b1)) begin
                    busy <= 1'b0; // Tat co busy
                    done <= 1'b1; // Bat co done bao da xu ly xong ca khung hinh
                end else begin
                    output_count <= output_count + 1'b1; // Tang bien dem output neu chua xong
                end
            end

            // Kiem tra trang thai cua stream vao
            if (!busy) begin
                // Neu dang ranh (busy = 0) va co xung 'start', khoi tao tat ca thong so de chuan bi frame moi
                if (start) begin
                    w00 <= 8'd0; w01 <= 8'd0; w02 <= 8'd0;
                    w10 <= 8'd0; w11 <= 8'd0; w12 <= 8'd0;
                    w20 <= 8'd0; w21 <= 8'd0; w22 <= 8'd0;
                    in_row <= 16'd0; in_col <= 16'd0;
                    input_count  <= 32'd0;
                    output_count <= 32'd0;
                    pending_valid <= 1'b0;
                    
                    // Kiem tra loi cau hinh kich thuoc (Khong co (= 0), hoac lon hon MAX_WIDTH)
                    if ((width == 16'd0) || (height == 16'd0) || (width > MAX_WIDTH[15:0])) begin
                        busy <= 1'b0;
                        done <= 1'b1; // Bao done luon vi khong the chay
                    end else begin
                        busy <= 1'b1; // Bat dau tien trinh chay
                    end
                end
            end else if (can_accept && in_valid) begin
                // Neu dang busy, co the nhan data (can_accept) va data dau vao dang valid
                
                // Buoc 1: Doc pixel cung cot tu 2 Line Buffer truoc ra bien tam
                row1_pix = linebuf1[in_col];
                row2_pix = linebuf2[in_col];

                // Buoc 2: Ghi de cac gia tri vao Line Buffer the kieu cuon day (FIFO nhung theo hang)
                linebuf2[in_col] <= row1_pix; // Hang cu nhat nhan data cua hang truoc do
                linebuf1[in_col] <= in_pixel; // Hang gan nhat nhan pixel moi nhat vua chay vao

                // Buoc 3: Cap nhat cua so 3x3 bang cach dich no sang ben trai 1 don vi
                // w02, w12, w22 nam o cot phai cung cua cua so, se nhan data moi nhat tu buffer va in_pixel
                w00 <= w01; w01 <= w02; w02 <= row2_pix;
                w10 <= w11; w11 <= w12; w12 <= row1_pix;
                w20 <= w21; w21 <= w22; w22 <= in_pixel;

                // Kiem tra xem cua so 3x3 da di vao khu vuc anh that (truoc do dang nap vien ao pad)
                // in_row >= 2 va in_col >= 2 tuc la da nap xong du 3 hang va 3 cot dau tien, cua so da full
                if ((in_row >= 16'd2) && (in_col >= 16'd2) &&
                    (in_row <= (height + 16'd1)) && (in_col <= (width + 16'd1))) begin
                    pending_valid <= 1'b1;          // Bao hieu cua so da co gia tri hop le
                    pending_row   <= in_row - 16'd2;// Tinh toan lai toa do cua pixel trung tam cua so
                    pending_col   <= in_col - 16'd2;
                end

                // Quan ly viec quet pixel (Quet tung cot tren cung 1 hang tu trai sang phai)
                input_count <= input_count + 1'b1;
                
                // Neu da quet het chieu rong cua anh thi xuong hang tiep theo
                if (in_col == (padded_width - 1'b1)) begin
                    in_col <= 16'd0;          // Reset cot ve 0
                    in_row <= in_row + 1'b1;  // Tang hang len 1
                end else begin
                    in_col <= in_col + 1'b1;  // Neu chua het hang thi di tiep sang cot ben phai
                end
            end
        end
    end
endmodule