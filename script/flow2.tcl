# ----------------------------------------------------------------------------------
# SCRIPT: flow2.tcl
# Kich ban nay tu dong hoa 1 quy trinh mo phong bao gom:
# 1. Chay Python de tien xu ly anh RGB dau vao.
# 2. Bien dich va mo phong ma nguon Verilog bang ModelSim.
# 3. Chay Python de hau xu ly va dung lai anh Grayscale ket qua.
# Cach dung: vsim -c -do "do script/flow2.tcl doc/baitap2_anhgoc.jpg temp/test2.jpg (do_sang [-128;127])"
# ----------------------------------------------------------------------------------

# ============================================================================
# PHAN 0: CAU HINH MOI TRUONG
# Muc dich: Giu cho thu muc goc luon duoc sach se va de dang quan ly
# ============================================================================

if {![file exists sim]} {
    file mkdir sim
}

if {![file exists temp]} {
    file mkdir temp
}

transcript file sim/transcript

if {[file exists transcript]} {
    catch {file delete -force transcript}
}

if {[file exists modelsim.ini]} {
    catch {file delete -force modelsim.ini}
}

# ============================================================================
# PHAN 1: KIEM TRA DOI SO DAU VAO VA KHOI TAO BIEN MOI TRUONG
# ============================================================================

if {$argc < 2 || $argc > 3} {
    puts "Loi: Sai so luong doi so truyen vao."
    puts "Huong dan su dung: do script/flow2.tcl <duong_dan_anh_vao> <duong_dan_anh_ra> (do_sang [-128;127])"
    exit
}

set input_img $1
set output_img $2
set brightness 0
if {$argc == 3} {
    set brightness $3
}

set python_env "C:/msys64/ucrt64/bin/python.exe"

puts "============================================================================"
puts " GIAI DOAN 1: TIEN XU LY DU LIEU BANG PYTHON "
puts "============================================================================"

# Lenh catch se bat loi neu qua trinh chay Python that bai, giup ModelSim khong bi crash.
if {[catch {exec $python_env script/pre2.py $input_img} py_out]} {
    puts "Da co loi xay ra trong qua trinh thuc thi script pre2.py:"
    puts $py_out
    exit
}

# In toan bo log cua Python ra man hinh de de dang theo doi tien trinh
puts $py_out

# Dung RegEx de quet dong log cua Python va lay ra 2 gia tri:
# WIDTH (Chieu rong), HEIGHT (Chieu cao).
if {![regexp {WIDTH:\s*(\d+),\s*HEIGHT:\s*(\d+)} $py_out match width height]} {
    puts "Loi: Khong the lay duoc thong so kich thuoc anh tu ket qua in ra cua pre2.py."
    exit
}
puts "-> Thanh cong: Da lay duoc cac tham so: WIDTH=$width, HEIGHT=$height, BRIGHTNESS=$brightness"

puts "============================================================================"
puts " GIAI DOAN 2: MO PHONG PHAN CUNG BANG MODELSIM "
puts "============================================================================"

if {![file exists sim/work]} {
    vlib sim/work
}

# Bien dich va su dung tham so '-work sim/work' de ep ModelSim luu file bien dich vao dung cho.
vlog -work sim/work rtl/rgb2gray.v tb/tb_rgb2gray.v

# Thuc thi mo phong phan cung bang lenh vsim.
# '-wlf sim/vsim.wlf': Ep file dang song (wave) luu vao thu muc 'sim'.
# '-c': Chay vsim o che do batch (command-line mode) khi goi tu TCL nham tiet kiem thoi gian
# Goi 'sim/work.tb_rgb2gray': tro dung den noi chua testbench da duoc bien dich.
# Truyen them cac tham so rong, cao, do sang tu script vao testbench.
vsim -c -wlf sim/vsim.wlf sim/work.tb_rgb2gray +WIDTH=$width +HEIGHT=$height +BRIGHTNESS=$brightness

run -all
quit -sim

puts "============================================================================"
puts " GIAI DOAN 3: HAU XU LY KET QUA BANG PYTHON "
puts "============================================================================"

# Goi script post2.py de doc du lieu ket qua do phan cung xuat ra
# va dung lai thanh mot file anh hoan chinh.
if {[catch {exec $python_env script/post2.py $output_img} post_out]} {
    puts "Da co loi xay ra trong qua trinh thuc thi script post2.py:"
    puts $post_out
    exit
}
puts $post_out

puts "============================================================================"
puts " KET THUC QUY TRINH MO PHONG "
puts "============================================================================"

exit