# LAB 3: Direct Memory Access (DMA) 

**Giảng viên hướng dẫn:** Ngô Hiếu Trường  
**Thành viên:** Nhóm 2 người *(chi tiết tại file báo cáo và MIT License)*

> **Lưu ý từ nhóm phát triển:** Repository này là phiên bản đã được tối ưu hóa toàn diện từ một codebase gốc "thảm họa". Bọn mình đã review, làm sạch code và chuyển đổi hoàn toàn cơ chế giao tiếp từ **Polling (thăm dò)** sang **Interrupt (ngắt)**. Nhờ đó, CPU không còn bị treo hay lãng phí tài nguyên để chờ DMA, mang lại hiệu năng hệ thống tối đa :))

---

## 1. Tổng Quan Kiến Trúc và Các Chức Năng Module

DMA (Direct Memory Access) là một bộ điều khiển phần cứng cho phép dữ liệu được chuyển trực tiếp giữa các vùng bộ nhớ (như RAM) mà không cần sự can thiệp liên tục của CPU. Dưới đây là bức tranh toàn cảnh về cách các module phối hợp với nhau:

| Thành phần | Vai trò thực tế | Nhiệm vụ chính trong code |
| :--- | :--- | :--- |
| **CPU (Nios II)** | Giám đốc | Chỉ ra lệnh lúc đầu: quy định nơi đọc, nơi ghi, số lượng. Cuối cùng, nhận kết quả báo cáo khi công việc hoàn tất. |
| **RAM (On-Chip Memory)**| Kho chứa hàng | Nơi lưu trữ dữ liệu nguồn cần copy và là đích đến của dữ liệu mới. |
| **Control Slave** | Bàn tiếp tân | Đứng ra nhận thông tin cấu hình từ CPU thông qua giao tiếp Avalon Memory Mapped (Avalon-MM) Slave. Sinh các xung đánh thức Master. |
| **Read Master** | Người bốc hàng | Chủ động chiếm quyền Bus, đọc dữ liệu từ RAM nguồn và đẩy nhanh vào FIFO. |
| **Write Master** | Người xếp hàng | Chủ động chiếm quyền ngõ ra, lấy dữ liệu đang chờ sẵn ở FIFO và ghi đè xuống RAM đích. |
| **FIFO** | Xe trung chuyển | Đóng vai trò làm bộ đệm dữ liệu tạm thời. Giúp Read Master và Write Master chạy song song vô cấp mà không phải đợi nhau, triệt tiêu độ trễ thắt nút cổ chai. |

---

## 2. Bản Đồ Thanh Ghi và Luồng Dữ Liệu (Register Map)

Quá trình điều khiển DMA được thực hiện qua các thanh ghi (Registers) được ánh xạ bộ nhớ trên Control Slave. Có 2 thanh ghi đóng vai trò xương sống cho việc trao đổi trạng thái: **Control Register (`REG_CTRL`)** và **Status Register (`REG_STAT`)**.

| Đặc điểm | Thanh ghi Control (`REG_CTRL`) | Thanh ghi Status (`REG_STAT`) |
| :--- | :--- | :--- |
| **Bản chất** | Hộp thư đi của CPU | Hộp thư đến của CPU |
| **Hướng dữ liệu** | CPU &rarr; Control Slave &rarr; Logic nội bộ | Logic nội bộ &rarr; Control Slave &rarr; CPU |
| **Quyền của CPU** | **Ghi** (Ra lệnh) | **Đọc** (Theo dõi tiến độ) |
| **Nội dung chính** | Các bit kích hoạt (`CTRL_GO`), cho phép ngắt (`CTRL_IRQ`) | Các cờ trạng thái báo hiệu (`BUSY`, `DONE`, `IRQ_PENDING`) |
| **Khi nào sử dụng?** | Dùng ngay trước khi bắt đầu một phiên truyền tải. | Dùng trong khoảng thời gian chờ (Interrupt ISR) hoặc sau khi xong việc. |

*Ghi chú: CPU tương tác thông qua các Offset chuẩn: `REG_SRC` (0) cho nguồn, `REG_DST` (1) cho đích, `REG_LEN` (2) cho số byte cần truyền.*

---

