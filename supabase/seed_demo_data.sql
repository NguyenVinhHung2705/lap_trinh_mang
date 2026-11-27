-- ════════════════════════════════════════════════════════════════════
-- SEED DATA MẪU CHO DỰ ÁN SMART FOOD LIFE
-- Bao gồm: Đơn vị tính, Danh mục & Thực phẩm mẫu, Công thức nấu ăn + Nguyên liệu
-- Chạy trên Supabase SQL Editor sau khi đã tạo xong các bảng.
-- File này an toàn để chạy nhiều lần (idempotent: sử dụng ON CONFLICT DO NOTHING / DO UPDATE)
-- ════════════════════════════════════════════════════════════════════

-- 1. ĐƠN VỊ TÍNH (don_vi)
INSERT INTO don_vi (id, ten, ky_hieu, nhom_do_luong) VALUES
  ('unit_g', 'Gram', 'g', 'MASS'),
  ('unit_kg', 'Kilogram', 'kg', 'MASS'),
  ('unit_ml', 'Mililit', 'ml', 'VOLUME'),
  ('unit_l', 'Lít', 'l', 'VOLUME'),
  ('unit_qua', 'Quả', 'quả', 'COUNT'),
  ('unit_goi', 'Gói', 'gói', 'COUNT'),
  ('unit_hop', 'Hộp', 'hộp', 'COUNT'),
  ('unit_chail', 'Chai', 'chai', 'COUNT')
ON CONFLICT (id) DO UPDATE SET
  ten = EXCLUDED.ten,
  ky_hieu = EXCLUDED.ky_hieu,
  nhom_do_luong = EXCLUDED.nhom_do_luong;

