// =====================================================
// 🎯 BMSChat — ЭКРАН ЗАСТАВКИ (SPLASH) — УКРАШЕННЫЙ
// =====================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../themes/rasta_theme.dart';
import '../utils/app_logger.dart';
import 'login_screen.dart';
import 'chats_screen.dart';

class SplashScreen extends StatefulWidget {
    const SplashScreen({super.key});

    @override
    State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
    // =====================================================
    // 🎬 АНИМАЦИИ
    // =====================================================
    late AnimationController _animationController;
    late AnimationController _pulseController;
    late AnimationController _backgroundController;

    late Animation<double> _logoScale;
    late Animation<double> _logoOpacity;
    late Animation<double> _textOpacity;
    late Animation<double> _footer1Opacity;
    late Animation<double> _footer2Opacity;
    late Animation<double> _footer3Opacity;
    late Animation<double> _pulseAnimation;

    // =====================================================
    // 🎯 СОСТОЯНИЕ
    // =====================================================
    bool _initComplete = false;
    String? _initError;

    @override
    void initState() {
        super.initState();

        // ─────────────────────────────────────────
        // Основная анимация появления
        // ─────────────────────────────────────────
        _animationController = AnimationController(
            duration: const Duration(milliseconds: 2000),
            vsync: this,
        );

        _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
            ),
        );

        _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
            ),
        );

        _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
            ),
        );

        _footer1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
            ),
        );

        _footer2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.6, 0.85, curve: Curves.easeIn),
            ),
        );

        _footer3Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.7, 0.95, curve: Curves.easeIn),
            ),
        );

        // ─────────────────────────────────────────
        // Пульсация вокруг логотипа
        // ─────────────────────────────────────────
        _pulseController = AnimationController(
            duration: const Duration(milliseconds: 2000),
            vsync: this,
        )..repeat(reverse: true);

        _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
            CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
            ),
        );

        // ─────────────────────────────────────────
        // Движение градиента фона
        // ─────────────────────────────────────────
        _backgroundController = AnimationController(
            duration: const Duration(seconds: 8),
            vsync: this,
        )..repeat();

        _animationController.forward();

        // Запускаем инициализацию
        _initialize();
    }

    @override
    void dispose() {
        _animationController.dispose();
        _pulseController.dispose();
        _backgroundController.dispose();
        super.dispose();
    }

    // =====================================================
    // 🚀 ИНИЦИАЛИЗАЦИЯ
    // =====================================================
    Future<void> _initialize() async {
        AppLogger.info('🎯 SplashScreen: начало инициализации');

        final minWait = Future.delayed(const Duration(seconds: 3));

        try {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            await auth.initialize();

            AppLogger.info('AuthProvider: initialized=${auth.isInitialized}, '
                'isAuthenticated=${auth.isAuthenticated}');

            if (!mounted) return;

            if (auth.isAuthenticated) {
                final chat = Provider.of<ChatProvider>(context, listen: false);
                chat.initSocketListeners();
                AppLogger.info('ChatProvider: Socket-слушатели подключены');
            }

            await minWait;

            if (!mounted) return;

            setState(() {
                _initComplete = true;
            });
            _navigateToNextScreen();

        } catch (e) {
            AppLogger.error('Ошибка инициализации в SplashScreen', e);

            await minWait;

            if (!mounted) return;

            setState(() {
                _initError = 'Ошибка инициализации: $e';
            });

            Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _navigateToNextScreen();
            });
        }
    }

    // =====================================================
    // 🧭 НАВИГАЦИЯ
    // =====================================================
    void _navigateToNextScreen() {
        if (!mounted) return;

        final auth = Provider.of<AuthProvider>(context, listen: false);

        final Widget targetScreen = auth.isAuthenticated
            ? const ChatsScreen()
            : const LoginScreen();

        AppLogger.info(
            'Навигация → ${auth.isAuthenticated ? "ChatsScreen" : "LoginScreen"}'
        );

        Navigator.of(context).pushReplacement(
            PageRouteBuilder(
                pageBuilder: (_, __, ___) => targetScreen,
                transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                        opacity: animation,
                        child: child,
                    );
                },
                transitionDuration: const Duration(milliseconds: 400),
            ),
        );
    }

    // =====================================================
    // 🎨 UI
    // =====================================================
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: RastaTheme.background,
            body: SafeArea(
                child: Stack(
                    children: [
                        // ═══════════════════════════════════════
                        // 🌈 АНИМИРОВАННЫЙ ГРАДИЕНТНЫЙ ФОН
                        // ═══════════════════════════════════════
                        Positioned.fill(
                            child: AnimatedBuilder(
                                animation: _backgroundController,
                                builder: (context, child) {
                                    final t = _backgroundController.value;
                                    // Двигаем позиции начала и конца градиента
                                    return Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment(
                                                    -1.0 + t * 2,
                                                    -1.0 + t * 2,
                                                ),
                                                end: Alignment(
                                                    1.0 - t * 2,
                                                    1.0 - t * 2,
                                                ),
                                                colors: const [
                                                    Color(0xFF000000),
                                                    Color(0xFF1A0505), // тёмно-красный
                                                    Color(0xFF0A0A0A),
                                                    Color(0xFF1A1A0A), // тёмно-жёлтый
                                                    Color(0xFF000000),
                                                ],
                                                stops: const [
                                                    0.0,
                                                    0.25,
                                                    0.5,
                                                    0.75,
                                                    1.0,
                                                ],
                                            ),
                                        ),
                                    );
                                },
                            ),
                        ),

                        // ═══════════════════════════════════════
                        // ✨ ЧАСТИЦЫ / ЗВЁЗДЫ
                        // ═══════════════════════════════════════
                        Positioned.fill(
                            child: AnimatedBuilder(
                                animation: _backgroundController,
                                builder: (context, child) {
                                    return CustomPaint(
                                        painter: _ParticlesPainter(
                                            progress: _backgroundController.value,
                                        ),
                                    );
                                },
                            ),
                        ),

                        // ═══════════════════════════════════════
                        // 🎯 ОСНОВНОЙ КОНТЕНТ
                        // ═══════════════════════════════════════
                        Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    // ─────────────────────────────
                                    // ЛОГОТИП С ПУЛЬСАЦИЕЙ
                                    // ─────────────────────────────
                                    ScaleTransition(
                                        scale: _logoScale,
                                        child: FadeTransition(
                                            opacity: _logoOpacity,
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    // Пульсирующее кольцо
                                                    AnimatedBuilder(
                                                        animation: _pulseAnimation,
                                                        builder: (context, child) {
                                                            return Container(
                                                                width: 280 *
                                                                    _pulseAnimation.value,
                                                                height: 280 *
                                                                    _pulseAnimation.value,
                                                                decoration: BoxDecoration(
                                                                    shape: BoxShape.circle,
                                                                    border: Border.all(
                                                                        color: RastaTheme
                                                                            .rastaYellow
                                                                            .withValues(alpha: 0.3),
                                                                        width: 2,
                                                                    ),
                                                                    boxShadow: [
                                                                        BoxShadow(
                                                                            color: RastaTheme
                                                                                .rastaYellow
                                                                                .withValues(alpha: 0.15),
                                                                            blurRadius: 40,
                                                                            spreadRadius: 10,
                                                                        ),
                                                                    ],
                                                                ),
                                                            );
                                                        },
                                                    ),

                                                    // Логотип
                                                    Container(
                                                        width: 280,
                                                        height: 280,
                                                        decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            boxShadow: [
                                                                BoxShadow(
                                                                    color: RastaTheme
                                                                        .rastaYellow
                                                                        .withValues(alpha: 0.4),
                                                                    blurRadius: 60,
                                                                    spreadRadius: 10,
                                                                ),
                                                                BoxShadow(
                                                                    color: RastaTheme
                                                                        .rastaRed
                                                                        .withValues(alpha: 0.2),
                                                                    blurRadius: 80,
                                                                    spreadRadius: 15,
                                                                ),
                                                            ],
                                                        ),
                                                        child: ClipOval(
                                                            child: Image.asset(
                                                                'assets/images/logo.png',
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (context,
                                                                    error, stackTrace) {
                                                                    return Container(
                                                                        color: RastaTheme
                                                                            .surfaceSecondary,
                                                                        child: const Center(
                                                                            child: Text(
                                                                                '🎯',
                                                                                style: TextStyle(
                                                                                    fontSize: 100,
                                                                                ),
                                                                            ),
                                                                        ),
                                                                    );
                                                                },
                                                            ),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 40),

                                    // ─────────────────────────────
                                    // НАЗВАНИЕ ПРИЛОЖЕНИЯ
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _textOpacity,
                                        child: Column(
                                            children: [
                                                // BMSChat
                                                const Text(
                                                    'BMSChat',
                                                    style: TextStyle(
                                                        fontSize: 52,
                                                        fontWeight: FontWeight.w900,
                                                        color: RastaTheme.rastaYellow,
                                                        letterSpacing: -1.5,
                                                        shadows: [
                                                            Shadow(
                                                                color: Color(0x80FED100),
                                                                blurRadius: 20,
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                                const SizedBox(height: 6),

                                                // Отряд Боба Марли
                                                Text(
                                                    'Отряд Боба Марли',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        color: RastaTheme.textSecondary
                                                            .withValues(alpha: 0.9),
                                                        letterSpacing: 2.5,
                                                        fontWeight: FontWeight.w500,
                                                    ),
                                                ),
                                                const SizedBox(height: 20),

                                                // Полоска раста
                                                Container(
                                                    height: 4,
                                                    width: 180,
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(2),
                                                        gradient: const LinearGradient(
                                                            colors: [
                                                                RastaTheme.rastaRed,
                                                                RastaTheme.rastaYellow,
                                                                RastaTheme.rastaGreen,
                                                            ],
                                                        ),
                                                        boxShadow: [
                                                            BoxShadow(
                                                                color: RastaTheme
                                                                    .rastaYellow
                                                                    .withValues(alpha: 0.5),
                                                                blurRadius: 15,
                                                                spreadRadius: 2,
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),

                                    const SizedBox(height: 40),

                                    // ─────────────────────────────
                                    // ФУТЕР 1: 🌿 One Love 🤙
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _footer1Opacity,
                                        child: Text(
                                            '🌿 One Love 🤙',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: RastaTheme.textMuted
                                                    .withValues(alpha: 0.9),
                                                letterSpacing: 2,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 12),

                                    // ─────────────────────────────
                                    // ФУТЕР 2: 🔥 BOB MARLEY SQUAD 🔥
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _footer2Opacity,
                                        child: const Text(
                                            '🔥 BOB MARLEY SQUAD 🔥',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: RastaTheme.rastaYellow,
                                                letterSpacing: 3,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 8),

                                    // ─────────────────────────────
                                    // ФУТЕР 3: 💬 CHAT 💬
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _footer3Opacity,
                                        child: Text(
                                            '💬 CHAT 💬',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: RastaTheme.rastaGreen
                                                    .withValues(alpha: 0.9),
                                                letterSpacing: 6,
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 50),

                                    // ─────────────────────────────
                                    // ИНДИКАТОР ЗАГРУЗКИ
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _textOpacity,
                                        child: _buildLoadingIndicator(),
                                    ),
                                ],
                            ),
                        ),

                        // ═══════════════════════════════════════
                        // 📝 ОШИБКА
                        // ═══════════════════════════════════════
                        if (_initError != null)
                            Positioned(
                                bottom: 40,
                                left: 24,
                                right: 24,
                                child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: RastaTheme.error.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: RastaTheme.error.withValues(alpha: 0.3),
                                        ),
                                    ),
                                    child: Text(
                                        _initError!,
                                        style: const TextStyle(
                                            color: RastaTheme.error,
                                            fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                    ),
                                ),
                            ),
                    ],
                ),
            ),
        );
    }

    // =====================================================
    // ⏳ ИНДИКАТОР ЗАГРУЗКИ
    // =====================================================
    Widget _buildLoadingIndicator() {
        if (_initError != null) {
            return const Icon(
                Icons.error_outline,
                color: RastaTheme.error,
                size: 36,
            );
        }

        if (_initComplete) {
            return const Icon(
                Icons.check_circle_outline,
                color: RastaTheme.success,
                size: 36,
            );
        }

        return const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(RastaTheme.rastaYellow),
            ),
        );
    }
}

