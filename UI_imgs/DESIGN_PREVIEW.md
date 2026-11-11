# SMART FOOD LIFE — BÁO CÁO THIẾT KẾ UI/UX GIAI ĐOẠN 1

> **Dự án:** Smart Food Life — Ứng dụng quản lý thực phẩm cá nhân (Android)  
> **Phạm vi giai đoạn 1:** Design System hoàn chỉnh & Màn hình Dashboard chuẩn (chưa triển khai 5 module chi tiết, không sinh mã nguồn ứng dụng)  
> **Cấu trúc 5 module chuẩn nghiệp vụ:** (1) Kho thực phẩm, (2) Mua sắm, (3) Công thức nấu ăn, (4) Kế hoạch bữa ăn, (5) Tài khoản và xác thực *(không có module diễn đàn hoặc thanh toán)*

---

## 1. Danh sách hình ảnh đã tạo

### 1.1. Design System (`UI_imgs/00_design_system/`)

| STT | Tệp hình ảnh | Kích thước (px) | Nội dung chính |
|---|---|---|---|
| 1 | `00_design_system/01_color_palette.png` | `2400 × 1280` | Bảng màu chuẩn: màu chính, màu phụ, màu nền, bề mặt, chữ, viền, 3 màu trạng thái kèm mã HEX, RGB và quy tắc phân bổ 60–30–10 |
| 2 | `00_design_system/02_typography.png` | `2400 × 1260` | Hệ thống chữ viết font **Roboto** (Display, Heading, Section Title, Body, Caption, Button), kích thước `sp`, độ đậm, line-height, tracking và minh họa trên thẻ thực phẩm |
| 3 | `00_design_system/03_spacing_grid.png` | `2400 × 1440` | Thang khoảng cách `4dp`, lưới 4 cột cho Android `1080 × 2400 px` (`Margin 16dp`, `Gutter 12dp`), hệ thống bo góc (`8dp–999dp`) và kích thước chuẩn component |
| 4 | `00_design_system/04_ui_components.png` | `2600 × 2470` | Thư viện 16 thành phần UI thống nhất: Button, Input, Search Bar, Food/Recipe/Meal Card, Shopping Item, Status Badge, Bottom Nav, Toolbar, Notification Badge, Dialog, Bottom Sheet, Empty State, Loading State |
| 5 | `00_design_system/05_iconography.png` | `2400 × 1260` | Bộ 14 nhóm icon nét bo tròn thống nhất (`24dp` keyline grid, nét `2dp`), biến thể Filled cho Bottom Navigation đang chọn, trạng thái màu và thang kích thước |
| 6 | `00_design_system/06_design_guidelines.png` | `2400 × 1580` | 6 nhóm nguyên tắc thiết kế & quy tắc nghiệp vụ UI (tách lô hết hạn, lập kế hoạch không trừ kho, mua sắm đồng bộ một lần, phạm vi 5 module, tiếp cận `48dp`) |

### 1.2. Màn hình Dashboard (`UI_imgs/01_dashboard/`)

| STT | Tệp hình ảnh | Kích thước (px) | Nội dung chính |
|---|---|---|---|
| 7 | `01_dashboard/01_dashboard_full.png` | `1080 × 2400` | Màn hình Dashboard chuẩn tỷ lệ `9:20` hiển thị đầy đủ từ Status Bar, Header, Search Bar, 4 Summary Cards, Thực phẩm sắp hết hạn ưu tiên, Bữa ăn hôm nay (Sáng/Trưa/Tối), Thao tác nhanh và Bottom Navigation 5 tab |
| 8 | `01_dashboard/02_dashboard_scroll.png` | `1080 × 2400` | Trạng thái cuộn (scrolled state) với Header & Bottom Nav cố định, làm rõ lô đã hết hạn màu Đỏ, danh sách thực phẩm sắp hết số lượng có nút gợi ý thêm vào mua sắm, thẻ bữa ăn chi tiết kèm nút *Hoàn thành* và Thao tác nhanh |
| 9 | `01_dashboard/03_dashboard_mobile_preview.png` | `1360 × 2640` | Bản trình diễn Dashboard đặt trong khung thiết bị Android viền siêu mỏng (tối đa hóa diện tích giao diện hiển thị) phục vụ kiểm tra trải nghiệm thực tế |

