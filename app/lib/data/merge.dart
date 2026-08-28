import 'dart:convert';

import '../models/brand.dart';
import '../models/campaign.dart';
import '../models/discount_code.dart';

/// Uzak JSON'un ayrıştırılmış hâli.
///
/// Ayrıştırma **hiçbir koşulda istisna fırlatmaz**. Veri kazınarak üretildiği
/// için bozuk gelmesi olağan bir durum; tek bir hatalı kaydın uygulamayı
/// düşürmesine izin verilmez. Tamamen okunamayan veri boş sonuç verir ve
/// uygulama hesaplanan takvimle çalışmaya devam eder.
class RemoteData {
  const RemoteData({
    required this.campaigns,
    required this.codes,
    this.generatedAt,
  });

  final List<Campaign> campaigns;
  final List<DiscountCode> codes;
  final DateTime? generatedAt;

  static const RemoteData empty =
      RemoteData(campaigns: <Campaign>[], codes: <DiscountCode>[]);

  bool get isEmpty => campaigns.isEmpty && codes.isEmpty;

  static RemoteData parse(String jsonText) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map) return empty;

    final List<Campaign> campaigns = <Campaign>[
      if (decoded['campaigns'] is List)
        for (final Object? raw in decoded['campaigns'] as List)
          if (Campaign.tryFromJson(raw) case final Campaign c) c,
    ];
    final List<DiscountCode> codes = <DiscountCode>[
      if (decoded['codes'] is List)
        for (final Object? raw in decoded['codes'] as List)
          if (DiscountCode.tryFromJson(raw) case final DiscountCode c) c,
    ];
    final Object? gen = decoded['generatedAt'];
    return RemoteData(
      campaigns: campaigns,
      codes: codes,
      generatedAt: gen is String ? DateTime.tryParse(gen) : null,
    );
  }
}

/// Hesaplanan takvim ile uzak veriyi birleştirir.
///
/// Kural: aynı kimlikli uzak kayıt hesaplanan kaydı **tamamen ezer**. Böylece
/// haberlerden kesin tarih geldiğinde tahmin kendiliğinden gerçek tarihe
/// dönüşür. Uzakta karşılığı olmayan hesaplanan kayıt olduğu gibi kalır — ağ
/// hiç çalışmasa bile takvim dolu olur.
List<Campaign> mergeCampaigns({
  required List<Campaign> computed,
  required List<Campaign> remote,
  required DateTime now,
}) {
  final Map<String, Campaign> byId = <String, Campaign>{
    for (final Campaign c in computed) c.id: c,
  };
  for (final Campaign c in remote) {
    final Campaign? base = byId[c.id];
    // Hesaplanan bir kaydin uzerine yaziyorsak alan bazli birlestir: haber
    // kaynagi genelde yalnizca **baslangic** tarihini bilir, bitis tarihini
    // bilmez. Tam degistirme yapsaydik kampanya tek gunluk gorunur ve ertesi
    // gun "bitti" sayilip listeden duserdi.
    byId[c.id] = base == null
        ? c
        : base.copyWith(
            title: c.title,
            startsAt: c.startsAt,
            endsAt: c.endsAt,
            confidence: c.confidence,
            source: c.source,
            sourceUrl: c.sourceUrl,
            note: c.note,
            lastSeenAt: c.lastSeenAt,
          );
  }

  final List<Campaign> result = byId.values
      .where((Campaign c) => !c.isOver(now))
      // Bilinmeyen marka kimliği taşıyan kayıt arayüzde çizilemez; atlanır.
      .where((Campaign c) => c.brandIds.any((String id) => brandById(id) != null))
      .toList();
  result.sort((Campaign a, Campaign b) {
    final int byDate = a.startsAt.compareTo(b.startsAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  return result;
}

/// Gösterilebilir kodlar: süresi dolmamış ve son 30 gün içinde görülmüş olanlar.
///
/// [brokenIds] kullanıcının "işe yaramadı" dediği kodlardır; gizlenmez ama
/// listenin sonuna düşer.
List<DiscountCode> visibleCodes({
  required List<DiscountCode> codes,
  required DateTime now,
  Set<String> brokenIds = const <String>{},
}) {
  final List<DiscountCode> result = codes
      .where((DiscountCode c) => c.isShowableOn(now))
      .where((DiscountCode c) => brandById(c.brandId) != null)
      .toList();
  result.sort((DiscountCode a, DiscountCode b) {
    final bool aBroken = brokenIds.contains(a.id);
    final bool bBroken = brokenIds.contains(b.id);
    if (aBroken != bBroken) return aBroken ? 1 : -1;
    // Sonra en yakın zamanda doğrulanan üstte.
    final DateTime aSeen = a.lastSeenAt ?? DateTime(1970);
    final DateTime bSeen = b.lastSeenAt ?? DateTime(1970);
    final int bySeen = bSeen.compareTo(aSeen);
    return bySeen != 0 ? bySeen : a.id.compareTo(b.id);
  });
  return result;
}
