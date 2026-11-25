# 🧪 Maestro UI Test Flows — Smart Food Life

## Cài đặt

```powershell
# Windows — cài Maestro CLI
iwr get.maestro.mobile.dev -useb | iex

# Khởi động emulator Pixel 5
flutter emulators --launch Pixel_5

# Build và cài app lên emulator
flutter run --debug
```

---

## Chạy test

```powershell
# Chạy TẤT CẢ flows (theo thứ tự số)
maestro test .maestro/flows/

# Chạy 1 flow cụ thể
maestro test .maestro/flows/22_smoke_test_navigation.yaml

# Chạy và mở Maestro Studio (UI trực quan)
maestro studio
```

---

## Danh sách flows

| File | Module | Test Case | Mô tả |
|------|--------|-----------|-------|
| `00_helpers.yaml` | — | HELPER | Đăng nhập local nhanh (dùng lại trong các flow) |
| `01_auth_local_login.yaml` | MOD-05 | TC-AUTH-01 | Đăng nhập bằng tài khoản Local |
| `02_auth_validation.yaml` | MOD-05 | TC-AUTH-02 | Validation form đăng nhập |
| `03_pantry_view.yaml` | MOD-01 | TC-PANTRY-01 | Xem kho thực phẩm |
| `04_pantry_add_batch.yaml` | MOD-01 | TC-PANTRY-02 | Nhập kho thực phẩm mới |
| `05_shopping_create_list.yaml` | MOD-02 | TC-SHOP-01 | Tạo danh sách mua sắm |
| `06_shopping_delete_list.yaml` | MOD-02 | TC-SHOP-02 | Xóa danh sách mua sắm |
| `07_recipe_list.yaml` | MOD-03 | TC-RECIPE-01 | Xem & tìm kiếm công thức |
| `08_recipe_create.yaml` | MOD-03 | TC-RECIPE-02 | Tạo công thức mới |
| `09_meal_view_calendar.yaml` | MOD-04 | TC-MEAL-01 | Xem lịch & mở chi tiết bữa |
| `10_meal_add_dish_recipe.yaml` | MOD-04 | TC-MEAL-02 | Thêm món từ công thức |
| `11_meal_add_dish_food.yaml` | MOD-04 | TC-MEAL-03 | Thêm thực phẩm đơn lẻ |
| `12_meal_reschedule.yaml` | MOD-04 | TC-MEAL-04 | Dời lịch bữa ăn |
| `13_meal_set_reminder.yaml` | MOD-04 | TC-MEAL-05 | Đặt nhắc nhở |
| `14_meal_cancel.yaml` | MOD-04 | TC-MEAL-06 | Hủy kế hoạch bữa ăn |
| `15_meal_complete_deduct_stock.yaml` | MOD-04 | TC-MEAL-07 | ⭐ Hoàn thành + trừ kho FEFO |
| `16_meal_remove_item.yaml` | MOD-04 | TC-MEAL-08 | Bỏ món khỏi bữa |
| `17_meal_calendar_navigation.yaml` | MOD-04 | TC-MEAL-09 | Điều hướng lịch tuần |
| `18_meal_edit_quantity.yaml` | MOD-04 | TC-MEAL-10 | Sửa định lượng món |
| `19_profile_view.yaml` | MOD-05 | TC-PROFILE-01 | Xem hồ sơ cá nhân |
| `20_e2e_full_meal_flow.yaml` | E2E | TC-E2E-01 | Lên lịch → Thêm món → Hoàn thành |
| `21_e2e_shopping_to_meal.yaml` | E2E | TC-E2E-02 | Mua sắm → Nhập kho → Lên lịch |
| `22_smoke_test_navigation.yaml` | SMOKE | TC-REGRESSION-01 | ⭐ Smoke test toàn bộ navigation |

---

## Tips

> **Chạy smoke test trước demo báo cáo:**
> ```powershell
> maestro test .maestro/flows/22_smoke_test_navigation.yaml
> ```

> **Nếu flow thất bại vì text không khớp:**
> Mở `maestro studio` để xem screen hierarchy thực tế và cập nhật lại text selector.

> **Flows có phụ thuộc nhau (runFlow):**
> Các flow từ `10_` trở đi dùng `runFlow` → phải chạy đủ điều kiện tiên quyết.
> Khi chạy riêng lẻ, hãy chạy từ flow `09_` hoặc `00_helpers.yaml` trước.
