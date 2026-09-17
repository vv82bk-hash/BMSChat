// =====================================================
// ✨ BMSChat — ОБЁРТКА ДЛЯ АНИМАЦИИ СООБЩЕНИЙ
// =====================================================
// Плавное появление: fade + slide снизу.
// Отслеживает новые сообщения по messageId.
// =====================================================

import 'package:flutter/material.dart';

class AnimatedMessageWrapper extends StatefulWidget {
    final int messageId;
    final Widget child;

    const AnimatedMessageWrapper({
        super.key,
        required this.messageId,
        required this.child,
    });

    @override
    State<AnimatedMessageWrapper> createState() =>
        _AnimatedMessageWrapperState();
}

class _AnimatedMessageWrapperState extends State<AnimatedMessageWrapper>
    with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _fadeAnimation;
    late Animation<Offset> _slideAnimation;

    @override
    void initState() {
        super.initState();

        _controller = AnimationController(
            duration: const Duration(milliseconds: 250),
            vsync: this,
        );

        _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
            ),
        );

        _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
        ).animate(
            CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
            ),
        );

        _controller.forward();
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
                position: _slideAnimation,
                child: widget.child,
            ),
        );
    }
}