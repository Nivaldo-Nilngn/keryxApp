import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/features/ai/model/chat_model.dart';

final chatHistoryServiceProvider = Provider<ChatHistoryService>((ref) {
  return ChatHistoryService();
});

class ChatHistoryService {
  static const String _sessionsKey = 'iatheos_chat_sessions_v1';
  static const String _activeSessionIdKey = 'iatheos_active_session_id';

  Future<List<ChatSession>> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionsKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final sessions = list
          .map((item) => ChatSession.fromMap(item as Map<String, dynamic>))
          .toList();
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao carregar histórico de conversas: $e');
      }
      return [];
    }
  }

  Future<void> saveSession(ChatSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await loadSessions();
      final index = sessions.indexWhere((s) => s.id == session.id);

      if (index >= 0) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session);
      }

      final raw = jsonEncode(sessions.map((s) => s.toMap()).toList());
      await prefs.setString(_sessionsKey, raw);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao salvar conversa: $e');
      }
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await loadSessions();
      sessions.removeWhere((s) => s.id == sessionId);

      final raw = jsonEncode(sessions.map((s) => s.toMap()).toList());
      await prefs.setString(_sessionsKey, raw);

      final activeId = prefs.getString(_activeSessionIdKey);
      if (activeId == sessionId) {
        await prefs.remove(_activeSessionIdKey);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao deletar conversa: $e');
      }
    }
  }

  Future<void> clearAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionsKey);
      await prefs.remove(_activeSessionIdKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao limpar todo histórico: $e');
      }
    }
  }

  Future<String?> getActiveSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeSessionIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> setActiveSessionId(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_activeSessionIdKey);
      } else {
        await prefs.setString(_activeSessionIdKey, id);
      }
    } catch (_) {}
  }
}