-- 2. THỰC PHẨM TOÀN CỤC (thuc_pham_global)
INSERT INTO thuc_pham_global (id, ten, ten_danh_muc, don_vi_co_so, hinh_anh, ton_kho_toi_thieu) VALUES
  ('food_thit_bo', 'Thịt bò tươi', 'Thịt & Hải sản', 'unit_g', 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800', 500),
  ('food_thit_heo', 'Thịt heo nạc dăm', 'Thịt & Hải sản', 'unit_g', 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800', 300),
  ('food_trung_ga', 'Trứng gà công nghiệp', 'Trứng & Sữa', 'unit_qua', 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=800', 6),
  ('food_gao_st25', 'Gạo thơm ST25', 'Lương thực khô', 'unit_kg', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800', 2),
  ('food_ca_chua', 'Cà chua Đà Lạt', 'Rau củ quả', 'unit_g', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800', 200),
  ('food_hanh_la', 'Hành lá', 'Gia vị & Rau thơm', 'unit_g', 'https://images.unsplash.com/photo-1608686207856-001b95cf60ca?w=800', 50),
  ('food_nuoc_mam', 'Nước mắm cá cơm', 'Gia vị & Rau thơm', 'unit_ml', 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=800', 100),
  ('food_dau_an', 'Dầu ăn thực vật', 'Gia vị & Rau thơm', 'unit_ml', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=800', 200),
  ('food_banh_pho', 'Bánh phở tươi', 'Lương thực khô', 'unit_g', 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800', 500),
  ('food_ca_loc', 'Cá lóc đồng', 'Thịt & Hải sản', 'unit_g', 'https://images.unsplash.com/photo-1534483509719-3feaee7c30da?w=800', 400)
ON CONFLICT (id) DO UPDATE SET
  ten = EXCLUDED.ten,
  ten_danh_muc = EXCLUDED.ten_danh_muc,
  don_vi_co_so = EXCLUDED.don_vi_co_so;

-- 3. CÔNG THỨC MẪU HỆ THỐNG (cong_thuc - Dùng chung cho tất cả thành viên)
INSERT INTO cong_thuc (id, ma_tac_gia, ten, mo_ta, hinh_anh, khau_phan, thoi_gian_nau, loai) VALUES
  ('a1b2c3d4-0001-4000-8000-000000000001', 'system', 'Phở bò tái truyền thống', 'Phở bò thơm ngon, đậm đà hương vị gia truyền.', 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=800', 2, 45, 'SYSTEM'),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'system', 'Trứng chiên thịt bằm', 'Món ăn gia đình nhanh gọn, giàu dinh dưỡng và dễ làm.', 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800', 2, 15, 'SYSTEM'),
  ('a1b2c3d4-0003-4000-8000-000000000003', 'system', 'Canh chua cá lóc Nam Bộ', 'Vị chua thanh mát từ cà chua và me, ngọt thịt cá lóc đồng.', 'https://images.unsplash.com/photo-1547592180-85f173990554?w=800', 3, 30, 'SYSTEM'),
  ('a1b2c3d4-0004-4000-8000-000000000004', 'system', 'Thịt heo xào hành cà chua', 'Món mặn ăn kèm cơm trắng đậm vị đưa cơm.', 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800', 2, 20, 'SYSTEM')
ON CONFLICT (id) DO UPDATE SET
  ten = EXCLUDED.ten,
  mo_ta = EXCLUDED.mo_ta,
  hinh_anh = EXCLUDED.hinh_anh,
  khau_phan = EXCLUDED.khau_phan,
  thoi_gian_nau = EXCLUDED.thoi_gian_nau,
  loai = EXCLUDED.loai;

-- 4. NGUYÊN LIỆU CHO CÔNG THỨC (nguyen_lieu_cong_thuc)
-- Xóa nguyên liệu cũ của các công thức mẫu trên để nạp mới tránh trùng lặp
DELETE FROM nguyen_lieu_cong_thuc WHERE cong_thuc_id IN (
  'a1b2c3d4-0001-4000-8000-000000000001',
  'a1b2c3d4-0002-4000-8000-000000000002',
  'a1b2c3d4-0003-4000-8000-000000000003',
  'a1b2c3d4-0004-4000-8000-000000000004'
);

INSERT INTO nguyen_lieu_cong_thuc (cong_thuc_id, thuc_pham_id, ten_thuc_pham, don_vi_id, ky_hieu_don_vi, so_luong_co_so) VALUES
  -- Phở bò tái:
  ('a1b2c3d4-0001-4000-8000-000000000001', 'food_thit_bo', 'Thịt bò tươi', 'unit_g', 'g', 300),
  ('a1b2c3d4-0001-4000-8000-000000000001', 'food_banh_pho', 'Bánh phở tươi', 'unit_g', 'g', 400),
  ('a1b2c3d4-0001-4000-8000-000000000001', 'food_hanh_la', 'Hành lá', 'unit_g', 'g', 30),
  
  -- Trứng chiên thịt bằm:
  ('a1b2c3d4-0002-4000-8000-000000000002', 'food_trung_ga', 'Trứng gà', 'unit_qua', 'quả', 4),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'food_thit_heo', 'Thịt heo nạc dăm', 'unit_g', 'g', 150),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'food_hanh_la', 'Hành lá', 'unit_g', 'g', 20),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'food_nuoc_mam', 'Nước mắm', 'unit_ml', 'ml', 15),

  -- Canh chua cá lóc:
  ('a1b2c3d4-0003-4000-8000-000000000003', 'food_ca_loc', 'Cá lóc đồng', 'unit_g', 'g', 400),
  ('a1b2c3d4-0003-4000-8000-000000000003', 'food_ca_chua', 'Cà chua Đà Lạt', 'unit_g', 'g', 150),
  ('a1b2c3d4-0003-4000-8000-000000000003', 'food_nuoc_mam', 'Nước mắm', 'unit_ml', 'ml', 20),

  -- Thịt heo xào hành cà chua:
  ('a1b2c3d4-0004-4000-8000-000000000004', 'food_thit_heo', 'Thịt heo nạc dăm', 'unit_g', 'g', 250),
  ('a1b2c3d4-0004-4000-8000-000000000004', 'food_ca_chua', 'Cà chua Đà Lạt', 'unit_g', 'g', 100),
  ('a1b2c3d4-0004-4000-8000-000000000004', 'food_hanh_la', 'Hành lá', 'unit_g', 'g', 20),
  ('a1b2c3d4-0004-4000-8000-000000000004', 'food_dau_an', 'Dầu ăn', 'unit_ml', 'ml', 20);
