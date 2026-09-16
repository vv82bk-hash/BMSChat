// =====================================================
// 🎭 BMSChat — МОДЕЛЬ РОЛИ
// =====================================================
// Роль — гибкая система прав.
//
// ИЕРАРХИЯ (по priority):
//   1000 — 👑 Администратор (технический)
//    100 — 🎖️ Командир (несколько)
//     50 — 🪖 Боец (полноправный)
//     10 — 🆕 Новобранец (испытательный срок)
//
// 8 ПРАВ:
//   Чат:
//     can_write_general       — писать в общий чат и группы
//     can_write_private       — писать в личные чаты
//     can_write_to_commander  — писать лично командиру (для новобранцев)
//
//   Лента и модерация:
//     can_create_feed         — создавать события в ленте
//     can_approve_users       — подтверждать новобранцев
//     can_manage_roles        — управлять ролями
//
//   Администрирование:
//     can_manage_users        — управлять пользователями
//     can_assign_commanders   — назначать командиров
// =====================================================

class Role {
    // =====================================================
    // 📋 ПОЛЯ
    // =====================================================

    final int id;
    final String name;
    final String? description;
    final String color;
    final String icon;
    final int priority;

    // =====================================================
    // 🎯 ПРАВА (8 штук)
    // =====================================================

    /// Писать в общий чат и группы
    final bool canWriteGeneral;

    /// Писать в личные чаты
    final bool canWritePrivate;

    /// Писать лично командиру (для новобранцев)
    final bool canWriteToCommander;

    /// Создавать события в ленте
    final bool canCreateFeed;

    /// Подтверждать новых пользователей
    final bool canApproveUsers;

    /// Управлять ролями
    final bool canManageRoles;

    /// Управлять пользователями (Admin)
    final bool canManageUsers;

    /// Назначать командиров (Admin)
    final bool canAssignCommanders;

    /// Системная роль (нельзя удалить)
    final bool isSystem;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const Role({
        required this.id,
        required this.name,
        this.description,
        this.color = '#FED100',
        this.icon = '🎖️',
        this.priority = 0,
        this.canWriteGeneral = false,
        this.canWritePrivate = false,
        this.canWriteToCommander = false,
        this.canCreateFeed = false,
        this.canApproveUsers = false,
        this.canManageRoles = false,
        this.canManageUsers = false,
        this.canAssignCommanders = false,
        this.isSystem = false,
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================

    factory Role.fromJson(Map<String, dynamic> json) {
        return Role(
            id: json['id'] as int? ?? 0,
            name: json['name'] as String? ?? '',
            description: json['description'] as String?,
            color: json['color'] as String? ?? '#FED100',
            icon: json['icon'] as String? ?? '🎖️',
            priority: json['priority'] as int? ?? 0,

            // Права чата
            canWriteGeneral: _intToBool(json['can_write_general']),
            canWritePrivate: _intToBool(json['can_write_private']),
            canWriteToCommander: _intToBool(json['can_write_to_commander']),

            // Лента и модерация
            canCreateFeed: _intToBool(json['can_create_feed']),
            canApproveUsers: _intToBool(json['can_approve_users']),
            canManageRoles: _intToBool(json['can_manage_roles']),

            // Администрирование
            canManageUsers: _intToBool(json['can_manage_users']),
            canAssignCommanders: _intToBool(json['can_assign_commanders']),

            isSystem: _intToBool(json['is_system']),
        );
    }

    // =====================================================
    // 📤 TO JSON
    // =====================================================

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'name': name,
            'description': description,
            'color': color,
            'icon': icon,
            'priority': priority,
            'can_write_general': canWriteGeneral ? 1 : 0,
            'can_write_private': canWritePrivate ? 1 : 0,
            'can_write_to_commander': canWriteToCommander ? 1 : 0,
            'can_create_feed': canCreateFeed ? 1 : 0,
            'can_approve_users': canApproveUsers ? 1 : 0,
            'can_manage_roles': canManageRoles ? 1 : 0,
            'can_manage_users': canManageUsers ? 1 : 0,
            'can_assign_commanders': canAssignCommanders ? 1 : 0,
            'is_system': isSystem ? 1 : 0,
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    Role copyWith({
        int? id,
        String? name,
        String? description,
        String? color,
        String? icon,
        int? priority,
        bool? canWriteGeneral,
        bool? canWritePrivate,
        bool? canWriteToCommander,
        bool? canCreateFeed,
        bool? canApproveUsers,
        bool? canManageRoles,
        bool? canManageUsers,
        bool? canAssignCommanders,
        bool? isSystem,
    }) {
        return Role(
            id: id ?? this.id,
            name: name ?? this.name,
            description: description ?? this.description,
            color: color ?? this.color,
            icon: icon ?? this.icon,
            priority: priority ?? this.priority,
            canWriteGeneral: canWriteGeneral ?? this.canWriteGeneral,
            canWritePrivate: canWritePrivate ?? this.canWritePrivate,
            canWriteToCommander: canWriteToCommander ?? this.canWriteToCommander,
            canCreateFeed: canCreateFeed ?? this.canCreateFeed,
            canApproveUsers: canApproveUsers ?? this.canApproveUsers,
            canManageRoles: canManageRoles ?? this.canManageRoles,
            canManageUsers: canManageUsers ?? this.canManageUsers,
            canAssignCommanders: canAssignCommanders ?? this.canAssignCommanders,
            isSystem: isSystem ?? this.isSystem,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    /// Преобразует HEX-цвет в int (для Flutter Color)
    int get colorValue {
        String hex = color.replaceAll('#', '');
        if (hex.length == 6) {
            hex = 'FF$hex';
        }
        return int.tryParse(hex, radix: 16) ?? 0xFFFED100;
    }

    /// Является ли роль администратором
    bool get isAdmin => name == 'Администратор';

    /// Является ли роль командиром
    bool get isCommander => name == 'Командир';

    /// Является ли роль бойцом
    bool get isSoldier => name == 'Боец';

    /// Является ли роль новобранцем
    bool get isRecruit => name == 'Новобранец';

    // =====================================================
    // 🛠️ ВСПОМОГАТЕЛЬНЫЕ СТАТИЧЕСКИЕ МЕТОДЫ
    // =====================================================

    static bool _intToBool(dynamic value) {
        if (value == null) return false;
        if (value is bool) return value;
        if (value is int) return value == 1;
        return false;
    }

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    @override
    String toString() {
        return 'Role(id: $id, name: $name, icon: $icon, priority: $priority)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Role && other.id == id;
    }

    @override
    int get hashCode => id.hashCode;
}