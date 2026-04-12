# Thiết kế hệ thống số với HDL - CE213.Q21.VMTN
## LAB 2: Xử lý ảnh trên phần cứng (Median Filter & RGB to Grayscale)

### THÔNG TIN NHÓM THỰC HIỆN
- **Giảng viên hướng dẫn:** Ngô Hiếu Trường
- **Sinh viên 1:** Huỳnh Nhật Phát - MSSV: 24521294
- **Sinh viên 2:** Nguyễn Đông Quân - MSSV: 24521438

---

## 1. Mục tiêu theo đề HDL-Lab2.pdf

### Bài 1 - Median Filter (không dùng `for/while` trong Verilog)
- Tiền xử lý ảnh grayscale sang dữ liệu text cho testbench.
- Hiện thực bộ lọc trung vị trên Verilog, đọc input text và ghi output text.
- Hậu xử lý text về ảnh, đánh giá chất lượng bằng **PSNR** và **SSIM**.

### Bài 2 - RGB to Grayscale (không dùng `for/while` trong Verilog)
- Chuyển ảnh RGB sang dữ liệu bitmap/text để đưa vào khối Verilog.
- Dùng công thức chuẩn grayscale: **Y = 0.299R + 0.587G + 0.114B**.
- Có tham số điều chỉnh độ sáng (**brightness**) trong mã Verilog.

---

## 2. Cấu trúc thư mục (tóm tắt)

- `doc/`: đề bài `HDL-Lab2.pdf` và ảnh mẫu đầu vào.
- `rtl/`: mã RTL chính (`median.v`, `median_ip.v`, `rgb2gray.v`, `rgb2gray_ip.v`).
- `tb/`: testbench tích hợp cho 2 IP (`tb_median_ip.v`, `tb_rgb2gray_ip.v`).
- `script/`: tiền xử lý, flow mô phỏng, hậu xử lý, so sánh chất lượng.
- `sta/`: project Quartus + ràng buộc timing cho 2 bài (`median`, `rgb2gray`).
- `sim/`: thư mục mô phỏng ModelSim (tự tạo khi chạy).
- `temp/`: dữ liệu trung gian và ảnh kết quả (tự tạo khi chạy).

---

## 3. Yêu cầu môi trường

- Python 3.10+.
- Thư viện Python: `numpy`, `opencv-python`, `scikit-image`.
- ModelSim/QuestaSim (có lệnh `vlog`, `vsim`).
- Quartus II 13.0sp1 (phục vụ STA trong `flow1.tcl` và `flow2.tcl`).

Cài nhanh thư viện Python:

```bash
pip install numpy opencv-python scikit-image
```

---

## 4. Cách chạy nhanh (khuyến nghị)

Chạy menu tương tác:

```bash
python script/run_all.py
```

Menu cho phép:
- chạy riêng Bài 1,
- chạy riêng Bài 2,
- hoặc chạy liên tục cả hai bài.

---

## 5. Cách chạy trực tiếp từng flow

### 5.1 Flow Bài 1 (Median + so sánh PSNR/SSIM)

```bash
vsim -c -do "do script/flow1.tcl doc/baitap1_nhieu.jpg temp/lab1_out.jpg doc/baitap1_anhgoc.jpg"
```

Flow này tự động: `pre1.py` -> mô phỏng `tb_median_ip` -> STA (`sta/median`) -> `post1.py` -> `cmp.py`.

### 5.2 Flow Bài 2 (RGB to Grayscale + brightness)

```bash
vsim -c -do "do script/flow2.tcl doc/baitap2_anhgoc.jpg temp/lab2_out.jpg 20"
```

Trong đó `20` là brightness (miền hợp lệ: `-128..127`).

Nếu bỏ trống tham số này thì mặc định chọn tham số fallback là 0 (không thay đổi độ sáng).

Flow này tự động: `pre2.py` -> mô phỏng `tb_rgb2gray_ip` -> STA (`sta/rgb2gray`) -> `post2.py`.

---

## 6. Tệp vào/ra chính

- Bài 1 (Median):
  - Input trung gian: `temp/input_median.txt`, `temp/pattern.txt`, `temp/meta1.json`
  - Output mô phỏng: `temp/output_median.txt`
- Bài 2 (RGB2Gray):
  - Input trung gian: `temp/input_rgb.txt`, `temp/meta2.json`
  - Output mô phỏng: `temp/output_gray.txt`

Ảnh kết quả cuối nằm ở đường dẫn output truyền vào `flow1.tcl` hoặc `flow2.tcl`.

---
