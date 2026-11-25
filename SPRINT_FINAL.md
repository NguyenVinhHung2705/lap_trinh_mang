# KẾ HOẠCH SPRINT CUỐI — Smart Food Life
# Migrate NoSQL → SQL + Deploy Web
# Deadline: 2 tuần | Cập nhật: 2026-11-25

> **ĐỌC FILE NÀY TRƯỚC KHI LÀM BẤT CỨ ĐIỀU GÌ**
> File này là nguồn sự thật duy nhất cho toàn nhóm.
> Mỗi agent/thành viên chỉ làm đúng phần được giao.

---

## 🎯 MỤC TIÊU CUỐI KỲ

Thầy yêu cầu 2 điều:
1. **Không dùng NoSQL** → Thay Firestore bằng **Supabase (PostgreSQL)**
2. **Link cloud chạy được** → Deploy **Flutter Web lên Vercel**

```
Trước:  Firebase Firestore (NoSQL) + Android APK
Sau:    Supabase PostgreSQL (SQL)  + Flutter Web tại https://smart-food-life.vercel.app
```

---

## 🏗️ KIẾN TRÚC SAU KHI THAY ĐỔI

```
┌─────────────────────────────────────────────────────┐
│              Flutter Web (Vercel)                   │
│         https://smart-food-life.vercel.app          │
│  ┌──────────────────────────────────────────────┐   │
│  │  Presentation Layer (KHÔNG ĐỔI GÌ)          │   │
│  │  Screens + Riverpod Providers                │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Domain Layer (KHÔNG ĐỔI GÌ)                │   │
│  │  Services + Models + Mock Data               │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Data Layer (CHỈ PHẦN NÀY THAY ĐỔI)        │   │
│  │  Repository: Firestore → Supabase Client     │   │
│  └──────────────────────────────────────────────┘   │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
    Firebase Auth          Supabase PostgreSQL
  (GIỮ NGUYÊN ✅)          (THAY FIRESTORE ✅)
```

---

## ⚠️ QUY TẮC CHUNG CHO MỌI AGENT

1. **Chỉ sửa trong feature folder của mình** (`lib/features/<module>/`)
2. **KHÔNG đổi**: Screens, Providers, Models, Domain Services, Mock Data
3. **CHỈ ĐỔI**: Repository files (xóa Firestore calls, thêm Supabase calls)
4. **Firebase Auth GIỮ NGUYÊN** — không phải NoSQL, được phép dùng
5. Commit theo format: `feat(mod-XX): migrate repository to Supabase`
6. Push lên branch của mình, **không push lên main**

---

## 📦 BƯỚC 0 — SETUP CHUNG (Khởi làm, còn lại chờ)

> **Người thực hiện: Hồ Nguyên Khởi (MOD-04)**
> **Deadline: Ngày 1–2**

### 0A. Tạo Supabase Project

1. Vào https://supabase.com → đăng ký/đăng nhập
2. New Project → tên: `smart-food-life` → region: Southeast Asia
3. Lưu lại:
   - `Project URL`: `https://xxxx.supabase.co`
   - `anon public key`: `eyJxxx...`
4. Share 2 giá trị trên với cả nhóm qua nhóm chat

### 0B. Chạy SQL Schema (copy paste vào Supabase SQL Editor)

