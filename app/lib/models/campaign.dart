/// Bir kampanyanın tarihine ne kadar güvenildiği.
///
/// Arayüz tahmini bir tarihi asla kesin bir tarihmiş gibi göstermez.
enum CampaignConfidence {
  /// Kodun kendi hesapladığı, geçmiş desene dayanan tarih.
  predicted,

  /// Haber ya da agregatör kaynağında ilan edilmiş kesin tarih.
  announced,

  /// Şu anda yürürlükte olduğu doğrulanmış kampanya.
  live,
}

enum CampaignSource { computed, news, aggregator, brand }

/// Yalnızca gün hassasiyeti kullanılır; saat kısmı her zaman gece yarısıdır.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class Campaign {
  const Campaign({
    required this.id,
    required this.brandIds,
    required this.title,
    required this.startsAt,
    required this.confidence,
    required this.source,
    this.endsAt,
    this.sourceUrl,
    this.note,
    this.lastSeenAt,
  });

  final String id;
  final List<String> brandIds;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final CampaignConfidence confidence;
  final CampaignSource source;
  final String? sourceUrl;
  final String? note;
  final DateTime? lastSeenAt;

  /// Bugüne göre başlangıca kaç gün kaldığı. Başlamışsa negatif.
  int daysUntilStart(DateTime now) =>
      dateOnly(startsAt).difference(dateOnly(now)).inDays;

  bool isActiveOn(DateTime now) {
    final DateTime today = dateOnly(now);
    if (today.isBefore(dateOnly(startsAt))) return false;
    if (endsAt == null) return today == dateOnly(startsAt);
    return !today.isAfter(dateOnly(endsAt!));
  }

  bool isOver(DateTime now) {
    final DateTime last = dateOnly(endsAt ?? startsAt);
    return dateOnly(now).isAfter(last);
  }

  Campaign copyWith({
    CampaignConfidence? confidence,
    CampaignSource? source,
    DateTime? startsAt,
    DateTime? endsAt,
    String? title,
    String? sourceUrl,
    String? note,
    DateTime? lastSeenAt,
  }) => Campaign(
    id: id,
    brandIds: brandIds,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    note: note ?? this.note,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );

  /// Bozuk kayıtta istisna fırlatmak yerine null döner.
  ///
  /// Uzak veri kazınarak üretildiği için tek bir hatalı kaydın tüm listeyi
  /// düşürmesine izin verilmez.
  static Campaign? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final String? id = _asString(raw['id']);
    final String? title = _asString(raw['title']);
    final DateTime? startsAt = _asDate(raw['startsAt']);
    if (id == null || title == null || startsAt == null) return null;

    final List<String> brandIds = <String>[
      if (raw['brands'] is List)
        for (final Object? b in raw['brands'] as List)
          if (_asString(b) != null) _asString(b)!,
    ];
    if (brandIds.isEmpty) return null;

    return Campaign(
      id: id,
      brandIds: brandIds,
      title: title,
      startsAt: startsAt,
      endsAt: _asDate(raw['endsAt']),
      confidence: _confidenceFrom(_asString(raw['confidence'])),
      source: _sourceFrom(_asString(raw['source'])),
      sourceUrl: _asString(raw['sourceUrl']),
      note: _asString(raw['note']),
      lastSeenAt: _asDate(raw['lastSeenAt']),
    );
  }

  static CampaignConfidence _confidenceFrom(String? v) => switch (v) {
    'live' => CampaignConfidence.live,
    'announced' => CampaignConfidence.announced,
    _ => CampaignConfidence.predicted,
  };

  static CampaignSource _sourceFrom(String? v) => switch (v) {
    'news' => CampaignSource.news,
    'aggregator' => CampaignSource.aggregator,
    'brand' => CampaignSource.brand,
    _ => CampaignSource.computed,
  };
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
