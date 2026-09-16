import 'package:flutter/material.dart';

import '../themes/rasta_theme.dart';

/// Анимированный индикатор «печатает...».
class TypingIndicator extends StatefulWidget {
    final String userName;

    const TypingIndicator({
        super.key,
        required this.userName,
    });

    @override
    State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
    late List<AnimationController> _controllers;

    @override
    void initState() {
        super.initState();
        _controllers = List.generate(
            3,
            (i) => AnimationController(
                duration: const Duration(milliseconds: 600),
                vsync: this,
            ),
        );

        for (int i = 0; i < 3; i++) {
            Future.delayed(Duration(milliseconds: i * 150), () {
                if (mounted) _controllers[i].repeat(reverse: true);
            });
        }
    }

    @override
    void dispose() {
        for (final c in _controllers) {
            c.dispose();
        }
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        return Align(
            alignment: Alignment.centerLeft,
            child: Container(
                margin: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                ),
                decoration: BoxDecoration(
                    color: RastaTheme.bubbleOther,
                    borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(
                            '${widget.userName} печатает',
                            style: const TextStyle(
                                fontSize: 13,
                                color: RastaTheme.textMuted,
                            ),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(3, (i) {
                            return AnimatedBuilder(
                                animation: _controllers[i],
                                builder: (context, child) {
                                    return Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: RastaTheme.rastaYellow
                                                .withValues(
                                                    alpha: 0.4 +
                                                        _controllers[i].value * 0.6,
                                                ),
                                        ),
                                    );
                                },
                            );
                        }),
                    ],
                ),
            ),
        );
    }
}