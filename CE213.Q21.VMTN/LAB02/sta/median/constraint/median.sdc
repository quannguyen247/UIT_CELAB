# Khai bao clock 100MHz
create_clock -name main_clk -period 10.000 [get_ports {clk}]

# Yeu cau Quartus tu dong tinh toan nhieu/sai so cua clock (jitter)
derive_clock_uncertainty

# Do tre toi da cho phep cua reset bat dong bo
set_input_delay -clock main_clk 5.000 [get_ports {rst_n}]