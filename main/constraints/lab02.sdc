# ============================================================================
# LAB02 - Timing constraints for clocked IP wrappers
# Applicable top-levels: rgb2gray_ip, median_ip
# ============================================================================

# 100 MHz system clock
create_clock -name clk -period 10.000 [get_ports {clk}]
