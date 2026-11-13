# Smart Food Life — Ứng dụng Quản lý Thực phẩm Cá nhân (Android)

> **Môn học:** Lập trình mạng  
> **Lớp:** 23CT1 — Khoa Công nghệ Thông tin, Đại học Kiến trúc Đà Nẵng  
> **GVHD:** TS. Đặng Hùng Vĩ  
> **Nhóm sinh viên thực hiện (5 thành viên / 5 phân hệ):**
> 1. Nguyễn Văn Định (`2351220031`) — **MOD-01:** Quản lý Kho thực phẩm
> 2. Nguyễn Vĩnh Hưng (`2351220021`) — **MOD-02:** Quản lý Mua sắm
> 3. Nguyễn Khang Hy (`2351220008`) — **MOD-03:** Công thức Nấu ăn
> 4. Hồ Nguyên Khởi (`2351220090`) — **MOD-04:** Kế hoạch Bữa ăn *(Trưởng nhóm & Tích hợp)*
> 5. Bùi Thị Quỳnh Như (`2351220202`) — **MOD-05:** Tài khoản & Xác thực

---

## ⚠️ QUY CHUẨN CÔNG NGHỆ CHỐNG LỆCH HƯỚNG (BẮT BUỘC CHO CẢ NHÓM & CÁC AI AGENT)

Dự án đã được thống nhất triển khai theo hướng:
- **Nền tảng & Framework:** **Flutter 3.x (ngôn ngữ Dart)**.
- **Hệ điều hành mục tiêu:** **Android** (đóng gói file `.apk` / `.aab`).
- **Môi trường phát triển khuyến nghị:** **Android Studio** (cài thêm plugin *Flutter* và *Dart*) hoặc Visual Studio Code.
- **Backend & Cơ sở dữ liệu:** **Firebase Authentication** + **Cloud Firestore** + **Firebase Cloud Messaging / Local Notifications**.
- **Quản lý trạng thái (State Management):** **Riverpod** (`flutter_riverpod`).

> ⛔ **LƯU Ý QUAN TRỌNG:**  
> Không tự ý chuyển đổi sang Java/Kotlin Native thuần, và không tự dựng server backend riêng (Node.js/Spring Boot/PHP) gây xung đột kiến trúc và phân mảnh mã nguồn giữa 5 thành viên.

---

## Cấu trúc thư mục mã nguồn (`lib/features/`)

Nhóm tổ chức mã nguồn theo kiến trúc **Feature-First**. Mỗi thành viên làm việc độc lập trong thư mục phân hệ của mình, không sửa chéo file của người khác trừ khi thông qua integration contract:

```
lib/
├── features/
│   ├── pantry/               # MOD-01: Kho thực phẩm (Nguyễn Văn Định)
│   ├── shopping/             # MOD-02: Mua sắm (Nguyễn Vĩnh Hưng)
│   ├── recipe/               # MOD-03: Công thức nấu ăn (Nguyễn Khang Hy)
│   ├── meal_plan/            # MOD-04: Kế hoạch bữa ăn (Hồ Nguyên Khởi)
│   │   ├── data/
│   │   │   ├── meal_repository.dart
│   │   │   └── models/
│   │   ├── domain/
│   │   │   ├── meal_service.dart
│   │   │   ├── reminder_service.dart
│   │   │   └── stock_deduction_service.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       └── widgets/
│   └── auth/                 # MOD-05: Tài khoản & Xác thực (Bùi Thị Quỳnh Như)
├── shared/                   # Thành phần dùng chung (theme, design tokens, formatters)
└── main.dart                 # Điểm khởi chạy ứng dụng
```

---

## Ánh xạ dữ liệu Firestore (User-Scoped)

Toàn bộ dữ liệu nghiệp vụ gắn liền với người dùng đăng nhập (`ma_tai_khoan = request.auth.uid`):

| Phân hệ | Collection Firestore | Schema tương ứng | Trách nhiệm |
|---|---|---|---|
| MOD-01 | `/users/{uid}/thuc_pham`<br>`/users/{uid}/lo_thuc_pham`<br>`/users/{uid}/bien_dong_kho` | `thuc_pham`, `lo_thuc_pham`, `bien_dong_kho` | Quản lý kho, cảnh báo HSD, ghi nhận biến động kho (`CONSUME`, `IN`, `ADJUST`) |
| MOD-02 | `/users/{uid}/danh_sach_mua`<br>`/users/{uid}/chi_tiet_mua` | `danh_sach_mua`, `chi_tiet_mua` | Danh sách mua, đồng bộ lượng thực mua vào kho |
| MOD-03 | `/cong_thuc` (hoặc `/users/{uid}/cong_thuc`) | `cong_thuc`, `nguyen_lieu_cong_thuc` | Thư viện công thức, định lượng theo khẩu phần |
| MOD-04 | `/users/{uid}/meals`<br>`/users/{uid}/meals/{mealId}/items` | `bua_an`, `mon_an_ke_hoach` | Lập lịch (chưa trừ kho), hoàn thành bữa & trừ kho FEFO nguyên tử |
| MOD-05 | `/users/{uid}` | `tai_khoan` | Firebase Auth UID, phân quyền sở hữu dữ liệu |
| Chung | `/users/{uid}/notifications` | `thong_bao` | Nhắc bữa ăn (`MEAL_REMINDER`) và cảnh báo hạn dùng (`EXPIRY`) |

---

## Hướng dẫn mở và chạy dự án trên Android Studio

1. **Cài đặt công cụ:**
   - Cài đặt Flutter SDK (bản 3.x trở lên).
   - Mở Android Studio -> vào **Plugins** -> cài **Flutter** và **Dart** -> Khởi động lại IDE.
2. **Mở dự án:**
   - Trong Android Studio: chọn **File** -> **Open** -> trỏ đến thư mục `lap_trinh_mang`.
3. **Cài đặt thư viện:**
   - Mở terminal trong Android Studio và chạy:
     ```bash
     flutter pub get
     ```
4. **Chạy ứng dụng:**
   - Bật máy ảo Android (AVD) hoặc cắm điện thoại Android (bật USB Debugging).
   - Nhấn nút **Run** (tam giác xanh) trên thanh công cụ của Android Studio.

---

## Tài liệu tham khảo trong repo
- [tien-do-mod04.md](file:///c:/Users/ADMIN/Downloads/lap_trinh_mang/tien-do-mod04.md): Tiến độ chi tiết phân hệ Kế hoạch Bữa ăn (MOD-04).
- [AGENTS.md](file:///c:/Users/ADMIN/Downloads/lap_trinh_mang/AGENTS.md): Hướng dẫn phối hợp chuẩn cho các AI Agent (Gemini, Claude, Cursor, Copilot).
- `UI_imgs/DESIGN_PREVIEW.md`: Bộ Design System và quy chuẩn giao diện Android.
- `So_do_Quan_ly_thuc_pham_5_module/`: Sơ đồ nghiệp vụ ERD, workflow HTML và `schema.sql`.
