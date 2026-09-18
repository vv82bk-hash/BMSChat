// =====================================================
// 📥 BMSChat — ОТДАЧА ФАЙЛОВ ИЗ БД
// =====================================================
// GET /api/files/:id
// =====================================================

const express = require('express');
const router = express.Router();
const path = require('path');

const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 🎯 ОПРЕДЕЛЕНИЕ MIME-ТИПА ПО РАСШИРЕНИЮ
// =====================================================
// Flutter не всегда отправляет правильный MIME,
// поэтому определяем тип по расширению файла.
// =====================================================
const MIME_MAP = {
    // Изображения
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.svg': 'image/svg+xml',
    // Аудио
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.wav': 'audio/wav',
    '.webm': 'audio/webm',
    '.ogg': 'audio/ogg',
    '.aac': 'audio/aac',
    // Документы
    '.pdf': 'application/pdf',
    // Текст
    '.txt': 'text/plain',
    '.json': 'application/json',
};

/**
 * Определяет MIME-тип файла.
 * 
 * 1. Если `mime_type` в БД корректный (не octet-stream) — используем его.
 * 2. Иначе — определяем по расширению файла.
 * 3. Если и это не удалось — `application/octet-stream`.
 */
function detectContentType(mimeType, fileName) {
    // Если MIME уже корректный — используем его
    if (mimeType && mimeType !== 'application/octet-stream') {
        return mimeType;
    }

    // Определяем по расширению
    if (fileName) {
        const ext = path.extname(fileName).toLowerCase();
        if (MIME_MAP[ext]) {
            return MIME_MAP[ext];
        }
    }

    // Не удалось определить
    return 'application/octet-stream';
}

// =====================================================
// 📥 GET /api/files/:id
// =====================================================
// Публичный роут (без авторизации) — чтобы можно было
// показывать картинки в <img src="...">.
// =====================================================
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        if (!id || id.length !== 32) {
            return res.status(400).json({ error: 'Неверный ID файла' });
        }

        const result = await pool.query(`
            SELECT file_data, file_name, mime_type
            FROM uploaded_files
            WHERE id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Файл не найден' });
        }

        const file = result.rows[0];

        // 🎯 Определяем Content-Type правильно
        const contentType = detectContentType(file.mime_type, file.file_name);

        res.setHeader('Content-Type', contentType);
        res.setHeader(
            'Content-Disposition',
            `inline; filename="${encodeURIComponent(file.file_name)}"`
        );
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

        logger.debug('Отдача файла', {
            id,
            fileName: file.file_name,
            mimeType: file.mime_type,
            contentType,
        });

        res.send(file.file_data);
    } catch (error) {
        logger.error('Ошибка отдачи файла', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;