---

## 2. Mô tả chi tiết từng hình ảnh

### 2.1. Bộ Design System (`00_design_system/`)

1. **`01_color_palette.png`**  
   Trình bày hệ thống màu định hướng Fresh Food – Modern Minimalist:
   - **Brand & Accent:** `Primary #16A36A`, `Primary Dark #087F55`, `Secondary #A3D977`.
   - **Background & Surface:** `Background #F7F9F7`, `Surface #FFFFFF`, `Border #E5EBE6`.
   - **Typography:** `Text Primary #202B26`, `Text Secondary #77847C`.
   - **Semantic Status:** `Success #22C55E` (tint `#E7FAEE`), `Warning #F59E0B` (tint `#FEF5E2`), `Danger #EF4444` (tint `#FEECEC`).
   - Minh họa quy tắc tỷ lệ **60% nền/bề mặt – 30% chữ/viền trung tính – 10% màu nhấn thương hiệu** và cặp phối nút bấm.

2. **`02_typography.png`**  
   Chuẩn hóa 6 cấp chữ sử dụng font **Roboto** trên Android với hỗ trợ đầy đủ dấu tiếng Việt:
   - `Display`: `28sp`, Bold (700), Line Height `36sp`, Tracking `-0.2sp`
   - `Heading`: `22sp`, Bold (700), Line Height `28sp`, Tracking `0sp`
   - `Section Title`: `17sp`, Bold (700), Line Height `24sp`, Tracking `+0.1sp`
   - `Body`: `14sp`, Regular (400), Line Height `20sp`, Tracking `+0.2sp`
   - `Caption`: `12sp`, Medium (500), Line Height `16sp`, Tracking `+0.3sp`
   - `Button`: `14sp`, Bold (700), Line Height `20sp`, Tracking `+0.3sp`
   - Bên phải trình bày trực tiếp cấu trúc phân cấp chữ (Live Anatomy) trên thẻ *Thực phẩm sắp hết hạn*.

3. **`03_spacing_grid.png`**  
   - **Thang `4dp`:** `4dp`, `8dp`, `12dp`, `16dp`, `20dp`, `24dp`, `32dp`, `40dp`, `48dp` gắn với từng ngữ cảnh sử dụng cụ thể.
   - **Lưới Android 4 cột (`9:20`):** `Margin 16dp`, `Gutter 12dp`, khoảng cách giữa các section `20dp–24dp`, khoảng đệm Card `12dp–16dp`, vùng Bottom Navigation cố định `64–68dp`.
   - **Kích thước & Bo góc:** `8dp` (Badge), `12dp` (Button `48dp` cao / Text Input `48–52dp` cao), `16dp` (Card / Search Bar), `20dp` (Featured Card), `24dp` (Bottom Sheet / Dialog), `999dp` (Avatar / Nav Pill).

