import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/study_plan.dart';

class PlanRepository {
  final AssetBundle _bundle;

  PlanRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Caminho padrão para o plano cronológico
  static const String chronologicalPlanAsset =
      'assets/data/plans/cronologico_52.json';

  /// Carrega e analisa o plano cronológico de 52 semanas
  Future<StudyPlan> loadChronologicalPlan() async {
    return loadPlanFromAsset(chronologicalPlanAsset);
  }

  /// Carrega qualquer plano pelo seu ID de asset (ex.: 'cronologico_52')
  Future<StudyPlan> loadPlan(String planId) async {
    final assetPath = planId.endsWith('.json')
        ? 'assets/data/plans/$planId'
        : 'assets/data/plans/$planId.json';
    return loadPlanFromAsset(assetPath);
  }

  /// Carrega e analisa um plano a partir de um caminho de asset
  Future<StudyPlan> loadPlanFromAsset(String assetPath) async {
    final jsonString = await _bundle.loadString(assetPath);
    return parsePlanJson(jsonString);
  }

  /// Faz o parse síncrono de uma string JSON para o modelo StudyPlan
  StudyPlan parsePlanJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
    return StudyPlan.fromJson(data);
  }
}

/// Provider do repositório de planos de estudo
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});