```sql
-- ══════════════════════════════════════
-- BẢNG THAM CHIẾU DÙNG CHUNG
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS don_vi (
  id TEXT PRIMARY KEY,
  ten TEXT NOT NULL,
  ky_hieu TEXT,
  nhom_do_luong TEXT
);

CREATE TABLE IF NOT EXISTS thuc_pham_global (
  id TEXT PRIMARY KEY,
  ten TEXT NOT NULL,
  ten_danh_muc TEXT,
  don_vi_co_so TEXT,
  ma_vach TEXT,
  hinh_anh TEXT,
  ton_kho_toi_thieu NUMERIC DEFAULT 0
);

-- ══════════════════════════════════════
-- MOD-01: KHO THỰC PHẨM
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS lo_thuc_pham (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,          -- Firebase Auth UID
  thuc_pham_id TEXT NOT NULL,
  ten_thuc_pham TEXT NOT NULL,
  so_luong NUMERIC NOT NULL DEFAULT 0,
  don_vi TEXT,
  ngay_het_han DATE,
  vi_tri TEXT,
  ghi_chu TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bien_dong_kho (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  thuc_pham_id TEXT NOT NULL,
  ten_thuc_pham TEXT,
  loai_bien_dong TEXT CHECK (loai_bien_dong IN ('IMPORT','CONSUME','ADJUST','EXPIRED','DISCARD')),
  so_luong_nhap NUMERIC DEFAULT 0,
  so_luong_xuat NUMERIC DEFAULT 0,
  ghi_chu TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vi_tri_luu_tru (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  ten TEXT NOT NULL,
  mo_ta TEXT
);

CREATE TABLE IF NOT EXISTS food_minimum_stock (
  user_id TEXT NOT NULL,
  thuc_pham_id TEXT NOT NULL,
  ton_kho_toi_thieu NUMERIC DEFAULT 0,
  PRIMARY KEY (user_id, thuc_pham_id)
);

-- ══════════════════════════════════════
-- MOD-02: MUA SẮM
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS danh_sach_mua (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  ten TEXT NOT NULL,
  ghi_chu TEXT,
  trang_thai TEXT DEFAULT 'OPEN',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chi_tiet_mua (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  danh_sach_id UUID REFERENCES danh_sach_mua(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  thuc_pham_id TEXT,
  ten_thuc_pham TEXT NOT NULL,
  so_luong_can NUMERIC DEFAULT 1,
  so_luong_da_mua NUMERIC DEFAULT 0,
  don_vi TEXT,
  da_mua BOOLEAN DEFAULT FALSE,
  ghi_chu TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════
-- MOD-03: CÔNG THỨC NẤU ĂN
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS cong_thuc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ma_tac_gia TEXT,                -- Firebase Auth UID hoặc NULL (hệ thống)
  ten TEXT NOT NULL,
  mo_ta TEXT,
  hinh_anh TEXT,
  khau_phan INTEGER DEFAULT 1,
  thoi_gian_nau INTEGER,          -- phút
  loai TEXT DEFAULT 'USER' CHECK (loai IN ('USER','SYSTEM')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS nguyen_lieu_cong_thuc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cong_thuc_id UUID REFERENCES cong_thuc(id) ON DELETE CASCADE,
  thuc_pham_id TEXT,
  ten_thuc_pham TEXT NOT NULL,
  don_vi_id TEXT,
  ky_hieu_don_vi TEXT,
  so_luong_co_so NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS cong_thuc_da_luu (
  user_id TEXT NOT NULL,
  cong_thuc_id UUID REFERENCES cong_thuc(id) ON DELETE CASCADE,
  saved_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, cong_thuc_id)
);

-- ══════════════════════════════════════
-- MOD-04: KẾ HOẠCH BỮA ĂN
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS meals (
  id TEXT PRIMARY KEY,            -- deterministic ID: userId_date_slot
  user_id TEXT NOT NULL,
  ngay_an DATE NOT NULL,
  buoi TEXT NOT NULL CHECK (buoi IN ('BREAKFAST','LUNCH','DINNER','SNACK')),
  trang_thai TEXT DEFAULT 'PLANNED' CHECK (trang_thai IN ('PLANNED','COMPLETED','CANCELLED')),
  gio_nhac TIMESTAMPTZ,
  hoan_thanh_luc TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_items (
  id TEXT PRIMARY KEY,
  meal_id TEXT REFERENCES meals(id) ON DELETE CASCADE,
  loai TEXT CHECK (loai IN ('RECIPE','FOOD')),
  tham_chieu_id TEXT,
  ten TEXT NOT NULL,
  so_luong NUMERIC DEFAULT 1,
  don_vi_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 0C. Thêm Supabase vào pubspec.yaml

```yaml
dependencies:
  # Giữ nguyên:
  flutter:
    sdk: flutter
  firebase_auth: ^5.3.1        # GIỮ — không phải NoSQL
  firebase_core: ^3.15.2       # GIỮ — cần cho Auth
  flutter_local_notifications: ^17.2.3
  flutter_riverpod: ^2.5.1
  image_picker: ^1.1.2
  timezone: ^0.9.4

  # THÊM MỚI:
  supabase_flutter: ^2.5.0

  # XÓA:
  # cloud_firestore: ^5.4.4   ← XÓA dòng này
  # firebase_storage: ^12.3.2 ← XÓA dòng này
