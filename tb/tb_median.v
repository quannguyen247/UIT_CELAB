`timescale 1ns / 1ps

// =========================================================================
// Module: tb_median
// Chuc nang: Testbench de mo phong IP median voi pipeline 3 tang va FSM
// =========================================================================
module tb_median;
    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;

    // Khoi tao cac mang bo nho
    reg [7:0]  mem_in  [0 : (MAX_WIDTH + 2) * (MAX_HEIGHT + 2) - 1];
    reg [7:0]  mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [31:0] mem_pattern [0 : 7]; // Chuyen thanh 8 block x 32-bit
    
    // Tin hieu he thong va FSM
    reg clk;
    reg rst_n;
    reg start_load;
    reg [31:0] border_data_in;
    wire load_done;
    reg sim_done;

    // Tin hieu du lieu anh
    reg in_valid;
    reg [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;
    reg [15:0] cur_row, cur_col;                           
    
    integer WIDTH, HEIGHT, BORDER; 
    wire out_valid;
    wire [7:0] out_pixel;

    // Khoi tao module thiet ke chinh (UUT)
    median uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_load(start_load),
        .border_data_in(border_data_in),
        .load_done(load_done),
        .in_valid(in_valid),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .row(cur_row), .col(cur_col),
        .width(WIDTH[15:0]), .height(HEIGHT[15:0]),
        .border(BORDER[7:0]),
        .out_valid(out_valid),
        .out_pixel(out_pixel)
    );

    // Tao xung nhip clock (100MHz)
    initial begin
        clk = 0;
        sim_done = 0;
        while (!sim_done) #5 clk = ~clk; 
    end

    integer r, c, i, pad_w, fd;
    integer out_r, out_c;

    initial begin
        // Buoc 1: Nhan tham so truyen vao tu script
        $display("Cau hinh phan cung -> WIDTH:%0d, HEIGHT:%0d, BORDER:%0d", WIDTH, HEIGHT, BORDER);
        pad_w = WIDTH + 2;

        for (i = 0; i < MAX_WIDTH * MAX_HEIGHT; i = i + 1) begin
            mem_out[i] = 0;
        end

        // Doc file du lieu
        $readmemh("temp/input_median.txt", mem_in);
        $readmemh("temp/pattern.txt", mem_pattern);

        // Buoc 2: Reset he thong
        rst_n = 0;
        start_load = 0;
        border_data_in = 0;
        in_valid = 0;
        out_r = 0;
        out_c = 0;

        #20 rst_n = 1;
        #10;

        // Buoc 3: Kich hoat FSM nap vien (8 chu ky x 32 bit)
        @(posedge clk);
        start_load = 1;
        @(posedge clk);
        start_load = 0; // FSM bat dau vao trang thai LOAD
        
        for (i = 0; i < 8; i = i + 1) begin
            border_data_in = mem_pattern[i];
            @(posedge clk);
        end
        
        wait(load_done);
        $display("Nap xong 256-bit border pattern. Bat dau bom pixel vao pipeline.");
        @(posedge clk);

        // Buoc 4: Bom du lieu vao pipeline lien tuc moi chu ky clock
        for (r = 0; r < HEIGHT; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                cur_row = r;
                cur_col = c;
                p00 = mem_in[(r)   * pad_w + (c)];
                p01 = mem_in[(r)   * pad_w + (c + 1)];
                p02 = mem_in[(r)   * pad_w + (c + 2)];
                p10 = mem_in[(r+1) * pad_w + (c)];
                p11 = mem_in[(r+1) * pad_w + (c + 1)];
                p12 = mem_in[(r+1) * pad_w + (c + 2)];
                p20 = mem_in[(r+2) * pad_w + (c)];
                p21 = mem_in[(r+2) * pad_w + (c + 1)];
                p22 = mem_in[(r+2) * pad_w + (c + 2)];

                in_valid = 1;
                @(posedge clk);
            end
        end
        in_valid = 0;

        // Cho doi toan bo ket qua chay het khoi pipeline tang cuoi
        wait (out_r == HEIGHT);
        repeat(5) @(posedge clk);

        // Buoc 5: Xuat ket qua
        fd = $fopen("temp/output_median.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file output_median.txt");
            $finish;
        end
        $writememh("temp/output_median.txt", mem_out, 0, (WIDTH * HEIGHT) - 1);
        $fclose(fd);
        $display("Mo phong hoan tat. Du lieu da duoc ghi vao output_median.txt");
        
        sim_done = 1;
    end

    // Tien trinh chay song song: Hung du lieu tu pipeline tra ve
    always @(posedge clk) begin
        if (out_valid) begin
            mem_out[out_r * WIDTH + out_c] = out_pixel;
            out_c = out_c + 1;
            if (out_c == WIDTH) begin
                out_c = 0;
                out_r = out_r + 1;
            end
        end
    end
endmodule