# ---------------------------------------------------------------------------------------------------
# SCRIPT: flow1.tcl
# Kich ban nay tu dong hoa 1 quy trinh mo phong bao gom 5 giai doan:
# 1. Chay Python de tien xu ly anh dau vao.
# 2. Bien dich va mo phong IP Verilog bang ModelSim.
# 3. Thuc hien STA bang TimeQuest Timing Analyzer (Su dung project Quartus dat o sta/median).
# 4. Chay Python de hau xu ly va dung lai anh ket qua.
# 5. Kiem tra va danh gia do chinh xac giua anh ket qua va anh goc.
# Cach dung: vsim -c -do "do script/flow1.tcl <anh_vao> <anh_ra> <anh_tham_chieu>"
# Vi du: vsim -c -do "do script/flow1.tcl doc/baitap1_nhieu.jpg temp/test.jpg doc/baitap1_anhgoc.jpg" 
# ---------------------------------------------------------------------------------------------------

# ===================================================================================================
# GIAI DOAN 0: CAU HINH MOI TRUONG
# ===================================================================================================

if {![file exists sim]} { file mkdir sim }
if {![file exists temp]} { file mkdir temp }

transcript file sim/transcript

if {[file exists transcript]} { quietly catch {file delete -force transcript} }
if {[file exists modelsim.ini]} { quietly catch {file delete -force modelsim.ini} }

# Bat buoc phai co dung 3 doi so
if {$argc != 3} {
    puts "Loi: Sai so luong doi so."
    puts "HDSD: do script/flow1.tcl <anh_vao> <anh_ra> <anh_goc_tham_chieu>"
    quit -f -code 1
}

quietly set input_img $1
quietly set output_img $2
quietly set ref_img $3
quietly set python_env "python"
quietly set quartus_env "C:/altera/13.0sp1/quartus/bin64"

if {[file exists temp/output_median.txt]} { quietly catch {file delete -force temp/output_median.txt} }
if {[file exists $output_img]} { quietly catch {file delete -force $output_img} }

puts "==================================================================================================="
puts " GIAI DOAN 1: TIEN XU LY DU LIEU BANG PYTHON "
puts "==================================================================================================="

if {[catch {exec $python_env script/pre1.py $input_img} py_out]} {
    puts "Loi khi chay pre1.py:\n$py_out"
    quit -f -code 1
}
puts $py_out

if {![regexp {WIDTH:\s*(\d+),\s*HEIGHT:\s*(\d+),\s*BORDER:\s*(\d+)} $py_out match width height border]} {
    puts "Loi: Khong lay duoc thong so kich thuoc tu pre1.py."
    quit -f -code 1
}

puts "==================================================================================================="
puts " GIAI DOAN 2: MO PHONG PHAN CUNG BANG MODELSIM (tb_median_ip) "
puts "==================================================================================================="

if {![file exists sim/work]} { vlib sim/work }

# Bien dich toan bo RTL va Testbench
vlog -work sim/work rtl/median.v rtl/median_ip.v tb/tb_median_ip.v

# Chay mo phong voi tb_median_ip la module Top
vsim -c -wlf sim/vsim.wlf sim/work.tb_median_ip +WIDTH=$width +HEIGHT=$height +BORDER=$border
run -all
quit -sim

puts "==================================================================================================="
puts " GIAI DOAN 3: THONG KE THOI GIAN (STA) BANG QUARTUS TIMEQUEST TIMING ANALYZER "
puts "==================================================================================================="

# Chuyen huong vao thu muc chua project Quartus da duoc khoi tao tu truoc
cd sta/median

puts " Dang chay Quartus Map (Analysis & Synthesis)..."
# Redirect output vao file map.log de ngan ModelSim tu dong spam raw log len console
if {[catch {exec $quartus_env/quartus_map median > map.log} err]} { 
    puts "Loi Map:\n$err"
    quit -f -code 1 
}
puts " -> Analysis & Synthesis chay thanh cong!"

puts " Dang chay Quartus Fit (Place & Route)..."
# Tuong tu cho Fit, redirect vao fit.log
if {[catch {exec $quartus_env/quartus_fit median > fit.log} err]} { 
    puts "Loi Fit:\n$err"
    quit -f -code 1 
}
puts " -> Place & Route chay thanh cong!"

puts " Dang chay TimeQuest Timing Analyzer (STA)..."
# Tuong tu cho STA, redirect vao sta.log
if {[catch {exec $quartus_env/quartus_sta median > sta.log} err]} { 
    puts "Loi STA:\n$err"
    quit -f -code 1
} 
puts " -> Timing Analysis chay thanh cong!\n"

# Doc noi dung tu file sta.log vua duoc luu de loc thong tin quan trong
puts "----------- BAO CAO TIMING CHI TIET -----------"
quietly set found_info 0

# Su dung catch de boc lenh open giup ModelSim khong in ra cai ma file handle
if {![catch {open "sta.log" r} fp]} {
    # Doc tung dong thay vi doc toan bo file
    while {[gets $fp line] >= 0} {
        # Bat kieu Model (Slow/Fast) de phan nhom ket qua
        if {[regexp -nocase {Analyzing (Slow Model|Fast Model)} $line match model_type]} {
            # Chi dung 1 dau gach cheo de thoat ky tu ngoac vuong
            puts "  \[$model_type\]"
        }

        # Dung Regex bat cac dong chua "Worst-case <loai> slack is <gia_tri>"
        if {[regexp -nocase {Worst-case (setup|hold|recovery|removal|minimum pulse width) slack is ([0-9\.\-]+)} $line match type slack_val]} {
            set type_cap [string totitle $type]
            # Format %-27s de can le dung kich thuoc cua chu "Minimum pulse width Slack"
            puts [format "    * %-27s : %s ns" "$type_cap Slack" $slack_val]
            quietly set found_info 1
        }
        
        # Dung Regex bat cac dong chua Fmax (Tan so hoat dong toi da) neu co
        if {[regexp -nocase {Fmax is ([0-9\.]+ MHz)} $line match fmax_val]} {
            puts [format "    * %-27s : %s" "Fmax (Max Freq)" $fmax_val]
            quietly set found_info 1
        }
    }
    close $fp
}

if {$found_info == 0} {
    puts "  (Khong tim thay thong tin Slack/Fmax tom tat. Xem chi tiet trong sta/median/sta.log)"
}
puts "-----------------------------------------------\n"

# Hoan tat STA, quay tro lai thu muc goc cua du an de chay tiep cac giai doan sau
cd ../..

puts "==================================================================================================="
puts " GIAI DOAN 4: HAU XU LY KET QUA BANG PYTHON "
puts "==================================================================================================="

if {[catch {exec $python_env script/post1.py $output_img} post_out]} {
    puts "Loi khi chay post1.py:\n$post_out"
    quit -f -code 1
}
puts $post_out

puts "==================================================================================================="
puts " GIAI DOAN 5: DANH GIA VA SO SANH KET QUA "
puts "==================================================================================================="

if {[catch {exec $python_env script/cmp.py $ref_img $output_img} cmp_out]} {
    puts "Loi khi chay cmp.py:\n$cmp_out"
    quit -f -code 1
}
puts $cmp_out

puts "==================================================================================================="
puts " KET THUC QUY TRINH "
puts "==================================================================================================="
quit -f -code 0