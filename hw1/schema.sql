-- =========================================================
-- ДЗ №1. Вариант 1: Онлайн-курсы (EdTech)
-- Физическая модель для PostgreSQL
-- Версия после ревью: User разделён на Teacher/Student,
-- добавлена таблица Payment (история оплат).
-- Скрипт идемпотентен: повторный запуск даёт тот же результат.
-- =========================================================

DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS lesson_progress CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS teacher CASCADE;
DROP TABLE IF EXISTS student CASCADE;

-- ---------------------------------------------------------
-- TEACHER: отдельная сущность (не общий User с ролью),
-- т.к. только преподаватель создаёт курсы и получает выплаты
-- ---------------------------------------------------------
CREATE TABLE teacher (
    teacher_id      SERIAL PRIMARY KEY,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    registered_at   TIMESTAMP       NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- STUDENT: отдельная сущность, т.к. только студент
-- записывается на курсы, платит и пишет отзывы
-- ---------------------------------------------------------
CREATE TABLE student (
    student_id      SERIAL PRIMARY KEY,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    registered_at   TIMESTAMP       NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- COURSE: курс всегда принадлежит одному преподавателю
-- ---------------------------------------------------------
CREATE TABLE course (
    course_id       SERIAL PRIMARY KEY,
    title           VARCHAR(200)    NOT NULL,
    description     TEXT,
    teacher_id      INTEGER         NOT NULL REFERENCES teacher (teacher_id) ON DELETE RESTRICT,
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
-- ENROLLMENT: ассоциативная сущность для связи M:N Student <-> Course
-- ---------------------------------------------------------
CREATE TABLE enrollment (
    enrollment_id   SERIAL PRIMARY KEY,
    student_id      INTEGER         NOT NULL REFERENCES student (student_id) ON DELETE CASCADE,
    course_id       INTEGER         NOT NULL REFERENCES course (course_id) ON DELETE CASCADE,
    enrolled_at     TIMESTAMP       NOT NULL DEFAULT now(),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active',
    completed_at    TIMESTAMP,
    CONSTRAINT chk_enrollment_status CHECK (status IN ('active', 'completed', 'cancelled')),
    CONSTRAINT uq_enrollment_student_course UNIQUE (student_id, course_id)
);

CREATE INDEX idx_enrollment_student_id ON enrollment (student_id);
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
    student_id      INTEGER         NOT NULL REFERENCES student (student_id) ON DELETE CASCADE,
    course_id       INTEGER         NOT NULL REFERENCES course (course_id) ON DELETE CASCADE,
    rating          SMALLINT        NOT NULL,
    comment         TEXT,
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT uq_review_student_course UNIQUE (student_id, course_id)
);

CREATE INDEX idx_review_student_id ON review (student_id);
CREATE INDEX idx_review_course_id ON review (course_id);

-- ---------------------------------------------------------
-- PAYMENT: история фактических оплат за запись на курс.
-- Нужна, чтобы считать выплаты преподавателю за период
-- по реальным платежам, а не по текущей Course.price,
-- и чтобы учитывать возвраты.
-- ---------------------------------------------------------
CREATE TABLE payment (
    payment_id      SERIAL PRIMARY KEY,
    enrollment_id   INTEGER         NOT NULL REFERENCES enrollment (enrollment_id) ON DELETE CASCADE,
    amount          DECIMAL(10, 2)  NOT NULL,
    paid_at         TIMESTAMP       NOT NULL DEFAULT now(),
    status          VARCHAR(20)     NOT NULL DEFAULT 'paid',
    CONSTRAINT chk_payment_amount CHECK (amount >= 0),
    CONSTRAINT chk_payment_status CHECK (status IN ('paid', 'refunded'))
);

CREATE INDEX idx_payment_enrollment_id ON payment (enrollment_id);
