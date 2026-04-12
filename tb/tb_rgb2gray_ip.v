`timescale 1ns / 1ps

// =========================================================================
// Module: tb_rgb2gray_ip
// Chuc nang: Testbench thuc thi Integration Test cho he thong rgb2gray_ip
// =========================================================================
module tb_rgb2gray_ip;

    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;

    reg [23:0] mem_in  [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [7:0]  mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];

    reg clk;
    reg rst_n;
    reg start;
    reg sim_done;

    integer WIDTH, HEIGHT;
    reg signed [7:0] BRIGHTNESS;
    
    reg in_valid;
    reg [7:0] in_r, in_g, in_b;
    wire in_ready;

    wire out_valid;
    wire [7:0] out_gray;
    wire busy;
    wire done;

    rgb2gray_ip uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .width(WIDTH[15:0]),
        .height(HEIGHT[15:0]),
        .brightness(BRIGHTNESS),
        .in_valid(in_valid),
        .in_r(in_r),
        .in_g(in_g),
        .in_b(in_b),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_gray(out_gray),
        .busy(busy),
        .done(done)
    );

    // Khoi tao tin hieu clock voi tan so thiet lap san
    initial begin
        clk = 0;
        sim_done = 0;
        while (!sim_done) #10 clk = ~clk; 
    end

    integer i, out_idx, total_pixels, fd;

    initial begin
        if (!$value$plusargs("WIDTH=%d", WIDTH)    || 
            !$value$plusargs("HEIGHT=%d", HEIGHT)  || 
            !$value$plusargs("BRIGHTNESS=%d", BRIGHTNESS)) begin
            $display("Loi: Thieu tham so dong lenh.");
            $finish;
        end
        $display("Cau hinh phan cung -> WIDTH:%0d, HEIGHT:%0d, BRIGHTNESS:%0d", WIDTH, HEIGHT, BRIGHTNESS);
        
        total_pixels = WIDTH * HEIGHT;

        for (i = 0; i < MAX_WIDTH * MAX_HEIGHT; i = i + 1) begin
            mem_out[i] = 8'd0;
        end

        $readmemh("temp/input_rgb.txt", mem_in);

        rst_n = 0;
        start = 0;
        in_valid = 0;
        in_r = 0; in_g = 0; in_b = 0;
        out_idx = 0;

        #20 rst_n = 1;
        repeat(5) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(busy);

        // Kich hoat phien day du lieu vao he thong
        i = 0;
        while (i < total_pixels) begin
            in_valid = 1;
            {in_r, in_g, in_b} = mem_in[i];
            
            @(posedge clk);
            if (in_ready) begin
                i = i + 1; 
            end
        end
        in_valid = 0;

        wait(done);
        repeat(5) @(posedge clk);

        fd = $fopen("temp/output_gray.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file output_gray.txt.");
            $finish;
        end
        $writememh("temp/output_gray.txt", mem_out, 0, total_pixels - 1);
        $fclose(fd);
        
        $display("Mo phong hoan tat. Du lieu da duoc ghi vao output_gray.txt");
        sim_done = 1;
    end

    // Giam sat tin hieu bat tay va ghi lai gia tri dau ra
    always @(posedge clk) begin
        if (out_valid) begin
            mem_out[out_idx] = out_gray;
            out_idx = out_idx + 1;
        end
    end

endmodule