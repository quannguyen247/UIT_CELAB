`timescale 1ns/1ps
`include "../rtl/dma_defs.vh"

module tb_dmafinal;
    reg         clk;
    reg         rst_n;
    reg         chipselect_n;
    reg         rd;
    reg         wr;
    reg  [2:0]  addr;
    reg  [31:0] writedata;
    wire [31:0] readdata;

    reg         rm_readdatavalid;
    reg         rm_waitrequest;
    reg  [31:0] rm_readdata;
    wire        rm_read;
    wire [31:0] rm_readaddress;

    reg         wm_waitrequest;
    wire        wm_write;
    wire [31:0] wm_writeaddress;
    wire [31:0] wm_writedata;
    wire        irq;

    DMAFinal dut (
        .iClk(clk),
        .iReset_n(rst_n),
        .iChipselect_n(chipselect_n),
        .iRead(rd),
        .iWrite(wr),
        .iAddress(addr),
        .iWritedata(writedata),
        .oReaddata(readdata),
        .iRM_readdatavalid(rm_readdatavalid),
        .iRM_waitrequest(rm_waitrequest),
        .iRM_readdata(rm_readdata),
        .oRM_read(rm_read),
        .oRM_readaddress(rm_readaddress),
        .iWM_waitrequest(wm_waitrequest),
        .oWM_write(wm_write),
        .oWM_writeaddress(wm_writeaddress),
        .oWM_writedata(wm_writedata),
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

    reg  pending_read;
    reg  [31:0] pending_addr;
    integer write_count;
    integer error_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rm_readdatavalid <= 1'b0;
            rm_readdata <= 32'h0;
            pending_read <= 1'b0;
            pending_addr <= 32'h0;
        end else begin
            rm_readdatavalid <= 1'b0;
            if (rm_read && !rm_waitrequest) begin
                pending_read <= 1'b1;
                pending_addr <= rm_readaddress;
            end
            if (pending_read) begin
                rm_readdatavalid <= 1'b1;
                rm_readdata <= pending_addr ^ 32'hA5A50000;
                pending_read <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_count <= 0;
            error_count <= 0;
        end else begin
            if (wm_write && !wm_waitrequest) begin
                write_count <= write_count + 1;
                if (wm_writedata != ((wm_writeaddress - 32'h0000_1000) ^ 32'hA5A50000)) begin
                    error_count <= error_count + 1;
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        chipselect_n = 1'b1;
        rd = 1'b0;
        wr = 1'b0;
        addr = 3'h0;
        writedata = 32'h0;
        rm_waitrequest = 1'b0;
        wm_waitrequest = 1'b0;
        rm_readdatavalid = 1'b0;
        rm_readdata = 32'h0;

        #40;
        rst_n = 1'b1;

        write_reg(`DMA_ADDR_RM_START, 32'h0000_1000);
        write_reg(`DMA_ADDR_WM_START, 32'h0000_2000);
        write_reg(`DMA_ADDR_LENGTH,   32'd16);
        write_reg(`DMA_ADDR_CONTROL,  (1 << `DMA_CTRL_GO_BIT) | (1 << `DMA_CTRL_IRQ_EN_BIT));

        wait (irq == 1'b1);

        read_reg(`DMA_ADDR_STATUS);
        #1;
        if (readdata[`DMA_STATUS_DONE_BIT] != 1'b1) error_count = error_count + 1;

        write_reg(`DMA_ADDR_STATUS, (1 << `DMA_STATUS_DONE_BIT) | (1 << `DMA_STATUS_IRQ_BIT));
        #20;
        if (irq != 1'b0) error_count = error_count + 1;

        $display("DMAFinal TB: writes=%0d errors=%0d", write_count, error_count);
        #40;
        $finish;
    end
endmodule
