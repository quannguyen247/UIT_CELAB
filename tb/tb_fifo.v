`timescale 1ns/1ps

module tb_fifo;
    reg         clk;
    reg         rst_n;
    reg         rdreq;
    reg         wrreq;
    reg  [31:0] data;
    wire [31:0] q;
    wire        empty;
    wire        almostfull;

    FIFO dut (
        .iClk(clk),
        .iReset_n(rst_n),
        .FF_empty(empty),
        .FF_almostfull(almostfull),
        .FF_data(data),
        .FF_q(q),
        .FF_readrequest(rdreq),
        .FF_writerequest(wrreq)
    );

    always #5 clk = ~clk;

    task write_word(input [31:0] d);
        begin
            @(negedge clk);
            data = d;
            wrreq = 1'b1;
            rdreq = 1'b0;
            @(negedge clk);
            wrreq = 1'b0;
        end
    endtask

    task read_word;
        begin
            @(negedge clk);
            rdreq = 1'b1;
            wrreq = 1'b0;
            @(negedge clk);
            rdreq = 1'b0;
        end
    endtask

    integer i;
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rdreq = 1'b0;
        wrreq = 1'b0;
        data = 32'h0;

        #20;
        rst_n = 1'b1;

        for (i = 0; i < 130; i = i + 1) begin
            write_word(i);
        end

        if (!almostfull) $display("FIFO TB: expected almostfull=1");

        for (i = 0; i < 130; i = i + 1) begin
            read_word();
        end

        if (!empty) $display("FIFO TB: expected empty=1");

        #20;
        $finish;
    end
endmodule
