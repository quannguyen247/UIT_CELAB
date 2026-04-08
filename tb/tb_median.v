`timescale 1ns / 1ps

// =========================================================================
// Module: tb_median
// Chuc nang: Testbench de mo phong va kiem tra hoat dong cua module median
// =========================================================================
module tb_median;

    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;

    // Khoi tao cac mang bo nho (memory arrays)
    reg [7:0] mem_in  [0 : (MAX_WIDTH + 2) * (MAX_HEIGHT + 2) - 1];
    reg [7:0] mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [7:0] mem_pattern [0 : 63];

    // Khai bao cac thanh ghi (reg) de bom du lieu vao module
    reg [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22; 
    reg [15:0] cur_row, cur_col;                           
    reg [511:0] pattern_flat;                              
    
    integer WIDTH, HEIGHT, BORDER; 
    wire [7:0] out_pixel;         

    // Khoi tao module thiet ke chinh (Unit Under Test)
    median uut (
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .row(cur_row), .col(cur_col),
        .width(WIDTH[15:0]), .height(HEIGHT[15:0]),
        .border(BORDER[7:0]),
        .border_pattern_flat(pattern_flat),
        .out_pixel(out_pixel)
    );

    // Bien chay cho vong lap 
    integer r, c, i, pad_w, fd;

    initial begin
        // Buoc 1: Nhan cac tham so cau hinh tu lenh mo phong
        // Neu thieu bat ky tham so nao, testbench se dung lai ngay lap tuc ($finish)
        if (!$value$plusargs("WIDTH=%d", WIDTH) || !$value$plusargs("HEIGHT=%d", HEIGHT) || !$value$plusargs("BORDER=%d", BORDER)) begin
            $finish;
        end

        $display("Cau hinh phan cung -> WIDTH:%0d, HEIGHT:%0d, BORDER:%0d", WIDTH, HEIGHT, BORDER);
        
        // Chieu rong cua anh dau vao co tinh them 2 pixel padding
        pad_w = WIDTH + 2;

        // Buoc 2: Xoa sach bo nho output de tranh du lieu rac anh huong den ket qua
        for (i = 0; i < MAX_WIDTH * MAX_HEIGHT; i = i + 1) begin
            mem_out[i] = 0;
        end

        // Buoc 3: Nap noi dung tu file text vao mang bo nho cua testbench
        $readmemh("temp/input_median.txt", mem_in);
        $readmemh("temp/pattern.txt", mem_pattern);
        
        pattern_flat = 512'b0;

        // Buoc 4: Trai phang mang pattern tu 64 block 8-bit thanh 1 vector 512-bit
        for (i = 0; i < 64; i = i + 1) begin
            pattern_flat[i*8 +: 8] = mem_pattern[i];
        end

        // Buoc 5: Quet qua tung diem anh anh that va dua vao mach
        for (r = 0; r < HEIGHT; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                // Cap nhat toa do hien tai de mach tinh toan khoang cach vien
                cur_row = r;
                cur_col = c;
                
                // Trich xuat 9 pixel xung quanh vi tri (r, c) tao thanh cua so 3x3
                // R va C bat dau tu 0, nhung anh mem_in co padding nen r tuong duong hang 0 cua anh that
                // Cong thuc (r * pad_w + c) giup mapping tu toa do 2D sang dia chi 1D cua mang mem_in
                p00 = mem_in[(r)   * pad_w + (c)];
                p01 = mem_in[(r)   * pad_w + (c + 1)];
                p02 = mem_in[(r)   * pad_w + (c + 2)];
                p10 = mem_in[(r+1) * pad_w + (c)];
                p11 = mem_in[(r+1) * pad_w + (c + 1)];
                p12 = mem_in[(r+1) * pad_w + (c + 2)];
                p20 = mem_in[(r+2) * pad_w + (c)];
                p21 = mem_in[(r+2) * pad_w + (c + 1)];
                p22 = mem_in[(r+2) * pad_w + (c + 2)];

                // Cho mach to hop on dinh ket qua truoc khi ghi vao bo nho output
                #1;
                
                // Do day la mach to hop, ket qua out_pixel co ngay lap tuc
                // Ghi ket qua vao mang bo nho dau ra
                mem_out[r * WIDTH + c] = out_pixel;
            end
        end

        // Buoc 6: Xuat toan bo noi dung mang bo nho mem_out ra thanh file dang Hex
        // De script post1.py doc file nay va dung lai thanh buc anh hoan chinh
        fd = $fopen("temp/output_median.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file temp/output_median.txt de ghi ket qua.");
            $finish;
        end
        $fclose(fd);
        $writememh("temp/output_median.txt", mem_out, 0, (WIDTH * HEIGHT) - 1);
        $display("Mo phong phan cung hoan tat. Du lieu da duoc ghi vao output_median.txt");
    end
endmodule