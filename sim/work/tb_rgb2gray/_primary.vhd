library verilog;
use verilog.vl_types.all;
entity tb_rgb2gray is
    generic(
        MAX_WIDTH       : integer := 3840;
        MAX_HEIGHT      : integer := 2160
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of MAX_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of MAX_HEIGHT : constant is 1;
end tb_rgb2gray;