```

### 0D. Cập nhật main.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // THÊM:
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT.supabase.co',   // ← điền URL thật
    anonKey: 'YOUR_ANON_KEY',                  // ← điền key thật
  );

  runApp(const ProviderScope(child: SmartFoodLifeApp()));
}
```

### 0E. Bật Flutter Web

```powershell
flutter create --platforms=web .
flutter pub get
flutter run -d chrome   # test thử trên browser
```

---

## 👤 MOD-01 — Nguyễn Văn Định (Pantry/Kho)

> **File cần sửa:** `lib/features/pantry/data/pantry_repository.dart`  
> **Chỉ sửa phần này, không đụng file khác**

### Cách dùng Supabase thay Firestore

```dart
// Lấy client
final _db = Supabase.instance.client;

// THAY: _firestore.collection('users').doc(uid).collection('lo_thuc_pham').add(data)
// BẰNG:
await _db.from('lo_thuc_pham').insert({...data, 'user_id': userId});

// THAY: stream từ Firestore
// BẰNG: polling + StreamController hoặc dùng Supabase Realtime
_db.from('lo_thuc_pham')
    .stream(primaryKey: ['id'])
    .eq('user_id', userId)
    .map((rows) => rows.map(FoodBatch.fromMap).toList())
```

### Các method cần migrate

| Method | Firestore | Supabase |
|--------|-----------|----------|
| `watchFoodItems` | `.snapshots()` | `.stream(primaryKey:['id']).eq('user_id',uid)` |
| `getFoodItem` | `.doc(id).get()` | `.from('thuc_pham_global').select().eq('id',id).maybeSingle()` |
| `watchBatchesForFood` | collection query | `.stream(...).eq('thuc_pham_id', foodId).eq('user_id',uid)` |
| `addFoodBatch` | `.add(data)` | `.from('lo_thuc_pham').insert({...data,'user_id':uid})` |
| `consumeBatch` | transaction | `rpc('consume_batch', params: {...})` hoặc `.update()` |
| `watchStockMovements` | `.snapshots()` | `.stream(...).eq('user_id',uid)` |
| `addStorageLocation` | `.add()` | `.from('vi_tri_luu_tru').insert(...)` |

---

## 👤 MOD-02 — Nguyễn Vĩnh Hưng (Shopping/Mua sắm)

> **File cần sửa:** `lib/features/shopping/data/shopping_repository.dart`

### Các method cần migrate

| Method | Supabase |
|--------|----------|
| `createShoppingList` | `.from('danh_sach_mua').insert({...,'user_id':uid}).select().single()` |
| `getShoppingLists` | `.from('danh_sach_mua').select().eq('user_id',uid)` |
| `watchShoppingLists` | `.from('danh_sach_mua').stream(...).eq('user_id',uid)` |
| `updateShoppingList` | `.from('danh_sach_mua').update(data).eq('id',id)` |
| `deleteShoppingList` | `.from('danh_sach_mua').delete().eq('id',id)` |
| `addItem` | `.from('chi_tiet_mua').insert({...,'user_id':uid}).select().single()` |
| `getItems` | `.from('chi_tiet_mua').select().eq('danh_sach_id',listId)` |
| `watchItems` | `.from('chi_tiet_mua').stream(...).eq('danh_sach_id',listId)` |
| `updateItem` | `.from('chi_tiet_mua').update(data).eq('id',id)` |
| `removeItem` | `.from('chi_tiet_mua').delete().eq('id',id)` |
| `setItemBoughtStatus` | `.from('chi_tiet_mua').update({'da_mua':bought}).eq('id',id)` |

