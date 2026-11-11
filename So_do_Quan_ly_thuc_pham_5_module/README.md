# Sơ đồ quy trình và CSDL ứng dụng quản lý thực phẩm cá nhân

Giải nén toàn bộ thư mục, sau đó bấm đúp `workflow_tong_quan.html` bằng Chrome hoặc Edge. Không mở trực tiếp tệp HTML khi vẫn còn trong ZIP. Không cần cài thư viện, server hoặc kết nối mạng.

## Phạm vi

5 module cho nhóm 5 thành viên: Kho thực phẩm, Mua sắm, Công thức nấu ăn, Kế hoạch bữa ăn, Tài khoản và xác thực. Không có module diễn đàn.

## Các tệp

| Tệp | Nội dung |
|---|---|
| workflow_tong_quan.html | Chọn quy trình từng module; các bước hiển thị bảng đọc R và ghi W; bấm tên bảng để xem chi tiết; chuyển sang lưu đồ |
| erd_csdl.html | ERD 18 bảng chia nhóm màu; PK, FK, UQ, kiểu dữ liệu, đường nối; kéo, phóng to, tìm và tập trung vào bảng hoặc module |
| csdl_chi_tiet.html | Tìm bảng; cột và kiểu dữ liệu; khóa, NULL, quan hệ vào/ra, quy trình sử dụng và CREATE TABLE |
| chuc_nang_cay.html | Cây chức năng 5 module; tìm, mở hoặc thu toàn bộ nhánh |
| schema.sql | Tạo mô hình CSDL MySQL 8.0.16 trở lên; khóa chính, khóa ngoại, duy nhất và một số CHECK |
| erd.png | Ảnh ERD để xem và chèn vào báo cáo |
| erd.svg | ERD vector có thể chỉnh sửa và phóng lớn |
| wf5_*.png | Lưu đồ dùng trong trang quy trình |

## Lưu ý thiết kế

Đây là bộ tài liệu sơ đồ tương tác để phân tích và trình bày, không phải mã nguồn app Android. Phần code app đang tạm dừng theo yêu cầu.

SQL là mô hình quan hệ logic minh họa. Nếu triển khai Flutter + Firebase thì Firebase Authentication quản lý mật khẩu/token/phiên; không sao chép bảng token hay mật khẩu sang Firestore. Các bảng nghiệp vụ cần ánh xạ thành collection và kiểm tra tham chiếu/quyền sở hữu trong nghiệp vụ và Security Rules.

SQL không có lệnh DROP. Chạy trên cơ sở dữ liệu mới; không chạy lại nguyên tệp khi các bảng đã tồn tại. MySQL 8.0.16+ mới thực thi các CHECK được dùng. Kiểm tra quyền sở hữu, quy đổi đơn vị, nhập/trừ kho nguyên tử và chống thao tác lặp là các ràng buộc nghiệp vụ, không được bảo đảm chỉ bằng khóa ngoại.

Nhận diện ảnh AI và tra mã vạch trong cây là đặc tả chức năng dự kiến; các tệp sơ đồ không gọi dịch vụ AI hoặc camera.
