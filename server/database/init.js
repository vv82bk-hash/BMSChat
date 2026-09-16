// =====================================================
// 🎯 BMSChat — ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ (PostgreSQL)
// =====================================================
// Создаёт 9 таблиц в PostgreSQL:
//   1. users
//   2. roles
//   3. user_roles
//   4. chats
//   5. chat_members
//   6. messages
//   7. reactions
//   8. attachments
//   9. feed_events
//
// ЗАПУСК:
//   npm run init-db
// =====================================================

const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const config = require('../config');

// =====================================================
// 🗄️ ПОДКЛЮЧЕНИЕ К POSTGRESQL
// =====================================================
const pool = new Pool({
    connectionString: config.DATABASE_URL,
    ssl: config.DB_SSL ? { rejectUnauthorized: false } : false,
    max: config.DB_POOL_MAX,
    idleTimeoutMillis: config.DB_POOL_IDLE_TIMEOUT,
    connectionTimeoutMillis: config.DB_POOL_CONNECTION_TIMEOUT,
});

pool.on('error', (err) => {
    console.error('❌ Ошибка PostgreSQL pool:', err.message);
});

// =====================================================
// 📊 СОЗДАНИЕ ТАБЛИЦ
// =====================================================

async function createTables() {
    console.log('');
    console.log('🏗️  СОЗДАНИЕ СХЕМЫ БАЗЫ ДАННЫХ');
    console.log('═══════════════════════════════════════');

    // ─────────────────────────────────────────
    // 1️⃣ users
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(30) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            display_name VARCHAR(100) NOT NULL,
            avatar VARCHAR(255),
            status VARCHAR(10) DEFAULT 'offline' CHECK(status IN ('online', 'offline')),
            is_approved BOOLEAN DEFAULT FALSE,
            approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            failed_login_attempts INTEGER DEFAULT 0,
            lockout_until TIMESTAMPTZ,
            last_seen TIMESTAMPTZ DEFAULT NOW(),
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица users создана');

    // ─────────────────────────────────────────
    // 2️⃣ roles
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS roles (
            id SERIAL PRIMARY KEY,
            name VARCHAR(50) UNIQUE NOT NULL,
            description TEXT,
            color VARCHAR(7) DEFAULT '#FED100',
            icon VARCHAR(10) DEFAULT '🎖️',
            priority INTEGER DEFAULT 0,
            can_write_general BOOLEAN DEFAULT FALSE,
            can_write_private BOOLEAN DEFAULT FALSE,
            can_write_to_commander BOOLEAN DEFAULT FALSE,
            can_create_feed BOOLEAN DEFAULT FALSE,
            can_approve_users BOOLEAN DEFAULT FALSE,
            can_manage_roles BOOLEAN DEFAULT FALSE,
            can_manage_users BOOLEAN DEFAULT FALSE,
            can_assign_commanders BOOLEAN DEFAULT FALSE,
            is_system BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица roles создана');

    // ─────────────────────────────────────────
    // 3️⃣ user_roles
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS user_roles (
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
            assigned_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            assigned_at TIMESTAMPTZ DEFAULT NOW(),
            PRIMARY KEY (user_id, role_id)
        )
    `);
    console.log('   ✅ Таблица user_roles создана');

    // ─────────────────────────────────────────
    // 4️⃣ chats
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS chats (
            id SERIAL PRIMARY KEY,
            type VARCHAR(20) NOT NULL CHECK(type IN ('private', 'general', 'group', 'channel')),
            name VARCHAR(100),
            description TEXT,
            avatar VARCHAR(255),
            created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица chats создана');

    // ─────────────────────────────────────────
    // 5️⃣ chat_members
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS chat_members (
            chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role VARCHAR(10) DEFAULT 'member' CHECK(role IN ('admin', 'member')),
            joined_at TIMESTAMPTZ DEFAULT NOW(),
            last_read_message_id INTEGER,
            PRIMARY KEY (chat_id, user_id)
        )
    `);
    console.log('   ✅ Таблица chat_members создана');

    // ─────────────────────────────────────────
    // 6️⃣ messages
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            text TEXT,
            reply_to_id INTEGER REFERENCES messages(id) ON DELETE SET NULL,
            is_deleted BOOLEAN DEFAULT FALSE,
            is_edited BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица messages создана');

    // ─────────────────────────────────────────
    // 7️⃣ reactions
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS reactions (
            id SERIAL PRIMARY KEY,
            message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            emoji VARCHAR(10) NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE (message_id, user_id, emoji)
        )
    `);
    console.log('   ✅ Таблица reactions создана');

    // ─────────────────────────────────────────
    // 8️⃣ attachments
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS attachments (
            id SERIAL PRIMARY KEY,
            message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
            file_type VARCHAR(20) NOT NULL CHECK(file_type IN ('image', 'voice', 'file')),
            file_path VARCHAR(500) NOT NULL,
            file_name VARCHAR(255),
            file_size INTEGER,
            mime_type VARCHAR(100),
            duration INTEGER,
            width INTEGER,
            height INTEGER,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица attachments создана');

    // ─────────────────────────────────────────
    // 9️⃣ feed_events
    // ─────────────────────────────────────────
    await pool.query(`
        CREATE TABLE IF NOT EXISTS feed_events (
            id SERIAL PRIMARY KEY,
            type VARCHAR(20) NOT NULL CHECK(type IN ('announcement', 'schedule', 'achievement', 'new_member')),
            title VARCHAR(255) NOT NULL,
            content TEXT,
            author_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
            target_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
            event_date TIMESTAMPTZ,
            is_pinned BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    `);
    console.log('   ✅ Таблица feed_events создана');

    console.log('═══════════════════════════════════════');
}

// =====================================================
// ⚡ ИНДЕКСЫ
// =====================================================
async function createIndexes() {
    console.log('');
    console.log('⚡ СОЗДАНИЕ ИНДЕКСОВ');

    // messages
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages(reply_to_id)`);

    // chat_members
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON chat_members(user_id)`);

    // user_roles
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id)`);

    // reactions
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_reactions_message_id ON reactions(message_id)`);

    // attachments
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_attachments_message_id ON attachments(message_id)`);

    // feed_events
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_feed_events_type ON feed_events(type)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_feed_events_created_at ON feed_events(created_at DESC)`);

    // users
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_users_status ON users(status)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_users_lockout ON users(lockout_until)`);

    console.log('   ✅ Индексы созданы (11 штук)');
}

