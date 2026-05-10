`timescale 1ns/1ps

module tb_control_slave();
    reg iClk;
    reg iReset_n;
    reg iChipselect_n;
    reg iWrite;
    reg iRead;
    reg iMW_done;
    reg [2:0] iAddress;
    reg [31:0] iWritedata;

    wire oStart;
    wire oIRQ;
    wire [31:0] oReaddata;
    wire [31:0] oRM_startaddress;
    wire [31:0] oWM_startaddress;
    wire [31:0] oLength;

    wire [31:0] dsControl = dut.control;
    wire [31:0] dsStatus = dut.status;

    control_slave dut(
        .iClk(iClk),
        .iReset_n(iReset_n),
        .iChipselect_n(iChipselect_n),
        .iWrite(iWrite),
        .iRead(iRead),
        .iMW_done(iMW_done),
        .iAddress(iAddress),
        .iWritedata(iWritedata),
        .oStart(oStart),
        .oReaddata(oReaddata),
        .oRM_startaddress(oRM_startaddress),
        .oWM_startaddress(oWM_startaddress),
        .oLength(oLength),
        .oIRQ(oIRQ)
    );

    initial begin
        iClk = 0;
        forever #5 iClk = ~iClk;
    end

    initial begin
        iReset_n = 0;
        iChipselect_n = 1;
        iWrite = 0;
        iRead = 0;
        iMW_done = 1'bx; 
        iAddress = 3'd7;
        iWritedata = 32'd27; // 11011
        
        #12; 
        iReset_n = 1;
        iChipselect_n = 0; 

        // iAddress = 0, nap cho oRM_startaddress 
        @(negedge iClk);
        iAddress = 3'd0;
        iWrite = 1;

        // iAddress = 1, nap cho oWM_startaddress
        @(negedge iClk);
        iAddress = 3'd1;

        // iAddress = 2, nap cho oLength
        @(negedge iClk);
        iAddress = 3'd2;

        // iAddress = 3, nap cho dsControl
        @(negedge iClk);
        iAddress = 3'd3;

        // iAddress = 7, doc dsStatus
        @(negedge iClk);
        iAddress = 3'd7;
        iWrite = 0;
        iRead = 1;

        // Tat iRead va cho vai nhip bat iMW_done
        @(negedge iClk);
        iRead = 0;
        repeat(5) @(negedge iClk);
        iMW_done = 1;
        
        // Tat iMW_done, dsStatus về 0
        @(negedge iClk);
        iMW_done = 0;

        // Kiem tra ngat
        repeat(2) @(negedge iClk); 
        iAddress = 3'd7; 
        iRead = 1; 
        @(negedge iClk) 
        iRead = 0;  

        #30 $stop;
    end
endmodule