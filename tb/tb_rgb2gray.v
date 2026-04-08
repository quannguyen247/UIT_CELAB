`timescale 1ns / 1ps

// =========================================================================
// Module: tb_rgb2gray
// Chuc nang: Testbench de mo phong va kiem tra hoat dong cua module rgb2gray
// =========================================================================
module tb_rgb2gray;

    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;
    
    // Khoi tao cac mang bo nho (memory arrays)
    reg [23:0] mem_in  [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [7:0]  mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    
    // Khai bao cac thanh ghi (reg) de bom du lieu vao module
    reg [7:0] r, g, b;
    reg signed [7:0] brightness; 
    wire [7:0] gray_out;
    integer WIDTH, HEIGHT, i, fd;
    
    // Khoi tao module thiet ke chinh (Unit Under Test - UUT)
    rgb2gray uut (
        .r(r), 
        .g(g), 
        .b(b),
        .brightness(brightness),
        .gray(gray_out)
    );
    
    initial begin
        // Buoc 1: Nhan cac tham so cau hinh tu lenh mo phong
        // Neu thieu bat ky tham so nao, testbench se dung lai ngay lap tuc ($finish)
        if (!$value$plusargs("WIDTH=%d", WIDTH)) $finish;
        if (!$value$plusargs("HEIGHT=%d", HEIGHT)) $finish;
        
        // Thiet lap do sang (Mac dinh la 0 neu khong truyen tham so)
        if (!$value$plusargs("BRIGHTNESS=%d", brightness)) brightness = 8'sd0;
        
        $display("Cau hinh mo phong -> WIDTH:%0d, HEIGHT:%0d, BRIGHTNESS:%0d", WIDTH, HEIGHT, brightness);
        
        // Buoc 2: Nap noi dung tu file text vao mang bo nho cua testbench
        $readmemh("temp/input_rgb.txt", mem_in);
        
        // Buoc 3: Quet qua tung diem anh va dua vao mach
        for (i = 0; i < WIDTH * HEIGHT; i = i + 1) begin
            // Nap du lieu vao input cua module
            {r, g, b} = mem_in[i];
            
            // Cho mach to hop on dinh ket qua
            #1; 
            
            // Ghi ket qua vao mang bo nho dau ra
            mem_out[i] = gray_out;
        end

        // Buoc 4: Xuat toan bo noi dung mang bo nho mem_out ra thanh file dang Hex
        // De script post2.py doc file nay va dung lai thanh buc anh xam hoan chinh
        fd = $fopen("temp/output_gray.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file temp/output_gray.txt de ghi ket qua.");
            $finish;
        end
        $fclose(fd);
        $writememh("temp/output_gray.txt", mem_out, 0, (WIDTH * HEIGHT) - 1);
        
        $display("Mo phong phan cung hoan hoan tat. Du lieu da duoc ghi vao output_gray.txt");
    end

endmodule