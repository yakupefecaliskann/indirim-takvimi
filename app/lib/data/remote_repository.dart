import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'merge.dart';

/// Uzak JSON'u çeker ve diske önbelleğe alır.
///
/// Tasarım kuralı: **ağ hatası hiçbir zaman istisnaya dönüşmez.** Çekme
/// başarısız olursa önbellek, önbellek de yoksa boş veri döner; uygulama
/// hesaplanan takvimle çalışmaya devam eder.
class RemoteRepository {
  RemoteRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _cacheFileName = 'campaigns_cache.json';

  Future<File> _cacheFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<RemoteData> readCache() async {
    try {
      final File f = await _cacheFile();
      if (!await f.exists()) return RemoteData.empty;
      return RemoteData.parse(await f.readAsString());
    } catch (e) {
      debugPrint('Önbellek okunamadı: $e');
      return RemoteData.empty;
    }
  }

  /// Uzak veriyi çeker. Başarısız olursa önbelleğe düşer.
  ///
  /// Boş ya da okunamayan yanıt önbelleği **ezmez** — sunucu tarafında bir
  /// bozulma olursa telefondaki son iyi veri korunur.
  Future<RemoteData> refresh({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final http.Response res =
          await _client.get(Uri.parse(kDataUrl)).timeout(timeout);
      if (res.statusCode != 200) {
        debugPrint('Veri çekilemedi: HTTP ${res.statusCode}');
        return readCache();
      }
      // GitHub raw çıktısı UTF-8; res.body latin1 varsayabildiği için
      // bayt dizisinden açıkça çözülüyor (Türkçe karakterler bozulmasın).
      final String body = utf8DecodeSafe(res.bodyBytes);
      final RemoteData parsed = RemoteData.parse(body);
      if (parsed.isEmpty) {
        debugPrint('Gelen veri boş ya da okunamadı; önbellek korunuyor.');
        return readCache();
      }
      try {
        await (await _cacheFile()).writeAsString(body);
      } catch (e) {
        debugPrint('Önbellek yazılamadı: $e');
      }
      return parsed;
    } catch (e) {
      debugPrint('Ağ hatası, önbelleğe düşülüyor: $e');
      return readCache();
    }
  }
}

String utf8DecodeSafe(List<int> bytes) {
  try {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  } catch (_) {
    return '';
  }
}
