# LAB01 - Thiết kế hệ thống số với HDL

## Thông tin nhóm
- **Môn học:** Thiết kế hệ thống số với HDL - CE213.Q21.VMTN
- **Giảng viên hướng dẫn:** Ngô Hiếu Trường
- **Thành viên:**
  1. Huỳnh Nhật Phát - MSSV: 24521294
  2. Nguyễn Đông Quân - MSSV: 24521438

## Yêu cầu đề bài
Sử dụng ngôn ngữ Verilog HDL thiết kế bộ đếm (như Hình 1-1) với giá trị ban đầu của mạch đếm được nạp vào thông qua các chân Preset và Clear. Yêu cầu chi tiết nằm trong: doc/main_requirements.txt.
*(Lưu ý: Không yêu cầu viết Testbench).*

## Cấu trúc mã nguồn
- LAB01_Behavioral.v: Cấu trúc code mô tả theo kiểu hành vi (Behavioral).
- LAB01_Structural.v: Cấu trúc code mô tả theo kiểu cấu trúc (Structural).
- Các file còn lại (.qpf, .qsf, .qws...): Các file của project Quartus.

## Hướng dẫn sử dụng
1. Mở IDE Quartus II, load project file LAB01.qpf.
2. Tuỳ thuộc vào việc bạn muốn chạy kiểu thiết kế nào, hãy set file đó (LAB01_Behavioral.v hoặc LAB01_Structural.v) làm **Top-Level Entity**.
3. Khởi chạy để xem mô phỏng trực tiếp bằng Quartus II Simulator.