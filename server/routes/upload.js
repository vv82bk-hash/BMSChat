// =====================================================
// 📤 BMSChat — ЗАГРУЗКА ФАЙЛОВ (PostgreSQL)
// =====================================================
// POST /api/upload
// =====================================================

const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const { authMiddleware } = require('../middleware/auth');
const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 📁 ПАПКА UPLOADS
// =====================================================
const uploadsDir = path.join(__dirname, '..', 'uploads');

if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
    logger.info('Создана папка uploads', { path: uploadsDir });
}

// =====================================================
// 💾 ХРАНИЛИЩЕ MULTER
// =====================================================
const storage = multer.diskStorage({
    destination: (_req, _file, cb) => {
        cb(null, uploadsDir);
    },
    filename: (_req, file, cb) => {
        const ext = path.extname(file.originalname).toLowerCase();
        const unique = crypto.randomBytes(8).toString('hex');
        const filename = `${Date.now()}_${unique}${ext}`;
        cb(null, filename);
    },
});

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

// =====================================================
// ⚙️ КОНФИГ MULTER
// =====================================================
const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: 10 * 1024 * 1024 },
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
            // Определяем тип
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

            const result = {
                file_path: `/uploads/${req.file.filename}`,
                file_name: req.file.originalname,
                file_size: req.file.size,
                mime_type: req.file.mimetype,
                file_type: fileType,
            };

            logger.success('Файл загружен', {
                userId: req.user.id,
                name: result.file_name,
                size: result.file_size,
                type: result.file_type,
            });

            res.status(201).json(result);
        } catch (error) {
            logger.error('Ошибка обработки загрузки', error);
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    });
});

module.exports = router;