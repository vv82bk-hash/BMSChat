// =====================================================
// 🗄️ BMSChat — МИГРАЦИИ БАЗЫ ДАННЫХ
// =====================================================
// Создаёт таблицу uploaded_files для хранения
// файлов прямо в БД (BYTEA).
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