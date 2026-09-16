// =====================================================
// 👤 BMSChat — МОДЕЛЬ ПОЛЬЗОВАТЕЛЯ
// =====================================================
// Описывает пользователя приложения.
//
// ПОЛЯ:
//   • id, username, displayName, avatar
//   • status (online/offline)
//   • isApproved (подтверждён командиром)
//   • roles (список ролей)
//   • permissions (объединённые права, 8 штук)
//
// ГЕТТЕРЫ ПРАВ:
//   user.canWriteGeneral      — писать в общий чат
//   user.canWritePrivate      — писать в личные чаты
//   user.canWriteToCommander  — писать командиру
//   user.canCreateFeed        — создавать события
//   user.canApproveUsers      — подтверждать новичков
//   user.canManageRoles       — управлять ролями
//   user.canManageUsers       — Admin
//   user.canAssignCommanders  — Admin
//
// ГЕТТЕРЫ РОЛЕЙ:
//   user.isAdmin      — Администратор
//   user.isCommander  — Командир
//   user.isSoldier    — Боец
//   user.isRecruit    — Новобранец
// =====================================================

import 'role.dart';

class User {
    // =====================================================
    // 📋 ОСНОВНЫЕ ПОЛЯ
    // =====================================================

    final int id;
    final String username;
    final String displayName;
    final String? avatar;
    final String status;
    final bool isApproved;
    final DateTime? lastSeen;
    final DateTime? createdAt;

    // =====================================================
    // 🎭 РОЛИ И ПРАВА
    // =====================================================

    /// Список ролей пользователя
    final List<Role> roles;

