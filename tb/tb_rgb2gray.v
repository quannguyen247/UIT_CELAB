`timescale 1ns / 1ps

// =========================================================================
// Module: tb_rgb2gray
// Chuc nang: Testbench thuc thi Unit Test cho module rgb2gray
// =========================================================================
module tb_rgb2gray;

    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;
    
    reg [23:0] mem_in  [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [7:0]  mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    
    reg clk;
    reg rst_n;
    reg in_valid;
    reg [7:0] r, g, b;
    reg signed [7:0] brightness; 
    
    wire out_valid;
    wire [7:0] gray_out;
    
    integer WIDTH, HEIGHT, i, out_idx, fd;
    reg sim_done;
    
    rgb2gray uut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_r(r), 
        .in_g(g), 
        .in_b(b),
        .brightness(brightness),
        .out_valid(out_valid),
        .out_gray(gray_out)
    );
    
    // Khoi tao tin hieu clock voi tan so thiet lap san
    initial begin
        clk = 0;
        sim_done = 0;
        while (!sim_done) #5 clk = ~clk;
    end
    
    initial begin
        $display("Cau hinh mo phong -> WIDTH:%0d, HEIGHT:%0d, BRIGHTNESS:%0d", WIDTH, HEIGHT, brightness);
        $readmemh("temp/input_rgb.txt", mem_in);
        
        rst_n = 0;
        in_valid = 0;
        out_idx = 0;
        
        #20 rst_n = 1;
        #10;
        
        // Kich hoat phien day du lieu vao he thong
        for (i = 0; i < WIDTH * HEIGHT; i = i + 1) begin
            {r, g, b} = mem_in[i];
            in_valid = 1;
            @(posedge clk);
        end
        in_valid = 0;

        // Dong bo cho doi qua trinh tinh toan duoc xac nhan hoan tat
        wait(out_idx == WIDTH * HEIGHT);
        repeat(2) @(posedge clk);

        fd = $fopen("temp/output_gray.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file ghi ket qua.");
            $finish;
        end
        $writememh("temp/output_gray.txt", mem_out, 0, (WIDTH * HEIGHT) - 1);
        $fclose(fd);
        
        $display("Mo phong phan cung hoan tat. Ket qua da duoc luu lai.");
        sim_done = 1;
    end

    // Giam sat tin hieu bat tay va ghi lai gia tri dau ra
    always @(posedge clk) begin
        if (out_valid) begin
            mem_out[out_idx] = gray_out;
            out_idx = out_idx + 1;
        end
    end

endmodule