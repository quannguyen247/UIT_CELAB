`timescale 1ns / 1ps

// =========================================================================
// Module: tb_median_ip
// Chuc nang: Testbench de mo phong IP wrapper median_ip voi Line Buffer
//            Bom du lieu dang stream (pixel by pixel) va kiem tra handshake
// =========================================================================
module tb_median_ip;
    parameter MAX_WIDTH  = 3840;
    parameter MAX_HEIGHT = 2160;

    // Khoi tao cac mang bo nho
    reg [7:0]  mem_in  [0 : (MAX_WIDTH + 2) * (MAX_HEIGHT + 2) - 1];
    reg [7:0]  mem_out [0 : (MAX_WIDTH * MAX_HEIGHT) - 1];
    reg [31:0] mem_pattern [0 : 7];
    
    // Tin hieu he thong va FSM
    reg clk;
    reg rst_n;
    reg start;
    reg start_load;
    reg [31:0] border_data_in;
    wire load_done;
    reg sim_done;

    // Tin hieu stream du lieu anh
    reg in_valid;
    reg [7:0] in_pixel;
    wire in_ready;

    // Tin hieu ngo ra tu IP
    wire out_valid;
    wire [7:0] out_pixel;
    wire [15:0] out_row;
    wire [15:0] out_col;
    wire busy;
    wire done;
    
    integer WIDTH, HEIGHT, BORDER;

    // Khoi tao module thiet ke chinh (UUT)
    median_ip uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .start_load(start_load),
        .border_data_in(border_data_in),
        .load_done(load_done),
        .width(WIDTH[15:0]), 
        .height(HEIGHT[15:0]),
        .border(BORDER[7:0]),
        .in_valid(in_valid),
        .in_pixel(in_pixel),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_pixel(out_pixel),
        .out_row(out_row),
        .out_col(out_col),
        .busy(busy),
        .done(done)
    );

    // Tao xung nhip clock (100MHz = chu ky 10ns)
    initial begin
        clk = 0;
        sim_done = 0;
        while (!sim_done) #5 clk = ~clk; 
    end

    integer i, total_in_pixels, fd;

    initial begin
        // Buoc 1: Kiem tra tham so truyen vao tu script
        if (!$value$plusargs("WIDTH=%d", WIDTH)    || 
            !$value$plusargs("HEIGHT=%d", HEIGHT)  || 
            !$value$plusargs("BORDER=%d", BORDER)) begin
            $display("Loi: Thieu tham so dong lenh.");
            $finish;
        end
        $display("Cau hinh phan cung -> WIDTH:%0d, HEIGHT:%0d, BORDER:%0d", WIDTH, HEIGHT, BORDER);
        
        total_in_pixels = (WIDTH + 2) * (HEIGHT + 2);

        // Xoa bo nho ket qua
        for (i = 0; i < MAX_WIDTH * MAX_HEIGHT; i = i + 1) begin
            mem_out[i] = 0;
        end

        // Doc file du lieu he so hexa
        $readmemh("temp/input_median.txt", mem_in);
        $readmemh("temp/pattern.txt", mem_pattern);

        // Buoc 2: Reset he thong
        rst_n = 0;
        start = 0;
        start_load = 0;
        border_data_in = 0;
        in_valid = 0;
        in_pixel = 0;

        #20 rst_n = 1;
        #10;

        // Buoc 3: Kich hoat FSM nap vien (8 chu ky x 32 bit)
        @(posedge clk);
        start_load = 1;
        @(posedge clk);
        start_load = 0;
        
        for (i = 0; i < 8; i = i + 1) begin
            border_data_in = mem_pattern[i];
            @(posedge clk);
        end
        
        wait(load_done);
        $display("Nap xong 256-bit border pattern. Bat dau qua trinh loc anh.");
        @(posedge clk);

        // Buoc 4: Khoi dong module IP
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(busy); // Cho den khi IP xac nhan da san sang nhan stream

        // Buoc 5: Bom du lieu vao pipeline dang stream co bat tay (handshake)
        i = 0;
        while (i < total_in_pixels) begin
            in_valid = 1;
            in_pixel = mem_in[i];
            
            @(posedge clk);
            // Chi tang chi so i neu IP xac nhan da nhan du lieu (in_ready == 1)
            if (in_ready) begin
                i = i + 1;
            end
        end
        in_valid = 0; // Ngung gui valid khi da het du lieu

        // Buoc 6: Cho doi xuat ket qua toan bo anh
        wait (done);
        repeat(10) @(posedge clk);

        // Buoc 7: Ghi ket qua ra file txt
        fd = $fopen("temp/output_median.txt", "w");
        if (fd == 0) begin
            $display("Loi: Khong the tao file temp/output_median.txt");
            $finish;
        end
        $writememh("temp/output_median.txt", mem_out, 0, (WIDTH * HEIGHT) - 1);
        $fclose(fd);
        
        $display("Mo phong hoan tat. Du lieu da duoc ghi vao temp/output_median.txt");
        sim_done = 1;
    end

    // Tien trinh chay song song: Hung du lieu tu IP tra ve
    // Su dung toa do out_row va out_col do IP cung cap de dien vao RAM
    always @(posedge clk) begin
        if (out_valid) begin
            mem_out[out_row * WIDTH + out_col] = out_pixel;
        end
    end
endmodule