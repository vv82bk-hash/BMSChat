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
// ИСПОЛЬЗОВАНИЕ В UI:
//   final auth = Provider.of<AuthProvider>(context);
//   if (auth.isAdmin) { ... }
//   if (auth.canWriteGeneral) { ... }
// =====================================================

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/role.dart';
import '../services/api_service.dart';
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
    // Быстрые проверки для UI.
    // Возвращают false, если пользователь не авторизован.

    /// Администратор (технический)?
    bool get isAdmin => _user?.isAdmin ?? false;

    /// Командир?
    bool get isCommander => _user?.isCommander ?? false;

    /// Боец?
    bool get isSoldier => _user?.isSoldier ?? false;

    /// Новобранец?
    bool get isRecruit => _user?.isRecruit ?? false;

    /// Командир или выше?
    bool get isCommanderOrHigher => _user?.isCommanderOrHigher ?? false;

    /// Главная роль пользователя
    Role? get primaryRole => _user?.primaryRole;

    /// Список ролей
    List<Role> get roles => _user?.roles ?? [];

    // =====================================================
    // 🎯 ГЕТТЕРЫ ПРАВ (8 штук)
    // =====================================================

    /// Может писать в общий чат
    bool get canWriteGeneral => _user?.canWriteGeneral ?? false;

    /// Может писать в личные чаты
    bool get canWritePrivate => _user?.canWritePrivate ?? false;

    /// Может писать лично командиру
    bool get canWriteToCommander => _user?.canWriteToCommander ?? false;

    /// Может создавать события в ленте
    bool get canCreateFeed => _user?.canCreateFeed ?? false;

    /// Может подтверждать новичков
    bool get canApproveUsers => _user?.canApproveUsers ?? false;

    /// Может управлять ролями
    bool get canManageRoles => _user?.canManageRoles ?? false;

    /// Может управлять пользователями (Admin)
    bool get canManageUsers => _user?.canManageUsers ?? false;

    /// Может назначать командиров (Admin)
    bool get canAssignCommanders => _user?.canAssignCommanders ?? false;

    // =====================================================
    // 🚀 ИНИЦИАЛИЗАЦИЯ
    // =====================================================

    /// Проверить сохранённый токен при запуске приложения
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

            // Сразу показываем пользователя (для скорости)
            _user = savedUser;
            notifyListeners();

            // Проверяем токен через сервер
            final response = await ApiService.getMe();

            if (response.isSuccess && response.data != null) {
                _user = response.data;
                await StorageService.saveUser(_user!);
                AppLogger.success(
                    'Токен валиден: ${_user!.displayName} (${_user!.primaryRole?.name})'
                );

                await SocketService.connect(token);

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

    /// Войти в систему
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

            // Извлекаем данные
            final data = response.data!;
            final token = data['token'] as String;
            final userJson = data['user'] as Map<String, dynamic>;
            final user = User.fromJson(userJson);

            // Сохраняем
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

    /// Зарегистрировать нового пользователя
    /// 
    /// ⚠️ После регистрации нужно ЖДАТЬ ПОДТВЕРЖДЕНИЯ командира.
    /// Роль выдаётся автоматически при подтверждении.
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

    /// Выйти из аккаунта
    Future<void> logout() async {
        AppLogger.info('🚪 Выход из аккаунта');

        _isLoading = true;
        notifyListeners();

        try {
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
    /// 
    /// ⚠️ ВАЖНО: вызывать после того, как командир изменил роль
    /// (например, повысил с новобранца до бойца).
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

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ
    // =====================================================

    /// Очистить авторизационные данные
    Future<void> _clearAuth() async {
        _user = null;
        _error = null;
        await StorageService.clearAll();
    }

    /// Сбросить ошибку (например, после показа SnackBar)
    void clearError() {
        _error = null;
        notifyListeners();
    }

    // =====================================================
    // 📊 ОТЛАДКА
    // =====================================================

    /// Вывести текущее состояние авторизации в лог
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