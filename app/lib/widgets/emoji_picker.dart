// =====================================================
// 😀 BMSChat — ВЫБОР ЭМОДЗИ ДЛЯ АВАТАРКИ КАНАЛА
// =====================================================
// 🎯 ШАГ 10: обёртка над пакетом emoji_picker_flutter.
// 
// Использование:
//   final emoji = await showChannelEmojiPicker(context);
//   if (emoji != null) { ... }
// =====================================================

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../themes/rasta_theme.dart';

/// 🎯 Показать пикер эмодзи в bottom sheet.
/// 
/// Возвращает выбранный эмодзи (String) или null, если отменено.
Future<String?> showChannelEmojiPicker(
    BuildContext context, {
    String? initialEmoji,
}) {
    return showModalBottomSheet<String>(
        context: context,
        backgroundColor: RastaTheme.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bottomSheetContext) {
            return _EmojiPickerSheet(initialEmoji: initialEmoji);
        },
    );
}

// =====================================================
// 🎨 BOTTOM SHEET С ПИКЕРОМ
// =====================================================

class _EmojiPickerSheet extends StatefulWidget {
    final String? initialEmoji;

    const _EmojiPickerSheet({this.initialEmoji});

    @override
    State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
    // Высота: половина экрана — чтобы удобно было выбирать
    static const double _height = 400;

    @override
    Widget build(BuildContext context) {
        return SizedBox(
            height: _height,
            child: Column(
                children: [
                    // ─────────────────────────────
                    // Ручка сверху + заголовок
                    // ─────────────────────────────
                    Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: RastaTheme.textMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                        ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'Выберите эмодзи',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: RastaTheme.textPrimary,
                        ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(
                        height: 1,
                        color: RastaTheme.separator,
                    ),

                    // ─────────────────────────────
                    // Пикер
                    // ─────────────────────────────
                    Expanded(
                        child: EmojiPicker(
                            onEmojiSelected: (category, emoji) {
                                Navigator.pop(context, emoji.emoji);
                            },
                            config: const Config(
                                height: _height - 80,
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                    backgroundColor: RastaTheme.surface,
                                    emojiSizeMax: 28,
                                    columns: 8,
                                    recentsLimit: 28,
                                    noRecents: Text(
                                        'Недавних нет',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: RastaTheme.textMuted,
                                        ),
                                        textAlign: TextAlign.center,
                                    ),
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                    backgroundColor: RastaTheme.surface,
                                    indicatorColor: RastaTheme.rastaYellow,
                                    iconColor: RastaTheme.textMuted,
                                    iconColorSelected: RastaTheme.rastaYellow,
                                    backspaceColor: RastaTheme.rastaYellow,
                                ),
                                bottomActionBarConfig:
                                    BottomActionBarConfig(
                                    enabled: false,
                                ),
                                searchViewConfig: SearchViewConfig(
                                    backgroundColor: RastaTheme.surface,
                                    buttonIconColor: RastaTheme.textMuted,
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}