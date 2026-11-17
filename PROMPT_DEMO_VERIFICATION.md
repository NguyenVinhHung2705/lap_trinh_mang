# PROMPT KIỂM TRA MÔI TRƯỜNG & KHẢ NĂNG CHẠY DEMO DỰ ÁN SMART FOOD LIFE

> **Mục đích:** Sử dụng prompt này để giao việc cho AI Agent (Antigravity, Cursor, Claude, Copilot, ChatGPT) thực hiện kiểm tra tự động toàn diện môi trường máy tính, cấu hình dự án và kết luận xem việc chạy demo ứng dụng Android/Flutter có khả thi ngay không, kèm theo danh sách việc cần xử lý.

---

```markdown
Bạn là một Chuyên gia DevOps & Senior Flutter QA Engineer. Hãy thực hiện một cuộc kiểm tra toàn diện (Pre-flight Audit) trên máy tính hiện tại để đánh giá khả năng chạy demo ứng dụng "Smart Food Life" (Flutter 3.x, Android, Firebase).

Thực hiện tuần tự các bước kiểm tra sau bằng các câu lệnh hệ thống (PowerShell/CMD/Bash) và đọc file mã nguồn:

---

### GIAI ĐOẠN 1: KIỂM TRA MÔI TRƯỜNG VÀ CÔNG CỤ (ENVIRONMENT & TOOLING)
1. **Kiểm tra Flutter SDK & Dart:**
   - Chạy lệnh kiểm tra `flutter --version` và `dart --version`.
   - Nếu không nhận diện được lệnh `flutter`, hãy tìm kiếm xem Flutter SDK đã được cài ở các thư mục phổ biến (ví dụ: `C:\src\flutter`, `C:\flutter`, `D:\flutter`, `%LOCALAPPDATA%`) nhưng chưa được thêm vào biến môi trường `PATH` hay chưa.
   - Chạy `flutter doctor -v` để đánh giá chi tiết tình trạng toolchain.

2. **Kiểm tra Java JDK & Android SDK:**
   - Kiểm tra phiên bản Java: `java -version`.
   - Kiểm tra sự tồn tại của Android Studio và Android SDK tại các đường dẫn mặc định (`C:\Program Files\Android\Android Studio`, `%LOCALAPPDATA%\Android\Sdk`).

3. **Kiểm tra Thiết bị chạy (Devices / Emulators):**
   - Chạy `flutter devices` để xem hiện có thiết bị Android thật nào kết nối qua USB (ADB) hoặc máy ảo (AVD) nào đang chạy hay không.
   - Chạy `flutter emulators` để liệt kê danh sách các máy ảo đã được cài đặt sẵn.

---

### GIAI ĐOẠN 2: KIỂM TRA MÃ NGUỒN VÀ NỀN TẢNG DỰ ÁN (PROJECT SCAFFOLDING)
1. **Kiểm tra thư mục nền tảng Android (`android/`):**
   - Kiểm tra xem thư mục `android/` và file `android/app/build.gradle` có tồn tại trong repo hay không.
   - Nếu CHƯA có thư mục `android/`, xác định lệnh khắc phục: `flutter create . --platforms=android` để tự động tái tạo nền tảng Android mà không ảnh hưởng code Dart.

2. **Kiểm tra Dependencies & Packages:**
   - Kiểm tra file `pubspec.yaml` và `pubspec.lock`.
   - Kiểm tra khả năng chạy `flutter pub get` để tải đầy đủ các package (`flutter_riverpod`, `cloud_firestore`, `firebase_auth`, `firebase_core`, `flutter_local_notifications`).

3. **Kiểm tra cú pháp & tính toàn vẹn của mã nguồn:**
   - Kiểm tra file [lib/main.dart](file:///c:/Users/ADMIN/Downloads/lap_trinh_mang/lib/main.dart) đã kết nối đầy đủ cả 5 module:
     - `MOD-01`: Kho thực phẩm (PantryModule)
     - `MOD-02`: Mua sắm (ShoppingModule)
     - `MOD-03`: Công thức (RecipeModule)
     - `MOD-04`: Kế hoạch bữa ăn (MealPlanModule)
     - `MOD-05`: Tài khoản & Xác thực (AuthModule)
   - Chạy `flutter analyze` để kiểm tra cảnh báo lỗi cú pháp hoặc lỗi import.

---

### GIAI ĐOẠN 3: KIỂM TRA KẾT NỐI MẠNG & CẤU HÌNH FIREBASE (CLIENT - SERVER)
1. **Kiểm tra file cấu hình Firebase Android:**
   - Kiểm tra sự tồn tại của file `android/app/google-services.json`.
   - Đánh giá khả năng hoạt động:
     - Nếu ĐÃ CÓ: App sẵn sàng kết nối trực tiếp đến Firebase Cloud thật.
     - Nếu CHƯA CÓ: Đánh giá xem ứng dụng có cơ chế chạy Fallback / Mock Data trong bộ nhớ (ví dụ: `PantryMockData`) để demo giao diện mà không bị crash app hay không.

---

### GIAI ĐOẠN 4: CHẠY KIỂM THỬ TỰ ĐỘNG (AUTOMATED TEST SUITE)
1. Chạy bộ kiểm thử tự động của dự án:
   ```bash
   flutter test
   ```
2. Ghi nhận kết quả: Bao nhiêu test cases passed (đặc biệt là các test case trừ kho FEFO nguyên tử và co giãn khẩu phần công thức của MOD-04 trong `test/features/meal_plan/meal_plan_test.dart`).

---

### GIAI ĐOẠN 5: BÁO CÁO KẾT LUẬN & ĐÁNH GIÁ TÍNH KHẢ THI (FINAL REPORT)

Hãy lập bảng tổng hợp kết quả theo mẫu sau:

| Hạng mục kiểm tra | Hiện trạng trên máy | Đánh giá (ĐẠT / CHƯA / CẢNH BÁO) | Giải pháp khắc phục |
|---|---|---|---|
| Flutter SDK & PATH | ... | ... | ... |
| Android Studio & SDK | ... | ... | ... |
| Thiết bị / Máy ảo (Device) | ... | ... | ... |
| Thư mục nền tảng `android/` | ... | ... | ... |
| Gói thư viện `pubspec` | ... | ... | ... |
| Tích hợp 5 Module (`main.dart`)| ... | ... | ... |
| Cấu hình Firebase (`google-services.json`)| ... | ... | ... |
| Kiểm thử tự động (`flutter test`)| ... | ... | ... |

**KẾT LUẬN KHẢ NĂNG CHẠY DEMO:**
- **Mức độ khả thi:** [SẴN SÀNG 100% / CẦN THIẾT LẬP 5 PHÚT / BỊ CHẶN]
- **Các lệnh cần chạy ngay:** Cung cấp chuỗi lệnh copy-paste để giải quyết tất cả các điểm CHƯA ĐẠT.
- **Kịch bản chạy demo:** Hướng dẫn 3 bước nhanh nhất để mở app và biểu diễn cho giảng viên xem.
```
