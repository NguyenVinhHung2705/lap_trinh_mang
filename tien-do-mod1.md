# Tiến độ triển khai MOD-01 (Quản lý Kho thực phẩm)

**Phụ trách:** Nguyễn Văn Định (`2351220031`)  
**Cập nhật lần cuối:** 2026-11-13  
**Dành cho:** AI Coding Assistants & Các thành viên nhóm (Khởi - MOD-04, Hưng - MOD-02, Hy - MOD-03, Như - MOD-05)

---

## 1. Trạng thái tổng quan

| Bước | Hạng mục | File phụ trách | Trạng thái | Ghi chú kỹ thuật |
|---|---|---|---|---|
| 1 | Data Models | `lib/features/pantry/data/models/food_item.dart`<br>`lib/features/pantry/data/models/food_batch.dart`<br>`lib/features/pantry/data/models/stock_movement.dart` | ✅ Hoàn thành 100% | Đủ enum `ExpiryStatus`, `StockMovementType`, tính toán hạn tự động |
| 2 | Firestore CRUD & FEFO Repository | `lib/features/pantry/data/pantry_repository.dart`<br>`lib/features/pantry/data/pantry_mock_data.dart` | ✅ Hoàn thành 100% | User-scoped `/users/{uid}/...`, Transaction nguyên tử `IN` / `DISCARD`, bộ nhớ in-memory fallback |
| 3 | State Management (Riverpod) | `lib/features/pantry/presentation/providers/pantry_providers.dart` | ✅ Hoàn thành 100% | Tìm kiếm thời gian thực, lọc danh mục, lọc theo trạng thái HSD |
| 4 | Màn hình Kho (`PantryHomeScreen`) | `lib/features/pantry/presentation/screens/pantry_home_screen.dart`<br>`lib/features/pantry/presentation/widgets/food_card.dart` | ✅ Hoàn thành 100% | Khớp Design System `#16A36A`, banner cảnh báo lô cận date, card bo góc 16dp |
| 5 | Chi tiết thực phẩm & Quản lý lô | `lib/features/pantry/presentation/screens/food_detail_screen.dart`<br>`lib/features/pantry/presentation/widgets/batch_item_tile.dart` | ✅ Hoàn thành 100% | Danh sách lô xếp theo thứ tự FEFO (cận date nhất trên cùng), chức năng hủy lô hỏng |
| 6 | Nhập kho (`AddBatchScreen`) | `lib/features/pantry/presentation/screens/add_batch_screen.dart` | ✅ Hoàn thành 100% | Form thêm lô mới, chọn vị trí lưu trữ, chọn HSD bằng DatePicker, tự tăng tồn tổng |
| 7 | Biến động kho (`StockMovementHistoryScreen`) | `lib/features/pantry/presentation/screens/stock_movement_screen.dart` | ✅ Hoàn thành 100% | Theo dõi lịch sử nhập xuất: `IN`, `CONSUME` (từ MOD-04), `DISCARD`, `ADJUST` |
| 8 | Unit Tests & Integration Entrypoint | `lib/features/pantry/pantry_module.dart`<br>`test/features/pantry/pantry_test.dart` | ✅ Hoàn thành 100% | 4 test cases (`TC-P01` .. `TC-P04`) kiểm tra logic HSD, nhập lô, trừ kho |

---

## 2. HỢP ĐỒNG TÍCH HỢP CHO CÁC MODULE KHÁC (INTEGRATION CONTRACTS)

### 2.1. Dành cho MOD-04 (Kế hoạch bữa ăn — Hồ Nguyên Khởi)
- **Cơ chế trừ kho:** MOD-04 đọc các lô thực phẩm từ `/users/{uid}/lo_thuc_pham` và trừ theo nguyên tắc **FEFO** (First-Expiry-First-Out, lô hết hạn sớm nhất trừ trước).
- **Cột số lượng khả dụng trên mỗi lô:** Trường `so_luong_ton` (hoặc `so_luong`).
- **Ghi biến động kho:** Khi hoàn thành bữa ăn, MOD-04 ghi vào `/users/{uid}/bien_dong_kho`:
  - `loai_bien_dong = 'CONSUME'`
  - `so_luong_nhap = 0.0`
  - `so_luong_xuat = deducted_amount`
  - `ma_lo = batch_id`
  - `ghi_chu = 'Tiêu thụ cho bữa ăn ...'`
- **Nguyên tử (All-or-nothing):** Nếu thiếu bất kỳ nguyên liệu nào trong kho, giao dịch phải hủy (abort).

### 2.2. Dành cho MOD-02 (Quản lý Mua sắm — Nguyễn Vĩnh Hưng)
- Khi người dùng tick hoàn tất danh sách mua sắm, MOD-02 gọi hàm `addFoodBatch` của MOD-01 để đồng bộ số lượng thực mua vào kho:
  - Tự động cộng dồn vào `so_luong_ton` của `thuc_pham`.
  - Sinh một bản ghi mới trong `lo_thuc_pham`.
  - Ghi bản ghi `bien_dong_kho` với `loai_bien_dong = 'IN'`.

### 2.3. Dành cho MOD-03 (Công thức nấu ăn — Nguyễn Khang Hy)
- MOD-03 khi kiểm tra nguyên liệu cho món ăn sẽ đối chiếu `ma_thuc_pham` với collection `/users/{uid}/thuc_pham` để hiển thị trạng thái `Đủ X/Y nguyên liệu`.

---

## 3. Cấu trúc Firestore của MOD-01

Tất cả đều nằm dưới user scope: `/users/{uid}/...`

```
/users/{uid}/thuc_pham/{foodId}
  ├── ten_thuc_pham: string
  ├── ten_danh_muc: string
  ├── don_vi_co_so: string (kg, g, quả, hộp...)
  ├── nguong_sap_het: number (mặc định 1.0)
  ├── so_luong_ton: number
  └── han_su_dung_gan_nhat: ISO string

/users/{uid}/lo_thuc_pham/{batchId}
  ├── ma_thuc_pham: string
  ├── ten_thuc_pham: string
  ├── ten_vi_tri: string (Ngăn mát, Ngăn đông, Tủ gia vị...)
  ├── ngay_nhap: YYYY-MM-DD
  ├── han_su_dung: YYYY-MM-DD
  ├── so_luong: number
  ├── so_luong_ton: number (phục vụ FEFO MOD-04)
  └── don_vi: string

/users/{uid}/bien_dong_kho/{movementId}
  ├── ma_lo: string
  ├── ma_chi_tiet_mua: string?
  ├── ma_mon_an: string?
  ├── loai_bien_dong: string ('IN' | 'CONSUME' | 'DISCARD' | 'ADJUST')
  ├── so_luong_nhap: number
  ├── so_luong_xuat: number
  ├── thoi_diem: ISO string
  └── ghi_chu: string?
```

---

## 4. Cách chạy và kiểm thử độc lập

```bash
# Chạy Unit Tests của MOD-01
flutter test test/features/pantry/pantry_test.dart

# Chạy ứng dụng
flutter run
```
Màn hình mặc định của ứng dụng đã được cắm sẵn tại Tab thứ 2 (**Kho (Định)**) trên thanh Bottom Navigation.
