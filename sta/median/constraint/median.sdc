# Khai bao clock 100MHz
create_clock -name main_clk -period 10.000 [get_ports {clk}]

# Yeu cau Quartus tu dong tinh toan nhieu/sai so cua clock (jitter)
derive_clock_uncertainty