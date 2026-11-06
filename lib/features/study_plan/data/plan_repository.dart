import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/study_plan.dart';

@immutable
class AvailablePlanInfo {
  final String id;
  final String title;
  final String description;
  final int totalDays;
  final int totalWeeks;
  final String tag;
  final IconData icon;

  const AvailablePlanInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.totalDays,
    required this.totalWeeks,
    required this.tag,
    required this.icon,
  });
}

class PlanRepository {
  final AssetBundle _bundle;

  PlanRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Catálogo de planos de leitura bíblica disponíveis
  static const List<AvailablePlanInfo> catalog = [
    AvailablePlanInfo(
      id: 'cronologico-52',
      title: 'Bíblia em Ordem Cronológica',
      description: 'Leia toda a Escritura Sagrada em 1 ano, acompanhando a ordem dos acontecimentos históricos e proféticos do Gênesis ao Apocalipse.',
      totalDays: 364,
      totalWeeks: 52,
      tag: 'Histórico & Profético',
      icon: Icons.history_edu_rounded,
    ),
    AvailablePlanInfo(
      id: 'canonico-365',
      title: 'Bíblia Completa em 1 Ano',
      description: 'Leia toda a Bíblia de Gênesis a Apocalipse na ordem canônica tradicional (cerca de 3 capítulos por dia).',
      totalDays: 365,
      totalWeeks: 53,
      tag: 'Gênesis ao Apocalipse',
      icon: Icons.menu_book_rounded,
    ),
    AvailablePlanInfo(
      id: 'novo-testamento-180',
      title: 'Novo Testamento em 6 Meses',
      description: 'Leitura completa dos 27 livros do Novo Testamento em ritmo tranquilo (1 a 2 capítulos por dia).',
      totalDays: 180,
      totalWeeks: 26,
      tag: 'Novo Testamento',
      icon: Icons.auto_stories_rounded,
    ),
    AvailablePlanInfo(
      id: 'evangelhos-90',
      title: 'Os 4 Evangelhos em 90 Dias',
      description: 'Mergulho profundo na vida, ministério e ensinamentos de Jesus (Mateus, Marcos, Lucas e João).',
      totalDays: 90,
      totalWeeks: 13,
      tag: 'Vida de Jesus',
      icon: Icons.local_fire_department_rounded,
    ),
    AvailablePlanInfo(
      id: 'salmos-proverbios-60',
      title: 'Sabedoria & Louvor em 60 Dias',
      description: 'Todos os 150 Salmos e 31 capítulos de Provérbios para enriquecer sua oração diária e comunhão.',
      totalDays: 60,
      totalWeeks: 9,
      tag: 'Devocional & Oração',
      icon: Icons.favorite_rounded,
    ),
    AvailablePlanInfo(
      id: 'cartas-paulinas-30',
      title: 'Epístolas de Paulo em 30 Dias',
      description: 'Estudo concentrado das 13 cartas paulinas de Romanos a Filemom para edificação na fé e doutrina.',
      totalDays: 30,
      totalWeeks: 5,
      tag: 'Doutrina & Fé',
      icon: Icons.mail_outline_rounded,
    ),
  ];

  static AvailablePlanInfo getPlanInfo(String planId) {
    return catalog.firstWhere(
      (p) => p.id == planId,
      orElse: () => catalog.first,
    );
  }

  /// Caminho padrão para o plano cronológico
  static const String chronologicalPlanAsset =
      'assets/data/plans/cronologico_52.json';

  /// Carrega e analisa o plano cronológico de 52 semanas
  Future<StudyPlan> loadChronologicalPlan() async {
    return loadPlanFromAsset(chronologicalPlanAsset);
  }

  /// Carrega qualquer plano pelo seu ID de asset (ex.: 'cronologico-52' ou 'canonico-365')
  Future<StudyPlan> loadPlan(String planId) async {
    final cleanId = planId.replaceAll('-', '_');
    final assetPath = cleanId.endsWith('.json')
        ? 'assets/data/plans/$cleanId'
        : 'assets/data/plans/$cleanId.json';
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
