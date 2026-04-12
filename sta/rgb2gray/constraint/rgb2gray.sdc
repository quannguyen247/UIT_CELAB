# Khai bao clock 150MHz
create_clock -name main_clk -period 6.667 [get_ports {clk}]

# Yeu cau Quartus tu dong tinh toan nhieu/sai so cua clock (jitter)
derive_clock_uncertainty