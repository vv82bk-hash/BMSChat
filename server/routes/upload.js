// =====================================================
// 📤 BMSChat — ЗАГРУЗКА ФАЙЛОВ (PostgreSQL BYTEA)
// =====================================================
// POST /api/upload
// Файл сохраняется прямо в БД (колонка file_data).
// 🎤 ГОЛОСОВЫЕ: вычисляем duration через music-metadata
// 📄 ДОКУМЕНТЫ: PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX,
//    TXT, CSV, ZIP/RAR/7Z, APK (безопасный список)
// =====================================================

const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');
const mm = require('music-metadata');

const { authMiddleware } = require('../middleware/auth');
const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 💾 ХРАНИЛИЩЕ MULTER — в памяти!
// =====================================================
const storage = multer.memoryStorage();

// =====================================================
// 🛡️ ФИЛЬТР ФАЙЛОВ — БЕЗОПАСНЫЙ СПИСОК
// =====================================================
const ALLOWED_MIME_TYPES = [
    // ─── Изображения ───
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',

    // ─── Аудио (голосовые) ───
    'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/webm',
    'audio/ogg', 'audio/aac', 'audio/x-m4a',

    // ─── Документы ───
    'application/pdf',
    'application/msword',                                                   // .doc
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
    'application/vnd.ms-excel',                                             // .xls
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',    // .xlsx
    'application/vnd.ms-powerpoint',                                        // .ppt
    'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
    'text/plain',                                                           // .txt
    'text/csv',                                                             // .csv

    // ─── Архивы ───
    'application/zip',
    'application/x-zip-compressed',
    'application/vnd.rar',
    'application/x-rar-compressed',
    'application/x-7z-compressed',

    // ─── Мобильные пакеты ───
    'application/vnd.android.package-archive',                              // .apk

    // ─── Fallback: браузеры часто не знают MIME ───
    'application/octet-stream',
];

const ALLOWED_EXTENSIONS = [
    // Изображения
    '.jpg', '.jpeg', '.png', '.gif', '.webp',

    // Аудио
    '.mp3', '.m4a', '.wav', '.webm', '.ogg', '.aac',

    // Документы
    '.pdf', '.doc', '.docx', '.xls', '.xlsx',
    '.ppt', '.pptx', '.txt', '.csv',

    // Архивы
    '.zip', '.rar', '.7z',

    // Мобильные
    '.apk',
];

const fileFilter = (_req, file, cb) => {
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
        return cb(null, true);
    }

    // Fallback: некоторые клиенты/ОС отдают generic MIME.
    // Проверяем по расширению.
    if (file.mimetype === 'application/octet-stream') {
        const ext = path.extname(file.originalname).toLowerCase();
        if (ALLOWED_EXTENSIONS.includes(ext)) {
            return cb(null, true);
        }
    }

    cb(new Error(`Недопустимый тип файла: ${file.mimetype}`));
};

const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: 10 * 1024 * 1024 },
});

// =====================================================
// 🎤 ВЫЧИСЛЕНИЕ ДЛИТЕЛЬНОСТИ АУДИО
// =====================================================
// Возвращает секунды (int) или null при ошибке.
async function extractAudioDuration(buffer, mimeType) {
    try {
        const metadata = await mm.parseBuffer(buffer, { mimeType });
        const duration = metadata.format.duration;

        if (!duration || !isFinite(duration)) {
            return null;
        }

        return Math.round(duration);
    } catch (err) {
        logger.warn('Не удалось определить длительность аудио', {
            error: err.message,
            mimeType,
        });
        return null;
    }
}

// =====================================================
// 📤 POST /api/upload
// =====================================================
router.post('/', authMiddleware, (req, res) => {
    upload.single('file')(req, res, async (err) => {
        if (err) {
            if (err instanceof multer.MulterError) {
                if (err.code === 'LIMIT_FILE_SIZE') {
                    return res.status(413).json({
                        error: 'Файл слишком большой (максимум 10 МБ)',
                    });
                }
                return res.status(400).json({ error: err.message });
            }
            logger.warn('Ошибка загрузки', { error: err.message });
            return res.status(400).json({ error: err.message });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'Файл не получен' });
        }

        try {
            // ─────────────────────────────────────────
            // Определяем тип
            // ─────────────────────────────────────────
            let fileType = req.body.type || 'file';
            const ext = path.extname(req.file.originalname).toLowerCase();

            if (req.file.mimetype.startsWith('image/')) {
                fileType = 'image';
            } else if (req.file.mimetype.startsWith('audio/')) {
                fileType = 'voice';
            } else if (req.file.mimetype === 'application/octet-stream') {
                // Fallback: угадываем по расширению
                if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
                    fileType = 'image';
                } else if (
                    ['.mp3', '.m4a', '.wav', '.webm', '.ogg', '.aac'].includes(ext)
                ) {
                    fileType = 'voice';
                } else {
                    fileType = 'file';
                }
            } else {
                fileType = 'file';
            }

            // ─────────────────────────────────────────
            // 🎤 Длительность для аудио
            // ─────────────────────────────────────────
            let duration = null;
            if (fileType === 'voice') {
                duration = await extractAudioDuration(
                    req.file.buffer,
                    req.file.mimetype,
                );
                logger.info('Длительность аудио определена', {
                    name: req.file.originalname,
                    duration,
                });
            }

            // ─────────────────────────────────────────
            // Сохраняем файл в БД (BYTEA)
            // ─────────────────────────────────────────
            const fileId = crypto.randomBytes(16).toString('hex');

            const result = await pool.query(`
                INSERT INTO uploaded_files (
                    id, user_id, file_data, file_name, file_size,
                    mime_type, file_type, duration, created_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
                RETURNING id, file_name, file_size, mime_type, file_type, duration
            `, [
                fileId,
                req.user.id,
                req.file.buffer,
                req.file.originalname,
                req.file.size,
                req.file.mimetype,
                fileType,
                duration,
            ]);

            const saved = result.rows[0];

            logger.success('Файл загружен в БД', {
                userId: req.user.id,
                fileId: saved.id,
                name: saved.file_name,
                size: saved.file_size,
                type: saved.file_type,
                duration: saved.duration,
            });

            res.status(201).json({
                file_path: `/api/files/${saved.id}`,
                file_id: saved.id,
                file_name: saved.file_name,
                file_size: saved.file_size,
                mime_type: saved.mime_type,
                file_type: saved.file_type,
                duration: saved.duration,
            });
        } catch (error) {
            logger.error('Ошибка обработки загрузки', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    });
});

module.exports = router;