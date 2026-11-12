# Tiến độ triển khai MOD-04 (Kế hoạch Bữa ăn)

**Phụ trách:** Hồ Nguyên Khởi (`2351220090`)  
**Cập nhật lần cuối:** 2026-11-12

---

## Trạng thái tổng quan

| Bước | Hạng mục | File đã tạo | Trạng thái | Ghi chú |
|---|---|---|---|---|
| 1 | Data models (`bua_an`, `mon_an_ke_hoach`) | `lib/features/meal_plan/data/models/meal.dart`<br>`lib/features/meal_plan/data/models/meal_item.dart` | ✅ Xong (chờ chạy SDK verify) | Đủ enum, chuẩn hóa ngày local, ràng buộc XOR & `so_luong > 0` |
| 2 | Cấu hình package & Firestore CRUD | `pubspec.yaml`<br>`lib/features/meal_plan/data/meal_repository.dart` | ✅ Xong (chờ chạy SDK verify) | CRUD + Transaction guard chống trùng khung bữa & cấm sửa bữa đã hoàn thành |
| 3 | `MealCalendarScreen` (MOD-04-01) | `lib/features/meal_plan/presentation/providers/meal_calendar_provider.dart`<br>`lib/features/meal_plan/presentation/screens/meal_calendar_screen.dart` | ✅ Xong (chờ chạy SDK verify) | Lịch Tuần/Tháng read-only, nhóm theo ngày & khung bữa, badge `Đã lên lịch`/`Đã hoàn thành` |
| 4 | `MealDetailScreen` + chọn khung (MOD-04-02) | `lib/features/meal_plan/presentation/providers/meal_detail_provider.dart`<br>`lib/features/meal_plan/presentation/screens/meal_detail_screen.dart` | ✅ Xong (chờ chạy SDK verify) | Tự tìm hoặc tạo bữa `PLANNED` theo `(ngày, khung)`, xem danh sách món |
| 5 | `AddDishScreen` (MOD-04-03, MOD-04-04) | `lib/features/meal_plan/domain/meal_service.dart`<br>`lib/features/meal_plan/presentation/screens/add_dish_screen.dart` | ✅ Xong (chờ chạy SDK verify) | Thêm món theo công thức & thực phẩm ăn liền (check quyền CT, quy đổi đơn vị, không trừ kho) |
| 6 | Sửa/hủy kế hoạch (MOD-04-05) | `lib/features/meal_plan/domain/meal_service.dart`<br>`lib/features/meal_plan/presentation/screens/meal_detail_screen.dart` | ✅ Xong (chờ chạy SDK verify) | Sửa khẩu phần/lượng, bỏ món, dời ngày/khung bữa, hủy bữa chưa hoàn thành |
| 7 | `ReminderService` (MOD-04-06) | `lib/features/meal_plan/domain/reminder_service.dart`<br>`lib/features/meal_plan/presentation/widgets/reminder_bottom_sheet.dart` | ✅ Xong (chờ chạy SDK verify) | Đặt/cập nhật/hủy nhắc cục bộ + ghi `thong_bao` (`MEAL_REMINDER`), fallback in-app |
| 8 | `ConfirmConsumptionScreen` (MOD-04-07) | `lib/features/meal_plan/data/models/consumption_request.dart`<br>`lib/features/meal_plan/presentation/screens/confirm_consumption_screen.dart` | ✅ Xong (chờ chạy SDK verify) | Tính lượng dự kiến theo khẩu phần, quy đổi về đơn vị cơ sở, cho điều chỉnh lượng thực dùng (chưa trừ kho) |
| 9 | `StockDeductionService` + Dialog (MOD-04-08) | — | ⏳ Tiếp theo | Transaction trừ kho FEFO + chống lặp |
| 10 | Integration tests (`TC-08`..`TC-11`) | — | ⏳ Chờ | Kiểm thử các ca trọng tâm |

---

## Tóm tắt những gì đã làm

### Bước 1 — Models (`meal.dart`, `meal_item.dart`)
- Ánh xạ 2 bảng chính `bua_an` và `mon_an_ke_hoach` sang Dart pure models.
- Giữ ngày theo múi giờ địa phương (`YYYY-MM-DD`) và tạo `buildDeterministicId` để tránh trùng 2 bữa cùng ngày & khung.
- Ép chặt quy tắc XOR (mỗi dòng chỉ chọn công thức **hoặc** thực phẩm ăn liền) và số lượng `> 0`.

### Bước 2 — Repository & cấu hình (`pubspec.yaml`, `meal_repository.dart`)
- Khởi tạo `pubspec.yaml` cho Flutter + Firebase (`cloud_firestore`, `firebase_auth`, `flutter_riverpod`, `flutter_local_notifications`).
- Viết `MealRepository` kết nối `/users/{uid}/meals` và subcollection `items`:
  - Truy vấn/stream lịch theo khoảng ngày.
  - `getOrCreateMeal` dùng transaction + ID cố định để chống tạo trùng.
  - Thêm/sửa/xóa món, dời lịch, hủy bữa đều kiểm tra bữa chưa `COMPLETED` và **không đụng tồn kho**.

