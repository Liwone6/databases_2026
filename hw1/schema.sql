-- =========================================================
-- ДЗ №1. Вариант 1: Онлайн-курсы (EdTech)
-- Физическая модель для PostgreSQL
-- Скрипт идемпотентен: повторный запуск даёт тот же результат.
-- =========================================================

DROP TABLE IF EXISTS lesson_progress CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;

-- ---------------------------------------------------------
-- USER: единый справочник пользователей (студент/преподаватель через role)
-- ---------------------------------------------------------
CREATE TABLE "user" (
    user_id         SERIAL PRIMARY KEY,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    role            VARCHAR(20)     NOT NULL DEFAULT 'student',
    registered_at   TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_role CHECK (role IN ('student', 'teacher'))
);

-- ---------------------------------------------------------
-- COURSE: курс всегда принадлежит одному преподавателю
-- ---------------------------------------------------------
CREATE TABLE course (
    course_id       SERIAL PRIMARY KEY,
    title           VARCHAR(200)    NOT NULL,
    description     TEXT,
    teacher_id      INTEGER         NOT NULL REFERENCES "user" (user_id) ON DELETE RESTRICT,
    price           DECIMAL(10, 2)  NOT NULL DEFAULT 0,
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT chk_course_price CHECK (price >= 0)
);

CREATE INDEX idx_course_teacher_id ON course (teacher_id);

-- ---------------------------------------------------------
-- LESSON: урок не существует без курса (идентифицирующая связь)
-- ---------------------------------------------------------
CREATE TABLE lesson (
    lesson_id       SERIAL PRIMARY KEY,
    course_id       INTEGER         NOT NULL REFERENCES course (course_id) ON DELETE CASCADE,
    title           VARCHAR(200)    NOT NULL,
    content         TEXT,
    order_number    INTEGER         NOT NULL,
    duration_minutes INTEGER        NOT NULL DEFAULT 0,
    CONSTRAINT chk_lesson_order CHECK (order_number > 0),
    CONSTRAINT chk_lesson_duration CHECK (duration_minutes >= 0),
    CONSTRAINT uq_lesson_course_order UNIQUE (course_id, order_number)
);

CREATE INDEX idx_lesson_course_id ON lesson (course_id);

-- ---------------------------------------------------------
-- ENROLLMENT: ассоциативная сущность для связи M:N User <-> Course
-- ---------------------------------------------------------
CREATE TABLE enrollment (
    enrollment_id   SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES "user" (user_id) ON DELETE CASCADE,
    course_id       INTEGER         NOT NULL REFERENCES course (course_id) ON DELETE CASCADE,
    enrolled_at     TIMESTAMP       NOT NULL DEFAULT now(),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active',
    completed_at    TIMESTAMP,
    CONSTRAINT chk_enrollment_status CHECK (status IN ('active', 'completed', 'cancelled')),
    CONSTRAINT uq_enrollment_user_course UNIQUE (user_id, course_id)
);

CREATE INDEX idx_enrollment_user_id ON enrollment (user_id);
CREATE INDEX idx_enrollment_course_id ON enrollment (course_id);

-- ---------------------------------------------------------
-- LESSON_PROGRESS: статус прохождения конкретного урока
-- в рамках конкретной записи на курс
-- ---------------------------------------------------------
CREATE TABLE lesson_progress (
    progress_id     SERIAL PRIMARY KEY,
    enrollment_id   INTEGER         NOT NULL REFERENCES enrollment (enrollment_id) ON DELETE CASCADE,
    lesson_id       INTEGER         NOT NULL REFERENCES lesson (lesson_id) ON DELETE CASCADE,
    is_completed    BOOLEAN         NOT NULL DEFAULT false,
    completed_at    TIMESTAMP,
    CONSTRAINT uq_progress_enrollment_lesson UNIQUE (enrollment_id, lesson_id)
);

CREATE INDEX idx_progress_enrollment_id ON lesson_progress (enrollment_id);
CREATE INDEX idx_progress_lesson_id ON lesson_progress (lesson_id);

-- ---------------------------------------------------------
-- REVIEW: один отзыв студента на курс, оценка 1..5
-- ---------------------------------------------------------
CREATE TABLE review (
    review_id       SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES "user" (user_id) ON DELETE CASCADE,
    course_id       INTEGER         NOT NULL REFERENCES course (course_id) ON DELETE CASCADE,
    rating          SMALLINT        NOT NULL,
    comment         TEXT,
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT uq_review_user_course UNIQUE (user_id, course_id)
);

CREATE INDEX idx_review_user_id ON review (user_id);
CREATE INDEX idx_review_course_id ON review (course_id);