4. **`04_ui_components.png`**  
   Tổng hợp đầy đủ **16 thành phần UI** dùng chung ngôn ngữ thiết kế:
   - `01 Primary Button` (Default `#16A36A`, Pressed `#087F55`, Disabled `#E5EBE6`)
   - `02 Secondary Button` (Outlined `#16A36A`, Tonal Mint `#E7F6EF`, Hủy bỏ trung tính)
   - `03 Text Input` (Focused `#16A36A`, Error `#EF4444` kèm thông báo lỗi dưới trường nhập)
   - `04 Search Bar` (`"Bạn đang tìm thực phẩm hay công thức?"` + nút quét mã vạch)
   - `05 Status Badge` (`Còn hạn`, `Sắp hết hạn · Còn 1 ngày`, `Đã hết hạn`, `Sắp hết số lượng`, `Đã đồng bộ kho`, `Đã lên lịch · Chưa trừ kho`)
   - `06 Notification Badge` (Chuông thông báo với bộ đếm chưa đọc `#EF4444` và thẻ thông báo xem trước)
   - `07 Food Card` (Ảnh thực phẩm, tên, số lượng, vị trí lưu trữ, hạn sử dụng, cảnh báo, nút `+ Mua thêm`)
   - `08 Recipe Card` (Ảnh món ăn, thời gian nấu, khẩu phần, trạng thái yêu thích, chỉ báo `Đủ 5/6 nguyên liệu`)
   - `09 Meal Card` (Khung bữa, giờ nhắc, trạng thái `Đã lên lịch` chưa trừ kho, nút `Hoàn thành`)
   - `10 Shopping Item` (Checkbox đánh dấu đã mua, đối chiếu `Cần mua` / `Thực mua`, tách biệt `Chưa đồng bộ` vs `Đã nhập kho`)
   - `11 App Toolbar` (Nút quay lại, tiêu đề, lọc, nút thêm nhanh)
   - `12 Bottom Navigation` (5 tab cố định: `Trang chủ`, `Kho`, `Công thức`, `Kế hoạch`, `Tài khoản`)
   - `13 Dialog` (Hộp thoại xác nhận hoàn thành bữa ăn và trừ kho FEFO)
   - `14 Bottom Sheet` (Bảng thao tác nhanh bo góc trên `24dp`)
   - `15 Empty State` (Minh họa + thông điệp + nút `Lập kế hoạch ngay`)
   - `16 Loading State` (Skeleton placeholder đồng bộ cấu trúc Card)

5. **`05_iconography.png`**  
   Trình bày đủ **14 nhóm icon** (`Trang chủ`, `Kho thực phẩm`, `Mua sắm`, `Công thức`, `Kế hoạch`, `Tài khoản`, `Thông báo`, `Tìm kiếm`, `Thêm`, `Chỉnh sửa`, `Xóa`, `Lịch`, `Hạn sử dụng`, `Vị trí lưu trữ`) kèm biến thể Filled cho 5 tab điều hướng chính, bảng quy chuẩn lưới `24dp × 24dp` (padding an toàn `2dp`, stroke `2dp`), bảng màu trạng thái và thang kích thước `16dp / 20dp / 24dp / 28dp`.

6. **`06_design_guidelines.png`**  
   Hệ thống hóa 6 nhóm nguyên tắc kết nối trực tiếp Design System với quy tắc nghiệp vụ trong báo cáo phân tích và CSDL 18 bảng (`lo_thuc_pham`, `cau_hinh_thuc_pham`, `chi_tiet_mua`, `bua_an`, `mon_an_ke_hoach`, `thong_bao`).

### 2.2. Bộ màn hình Dashboard (`01_dashboard/`)

7. **`01_dashboard_full.png` (`1080 × 2400 px`)**  
   - **Header:** Ảnh đại diện cá nhân, lời chào `"Xin chào!"`, tên người dùng (`Nguyễn Văn Định`), nút thông báo kèm badge đỏ `"3"`.
   - **Search Bar:** Thanh tìm kiếm bo góc `15dp` với placeholder `"Bạn đang tìm thực phẩm hay công thức?"` và phím tắt quét mã vạch.
   - **Summary Cards (2×2):**
     1. *Thực phẩm trong kho*: `24` (`4 vị trí · 28 lô khả dụng`)
     2. *Thực phẩm sắp hết hạn*: `3` (`1 đã hết hạn · Ưu tiên dùng`) — nhấn sắc cam nổi bật
     3. *Danh sách mua sắm*: `7 món` (`2 gợi ý sắp hết · Chưa đồng bộ`) — lối vào nhanh module Mua sắm
     4. *Bữa ăn hôm nay*: `3 bữa` (`Sáng · Trưa · Tối (1 đã ăn)`)
   - **Thực phẩm sắp hết hạn (Ưu tiên):** Hiển thị 3 mục tiêu biểu: *Sữa tươi thanh trùng* (`Còn 1 ngày` + nút `+ Mua thêm`), *Thịt bò thăn* (`Còn 2 ngày`), *Rau cải xanh* (`Còn 3 ngày`).
   - **Bữa ăn hôm nay:** Hàng 3 thẻ trực quan theo khung giờ: *Sáng (07:00)* — Phở bò tái (`Đã ăn · Đã trừ`), *Trưa (12:00)* — Cơm tấm sườn (`Đã lên lịch`), *Tối (18:30)* — Cá hồi rau củ (`Chưa trừ kho`).
   - **Thao tác nhanh:** 4 nút chức năng cốt lõi (*Thêm thực phẩm*, *Tạo DS mua sắm*, *Tạo công thức*, *Lập kế hoạch bữa*).
   - **Bottom Navigation:** Cố định 5 tab (`Trang chủ` đang chọn, `Kho`, `Công thức`, `Kế hoạch`, `Tài khoản`).

