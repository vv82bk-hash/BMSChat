// =====================================================
// 📥 BMSChat — ОТДАЧА ФАЙЛОВ ИЗ БД
// =====================================================
// GET /api/files/:id
// =====================================================

const express = require('express');
const router = express.Router();

const { pool } = require('../database/init');
const logger = require('../utils/logger');

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

        res.setHeader('Content-Type', file.mime_type || 'application/octet-stream');
        res.setHeader(
            'Content-Disposition',
            `inline; filename="${encodeURIComponent(file.file_name)}"`
        );
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

        res.send(file.file_data);
    } catch (error) {
        logger.error('Ошибка отдачи файла', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

module.exports = router;