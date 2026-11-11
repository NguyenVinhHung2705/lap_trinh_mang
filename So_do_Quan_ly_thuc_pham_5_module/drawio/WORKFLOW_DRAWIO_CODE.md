# BỘ MÃ NGUỒN WORKFLOW CHẠY TRÊN DRAW.IO (5 MODULE + TỔNG THỂ + LIÊN KẾT)

Bộ tệp này chuyển đổi đầy đủ **7 sơ đồ workflow** (`wf5_tong_the`, `wf5_kho`, `wf5_mua_sam`, `wf5_cong_thuc`, `wf5_ke_hoach`, `wf5_tai_khoan`, `wf5_lien_ket`) sang mã chuẩn để mở, chỉnh sửa và xuất ảnh trên **draw.io** ([app.diagrams.net](https://app.diagrams.net)).

---

## CÁCH 1 (KHUYÊN DÙNG): MỞ FILE `.drawio` CHUẨN XML (ĐÚNG TỪNG TỌA ĐỘ & MÀU SẮC)

Các file XML `.drawio` đã được xuất sẵn theo đúng tọa độ khối, màu xanh nhạt `#EAF3F8`, hình thoi vàng `#FFFACD` và hướng mũi tên như hình mẫu:

| File | Nội dung |
|---|---|
| `ALL_WORKFLOWS_5_MODULE.drawio` | **File tổng hợp gồm đủ 7 tab** trong một bản vẽ duy nhất |
| `01_wf5_tong_the.drawio` | 1. Quy trình Tổng thể ứng dụng |
| `02_wf5_kho.drawio` | 2. Quy trình Quản lý Kho thực phẩm |
| `03_wf5_mua_sam.drawio` | 3. Quy trình Quản lý Mua sắm |
| `04_wf5_cong_thuc.drawio` | 4. Quy trình Công thức nấu ăn |
| `05_wf5_ke_hoach.drawio` | 5. Quy trình Kế hoạch bữa ăn |
| `06_wf5_tai_khoan.drawio` | 6. Quy trình Tài khoản & Xác thực |
| `07_wf5_lien_ket.drawio` | 7. Quy trình Liên kết giữa các module |

**Thao tác trên draw.io:**
1. Truy cập [app.diagrams.net](https://app.diagrams.net) (hoặc mở Draw.io Desktop).
2. Chọn **File → Open from → Device...** (hoặc kéo thả file `ALL_WORKFLOWS_5_MODULE.drawio` vào khung vẽ).
3. Chuyển đổi giữa 7 workflow ở thanh tab phía dưới; từng khối và mũi tên đều chỉnh sửa độc lập được.

---

## CÁCH 2: DÁN CODE `<mxGraphModel>` VÀO `Extras -> Edit Diagram...`

Nếu bạn đang mở sẵn một trang trắng trên draw.io và muốn dán code XML trực tiếp:
1. Mở một trong các file lẻ `01_wf5_*.drawio` bằng trình soạn thảo text.
2. Copy từ thẻ `<mxGraphModel ...>` đến hết `</mxGraphModel>`.
3. Trên draw.io, vào **Extras → Edit Diagram...**, dán toàn bộ đoạn XML đó vào rồi nhấn **OK**.

---

## CÁCH 3: CODE MERMAID ĐỂ DÁN VÀO `Arrange -> Insert -> Advanced -> Mermaid...`

Nếu bạn muốn dùng trình nhập code text nhanh của draw.io (**Arrange → Insert → Advanced → Mermaid...**), hãy copy từng đoạn code dưới đây dán vào ô nhập và bấm **Insert**:

### 1. Workflow Tổng thể (`wf5_tong_the`)
```mermaid
flowchart TD
    n1["Bắt đầu"] --> n2["Mở ứng dụng Android"]
    n2 --> n3["Đăng ký / Đăng nhập"]
    n3 --> d1{"Xác thực hợp lệ"}
    d1 -->|Không| n_err["Hiện lỗi<br/>Nhập lại thông tin"]
    n_err -->|Thử lại| n3
    d1 -->|Có| n4["Trang chủ<br/>Chọn một trong 5 module"]
    n4 --> n5["Kho • Mua sắm • Công thức<br/>Kế hoạch bữa ăn • Tài khoản"]
    n5 --> n6["Lưu và đồng bộ dữ liệu<br/>Quay lại trang chủ"]
    n6 -->|Khi kết thúc phiên| n7["Đăng xuất / Đóng ứng dụng"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n_err,n4,n5,n6,n7 box
    class d1 cond
```

### 2. Workflow Kho thực phẩm (`wf5_kho`)
```mermaid
flowchart TD
    n1["Mở Kho thực phẩm"] --> n2["Chọn thêm / sửa / chuyển vị trí<br/>hoặc loại bỏ thực phẩm"]
    n2 --> n3["Nhập thông tin thực phẩm<br/>Số lượng • Đơn vị • Hạn dùng"]
    n3 --> d1{"Dữ liệu hợp lệ"}
    d1 -->|Không| n_err["Hiện lỗi<br/>Sửa lại thông tin"]
    n_err -->|Sửa| n3
    d1 -->|Có| n4["Lưu theo từng lô<br/>Ghi lịch sử thay đổi"]
    n4 --> n5["Cập nhật tồn và vị trí<br/>Kiểm tra hạn sử dụng"]
    n5 --> d2{"Sắp hết hạn hoặc<br/>sắp hết"}
    d2 -->|Có| n_warn["Hiện cảnh báo<br/>Gợi ý nấu / thêm mục mua"]
    n_warn --> n6["Hiển thị kho đã cập nhật"]
    d2 -->|Không| n6

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n_err,n4,n5,n_warn,n6 box
    class d1,d2 cond
```

### 3. Workflow Mua sắm (`wf5_mua_sam`)
```mermaid
flowchart TD
    n1["Mở danh sách mua sắm"] --> n2["Thêm thủ công / nguyên liệu thiếu<br/>hoặc thực phẩm sắp hết"]
    n2 --> n3["Sửa số lượng dự kiến<br/>Phân loại và tra cứu danh sách"]
    n3 --> n4["Đi mua và đánh dấu đã mua<br/>Nhập số lượng thực tế"]
    n4 --> d1{"Xác nhận hoàn tất"}
    d1 -->|Chưa| n_hold["Lưu danh sách đang mua<br/>Chưa thay đổi tồn kho"]
    d1 -->|Có| n5["Nhập hạn dùng và vị trí<br/>cho các mục thực mua"]
    n5 --> d2{"Dữ liệu nhập kho<br/>hợp lệ"}
    d2 -->|Không| n_err["Báo lỗi<br/>Bổ sung dữ liệu"]
    n_err -->|Sửa| n5
    d2 -->|Có| n6["Đồng bộ vào kho đúng một lần<br/>Lưu lịch sử mua và nhập kho"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n4,n_hold,n5,n_err,n6 box
    class d1,d2 cond
```

### 4. Workflow Công thức nấu ăn (`wf5_cong_thuc`)
```mermaid
flowchart TD
    n1["Mở Công thức nấu ăn"] --> n2["Tạo / sửa công thức riêng<br/>hoặc chọn công thức có sẵn"]
    n2 -->|Tạo mới| n3["Nhập món, nguyên liệu<br/>định lượng và các bước nấu"]
    n2 -->|Chọn có sẵn| n4["Lưu công thức hợp lệ<br/>Chọn số khẩu phần"]
    n3 --> n4
    n4 --> n5["So khớp nguyên liệu với kho<br/>Ưu tiên lô gần hết hạn"]
    n5 --> d1{"Đủ nguyên liệu còn<br/>dùng được"}
    d1 -->|Không| n_missing["Thêm lượng thiếu<br/>vào danh sách mua sắm"]
    n_missing -->|Vẫn có thể lập kế hoạch| n6["Xem nguyên liệu cần dùng<br/>Chọn ngày và khung bữa"]
    d1 -->|Có| n6
    n6 --> n7["Thêm vào kế hoạch bữa ăn"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n4,n5,n_missing,n6,n7 box
    class d1 cond
```

### 5. Workflow Kế hoạch bữa ăn (`wf5_ke_hoach`)
```mermaid
flowchart TD
    n1["Mở lịch tuần / tháng"] --> n2["Chọn ngày và khung bữa<br/>Sáng • Trưa • Tối • Phụ"]
    n2 --> n3["Thêm công thức / thực phẩm ăn liền<br/>Nhập số khẩu phần hoặc số lượng"]
    n3 --> n4["Lưu kế hoạch<br/>Nhắc chuẩn bị bữa ăn"]
    n4 --> d1{"Xác nhận đã ăn<br/>xong"}
    d1 -->|Chưa| n_keep["Giữ nguyên kế hoạch<br/>Chưa trừ tồn kho"]
    d1 -->|Có| n5["Kiểm tra lượng thực tế<br/>và tồn kho còn dùng được"]
    n5 --> d2{"Đủ tồn và chưa ghi<br/>nhận"}
    d2 -->|Không| n_lack["Thông báo thiếu tồn<br/>hoặc bữa ăn đã hoàn thành"]
    d2 -->|Có| n6["Trừ kho và ghi biến động<br/>Đánh dấu hoàn thành một lần"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n4,n_keep,n5,n_lack,n6 box
    class d1,d2 cond
```

### 6. Workflow Tài khoản (`wf5_tai_khoan`)
```mermaid
flowchart TD
    n1["Mở module Tài khoản"] --> n2["Chọn đăng ký / đăng nhập<br/>quên mật khẩu / hồ sơ"]
    n2 --> n3["Nhập thông tin theo chức năng<br/>Gửi yêu cầu xác thực"]
    n3 --> d1{"Thông tin hợp lệ"}
    d1 -->|Không| n_err["Hiện lỗi<br/>Yêu cầu nhập lại"]
    n_err -->|Sửa| n3
    d1 -->|Có| n4["Xử lý chức năng đã chọn<br/>Xác thực hoặc cập nhật dữ liệu"]
    n4 --> n5["Trả kết quả xử lý<br/>hoặc gửi email xác thực / khôi phục"]
    n5 -->|Thành công| n6["Vào app / trở lại màn hình tài khoản<br/>Đăng xuất khi cần"]
    n6 -->|Đăng xuất| n7["Xóa phiên cục bộ khi đăng xuất<br/>Giữ dữ liệu đúng tài khoản"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n3,n_err,n4,n5,n6,n7 box
    class d1 cond
```

### 7. Workflow Liên kết các module (`wf5_lien_ket`)
```mermaid
flowchart TD
    n1["Kho thực phẩm hiện có"] --> n2["Chọn công thức và khẩu phần<br/>So khớp với tồn kho"]
    n2 --> d1{"Thiếu nguyên liệu"}
    d1 -->|Có| n_buy1["Tạo mục mua lượng còn thiếu"]
    n_buy1 --> n_buy2["Mua và xác nhận thực mua<br/>Đồng bộ thêm vào kho"]
    n_buy2 -->|Đã bổ sung| n3["Lập kế hoạch ngày và bữa<br/>Chưa trừ tồn kho"]
    d1 -->|Không| n3
    n3 --> n4["Chuẩn bị và hoàn thành bữa ăn<br/>Kiểm tra lượng thực tế"]
    n4 --> d2{"Đủ lượng tồn hợp lệ"}
    d2 -->|Không| n_lack["Báo thiếu tồn<br/>Cập nhật kho hoặc lượng dùng"]
    d2 -->|Có| n5["Trừ kho theo lô một lần<br/>Lưu lịch sử và trạng thái"]

    classDef box fill:#EAF3F8,stroke:#4B637E,color:#1F2937
    classDef cond fill:#FFFACD,stroke:#4B637E,color:#1F2937
    class n1,n2,n_buy1,n_buy2,n3,n4,n_lack,n5 box
    class d1,d2 cond
```

