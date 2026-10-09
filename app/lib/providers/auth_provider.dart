// =====================================================
// 🔐 BMSChat — ПРОВАЙДЕР АВТОРИЗАЦИИ
// =====================================================
// Управляет состоянием авторизации:
//   • Текущий пользователь
//   • JWT-токен
//   • Статусы загрузки
//   • Вход / Регистрация / Выход
//
// НОВАЯ СИСТЕМА РОЛЕЙ:
//   • 4 роли: Администратор, Командир, Боец, Новобранец
//   • 8 прав
//   • Геттеры для быстрой проверки в UI
//
// 🎯 ПРОФИЛЬ: setUser() + updateProfile()
// 🔔 FCM: _sendFcmTokenToServer() при логине и старте
// 🔕 FCM: удаление токена при logout
// =====================================================

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/role.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
    // =====================================================
    // 📊 СОСТОЯНИЕ
    // =====================================================

    User? _user;
    bool _isLoading = false;
    String? _error;
    bool _isInitialized = false;

    // =====================================================
    // 📤 ГЕТТЕРЫ СОСТОЯНИЯ
    // =====================================================

    User? get user => _user;
    bool get isAuthenticated => _user != null;
    bool get isLoading => _isLoading;
    bool get hasError => _error != null;
    String? get error => _error;
    bool get isInitialized => _isInitialized;

    // =====================================================
    // 👑 ГЕТТЕРЫ РОЛЕЙ
    // =====================================================

    bool get isAdmin => _user?.isAdmin ?? false;
    bool get isCommander => _user?.isCommander ?? false;
    bool get isSoldier => _user?.isSoldier ?? false;
    bool get isRecruit => _user?.isRecruit ?? false;
    bool get isCommanderOrHigher => _user?.isCommanderOrHigher ?? false;

    Role? get primaryRole => _user?.primaryRole;
    List<Role> get roles => _user?.roles ?? [];

    // =====================================================
    // 🎯 ГЕТТЕРЫ ПРАВ (8 штук)
    // =====================================================

    bool get canWriteGeneral => _user?.canWriteGeneral ?? false;
    bool get canWritePrivate => _user?.canWritePrivate ?? false;
    bool get canWriteToCommander => _user?.canWriteToCommander ?? false;
    bool get canCreateFeed => _user?.canCreateFeed ?? false;
    bool get canApproveUsers => _user?.canApproveUsers ?? false;
    bool get canManageRoles => _user?.canManageRoles ?? false;
    bool get canManageUsers => _user?.canManageUsers ?? false;
    bool get canAssignCommanders => _user?.canAssignCommanders ?? false;

    // =====================================================
    // 🚀 ИНИЦИАЛИЗАЦИЯ
    // =====================================================

    Future<void> initialize() async {
        AppLogger.info('🔐 Инициализация авторизации');

        try {
            final token = await StorageService.getToken();
            final savedUser = await StorageService.getUser();

            if (token == null || token.isEmpty || savedUser == null) {
                AppLogger.info('Сохранённого токена нет');
                _isInitialized = true;
                notifyListeners();
                return;
            }

            AppLogger.info('Найден сохранённый токен, проверяем...');

            _user = savedUser;
            notifyListeners();

            final response = await ApiService.getMe();

            if (response.isSuccess && response.data != null) {
                _user = response.data;
                await StorageService.saveUser(_user!);
                AppLogger.success(
                    'Токен валиден: ${_user!.displayName} (${_user!.primaryRole?.name})'
                );

                await SocketService.connect(token);

                // 🔔 Отправляем FCM-токен на сервер
                await _sendFcmTokenToServer();

                _isInitialized = true;
                notifyListeners();
            } else {
                AppLogger.warn('Токен невалиден: ${response.error}');
                await _clearAuth();
                _isInitialized = true;
                notifyListeners();
            }
        } catch (e) {
            AppLogger.error('Ошибка инициализации', e);
            await _clearAuth();
            _isInitialized = true;
            notifyListeners();
        }
    }

    // =====================================================
    // 🔑 ВХОД
    // =====================================================

    Future<bool> login(String username, String password) async {
        AppLogger.info('🔑 Попытка входа: $username');

        _isLoading = true;
        _error = null;
        notifyListeners();

        try {
            final response = await ApiService.login(username, password);

            if (!response.isSuccess) {
                _error = response.error ?? 'Ошибка входа';
                _isLoading = false;
                AppLogger.warn('Ошибка входа: $_error');
                notifyListeners();
                return false;
            }

            final data = response.data!;
            final token = data['token'] as String;
            final userJson = data['user'] as Map<String, dynamic>;
            final user = User.fromJson(userJson);

            await StorageService.saveToken(token);
            await StorageService.saveUser(user);

            _user = user;
            _isLoading = false;
            _error = null;

            final roleName = user.primaryRole?.name ?? 'без роли';
            AppLogger.success(
                'Вход выполнен: ${user.displayName} [$roleName]'
            );

            await SocketService.connect(token);

            // 🔔 Отправляем FCM-токен на сервер
            await _sendFcmTokenToServer();

            notifyListeners();
            return true;
        } catch (e) {
            AppLogger.error('Ошибка входа', e);
            _error = 'Ошибка сети. Проверьте подключение.';
            _isLoading = false;
            notifyListeners();
            return false;
        }
    }

    // =====================================================
    // 📝 РЕГИСТРАЦИЯ
    // =====================================================

    Future<bool> register(
        String username,
        String password,
        String displayName,
    ) async {
        AppLogger.info('📝 Регистрация: $username');

        _isLoading = true;
        _error = null;
        notifyListeners();

        try {
            final response = await ApiService.register(
                username,
                password,
                displayName,
            );

            if (!response.isSuccess) {
                _error = response.error ?? 'Ошибка регистрации';
                _isLoading = false;
                AppLogger.warn('Ошибка регистрации: $_error');
                notifyListeners();
                return false;
            }

            AppLogger.success('Регистрация успешна: $username');
            AppLogger.info('Ожидание подтверждения командиром');

            _isLoading = false;
            _error = null;
            notifyListeners();
            return true;
        } catch (e) {
            AppLogger.error('Ошибка регистрации', e);
            _error = 'Ошибка сети. Проверьте подключение.';
            _isLoading = false;
            notifyListeners();
            return false;
        }
    }

    // =====================================================
    // 🚪 ВЫХОД
    // =====================================================

    Future<void> logout() async {
        AppLogger.info('🚪 Выход из аккаунта');

        _isLoading = true;
        notifyListeners();

        try {
            // 🔕 Удаляем FCM-токен ПОКА авторизация ещё активна:
            //    1. На сервере — обнуляем users.fcm_token.
            //    2. Локально — удаляем из Firebase и SharedPreferences.
            await _removeFcmToken();

            await ApiService.logout();
            SocketService.disconnect();
            await _clearAuth();

            _isLoading = false;
            notifyListeners();

            AppLogger.success('Выход выполнен');
        } catch (e) {
            AppLogger.error('Ошибка выхода', e);
            await _clearAuth();
            _isLoading = false;
            notifyListeners();
        }
    }

    // =====================================================
    // 🔄 ОБНОВЛЕНИЕ ПРОФИЛЯ И ПРАВ
    // =====================================================

    /// Обновить данные текущего пользователя с сервера.
    Future<void> refreshUser() async {
        if (_user == null) return;

        AppLogger.info('🔄 Обновление профиля...');

        try {
            final response = await ApiService.getMe();
            if (response.isSuccess && response.data != null) {
                final oldRole = _user!.primaryRole?.name;
                _user = response.data;
                await StorageService.saveUser(_user!);
                final newRole = _user!.primaryRole?.name;

                if (oldRole != newRole) {
                    AppLogger.success('Роль изменилась: $oldRole → $newRole');
                } else {
                    AppLogger.info('Профиль обновлён');
                }
                notifyListeners();
            }
        } catch (e) {
            AppLogger.error('Ошибка обновления профиля', e);
        }
    }

    /// Установить пользователя напрямую (например, после updateProfile).
    Future<void> setUser(User user) async {
        _user = user;
        await StorageService.saveUser(user);
        notifyListeners();
        AppLogger.info('👤 Пользователь обновлён: ${user.displayName}');
    }

    /// Обновить профиль (имя и/или аватар) на сервере.
    Future<bool> updateProfile({
        String? displayName,
        String? avatar,
    }) async {
        if (_user == null) {
            AppLogger.warn('updateProfile: пользователь не авторизован');
            return false;
        }

        if (displayName == null && avatar == null) {
            AppLogger.warn('updateProfile: нечего обновлять');
            return false;
        }

        _isLoading = true;
        notifyListeners();

        try {
            final response = await ApiService.updateProfile(
                displayName: displayName,
                avatar: avatar,
            );

            if (!response.isSuccess || response.data == null) {
                _error = response.error ?? 'Ошибка обновления профиля';
                _isLoading = false;
                AppLogger.warn('Ошибка updateProfile: $_error');
                notifyListeners();
                return false;
            }

            _user = response.data;
            await StorageService.saveUser(_user!);

            _isLoading = false;
            _error = null;
            notifyListeners();

            AppLogger.success('Профиль обновлён: ${_user!.displayName}');
            return true;
        } catch (e) {
            AppLogger.error('Ошибка updateProfile', e);
            _error = 'Ошибка сети';
            _isLoading = false;
            notifyListeners();
            return false;
        }
    }

    // =====================================================
    // 🔔 FCM-ТОКЕН
    // =====================================================

    /// Отправляет текущий FCM-токен устройства на сервер.
    /// Вызывается при логине и при старте (если токен сохранён).
    /// Не критично: если не получилось — просто логируем.
    Future<void> _sendFcmTokenToServer() async {
        try {
            final fcmToken = await NotificationService.getFcmToken();

            if (fcmToken == null || fcmToken.isEmpty) {
                AppLogger.warn('FCM-токен ещё не получен, пропускаем');
                return;
            }

            final response = await ApiService.sendFcmToken(fcmToken);

            if (response.isSuccess) {
                AppLogger.success(
                    'FCM-токен отправлен на сервер: '
                    '${fcmToken.substring(0, 20)}...',
                );
            } else {
                AppLogger.warn(
                    'Не удалось отправить FCM-токен: ${response.error}',
                );
            }
        } catch (e) {
            AppLogger.error('Ошибка отправки FCM-токена', e);
        }
    }

    /// Удаляет FCM-токен:
    ///   1. На сервере — обнуляет users.fcm_token.
    ///   2. Локально — Firebase + SharedPreferences.
    /// Вызывается при logout ПОКА авторизация активна.
    Future<void> _removeFcmToken() async {
        try {
            // 1. На сервере
            final response = await ApiService.deleteFcmToken();
            if (response.isSuccess) {
                AppLogger.info('FCM-токен удалён на сервере');
            } else {
                AppLogger.warn(
                    'Не удалось удалить FCM-токен на сервере: ${response.error}',
                );
            }
        } catch (e) {
            AppLogger.error('Ошибка удаления FCM-токена на сервере', e);
        }

        try {
            // 2. Локально
            await NotificationService.deleteFcmToken();
        } catch (e) {
            AppLogger.error('Ошибка локального удаления FCM-токена', e);
        }
    }

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ
    // =====================================================

    Future<void> _clearAuth() async {
        _user = null;
        _error = null;
        await StorageService.clearAll();
    }

    void clearError() {
        _error = null;
        notifyListeners();
    }

    // =====================================================
    // 📊 ОТЛАДКА
    // =====================================================

    void debugPrintState() {
        if (_user == null) {
            AppLogger.debug('AuthProvider: не авторизован');
            return;
        }

        final roles = _user!.roles.map((r) => r.name).join(', ');
        AppLogger.debug('AuthProvider: ${_user!.displayName} [$roles]');
        AppLogger.debug(
            'Права: general=$canWriteGeneral, '
            'private=$canWritePrivate, '
            'to_commander=$canWriteToCommander, '
            'approve=$canApproveUsers, '
            'manage_users=$canManageUsers, '
            'assign_commanders=$canAssignCommanders'
        );
    }
}