8. **`02_dashboard_scroll.png` (`1080 × 2400 px`)**  
   Thể hiện trạng thái người dùng cuộn xuống trên Dashboard (Header thu gọn & Bottom Navigation ghim cố định):
   - **Cảnh báo hạn dùng (Đỏ & Cam):** Tách bạch lô **đã hết hạn** màu Đỏ `#EF4444` (*Sữa chua Hy Lạp · Hết hạn · Không tính tồn*) và lô **sắp hết hạn** màu Cam (*Sữa tươi thanh trùng · Còn 1 ngày*).
   - **Thực phẩm sắp hết · Gợi ý mua:** Hiển thị trực tiếp thực phẩm dưới ngưỡng (`Trứng gà ta: Còn 2 quả · Ngưỡng 6 quả`) và nguyên liệu thiếu từ công thức (`Cà rốt tươi: Thiếu 100 g`) kèm nút thêm nhanh vào danh sách mua sắm (`+ Thêm 10 quả`, `+ Thêm 100 g`).
   - **Kế hoạch bữa ăn hôm nay (chi tiết):** Phân biệt rõ bữa *Đã hoàn thành* (`Đã trừ kho`) với các bữa *Đã lên lịch* (`Chưa trừ tồn kho`) kèm nút CTA `Hoàn thành` để người dùng xác nhận tiêu thụ nguyên liệu.
   - **Thao tác nhanh:** Đầy đủ 4 tác vụ nhanh phía trên thanh điều hướng.

9. **`03_dashboard_mobile_preview.png` (`1360 × 2640 px`)**  
   Khung xem trước trên thiết bị Android thực tế với viền siêu mỏng để giữ trọn diện tích hiển thị giao diện, giúp đánh giá tỷ lệ chữ, mật độ thẻ và độ cân đối của thanh điều hướng.

---

## 3. Quy tắc thiết kế cốt lõi

1. **Tính nhất quán token:** Toàn bộ thành phần trên Dashboard sử dụng chính xác bộ token trong `00_design_system` (Primary `#16A36A`, Primary Dark `#087F55`, Secondary `#A3D977`, Background `#F7F9F7`, Surface `#FFFFFF`, Text Primary `#202B26`, Text Secondary `#77847C`, Border `#E5EBE6`, Success `#22C55E`, Warning `#F59E0B`, Danger `#EF4444`), font `Roboto` và lưới `4dp`.
2. **Thứ tự ưu tiên thị giác:** Cảnh báo thực phẩm sắp hết hạn và đã hết hạn luôn nằm ở tầng ưu tiên cao ngay dưới Summary Cards; không nhồi nhét quá 4 chỉ số KPI hay biểu đồ phức tạp.
3. **Ngôn ngữ thân thiện & thực tế:** Sử dụng hình ảnh thực phẩm chụp sắc nét, nền sạch, bo góc thống nhất (`10–16dp`), khoảng cách thoáng để tạo cảm giác ứng dụng quản lý thực phẩm hiện đại đạt chuẩn Google Play.

---

## 4. Các quyết định thiết kế quan trọng