### Bước 3 — Lịch tuần/tháng (`meal_calendar_provider.dart`, `meal_calendar_screen.dart`)
- Quản lý chế độ xem Tuần/Tháng, điều hướng kỳ trước/sau, nhảy về Hôm nay.
- Stream dữ liệu read-only theo khoảng ngày địa phương và nhóm theo `ngay_an` + `khung_bua`.
- Hiển thị rõ 4 khung bữa (`Sáng`, `Trưa`, `Tối`, `Phụ`) với badge `Đã lên lịch · Chưa trừ kho` (xanh dương) và `Đã hoàn thành` (xám).

### Bước 4 — Chọn ngày/khung & chi tiết bữa (`meal_detail_provider.dart`, `meal_detail_screen.dart`)
- Tạo `MealSlotKey` + `MealDetailController` gọi `getOrCreateMeal` theo `(userId, date, slot)` để tránh tạo trùng bữa.
- Stream danh sách món `mon_an_ke_hoach` theo `mealId`.
- Giao diện cho đổi ngày/khung bữa, hiển thị trạng thái `Đã lên lịch · Chưa trừ kho`, ẩn toàn bộ nút sửa/thêm/hoàn thành khi bữa đã `COMPLETED`.

### Bước 5 — Thêm món theo công thức & thực phẩm ăn liền (`meal_service.dart`, `add_dish_screen.dart`)
- Định nghĩa contract tích hợp đọc `cong_thuc` (MOD-03) và `thuc_pham`/`don_vi` (MOD-01) kèm adapter Firestore mặc định.
- `MealService` kiểm tra bữa chưa `COMPLETED`, quyền dùng công thức, số lượng `> 0`, và tính tương thích đơn vị trước khi ghi `mon_an_ke_hoach`.
- `AddDishScreen` cho tìm và thêm món theo 2 tab (`Công thức` / `Thực phẩm ăn liền`), hiển thị rõ trạng thái chưa trừ kho.

### Bước 6 — Sửa/hủy kế hoạch chưa hoàn thành (`meal_service.dart`, `meal_detail_screen.dart`)
- Bổ sung `updateItemQuantity`, `removeItem`, `rescheduleMeal`, `cancelMeal` vào `MealService` kèm hook cập nhật/hủy nhắc nhở.
- Gắn dialog sửa định lượng, bỏ món, dời lịch bữa ăn và xác nhận hủy kế hoạch vào `MealDetailScreen` (chỉ hoạt động khi bữa ở trạng thái `PLANNED`, không đụng tồn kho).
- **Lưu ý schema mới sau khi pull branch `mod4`:** `lo_thuc_pham` bỏ cột `so_luong_ton`, `bien_dong_kho` dùng `so_luong_nhap`/`so_luong_xuat` và `loai_bien_dong = 'CONSUME'` — sẽ áp dụng chuẩn này ở Bước 9 (`StockDeductionService`).

### Bước 7 — Nhắc chuẩn bị bữa ăn (`reminder_service.dart`, `reminder_bottom_sheet.dart`)
- Tạo `ReminderService` với `LocalNotificationScheduler` (`flutter_local_notifications` + `timezone`) và đồng bộ bản ghi `MEAL_REMINDER` trên `thong_bao`.
- Nếu người dùng từ chối quyền thông báo thiết bị, vẫn lưu `thong_bao` để nhắc trong ứng dụng (`watchDueInAppReminders`).
- Tạo `ReminderBottomSheet` (bo góc `24dp`, chọn giờ nhắc mặc định theo khung bữa, bật/tắt nhắc).

### Bước 8 — Xác nhận lượng dùng thực tế (`consumption_request.dart`, `confirm_consumption_screen.dart`)
- Tạo `ConsumptionItem`, `ConsumptionRequest` và `ConsumptionEstimator` tính lượng dự kiến từ công thức (theo khẩu phần) + thực phẩm ăn liền, chuẩn hóa toàn bộ về đơn vị tồn kho cơ sở (`ma_don_vi_co_so`).
- `ConfirmConsumptionScreen` cho phép chỉnh lượng thực tế (`>= 0`) hoặc bỏ chọn nguyên liệu không dùng, bắt buộc có ít nhất 1 nguyên liệu `> 0`, và **chưa ghi vào tồn kho**.

---

## Lưu ý verify
- Máy hiện chưa có Flutter/Dart SDK nên chưa chạy được `flutter pub get`, `dart analyze`, `flutter test`.
- Đã kiểm tra tĩnh thủ công các file vừa viết trước khi sang bước tiếp theo.

