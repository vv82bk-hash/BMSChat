// =====================================================
// 🎯 BMSChat — ЭКРАН ЗАСТАВКИ (SPLASH)
// =====================================================
// Первый экран при запуске приложения.
//
// ЧТО ДЕЛАЕТ:
//   1. Показывает красивую заставку с логотипом
//   2. Инициализирует AuthProvider (проверка токена)
//   3. Инициализирует ChatProvider (Socket.IO)
//   4. Переходит на нужный экран:
//      - ChatsScreen если авторизован
//      - LoginScreen если нет
//
// ВРЕМЯ ПОКАЗА: минимум 2 секунды (для красоты)
// =====================================================

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
    with SingleTickerProviderStateMixin {
    // =====================================================
    // 🎬 АНИМАЦИЯ
    // =====================================================
    late AnimationController _animationController;
    late Animation<double> _logoScale;
    late Animation<double> _logoOpacity;
    late Animation<double> _textOpacity;

    // =====================================================
    // 🎯 СОСТОЯНИЕ
    // =====================================================
    bool _initComplete = false;
    String? _initError;

    @override
    void initState() {
        super.initState();

        // Настраиваем анимацию
        _animationController = AnimationController(
            duration: const Duration(milliseconds: 1500),
            vsync: this,
        );

        _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
            ),
        );

        _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
            ),
        );

        _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
            ),
        );

        _animationController.forward();

        // Запускаем инициализацию
        _initialize();
    }

    @override
    void dispose() {
        _animationController.dispose();
        super.dispose();
    }

    // =====================================================
    // 🚀 ИНИЦИАЛИЗАЦИЯ
    // =====================================================
    Future<void> _initialize() async {
        AppLogger.info('🎯 SplashScreen: начало инициализации');

        // Минимальное время показа заставки (2 сек)
        final minWait = Future.delayed(const Duration(seconds: 2));

        try {
            // ═══════════════════════════════════════════════════
            // 1. Инициализация AuthProvider
            // ═══════════════════════════════════════════════════
            final auth = Provider.of<AuthProvider>(context, listen: false);
            await auth.initialize();

            AppLogger.info('AuthProvider: initialized=${auth.isInitialized}, '
                'isAuthenticated=${auth.isAuthenticated}');

            // ⚠️ Проверка mounted перед повторным использованием context
            if (!mounted) return;

            // ═══════════════════════════════════════════════════
            // 2. Если авторизован — инициализируем ChatProvider
            // ═══════════════════════════════════════════════════
            if (auth.isAuthenticated) {
                final chat = Provider.of<ChatProvider>(context, listen: false);
                chat.initSocketListeners();
                AppLogger.info('ChatProvider: Socket-слушатели подключены');
            }

            // Ждём минимальное время
            await minWait;

            // ⚠️ Проверка mounted после ещё одного await
            if (!mounted) return;

            // Успех
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

            // Всё равно переходим на Login (даже при ошибке)
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

        // Плавный переход с fade
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
                        // 🌈 ФОН (градиент)
                        // ═══════════════════════════════════════
                        Positioned.fill(
                            child: Container(
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                            Color(0xFF000000),
                                            Color(0xFF0A0A0A),
                                            Color(0xFF1A1A1A),
                                        ],
                                    ),
                                ),
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
                                    // ЛОГОТИП (картинка отряда)
                                    // ─────────────────────────────
                                    ScaleTransition(
                                        scale: _logoScale,
                                        child: FadeTransition(
                                            opacity: _logoOpacity,
                                            child: Container(
                                                width: 220,
                                                height: 220,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: RastaTheme
                                                                .rastaYellow
                                                                .withValues(
                                                                    alpha: 0.25,
                                                                ),
                                                            blurRadius: 40,
                                                            spreadRadius: 5,
                                                        ),
                                                    ],
                                                ),
                                                child: ClipOval(
                                                    child: Image.asset(
                                                        'assets/images/logo.png',
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                            // Фолбэк — эмодзи, если картинка не найдена
                                                            return Container(
                                                                color: RastaTheme
                                                                    .surfaceSecondary,
                                                                child: const Center(
                                                                    child: Text(
                                                                        '🎯',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                80,
                                                                        ),
                                                                    ),
                                                                ),
                                                            );
                                                        },
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),

                                    const SizedBox(height: 32),

                                    // ─────────────────────────────
                                    // Название приложения
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _textOpacity,
                                        child: Column(
                                            children: [
                                                const Text(
                                                    'BMSChat',
                                                    style: TextStyle(
                                                        fontSize: 42,
                                                        fontWeight: FontWeight.w900,
                                                        color: RastaTheme.rastaYellow,
                                                        letterSpacing: -1.5,
                                                    ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                    'Отряд Боба Марли',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: RastaTheme.textSecondary
                                                            .withValues(alpha: 0.8),
                                                        letterSpacing: 2,
                                                    ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Полоска раста
                                                Container(
                                                    height: 4,
                                                    width: 140,
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
                                                    ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                    '🌿 One Love 🤙',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: RastaTheme.textMuted
                                                            .withValues(alpha: 0.9),
                                                        letterSpacing: 1.5,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),

                                    const SizedBox(height: 60),

                                    // ─────────────────────────────
                                    // Индикатор загрузки
                                    // ─────────────────────────────
                                    FadeTransition(
                                        opacity: _textOpacity,
                                        child: _buildLoadingIndicator(),
                                    ),
                                ],
                            ),
                        ),

                        // ═══════════════════════════════════════
                        // 📝 ОШИБКА (если есть)
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
                size: 32,
            );
        }

        if (_initComplete) {
            return const Icon(
                Icons.check_circle_outline,
                color: RastaTheme.success,
                size: 32,
            );
        }

        return const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(RastaTheme.rastaYellow),
            ),
        );
    }
}