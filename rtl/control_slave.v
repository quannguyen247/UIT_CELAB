`timescale 1ns/1ps
`include "dma_defs.vh"

module control_slave (
    input wire iClk,
    input wire iReset_n,
    input wire iChipselect_n,
    input wire iWrite,
    input wire iRead,
    input wire iMW_done,
    input wire [2:0] iAddress,
    input wire [31:0] iWritedata,
    output reg oStart,
    output reg [31:0] oReaddata,
    output reg [31:0] oRM_startaddress,
    output reg [31:0] oWM_startaddress,
    output reg [31:0] oLength,
    output reg oIRQ
);

    reg [31:0] control;
    reg busy, done;

    wire write_en = (~iChipselect_n) && iWrite;
    wire read_en = (~iChipselect_n) && iRead;
    wire irq_en = control[`CTRL_IRQ];
    wire [31:0] status = {29'b0, oIRQ, busy, done};

    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            {oStart, oReaddata, oRM_startaddress, oWM_startaddress, oLength, oIRQ, control, busy, done} <= 0;
        end else begin
            oStart <= 1'b0; // Tat xung start sau 1 pulse

            // Write block
            if (write_en) begin
                case (iAddress)
                    `REG_SRC: if (!busy) oRM_startaddress <= iWritedata;
                    `REG_DST: if (!busy) oWM_startaddress <= iWritedata;
                    `REG_LEN: if (!busy) oLength <= iWritedata;
                    `REG_CTRL: if (!busy) begin
                        control <= iWritedata;
                        if (iWritedata[`CTRL_GO]) begin 
                            {oStart, busy} <= 2'b11;
                            {done, oIRQ} <= 2'b00; 
                        end
                    end
                    `REG_STAT: begin // W1C
                        if (iWritedata[`STAT_DONE]) done <= 1'b0;
                        if (iWritedata[`STAT_IRQ]) oIRQ <= 1'b0;
                    end
                endcase
            end

            // Read block
            if (read_en) begin
                oReaddata <= (iAddress == `REG_STAT) ? status : 32'h0;
            end

            // Done block
            if (iMW_done && busy) begin
                busy <= 1'b0;
                done <= 1'b1;
                oIRQ <= irq_en; 
                control <= 32'h0;
            end
        end
    end

endmodule