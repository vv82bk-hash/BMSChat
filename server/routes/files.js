// =====================================================
// 📥 BMSChat — ОТДАЧА ФАЙЛОВ ИЗ БД
// =====================================================

const express = require('express');
const router = express.Router();
const path = require('path');

const { pool } = require('../database/init');
const logger = require('../utils/logger');

// =====================================================
// 🎯 ОПРЕДЕЛЕНИЕ MIME-ТИПА ПО РАСШИРЕНИЮ
// =====================================================
const MIME_MAP = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.svg': 'image/svg+xml',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.wav': 'audio/wav',
    '.webm': 'audio/webm',
    '.ogg': 'audio/ogg',
    '.aac': 'audio/aac',
    '.pdf': 'application/pdf',
    '.txt': 'text/plain',
    '.json': 'application/json',
};

function detectContentType(mimeType, fileName) {
    if (mimeType && mimeType !== 'application/octet-stream') {
        return mimeType;
    }
    if (fileName) {
        const ext = path.extname(fileName).toLowerCase();
        if (MIME_MAP[ext]) {
            return MIME_MAP[ext];
        }
    }
    return 'application/octet-stream';
}

// =====================================================
// 📥 GET /api/files/:id
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

        // Проверяем, что file_data — Buffer
        if (!file.file_data) {
            return res.status(500).json({ error: 'Данные файла пусты' });
        }

        const contentType = detectContentType(file.mime_type, file.file_name);

        res.setHeader('Content-Type', contentType);
        res.setHeader(
            'Content-Disposition',
            `inline; filename="${encodeURIComponent(file.file_name)}"`
        );
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

        // 🎯 Отправляем Buffer напрямую
        res.send(Buffer.from(file.file_data));
    } catch (error) {
        logger.error('Ошибка отдачи файла', error);
        if (!res.headersSent) {
            res.status(500).json({ error: 'Ошибка сервера' });
        }
    }
});

module.exports = router;