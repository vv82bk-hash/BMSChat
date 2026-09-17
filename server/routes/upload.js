// =====================================================
// 📤 BMSChat — ЗАГРУЗКА ФАЙЛОВ (PostgreSQL BYTEA)
// =====================================================
// POST /api/upload
// Файл сохраняется прямо в БД (колонка file_data).
// =====================================================

const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const crypto = require('crypto');

const { authMiddleware } = require('../middleware/auth');
const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 💾 ХРАНИЛИЩЕ MULTER — в памяти!
// =====================================================
// ВАЖНО: storage = memoryStorage, а не diskStorage.
// Файл попадает в req.file.buffer и потом пишется в БД.
// =====================================================
const storage = multer.memoryStorage();

// =====================================================
// 🛡️ ФИЛЬТР ФАЙЛОВ
// =====================================================
const ALLOWED_MIME_TYPES = [
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/webm',
    'audio/ogg', 'audio/aac', 'audio/x-m4a',
    'application/pdf',
    'application/octet-stream',
];

const ALLOWED_EXTENSIONS = [
    '.jpg', '.jpeg', '.png', '.gif', '.webp',
    '.mp3', '.m4a', '.wav', '.webm', '.ogg', '.aac',
    '.pdf',
];

const fileFilter = (_req, file, cb) => {
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
        return cb(null, true);
    }

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
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

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
            if (req.file.mimetype.startsWith('image/')) {
                fileType = 'image';
            } else if (req.file.mimetype.startsWith('audio/')) {
                fileType = 'voice';
            } else if (req.file.mimetype === 'application/octet-stream') {
                const ext = path.extname(req.file.originalname).toLowerCase();
                if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
                    fileType = 'image';
                } else if (['.mp3', '.m4a', '.wav', '.webm', '.ogg', '.aac'].includes(ext)) {
                    fileType = 'voice';
                } else {
                    fileType = 'file';
                }
            }

            // ─────────────────────────────────────────
            // Сохраняем файл в БД (BYTEA)
            // ─────────────────────────────────────────
            const fileId = crypto.randomBytes(16).toString('hex');

            const result = await pool.query(`
                INSERT INTO uploaded_files (
                    id, user_id, file_data, file_name, file_size,
                    mime_type, file_type, created_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
                RETURNING id, file_name, file_size, mime_type, file_type
            `, [
                fileId,
                req.user.id,
                req.file.buffer,
                req.file.originalname,
                req.file.size,
                req.file.mimetype,
                fileType,
            ]);

            const saved = result.rows[0];

            logger.success('Файл загружен в БД', {
                userId: req.user.id,
                fileId: saved.id,
                name: saved.file_name,
                size: saved.file_size,
                type: saved.file_type,
            });

            res.status(201).json({
                file_path: `/api/files/${saved.id}`,
                file_id: saved.id,
                file_name: saved.file_name,
                file_size: saved.file_size,
                mime_type: saved.mime_type,
                file_type: saved.file_type,
            });
        } catch (error) {
            logger.error('Ошибка обработки загрузки', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    });
});

module.exports = router;