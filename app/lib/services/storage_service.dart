// =====================================================
// 💾 BMSChat — СЕРВИС ЛОКАЛЬНОГО ХРАНИЛИЩА
// =====================================================
// Сохраняет данные на устройстве через SharedPreferences.
// =====================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../config/constants.dart';
import '../utils/app_logger.dart';

class StorageService {
    // =====================================================
    // 🔐 ТОКЕН
    // =====================================================

    static Future<bool> saveToken(String token) async {
        try {
            final prefs = await SharedPreferences.getInstance();
            return await prefs.setString(StorageKeys.authToken, token);
        } catch (e) {
            AppLogger.error('Ошибка сохранения токена', e);
            return false;
        }
    }

    static Future<String?> getToken() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            return prefs.getString(StorageKeys.authToken);
        } catch (e) {
            AppLogger.error('Ошибка чтения токена', e);
            return null;
        }
    }

    static Future<void> removeToken() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(StorageKeys.authToken);
        } catch (e) {
            AppLogger.error('Ошибка удаления токена', e);
        }
    }

    static Future<bool> hasToken() async {
        final token = await getToken();
        return token != null && token.isNotEmpty;
    }

    // =====================================================
    // 👤 ПОЛЬЗОВАТЕЛЬ
    // =====================================================

    static Future<bool> saveUser(User user) async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final jsonString = jsonEncode(user.toJson());
            return await prefs.setString(StorageKeys.currentUser, jsonString);
        } catch (e) {
            AppLogger.error('Ошибка сохранения пользователя', e);
            return false;
        }
    }

    static Future<User?> getUser() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final jsonString = prefs.getString(StorageKeys.currentUser);

            if (jsonString == null || jsonString.isEmpty) {
                return null;
            }

            final json = jsonDecode(jsonString) as Map<String, dynamic>;
            return User.fromJson(json);
        } catch (e) {
            AppLogger.error('Ошибка чтения пользователя', e);
            return null;
        }
    }

    static Future<void> removeUser() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(StorageKeys.currentUser);
        } catch (e) {
            AppLogger.error('Ошибка удаления пользователя', e);
        }
    }

    // =====================================================
    // 📌 ПОСЛЕДНИЙ ЧАТ
    // =====================================================

    static Future<bool> saveLastChatId(int chatId) async {
        try {
            final prefs = await SharedPreferences.getInstance();
            return await prefs.setInt(StorageKeys.lastChatId, chatId);
        } catch (e) {
            AppLogger.error('Ошибка сохранения lastChatId', e);
            return false;
        }
    }

    static Future<int?> getLastChatId() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            return prefs.getInt(StorageKeys.lastChatId);
        } catch (e) {
            AppLogger.error('Ошибка чтения lastChatId', e);
            return null;
        }
    }

    // =====================================================
    // 🚪 ОЧИСТКА
    // =====================================================

    static Future<void> clearAll() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(StorageKeys.authToken);
            await prefs.remove(StorageKeys.currentUser);
            await prefs.remove(StorageKeys.lastChatId);
        } catch (e) {
            AppLogger.error('Ошибка очистки данных', e);
        }
    }

    static Future<void> clearEverything() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
        } catch (e) {
            AppLogger.error('Ошибка полной очистки', e);
        }
    }

    // =====================================================
    // 🔍 ОТЛАДКА
    // =====================================================

    static Future<Map<String, dynamic>> debugGetAll() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final keys = prefs.getKeys();
            final result = <String, dynamic>{};

            for (final key in keys) {
                result[key] = prefs.get(key);
            }

            return result;
        } catch (e) {
            AppLogger.error('Ошибка чтения хранилища', e);
            return {};
        }
    }
}