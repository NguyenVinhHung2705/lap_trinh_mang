-- Mô hình CSDL quan hệ cho 5 module quản lý thực phẩm cá nhân

-- MySQL 8.0.16+; chạy trên cơ sở dữ liệu mới, không chứa lệnh DROP.

-- Đây là thiết kế quan hệ; Firebase cần ánh xạ và kiểm tra tham chiếu riêng.

CREATE DATABASE IF NOT EXISTS quan_ly_thuc_pham CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE quan_ly_thuc_pham;

CREATE TABLE tai_khoan (
  ma_tai_khoan INT NOT NULL AUTO_INCREMENT,
  ho_ten VARCHAR(120) NOT NULL,
  email VARCHAR(254) NOT NULL,
  mat_khau_hash VARCHAR(255) NOT NULL,
  vai_tro VARCHAR(30) NOT NULL DEFAULT 'USER',
  anh_dai_dien VARCHAR(255) NULL,
  da_xac_thuc_email BOOLEAN NOT NULL DEFAULT FALSE,
  trang_thai VARCHAR(30) NOT NULL,
  ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ma_tai_khoan),
  UNIQUE KEY uq_tai_khoan_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE token_xac_thuc (
  ma_token INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  token_hash VARCHAR(255) NOT NULL,
  loai_token VARCHAR(30) NOT NULL,
  het_han DATETIME NOT NULL,
  da_su_dung BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (ma_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE phien_dang_nhap (
  ma_phien INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  refresh_token_hash VARCHAR(255) NOT NULL,
  het_han DATETIME NOT NULL,
  ngay_thu_hoi DATETIME NULL,
  PRIMARY KEY (ma_phien)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE danh_muc_thuc_pham (
  ma_danh_muc INT NOT NULL AUTO_INCREMENT,
  ten_danh_muc VARCHAR(120) NOT NULL,
  PRIMARY KEY (ma_danh_muc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE don_vi (
  ma_don_vi INT NOT NULL AUTO_INCREMENT,
  ten_don_vi VARCHAR(120) NOT NULL,
  ky_hieu VARCHAR(120) NOT NULL,
  nhom_do_luong VARCHAR(30) NOT NULL,
  PRIMARY KEY (ma_don_vi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE thuc_pham (
  ma_thuc_pham INT NOT NULL AUTO_INCREMENT,
  ma_danh_muc INT NOT NULL,
  ma_don_vi_co_so INT NOT NULL,
  ten_thuc_pham VARCHAR(120) NOT NULL,
  ma_vach VARCHAR(120) NULL,
  hinh_anh VARCHAR(255) NULL,
  PRIMARY KEY (ma_thuc_pham)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE vi_tri_luu_tru (
  ma_vi_tri INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  ten_vi_tri VARCHAR(120) NOT NULL,
  mo_ta TEXT NULL,
  PRIMARY KEY (ma_vi_tri)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE lo_thuc_pham (
  ma_lo INT NOT NULL AUTO_INCREMENT,
  ma_thuc_pham INT NOT NULL,
  ma_vi_tri INT NOT NULL,
  ngay_nhap DATE NOT NULL,
  han_su_dung DATE NOT NULL,
  PRIMARY KEY (ma_lo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bien_dong_kho (
  ma_bien_dong INT NOT NULL AUTO_INCREMENT,
  ma_lo INT NOT NULL,
  ma_chi_tiet_mua INT NULL,
  ma_mon_an INT NULL,
  loai_bien_dong VARCHAR(30) NOT NULL,
  so_luong_nhap DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  so_luong_xuat DECIMAL(12,3) NOT NULL DEFAULT 0.000,
  thoi_diem DATETIME NOT NULL,
  ghi_chu VARCHAR(255) NULL,
  PRIMARY KEY (ma_bien_dong),
  CONSTRAINT chk_bien_dong_loai CHECK (loai_bien_dong IN ('IN', 'CONSUME', 'DISCARD', 'ADJUST')),
  CONSTRAINT chk_bien_dong_nhap_khong_am CHECK (so_luong_nhap >= 0),
  CONSTRAINT chk_bien_dong_xuat_khong_am CHECK (so_luong_xuat >= 0),
  CONSTRAINT chk_bien_dong_chi_mot_chieu CHECK ((so_luong_nhap > 0 AND so_luong_xuat = 0) OR (so_luong_nhap = 0 AND so_luong_xuat > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cau_hinh_thuc_pham (
  ma_tai_khoan INT NOT NULL,
  ma_thuc_pham INT NOT NULL,
  nguong_sap_het DECIMAL(12,3) NOT NULL,
  so_luong_mua_de_xuat DECIMAL(12,3) NOT NULL,
  tu_dong_them_mua_sam BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (ma_tai_khoan, ma_thuc_pham)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE danh_sach_mua (
  ma_danh_sach INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  ten_danh_sach VARCHAR(120) NOT NULL,
  ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  trang_thai VARCHAR(30) NOT NULL,
  ngay_hoan_tat DATETIME NULL,
  PRIMARY KEY (ma_danh_sach)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE chi_tiet_mua (
  ma_chi_tiet_mua INT NOT NULL AUTO_INCREMENT,
  ma_danh_sach INT NOT NULL,
  ma_thuc_pham INT NOT NULL,
  ma_don_vi INT NOT NULL,
  so_luong_can_mua DECIMAL(12,3) NOT NULL,
  so_luong_da_mua DECIMAL(12,3) NOT NULL,
  da_dong_bo_kho BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (ma_chi_tiet_mua),
  CHECK (so_luong_can_mua > 0),
  CHECK (so_luong_da_mua >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cong_thuc (
  ma_cong_thuc INT NOT NULL AUTO_INCREMENT,
  ma_tac_gia INT NOT NULL,
  ten_mon VARCHAR(120) NOT NULL,
  mo_ta TEXT NULL,
  cach_lam TEXT NOT NULL,
  hinh_anh VARCHAR(255) NULL,
  khau_phan DECIMAL(12,3) NOT NULL,
  thoi_gian_nau SMALLINT NOT NULL,
  nguon VARCHAR(30) NOT NULL,
  pham_vi_hien_thi VARCHAR(30) NOT NULL,
  PRIMARY KEY (ma_cong_thuc),
  CHECK (khau_phan > 0),
  CHECK (thoi_gian_nau >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE nguyen_lieu_cong_thuc (
  ma_cong_thuc INT NOT NULL,
  ma_thuc_pham INT NOT NULL,
  ma_don_vi INT NOT NULL,
  so_luong DECIMAL(12,3) NOT NULL,
  PRIMARY KEY (ma_cong_thuc, ma_thuc_pham),
  CHECK (so_luong > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bua_an (
  ma_bua_an INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  ngay_an DATE NOT NULL,
  khung_bua VARCHAR(30) NOT NULL,
  gio_nhac DATETIME NULL,
  trang_thai VARCHAR(30) NOT NULL,
  hoan_thanh_luc DATETIME NULL,
  PRIMARY KEY (ma_bua_an)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE mon_an_ke_hoach (
  ma_mon_an INT NOT NULL AUTO_INCREMENT,
  ma_bua_an INT NOT NULL,
  ma_cong_thuc INT NULL,
  ma_thuc_pham INT NULL,
  ma_don_vi INT NULL,
  so_luong DECIMAL(12,3) NOT NULL,
  PRIMARY KEY (ma_mon_an),
  CHECK ((ma_cong_thuc IS NOT NULL) + (ma_thuc_pham IS NOT NULL) = 1),
  CHECK (so_luong > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cong_thuc_da_luu (
  ma_tai_khoan INT NOT NULL,
  ma_cong_thuc INT NOT NULL,
  ngay_luu DATETIME NOT NULL,
  PRIMARY KEY (ma_tai_khoan, ma_cong_thuc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE thong_bao (
  ma_thong_bao INT NOT NULL AUTO_INCREMENT,
  ma_tai_khoan INT NOT NULL,
  ma_lo INT NULL,
  ma_bua_an INT NULL,
  loai VARCHAR(30) NOT NULL,
  noi_dung TEXT NOT NULL,
  thoi_diem_gui DATETIME NOT NULL,
  da_doc BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (ma_thong_bao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE token_xac_thuc ADD CONSTRAINT fk_token_xac_thuc_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE phien_dang_nhap ADD CONSTRAINT fk_phien_dang_nhap_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE thuc_pham ADD CONSTRAINT fk_thuc_pham_ma_danh_muc FOREIGN KEY (ma_danh_muc) REFERENCES danh_muc_thuc_pham (ma_danh_muc) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE thuc_pham ADD CONSTRAINT fk_thuc_pham_ma_don_vi_co_so FOREIGN KEY (ma_don_vi_co_so) REFERENCES don_vi (ma_don_vi) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE vi_tri_luu_tru ADD CONSTRAINT fk_vi_tri_luu_tru_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE lo_thuc_pham ADD CONSTRAINT fk_lo_thuc_pham_ma_thuc_pham FOREIGN KEY (ma_thuc_pham) REFERENCES thuc_pham (ma_thuc_pham) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE lo_thuc_pham ADD CONSTRAINT fk_lo_thuc_pham_ma_vi_tri FOREIGN KEY (ma_vi_tri) REFERENCES vi_tri_luu_tru (ma_vi_tri) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE bien_dong_kho ADD CONSTRAINT fk_bien_dong_kho_ma_lo FOREIGN KEY (ma_lo) REFERENCES lo_thuc_pham (ma_lo) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE bien_dong_kho ADD CONSTRAINT fk_bien_dong_kho_ma_chi_tiet_mua FOREIGN KEY (ma_chi_tiet_mua) REFERENCES chi_tiet_mua (ma_chi_tiet_mua) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE bien_dong_kho ADD CONSTRAINT fk_bien_dong_kho_ma_mon_an FOREIGN KEY (ma_mon_an) REFERENCES mon_an_ke_hoach (ma_mon_an) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cau_hinh_thuc_pham ADD CONSTRAINT fk_cau_hinh_thuc_pham_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cau_hinh_thuc_pham ADD CONSTRAINT fk_cau_hinh_thuc_pham_ma_thuc_pham FOREIGN KEY (ma_thuc_pham) REFERENCES thuc_pham (ma_thuc_pham) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE danh_sach_mua ADD CONSTRAINT fk_danh_sach_mua_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE chi_tiet_mua ADD CONSTRAINT fk_chi_tiet_mua_ma_danh_sach FOREIGN KEY (ma_danh_sach) REFERENCES danh_sach_mua (ma_danh_sach) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE chi_tiet_mua ADD CONSTRAINT fk_chi_tiet_mua_ma_thuc_pham FOREIGN KEY (ma_thuc_pham) REFERENCES thuc_pham (ma_thuc_pham) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE chi_tiet_mua ADD CONSTRAINT fk_chi_tiet_mua_ma_don_vi FOREIGN KEY (ma_don_vi) REFERENCES don_vi (ma_don_vi) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cong_thuc ADD CONSTRAINT fk_cong_thuc_ma_tac_gia FOREIGN KEY (ma_tac_gia) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE nguyen_lieu_cong_thuc ADD CONSTRAINT fk_nguyen_lieu_cong_thuc_ma_cong_thuc FOREIGN KEY (ma_cong_thuc) REFERENCES cong_thuc (ma_cong_thuc) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE nguyen_lieu_cong_thuc ADD CONSTRAINT fk_nguyen_lieu_cong_thuc_ma_thuc_pham FOREIGN KEY (ma_thuc_pham) REFERENCES thuc_pham (ma_thuc_pham) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE nguyen_lieu_cong_thuc ADD CONSTRAINT fk_nguyen_lieu_cong_thuc_ma_don_vi FOREIGN KEY (ma_don_vi) REFERENCES don_vi (ma_don_vi) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE bua_an ADD CONSTRAINT fk_bua_an_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE mon_an_ke_hoach ADD CONSTRAINT fk_mon_an_ke_hoach_ma_bua_an FOREIGN KEY (ma_bua_an) REFERENCES bua_an (ma_bua_an) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE mon_an_ke_hoach ADD CONSTRAINT fk_mon_an_ke_hoach_ma_cong_thuc FOREIGN KEY (ma_cong_thuc) REFERENCES cong_thuc (ma_cong_thuc) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE mon_an_ke_hoach ADD CONSTRAINT fk_mon_an_ke_hoach_ma_thuc_pham FOREIGN KEY (ma_thuc_pham) REFERENCES thuc_pham (ma_thuc_pham) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE mon_an_ke_hoach ADD CONSTRAINT fk_mon_an_ke_hoach_ma_don_vi FOREIGN KEY (ma_don_vi) REFERENCES don_vi (ma_don_vi) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cong_thuc_da_luu ADD CONSTRAINT fk_cong_thuc_da_luu_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cong_thuc_da_luu ADD CONSTRAINT fk_cong_thuc_da_luu_ma_cong_thuc FOREIGN KEY (ma_cong_thuc) REFERENCES cong_thuc (ma_cong_thuc) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE thong_bao ADD CONSTRAINT fk_thong_bao_ma_tai_khoan FOREIGN KEY (ma_tai_khoan) REFERENCES tai_khoan (ma_tai_khoan) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE thong_bao ADD CONSTRAINT fk_thong_bao_ma_lo FOREIGN KEY (ma_lo) REFERENCES lo_thuc_pham (ma_lo) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE thong_bao ADD CONSTRAINT fk_thong_bao_ma_bua_an FOREIGN KEY (ma_bua_an) REFERENCES bua_an (ma_bua_an) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Tồn kho mỗi lô = SUM(so_luong_nhap) - SUM(so_luong_xuat) trong bien_dong_kho (>= 0).
-- Khi xuất/tiêu thụ/điều chỉnh giảm phải khóa bản ghi lô (SELECT ... FOR UPDATE) trong giao dịch nguyên tử, kiểm tra tổng tồn khả dụng không âm và giữ bất biến lịch sử đã xác nhận.
-- Liên tài khoản, số lượng/đơn vị tương thích và chống thao tác lặp phải kiểm tra trong nghiệp vụ/giao dịch.

-- Firebase Authentication đảm nhiệm mật khẩu và token nếu dùng backend Firebase; không lưu chúng trong Firestore.