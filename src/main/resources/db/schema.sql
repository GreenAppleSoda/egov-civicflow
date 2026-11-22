-- =====================================================================
-- eGov-CivicFlow 민원 접수·처리 시스템 - 테이블 생성 스크립트 (MariaDB)
--
-- 실행 대상 : civil 데이터베이스 (civil 계정으로 접속해서 실행)
-- 실행 순서 : schema.sql -> seed.sql
-- 주의      : 맨 위의 DROP 문은 개발용 초기화 용도이며, 기존 데이터가 삭제됩니다.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS stat_daily;
DROP TABLE IF EXISTS attach_file;
DROP TABLE IF EXISTS complaint_answer;
DROP TABLE IF EXISTS complaint_history;
DROP TABLE IF EXISTS complaint;
DROP TABLE IF EXISTS notice;
DROP TABLE IF EXISTS `code`;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- users : 사용자 (민원인, 담당자, 관리자)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '사용자 ID',
  login_id      VARCHAR(30)  NOT NULL COMMENT '로그인 아이디',
  password_hash VARCHAR(100) NOT NULL COMMENT '비밀번호 해시 (SR-01)',
  user_name     VARCHAR(50)  NOT NULL COMMENT '이름',
  email         VARCHAR(100) NOT NULL COMMENT '이메일',
  phone         VARCHAR(20)  NULL     COMMENT '연락처',
  user_role     VARCHAR(10)  NOT NULL COMMENT '역할: CITIZEN / OFFICER / ADMIN',
  use_yn        CHAR(1)      NOT NULL DEFAULT 'Y' COMMENT '사용 여부 (비활성화 = N)',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록일시',
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  PRIMARY KEY (user_id),
  UNIQUE KEY uk_users_login_id (login_id),
  UNIQUE KEY uk_users_email (email),
  CONSTRAINT ck_users_role CHECK (user_role IN ('CITIZEN', 'OFFICER', 'ADMIN')),
  CONSTRAINT ck_users_use_yn CHECK (use_yn IN ('Y', 'N'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='사용자';

-- ---------------------------------------------------------------------
-- code : 공통코드 (민원 분류, 민원 상태, 사용자 역할의 표시 이름)
-- ---------------------------------------------------------------------
CREATE TABLE `code` (
  group_code VARCHAR(30) NOT NULL COMMENT '코드 그룹',
  `code`     VARCHAR(30) NOT NULL COMMENT '코드 값',
  code_name  VARCHAR(50) NOT NULL COMMENT '화면 표시 이름',
  sort_order INT         NOT NULL DEFAULT 0 COMMENT '정렬 순서',
  use_yn     CHAR(1)     NOT NULL DEFAULT 'Y' COMMENT '사용 여부',
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록일시',
  PRIMARY KEY (group_code, `code`),
  CONSTRAINT ck_code_use_yn CHECK (use_yn IN ('Y', 'N'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='공통코드';

-- ---------------------------------------------------------------------
-- complaint : 민원
-- ---------------------------------------------------------------------
CREATE TABLE complaint (
  complaint_id  BIGINT       NOT NULL AUTO_INCREMENT COMMENT '민원 ID',
  category_code VARCHAR(30)  NOT NULL COMMENT '민원 분류 코드 (code.group_code = COMPLAINT_CATEGORY)',
  title         VARCHAR(200) NOT NULL COMMENT '제목',
  content       TEXT         NOT NULL COMMENT '내용',
  status        VARCHAR(20)  NOT NULL DEFAULT 'RECEIVED' COMMENT '상태',
  requester_id  BIGINT       NOT NULL COMMENT '등록한 민원인',
  officer_id    BIGINT       NULL     COMMENT '배정된 담당자',
  due_date      DATE         NOT NULL COMMENT '처리 기한 (접수일 + 7일, BR-06)',
  overdue_yn    CHAR(1)      NOT NULL DEFAULT 'N' COMMENT '기한 초과 여부 (BT-02)',
  closed_at     DATETIME     NULL     COMMENT '종결 일시 (완료, 반려, 취소)',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '접수일시',
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  PRIMARY KEY (complaint_id),
  KEY idx_complaint_requester (requester_id, created_at),
  KEY idx_complaint_officer (officer_id, status),
  KEY idx_complaint_status_created (status, created_at),
  KEY idx_complaint_status_due (status, due_date),
  KEY idx_complaint_category (category_code, created_at),
  CONSTRAINT fk_complaint_requester FOREIGN KEY (requester_id) REFERENCES users (user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_complaint_officer FOREIGN KEY (officer_id) REFERENCES users (user_id) ON DELETE RESTRICT,
  CONSTRAINT ck_complaint_status CHECK (status IN ('RECEIVED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'CANCELED')),
  CONSTRAINT ck_complaint_overdue CHECK (overdue_yn IN ('Y', 'N'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='민원';

-- ---------------------------------------------------------------------
-- complaint_history : 민원 처리 이력 (BR-01, BR-09)
--   재배정은 from_status = to_status = ASSIGNED 이면서 officer_id 가 새 담당자인 행으로 기록
-- ---------------------------------------------------------------------
CREATE TABLE complaint_history (
  history_id   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '이력 ID',
  complaint_id BIGINT       NOT NULL COMMENT '민원 ID',
  from_status  VARCHAR(20)  NULL     COMMENT '이전 상태 (최초 등록은 NULL)',
  to_status    VARCHAR(20)  NOT NULL COMMENT '이후 상태',
  actor_id     BIGINT       NOT NULL COMMENT '처리한 사용자',
  officer_id   BIGINT       NULL     COMMENT '배정, 재배정 대상 담당자',
  memo         VARCHAR(500) NULL     COMMENT '메모, 반려 사유 등',
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '처리일시',
  PRIMARY KEY (history_id),
  KEY idx_history_complaint (complaint_id, created_at),
  CONSTRAINT fk_history_complaint FOREIGN KEY (complaint_id) REFERENCES complaint (complaint_id) ON DELETE RESTRICT,
  CONSTRAINT fk_history_actor FOREIGN KEY (actor_id) REFERENCES users (user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_history_officer FOREIGN KEY (officer_id) REFERENCES users (user_id) ON DELETE RESTRICT,
  CONSTRAINT ck_history_from_status CHECK (from_status IN ('RECEIVED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'CANCELED')),
  CONSTRAINT ck_history_to_status CHECK (to_status IN ('RECEIVED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'CANCELED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='민원 처리 이력';

-- ---------------------------------------------------------------------
-- complaint_answer : 민원 답변 (민원당 1건)
-- ---------------------------------------------------------------------
CREATE TABLE complaint_answer (
  answer_id    BIGINT   NOT NULL AUTO_INCREMENT COMMENT '답변 ID',
  complaint_id BIGINT   NOT NULL COMMENT '민원 ID',
  officer_id   BIGINT   NOT NULL COMMENT '답변한 담당자',
  content      TEXT     NOT NULL COMMENT '답변 내용',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록일시',
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  PRIMARY KEY (answer_id),
  UNIQUE KEY uk_answer_complaint (complaint_id),
  CONSTRAINT fk_answer_complaint FOREIGN KEY (complaint_id) REFERENCES complaint (complaint_id) ON DELETE RESTRICT,
  CONSTRAINT fk_answer_officer FOREIGN KEY (officer_id) REFERENCES users (user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='민원 답변';

-- ---------------------------------------------------------------------
-- attach_file : 첨부파일 (BR-07, BR-08)
-- ---------------------------------------------------------------------
CREATE TABLE attach_file (
  file_id       BIGINT       NOT NULL AUTO_INCREMENT COMMENT '파일 ID',
  complaint_id  BIGINT       NOT NULL COMMENT '민원 ID',
  original_name VARCHAR(255) NOT NULL COMMENT '원본 파일명',
  stored_name   VARCHAR(100) NOT NULL COMMENT '저장 파일명 (UUID 기반)',
  file_size     BIGINT       NOT NULL COMMENT '파일 크기 (바이트)',
  content_type  VARCHAR(100) NULL     COMMENT 'MIME 타입',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록일시',
  PRIMARY KEY (file_id),
  UNIQUE KEY uk_attach_stored_name (stored_name),
  KEY idx_attach_complaint (complaint_id),
  CONSTRAINT fk_attach_complaint FOREIGN KEY (complaint_id) REFERENCES complaint (complaint_id) ON DELETE RESTRICT,
  CONSTRAINT ck_attach_size CHECK (file_size >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='첨부파일';

-- ---------------------------------------------------------------------
-- notice : 공지사항
-- ---------------------------------------------------------------------
CREATE TABLE notice (
  notice_id  BIGINT       NOT NULL AUTO_INCREMENT COMMENT '공지 ID',
  title      VARCHAR(200) NOT NULL COMMENT '제목',
  content    TEXT         NOT NULL COMMENT '내용',
  writer_id  BIGINT       NOT NULL COMMENT '작성자 (관리자)',
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록일시',
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정일시',
  PRIMARY KEY (notice_id),
  KEY idx_notice_created (created_at),
  CONSTRAINT fk_notice_writer FOREIGN KEY (writer_id) REFERENCES users (user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='공지사항';

-- ---------------------------------------------------------------------
-- stat_daily : 일별 통계 (BT-01 배치 결과)
-- ---------------------------------------------------------------------
CREATE TABLE stat_daily (
  stat_date     DATE        NOT NULL COMMENT '집계 일자',
  category_code VARCHAR(30) NOT NULL COMMENT '민원 분류 코드',
  received_cnt  INT         NOT NULL DEFAULT 0 COMMENT '접수 건수',
  completed_cnt INT         NOT NULL DEFAULT 0 COMMENT '완료 건수',
  rejected_cnt  INT         NOT NULL DEFAULT 0 COMMENT '반려 건수',
  canceled_cnt  INT         NOT NULL DEFAULT 0 COMMENT '취소 건수',
  created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '집계일시',
  PRIMARY KEY (stat_date, category_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='일별 통계';
