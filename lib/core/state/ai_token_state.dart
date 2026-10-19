import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final aiTokenProvider = StateNotifierProvider<AiTokenNotifier, int>((ref) {
  return AiTokenNotifier();
});

class AiTokenNotifier extends StateNotifier<int> {
  static const int maxTokens = 20;
  
  AiTokenNotifier() : super(maxTokens) {
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('ai_token_date') ?? '';
    final today = DateTime.now().toIso8601String().split('T').first; // YYYY-MM-DD
    
    if (lastDate != today) {
      // Novo dia, reseta as cotas
      await prefs.setString('ai_token_date', today);
      await prefs.setInt('ai_token_count', maxTokens);
      state = maxTokens;
    } else {
      state = prefs.getInt('ai_token_count') ?? maxTokens;
    }
  }

  Future<bool> consumeToken() async {
    if (state <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    state = state - 1;
    await prefs.setInt('ai_token_count', state);
    return true;
  }
}
