// =====================================================
// 💬 BMSChat — МОДЕЛЬ ЧАТА
// =====================================================
// 🎯 unreadCount: количество непрочитанных сообщений
//    Парсит и unread_count, и unreadCount — на случай
//    разного именования на сервере.
// =====================================================

class Chat {
    // =====================================================
    // 📋 ОСНОВНЫЕ ПОЛЯ
    // =====================================================

    final int id;
    final String type;
    final String? name;
    final String? displayName;
    final String? description;
    final String? avatar;
    final int? createdBy;
    final bool isActive;
    final DateTime? createdAt;
    final DateTime? updatedAt;

    // =====================================================
    // 📊 ДАННЫЕ О ЧАТЕ
    // =====================================================

    final String? myRole;
    final int membersCount;
    final int? lastMessageId;
    final String? lastMessageText;
    final DateTime? lastMessageAt;
    final List<ChatMember> members;

    /// 🎯 Количество непрочитанных сообщений
    /// Обновляется:
    ///   • из ответа сервера (`unread_count` / `unreadCount`)
    ///   • локально при новом сообщении (в неактивный чат)
    ///   • обнуляется при markAsRead
    final int unreadCount;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const Chat({
        required this.id,
        required this.type,
        this.name,
        this.displayName,
        this.description,
        this.avatar,
        this.createdBy,
        this.isActive = true,
        this.createdAt,
        this.updatedAt,
        this.myRole,
        this.membersCount = 0,
        this.lastMessageId,
        this.lastMessageText,
        this.lastMessageAt,
        this.members = const [],
        this.unreadCount = 0,
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================

    factory Chat.fromJson(Map<String, dynamic> json) {
        return Chat(
            id: json['id'] as int? ?? 0,
            type: json['type'] as String? ?? 'group',
            name: json['name'] as String?,
            displayName: json['display_name'] as String?,
            description: json['description'] as String?,
            avatar: json['avatar'] as String?,
            createdBy: json['created_by'] as int?,
            isActive: _intToBool(json['is_active']),
            createdAt: _parseDate(json['created_at']),
            updatedAt: _parseDate(json['updated_at']),
            myRole: json['my_role'] as String?,
            membersCount: json['members_count'] as int? ?? 0,
            lastMessageId: json['last_message_id'] as int?,
            lastMessageText: json['last_message_text'] as String?,
            lastMessageAt: _parseDate(json['last_message_at']),
            members: (json['members'] as List<dynamic>?)
                ?.map((m) => ChatMember.fromJson(m as Map<String, dynamic>))
                .toList() ?? [],
            // 🎯 Парсим оба варианта имени
            unreadCount: json['unread_count'] as int?
                ?? json['unreadCount'] as int?
                ?? 0,
        );
    }

    // =====================================================
    // 📤 TO JSON
    // =====================================================

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'type': type,
            'name': name,
            'display_name': displayName,
            'description': description,
            'avatar': avatar,
            'created_by': createdBy,
            'is_active': isActive ? 1 : 0,
            'created_at': createdAt?.toIso8601String(),
            'updated_at': updatedAt?.toIso8601String(),
            'my_role': myRole,
            'members_count': membersCount,
            'last_message_id': lastMessageId,
            'last_message_text': lastMessageText,
            'last_message_at': lastMessageAt?.toIso8601String(),
            // 🎯 Пишем со snake_case (совместимо с бэком)
            'unread_count': unreadCount,
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    Chat copyWith({
        int? id,
        String? type,
        String? name,
        String? displayName,
        String? description,
        String? avatar,
        int? createdBy,
        bool? isActive,
        DateTime? createdAt,
        DateTime? updatedAt,
        String? myRole,
        int? membersCount,
        int? lastMessageId,
        String? lastMessageText,
        DateTime? lastMessageAt,
        List<ChatMember>? members,
        int? unreadCount,
    }) {
        return Chat(
            id: id ?? this.id,
            type: type ?? this.type,
            name: name ?? this.name,
            displayName: displayName ?? this.displayName,
            description: description ?? this.description,
            avatar: avatar ?? this.avatar,
            createdBy: createdBy ?? this.createdBy,
            isActive: isActive ?? this.isActive,
            createdAt: createdAt ?? this.createdAt,
            updatedAt: updatedAt ?? this.updatedAt,
            myRole: myRole ?? this.myRole,
            membersCount: membersCount ?? this.membersCount,
            lastMessageId: lastMessageId ?? this.lastMessageId,
            lastMessageText: lastMessageText ?? this.lastMessageText,
            lastMessageAt: lastMessageAt ?? this.lastMessageAt,
            members: members ?? this.members,
            unreadCount: unreadCount ?? this.unreadCount,
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    bool get isPrivate => type == 'private';
    bool get isGeneral => type == 'general';
    bool get isGroup => type == 'group';
    bool get isChannel => type == 'channel';

    bool get isAdmin => myRole == 'admin';
    bool get isMember => myRole == 'member';

    /// Есть ли непрочитанные?
    bool get hasUnread => unreadCount > 0;

    /// Отображаемое имя чата
    String get title {
        if (isPrivate && displayName != null && displayName!.isNotEmpty) {
            return displayName!;
        }
        if (name != null && name!.isNotEmpty) return name!;
        if (isGeneral) return 'Общий чат';
        if (isPrivate) return 'Личный чат';
        return 'Чат #$id';
    }

    // =====================================================
    // 🎨 ИКОНКА ЧАТА
    // =====================================================

    String get icon {
        switch (type) {
            case 'general':
                return '🖼️';
            case 'private':
                return '🤙';
            case 'group':
                return '📢';
            case 'channel':
                return '📢';
            default:
                return '💬';
        }
    }

    /// Использовать логотип вместо эмодзи?
    bool get useLogoImage => type == 'general';

    /// Текст последнего сообщения (сокращённый)
    String get lastMessagePreview {
        if (lastMessageText == null || lastMessageText!.isEmpty) {
            return 'Нет сообщений';
        }
        final text = lastMessageText!;
        if (text.startsWith('/api/files/') || text.startsWith('IMG:')) {
            return '📷 Фото';
        }
        if (text.length > 50) {
            return '${text.substring(0, 50)}...';
        }
        return text;
    }

    /// Время последнего сообщения
    String get lastMessageTime {
        if (lastMessageAt == null) return '';

        final now = DateTime.now();
        final diff = now.difference(lastMessageAt!);

        if (diff.inHours < 24 && now.day == lastMessageAt!.day) {
            final hour = lastMessageAt!.hour.toString().padLeft(2, '0');
            final minute = lastMessageAt!.minute.toString().padLeft(2, '0');
            return '$hour:$minute';
        }

        if (diff.inDays < 2) {
            return 'вчера';
        }

        if (diff.inDays < 7) {
            return '${diff.inDays} дн';
        }

        final day = lastMessageAt!.day.toString().padLeft(2, '0');
        final month = lastMessageAt!.month.toString().padLeft(2, '0');
        return '$day.$month';
    }

    /// Инициалы для аватарки-заглушки
    String get initials {
        final source = displayName ?? name;
        if (source == null || source.isEmpty) return '?';
        final parts = source.trim().split(' ');
        if (parts.length == 1) {
            return parts[0].substring(0, 1).toUpperCase();
        }
        return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    }

    // =====================================================
    // 🛠️ СТАТИЧЕСКИЕ МЕТОДЫ
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

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    @override
    String toString() {
        return 'Chat(id: $id, type: $type, title: $title, '
            'members: $membersCount, unread: $unreadCount)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Chat &&
            other.id == id &&
            other.lastMessageId == lastMessageId &&
            other.unreadCount == unreadCount;
    }

    @override
    int get hashCode => Object.hash(id, lastMessageId, unreadCount);
}

// =====================================================
// 👥 МОДЕЛЬ УЧАСТНИКА ЧАТА
// =====================================================

class ChatMember {
    final int id;
    final String username;
    final String displayName;
    final String? avatar;
    final String status;
    final String role;
    final DateTime? joinedAt;

    const ChatMember({
        required this.id,
        required this.username,
        required this.displayName,
        this.avatar,
        this.status = 'offline',
        this.role = 'member',
        this.joinedAt,
    });

    factory ChatMember.fromJson(Map<String, dynamic> json) {
        return ChatMember(
            id: json['id'] as int? ?? 0,
            username: json['username'] as String? ?? '',
            displayName: json['display_name'] as String? ?? '',
            avatar: json['avatar'] as String?,
            status: json['status'] as String? ?? 'offline',
            role: json['role'] as String? ?? 'member',
            joinedAt: _parseDate(json['joined_at']),
        );
    }

    bool get isOnline => status == 'online';
    bool get isAdmin => role == 'admin';

    String get initials {
        final parts = displayName.trim().split(' ');
        if (parts.isEmpty || parts.first.isEmpty) return '?';
        if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
        return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    @override
    String toString() => 'ChatMember(id: $id, name: $displayName, role: $role)';
}