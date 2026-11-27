# Tiến độ triển khai MOD-01 (Quản lý Kho thực phẩm — Supabase + Web/Android)

**Phụ trách:** Nguyễn Văn Định (`2351220031`)  
**Cập nhật lần cuối:** 2026-11-27  
**Trạng thái:** ✅ Hoàn thành 100% (8/8 chức năng `MOD-01-01` .. `MOD-01-08` & Migrate Supabase PostgreSQL)

---

## 1. Bảng đối chiếu hoàn thành 8 chức năng theo Báo cáo (`Bao_cao_ltm.docx`)

| Mã chức năng | Yêu cầu | Mô tả triển khai | File chính | Trạng thái |
|---|---|---|---|---|
| `MOD-01-01` | `FR-01` | Nhập thực phẩm thủ công, tách lô theo hạn dùng (`TC-04`), kiểm tra số lượng `> 0` (`TC-03`), ghi biến động `IMPORT` | `add_batch_screen.dart`<br>`pantry_repository.dart` | ✅ Xong |
| `MOD-01-02` | `FR-02` | Tra cứu mã vạch EAN-13 / QR, kiểm tra định dạng mã, điền nhanh vào biểu mẫu nhập kho hoặc tìm kiếm | `barcode_scanner_dialog.dart`<br>`pantry_repository.dart` | ✅ Xong |
| `MOD-01-03` | `FR-03` | Nhận diện ảnh thực phẩm AI (Web & Android), kiểm tra định dạng/dung lượng `<= 5MB`, đề xuất kèm độ tin cậy, fallback nhập tay (`TC-12`) | `ai_image_recognition_dialog.dart` | ✅ Xong |
| `MOD-01-04` | `FR-04` | Thêm, sửa, xóa vị trí lưu trữ cá nhân (`vi_tri_luu_tru`), đồng bộ tham chiếu lô và chặn xóa vị trí đang còn lô tồn | `storage_locations_screen.dart`<br>`pantry_repository.dart` | ✅ Xong |
| `MOD-01-05` | `FR-05` | Chuyển vị trí lưu trữ giữ nguyên tồn (`TC-15`), Điều chỉnh số lượng thực tế ghi `ADJUST` cấm tồn âm (`TC-14`), Loại bỏ lô hỏng/quá hạn (`DISCARD`/`EXPIRED`) | `food_detail_screen.dart`<br>`batch_item_tile.dart` | ✅ Xong |
| `MOD-01-06` | `FR-06` | Theo dõi hạn dùng theo ngày địa phương, banner ưu tiên dùng, bộ lọc Danh mục + HSD (`Sắp hết hạn`, `Đã hết hạn`, `Sắp hết tồn`), cấu hình ngưỡng tồn tối thiểu | `pantry_home_screen.dart`<br>`pantry_providers.dart` | ✅ Xong |
| `MOD-01-07` | `FR-07` | Tương thích đồng bộ lô thực mua từ Mua sắm (`MOD-02`) vào `lo_thuc_pham` và `bien_dong_kho` | `pantry_repository.dart` | ✅ Xong |
| `MOD-01-08` | `FR-08` | Khớp 100% cơ chế trừ kho nguyên tử FEFO `complete_meal_fefo` của Kế hoạch bữa ăn (`MOD-04`) và sổ cái bất biến (`TC-16`) | `stock_movement_screen.dart`<br>`pantry_repository.dart` | ✅ Xong |

---

## 2. Cấu trúc Bảng PostgreSQL (Supabase) của MOD-01

- **`thuc_pham_global`**: `id`, `ten`, `ten_danh_muc`, `don_vi_co_so`, `ma_vach`, `hinh_anh`, `ton_kho_toi_thieu`
- **`lo_thuc_pham`**: `id` (UUID), `user_id` (Firebase UID), `thuc_pham_id`, `ten_thuc_pham`, `so_luong`, `don_vi`, `ngay_het_han`, `vi_tri`, `ghi_chu`, `created_at`
- **`bien_dong_kho`**: `id` (UUID), `user_id`, `thuc_pham_id`, `ten_thuc_pham`, `loai_bien_dong` (`IMPORT` | `CONSUME` | `ADJUST` | `EXPIRED` | `DISCARD`), `so_luong_nhap`, `so_luong_xuat`, `ghi_chu`, `created_at`
- **`vi_tri_luu_tru`**: `id` (UUID), `user_id`, `ten`, `mo_ta`
- **`food_minimum_stock`**: `(user_id, thuc_pham_id)` PK, `ton_kho_toi_thieu`

---

## 3. Kiểm thử tự động

```bash
flutter test test/features/pantry/pantry_test.dart
```
Bao phủ đầy đủ các ca kiểm thử: `TC-P01`, `TC-03`, `TC-04`, `TC-14`, `TC-15`, `FR-02`, `FR-04`, `TC-P05`.