// =====================================================
// ✨ ХУДОЖНИК ЧАСТИЦ
// =====================================================
class _ParticlesPainter extends CustomPainter {
    final double progress;

    _ParticlesPainter({required this.progress});

    @override
    void paint(Canvas canvas, Size size) {
        final random = math.Random(42); // фиксированный seed
        final paint = Paint()..style = PaintingStyle.fill;

        // Цвета частиц (раста + белый)
        final colors = [
            Colors.white.withValues(alpha: 0.6),
            RastaTheme.rastaYellow.withValues(alpha: 0.5),
            RastaTheme.rastaRed.withValues(alpha: 0.4),
            RastaTheme.rastaGreen.withValues(alpha: 0.4),
        ];

        // Рисуем 60 частиц
        for (int i = 0; i < 60; i++) {
            // Позиция частицы
            final baseX = random.nextDouble() * size.width;
            final baseY = random.nextDouble() * size.height;
            final speed = 0.3 + random.nextDouble() * 0.7;
            final radius = 1.0 + random.nextDouble() * 2.5;

            // Движение по кругу
            final offsetX = math.sin(progress * 2 * math.pi * speed + i) * 15;
            final offsetY = math.cos(progress * 2 * math.pi * speed + i) * 15;

            final x = baseX + offsetX;
            final y = baseY + offsetY;

            // Прозрачность мерцает
            final twinkle = 0.5 + 0.5 * math.sin(progress * 4 * math.pi + i);
            final color = colors[i % colors.length];

            paint.color = color.withValues(
                alpha: color.a * twinkle,
            );

            canvas.drawCircle(Offset(x, y), radius, paint);
        }
    }

    @override
    bool shouldRepaint(_ParticlesPainter oldDelegate) {
        return oldDelegate.progress != progress;
    }
}