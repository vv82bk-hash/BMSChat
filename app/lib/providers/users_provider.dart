// =====================================================
// 👥 BMSChat — ПРОВАЙДЕР ПОЛЬЗОВАТЕЛЕЙ
// =====================================================
// Управляет списком пользователей + заявками.
// 👑 Подписан на Socket.IO события new_recruit, pending_count.
//
// 🎯 ОБРАБОТКА ОШИБОК:
//   • _handleAction() — единая точка обработки ответов API
//   • _error заполняется реальным текстом от сервера + статусом
//   • Все ошибки логируются через AppLogger.warn
//   • try/catch больше не проглатывает исключения
// =====================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/app_logger.dart';

class UsersProvider extends ChangeNotifier {
    List<User> _users = [];
    List<User> _pendingUsers = [];
    bool _isLoading = false;
    bool _isLoadingPending = false;
    String? _error;
    int _pendingCount = 0;

    // Подписки на Socket
    StreamSubscription? _newRecruitSub;
    StreamSubscription? _pendingCountSub;

    // =====================================================
    // 📤 ГЕТТЕРЫ
    // =====================================================

    List<User> get allUsers => List.unmodifiable(_users);
    List<User> get onlineUsers => _users.where((u) => u.isOnline).toList();
    List<User> get offlineUsers => _users.where((u) => u.isOffline).toList();
    List<User> get pendingUsers => List.unmodifiable(_pendingUsers);

    bool get isLoading => _isLoading;
    bool get isLoadingPending => _isLoadingPending;
    String? get error => _error;
    bool get hasError => _error != null;
    int get count => _users.length;

    /// Количество заявок (из Socket или из локального списка)
    int get pendingCount => _pendingCount > 0 ? _pendingCount : _pendingUsers.length;

    /// Есть ли заявки?
    bool get hasPending => pendingCount > 0;

    // =====================================================
    // 🔌 SOCKET LISTENERS
    // =====================================================

    /// Инициализация Socket-слушателей.
    void initSocketListeners() {
        AppLogger.info('👑 Инициализация Socket-слушателей заявок');

        _newRecruitSub?.cancel();
        _newRecruitSub = SocketService.onNewRecruit.listen(_handleNewRecruit);

        _pendingCountSub?.cancel();
        _pendingCountSub = SocketService.onPendingCount.listen(_handlePendingCount);
    }

    void _handleNewRecruit(Map<String, dynamic> data) {
        try {
            final userJson = data['user'] as Map<String, dynamic>?;
            final count = data['pendingCount'] as int?;

            if (userJson != null) {
                final newUser = User.fromJson(userJson);
                _pendingUsers.insert(0, newUser);
                AppLogger.success('🔔 Новый новобранец: ${newUser.displayName}');
            }

            if (count != null) {
                _pendingCount = count;
            } else {
                _pendingCount = _pendingUsers.length;
            }

            notifyListeners();
        } catch (e) {
            AppLogger.error('Ошибка обработки new_recruit', e);
        }
    }

    void _handlePendingCount(int count) {
        _pendingCount = count;
        AppLogger.socket('📊 Заявок: $count');
        notifyListeners();
    }

    // =====================================================
    // 🔄 ЗАГРУЗКА
    // =====================================================

    Future<void> loadUsers() async {
        AppLogger.info('👥 Загрузка пользователей...');
        _isLoading = true;
        _error = null;
        notifyListeners();

        try {
            final response = await ApiService.getUsers();
            if (!response.isSuccess) {
                _error = response.error ?? 'Ошибка загрузки';
                _isLoading = false;
                notifyListeners();
                return;
            }
            _users = response.data!;
            _isLoading = false;
            _error = null;
            AppLogger.success('Загружено: ${_users.length}');
            notifyListeners();
        } catch (e) {
            AppLogger.error('Ошибка загрузки', e);
            _error = 'Ошибка сети';
            _isLoading = false;
            notifyListeners();
        }
    }

    Future<void> loadPendingUsers() async {
        _isLoadingPending = true;
        notifyListeners();
        try {
            final response = await ApiService.getPendingUsers();
            if (response.isSuccess) {
                _pendingUsers = response.data!;
                _pendingCount = _pendingUsers.length;
            }
            _isLoadingPending = false;
            notifyListeners();
        } catch (e) {
            _isLoadingPending = false;
            notifyListeners();
        }
    }

    // =====================================================
    // 🔍 ПОИСК
    // =====================================================

