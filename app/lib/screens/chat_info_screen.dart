// =====================================================
// ℹ️ BMSChat — ИНФОРМАЦИЯ О ЧАТЕ
// =====================================================
// 🎯 Показывает:
//   • Аватар (эмодзи / логотип)
//   • Название и тип
//   • Описание
//   • Метаданные (участники, дата, mute)
//   • Список участников (первые 5)
//   • Кнопка «Показать всех» → UsersScreen
// 🎯 Данные: ApiService.getChat(chatId) → { chat, members }
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../themes/rasta_theme.dart';
import 'users_screen.dart';

class ChatInfoScreen extends StatefulWidget {
    final Chat chat;

    const ChatInfoScreen({
        super.key,
        required this.chat,
    });

    @override
    State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
    List<ChatMember> _members = [];
    bool _isLoading = true;
    String? _error;

    @override
    void initState() {
        super.initState();
        _loadInfo();
    }

    Future<void> _loadInfo() async {
        setState(() {
            _isLoading = true;
            _error = null;
        });

        try {
            final response = await ApiService.getChat(widget.chat.id);

            if (!mounted) return;

            if (response.isSuccess && response.data != null) {
                final membersJson =
                    response.data!['members'] as List<dynamic>? ?? [];

                setState(() {
                    _members = membersJson
                        .map((m) => ChatMember.fromJson(
                            m as Map<String, dynamic>))
                        .toList();
                    _isLoading = false;
                });
            } else {
                setState(() {
                    _error = response.error ?? 'Не удалось загрузить';
                    _isLoading = false;
                });
            }
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _error = 'Ошибка: $e';
                _isLoading = false;
            });
        }
    }

    // =====================================================
    // 🎨 BUILD
    // =====================================================
    @override
    Widget build(BuildContext context) {
        final chat = widget.chat;
        final chatProvider = Provider.of<ChatProvider>(context);
        final freshChat = chatProvider.chats.firstWhere(
            (c) => c.id == chat.id,
            orElse: () => chat,
        );

        return Scaffold(
            backgroundColor: RastaTheme.background,
            appBar: AppBar(
                title: const Text('ℹ️ Информация'),
            ),
            body: RefreshIndicator(
                onRefresh: _loadInfo,
                color: RastaTheme.rastaYellow,
                backgroundColor: RastaTheme.surface,
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            _buildHeader(freshChat),
                            const SizedBox(height: 24),

                            if (freshChat.description != null &&
                                freshChat.description!.isNotEmpty) ...[
                                _buildDescription(freshChat),
                                const SizedBox(height: 16),
                            ],

                            _buildMetaSection(freshChat),
                            const SizedBox(height: 16),

                            _buildMembersSection(),
                            const SizedBox(height: 24),
                        ],
                    ),
                ),
            ),
        );
    }

    // =====================================================
    // 👤 ЗАГОЛОВОК С АВАТАРОМ
    // =====================================================
    Widget _buildHeader(Chat chat) {
        return Center(
            child: Column(
                children: [
                    _buildAvatar(chat),
                    const SizedBox(height: 16),
                    Text(
                        chat.title,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                        _typeLabel(chat.type),
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    if (chat.isMuted) ...[
                        const SizedBox(height: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                            ),
                            decoration: BoxDecoration(
                                color: RastaTheme.error
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: RastaTheme.error
                                        .withValues(alpha: 0.4),
                                ),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Icon(
                                        Icons.notifications_off_outlined,
                                        size: 14,
                                        color: RastaTheme.error,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                        'Уведомления отключены',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: RastaTheme.error,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _buildAvatar(Chat chat) {
        // 🎯 Для general с логотипом
        if (chat.useLogoImage) {
            return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                        BoxShadow(
                            color: RastaTheme.rastaYellow
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                        ),
                    ],
                ),
                child: ClipOval(
                    child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildEmojiAvatar(
                            chat.displayEmoji,
                            chat.isChannel,
                        ),
                    ),
                ),
            );
        }

        return _buildEmojiAvatar(chat.displayEmoji, chat.isChannel);
    }

    Widget _buildEmojiAvatar(String emoji, bool isChannel) {
        return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isChannel
                    ? const LinearGradient(
                        colors: [
                            Color(0xFF9C27B0),
                            RastaTheme.rastaRed,
                        ],
                    )
                    : const LinearGradient(
                        colors: [
                            RastaTheme.rastaRed,
                            RastaTheme.rastaYellow,
                        ],
                    ),
                boxShadow: [
                    BoxShadow(
                        color: RastaTheme.rastaYellow
                            .withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                    ),
                ],
            ),
            child: Center(
                child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 48),
                ),
            ),
        );
    }

    String _typeLabel(String type) {
        switch (type) {
            case 'general':
                return 'Общий чат';
            case 'group':
                return 'Группа';
            case 'channel':
                return 'Канал';
            case 'private':
                return 'Личный чат';
            default:
                return type;
        }
    }

    // =====================================================
    // 📝 ОПИСАНИЕ
    // =====================================================
    Widget _buildDescription(Chat chat) {
        return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        'Описание',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        chat.description!,
                        style: const TextStyle(
                            fontSize: 15,
                            color: RastaTheme.textPrimary,
                            height: 1.4,
                        ),
                    ),
                ],
            ),
        );
    }

    // =====================================================
    // 📊 МЕТАДАННЫЕ
    // =====================================================
    Widget _buildMetaSection(Chat chat) {
        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                        'Информация',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RastaTheme.textMuted,
                        ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetaRow(
                        Icons.people_outline,
                        'Участники',
                        '${chat.membersCount}',
                    ),
                    if (chat.createdAt != null) ...[
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            Icons.calendar_today,
                            'Создан',
                            DateFormat('dd.MM.yyyy')
                                .format(chat.createdAt!),
                        ),
                    ],
                    if (chat.createdBy != null) ...[
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            Icons.person_outline,
                            'Создатель',
                            'ID ${chat.createdBy}',
                        ),
                    ],
                    if (chat.isChannel) ...[
                        const SizedBox(height: 10),
                        _buildMetaRow(
                            Icons.lock_outline,
                            'Тип канала',
                            chat.isPrivate ? 'Приватный' : 'Публичный',
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _buildMetaRow(IconData icon, String label, String value) {
        return Row(
            children: [
                Icon(icon, size: 18, color: RastaTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 14,
                            color: RastaTheme.textSecondary,
                        ),
                    ),
                ),
                Text(
                    value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: RastaTheme.textPrimary,
                    ),
                ),
            ],
        );
    }

    // =====================================================
    // 👥 УЧАСТНИКИ
    // =====================================================
    Widget _buildMembersSection() {
        if (_isLoading) {
            return Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        RastaTheme.rastaYellow,
                    ),
                ),
            );
        }

        if (_error != null) {
            return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: RastaTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                    children: [
                        const Icon(
                            Icons.error_outline,
                            color: RastaTheme.error,
                            size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: RastaTheme.textMuted,
                                    fontSize: 14,
                                ),
                            ),
                        ),
                    ],
                ),
            );
        }

        return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        children: [
                            const Expanded(
                                child: Text(
                                    'Участники',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: RastaTheme.textMuted,
                                    ),
                                ),
                            ),
                            Text(
                                '${_members.length}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: RastaTheme.textMuted,
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 12),

                    // 🎯 Первые 5 участников
                    ..._members.take(5).map(_buildMemberTile),

                    if (_members.length > 5) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                                onPressed: _openAllMembers,
                                icon: const Icon(
                                    Icons.people_outline,
                                    size: 18,
                                ),
                                label: Text(
                                    'Показать всех (${_members.length})',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                    ),
                                ),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        RastaTheme.rastaYellow,
                                    side: const BorderSide(
                                        color: RastaTheme.rastaYellow,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                    ),
                                ),
                            ),
                        ),
                    ],
                ],
            ),
        );
    }

    Widget _buildMemberTile(ChatMember member) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
                children: [
                    Stack(
                        children: [
                            CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    RastaTheme.surfaceSecondary,
                                child: Text(
                                    member.initials,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: RastaTheme.rastaYellow,
                                    ),
                                ),
                            ),
                            if (member.isOnline)
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: RastaTheme.success,
                                            border: Border.all(
                                                color:
                                                    RastaTheme.background,
                                                width: 2,
                                            ),
                                        ),
                                    ),
                                ),
                        ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            member.displayName,
                            style: const TextStyle(
                                fontSize: 15,
                                color: RastaTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                    if (member.isAdmin)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                            ),
                            decoration: BoxDecoration(
                                color: RastaTheme.rastaYellow
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                                '👑',
                                style: TextStyle(fontSize: 12),
                            ),
                        ),
                ],
            ),
        );
    }

    void _openAllMembers() {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UsersScreen(),
            ),
        );
    }
}