1. **Tách biệt rõ trạng thái nghiệp vụ trên UI:**
   - Lên lịch bữa ăn luôn gắn nhãn `Đã lên lịch` / `Chưa trừ tồn kho` để người dùng hiểu kế hoạch chưa làm giảm tồn; chỉ khi bấm `Hoàn thành` (và xác nhận qua Dialog) mới chuyển sang `Đã hoàn thành · Đã trừ kho`.
   - Thực phẩm hết hạn dùng sắc Đỏ `#EF4444` và chú thích `Không tính tồn`, tách biệt với sắc Vàng/Cam `#F59E0B` của thực phẩm sắp hết hạn (`Còn 1–3 ngày`).
   - Thẻ mua sắm tách rõ checkbox *Đã mua* và nhãn *Chưa đồng bộ / Đã nhập kho*, tránh hiểu nhầm đánh dấu đã mua là tồn kho đã tăng ngay.
2. **Gợi ý mua sắm chủ động từ Dashboard:**  
   Đưa nút `+ Mua thêm` trực tiếp trên thẻ thực phẩm sắp hết hạn/hết hạn và khu vực `Thực phẩm sắp hết · Gợi ý mua` trong luồng cuộn Dashboard, phản ánh đúng liên kết giữa `MOD-01` (Kho), `MOD-03` (Công thức) và `MOD-02` (Mua sắm).
3. **Kiến trúc Bottom Navigation 5 mục đúng phạm vi:**  
   Cố định 5 tab: `Trang chủ`, `Kho`, `Công thức`, `Kế hoạch`, `Tài khoản`. Module **Mua sắm** được gắn làm điểm truy cập cấp 1 ngay trên Summary Card (`Danh sách mua sắm`) và Quick Actions (`Tạo DS mua sắm`), đúng yêu cầu đề bài và giữ thanh đáy gọn nhẹ cho màn hình `1080 × 2400`.
4. **Cân bằng mật độ trên `1080 × 2400`:**  
   Bố trí 3 bữa ăn hôm nay theo hàng 3 thẻ ngang ở màn hình khởi đầu (`01_dashboard_full.png`) để toàn bộ 7 khối chức năng Dashboard cùng hiển thị trọn vẹn không bị cắt; đồng thời cung cấp góc nhìn cuộn chi tiết (`02_dashboard_scroll.png`) với thẻ bữa ăn toàn chiều rộng và khối gợi ý mua sắm.

---

## 5. Những điểm cần người dùng duyệt trước khi sang Giai đoạn 2

Xin vui lòng kiểm tra và xác nhận các hạng mục sau trước khi chuyển sang thiết kế chi tiết 5 module:

- [ ] **Bảng màu & Phong cách tổng thể (`01_color_palette.png`, `06_design_guidelines.png`):** Tone xanh Emerald `#16A36A` trên nền `#F7F9F7` đã phù hợp với định hướng Fresh Food – Premium Mobile App chưa?
- [ ] **Hệ thống Typography, Spacing & Iconography (`02`, `03`, `05`):** Kích thước chữ `Roboto`, mật độ lưới `4dp`, và bộ 14 icon nét bo tròn đã rõ ràng và đồng nhất chưa?
- [ ] **Thư viện 16 UI Components (`04_ui_components.png`):** Kiểu dáng Button, Input, Food/Recipe/Meal Card, Shopping Item, Dialog, Bottom Sheet, Empty/Loading State có điểm nào cần điều chỉnh trước khi nhân bản sang 5 module chi tiết?
- [ ] **Bố cục Dashboard (`01_dashboard_full.png`, `02_dashboard_scroll.png`, `03_dashboard_mobile_preview.png`):** Thứ tự ưu tiên (Summary → Sắp hết hạn → Bữa ăn hôm nay → Thao tác nhanh), cách hiển thị cảnh báo Vàng/Cam/Đỏ và nút gợi ý mua sắm đã đúng kỳ vọng nghiệp vụ chưa?
- [ ] **Phê duyệt chuyển tiếp:** Xác nhận duyệt bộ thiết kế Giai đoạn 1 để bắt đầu thiết kế chi tiết màn hình cho 5 module (Kho thực phẩm, Mua sắm, Công thức nấu ăn, Kế hoạch bữa ăn, Tài khoản & Xác thực).

