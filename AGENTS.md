# INSTRUCTIONS FOR AI AGENTS & CODING ASSISTANTS

> **Target Audience:** Any AI coding assistant (Gemini, Claude, Cursor, Copilot, ChatGPT, Antigravity) working in this repository for any of the 5 team members.
> **Project:** Smart Food Life (Personal food management Android application)
> **Branch Convention:** Each team member develops on their feature branch (e.g. `mod4` for MOD-04).

---

## 1. ⚠️ HARD TECHNOLOGY MANDATES (DO NOT VIOLATE)

1. **Language & Framework:**
   - **STRICTLY USE FLUTTER 3.x (DART)**.
   - **DO NOT** create Java or Kotlin native Android files (`MainActivity.java`, XML layouts, etc.).
   - **DO NOT** create backend services in Python, Node.js, Spring Boot, or PHP.
2. **Target Platform:**
   - Android mobile app (opened and built in **Android Studio** with Flutter & Dart plugins).
3. **Backend & Persistence:**
   - **Firebase Authentication** for user identity (`request.auth.uid`).
   - **Cloud Firestore** for data storage. All user-specific collections MUST be scoped under:
     `/users/{uid}/{collection_name}/{document_id}`
   - **Local Notifications & FCM** for device alerts.
4. **State Management:**
   - Use **Riverpod** (`flutter_riverpod`) for state and dependency injection.

---

## 2. MODULAR ARCHITECTURE (FEATURE-FIRST)

Each team member is assigned exactly ONE module. Place all files within your dedicated feature folder:

```
lib/features/
├── pantry/       # MOD-01: Inventory, pantry batches, expiry alerts (Nguyễn Văn Định)
├── shopping/     # MOD-02: Shopping lists, sync purchases to inventory (Nguyễn Vĩnh Hưng)
├── recipe/       # MOD-03: Recipes, ingredient scaling by servings (Nguyễn Khang Hy)
├── meal_plan/    # MOD-04: Meal calendar, plans, atomic FEFO deduction (Hồ Nguyên Khởi) [DONE]
└── auth/         # MOD-05: User account, profile, auth state (Bùi Thị Quỳnh Như)
```

---

## 3. INTEGRATION CONTRACTS ACROSS MODULES

### With MOD-04 (Meal Plan — Hồ Nguyên Khởi):
- **MOD-03 (Recipe):** MOD-04 reads recipes from `cong_thuc` and ingredients from `nguyen_lieu_cong_thuc`. When recipe scaling changes, use `so_luong * servings / khau_phan`.
- **MOD-01 (Pantry):**
  - When a meal is completed, MOD-04 executes an **atomic Firestore transaction** that deducts stock using **FEFO** (First-Expiry-First-Out, earliest expiry date deducted first).
  - All-or-nothing: If any ingredient is insufficient, the transaction aborts with zero deductions.
  - Stock movement is logged in `bien_dong_kho` with:
    `loai_bien_dong = 'CONSUME'`, `so_luong_nhap = 0`, `so_luong_xuat = deducted_amount`.
- **MOD-02 (Shopping):** Only bought quantities (`so_luong_da_mua`) are imported to pantry upon synchronization; planned dishes never auto-buy without user confirmation.

---

## 4. DESIGN TOKENS (from `UI_imgs/DESIGN_PREVIEW.md`)

Use these standard colors and design tokens across all UI widgets:

```dart
static const Color primary = Color(0xFF16A36A);         // Brand Emerald
static const Color primaryDark = Color(0xFF087F55);
static const Color primaryTint = Color(0xFFE7F6EF);
static const Color background = Color(0xFFF7F9F7);      // App background
static const Color surface = Color(0xFFFFFFFF);         // Card / Sheet surface
static const Color border = Color(0xFFE5EBE6);          // Divider / Border
static const Color textPrimary = Color(0xFF202B26);
static const Color textSecondary = Color(0xFF77847C);

// Status colors
static const Color statusSuccess = Color(0xFF22C55E);   // Còn hạn
static const Color statusWarning = Color(0xFFF59E0B);   // Sắp hết hạn / sắp hết
static const Color statusDanger = Color(0xFFEF4444);    // Đã hết hạn / Lỗi
static const Color statusPlanned = Color(0xFF2563EB);   // Đã lên lịch · Chưa trừ kho
```

- Typography: Font **Roboto**
- Corner radii: `8dp` (badge), `12dp` (button/input), `16dp` (card), `24dp` (bottom sheet/dialog)

---

## 5. GIT & COLLABORATION RULES

- Keep commits scoped and clean: `feat(mod-XX): message`.
- **NEVER** push private/local files (`ke-hoach-ho-nguyen-khoi.md`, `agent-brief-mod04.md`).
- Ensure all business invariants (no stock deduction upon planning, FEFO upon completion, atomic writes) are preserved in automated tests.
