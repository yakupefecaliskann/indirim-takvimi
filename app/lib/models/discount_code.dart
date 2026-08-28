import 'campaign.dart' show dateOnly;

/// Kaynaklarda bu kadar süredir görülmeyen fırsat artık gösterilmez.
///
/// Boru hattı sessizce bozulsa bile kullanıcıya bayat bilgi sunulmamasını
/// sağlayan tek mekanizma budur.
const Duration kOfferStaleAfter = Duration(days: 30);

/// Canlı kaynaklardan toplanan tek bir fırsat.
///
/// İki biçimi var:
/// * **Kodlu fırsat** — [code] dolu, panoya kopyalanabilir.
/// * **Kodsuz kampanya** — [code] boş; Türkiye'deki perakende kampanyalarının
///   çoğu kod istemiyor, indirim kasada otomatik uygulanıyor.
class DiscountCode {
  const DiscountCode({
    required this.id,
    required this.brandId,
    required this.title,
    this.code,
    this.description = '',
    this.requiresCode = false,
    this.expiresAt,
    this.lastSeenAt,
    this.sourceUrl,
  });

  final String id;
  final String brandId;
  final String title;

  /// Kopyalanabilir kod. Kaynak kodu açıkça yayınlamıyorsa null olur.
  final String? code;
  final String description;

  /// Fırsat bir kod gerektiriyor ama kod dizesi kaynakta açık değil.
  final bool requiresCode;

  final DateTime? expiresAt;
  final DateTime? lastSeenAt;
  final String? sourceUrl;

  bool get hasCode => code != null && code!.isNotEmpty;

  bool isExpiredOn(DateTime now) =>
      expiresAt != null && dateOnly(now).isAfter(dateOnly(expiresAt!));

  bool isStaleOn(DateTime now) {
    if (lastSeenAt == null) return true;
    return dateOnly(now).difference(dateOnly(lastSeenAt!)) > kOfferStaleAfter;
  }

  bool isShowableOn(DateTime now) => !isExpiredOn(now) && !isStaleOn(now);

  static DiscountCode? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final String? id = _asString(raw['id']);
    final String? brandId = _asString(raw['brand']);
    final String? code = _asString(raw['code']);
    final String? title = _asString(raw['title']);
    // Ne kod ne başlık varsa gösterilecek bir şey yok.
    if (id == null || brandId == null || (code == null && title == null)) {
      return null;
    }
    return DiscountCode(
      id: id,
      brandId: brandId,
      title: title ?? code!,
      code: code,
      description: _asString(raw['description']) ?? '',
      requiresCode: raw['requiresCode'] == true,
      expiresAt: _asDate(raw['expiresAt']),
      lastSeenAt: _asDate(raw['lastSeenAt']),
      sourceUrl: _asString(raw['sourceUrl']),
    );
  }
}

String? _asString(Object? v) {
  if (v is! String) return null;
  final String s = v.trim();
  return s.isEmpty ? null : s;
}

DateTime? _asDate(Object? v) {
  final String? s = _asString(v);
  if (s == null) return null;
  final DateTime? parsed = DateTime.tryParse(s);
  return parsed == null ? null : dateOnly(parsed);
}
