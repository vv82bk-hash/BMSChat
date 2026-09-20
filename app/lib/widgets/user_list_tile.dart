// =====================================================
// 👤 BMSChat — ЭЛЕМЕНТ СПИСКА ПОЛЬЗОВАТЕЛЕЙ
// =====================================================
// 🎯 ЭТАП D.1: кэш аватаров через CachedNetworkImageProvider
// =====================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../themes/rasta_theme.dart';

class UserListTile extends StatelessWidget {
    final User user;
    final bool isMe;
    final VoidCallback? onTap;

    const UserListTile({
        super.key,
        required this.user,
        this.isMe = false,
        this.onTap,
    });

    @override
    Widget build(BuildContext context) {
        return ListTile(
            onTap: onTap,
            leading: _buildAvatar(),
            title: Row(
                children: [
                    Flexible(
                        child: Text(
                            user.displayName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: RastaTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                    // Подпись «(вы)» для себя
                    if (isMe)
                        const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                                '(вы)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: RastaTheme.rastaYellow,
                                ),
                            ),
                        ),
                    // Бейдж главной роли
                    if (user.primaryRole != null) ...[
                        const SizedBox(width: 6),
                        _buildRoleBadge(user.primaryRole!),
                    ],
                ],
            ),
            subtitle: Text(
                user.isOnline ? 'онлайн' : user.lastSeenText,
                style: TextStyle(
                    fontSize: 12,
                    color: user.isOnline
                        ? RastaTheme.success
                        : RastaTheme.textMuted,
                ),
            ),
            trailing: const Icon(
                Icons.chevron_right,
                color: RastaTheme.textMuted,
            ),
        );
    }

    // =====================================================
    // 🖼️ АВАТАР
    // =====================================================
    Widget _buildAvatar() {
        return Stack(
            children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: RastaTheme.surfaceSecondary,
                    // 🎯 ЭТАП D.1: кэш аватара на диск
                    backgroundImage: user.avatar != null
                        ? CachedNetworkImageProvider(user.avatar!)
                        : null,
                    child: user.avatar == null
                        ? Text(
                            user.initials,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: RastaTheme.rastaYellow,
                            ),
                        )
                        : null,
                ),
                // Индикатор онлайна
                Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: user.isOnline
                                ? RastaTheme.success
                                : RastaTheme.textMuted,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: RastaTheme.background,
                                width: 2,
                            ),
                        ),
                    ),
                ),
            ],
        );
    }

    // =====================================================
    // 🏷️ БЕЙДЖ РОЛИ
    // =====================================================
    Widget _buildRoleBadge(dynamic role) {
        final color = Color(role.colorValue);

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 0.5),
            ),
            child: Text(
                role.icon,
                style: const TextStyle(fontSize: 12),
            ),
        );
    }
}