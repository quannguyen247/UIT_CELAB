`timescale 1ns/1ps
`include "../rtl/dma_defs.vh"

module tb_control_slave;
    reg         clk;
    reg         rst_n;
    reg         chipselect_n;
    reg         wr;
    reg         rd;
    reg         mw_done;
    reg  [2:0]  addr;
    reg  [31:0] writedata;
    wire        start;
    wire [31:0] readdata;
    wire [31:0] rm_start;
    wire [31:0] wm_start;
    wire [31:0] length;
    wire        irq;

    control_slave dut (
        .iClk(clk),
        .iReset_n(rst_n),
        .iChipselect_n(chipselect_n),
        .iWrite(wr),
        .iRead(rd),
        .iMW_done(mw_done),
        .iAddress(addr),
        .iWritedata(writedata),
        .oStart(start),
        .oReaddata(readdata),
        .oRM_startaddress(rm_start),
        .oWM_startaddress(wm_start),
        .oLength(length),
        .oIRQ(irq)
    );

    always #5 clk = ~clk;

    task write_reg(input [2:0] a, input [31:0] d);
        begin
            @(negedge clk);
            chipselect_n = 1'b0;
            wr = 1'b1;
            rd = 1'b0;
            addr = a;
            writedata = d;
            @(negedge clk);
            wr = 1'b0;
            chipselect_n = 1'b1;
        end
    endtask

    task read_reg(input [2:0] a);
        begin
            @(negedge clk);
            chipselect_n = 1'b0;
            rd = 1'b1;
            wr = 1'b0;
            addr = a;
            @(negedge clk);
            rd = 1'b0;
            chipselect_n = 1'b1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        chipselect_n = 1'b1;
        wr = 1'b0;
        rd = 1'b0;
        mw_done = 1'b0;
        addr = 3'h0;
        writedata = 32'h0;

        #20;
        rst_n = 1'b1;

        write_reg(`DMA_ADDR_RM_START, 32'h0000_1000);
        write_reg(`DMA_ADDR_WM_START, 32'h0000_2000);
        write_reg(`DMA_ADDR_LENGTH,   32'd16);
        write_reg(`DMA_ADDR_CONTROL,  (1 << `DMA_CTRL_GO_BIT) | (1 << `DMA_CTRL_IRQ_EN_BIT));

        @(posedge clk);
        if (!start) $display("CTRL TB: expected start pulse");

        @(negedge clk);
        mw_done = 1'b1;
        @(negedge clk);
        mw_done = 1'b0;

        read_reg(`DMA_ADDR_STATUS);
        #1;
        if (!readdata[`DMA_STATUS_DONE_BIT]) $display("CTRL TB: expected DONE=1");
        if (!readdata[`DMA_STATUS_IRQ_BIT])  $display("CTRL TB: expected IRQ=1");

        write_reg(`DMA_ADDR_STATUS, (1 << `DMA_STATUS_DONE_BIT) | (1 << `DMA_STATUS_IRQ_BIT));
        #10;
        if (irq) $display("CTRL TB: expected IRQ cleared");

        #20;
        $finish;
    end
endmodule
