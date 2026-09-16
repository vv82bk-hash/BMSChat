// =====================================================
// 🎯 BMSChat — ТОЧКА ВХОДА
// =====================================================
// Главный файл приложения.
//
// ЧТО ЗДЕСЬ:
//   • Инициализация Flutter
//   • Настройка системного UI (тёмный статус-бар)
//   • Ограничение ориентации (портрет)
//   • Подключение провайдеров:
//       - AuthProvider — авторизация
//       - ChatProvider — чаты и сообщения
//   • Связь ChatProvider → AuthProvider
//
// СТРУКТУРА:
//   main()
//     ↓
//   BMSChatApp (StatelessWidget)
//     ↓
//   MultiProvider
//     ↓
//   MaterialApp
//     ↓
//   SplashScreen (initial route)
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Темы
import 'themes/rasta_theme.dart';

// Экраны
import 'screens/splash_screen.dart';

// Провайдеры
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';

// =====================================================
// 🚀 ТОЧКА ВХОДА
// =====================================================
void main() async {
    // Инициализация Flutter (нужна перед async-операциями)
    WidgetsFlutterBinding.ensureInitialized();

    // ═══════════════════════════════════════════════════
    // 🎨 НАСТРОЙКА СИСТЕМНОГО UI
    // ═══════════════════════════════════════════════════
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
    ));

    // ═══════════════════════════════════════════════════
    // 📱 ОРИЕНТАЦИЯ — ТОЛЬКО ПОРТРЕТ
    // ═══════════════════════════════════════════════════
    await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
    ]);

    // ═══════════════════════════════════════════════════
    // ▶️ ЗАПУСК ПРИЛОЖЕНИЯ
    // ═══════════════════════════════════════════════════
    runApp(const BMSChatApp());
}

// =====================================================
// 🎯 ГЛАВНЫЙ ВИДЖЕТ ПРИЛОЖЕНИЯ
// =====================================================
class BMSChatApp extends StatelessWidget {
    const BMSChatApp({super.key});

    @override
    Widget build(BuildContext context) {
        return MultiProvider(
            providers: [
                // ═══════════════════════════════════════════════════
                // 🔐 AUTH PROVIDER — авторизация
                // ═══════════════════════════════════════════════════
                ChangeNotifierProvider<AuthProvider>(
                    create: (_) => AuthProvider(),
                ),

                // ═══════════════════════════════════════════════════
                // 💬 CHAT PROVIDER — чаты и сообщения
                // ═══════════════════════════════════════════════════
                // ВАЖНО: ChatProvider зависит от AuthProvider
                // (для проверки прав при отправке).
                // Связываем их через ProxyProvider.
                ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
                    create: (_) => ChatProvider(),
                    update: (_, auth, chat) {
                        // При каждом обновлении AuthProvider
                        // передаём ссылку в ChatProvider
                        chat ??= ChatProvider();
                        chat.setAuthProvider(auth);
                        return chat;
                    },
                ),
            ],
            child: MaterialApp(
                title: 'BMSChat',
                debugShowCheckedModeBanner: false,

                // Тема приложения (iPhone + Rasta)
                theme: RastaTheme.darkTheme,

                // Главный экран
                home: const SplashScreen(),

                // Локализация для русских дат (intl)
                // locale: const Locale('ru', 'RU'),
                // localizationsDelegates: const [
                //     GlobalMaterialLocalizations.delegate,
                //     GlobalWidgetsLocalizations.delegate,
                //     GlobalCupertinoLocalizations.delegate,
                // ],
                // supportedLocales: const [
                //     Locale('ru', 'RU'),
                //     Locale('en', 'US'),
                // ],
            ),
        );
    }
}