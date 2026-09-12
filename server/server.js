// =====================================================
// 🎯 ОТРЯД БОБА МАРЛИ — СЕРВЕР
// =====================================================

const express = require('express');
const app = express();

const PORT = process.env.PORT || 5000;

// Middleware для чтения JSON
app.use(express.json());

// =====================================================
// 📡 РОУТЫ
// =====================================================

// Корневой роут
app.get('/', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'Сервер Отряда Боба Марли работает! 🎯',
        time: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Health-check (понадобится для UptimeRobot)
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
    });
});

// Тестовый роут
app.get('/api/test', (req, res) => {
    res.json({ 
        message: 'API работает!',
        path: '/api/test'
    });
});

// =====================================================
// 🚀 ЗАПУСК
// =====================================================

app.listen(PORT, '0.0.0.0', () => {
    console.log('');
    console.log('═══════════════════════════════════════');
    console.log('🎯 ОТРЯД БОБА МАРЛИ — СЕРВЕР ЗАПУЩЕН');
    console.log('═══════════════════════════════════════');
    console.log(`🚀 Порт: ${PORT}`);
    console.log(`📡 http://localhost:${PORT}`);
    console.log(`📡 http://localhost:${PORT}/api/health`);
    console.log(`📡 http://localhost:${PORT}/api/test`);
    console.log('');
    console.log('⛔ Для остановки: Ctrl+C');
    console.log('═══════════════════════════════════════');
});