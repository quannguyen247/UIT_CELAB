library verilog;
use verilog.vl_types.all;
entity median is
    port(
        p00             : in     vl_logic_vector(7 downto 0);
        p01             : in     vl_logic_vector(7 downto 0);
        p02             : in     vl_logic_vector(7 downto 0);
        p10             : in     vl_logic_vector(7 downto 0);
        p11             : in     vl_logic_vector(7 downto 0);
        p12             : in     vl_logic_vector(7 downto 0);
        p20             : in     vl_logic_vector(7 downto 0);
        p21             : in     vl_logic_vector(7 downto 0);
        p22             : in     vl_logic_vector(7 downto 0);
        row             : in     vl_logic_vector(15 downto 0);
        col             : in     vl_logic_vector(15 downto 0);
        width           : in     vl_logic_vector(15 downto 0);
        height          : in     vl_logic_vector(15 downto 0);
        border          : in     vl_logic_vector(7 downto 0);
        border_pattern_flat: in     vl_logic_vector(511 downto 0);
        out_pixel       : out    vl_logic_vector(7 downto 0)
    );
end median;
