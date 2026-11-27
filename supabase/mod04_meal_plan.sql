-- ════════════════════════════════════════════════════════════════════
-- MOD-04 · Kế hoạch bữa ăn — Supabase (PostgreSQL)
-- Chạy SAU phần schema chung trong SPRINT_FINAL.md (Bước 0B).
-- Supabase Dashboard → SQL Editor → New query → dán toàn bộ → Run.
-- File idempotent: chạy lại nhiều lần không lỗi.
-- ════════════════════════════════════════════════════════════════════

-- 1. Ràng buộc nghiệp vụ cho bảng meals / meal_items -----------------
CREATE UNIQUE INDEX IF NOT EXISTS meals_user_date_slot_uq
  ON meals (user_id, ngay_an, buoi);           -- UNIQUE(ma_tai_khoan, ngay_an, khung_bua)
CREATE INDEX IF NOT EXISTS meals_user_date_idx ON meals (user_id, ngay_an);
CREATE INDEX IF NOT EXISTS meal_items_meal_idx ON meal_items (meal_id);

DO $$ BEGIN
  ALTER TABLE meal_items ADD CONSTRAINT meal_items_so_luong_pos CHECK (so_luong > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Bảng thông báo nhắc bữa ăn (in-app reminder) ------------------
CREATE TABLE IF NOT EXISTS thong_bao (
  id TEXT PRIMARY KEY,                -- 'meal_reminder_{userId}_{mealId}'
  user_id TEXT NOT NULL,
  meal_id TEXT,
  loai TEXT NOT NULL DEFAULT 'MEAL_REMINDER',
  noi_dung TEXT NOT NULL,
  thoi_diem_gui TIMESTAMPTZ NOT NULL,
  da_doc BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS thong_bao_user_idx ON thong_bao (user_id, loai);

-- 3. Hoàn thành bữa ăn + trừ kho FEFO NGUYÊN TỬ ---------------------
-- Một hàm PL/pgSQL chạy trong MỘT transaction: RAISE EXCEPTION ở bất kỳ
-- bước nào → PostgreSQL rollback toàn bộ (all-or-nothing, TC-09).
--
-- p_items: [{"food_id":"..","food_name":"..","meal_item_id":"..","qty":1.5}, ...]
CREATE OR REPLACE FUNCTION complete_meal_fefo(
  p_user_id TEXT,
  p_meal_id TEXT,
  p_items   JSONB,
  p_today   DATE DEFAULT CURRENT_DATE
) RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_status    TEXT;
  v_item      JSONB;
  v_food_id   TEXT;
  v_food_name TEXT;
  v_need      NUMERIC;
  v_available NUMERIC;
  v_take      NUMERIC;
  v_batch     RECORD;
  v_deducted  INT := 0;
BEGIN
  -- (a) Khóa dòng bữa ăn → chống hoàn thành trùng từ 2 thiết bị
  SELECT trang_thai INTO v_status
    FROM meals WHERE id = p_meal_id AND user_id = p_user_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'MEAL_NOT_FOUND';
  END IF;
  IF v_status = 'COMPLETED' THEN               -- Idempotent (TC-10)
    RETURN jsonb_build_object('status', 'ALREADY_COMPLETED', 'deducted_batches', 0);
  END IF;
  IF v_status = 'CANCELLED' THEN
    RAISE EXCEPTION 'MEAL_CANCELLED';
  END IF;

  -- (b) Kiểm tra đủ hàng cho TẤT CẢ nguyên liệu trước khi trừ (TC-09)
  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) LOOP
    v_food_id := v_item->>'food_id';
    v_need    := (v_item->>'qty')::NUMERIC;
    CONTINUE WHEN v_need IS NULL OR v_need <= 0;

    PERFORM 1 FROM lo_thuc_pham
      WHERE user_id = p_user_id AND thuc_pham_id = v_food_id
        AND so_luong > 0
        AND (ngay_het_han IS NULL OR ngay_het_han >= p_today)
      FOR UPDATE;                               -- khóa các lô liên quan

    SELECT COALESCE(SUM(so_luong), 0) INTO v_available
      FROM lo_thuc_pham
      WHERE user_id = p_user_id AND thuc_pham_id = v_food_id
        AND so_luong > 0
        AND (ngay_het_han IS NULL OR ngay_het_han >= p_today);

    IF v_available < v_need THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK: % (can %, con %)',
        COALESCE(v_item->>'food_name', v_food_id), v_need, v_available;
    END IF;
  END LOOP;

  -- (c) Trừ kho theo FEFO: hạn gần nhất trước, cùng hạn thì nhập trước trước (TC-11)
  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) LOOP
    v_food_id   := v_item->>'food_id';
    v_food_name := COALESCE(v_item->>'food_name', v_food_id);
    v_need      := (v_item->>'qty')::NUMERIC;
    CONTINUE WHEN v_need IS NULL OR v_need <= 0;

    FOR v_batch IN
      SELECT id, so_luong FROM lo_thuc_pham
       WHERE user_id = p_user_id AND thuc_pham_id = v_food_id
         AND so_luong > 0
         AND (ngay_het_han IS NULL OR ngay_het_han >= p_today)
       ORDER BY ngay_het_han ASC NULLS LAST, created_at ASC
    LOOP
      EXIT WHEN v_need <= 0;
      v_take := LEAST(v_batch.so_luong, v_need);

      UPDATE lo_thuc_pham SET so_luong = so_luong - v_take WHERE id = v_batch.id;

      INSERT INTO bien_dong_kho
        (user_id, thuc_pham_id, ten_thuc_pham, loai_bien_dong,
         so_luong_nhap, so_luong_xuat, ghi_chu)
      VALUES
        (p_user_id, v_food_id, v_food_name, 'CONSUME',
         0, v_take,
         format('Tieu thu bua an %s | lo %s | mon %s',
                p_meal_id, v_batch.id, COALESCE(v_item->>'meal_item_id', '')));

      v_need     := v_need - v_take;
      v_deducted := v_deducted + 1;
    END LOOP;

    IF v_need > 0 THEN                          -- phòng thủ: không bao giờ trừ thiếu
      RAISE EXCEPTION 'INSUFFICIENT_STOCK: % (thieu %)', v_food_name, v_need;
    END IF;
  END LOOP;

  -- (d) Đánh dấu hoàn thành + xóa nhắc
  UPDATE meals
     SET trang_thai = 'COMPLETED', hoan_thanh_luc = NOW(), gio_nhac = NULL
   WHERE id = p_meal_id;

  DELETE FROM thong_bao WHERE meal_id = p_meal_id AND loai = 'MEAL_REMINDER';

  RETURN jsonb_build_object('status', 'COMPLETED', 'deducted_batches', v_deducted);
END;
$$;

GRANT EXECUTE ON FUNCTION complete_meal_fefo(TEXT, TEXT, JSONB, DATE) TO anon, authenticated;

-- 4. Realtime cho lịch bữa ăn (stream() trong Flutter) ---------------
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE meals;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE meal_items;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;
