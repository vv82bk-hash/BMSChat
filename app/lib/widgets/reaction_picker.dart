// =====================================================
// 😀 BMSChat — ВЫБОР РЕАКЦИИ (УКРАШЕННЫЙ)
// =====================================================

import 'package:flutter/material.dart';
import '../themes/rasta_theme.dart';

/// Панель выбора эмодзи-реакции.
class ReactionPicker extends StatelessWidget {
    final Function(String emoji) onSelect;
    final Set<String> myReactions;

    const ReactionPicker({
        super.key,
        required this.onSelect,
        this.myReactions = const {},
    });

    // ═══════════════════════════════════════════════════
    // 🎯 20 ЭМОДЗИ (2 ряда по 10)
    // ═══════════════════════════════════════════════════
    static const List<String> emojis = [
        '👍', '🔥', '❤️', '😂', '😮', '😢', '🎯', '💪', '🙏', '👏',
        '🤙', '💯', '✌️', '🤣', '😍', '🍻', '🌿', '💚', '💛', '⭐',
    ];

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                    ),
                ],
                border: Border.all(
                    color: RastaTheme.rastaYellow.withValues(alpha: 0.2),
                    width: 1,
                ),
            ),
            // Wrap — автоматически переносит на 2 строки
            child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: emojis.map((emoji) {
                    final isMyReaction = myReactions.contains(emoji);

                    return GestureDetector(
                        onTap: () => onSelect(emoji),
                        child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 1,
                                vertical: 1,
                            ),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: isMyReaction
                                    ? RastaTheme.rastaYellow
                                        .withValues(alpha: 0.25)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isMyReaction
                                    ? Border.all(
                                        color: RastaTheme.rastaYellow,
                                        width: 1.5,
                                    )
                                    : null,
                            ),
                            child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                            ),
                        ),
                    );
                }).toList(),
            ),
        );
    }
}