    /// Объединённые права (из всех ролей)
    /// Ключи: 'can_write_general', 'can_write_private', и т.д.
    final Map<String, bool> permissions;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const User({
        required this.id,
        required this.username,
        required this.displayName,
        this.avatar,
        this.status = 'offline',
        this.isApproved = false,
        this.lastSeen,
        this.createdAt,
        this.roles = const [],
        this.permissions = const {},
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================

    factory User.fromJson(Map<String, dynamic> json) {
        return User(
            id: json['id'] as int? ?? 0,
            username: json['username'] as String? ?? '',
            displayName: json['display_name'] as String? ?? 
                         json['username'] as String? ?? 'Без имени',
            avatar: json['avatar'] as String?,
            status: json['status'] as String? ?? 'offline',
            isApproved: _intToBool(json['is_approved']),
            lastSeen: _parseDate(json['last_seen']),
            createdAt: _parseDate(json['created_at']),
            roles: (json['roles'] as List<dynamic>?)
                ?.map((r) => Role.fromJson(r as Map<String, dynamic>))
                .toList() ?? [],
            permissions: _parsePermissions(json['permissions']),
        );
    }

    // =====================================================
    // 📤 TO JSON
    // =====================================================

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'username': username,
            'display_name': displayName,
            'avatar': avatar,
            'status': status,
            'is_approved': isApproved ? 1 : 0,
            'last_seen': lastSeen?.toIso8601String(),
            'created_at': createdAt?.toIso8601String(),
            'roles': roles.map((r) => r.toJson()).toList(),
            'permissions': permissions,
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    User copyWith({
        int? id,
        String? username,
        String? displayName,
        String? avatar,
        String? status,
        bool? isApproved,
        DateTime? lastSeen,
        DateTime? createdAt,
        List<Role>? roles,
        Map<String, bool>? permissions,
    }) {
        return User(
            id: id ?? this.id,
            username: username ?? this.username,
            displayName: displayName ?? this.displayName,
            avatar: avatar ?? this.avatar,
            status: status ?? this.status,
            isApproved: isApproved ?? this.isApproved,
            lastSeen: lastSeen ?? this.lastSeen,
            createdAt: createdAt ?? this.createdAt,
            roles: roles ?? this.roles,
            permissions: permissions ?? this.permissions,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ СТАТУСА
    // =====================================================

    bool get isOnline => status == 'online';
    bool get isOffline => status == 'offline';

    // =====================================================
    // 🎯 ГЕТТЕРЫ ПРАВ (8 штук)
    // =====================================================

    /// Может писать в общий чат
    bool get canWriteGeneral => permissions['can_write_general'] == true;

    /// Может писать в личные чаты
    bool get canWritePrivate => permissions['can_write_private'] == true;

    /// Может писать лично командиру (для новобранцев)
    bool get canWriteToCommander => 
        permissions['can_write_to_commander'] == true;

    /// Может создавать события в ленте
    bool get canCreateFeed => permissions['can_create_feed'] == true;

    /// Может подтверждать новых пользователей
    bool get canApproveUsers => permissions['can_approve_users'] == true;

    /// Может управлять ролями
    bool get canManageRoles => permissions['can_manage_roles'] == true;

    /// Может управлять пользователями (Admin)
    bool get canManageUsers => permissions['can_manage_users'] == true;

    /// Может назначать командиров (Admin)
    bool get canAssignCommanders => 
        permissions['can_assign_commanders'] == true;

    // =====================================================
    // 👑 ГЕТТЕРЫ РОЛЕЙ
    // =====================================================

    /// Является ли администратором
    bool get isAdmin => roles.any((r) => r.name == 'Администратор');

    /// Является ли командиром
    bool get isCommander => roles.any((r) => r.name == 'Командир');

    /// Является ли бойцом
    bool get isSoldier => roles.any((r) => r.name == 'Боец');

    /// Является ли новобранцем
    bool get isRecruit => roles.any((r) => r.name == 'Новобранец');

    /// Является ли командиром или выше
    bool get isCommanderOrHigher => isCommander || isAdmin;

    // =====================================================
    // 🛠️ ПРОВЕРКИ
    // =====================================================

    /// Есть ли конкретное право
    bool hasPermission(String permission) {
        return permissions[permission] == true;
    }

    /// Есть ли конкретная роль
    bool hasRole(String roleName) {
        return roles.any((r) => r.name == roleName);
    }

    /// Главная роль (с самым высоким priority)
    Role? get primaryRole {
        if (roles.isEmpty) return null;
        final sorted = List<Role>.from(roles)
            ..sort((a, b) => b.priority.compareTo(a.priority));
        return sorted.first;
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ ОТОБРАЖЕНИЯ
    // =====================================================

    /// Инициалы для аватарки-заглушки
    String get initials {
        final parts = displayName.trim().split(' ');
        if (parts.isEmpty || parts.first.isEmpty) return '?';
        if (parts.length == 1) {
            return parts[0].substring(0, 1).toUpperCase();
        }
        return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    }

    /// Текст последнего онлайна («был 5 минут назад»)
    String get lastSeenText {
        if (isOnline) return 'онлайн';
        if (lastSeen == null) return 'был(а) давно';

        final diff = DateTime.now().difference(lastSeen!);

        if (diff.inMinutes < 1) return 'был(а) только что';
        if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин назад';
        if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч назад';
        if (diff.inDays < 7) return 'был(а) ${diff.inDays} дн назад';
        return 'был(а) давно';
    }

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ СТАТИЧЕСКИЕ МЕТОДЫ
    // =====================================================

    static bool _intToBool(dynamic value) {
        if (value == null) return false;
        if (value is bool) return value;
        if (value is int) return value == 1;
        return false;
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    static Map<String, bool> _parsePermissions(dynamic value) {
        if (value == null) return {};
        if (value is Map<String, dynamic>) {
            final result = <String, bool>{};
            value.forEach((key, val) {
                result[key] = _intToBool(val);
            });
            return result;
        }
        return {};
    }

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    @override
    String toString() {
        final roleNames = roles.map((r) => r.name).join(', ');
        return 'User(id: $id, username: $username, roles: [$roleNames])';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is User && other.id == id;
    }

    @override
    int get hashCode => id.hashCode;
}