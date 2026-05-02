`timescale 1ns/1ps

module tb_write_master;
    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [31:0] startaddr;
    reg  [31:0] length;
    reg         waitrequest;
    reg         ff_empty;
    reg  [31:0] ff_q;
    wire        ff_readrequest;
    wire        wm_done;
    wire        wm_write;
    wire [31:0] wm_writeaddress;
    wire [31:0] wm_writedata;

    write_master dut (
        .iClk(clk),
        .iReset_n(rst_n),
        .iStart(start),
        .iWM_startaddress(startaddr),
        .iLength(length),
        .iWM_waitrequest(waitrequest),
        .iFF_empty(ff_empty),
        .iFF_q(ff_q),
        .oFF_readrequest(ff_readrequest),
        .oWM_done(wm_done),
        .oWM_write(wm_write),
        .oWM_writeaddress(wm_writeaddress),
        .oWM_writedata(wm_writedata)
    );

    always #5 clk = ~clk;

    integer write_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff_q <= 32'h10;
        end else if (ff_readrequest) begin
            ff_q <= ff_q + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_count <= 0;
        end else if (wm_write && !waitrequest) begin
            write_count <= write_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        startaddr = 32'h0;
        length = 32'h0;
        waitrequest = 1'b0;
        ff_empty = 1'b0;
        ff_q = 32'h10;

        #20;
        rst_n = 1'b1;

        startaddr = 32'h0000_2000;
        length = 32'd16;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        #200;
        if (write_count != 4) $display("WM TB: expected 4 writes, got %0d", write_count);
        $finish;
    end
endmodule
