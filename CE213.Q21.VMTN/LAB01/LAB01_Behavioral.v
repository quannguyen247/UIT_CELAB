module LAB01_Behavioral (
    input wire clk,
    input wire async_load, // Tin hieu nap bat dong bo
    input wire [2:0] p, // Tin hieu nap song song
    output reg [2:0] q
);

    always @(posedge clk or posedge async_load) begin
        if (async_load) begin
            q <= p;
        end else begin
            case (q)
                3'b000, 3'b001: q <= 3'b110; 
                3'b010, 3'b100: q <= 3'b111; 
                3'b011: q <= 3'b000; 
                3'b101: q <= 3'b010; 
                3'b110: q <= 3'b100; 
                3'b111: q <= 3'b011; 
                default: q <= 3'b000;
            endcase
        end
    end

endmodule