# ---------------------------------------------------------------------------------------------------
# SCRIPT: flow2.tcl
# Kich ban nay tu dong hoa 1 quy trinh mo phong bao gom 4 giai doan:
# 1. Chay Python de tien xu ly anh RGB dau vao.
# 2. Bien dich va mo phong IP Verilog bang ModelSim.
# 3. Thuc hien STA bang TimeQuest Timing Analyzer (Su dung project Quartus dat o sta/rgb2gray).
# 4. Chay Python de hau xu ly va dung lai anh grayscale ket qua.
# Cach dung: vsim -c -do "do script/flow2.tcl <anh_vao> <anh_ra> <do_sang>"
# Vi du: vsim -c -do "do script/flow2.tcl doc/baitap2_anhgoc.jpg temp/test2.jpg 20" 
# ---------------------------------------------------------------------------------------------------

# ===================================================================================================
# GIAI DOAN 0: CAU HINH MOI TRUONG
# ===================================================================================================

if {![file exists sim]} { file mkdir sim }
if {![file exists temp]} { file mkdir temp }

transcript file sim/transcript

if {[file exists transcript]} { quietly catch {file delete -force transcript} }
if {[file exists modelsim.ini]} { quietly catch {file delete -force modelsim.ini} }

if {$argc != 3} {
    puts "Loi: Khong hop le so luong doi so dau vao."
    puts "HDSD: do script/flow2.tcl <anh_vao> <anh_ra> <do_sang_tu_-128_den_127>"
    quit -f -code 1
}

quietly set input_img $1
quietly set output_img $2
if {$argc == 3} {
    quietly set brightness $3
} else {
    quietly set brightness 0
}
quietly set python_env "python"
quietly set quartus_env "C:/altera/13.0sp1/quartus/bin64"

if {[file exists temp/output_gray.txt]} { quietly catch {file delete -force temp/output_gray.txt} }
if {[file exists $output_img]} { quietly catch {file delete -force $output_img} }

puts "==================================================================================================="
puts " GIAI DOAN 1: TIEN XU LY DU LIEU BANG PYTHON "
puts "==================================================================================================="

if {[catch {exec $python_env script/pre2.py $input_img} py_out]} {
    puts "Loi tien xu ly du lieu (pre2.py):\n$py_out"
    quit -f -code 1
}
puts $py_out

if {![regexp {WIDTH:\s*(\d+),\s*HEIGHT:\s*(\d+)} $py_out match width height]} {
    puts "Loi: Trich xuat thong so do phan giai that bai."
    quit -f -code 1
}
puts "-> Tham so he thong: WIDTH=$width, HEIGHT=$height, BRIGHTNESS=$brightness"

puts "==================================================================================================="
puts " GIAI DOAN 2: MO PHONG PHAN CUNG BANG MODELSIM (tb_rgb2gray_ip) "
puts "==================================================================================================="

if {![file exists sim/work]} { vlib sim/work }

vlog -work sim/work rtl/rgb2gray.v rtl/rgb2gray_ip.v tb/tb_rgb2gray.v tb/tb_rgb2gray_ip.v
vsim -c -wlf sim/vsim.wlf sim/work.tb_rgb2gray_ip +WIDTH=$width +HEIGHT=$height +BRIGHTNESS=$brightness

run -all
quit -sim

puts "==================================================================================================="
puts " GIAI DOAN 3: THONG KE THOI GIAN (STA) BANG QUARTUS TIMEQUEST TIMING ANALYZER "
puts "==================================================================================================="

cd sta/rgb2gray

puts "  Dang chay Quartus Map (Analysis & Synthesis)..."
if {[catch {exec $quartus_env/quartus_map rgb2gray > map.log} err]} { 
    puts "Loi Map:\n$err"
    quit -f -code 1 
}
puts "   -> Analysis & Synthesis hoan tat thanh cong!"

puts "  Dang chay Quartus Fit (Place & Route)..."
if {[catch {exec $quartus_env/quartus_fit rgb2gray > fit.log} err]} { 
    puts "Loi Fit:\n$err"
    quit -f -code 1 
}
puts "   -> Place & Route hoan tat thanh cong!"

puts "  Dang chay TimeQuest Timing Analyzer (STA)..."
if {[catch {exec $quartus_env/quartus_sta rgb2gray > sta.log} err]} { 
    puts "Loi STA:\n$err"
    quit -f -code 1
} 
puts "   -> Timing Analysis hoan tat thanh cong!\n"

puts "----------- BAO CAO TIMING CHI TIET -----------"
quietly set found_info 0

if {![catch {open "sta.log" r} fp]} {
    while {[gets $fp line] >= 0} {
        if {[regexp -nocase {Analyzing (Slow Model|Fast Model)} $line match model_type]} {
            puts "  \[$model_type\]"
        }

        if {[regexp -nocase {Worst-case (setup|hold|recovery|removal|minimum pulse width) slack is ([0-9\.\-]+)} $line match type slack_val]} {
            quietly set type_cap [string totitle $type]
            puts [format "    * %-27s : %s ns" "$type_cap Slack" $slack_val]
            quietly set found_info 1
        }
        
        if {[regexp -nocase {Fmax is ([0-9\.]+ MHz)} $line match fmax_val]} {
            puts [format "    * %-27s : %s" "Fmax (Max Freq)" $fmax_val]
            quietly set found_info 1
        }
    }
    close $fp
}

if {$found_info == 0} {
    puts "  (Canh bao: Khong tim thay ban ghi Slack/Fmax. Kiem tra chi tiet sta.log)"
}
puts "-----------------------------------------------\n"

cd ../..

puts "==================================================================================================="
puts " GIAI DOAN 4: HAU XU LY KET QUA BANG PYTHON "
puts "==================================================================================================="

if {[catch {exec $python_env script/post2.py $output_img} post_out]} {
    puts "Loi hau xu ly (post2.py):\n$post_out"
    quit -f -code 1
}
puts $post_out

puts "==================================================================================================="
puts " KET THUC QUY TRINH "
puts "==================================================================================================="
quit -f -code 0