// =====================================================
// 🎭 СОЗДАНИЕ РОЛЕЙ ПО УМОЛЧАНИЮ
// =====================================================
async function createDefaultRoles() {
    console.log('');
    console.log('🎭 СОЗДАНИЕ РОЛЕЙ');

    const existing = await pool.query('SELECT id FROM roles LIMIT 1');
    if (existing.rows.length > 0) {
        console.log('   ℹ️  Роли уже существуют — пропускаем');
        const admin = await pool.query(`SELECT id FROM roles WHERE name = 'Администратор'`);
        return { adminRoleId: admin.rows[0]?.id };
    }

    // 1️⃣ Администратор
    const adminRole = await pool.query(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders, is_system
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id
    `, [
        'Администратор',
        'Технический администратор. Управляет всеми пользователями и назначает командиров.',
        '#9C27B0', '👑', 1000,
        true, true, false,
        true, true, true,
        true, true, true,
    ]);
    const adminRoleId = adminRole.rows[0].id;
    console.log(`   ✅ Роль "Администратор" создана (ID: ${adminRoleId})`);

    // 2️⃣ Командир
    const commanderRole = await pool.query(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders, is_system
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id
    `, [
        'Командир',
        'Командир команды. Ведёт состав, подтверждает новобранцев, создаёт события в ленте.',
        '#E31E24', '🎖️', 100,
        true, true, false,
        true, true, false,
        false, false, true,
    ]);
    console.log(`   ✅ Роль "Командир" создана (ID: ${commanderRole.rows[0].id})`);

    // 3️⃣ Боец
    const soldierRole = await pool.query(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders, is_system
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id
    `, [
        'Боец',
        'Полноправный боец команды. Пишет в общий чат и в личные сообщения.',
        '#00843D', '🪖', 50,
        true, true, false,
        false, false, false,
        false, false, true,
    ]);
    console.log(`   ✅ Роль "Боец" создана (ID: ${soldierRole.rows[0].id})`);

    // 4️⃣ Новобранец
    const recruitRole = await pool.query(`
        INSERT INTO roles (
            name, description, color, icon, priority,
            can_write_general, can_write_private, can_write_to_commander,
            can_create_feed, can_approve_users, can_manage_roles,
            can_manage_users, can_assign_commanders, is_system
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id
    `, [
        'Новобранец',
        'Новичок на испытательном сроке. Читает общий чат, пишет только командиру.',
        '#FED100', '🆕', 10,
        false, false, true,
        false, false, false,
        false, false, true,
    ]);
    console.log(`   ✅ Роль "Новобранец" создана (ID: ${recruitRole.rows[0].id})`);

    return { adminRoleId };
}

// =====================================================
// 👑 СОЗДАНИЕ АДМИНИСТРАТОРА
// =====================================================
async function createDefaultAdmin(adminRoleId) {
    console.log('');
    console.log('👑 СОЗДАНИЕ АДМИНИСТРАТОРА');

    const existing = await pool.query('SELECT id FROM users WHERE username = $1', ['admin']);
    if (existing.rows.length > 0) {
        console.log('   ℹ️  Пользователь "admin" уже существует — пропускаем');
        return existing.rows[0].id;
    }

    const { hashPasswordSync } = require('../utils/password');
    const passwordHash = hashPasswordSync('admin_secret_2024');

    const userResult = await pool.query(`
        INSERT INTO users (username, password, display_name, status, is_approved)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id
    `, ['admin', passwordHash, 'Администратор', 'offline', true]);

    const adminUserId = userResult.rows[0].id;
    console.log(`   ✅ Пользователь "admin" создан (ID: ${adminUserId})`);
    console.log(`      🔑 Пароль: admin_secret_2024 (смените после входа!)`);

    // Привязываем роль
    await pool.query(`
        INSERT INTO user_roles (user_id, role_id, assigned_by)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
    `, [adminUserId, adminRoleId, adminUserId]);
    console.log(`   ✅ Роль "Администратор" привязана`);

    return adminUserId;
}

// =====================================================
// 💬 СОЗДАНИЕ ОБЩЕГО ЧАТА
// =====================================================
async function createGeneralChat(adminUserId) {
    const existing = await pool.query(`SELECT id FROM chats WHERE type = 'general' LIMIT 1`);
    if (existing.rows.length > 0) {
        console.log('   ℹ️  Общий чат уже существует');
        return existing.rows[0].id;
    }

    const chatResult = await pool.query(`
        INSERT INTO chats (type, name, description, created_by)
        VALUES ($1, $2, $3, $4)
        RETURNING id
    `, ['general', 'Общий чат', 'Общий чат команды "Отряд Боба Марли"', adminUserId]);

    const generalChatId = chatResult.rows[0].id;
    console.log(`   ✅ Общий чат создан (ID: ${generalChatId})`);

    await pool.query(`
        INSERT INTO chat_members (chat_id, user_id, role)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
    `, [generalChatId, adminUserId, 'admin']);

    console.log(`   ✅ Admin добавлен в общий чат`);
    return generalChatId;
}

// =====================================================
// 📋 ПРИВЕТСТВЕННОЕ СОБЫТИЕ
// =====================================================
async function createWelcomeEvent(adminUserId) {
    const existing = await pool.query(`
        SELECT id FROM feed_events WHERE type = 'announcement' LIMIT 1
    `);
    if (existing.rows.length > 0) {
        console.log('   ℹ️  Приветственное событие уже есть');
        return;
    }

    await pool.query(`
        INSERT INTO feed_events (type, title, content, author_id, is_pinned)
        VALUES ($1, $2, $3, $4, $5)
    `, [
        'announcement',
        '🎉 Добро пожаловать в BMSChat!',
        'Приложение создано для команды "Отряд Боба Марли". One Love! ✌️',
        adminUserId,
        true,
    ]);

    console.log(`   ✅ Приветственное событие добавлено`);
}

// =====================================================
// 🚀 ГЛАВНАЯ ФУНКЦИЯ
// =====================================================
async function initDatabase() {
    try {
        console.log('');
        console.log('═══════════════════════════════════════');
        console.log('🎯 BMSChat — ИНИЦИАЛИЗАЦИЯ POSTGRESQL');
        console.log('═══════════════════════════════════════');

        // Проверка подключения
        const time = await pool.query('SELECT NOW()');
        console.log('✅ Подключено к PostgreSQL');
        console.log(`   Время сервера: ${time.rows[0].now}`);

        // Создание таблиц
        await createTables();

        // Индексы
        await createIndexes();

        // Роли
        const { adminRoleId } = await createDefaultRoles();

        // Администратор
        const adminUserId = await createDefaultAdmin(adminRoleId);

        // Общий чат
        await createGeneralChat(adminUserId);

        // Приветствие
        await createWelcomeEvent(adminUserId);

        // Список таблиц
        const tables = await pool.query(`
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name
        `);

        console.log('');
        console.log('📊 ТАБЛИЦЫ В БАЗЕ:');
        tables.rows.forEach((t) => {
            console.log(`   ✅ ${t.table_name}`);
        });

        console.log('');
        console.log('✅ БАЗА ДАННЫХ ГОТОВА!');
        console.log('═══════════════════════════════════════');
        console.log('');

        await pool.end();
        console.log('🔒 Соединение закрыто');
        process.exit(0);
    } catch (error) {
        console.error('');
        console.error('❌ ОШИБКА ИНИЦИАЛИЗАЦИИ:');
        console.error(error.message);
        console.error(error.stack);

        await pool.end().catch(() => {});
        process.exit(1);
    }
}

// =====================================================
// 📤 ЭКСПОРТ
// =====================================================
module.exports = { pool };

// Запуск при прямом вызове
if (require.main === module) {
    initDatabase();
}