---

## 👤 MOD-03 — Nguyễn Khang Hy (Recipe/Công thức)

> **File cần sửa:** `lib/features/recipe/data/recipe_repository.dart`

### Các method cần migrate

| Method | Supabase |
|--------|----------|
| `getAccessibleRecipes` | `.from('cong_thuc').select().or('ma_tac_gia.eq.${uid},loai.eq.SYSTEM')` |
| `watchAccessibleRecipes` | `.from('cong_thuc').stream(...)` |
| `getRecipeById` | `.from('cong_thuc').select().eq('id',id).maybeSingle()` |
| `getRecipeIngredients` | `.from('nguyen_lieu_cong_thuc').select().eq('cong_thuc_id',id)` |
| `createRecipe` | `.from('cong_thuc').insert(data).select().single()` |
| `updateRecipe` | `.from('cong_thuc').update(data).eq('id',id)` |
| `deleteRecipe` | `.from('cong_thuc').delete().eq('id',id)` |
| `toggleSaveRecipe` | upsert/delete `.from('cong_thuc_da_luu')` |
| `getSavedRecipeIds` | `.from('cong_thuc_da_luu').select('cong_thuc_id').eq('user_id',uid)` |

---

## 👤 MOD-04 — Hồ Nguyên Khởi (Meal Plan/Bữa ăn)

> **File cần sửa:** `lib/features/meal_plan/data/meal_repository.dart`  
> **Ngoài ra:** `meal_service.dart` (xóa import cloud_firestore)

### Các method cần migrate

| Method | Supabase |
|--------|----------|
| `getMealsForDateRange` | `.from('meals').select().eq('user_id',uid).gte('ngay_an',start).lte('ngay_an',end)` |
| `watchMealsForDateRange` | `.from('meals').stream(...).eq('user_id',uid)` |
| `getOrCreateMeal` | upsert: `.from('meals').upsert(data, onConflict:'id').select().single()` |
| `addMealItem` | `.from('meal_items').insert(data).select().single()` |
| `watchMealItems` | `.from('meal_items').stream(...).eq('meal_id',mealId)` |
| `updateMealItemQuantity` | `.from('meal_items').update({'so_luong':q}).eq('id',id)` |
| `removeMealItem` | `.from('meal_items').delete().eq('id',id)` |
| `cancelMeal` | `.from('meals').update({'trang_thai':'CANCELLED'}).eq('id',id)` |
| `markMealCompleted` | `.from('meals').update({'trang_thai':'COMPLETED','hoan_thanh_luc':now}).eq('id',id)` |
| `updateMealReminder` | `.from('meals').update({'gio_nhac':time}).eq('id',id)` |

### Lưu ý quan trọng cho MOD-04
- `getOrCreateMeal` dùng **upsert** thay vì transaction:
```dart
await _db.from('meals').upsert(
  newMeal.toMap(),
  onConflict: 'id',
  ignoreDuplicates: false,
).select().single();
```
- Giữ nguyên toàn bộ **fallback in-memory** (mock data) — chỉ thay Firestore calls

---

## 👤 MOD-05 — Bùi Thị Quỳnh Như (Auth)

> **File cần sửa:** `lib/features/auth/data/auth_repository.dart`  
> **Firebase Auth KHÔNG ĐỔI** — chỉ thay phần lưu UserProfile vào Firestore

### Vấn đề cụ thể
Hiện tại profile lưu vào Firestore. Cần tạo bảng và chuyển sang Supabase:

