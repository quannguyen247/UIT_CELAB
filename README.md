# Thiết kế hệ thống số với HDL - CE213.Q21.VMTN
## LAB 2: Xử lý Ảnh trên phần cứng (RGB to Grayscale & Median Filter)

### THÔNG TIN NHÓM THỰC HIỆN
- **Sinh viên 1:** Huỳnh Nhật Phát - MSSV: 24521294
- **Sinh viên 2:** Nguyễn Đông Quân - MSSV: 24521438
- **Giảng viên hướng dẫn:** Ngô Hiếu Trường
- **Môn học:** Thiết kế hệ thống số với HDL - CE213.Q21.VMTN

---

### 1. CẤU TRÚC THƯ MỤC VÀ CHỨC NĂNG

Dự án được cố tình chia thành nhiều thư mục khác nhau để đảm phảo tính module, dễ quản lý luồng dữ liệu giữa phần mềm (Python) và phần cứng (Verilog):

* **`doc/`**: Chứa đề bài (`HDL-Lab2.pdf`) và các tệp hình ảnh đầu vào (ảnh gốc, ảnh nhiễu) dùng để test module.
* **`rtl/`**: Thư mục lõi chứa mã nguồn thiết kế phần cứng bằng ngôn ngữ Verilog gồm các module chính (`rgb2gray.v`, `median.v`).
* **`tb/`**: Không gian dành cho các bộ Testbench (`tb_rgb2gray.v`, `tb_median.v`). Các testbench này cung cấp tín hiệu kích thích (stimuli) mô phỏng từ file text để kiểm tra logic của khối RTL.
* **`script/`**: Tập hợp các công cụ tự động hóa chạy bằng Python và Tcl:
  * Khâu tiền xử lý (Pre-processing): `pre1.py`, `pre2.py` để chuyển đổi ảnh từ `doc/` sang ma trận điểm ảnh dạng text hex/binary.
  * Tự động hóa mô phỏng (Simulation flow): `flow1.tcl`, `flow2.tcl` là kịch bản chạy mô phỏng ModelSim tự động.
  * Khâu hậu xử lý (Post-processing): `post1.py`, `post2.py` tái tạo lại ảnh kết quả từ text xuất ra sau mô phỏng.
  * Xác thực: `cmp.py` dùng để so sánh tự động bản phần cứng với chuẩn phần mềm nhằm đánh giá sai số.
* **`sim/`**: Thư mục làm việc (working directory) của ModelSim/QuestaSim. Nơi chứa file database compiled (thư mục `work/`), `transcript`, v.v.
* **`temp/`**: Không gian trao đổi dữ liệu tạm (buffer) giữa môi trường phần mềm và môi trường sim. Chứa các file `pattern.txt`, `input_*.txt`, `output_*.txt`,... mà Testbench sẽ đọc/ghi vào.

---

### 2. WORKFLOW (LUỒNG CHẠY CHƯƠNG TRÌNH STEP-BY-STEP)

Quy trình sử dụng chương trình hoàn thiện tuân thủ Data Flow sau:
**Python (Image -> Text) -> ModelSim (Text -> Text, chạy RTL) -> Python (Text -> Image)**

#### **Bước 1: Tiền xử lý (Pre-Processing)**
Mục đích: Chuyển đổi file ảnh `.jpg`/`.png` thành định dạng mã hex/binary để Testbench có thể `$readmemh`/`$readmemb`.
- Mở Terminal (cmd/powershell).
- Chạy: `python script/pre1.py` (hoặc `pre2.py` tương ứng cho mỗi bài).
- Kiểm tra mục `temp/` để đảm bảo file `pattern.txt` (ma trận ảnh) và `meta.json` (thông số w/h) đã được tạo ra.

#### **Bước 2: Chạy Mô phỏng (Simulation)**
Mục đích: Khởi động mô hình phần cứng, nạp dữ liệu pixel, xử lý logic (chuyển đổi Gray hoặc lọc Median), và lưu kết quả lại ra file log.
- Mở terminal/CMD ở giao diện có chứa ModelSim/MSYS2/Tcl.
- Hoặc mở ứng dụng ModelSim trực tiếp. Change directory (cd) về thư mục root hoặc thư mục `sim/`.
- Thực thi kịch bản tcl: 
  `vsim -do script/flow1.tcl` (Hoặc gõ `do script/flow1.tcl` ngay trong cửa sổ Transcript của ModelSim).
- ModelSim sẽ tự compile code RTL (`rtl/`) và TB (`tb/`), chạy mô phỏng và Testbench sẽ bắt đầu ghi vào tập tin log dạng text xuất ra thư mục `temp/output_*.txt`.

#### **Bước 3: Hậu xử lý (Post-Processing)**
Mục đích: Build lại hình ảnh thực tế từ các giá trị pixel rời rạc mà Verilog trả về.
- Chạy: `python script/post1.py` (hoặc `post2.py`).
- Script sẽ lấy chuỗi hex/binary từ `temp/` tái tạo thành ảnh kết quả (Ví dụ `output.png`).

#### **Bước 4: Xác thực và Đối chiếu (Testing & Compare)**
Mục đích: Đảm bảo độ chính xác so với mô hình tham chiếu thực tế.
- Chạy: `python script/cmp.py`.
- Script tiến hành tính sai số (Error diff / MSE) giữa ảnh phần cứng chạy được và thuật toán tham chiếu chạy trực tiếp trên python.

---