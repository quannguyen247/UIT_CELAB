module top_main (
    input wire clk,
    input wire async_load,
    input wire [2:0] p,
    output wire [2:0] q
);

    // --- 1. Behavioral Model ---
    /*
    LAB01_Behavioral behavioral_inst (
        .clk(clk),
        .async_load(async_load),
        .p(p),
        .q(q)
    );
    */

    // --- 2. Structural Model ---
    
    LAB01_Structural structural_inst (
        .clk(clk),
        .async_load(async_load),
        .p2(p[2]), .p1(p[1]), .p0(p[0]),
        .q2(q[2]), .q1(q[1]), .q0(q[0])
    );
    
endmodule
