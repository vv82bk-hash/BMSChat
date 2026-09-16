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

    static const List<String> emojis = [
        '👍', '🔥', '❤️', '😂', '😮', '😢', '🎯', '💪',
    ];

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
            ),
            decoration: BoxDecoration(
                color: RastaTheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                    ),
                ],
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: emojis.map((emoji) {
                    final isMyReaction = myReactions.contains(emoji);

                    return GestureDetector(
                        onTap: () => onSelect(emoji),
                        child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: isMyReaction
                                    ? RastaTheme.rastaYellow.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                            ),
                            child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                            ),
                        ),
                    );
                }).toList(),
            ),
        );
    }
}