## 3. Hoạt Động Dựa Trên Ngắt (Interrupt-Driven Workflow) thay vì Polling
Thay vì bắt CPU liên tục phải hỏi "Mày làm xong chưa?" với Polling, bọn mình đã rewrite module để áp dụng phương pháp **W1C (Write 1 to clear) với Interrupt**:
1. **CPU uỷ quyền:** CPU tuần tự Ghi vào `REG_SRC`, `REG_DST`, `REG_LEN`. 
2. **Kích hoạt ngầm:** CPU Ghi bit `CTRL_IRQ = 1` để cấp phép ngắt phần cứng, và bật bit `CTRL_GO = 1`. Lập tức Control Slave phát tia chớp xung `Start` xốc dậy các RM/WM. DMA bắt đầu truyền tải, CPU ngay lập tức được giải phóng để làm việc khác.
3. **Pháo hiệu ngắt (IRQ Ping):** Khi Byte cuối cùng được đẩy vào kho đích, `Write Master` phất cờ `done`. Mạch Control Slave lập tức hạ `BUSY`, sáng cờ `DONE`, đồng thời đẩy mức đường dây `oIRQ` lên mức 1, trực tiếp "đâm" vào chân ngắt của CPU.
4. **Phản hồi từ ISR:** CPU tạm ngưng tiến trình hiện hành, bay vào hàm phục vụ ngắt (ISR). CPU đọc `REG_STAT` xác nhận chiến lợi phẩm. Ngay sau đó, CPU ghi số `1` vào đúng bit báo hiệu trên `REG_STAT` (Write 1 to clear) để xóa cờ, hạ chuông ngắt, hoàn tất phiên làm việc sạch sẽ.

---

## 4. Hướng Dẫn Tích Hợp Hệ Thống Bằng Platform Designer (Qsys)

Để gắn kết CPU, RAM và DMA thành một khối kiến trúc System-on-a-Chip (SoC) hoàn thiện, làm theo các bước chuẩn mực sau:

### Bước 1: Chuẩn bị IP Components
- Thêm tổ hợp **Nios II Processor** (Khối trung tâm).
- Thêm **On-Chip Memory (RAM or ROM)** (Khối RAM).
- Chọn Add bộ DMA tự custom của nhóm vào Library từ file `DMA_hw.tcl`.

### Bước 2: Nối mạng Avalon-MM (Data & Control)
Đảm bảo luồng dữ liệu thông suốt bằng cách khai báo đúng Data Master vào Slave phù hợp:
1. Giao diện Cấu Hình: Nối cổng **Data Master** của CPU vào cổng **Avalon Slave** của khối *DMA Control Slave*.
2. Bộ Nhớ Chung: Kết nối từ **Data Master** của CPU tới cổng **Avalon Slave S1** của *On-Chip Memory*.
3. Read Path: Kế tiếp, móc cổng **Avalon Master** của *DMA Read Master* vào cùng cổng **Avalon Slave S1** của *On-Chip Memory*. 
4. Write Path: Do yêu cầu thiết kế thông lượng lớn không đụng độ, móc cổng **Avalon Master** của *DMA Write Master* vào cổng độc lập **Avalon Slave S2** của RAM (Nhớ bật Dual-Port RAM để khai sinh ra cổng S2).

### Bước 3: Đồng Bộ Thời Gian và Mạng Xóa (Clock & Reset)
- Kéo dây cấp nguồn tín hiệu `clk` gốc từ mạch vào tất cả các component (CPU, RAM, DMA Submodules).
- Đồng bộ tất cả các đường `reset` và nối về nguồn sinh Reset chung của mạch. Việc này tối quan trọng để giữ cờ không bị lật lung tung lúc bật nguồn.

### Bước 4: Thiết Lập Dòng Ngắt (Interrupt Routing - Bắt buộc)
*Vì Project đã loại bỏ hoàn toàn Polling, dây ngắt là bắt buộc!*
- Nhấn mở cột `IRQ`, kéo nút nối từ chân **Interrupt Sender** của *DMA Control Slave* sang cột chỉ hướng thẳng vào đường **IRQ Receiver** của CPU. Đặt IRQ number mặc định là `0` hoặc vị trí thấp tương ứng để set priority cao nhất.

### Bước 5: Chốt Địa Chỉ & Hoàn Thiện
1. Click mục **System** -> Chọn **Assign Base Addresses** để tự động gán offset và giải quyết toàn bộ xung đột chồng lấn (overlapping). 
2. Đảm bảo toàn mạch Qsys chuyển dấu tích xanh lá (Zero Errors).
3. Bấm **Generate HDL** góc bên phải dưới màn hình. 
4. Import block system vào sơ đồ khối chính hoặc top-level Verilog file, nạp pin và build!
