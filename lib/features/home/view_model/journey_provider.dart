import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo que representa o estado da jornada do usuário
class JourneyState {
  /// Lista de 7 dias (dom..sab) com booleano indicando se houve atividade
  final List<bool> weekDays;

  /// Quantidade de dias consecutivos com atividade (streak)
  final int streak;

  /// Total de dias ativos registrados (histórico)
  final int totalDaysActive;

  /// Total de sessões de leitura registradas
  final int totalSessions;

  const JourneyState({
    required this.weekDays,
    required this.streak,
    required this.totalDaysActive,
    required this.totalSessions,
  });

  JourneyState copyWith({
    List<bool>? weekDays,
    int? streak,
    int? totalDaysActive,
    int? totalSessions,
  }) {
    return JourneyState(
      weekDays: weekDays ?? this.weekDays,
      streak: streak ?? this.streak,
      totalDaysActive: totalDaysActive ?? this.totalDaysActive,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }

  static JourneyState get empty => const JourneyState(
        weekDays: [false, false, false, false, false, false, false],
        streak: 0,
        totalDaysActive: 0,
        totalSessions: 0,
      );
}

class JourneyNotifier extends StateNotifier<JourneyState> {
  JourneyNotifier() : super(JourneyState.empty) {
    _load();
  }

  static const _keyActiveDates = 'journey_active_dates';
  static const _keyTotalSessions = 'journey_total_sessions';

  /// Método estático para registrar atividade sem referência ao notifier.
  /// Pode ser chamado de qualquer parte do app (ex: bible_state.dart).
  static Future<void> recordActivityStatic() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final List<String> rawDates = prefs.getStringList(_keyActiveDates) ?? [];
    final Set<String> activeDates = rawDates.toSet();
    activeDates.add(today);

    // Remove datas com mais de 90 dias
    final cutoff = now.subtract(const Duration(days: 90));
    activeDates.removeWhere((d) {
      final parsed = DateTime.tryParse(d);
      return parsed != null && parsed.isBefore(cutoff);
    });

    final int newSessions = (prefs.getInt(_keyTotalSessions) ?? 0) + 1;
    await prefs.setInt(_keyTotalSessions, newSessions);
    await prefs.setStringList(_keyActiveDates, activeDates.toList());
  }

  /// Carrega os dados persistidos e recalcula o estado atual
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Conjunto de datas com atividade (formato "yyyy-MM-dd")
    final List<String> rawDates =
        prefs.getStringList(_keyActiveDates) ?? [];
    final Set<String> activeDates = rawDates.toSet();
    final int totalSessions = prefs.getInt(_keyTotalSessions) ?? 0;

    state = _computeState(activeDates, totalSessions);
  }

  /// Registra uma atividade de leitura/estudo para hoje e atualiza o estado
  Future<void> recordActivity() async {
    await recordActivityStatic();
    await _load(); // recarrega estado reativo após persistir
  }

  /// Calcula o estado da semana atual (dom-sab), streak e totais
  JourneyState _computeState(Set<String> activeDates, int totalSessions) {
    final now = DateTime.now();

    // Calcula o dia da semana atual (0=dom, 1=seg..6=sab)
    // Dart: weekday: 1=seg, 7=dom → ajustamos para domingos no índice 0
    final todayWeekday = now.weekday % 7; // 0=dom,...,6=sab

    // Calcula o domingo mais recente para montar a semana atual
    final startOfWeek =
        now.subtract(Duration(days: todayWeekday));
    
    final List<bool> weekDays = List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      return activeDates.contains(_dateKey(day));
    });

    // Calcula streak (dias consecutivos incluindo hoje ou ontem)
    int streak = 0;
    DateTime checkDay = now;
    while (true) {
      if (activeDates.contains(_dateKey(checkDay))) {
        streak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        // Permite que o streak não quebre se hoje ainda não houve atividade
        if (streak == 0 &&
            activeDates.contains(_dateKey(checkDay.subtract(const Duration(days: 1))))) {
          checkDay = checkDay.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }

    return JourneyState(
      weekDays: weekDays,
      streak: streak,
      totalDaysActive: activeDates.length,
      totalSessions: totalSessions,
    );
  }

  String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

/// Provider global da jornada do usuário
final journeyProvider =
    StateNotifierProvider<JourneyNotifier, JourneyState>(
  (ref) => JourneyNotifier(),
);
