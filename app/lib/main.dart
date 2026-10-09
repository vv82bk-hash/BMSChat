// =====================================================
// 🎯 BMSChat — ТОЧКА ВХОДА
// =====================================================

import 'package:firebase_core/firebase_core.dart';
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
import 'providers/users_provider.dart';

// 🎯 Уведомления (FCM + локальные)
import 'services/notification_service.dart';

// =====================================================
// 🎯 ГЛОБАЛЬНЫЙ КЛЮЧ НАВИГАЦИИ
// =====================================================
// Нужен для перехода в чат по тапу на push-уведомление.
// Устанавливается в MaterialApp → доступен из любого места
// приложения через navigatorKey.currentState.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// =====================================================
// 🚀 ТОЧКА ВХОДА
// =====================================================
void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 🎯 Firebase — обязательно ДО NotificationService
    await Firebase.initializeApp();

    // 🎯 Инициализация уведомлений (FCM + локальные)
    await NotificationService.init();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
    ));

    await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
    ]);

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
                // 🔐 Авторизация
                ChangeNotifierProvider<AuthProvider>(
                    create: (_) => AuthProvider(),
                ),

                // 💬 Чаты и сообщения
                ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
                    create: (_) => ChatProvider(),
                    update: (_, auth, chat) {
                        chat ??= ChatProvider();
                        chat.setAuthProvider(auth);
                        return chat;
                    },
                ),

                // 👥 Пользователи
                ChangeNotifierProvider<UsersProvider>(
                    create: (_) => UsersProvider(),
                ),
            ],
            child: MaterialApp(
                title: 'BMSChat',
                debugShowCheckedModeBanner: false,
                navigatorKey: navigatorKey,
                theme: RastaTheme.darkTheme,
                home: const SplashScreen(),
            ),
        );
    }
}