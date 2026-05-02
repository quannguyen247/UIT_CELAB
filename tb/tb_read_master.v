`timescale 1ns/1ps

module tb_read_master;
    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [31:0] length;
    reg  [31:0] startaddr;
    reg         readdatavalid;
    reg         waitrequest;
    wire        rm_read;
    wire [31:0] rm_readaddress;
    reg  [31:0] readdata;
    reg         ff_almostfull;
    wire        ff_writerequest;
    wire [31:0] ff_data;

    read_master dut (
        .iClk(clk),
        .iReset_n(rst_n),
        .iStart(start),
        .iLength(length),
        .iRM_startaddress(startaddr),
        .iRM_readdatavalid(readdatavalid),
        .iRM_waitrequest(waitrequest),
        .oRM_read(rm_read),
        .oRM_readaddress(rm_readaddress),
        .iRM_readdata(readdata),
        .iFF_almostfull(ff_almostfull),
        .oFF_writerequest(ff_writerequest),
        .oFF_data(ff_data)
    );

    always #5 clk = ~clk;

    reg pending;
    reg [31:0] pending_addr;
    integer wr_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            readdatavalid <= 1'b0;
            readdata <= 32'h0;
            pending <= 1'b0;
            pending_addr <= 32'h0;
        end else begin
            readdatavalid <= 1'b0;
            if (rm_read && !waitrequest) begin
                pending <= 1'b1;
                pending_addr <= rm_readaddress;
            end
            if (pending) begin
                readdatavalid <= 1'b1;
                readdata <= pending_addr + 32'h10;
                pending <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_count <= 0;
        end else if (ff_writerequest) begin
            wr_count <= wr_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        length = 32'h0;
        startaddr = 32'h0;
        waitrequest = 1'b0;
        readdatavalid = 1'b0;
        readdata = 32'h0;
        ff_almostfull = 1'b0;
        wr_count = 0;

        #20;
        rst_n = 1'b1;

        startaddr = 32'h0000_1000;
        length = 32'd16;
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        #200;
        if (wr_count != 4) $display("RM TB: expected 4 writes, got %0d", wr_count);
        $finish;
    end
endmodule
