import 'dart:convert';
import 'dart:collection';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class BookMetadata {
  final String? originalCoverUrl;
  final String? description;
  final List<String> authors;
  final int? pageCount;
  final bool isRealPdfCover;

  String? get coverUrl {
    if (kIsWeb && originalCoverUrl != null && originalCoverUrl!.startsWith('http') && !originalCoverUrl!.contains('wsrv.nl')) {
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(originalCoverUrl!)}';
    }
    return originalCoverUrl;
  }

  BookMetadata({
    String? coverUrl,
    this.description,
    required this.authors,
    this.pageCount,
    this.isRealPdfCover = false,
  }) : originalCoverUrl = coverUrl;

  Map<String, dynamic> toJson() => {
    'coverUrl': originalCoverUrl,
    'description': description,
    'authors': authors,
    'pageCount': pageCount,
    'isRealPdfCover': isRealPdfCover,
  };

  factory BookMetadata.fromJson(Map<String, dynamic> json) {
    return BookMetadata(
      coverUrl: json['coverUrl'],
      description: json['description'],
      authors: List<String>.from(json['authors'] ?? []),
      pageCount: json['pageCount'],
      isRealPdfCover: json['isRealPdfCover'] == true,
    );
  }
}

class BookCoverService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: kIsWeb ? null : {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    },
  ));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cachePrefix = 'book_meta_v9_';
  
  // Static queue to throttle requests
  static final Queue<Function> _requestQueue = Queue();
  static bool _isProcessingQueue = false;
  static final Set<String> _pendingKeys = {};
  static final Map<String, BookMetadata> _memoryCache = {};
  static DateTime? _googleBooksDisabledUntil;

  BookMetadata? getCachedMetadata(String title) {
    final cleanTitle = cleanTitleForSearch(title);
    if (cleanTitle.isEmpty) return null;
    final cacheKey = '$_cachePrefix$cleanTitle';
    return _memoryCache[cacheKey];
  }

  static void _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeFirst();
      try {
        await request();
      } catch (_) {}
    }

    _isProcessingQueue = false;
  }

  static String cleanTitleForSearch(String raw) {
    var t = raw;
    t = t.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'@\w+\s*-\s*'), '');
    t = t.replaceAll(RegExp(r'@\w+\s*'), '');
    t = t.replaceAll(RegExp(r'#\s*-\s*'), '');
    t = t.replaceAll('#', '');
    t = t.replaceAll(RegExp(r'^\s*\(\d*\)\s*'), '');
    t = t.replaceAll(RegExp(r'^\s*-\s*'), '');
    t = t.replaceAll('_', ' ');
    // Extra cleaner for special characters in file names
    t = t.replaceAll(RegExp(r'[\[\]]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.trim();
  }

  String _getFirestoreDocId(String cleanTitle) {
    final slug = cleanTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return slug.length > 100 ? slug.substring(0, 100) : slug;
  }

  Future<BookMetadata?> _getFromFirestore(String docId) async {
    try {
      final doc = await _firestore.collection('book_covers').doc(docId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final coverUrl = data['coverUrl'] as String?;
        if (coverUrl != null && coverUrl.isNotEmpty) {
          return BookMetadata(
            coverUrl: coverUrl,
            description: data['description'] as String?,
            authors: data['authors'] != null
                ? List<String>.from(data['authors'])
                : [],
            pageCount: data['pageCount'] as int?,
            isRealPdfCover: data['isRealPdfCover'] == true,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToFirestore(
      String docId, String title, BookMetadata meta) async {
    try {
      await _firestore.collection('book_covers').doc(docId).set({
        'title': title,
        'coverUrl': meta.originalCoverUrl,
        'description': meta.description,
        'authors': meta.authors,
        'pageCount': meta.pageCount,
        'isRealPdfCover': meta.isRealPdfCover,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<BookMetadata?> getBookMetadata(String title, {String? localPath}) async {
    final cleanTitle = cleanTitleForSearch(title);
    if (cleanTitle.isEmpty) return null;

    final cacheKey = '$_cachePrefix$cleanTitle';
    final docId = _getFirestoreDocId(cleanTitle);

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(cacheKey);
    BookMetadata? cachedMeta;
    
    if (cachedData != null && cachedData.isNotEmpty && cachedData != 'not_found') {
      try {
        cachedMeta = BookMetadata.fromJson(jsonDecode(cachedData));
        _memoryCache[cacheKey] = cachedMeta;
      } catch (_) {}
    }

    // 1. If we have a local path (filesystem or asset) and we DON'T have a real pdf cover yet, extract it!
    if (!kIsWeb && localPath != null && (cachedMeta == null || !cachedMeta.isRealPdfCover)) {
      if (localPath.startsWith('assets/') || File(localPath).existsSync()) {
        final localMeta = await _extractLocalCover(title, localPath);
        if (localMeta != null) {
          _memoryCache[cacheKey] = localMeta;
          return localMeta;
        }
      }
    }

    if (cachedMeta != null) return cachedMeta;
    if (cachedData == 'not_found') return null;

    // 3. Check Firestore database cache (shared across all devices)
    final firestoreMeta = await _getFromFirestore(docId);
    if (firestoreMeta != null) {
      await prefs.setString(cacheKey, jsonEncode(firestoreMeta.toJson()));
      return firestoreMeta;
    }

    if (_pendingKeys.contains(cacheKey)) {
      return null;
    }
    _pendingKeys.add(cacheKey);

    final completer = Completer<BookMetadata?>();
    
    _requestQueue.add(() async {
      try {
        await Future.delayed(const Duration(milliseconds: 600));

        BookMetadata? result;

        // Try Google Books API
        result = await _tryGoogleBooks(cleanTitle);

        // If Google Books failed (e.g. rate limit 429, 403 or not found), fallback to Open Library
        if (result == null || result.coverUrl == null) {
          final olResult = await _tryOpenLibrary(cleanTitle);
          if (olResult != null) {
            result = BookMetadata(
              coverUrl: olResult.coverUrl ?? result?.coverUrl,
              description: olResult.description ?? result?.description,
              authors: olResult.authors.isNotEmpty ? olResult.authors : (result?.authors ?? []),
              pageCount: olResult.pageCount ?? result?.pageCount,
            );
          }
        }

        if (result != null && (result.coverUrl != null || result.authors.isNotEmpty)) {
          await prefs.setString(cacheKey, jsonEncode(result.toJson()));
          _memoryCache[cacheKey] = result;
          // Salva no banco de dados Firestore para que nunca mais precise buscar na internet
          if (result.coverUrl != null && !result.coverUrl!.startsWith('file://')) {
            await _saveToFirestore(docId, cleanTitle, result);
          }
          completer.complete(result);
        } else {
          // Only cache 'not_found' if both APIs answered without rate limiting
          await prefs.setString(cacheKey, 'not_found');
          completer.complete(null);
        }
      } catch (e) {
        completer.complete(null);
      } finally {
        _pendingKeys.remove(cacheKey);
      }
    });
    
    _processQueue();
    return completer.future;
  }

  Future<BookMetadata?> _tryGoogleBooks(String queryTitle) async {
    if (_googleBooksDisabledUntil != null &&
        DateTime.now().isBefore(_googleBooksDisabledUntil!)) {
      return null;
    }

    try {
      final apiKey = dotenv.env['GOOGLE_BOOKS_API_KEY'] ?? dotenv.env['FIREBASE_API_KEY'];
      final keyParam = (apiKey != null && apiKey.isNotEmpty) ? '&key=$apiKey' : '';
      final query = Uri.encodeQueryComponent(queryTitle);
      
      final response = await _dio.get(
        'https://www.googleapis.com/books/v1/volumes?q=$query$keyParam&maxResults=1',
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 503 ||
          response.statusCode == 500 ||
          response.statusCode == 429) {
        // Se a API do Google Books estiver instável ou em manutenção, desativa temporariamente para não poluir o console
        _googleBooksDisabledUntil = DateTime.now().add(const Duration(minutes: 5));
        return null;
      }

      if (response.statusCode == 403) {
        _googleBooksDisabledUntil = DateTime.now().add(const Duration(minutes: 10));
        return null;
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['items'] != null && (data['items'] as List).isNotEmpty) {
          final volumeInfo = data['items'][0]['volumeInfo'];
          final googleTitle = (volumeInfo['title'] as String? ?? '').toLowerCase();
          
          final cleanQuery = queryTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúâêîôûãõç\s]'), ' ');
          final queryKeywords = cleanQuery.split(' ').where((w) => w.length > 3 && !['para', 'com', 'pelo', 'pela', 'sobre', 'livro'].contains(w)).toList();
          
          bool hasKeywordMatch = queryKeywords.isEmpty;
          for (final kw in queryKeywords) {
            if (googleTitle.contains(kw)) {
              hasKeywordMatch = true;
              break;
            }
          }

          if (!hasKeywordMatch) {
            return null;
          }
          
          String? coverUrl;
          if (volumeInfo['imageLinks'] != null) {
            coverUrl = volumeInfo['imageLinks']['thumbnail'] ?? 
                       volumeInfo['imageLinks']['smallThumbnail'];
            if (coverUrl != null && coverUrl.startsWith('http://')) {
              coverUrl = coverUrl.replaceFirst('http://', 'https://');
            }
          }

          String? description = volumeInfo['description'];
          List<String> authors = [];
          if (volumeInfo['authors'] != null) {
            authors = List<String>.from(volumeInfo['authors']);
          }
          int? pageCount = volumeInfo['pageCount'];

          return BookMetadata(
            coverUrl: coverUrl,
            description: description,
            authors: authors,
            pageCount: pageCount,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<BookMetadata?> _tryOpenLibrary(String queryTitle) async {
    try {
      final q = Uri.encodeQueryComponent(queryTitle);
      final resp = await _dio.get(
        'https://openlibrary.org/search.json?q=$q&limit=1',
        options: Options(
          validateStatus: (s) => true,
        ),
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final docs = resp.data['docs'] as List<dynamic>?;
        if (docs != null && docs.isNotEmpty) {
          final doc = docs[0];
          final coverI = doc['cover_i'];
          final authors = doc['author_name'] != null 
              ? List<String>.from(doc['author_name']) 
              : <String>[];
          String? coverUrl;
          if (coverI != null) {
            coverUrl = 'https://covers.openlibrary.org/b/id/$coverI-M.jpg';
          }

          return BookMetadata(
            coverUrl: coverUrl,
            authors: authors,
            pageCount: doc['number_of_pages_median'] as int?,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<BookMetadata?> extractAndSaveCoverFromPdf(String title, String pdfPath) async {
    if (kIsWeb) return null;
    
    try {
      PdfDocument document;
      if (pdfPath.startsWith('assets/')) {
        final byteData = await rootBundle.load(pdfPath);
        document = await PdfDocument.openData(byteData.buffer.asUint8List());
      } else {
        final file = File(pdfPath);
        if (!await file.exists() || await file.length() < 100) return null;

        final raf = await file.open(mode: FileMode.read);
        try {
          final head = await raf.read(5);
          if (!String.fromCharCodes(head).startsWith('%PDF-')) return null;
        } finally {
          await raf.close();
        }
        document = await PdfDocument.openFile(pdfPath);
      }

      final realPageCount = document.pagesCount;
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      
      await page.close();
      await document.close();

      if (pageImage == null || pageImage.bytes.isEmpty) return null;

      final dir = await getApplicationDocumentsDirectory();
      final cleanTitle = cleanTitleForSearch(title);
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final coverFile = File('${dir.path}/cover_$safeTitle.jpg');

      String? base64Cover;
      try {
        final decoded = img.decodeImage(pageImage.bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: 450);
          final jpgBytes = img.encodeJpg(resized, quality: 80);
          await coverFile.writeAsBytes(jpgBytes);
          base64Cover = 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';
        } else {
          await coverFile.writeAsBytes(pageImage.bytes);
          base64Cover = 'data:image/png;base64,${base64Encode(pageImage.bytes)}';
        }
      } catch (_) {
        await coverFile.writeAsBytes(pageImage.bytes);
      }

      final isGuia = cleanTitle.toLowerCase().contains('guia de leitura');
      final realMeta = BookMetadata(
        coverUrl: 'file://${coverFile.path}',
        description: isGuia
            ? 'Guia completo para ler toda a Bíblia Sagrada em ordem cronológica durante um ano. Um plano estruturado com devocionais e reflexões para fortalecer a sua fé.'
            : null,
        authors: isGuia ? ['Sherman Viana (More Bible)'] : [],
        pageCount: realPageCount,
        isRealPdfCover: true,
      );

      final docId = _getFirestoreDocId(cleanTitle);
      await _firestore.collection('book_covers').doc(docId).set({
        'title': cleanTitle,
        if (base64Cover != null) 'coverUrl': base64Cover,
        'pageCount': realPageCount,
        'isRealPdfCover': true,
        'description': realMeta.description,
        'authors': realMeta.authors,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$cleanTitle';
      await prefs.setString(cacheKey, jsonEncode(realMeta.toJson()));
      _memoryCache[cacheKey] = realMeta;

      return realMeta;
    } catch (e) {
      debugPrint('Erro ao extrair capa real do PDF: $e');
      return null;
    }
  }

  Future<BookMetadata?> _extractLocalCover(String title, String pdfPath) async {
    return extractAndSaveCoverFromPdf(title, pdfPath);
  }
}
