# ----------------------------------------------------------------------------------
# SCRIPT: flow1.tcl
# Kich ban nay tu dong hoa 1 quy trinh mo phong bao gom:
# 1. Chay Python de tien xu ly anh dau vao.
# 2. Bien dich va mo phong IP Verilog bang ModelSim.
# 3. Chay Python de hau xu ly va dung lai anh ket qua.
# 4. Kiem tra va danh gia do chinh xac giua anh ket qua va anh goc (PSNR, SSIM).
# Cach dung: vsim -c -do "do script/flow1.tcl <anh_vao> <anh_ra> [anh_goc_tham_chieu]"
# ----------------------------------------------------------------------------------

# ============================================================================
# PHAN 0: CAU HINH MOI TRUONG
# Giu cho thu muc goc luon duoc sach se va de dang quan ly
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
    puts "Huong dan su dung: do script/flow1.tcl <duong_dan_anh_vao> <duong_dan_anh_ra> [duong_dan_anh_goc_tham_chieu]"
    quit -f -code 1
}

set input_img $1
set output_img $2
if {$argc == 3} {
    set ref_img $3
} else {
    set ref_img "doc/baitap1_anhgoc.jpg"
}
set python_env "python"

# Xoa ket qua cu de tranh nham lan voi lan chay moi khi co loi giua chung
if {[file exists temp/output_median.txt]} {
    catch {file delete -force temp/output_median.txt}
}
if {[file exists $output_img]} {
    catch {file delete -force $output_img}
}

puts "============================================================================"
puts " GIAI DOAN 1: TIEN XU LY DU LIEU BANG PYTHON "
puts "============================================================================"

# Lenh catch se bat loi neu qua trinh chay Python that bai, giup ModelSim khong bi crash.
if {[catch {exec $python_env script/pre1.py $input_img} py_out]} {
    puts "Da co loi xay ra trong qua trinh thuc thi script pre1.py:"
    puts $py_out
    quit -f -code 1
}
puts $py_out

# Dung RegEx de quet dong log cua Python va lay ra 3 gia tri:
# WIDTH (Chieu rong), HEIGHT (Chieu cao), BORDER (Vien).
if {![regexp {WIDTH:\s*(\d+),\s*HEIGHT:\s*(\d+),\s*BORDER:\s*(\d+)} $py_out match width height border]} {
    puts "Loi: Khong the lay duoc thong so kich thuoc anh tu ket qua in ra cua pre1.py."
    quit -f -code 1
}
puts "-> Thanh cong: Da lay duoc cac tham so: WIDTH=$width, HEIGHT=$height, BORDER=$border"

puts "============================================================================"
puts " GIAI DOAN 2: MO PHONG PHAN CUNG BANG MODELSIM "
puts "============================================================================"

if {![file exists sim/work]} {
    vlib sim/work
}

# Bien dịch va su dung tham so '-work sim/work' de ep ModelSim luu file bien dich vao dung cho.
vlog -work sim/work rtl/median.v tb/tb_median.v

# Thuc thi mo phong phan cung bang lenh vsim.
# '-wlf sim/vsim.wlf': Ep file dang song (wave) luu vao thu muc 'sim'.
# '-c': Chay vsim o che do batch (command-line mode) khi goi tu TCL nham tiet kiem thoi gian
# 'sim/work.tb_median': tro dung den noi chua testbench da duoc bien dich.
# Truyen them cac tham so rong, cao, vien tu script vao testbench.
vsim -c -wlf sim/vsim.wlf sim/work.tb_median +WIDTH=$width +HEIGHT=$height +BORDER=$border

run -all
quit -sim

puts "============================================================================"
puts " GIAI DOAN 3: HAU XU LY KET QUA BANG PYTHON "
puts "============================================================================"

# Goi script post1.py de doc du lieu ket qua do phan cung xuat ra
# va dung lai thanh mot file anh hoan chinh.
if {[catch {exec $python_env script/post1.py $output_img} post_out]} {
    puts "Da co loi xay ra trong qua trinh thuc thi script post1.py:"
    puts $post_out
    quit -f -code 1
}
puts $post_out

puts "============================================================================"
puts " GIAI DOAN 4: DANH GIA VA SO SANH KET QUA "
puts "============================================================================"

# Goi script cmp.py de so sanh anh goc va anh do phan cung xu ly,
# tu do tinh toan ra cac chi so danh gia do lech (bao gom PSNR, SSIM).
if {[catch {exec $python_env script/cmp.py $ref_img $output_img} cmp_out]} {
    puts "Da co loi xay ra trong qua trinh thuc thi script cmp.py:"
    puts $cmp_out
    quit -f -code 1
}
puts $cmp_out

puts "============================================================================"
puts " KET THUC QUY TRINH MO PHONG "
puts "============================================================================"

quit -f -code 0