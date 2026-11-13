import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utilitário de navegação responsiva e adaptativa para controle inteligente
/// de botões de retorno (seta de voltar) nas barras superiores e navegação do app.
///
/// Regras:
/// 1. Plataforma Web e Desktop (PC):
///    Usuários de computadores NÃO possuem botões físicos ou barra nativa de voltar do sistema operacional.
///    Portanto, a opção de voltar in-app deve SEMPRE permanecer acessível (retorna false).
/// 2. Dispositivo móvel ou tablet Android com botões nativos do sistema:
///    Se o aparelho tiver os botões de navegação nativos (barra de 3 botões na Safe Area / ViewPadding: Voltar ◀, Início ●, Recentes ◼),
///    a seta no topo é ocultada (retorna true), já que o usuário possui o botão nativo de voltar do próprio aparelho.
/// 3. Em aparelhos com navegação por gestos (sem botões) ou iOS:
///    A seta de voltar permanece visível para permitir o retorno com facilidade (retorna false).

/// Verifica se o dispositivo (celular ou tablet) possui os botões nativos de navegação
/// do sistema operacional (barra clássica de 3 botões na Safe Area com botão Voltar ◀).
bool hasDeviceNavigationButtons(BuildContext context) {
  if (kIsWeb) return false;

  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    // Em celulares e tablets em modo retrato ou paisagem com barra inferior (geralmente 40dp a 48dp):
    if (viewPadding.bottom >= 24.0) {
      return true;
    }
    // Em tablets Android em modo paisagem onde a barra do sistema fica na lateral:
    if (viewPadding.right >= 24.0 || viewPadding.left >= 24.0) {
      return true;
    }
  }

  return false;
}

/// Determina se a seta de voltar (<) no topo da tela deve ser ocultada.
bool shouldHideBackButton(BuildContext context) {
  // 1. Plataforma Web e Desktop: sempre exibir controles in-app
  if (kIsWeb) {
    return false;
  }

  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows) {
    return false;
  }

  // 2. Se o aparelho (celular ou tablet Android) possui os botões do próprio dispositivo
  // na barra da Safe Area (Voltar ◀, Início ●, Recentes ◼):
  if (hasDeviceNavigationButtons(context)) {
    return true;
  }

  // 3. Em dispositivos sem os botões (navegação por gestos ou iOS):
  return false;
}
