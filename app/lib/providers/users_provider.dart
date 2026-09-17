// =====================================================
// 👥 BMSChat — ПРОВАЙДЕР ПОЛЬЗОВАТЕЛЕЙ
// =====================================================
// Управляет списком пользователей + заявками.
// 👑 Подписан на Socket.IO события new_recruit, pending_count.
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

    Future<bool> approveUser(int userId) async {
        try {
            final response = await ApiService.approveUser(userId);
            if (response.isSuccess) {
                _pendingUsers.removeWhere((u) => u.id == userId);
                _pendingCount = _pendingUsers.length;
                await loadUsers();
                return true;
            }
            return false;
        } catch (e) {
            AppLogger.error('Ошибка подтверждения', e);
            return false;
        }
    }

    Future<bool> rejectUser(int userId) async {
        try {
            final response = await ApiService.rejectUser(userId);
            if (response.isSuccess) {
                _pendingUsers.removeWhere((u) => u.id == userId);
                _pendingCount = _pendingUsers.length;
                notifyListeners();
                return true;
            }
            return false;
        } catch (e) {
            return false;
        }
    }

    Future<bool> assignCommander(int userId) async {
        try {
            final response = await ApiService.assignCommander(userId);
            if (response.isSuccess) {
                await loadUsers();
                return true;
            }
            return false;
        } catch (e) {
            return false;
        }
    }

    Future<bool> removeCommander(int userId) async {
        try {
            final response = await ApiService.removeCommander(userId);
            if (response.isSuccess) {
                await loadUsers();
                return true;
            }
            return false;
        } catch (e) {
            return false;
        }
    }

    Future<bool> makeRecruit(int userId) async {
        try {
            final response = await ApiService.makeRecruit(userId);
            if (response.isSuccess) {
                await loadUsers();
                return true;
            }
            return false;
        } catch (e) {
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