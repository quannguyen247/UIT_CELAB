library verilog;
use verilog.vl_types.all;
entity rgb2gray is
    port(
        r               : in     vl_logic_vector(7 downto 0);
        g               : in     vl_logic_vector(7 downto 0);
        b               : in     vl_logic_vector(7 downto 0);
        brightness      : in     vl_logic_vector(7 downto 0);
        gray            : out    vl_logic_vector(7 downto 0)
    );
end rgb2gray;
