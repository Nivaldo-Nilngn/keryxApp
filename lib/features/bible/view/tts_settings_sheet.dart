import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/tts/tts_service.dart';
import 'package:keryx_app/core/services/tts/tts_player_provider.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

final autoScrollProvider = StateProvider<bool>((ref) => true);
final highlightVerseProvider = StateProvider<bool>((ref) => true);
final continuousReadingProvider = StateProvider<bool>((ref) => false);

class TtsSettingsSheet extends ConsumerWidget {
  const TtsSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final selectedVoice = ref.watch(ttsSelectedVoiceProvider);
    final currentRate = ref.watch(ttsRateProvider);
    final currentPitch = ref.watch(ttsPitchProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Future<void> restartCurrentVerseIfNeeded() async {
      final ttsState = ref.read(ttsPlayerProvider);
      if (ttsState.isPlaying) {
        final notifier = ref.read(ttsPlayerProvider.notifier);
        await notifier.pause();
        await Future.delayed(const Duration(milliseconds: 150));
        await notifier.resume();
      }
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: onSurface.withValues(alpha: 0.1), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      'CONFIGURAÇÕES DE LEITURA (TTS)',
                      style: GoogleFonts.outfit(
                        color: onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personalize a voz, velocidade e o timbre.',
                      style: GoogleFonts.outfit(
                        color: onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Voice Selection (Dropdown)
                    Text('VOZ RECOMENDADA', style: _sectionTitleStyle(context)),
                    const SizedBox(height: 12),
                    voicesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red)),
                      data: (voices) {
                        if (voices.isEmpty) return const Text('Nenhuma voz encontrada.');
                        
                        // Mostrar todas as vozes disponíveis
                        final recommended = voices.toList();
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: onSurface.withValues(alpha: 0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, String>>(
                              isExpanded: true,
                              value: recommended.any((v) => v['name'] == selectedVoice?['name']) 
                                  ? recommended.firstWhere((v) => v['name'] == selectedVoice?['name'])
                                  : recommended.isNotEmpty ? recommended.first : null,
                              items: recommended.asMap().entries.map((e) {
                                final rawName = e.value['name']?.toLowerCase() ?? '';
                                final cleanName = rawName.replaceAll('pt-br-', '').replaceAll('pt-br-x-', '');
                                
                                String type = (rawName.contains('network') || rawName.contains('online')) ? 'Online' : 'Offline';
                                
                                return DropdownMenuItem<Map<String, String>>(
                                  value: e.value,
                                  child: Text(
                                    'Voz ${e.key + 1} ($cleanName - $type)',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: onSurface,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (voice) {
                                if (voice != null) {
                                  ref.read(ttsSelectedVoiceProvider.notifier).selectVoice(voice);
                                  final ttsState = ref.read(ttsPlayerProvider);
                                  if (ttsState.isPlaying) {
                                    restartCurrentVerseIfNeeded();
                                  } else {
                                    ref.read(ttsServiceProvider).speak("Testando a leitura.", voice: voice);
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Speed Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VELOCIDADE', style: _sectionTitleStyle(context)),
                        Text('${(currentRate * 100).toInt()}%', style: GoogleFonts.outfit(color: onSurface, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: currentRate,
                      min: 0.1,
                      max: 1.5,
                      activeColor: const Color(0xFF4ADE80),
                      onChanged: (val) => ref.read(ttsRateProvider.notifier).setRate(val),
                      onChangeEnd: (val) => restartCurrentVerseIfNeeded(),
                    ),

                    const SizedBox(height: 24),
                    
                    // Pitch Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TIMBRE (GRAVE / AGUDO)', style: _sectionTitleStyle(context)),
                        Text('${(currentPitch * 100).toInt()}%', style: GoogleFonts.outfit(color: onSurface, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: currentPitch,
                      min: 0.5,
                      max: 2.0,
                      activeColor: const Color(0xFF4ADE80),
                      onChanged: (val) => ref.read(ttsPitchProvider.notifier).setPitch(val),
                      onChangeEnd: (val) => restartCurrentVerseIfNeeded(),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    Text('RECURSOS INTELIGENTES', style: _sectionTitleStyle(context)),
                    const SizedBox(height: 16),
                    _buildFeatureSwitch(
                      context, 
                      ref, 
                      'Auto-Rolar Tela', 
                      'Acompanha a leitura automaticamente',
                      Icons.swipe_down_rounded,
                      autoScrollProvider,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureSwitch(
                      context, 
                      ref, 
                      'Destacar Versículo', 
                      'Ilumina o texto que está sendo lido',
                      Icons.highlight_rounded,
                      highlightVerseProvider,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureSwitch(
                      context, 
                      ref, 
                      'Leitura Contínua', 
                      'Inicia o próximo capítulo ao terminar',
                      Icons.queue_play_next_rounded,
                      continuousReadingProvider,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom Bar with Reset
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: onSurface.withValues(alpha: 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(ttsRateProvider.notifier).setRate(0.45);
                        await ref.read(ttsPitchProvider.notifier).setPitch(0.9);
                        restartCurrentVerseIfNeeded();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Padrão de leitura restaurado!')));
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: Text('Padrão Realista'),
                      style: TextButton.styleFrom(
                        foregroundColor: onSurface.withValues(alpha: 0.7),
                        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Fechar',
                        style: GoogleFonts.outfit(color: onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSwitch(
    BuildContext context, 
    WidgetRef ref, 
    String title, 
    String subtitle, 
    IconData icon, 
    StateProvider<bool> provider,
  ) {
    final isEnabled = ref.watch(provider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled 
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.2) 
                  : onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: isEnabled ? const Color(0xFF4ADE80) : onSurface.withValues(alpha: 0.5), 
              size: 20
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeColor: const Color(0xFF4ADE80),
            onChanged: (val) => ref.read(provider.notifier).state = val,
          ),
        ],
      ),
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    return GoogleFonts.outfit(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
  }
}
