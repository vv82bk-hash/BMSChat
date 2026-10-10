// =====================================================
// 🗄️ BMSChat — МИГРАЦИИ БАЗЫ ДАННЫХ
// =====================================================
// Создаёт таблицу uploaded_files для хранения
// файлов прямо в БД (BYTEA).
//
// 🎤 Добавлена миграция duration для голосовых.
// 🔔 Добавлена миграция fcm_token для push-уведомлений.
// 🔕 Добавлена таблица chat_mutes (mute уведомлений).
// 🔎 Добавлена миграция pg_trgm + GIN-индекс для поиска.
// 🎨 Добавлены колонки chats.emoji и chats.is_private.
// 📊 Добавлены таблицы голосований (polls / poll_options / poll_votes).
// 📌 Добавлена колонка chats.pinned_message_id (закреплённое сообщение).
//
// ЗАПУСК:
//   npm run migrate
// =====================================================

const { pool } = require('./init');

async function runMigrations() {
    console.log('');
    console.log('═══════════════════════════════════════');
    console.log('🗄️  BMSChat — МИГРАЦИИ БАЗЫ ДАННЫХ');
    console.log('═══════════════════════════════════════');

    try {
        // Проверка подключения
        const time = await pool.query('SELECT NOW()');
        console.log('✅ Подключено к PostgreSQL');
        console.log(`   Время: ${time.rows[0].now}`);

        // ─────────────────────────────────────────
        // 1. Таблица uploaded_files
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: таблица uploaded_files');

        await pool.query(`
            CREATE TABLE IF NOT EXISTS uploaded_files (
                id VARCHAR(32) PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                file_data BYTEA NOT NULL,
                file_name VARCHAR(255) NOT NULL,
                file_size INTEGER NOT NULL,
                mime_type VARCHAR(100) NOT NULL,
                file_type VARCHAR(20) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        `);
        console.log('   ✅ Таблица uploaded_files готова');

        // Индексы
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_uploaded_files_user_id
            ON uploaded_files(user_id)
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_uploaded_files_created_at
            ON uploaded_files(created_at DESC)
        `);
        console.log('   ✅ Индексы готовы');

        // ─────────────────────────────────────────
        // 2. Колонка file_data в attachments (на будущее)
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: attachments.file_data');

        const hasFileData = await pool.query(`
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'attachments'
              AND column_name = 'file_data'
        `);

        if (hasFileData.rows.length === 0) {
            await pool.query(`
                ALTER TABLE attachments
                ADD COLUMN file_data BYTEA
            `);
            console.log('   ✅ Колонка file_data добавлена');
        } else {
            console.log('   ℹ️  Колонка file_data уже существует');
        }

        // ─────────────────────────────────────────
        // 3. 🎤 Колонка duration в uploaded_files
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: uploaded_files.duration');

        await pool.query(`
            ALTER TABLE uploaded_files
            ADD COLUMN IF NOT EXISTS duration INTEGER
        `);
        console.log('   ✅ Колонка duration добавлена (или уже была)');

        // ─────────────────────────────────────────
        // 4. 🔔 Колонка fcm_token в users
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: users.fcm_token');

        await pool.query(`
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255)
        `);
        console.log('   ✅ Колонка fcm_token добавлена (или уже была)');

        // ─────────────────────────────────────────
        // 5. 🔕 Таблица chat_mutes (отключённые уведомления)
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: таблица chat_mutes');

        await pool.query(`
            CREATE TABLE IF NOT EXISTS chat_mutes (
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
                muted_at TIMESTAMPTZ DEFAULT NOW(),
                PRIMARY KEY (user_id, chat_id)
            )
        `);
        console.log('   ✅ Таблица chat_mutes готова');

        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_chat_mutes_user_id
            ON chat_mutes(user_id)
        `);
        console.log('   ✅ Индекс idx_chat_mutes_user_id готов');

        // ─────────────────────────────────────────
        // 6. 🎨 Колонки emoji и is_private в chats
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: chats.emoji + chats.is_private');

        await pool.query(`
            ALTER TABLE chats
            ADD COLUMN IF NOT EXISTS emoji VARCHAR(20)
        `);
        await pool.query(`
            ALTER TABLE chats
            ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE
        `);
        console.log('   ✅ Колонки emoji и is_private добавлены (или уже были)');

        // ─────────────────────────────────────────
        // 7. 🔎 Расширение pg_trgm (для поиска по сообщениям)
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: расширение pg_trgm');

        try {
            await pool.query(`CREATE EXTENSION IF NOT EXISTS pg_trgm`);
            console.log('   ✅ Расширение pg_trgm готово');
        } catch (err) {
            console.log('   ⚠️  Не удалось создать pg_trgm автоматически:');
            console.log(`      ${err.message}`);
            console.log('      Включите расширение вручную в панели БД,');
            console.log('      затем перезапустите миграцию.');
            throw err;
        }

        // ─────────────────────────────────────────
        // 8. 🔎 GIN-индекс для поиска по тексту сообщений
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: idx_messages_text_trgm');

        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_messages_text_trgm
            ON messages USING gin (text gin_trgm_ops)
            WHERE is_deleted = FALSE
        `);
        console.log('   ✅ Индекс idx_messages_text_trgm готов');

        // ─────────────────────────────────────────
        // 9. 📊 Таблицы голосований (polls)
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: таблицы polls / poll_options / poll_votes');

        await pool.query(`
            CREATE TABLE IF NOT EXISTS polls (
                id SERIAL PRIMARY KEY,
                chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
                message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
                created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                question TEXT NOT NULL,
                is_multiple BOOLEAN DEFAULT FALSE,
                is_anonymous BOOLEAN DEFAULT FALSE,
                is_closed BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                closed_at TIMESTAMPTZ
            )
        `);
        console.log('   ✅ Таблица polls готова');

        await pool.query(`
            CREATE TABLE IF NOT EXISTS poll_options (
                id SERIAL PRIMARY KEY,
                poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
                text TEXT NOT NULL,
                position INTEGER NOT NULL DEFAULT 0
            )
        `);
        console.log('   ✅ Таблица poll_options готова');

        await pool.query(`
            CREATE TABLE IF NOT EXISTS poll_votes (
                id SERIAL PRIMARY KEY,
                poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
                option_id INTEGER NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE (poll_id, option_id, user_id)
            )
        `);
        console.log('   ✅ Таблица poll_votes готова');

        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_polls_message_id
            ON polls(message_id)
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_polls_chat_id
            ON polls(chat_id)
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_poll_options_poll_id
            ON poll_options(poll_id)
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_id
            ON poll_votes(poll_id)
        `);
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_poll_votes_user_id
            ON poll_votes(user_id)
        `);
        console.log('   ✅ Индексы голосований готовы');

        // ─────────────────────────────────────────
        // 10. 📌 Закреплённое сообщение в чате
        // ─────────────────────────────────────────
        console.log('');
        console.log('📦 Миграция: chats.pinned_message_id');

        await pool.query(`
            ALTER TABLE chats
            ADD COLUMN IF NOT EXISTS pinned_message_id INTEGER
              REFERENCES messages(id) ON DELETE SET NULL
        `);
        console.log('   ✅ Колонка pinned_message_id добавлена (или уже была)');

        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_chats_pinned_message
            ON chats(pinned_message_id)
            WHERE pinned_message_id IS NOT NULL
        `);
        console.log('   ✅ Индекс idx_chats_pinned_message готов');

        // ─────────────────────────────────────────
        // Проверка
        // ─────────────────────────────────────────
        const tables = await pool.query(`
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name
        `);

        console.log('');
        console.log('📊 Таблицы в БД:');
        tables.rows.forEach((t) => {
            console.log(`   • ${t.table_name}`);
        });

        // Проверка колонки duration
        const hasDuration = await pool.query(`
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = 'uploaded_files'
              AND column_name = 'duration'
        `);

        if (hasDuration.rows.length > 0) {
            console.log('');
            console.log('🎤 Колонка uploaded_files.duration:');
            console.log(`   • Тип: ${hasDuration.rows[0].data_type}`);
        }

        // Проверка колонки fcm_token
        const hasFcmToken = await pool.query(`
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = 'users'
              AND column_name = 'fcm_token'
        `);

        if (hasFcmToken.rows.length > 0) {
            console.log('');
            console.log('🔔 Колонка users.fcm_token:');
            console.log(`   • Тип: ${hasFcmToken.rows[0].data_type}`);
        }

        // Проверка таблицы chat_mutes
        const hasChatMutes = await pool.query(`
            SELECT table_name
            FROM information_schema.tables
            WHERE table_name = 'chat_mutes'
        `);

        if (hasChatMutes.rows.length > 0) {
            console.log('');
            console.log('🔕 Таблица chat_mutes:');
            console.log('   • Существует');
        }

        // Проверка индекса поиска
        const hasSearchIndex = await pool.query(`
            SELECT indexname
            FROM pg_indexes
            WHERE tablename = 'messages'
              AND indexname = 'idx_messages_text_trgm'
        `);

        if (hasSearchIndex.rows.length > 0) {
            console.log('');
            console.log('🔎 Индекс поиска:');
            console.log('   • idx_messages_text_trgm существует');
        }

        // Проверка колонок chats.emoji / chats.is_private / chats.pinned_message_id
        const hasChatsExtras = await pool.query(`
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'chats'
              AND column_name IN ('emoji', 'is_private', 'pinned_message_id')
            ORDER BY column_name
        `);

        if (hasChatsExtras.rows.length > 0) {
            console.log('');
            console.log('🎨 Колонки chats:');
            hasChatsExtras.rows.forEach((c) => {
                console.log(`   • ${c.column_name}`);
            });
        }

        // Проверка таблиц голосований
        const hasPolls = await pool.query(`
            SELECT table_name
            FROM information_schema.tables
            WHERE table_name IN ('polls', 'poll_options', 'poll_votes')
            ORDER BY table_name
        `);

        if (hasPolls.rows.length > 0) {
            console.log('');
            console.log('📊 Таблицы голосований:');
            hasPolls.rows.forEach((t) => {
                console.log(`   • ${t.table_name}`);
            });
        }

        console.log('');
        console.log('✅ МИГРАЦИИ ЗАВЕРШЕНЫ');
        console.log('═══════════════════════════════════════');
        console.log('');

        await pool.end();
        process.exit(0);
    } catch (error) {
        console.error('');
        console.error('❌ ОШИБКА МИГРАЦИИ:');
        console.error(error.message);
        console.error(error.stack);
        await pool.end().catch(() => {});
        process.exit(1);
    }
}

runMigrations();