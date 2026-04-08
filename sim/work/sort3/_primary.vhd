library verilog;
use verilog.vl_types.all;
entity sort3 is
    port(
        in1             : in     vl_logic_vector(7 downto 0);
        in2             : in     vl_logic_vector(7 downto 0);
        in3             : in     vl_logic_vector(7 downto 0);
        out_max         : out    vl_logic_vector(7 downto 0);
        out_mid         : out    vl_logic_vector(7 downto 0);
        out_min         : out    vl_logic_vector(7 downto 0)
    );
end sort3;
