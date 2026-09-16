// =====================================================
// 💬 BMSChat — МОДЕЛЬ ЧАТА
// =====================================================
// Описывает чат. 4 типа:
//   • private — личный чат (2 человека)
//   • general — общий чат команды
//   • group   — групповой чат
//   • channel — канал (пишут только админы)
//
// Использование:
//   final chat = Chat.fromJson(jsonData);
//   print(chat.displayName);
//   print(chat.icon);
// =====================================================

class Chat {
    // =====================================================
    // 📋 ОСНОВНЫЕ ПОЛЯ
    // =====================================================

    /// Уникальный ID
    final int id;

    /// Тип чата: 'private', 'general', 'group', 'channel'
    final String type;

    /// Название (для групп/каналов)
    final String? name;

    /// Описание
    final String? description;

    /// Путь к аватарке
    final String? avatar;

    /// Кто создал чат
    final int? createdBy;

    /// Активен ли чат
    final bool isActive;

    /// Когда создан
    final DateTime? createdAt;

    /// Когда последнее изменение
    final DateTime? updatedAt;

    // =====================================================
    // 📊 ДАННЫЕ О ЧАТЕ
    // =====================================================

    /// Роль текущего пользователя в этом чате ('admin' или 'member')
    final String? myRole;

    /// Сколько участников
    final int membersCount;

    /// ID последнего сообщения
    final int? lastMessageId;

    /// Текст последнего сообщения
    final String? lastMessageText;

    /// Когда отправлено последнее сообщение
    final DateTime? lastMessageAt;

    /// Список участников (только если загружен)
    final List<ChatMember> members;

    // =====================================================
    // 🏗️ КОНСТРУКТОР
    // =====================================================

    const Chat({
        required this.id,
        required this.type,
        this.name,
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
    });

    // =====================================================
    // 📥 FROM JSON
    // =====================================================
    // Сервер присылает:
    //   {
    //     "id": 1,
    //     "type": "general",
    //     "name": "Общий чат",
    //     "description": "Общий чат команды",
    //     "avatar": null,
    //     "created_by": 1,
    //     "is_active": 1,
    //     "created_at": "...",
    //     "updated_at": "...",
    //     "my_role": "admin",
    //     "members_count": 3,
    //     "last_message_id": 5,
    //     "last_message_text": "Привет!",
    //     "last_message_at": "..."
    //   }
    // =====================================================

    factory Chat.fromJson(Map<String, dynamic> json) {
        return Chat(
            id: json['id'] as int? ?? 0,
            type: json['type'] as String? ?? 'group',
            name: json['name'] as String?,
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
        };
    }

    // =====================================================
    // 📋 COPY WITH
    // =====================================================

    Chat copyWith({
        int? id,
        String? type,
        String? name,
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
    }) {
        return Chat(
            id: id ?? this.id,
            type: type ?? this.type,
            name: name ?? this.name,
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
        );
    }

    // =====================================================
    // 🛠️ ГЕТТЕРЫ
    // =====================================================

    /// Личный чат?
    bool get isPrivate => type == 'private';

    /// Общий чат команды?
    bool get isGeneral => type == 'general';

    /// Групповой чат?
    bool get isGroup => type == 'group';

    /// Канал?
    bool get isChannel => type == 'channel';

    /// Текущий пользователь — админ чата?
    bool get isAdmin => myRole == 'admin';

    /// Текущий пользователь — участник?
    bool get isMember => myRole == 'member';

    /// Отображаемое имя чата
    /// (если название есть — используем его, иначе — тип)
    String get displayName {
        if (name != null && name!.isNotEmpty) return name!;
        if (isGeneral) return 'Общий чат';
        if (isPrivate) return 'Личный чат';
        return 'Чат #$id';
    }

    /// Иконка чата (эмодзи)
    String get icon {
        switch (type) {
            case 'general':
                return '💬';
            case 'private':
                return '👤';
            case 'group':
                return '👥';
            case 'channel':
                return '📢';
            default:
                return '💬';
        }
    }

    /// Текст последнего сообщения (сокращённый)
    String get lastMessagePreview {
        if (lastMessageText == null || lastMessageText!.isEmpty) {
            return 'Нет сообщений';
        }
        final text = lastMessageText!;
        if (text.length > 50) {
            return '${text.substring(0, 50)}...';
        }
        return text;
    }

    /// Время последнего сообщения в формате «14:30»
    String get lastMessageTime {
        if (lastMessageAt == null) return '';
        
        final now = DateTime.now();
        final diff = now.difference(lastMessageAt!);

        // Сегодня — показываем время
        if (diff.inHours < 24 && now.day == lastMessageAt!.day) {
            final hour = lastMessageAt!.hour.toString().padLeft(2, '0');
            final minute = lastMessageAt!.minute.toString().padLeft(2, '0');
            return '$hour:$minute';
        }

        // Вчера
        if (diff.inDays < 2) {
            return 'вчера';
        }

        // На этой неделе
        if (diff.inDays < 7) {
            return '${diff.inDays} дн';
        }

        // Старше
        final day = lastMessageAt!.day.toString().padLeft(2, '0');
        final month = lastMessageAt!.month.toString().padLeft(2, '0');
        return '$day.$month';
    }

    /// Инициалы для аватарки-заглушки
    String get initials {
        if (name == null || name!.isEmpty) return icon;
        final parts = name!.trim().split(' ');
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
        return 'Chat(id: $id, type: $type, name: $name, members: $membersCount)';
    }

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) return true;
        return other is Chat &&
            other.id == id &&
            other.lastMessageId == lastMessageId;
    }

    @override
    int get hashCode => Object.hash(id, lastMessageId);
}

// =====================================================
// 👥 МОДЕЛЬ УЧАСТНИКА ЧАТА
// =====================================================
// Расширяет данные User ролью в конкретном чате.
// Используется на экране информации о чате.
// =====================================================

class ChatMember {
    /// ID пользователя
    final int id;

    /// Логин
    final String username;

    /// Отображаемое имя
    final String displayName;

    /// Аватарка
    final String? avatar;

    /// Статус: 'online' / 'offline'
    final String status;

    /// Роль в чате: 'admin' / 'member'
    final String role;

    /// Когда присоединился
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

    /// Онлайн?
    bool get isOnline => status == 'online';

    /// Админ чата?
    bool get isAdmin => role == 'admin';

    /// Инициалы
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