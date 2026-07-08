module async_dff ( 
    input wire clk, 
    input wire pre_n, 
    input wire clr_n,
    input wire d,
    output wire q
);

    // Dung 6 cong nand tao DFF
    wire q_n;
    wire w1, w2, w3, w4;

    nand (w1, pre_n, w4, w2);
    nand (w2, clr_n, w1, clk);
    nand (w3, pre_n, w2, clk, w4);
    nand (w4, clr_n, w3, d);

    nand (q, pre_n, w2, q_n);
    nand (q_n, clr_n, w3, q);

endmodule

module next_state_logic (
    input wire q2, q1, q0,
    output wire d2, d1, d0
);

    wire q2_n, q1_n, q0_n;

    // inverter  
    not (q2_n, q2);
    not (q1_n, q1);
    not (q0_n, q0);

    // D2 logic
    wire w21;
    and (w21, q2_n, q1_n);
    or (d2, q0_n, w21);

    // D1 logic
    wire w20, w20_n;
    and (w20, q2, q0);
    and (w20_n, q2_n, q0_n);
    or (d1, q1_n, w20, w20_n);

    // D0 logic
    wire w1, w2, w3;
    and (w1, q2_n, q1, q0_n);
    and (w2, q2, q1_n, q0_n);
    and (w3, q2, q1, q0);
    or (d0, w1, w2, w3);

endmodule

module LAB01_Structural (
    input wire clk,
    input wire async_load, // Tin hieu nap bat dong bo
    input wire p2, p1, p0, // Tin hieu nap song song
    output wire q2, q1, q0
);

    wire d2, d1, d0;

    // Logic chuyen trang thai tiep theo
    next_state_logic NSL (
        .q2(q2), .q1(q1), .q0(q0),
        .d2(d2), .d1(d1), .d0(d0)
    );

    // Dao trang thai cua cac bit p2, p1, p0
    wire p2_n, p1_n, p0_n;
    not (p2_n, p2);
    not (p1_n, p1);
    not (p0_n, p0);

    // Tao tin hieu pre_n va clr_n cho tung Flip-Flop
    wire pre_n2, clr_n2;
    wire pre_n1, clr_n1;
    wire pre_n0, clr_n0;

    // Bit 2
    nand (pre_n2, async_load, p2);
    nand (clr_n2, async_load, p2_n);

    // Bit 1
    nand (pre_n1, async_load, p1);
    nand (clr_n1, async_load, p1_n);

    // Bit 0
    nand (pre_n0, async_load, p0);
    nand (clr_n0, async_load, p0_n);

    // Goi 3 module DFF cho 3 bit q2, q1, q0
    async_dff dff2 (
        .clk(clk), 
        .pre_n(pre_n2), 
        .clr_n(clr_n2), 
        .d(d2), 
        .q(q2)
    );

    async_dff dff1 (
        .clk(clk), 
        .pre_n(pre_n1), 
        .clr_n(clr_n1), 
        .d(d1), 
        .q(q1)
    );

    async_dff dff0 (
        .clk(clk), 
        .pre_n(pre_n0), 
        .clr_n(clr_n0), 
        .d(d0), 
        .q(q0)
    );
    
endmodule