```sql
-- Thêm vào schema (Như chạy lệnh này):
CREATE TABLE IF NOT EXISTS user_profiles (
  uid TEXT PRIMARY KEY,           -- Firebase Auth UID
  display_name TEXT,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

```dart
// THAY: lưu profile vào Firestore
// BẰNG:
await _db.from('user_profiles').upsert({
  'uid': uid,
  'display_name': displayName,
  'email': email,
}, onConflict: 'uid');

// watchProfile:
_db.from('user_profiles').stream(primaryKey:['uid'])
    .eq('uid', uid)
    .map((rows) => rows.isEmpty ? null : UserProfile.fromMap(rows.first))
```

---

## 🌐 DEPLOY WEB (Hưng + Khởi phối hợp)

> **Deadline: Tuần 2**

### Bước 1 — Xử lý plugin không hỗ trợ web

Thêm vào `pubspec.yaml` (web-compatible alternatives):
```yaml
  # flutter_local_notifications không chạy trên web
  # → dùng conditional import:
  flutter_local_notifications: ^17.2.3
```

Trong code, bọc notification calls bằng:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (!kIsWeb) {
  // flutter_local_notifications chỉ chạy trên mobile
  await notificationService.schedule(...);
}
```

### Bước 2 — Build web

```powershell
flutter build web --release --web-renderer canvaskit
```

### Bước 3 — Deploy lên Vercel (Hưng làm)

```bash
# Cài Vercel CLI
npm install -g vercel

# Trong thư mục build/web
cd build/web
vercel deploy --prod

# Hoặc dùng GitHub Integration:
# vercel.com → Import Project → chọn repo → Root Directory: build/web
```

**Kết quả:** `https://smart-food-life.vercel.app` (link gửi thầy)

---

## 📋 CHECKLIST TỔNG (cập nhật khi done)

### Tuần 1
- [ ] **Khởi**: Tạo Supabase project + chạy schema SQL
- [ ] **Khởi**: Cập nhật `pubspec.yaml` + `main.dart` + push lên `main`
- [ ] **Khởi**: Bật Flutter Web (`flutter create --platforms=web .`)
- [ ] **Khởi**: Migrate `meal_repository.dart`
- [ ] **Định**: Migrate `pantry_repository.dart`
- [ ] **Hưng**: Migrate `shopping_repository.dart`
- [ ] **Hy**: Migrate `recipe_repository.dart`
- [ ] **Như**: Migrate `auth_repository.dart` + tạo bảng `user_profiles`

### Tuần 2
- [ ] **Tất cả**: Test module mình trên web (`flutter run -d chrome`)
- [ ] **Khởi/Như**: Fix các plugin không hỗ trợ web
- [ ] **Hưng**: Deploy lên Vercel
- [ ] **Khởi**: Merge tất cả branch vào `main`
- [ ] **Như**: Cập nhật báo cáo (thêm schema SQL, link Supabase, link Vercel)
- [ ] **Tất cả**: Demo cuối thầy: `https://smart-food-life.vercel.app`

---

## 🔧 TEMPLATE CODE CHUẨN

Mỗi repository sẽ có cấu trúc tương tự:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
// XÓA: import 'package:cloud_firestore/cloud_firestore.dart';

class XxxRepository {
  // THAY:
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // BẰNG:
  final _db = Supabase.instance.client;

  // Helper lấy userId từ Firebase Auth (KHÔNG ĐỔI)
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Mọi query đều filter theo user_id để bảo mật:
  // .eq('user_id', userId)
}
```

---

## 📞 LIÊN HỆ KHI GẶP VẤN ĐỀ

- Supabase URL/key: hỏi **Khởi**
- Vấn đề merge conflict: hỏi **Khởi**
- Vấn đề deploy Vercel: hỏi **Hưng**
- Vấn đề schema SQL: xem lại Bước 0B hoặc hỏi **Khởi**

---

*File này được tạo bởi AI Agent của Khởi (MOD-04) — 2026-11-25*
*Cập nhật lần cuối: 2026-11-25*
