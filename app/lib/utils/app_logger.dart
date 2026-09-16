// =====================================================
// 📝 BMSChat — ЛОГГЕР ПРИЛОЖЕНИЯ
// =====================================================
// Единый логгер для всего приложения.
//
// ЗАЧЕМ:
//   • В продакшене логи отключаются одной константой
//   • Единый формат: [уровень] [время] сообщение
//   • Легко заменить на пакет `logger` в будущем
//
// ИСПОЛЬЗОВАНИЕ:
//   AppLogger.info('Привет');
//   AppLogger.error('Ошибка', error);
//   AppLogger.socket('Событие', data);
// =====================================================

import 'package:flutter/foundation.dart';
import '../config/constants.dart';

class AppLogger {
    // =====================================================
    // 📊 ФЛАГИ
    // =====================================================
    
    /// Показывать ли логи в консоль
    /// В продакшене — false (см. Constants.enableLogs)
    static bool get _enabled => Constants.enableLogs && kDebugMode;

    // =====================================================
    // 🕒 ВРЕМЯ
    // =====================================================
    
    static String get _timestamp {
        final now = DateTime.now();
        final h = now.hour.toString().padLeft(2, '0');
        final m = now.minute.toString().padLeft(2, '0');
        final s = now.second.toString().padLeft(2, '0');
        return '$h:$m:$s';
    }

    // =====================================================
    // ℹ️ INFO — обычная информация
    // =====================================================
    
    static void info(String message, [dynamic data]) {
        if (!_enabled) return;
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('ℹ️ [$_timestamp] $message$dataStr');
    }

    // =====================================================
    // ✅ SUCCESS — успешное действие
    // =====================================================
    
    static void success(String message, [dynamic data]) {
        if (!_enabled) return;
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('✅ [$_timestamp] $message$dataStr');
    }

    // =====================================================
    // ⚠️ WARN — предупреждение
    // =====================================================
    
    static void warn(String message, [dynamic data]) {
        if (!_enabled) return;
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('⚠️ [$_timestamp] $message$dataStr');
    }

    // =====================================================
    // ❌ ERROR — ошибка
    // =====================================================
    
    static void error(String message, [dynamic error, StackTrace? stackTrace]) {
        if (!_enabled) return;
        debugPrint('❌ [$_timestamp] $message');
        if (error != null) {
            debugPrint('   Ошибка: $error');
        }
        if (stackTrace != null && Constants.verboseErrors) {
            debugPrint('   Стек: $stackTrace');
        }
    }

    // =====================================================
    // 🌐 HTTP — запросы к API
    // =====================================================
    
    static void http(String method, String url, {int? statusCode, dynamic data}) {
        if (!_enabled) return;
        final status = statusCode != null ? ' [$statusCode]' : '';
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('🌐 [$_timestamp] $method $url$status$dataStr');
    }

    // =====================================================
    // 🔌 SOCKET — события WebSocket
    // =====================================================
    
    static void socket(String event, [dynamic data]) {
        if (!_enabled) return;
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('🔌 [$_timestamp] $event$dataStr');
    }

    // =====================================================
    // 🐛 DEBUG — подробная отладка
    // =====================================================
    
    static void debug(String message, [dynamic data]) {
        if (!_enabled) return;
        final dataStr = data != null ? ' → $data' : '';
        debugPrint('🐛 [$_timestamp] $message$dataStr');
    }

    // =====================================================
    // 📦 DATA — дамп данных
    // =====================================================
    
    static void data(String label, dynamic value) {
        if (!_enabled) return;
        debugPrint('📦 [$_timestamp] $label: $value');
    }
}