    User? getUserById(int id) {
        try {
            return _users.firstWhere((u) => u.id == id);
        } catch (_) {
            try {
                return _pendingUsers.firstWhere((u) => u.id == id);
            } catch (_) {
                return null;
            }
        }
    }

    List<User> search(String query) {
        if (query.trim().isEmpty) return allUsers;
        final q = query.toLowerCase().trim();
        return _users.where((u) {
            return u.displayName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q);
        }).toList();
    }

    // =====================================================
    // 🎭 ДЕЙСТВИЯ
    // =====================================================

    /// 🎯 Единая точка обработки ответа API на действия с пользователем.
    /// 
    /// Что делает:
    ///   • при успехе — очищает _error, опционально перезагружает список
    ///   • при ошибке — сохраняет РЕАЛЬНЫЙ текст от сервера в _error,
    ///     логирует через AppLogger.warn, уведомляет слушателей
    /// 
    /// Возвращает true при успехе.
    Future<bool> _handleAction(
        String actionName,
        ApiResponse<void> response, {
        bool reloadUsers = true,
    }) async {
        if (response.isSuccess) {
            _error = null;
            if (reloadUsers) await loadUsers();
            return true;
        }

        // 🎯 Сохраняем реальную ошибку для UI
        final rawError = response.error ?? 'неизвестная ошибка';
        _error = '[$actionName] $rawError (код ${response.statusCode})';
        AppLogger.warn('❌ $actionName не удалось: $_error');
        notifyListeners();
        return false;
    }

    Future<bool> approveUser(int userId) async {
        try {
            final response = await ApiService.approveUser(userId);
            if (response.isSuccess) {
                _pendingUsers.removeWhere((u) => u.id == userId);
                _pendingCount = _pendingUsers.length;
            }
            return await _handleAction('Подтверждение', response);
        } catch (e) {
            AppLogger.error('Ошибка подтверждения', e);
            _error = '[Подтверждение] $e';
            notifyListeners();
            return false;
        }
    }

    Future<bool> rejectUser(int userId) async {
        try {
            final response = await ApiService.rejectUser(userId);
            if (response.isSuccess) {
                _pendingUsers.removeWhere((u) => u.id == userId);
                _pendingCount = _pendingUsers.length;
            }
            return await _handleAction(
                'Отклонение',
                response,
                reloadUsers: false,
            );
        } catch (e) {
            AppLogger.error('Ошибка отклонения', e);
            _error = '[Отклонение] $e';
            notifyListeners();
            return false;
        }
    }

    Future<bool> assignCommander(int userId) async {
        try {
            final response = await ApiService.assignCommander(userId);
            return await _handleAction('Назначение командиром', response);
        } catch (e) {
            AppLogger.error('Ошибка назначения командиром', e);
            _error = '[Назначение командиром] $e';
            notifyListeners();
            return false;
        }
    }

    Future<bool> removeCommander(int userId) async {
        try {
            final response = await ApiService.removeCommander(userId);
            return await _handleAction('Снятие командира', response);
        } catch (e) {
            AppLogger.error('Ошибка снятия командира', e);
            _error = '[Снятие командира] $e';
            notifyListeners();
            return false;
        }
    }

    Future<bool> makeRecruit(int userId) async {
        try {
            final response = await ApiService.makeRecruit(userId);
            return await _handleAction('Понижение до новобранца', response);
        } catch (e) {
            AppLogger.error('Ошибка понижения до новобранца', e);
            _error = '[Понижение до новобранца] $e';
            notifyListeners();
            return false;
        }
    }

    // =====================================================
    // 🔄 ОБНОВЛЕНИЕ СТАТУСА
    // =====================================================

    void updateUserStatus(int userId, String status, {DateTime? lastSeen}) {
        final index = _users.indexWhere((u) => u.id == userId);
        if (index == -1) return;
        _users[index] = _users[index].copyWith(
            status: status,
            lastSeen: lastSeen,
        );
        notifyListeners();
    }

    // =====================================================
    // 🛠️ ОЧИСТКА
    // =====================================================

    void clear() {
        _newRecruitSub?.cancel();
        _pendingCountSub?.cancel();
        _users = [];
        _pendingUsers = [];
        _pendingCount = 0;
        _error = null;
        notifyListeners();
    }

    @override
    void dispose() {
        _newRecruitSub?.cancel();
        _pendingCountSub?.cancel();
        super.dispose();
    }
}