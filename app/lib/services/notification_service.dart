// =====================================================
// 🔔 BMSChat — СЕРВИС УВЕДОМЛЕНИЙ (FCM + локальные)
// =====================================================
// 🎯 Задачи:
//   • Инициализация Firebase Messaging
//   • Инициализация flutter_local_notifications (foreground)
//   • Запрос разрешения на уведомления (Android 13+)
//   • Получение FCM-токена (отправка на сервер — в AuthProvider)
//   • Показ локального уведомления при foreground-push
//   • Обработка тапа по уведомлению (переход в чат)
//   • Mute: не показывать уведомления для замьюченных чатов
// 🎯 Обновление токена: при onTokenRefresh — отправка на сервер
// =====================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Фоновый обработчик FCM.
/// Вызывается, когда приложение свёрнуто/закрыто.
/// Должен быть top-level функцией (не методом класса).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint('📩 FCM background: ${message.messageId}');
}

class NotificationService {
    // =====================================================
    // 📊 СОСТОЯНИЕ
    // =====================================================

    static final FlutterLocalNotificationsPlugin _localNotifications =
        FlutterLocalNotificationsPlugin();

    static bool _initialized = false;

    // 🎯 Android-канал уведомлений (тот же, что в манифесте)
    static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
        'messages_channel',
        'Сообщения',
        description: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
    );

    // 🎯 Callback: что делать при тапе по уведомлению.
    // Устанавливается извне (например, из MainScreen).
    static void Function(String? chatId)? onNotificationTap;

    // 🎯 Множество ID замьюченных чатов.
    // Обновляется из ChatProvider при toggleMute и loadChats.
    static final Set<int> _mutedChatIds = {};

    // =====================================================
    // 🚀 ИНИЦИАЛИЗАЦИЯ
    // =====================================================

    /// Главный метод инициализации.
    /// Вызывается в main() после Firebase.initializeApp().
    static Future<void> init() async {
        if (_initialized) return;

        try {
            // ─────────────────────────────────────────
            // 1. FCM: фоновый обработчик
            // ─────────────────────────────────────────
            FirebaseMessaging.onBackgroundMessage(
                _firebaseMessagingBackgroundHandler,
            );

            // ─────────────────────────────────────────
            // 2. Локальные уведомления
            // ─────────────────────────────────────────
            await _initLocalNotifications();

            // ─────────────────────────────────────────
            // 3. Разрешение на уведомления
            // ─────────────────────────────────────────
            await _requestPermission();

            // ─────────────────────────────────────────
            // 4. FCM-токен → в SharedPreferences
            // ─────────────────────────────────────────
            await _saveFcmToken();
            _listenTokenRefresh();

            // ─────────────────────────────────────────
            // 5. Слушаем входящие push (foreground)
            // ─────────────────────────────────────────
            FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

            // ─────────────────────────────────────────
            // 6. Слушаем тап по уведомлению (app был в фоне)
            // ─────────────────────────────────────────
            FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

            // ─────────────────────────────────────────
            // 7. Проверяем, не запущено ли приложение из уведомления
            // ─────────────────────────────────────────
            final initialMessage =
                await FirebaseMessaging.instance.getInitialMessage();
            if (initialMessage != null) {
                _handleMessageOpened(initialMessage);
            }

            _initialized = true;
            debugPrint('🔔 NotificationService инициализирован');
        } catch (e) {
            debugPrint('❌ Ошибка инициализации NotificationService: $e');
        }
    }

    // =====================================================
    // 🔧 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
    // =====================================================

    static Future<void> _initLocalNotifications() async {
        // Иконка уведомления (@mipmap/ic_launcher)
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

        // iOS-настройки (пока не используем, но нужны для сборки)
        const iosInit = DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
        );

        const initSettings = InitializationSettings(
            android: androidInit,
            iOS: iosInit,
        );

        await _localNotifications.initialize(
            initSettings,
            onDidReceiveNotificationResponse: (response) {
                // Тап по локальному уведомлению
                final chatId = response.payload;
                onNotificationTap?.call(chatId);
            },
        );

        // 🎯 Создаём Android-канал (важно для Android 8+)
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
            await androidPlugin.createNotificationChannel(_channel);
        }
    }

    static Future<void> _requestPermission() async {
        final settings = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
        );

        debugPrint(
            '🔔 Разрешение на уведомления: ${settings.authorizationStatus}',
        );
    }

    static Future<void> _saveFcmToken() async {
        try {
            final token = await FirebaseMessaging.instance.getToken();
            if (token == null) return;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fcm_token', token);

            debugPrint('🔑 FCM-токен сохранён: ${token.substring(0, 20)}...');
        } catch (e) {
            debugPrint('❌ Ошибка получения FCM-токена: $e');
        }
    }

    static void _listenTokenRefresh() {
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fcm_token', newToken);
            debugPrint('🔑 FCM-токен обновлён');

            // 🔔 Отправляем новый токен на сервер.
            // Пользователь может быть ещё не залогинен — тогда
            // ApiService.sendFcmToken вернёт 401, и мы просто залогируем.
            try {
                final response = await ApiService.sendFcmToken(newToken);
                if (response.isSuccess) {
                    debugPrint('🔔 Новый FCM-токен отправлен на сервер');
                } else {
                    debugPrint(
                        '⚠️ Не удалось отправить FCM-токен: ${response.error}',
                    );
                }
            } catch (e) {
                debugPrint('❌ Ошибка отправки FCM-токена: $e');
            }
        });
    }

    // =====================================================
    // 📥 ОБРАБОТКА ВХОДЯЩИХ PUSH
    // =====================================================

    /// Foreground: показываем локальное уведомление
    static void _handleForegroundMessage(RemoteMessage message) {
        debugPrint('📩 FCM foreground: ${message.messageId}');

        final notification = message.notification;
        if (notification == null) return;

        // 🎯 Проверяем mute по chatId
        final chatIdStr = message.data['chatId']?.toString();
        final chatId = chatIdStr != null ? int.tryParse(chatIdStr) : null;

        if (chatId != null && _mutedChatIds.contains(chatId)) {
            debugPrint('🔕 Чат #$chatId замьючен — уведомление пропущено');
            return;
        }

        _showLocalNotification(
            title: notification.title ?? 'Новое сообщение',
            body: notification.body ?? '',
            payload: chatIdStr,
        );
    }

    /// Тап по уведомлению (когда приложение было в фоне/закрыто)
    static void _handleMessageOpened(RemoteMessage message) {
        debugPrint('👆 FCM tap: ${message.messageId}');
        final chatId = message.data['chatId']?.toString();
        onNotificationTap?.call(chatId);
    }

    // =====================================================
    // 🎨 ПОКАЗ ЛОКАЛЬНОГО УВЕДОМЛЕНИЯ
    // =====================================================

    static Future<void> _showLocalNotification({
        required String title,
        required String body,
        String? payload,
    }) async {
        final androidDetails = AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFFFED100),
            playSound: true,
            enableVibration: true,
        );

        const iosDetails = DarwinNotificationDetails();

        final details = NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
        );

        await _localNotifications.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title,
            body,
            details,
            payload: payload,
        );
    }

    // =====================================================
    // 🛠️ ПУБЛИЧНЫЕ МЕТОДЫ
    // =====================================================

    /// Получить сохранённый FCM-токен (например, для отправки на сервер).
    static Future<String?> getFcmToken() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('fcm_token');
    }

    /// Удалить FCM-токен (например, при logout).
    static Future<void> deleteFcmToken() async {
        try {
            await FirebaseMessaging.instance.deleteToken();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('fcm_token');
            debugPrint('🔑 FCM-токен удалён');
        } catch (e) {
            debugPrint('❌ Ошибка удаления FCM-токена: $e');
        }
    }

    // =====================================================
    // 🔕 MUTE — УПРАВЛЕНИЕ ЗАМЬЮЧЕННЫМИ ЧАТАМИ
    // =====================================================

    /// 🎯 Установить/снять mute для чата.
    /// Вызывается из ChatProvider.toggleMute.
    static void setChatMuted(int chatId, bool isMuted) {
        if (isMuted) {
            _mutedChatIds.add(chatId);
            debugPrint('🔕 Чат #$chatId добавлен в muted');
        } else {
            _mutedChatIds.remove(chatId);
            debugPrint('🔔 Чат #$chatId убран из muted');
        }
    }

    /// 🎯 Массовое обновление mute-статусов.
    /// Вызывается из ChatProvider.loadChats.
    static void setMutedChats(Iterable<int> mutedIds) {
        _mutedChatIds.clear();
        _mutedChatIds.addAll(mutedIds);
        debugPrint('🔕 Замьючено чатов: ${_mutedChatIds.length}');
    }

    /// 🎯 Замьючен ли чат?
    static bool isChatMuted(int chatId) {
        return _mutedChatIds.contains(chatId);
    }
}