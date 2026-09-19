-- =========================================================
-- ДЗ №2. Часть 2. Демонстрация нарушений ограничений
--
-- Порядок запуска:
--   1) schema.sql (ДЗ №1: teacher/student/course/... /payment)
--   2) 02_schema_additions.sql (category, course_category)
--   3) этот файл
--
-- Скрипт сначала создаёт немного тестовых данных ("baseline"),
-- а затем 5 раз пытается сделать операцию, нарушающую то или
-- иное ограничение целостности, ловит исключение в блоке
-- DO $$ ... EXCEPTION ... END $$ и печатает понятное сообщение
-- + оригинальный текст ошибки от Postgres (SQLERRM).
-- =========================================================

-- ---------------------------------------------------------
-- BASELINE-данные для демонстраций
-- ---------------------------------------------------------
INSERT INTO teacher (teacher_id, full_name, email, password_hash)
VALUES (1, 'Иванов Иван Иванович', 'ivanov@example.com', 'hash1')
ON CONFLICT (teacher_id) DO NOTHING;

INSERT INTO student (student_id, full_name, email, password_hash)
VALUES (1, 'Петров Пётр Петрович', 'petrov@example.com', 'hash2')
ON CONFLICT (student_id) DO NOTHING;

INSERT INTO course (course_id, title, description, teacher_id, price)
VALUES (1, 'Введение в SQL', 'demo course', 1, 990.00)
ON CONFLICT (course_id) DO NOTHING;

INSERT INTO category (category_id, name)
VALUES (1, 'Программирование')
ON CONFLICT (category_id) DO NOTHING;

INSERT INTO course_category (course_id, category_id)
VALUES (1, 1)
ON CONFLICT (course_id, category_id) DO NOTHING;

-- Выше мы вставляли строки с явно указанными id (teacher_id=1,
-- student_id=1 и т.д.), а не давали SERIAL сгенерировать их
-- самостоятельно. Из-за этого внутренние счётчики
-- (sequence) остаются на нуле и не "знают", что id=1 уже занят.
-- Если это не поправить, следующая обычная вставка (без явного
-- id) попытается снова взять id=1 и упадёт с ошибкой PRIMARY KEY
-- вместо нужной нам по сценарию ошибки UNIQUE(email) — то есть
-- демонстрация №3 ниже проверяла бы не то, что задумано.
-- Синхронизируем последовательности с уже вставленными id:
SELECT setval(pg_get_serial_sequence('teacher', 'teacher_id'), COALESCE(MAX(teacher_id), 1)) FROM teacher;
SELECT setval(pg_get_serial_sequence('student', 'student_id'), COALESCE(MAX(student_id), 1)) FROM student;
SELECT setval(pg_get_serial_sequence('course', 'course_id'), COALESCE(MAX(course_id), 1)) FROM course;
SELECT setval(pg_get_serial_sequence('category', 'category_id'), COALESCE(MAX(category_id), 1)) FROM category;

-- =========================================================
-- 1. Нарушение CHECK
-- Бизнес-правило: цена курса не может быть отрицательной.
-- =========================================================
DO $$
BEGIN
    INSERT INTO course (title, description, teacher_id, price)
    VALUES ('Курс с отрицательной ценой', 'demo', 1, -100);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Понятное сообщение: цена курса не может быть отрицательной — курс не может "доплачивать" студенту за покупку. Ошибка СУБД: %', SQLERRM;
END;
$$;

-- =========================================================
-- 2. Нарушение FOREIGN KEY
-- Бизнес-правило: урок не может существовать без курса,
-- к которому он относится.
-- =========================================================
DO $$
BEGIN
    INSERT INTO lesson (course_id, title, order_number)
    VALUES (999999, 'Урок несуществующего курса', 1);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Понятное сообщение: нельзя добавить урок в курс, которого не существует — сначала нужно создать курс. Ошибка СУБД: %', SQLERRM;
END;
$$;

-- =========================================================
-- 3. Нарушение UNIQUE
-- Бизнес-правило: email студента используется для входа в
-- систему, поэтому два аккаунта с одним email недопустимы.
-- =========================================================
DO $$
BEGIN
    INSERT INTO student (full_name, email, password_hash)
    VALUES ('Другой Пётр', 'petrov@example.com', 'hash3');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Понятное сообщение: пользователь с таким email уже зарегистрирован — для входа в систему email должен быть уникальным. Ошибка СУБД: %', SQLERRM;
END;
$$;

-- =========================================================
-- 4. Нарушение NOT NULL
-- Бизнес-правило: у преподавателя обязательно должно быть имя,
-- иначе его нельзя показать студентам на странице курса.
-- =========================================================
DO $$
BEGIN
    INSERT INTO teacher (full_name, email, password_hash)
    VALUES (NULL, 'no_name_teacher@example.com', 'hash4');
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Понятное сообщение: имя преподавателя обязательно — без него невозможно показать профиль преподавателя студентам. Ошибка СУБД: %', SQLERRM;
END;
$$;

-- =========================================================
-- 5. Другое ограничение: составной PRIMARY KEY
-- (course_category: пара course_id+category_id уникальна)
-- Бизнес-правило: нельзя повторно присвоить курсу одну и ту
-- же категорию — это была бы бессмысленная дублирующая запись.
--
-- Важный нюанс для отчёта: в PostgreSQL PRIMARY KEY физически
-- реализован через уникальный индекс, поэтому конфликт по
-- составному PK ловится тем же кодом исключения unique_violation,
-- что и обычный UNIQUE (SQLSTATE 23505) — технически это одно
-- и то же семейство ошибок, но по бизнес-смыслу это разные
-- правила (идентичность строки vs просто уникальность поля).
-- =========================================================
DO $$
BEGIN
    -- (1, 1) уже есть в baseline-данных выше — вставляем ту же пару снова
    INSERT INTO course_category (course_id, category_id)
    VALUES (1, 1);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Понятное сообщение: этот курс уже отмечен данной категорией — повторное присвоение той же категории не имеет смысла. Ошибка СУБД: %', SQLERRM;
END;
$$;
