import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:keryx_app/core/theme/app_theme.dart';

/// Modelo de categoria do acervo de imagens para Stories
class VerseBackgroundCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<VerseBackgroundImage> images;

  const VerseBackgroundCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.images,
  });
}

/// Modelo de imagem individual com miniatura leve e URL em alta resolução
class VerseBackgroundImage {
  final String id;
  final String thumb;
  final String url;

  const VerseBackgroundImage({
    required this.id,
    required this.thumb,
    required this.url,
  });
}

/// Tela de Edição Visual de Versículo para Stories e Redes Sociais
class VerseStoryEditorScreen extends StatefulWidget {
  final String verseText;
  final String reference;

  const VerseStoryEditorScreen({
    super.key,
    required this.verseText,
    required this.reference,
  });

  @override
  State<VerseStoryEditorScreen> createState() => _VerseStoryEditorScreenState();
}

class _VerseStoryEditorScreenState extends State<VerseStoryEditorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isExporting = false;

  // Acervo temático catalogado em altíssima resolução (80+ papéis de parede verticais 9:16)
  static const List<VerseBackgroundCategory> _catalog = [
    VerseBackgroundCategory(
      id: 'natureza_amanhecer',
      name: 'Amanhecer',
      icon: Icons.wb_sunny_rounded,
      images: [
        VerseBackgroundImage(
          id: 'am_01',
          thumb: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_02',
          thumb: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_03',
          thumb: 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_04',
          thumb: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_05',
          thumb: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_06',
          thumb: 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_07',
          thumb: 'https://images.unsplash.com/photo-1470246973918-29a93221c455?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1470246973918-29a93221c455?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_08',
          thumb: 'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_09',
          thumb: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'am_10',
          thumb: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'montanhas_solidez',
      name: 'Montanhas',
      icon: Icons.terrain_rounded,
      images: [
        VerseBackgroundImage(
          id: 'mt_01',
          thumb: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_02',
          thumb: 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_03',
          thumb: 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_04',
          thumb: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_05',
          thumb: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_06',
          thumb: 'https://images.unsplash.com/photo-1434394354979-a235cd36269d?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1434394354979-a235cd36269d?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_07',
          thumb: 'https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_08',
          thumb: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_09',
          thumb: 'https://images.unsplash.com/photo-1516655855035-d5215bcb5604?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1516655855035-d5215bcb5604?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'mt_10',
          thumb: 'https://images.unsplash.com/photo-1491555103944-7c647fd857e6?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1491555103944-7c647fd857e6?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'ceus_estrelas',
      name: 'Céus & Noite',
      icon: Icons.auto_awesome_rounded,
      images: [
        VerseBackgroundImage(
          id: 'ce_01',
          thumb: 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_02',
          thumb: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_03',
          thumb: 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_04',
          thumb: 'https://images.unsplash.com/photo-1502134249126-9f3755a50d78?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1502134249126-9f3755a50d78?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_05',
          thumb: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_06',
          thumb: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_07',
          thumb: 'https://images.unsplash.com/photo-1517685352821-92cf88aee5a5?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1517685352821-92cf88aee5a5?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_08',
          thumb: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_09',
          thumb: 'https://images.unsplash.com/photo-1531306728370-e2ebd9d7bb99?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1531306728370-e2ebd9d7bb99?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ce_10',
          thumb: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'aguas_oceanos',
      name: 'Águas Vivas',
      icon: Icons.water_drop_rounded,
      images: [
        VerseBackgroundImage(
          id: 'ag_01',
          thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_02',
          thumb: 'https://images.unsplash.com/photo-1498855926480-d98e83099315?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1498855926480-d98e83099315?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_03',
          thumb: 'https://images.unsplash.com/photo-1439405326854-014607f694d7?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1439405326854-014607f694d7?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_04',
          thumb: 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_05',
          thumb: 'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_06',
          thumb: 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_07',
          thumb: 'https://images.unsplash.com/photo-1513553404607-988bf2703777?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1513553404607-988bf2703777?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_08',
          thumb: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_09',
          thumb: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'ag_10',
          thumb: 'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'florestas_natureza',
      name: 'Florestas',
      icon: Icons.forest_rounded,
      images: [
        VerseBackgroundImage(
          id: 'fl_01',
          thumb: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_02',
          thumb: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_03',
          thumb: 'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_04',
          thumb: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_05',
          thumb: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_06',
          thumb: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_07',
          thumb: 'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_08',
          thumb: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_09',
          thumb: 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fl_10',
          thumb: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'espiritual_oracao',
      name: 'Oração',
      icon: Icons.menu_book_rounded,
      images: [
        VerseBackgroundImage(
          id: 'or_01',
          thumb: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_02',
          thumb: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_03',
          thumb: 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_04',
          thumb: 'https://images.unsplash.com/photo-1507692049790-de58290a4334?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1507692049790-de58290a4334?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_05',
          thumb: 'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_06',
          thumb: 'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_07',
          thumb: 'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_08',
          thumb: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_09',
          thumb: 'https://images.unsplash.com/photo-1491841573634-28140fc7ced7?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1491841573634-28140fc7ced7?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'or_10',
          thumb: 'https://images.unsplash.com/photo-1497436072909-60f360e1d4b1?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1497436072909-60f360e1d4b1?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'flores_primavera',
      name: 'Flores',
      icon: Icons.local_florist_rounded,
      images: [
        VerseBackgroundImage(
          id: 'fr_01',
          thumb: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_02',
          thumb: 'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_03',
          thumb: 'https://images.unsplash.com/photo-1508615039623-a25605d2b022?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1508615039623-a25605d2b022?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_04',
          thumb: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_05',
          thumb: 'https://images.unsplash.com/photo-1526047932273-341f2a7631f9?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1526047932273-341f2a7631f9?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_06',
          thumb: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_07',
          thumb: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_08',
          thumb: 'https://images.unsplash.com/photo-1494548162494-384bba4ab999?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1494548162494-384bba4ab999?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_09',
          thumb: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'fr_10',
          thumb: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
    VerseBackgroundCategory(
      id: 'texturas_minimalistas',
      name: 'Escuros & Gradientes',
      icon: Icons.palette_rounded,
      images: [
        VerseBackgroundImage(
          id: 'tx_01',
          thumb: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_02',
          thumb: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_03',
          thumb: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_04',
          thumb: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_05',
          thumb: 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_06',
          thumb: 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_07',
          thumb: 'https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_08',
          thumb: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_09',
          thumb: 'https://images.unsplash.com/photo-1557683316-973673baf926?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1557683316-973673baf926?w=1080&h=1920&fit=crop&q=85',
        ),
        VerseBackgroundImage(
          id: 'tx_10',
          thumb: 'https://images.unsplash.com/photo-1557682250-33bd709cbe85?w=200&h=350&fit=crop',
          url: 'https://images.unsplash.com/photo-1557682250-33bd709cbe85?w=1080&h=1920&fit=crop&q=85',
        ),
      ],
    ),
  ];

  late int _selectedCategoryIndex;
  late String _selectedImageUrl;

  double _fontSize = 20.0;
  TextAlign _textAlign = TextAlign.center;
  double _overlayDarkness = 0.50;
  String _selectedFontFamily = 'Playfair Display';
  bool _showWatermark = true;

  final List<String> _fontOptions = [
    'Playfair Display',
    'Outfit',
    'Inter',
    'Cinzel',
    'Caveat',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryIndex = 0;
    _selectedImageUrl = _catalog[0].images[0].url;

    // Ajusta o tamanho inicial da fonte de acordo com a extensão do versículo
    if (widget.verseText.length > 250) {
      _fontSize = 16.0;
    } else if (widget.verseText.length > 150) {
      _fontSize = 18.0;
    } else {
      _fontSize = 21.0;
    }
  }

  TextStyle _getStoryTextStyle() {
    switch (_selectedFontFamily) {
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.45,
        );
      case 'Cinzel':
        return GoogleFonts.cinzel(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.45,
        );
      case 'Caveat':
        return GoogleFonts.caveat(
          fontSize: _fontSize + 4,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.35,
        );
      case 'Inter':
        return GoogleFonts.inter(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.45,
        );
      case 'Outfit':
      default:
        return GoogleFonts.outfit(
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.45,
        );
    }
  }

  Widget _buildAdaptiveImage({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    Key? key,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        key: key,
        fit: fit,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ??
              Container(
                color: const Color(0xFF161B2B),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.kPrimaryGold,
                    ),
                  ),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                color: const Color(0xFF1E2235),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                    size: 32,
                  ),
                ),
              );
        },
      );
    } else {
      return CachedNetworkImage(
        key: key,
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (_, __) =>
            placeholder ??
            Container(
              color: const Color(0xFF161B2B),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
              ),
            ),
        errorWidget: (_, __, ___) =>
            errorWidget ??
            Container(
              color: const Color(0xFF1E2235),
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 32,
                ),
              ),
            ),
      );
    }
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Captura o Story em 3x pixelRatio para nitidez 1080x1920 (Retina / 4K)
      final imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 120),
      );

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Não foi possível capturar a imagem.');
      }

      final fileName = 'versiculo_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        // No Flutter Web usa XFile em memória diretamente
        final xfile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: fileName,
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [xfile],
            text: '${widget.reference} • KeryxApp',
          ),
        );
      } else {
        // Em Android, iOS e Desktop usa arquivo temporário local
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(imageBytes);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: '${widget.reference} • Compartilhado via KeryxApp',
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E2235),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.kPrimaryGold, size: 20),
                SizedBox(width: 10),
                Text('Imagem gerada com sucesso!', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Erro ao exportar Story: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final currentCategory = _catalog[_selectedCategoryIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          tooltip: 'Fechar',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Criar Story com Versículo',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          _isExporting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppTheme.kPrimaryGold,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.kPrimaryGold,
                      backgroundColor: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      'Compartilhar',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _exportAndShare,
                  ),
                ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ÁREA PRINCIPAL DE PREVIEW DO STORY (Proporção 9:16)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Imagem de Fundo (Unsplash HD)
                            _buildAdaptiveImage(
                              key: ValueKey(_selectedImageUrl),
                              imageUrl: _selectedImageUrl,
                              fit: BoxFit.cover,
                            ),

                            // 2. Camada de Gradiente / Contraste Regulável
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: (_overlayDarkness * 0.7).clamp(0.0, 1.0)),
                                    Colors.black.withValues(alpha: _overlayDarkness.clamp(0.0, 1.0)),
                                    Colors.black.withValues(
                                      alpha: (_overlayDarkness * 1.25).clamp(0.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 3. Conteúdo Central: Versículo, Referência e Marca
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Ícone decorativo de aspas bíblicas
                                  Icon(
                                    Icons.format_quote_rounded,
                                    size: 32,
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(height: 12),

                                  // Texto do Versículo
                                  Text(
                                    widget.verseText,
                                    textAlign: _textAlign,
                                    style: _getStoryTextStyle().copyWith(
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 12,
                                          color: Colors.black87,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 22),

                                  // Badge da Referência Bíblica
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      widget.reference.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ),

                                  if (_showWatermark) ...[
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.auto_stories_rounded,
                                          size: 13,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'KeryxApp • Bíblia Sagrada',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // BARRA DE CONTROLES RÁPIDOS DE TIPOGRAFIA E CONTRASTE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161926),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  // Alinhamento
                  IconButton(
                    icon: Icon(
                      _textAlign == TextAlign.left
                          ? Icons.format_align_left_rounded
                          : _textAlign == TextAlign.center
                              ? Icons.format_align_center_rounded
                              : Icons.format_align_right_rounded,
                      color: AppTheme.kPrimaryGold,
                      size: 20,
                    ),
                    tooltip: 'Alinhamento',
                    onPressed: () {
                      setState(() {
                        if (_textAlign == TextAlign.center) {
                          _textAlign = TextAlign.left;
                        } else if (_textAlign == TextAlign.left) {
                          _textAlign = TextAlign.right;
                        } else {
                          _textAlign = TextAlign.center;
                        }
                      });
                    },
                  ),

                  // Tamanho da Fonte (- e +)
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, color: Colors.white70, size: 18),
                    tooltip: 'Diminuir Fonte',
                    onPressed: () => setState(() => _fontSize = (_fontSize - 1.5).clamp(13.0, 32.0)),
                  ),
                  Text(
                    '${_fontSize.toInt()}px',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white70, size: 18),
                    tooltip: 'Aumentar Fonte',
                    onPressed: () => setState(() => _fontSize = (_fontSize + 1.5).clamp(13.0, 32.0)),
                  ),

                  const SizedBox(width: 8),

                  // Slider de Contraste / Escurecimento
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.brightness_medium_rounded, size: 17, color: Colors.white60),
                        Expanded(
                          child: Slider(
                            value: _overlayDarkness,
                            min: 0.15,
                            max: 0.85,
                            thumbColor: AppTheme.kPrimaryGold,
                            activeColor: AppTheme.kPrimaryGold,
                            inactiveColor: Colors.white24,
                            onChanged: (val) => setState(() => _overlayDarkness = val),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Alternar Marca D'água
                  IconButton(
                    icon: Icon(
                      _showWatermark ? Icons.verified_rounded : Icons.verified_outlined,
                      color: _showWatermark ? AppTheme.kPrimaryGold : Colors.white38,
                      size: 19,
                    ),
                    tooltip: _showWatermark ? "Remover Marca d'água" : "Exibir Marca d'água",
                    onPressed: () => setState(() => _showWatermark = !_showWatermark),
                  ),
                ],
              ),
            ),

            // SELETOR DE FAMÍLIA DE FONTE
            Container(
              height: 38,
              color: const Color(0xFF131622),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: _fontOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final font = _fontOptions[index];
                  final isSelected = font == _selectedFontFamily;
                  return InkWell(
                    onTap: () => setState(() => _selectedFontFamily = font),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.kPrimaryGold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.kPrimaryGold : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          font,
                          style: GoogleFonts.outfit(
                            color: isSelected ? AppTheme.kPrimaryGold : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // SELETOR DE CATEGORIAS TEMÁTICAS (CHIPS)
            Container(
              height: 42,
              color: const Color(0xFF10131E),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                itemCount: _catalog.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _catalog[index];
                  final isSelected = index == _selectedCategoryIndex;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = index;
                        _selectedImageUrl = cat.images.first.url;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.kPrimaryGold : const Color(0xFF1A1E2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.kPrimaryGold : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 14,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: GoogleFonts.outfit(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // CARROSSEL DE MINIATURAS DAS IMAGENS DA CATEGORIA
            Container(
              height: 90 + bottomSafe,
              padding: EdgeInsets.only(bottom: bottomSafe > 0 ? bottomSafe : 8, top: 8),
              color: const Color(0xFF0C0E17),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: currentCategory.images.length,
                itemBuilder: (context, index) {
                  final img = currentCategory.images[index];
                  final isSelected = img.url == _selectedImageUrl;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedImageUrl = img.url),
                    child: Container(
                      width: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.kPrimaryGold : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildAdaptiveImage(
                          key: ValueKey(img.thumb),
                          imageUrl: img.thumb,
                          fit: BoxFit.cover,
                          placeholder: Container(color: Colors.white10),
                          errorWidget: Container(color: Colors.black26),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
