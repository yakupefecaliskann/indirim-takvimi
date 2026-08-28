import '../models/brand.dart';
import '../models/campaign.dart';

/// Katman 1 — uygulamanın içinde hesaplanan takvim.
///
/// Bu dosya hiçbir ağ çağrısı yapmaz ve hiçbir dış kaynağa bağlı değildir.
/// Scraper'lar bozulsa, sunucu kapansa, telefon tamamen çevrimdışı olsa bile
/// geri sayımlar ve bildirimler buradan üretilmeye devam eder. Uygulamanın
/// çalışacağına dair tek garanti budur.
///
/// Buradaki tarihler geçmiş desene dayanan **tahminlerdir**; hepsi
/// [CampaignConfidence.predicted] ile işaretlenir. Haber ya da agregatör
/// katmanından kesin tarih geldiğinde `merge.dart` bu kayıtları ezer.

/// [year]/[month] ayının [n]. [weekday] gününü döner (weekday: DateTime.monday…).
DateTime nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  final DateTime first = DateTime(year, month, 1);
  final int offset = (weekday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + (n - 1) * 7);
}

/// [year]/[month] ayının son [weekday] gününü döner.
DateTime lastWeekdayOfMonth(int year, int month, int weekday) {
  final int lastDay = DateTime(year, month + 1, 0).day;
  final DateTime last = DateTime(year, month, lastDay);
  final int offset = (last.weekday - weekday + 7) % 7;
  return DateTime(year, month, lastDay - offset);
}

/// Ayın son gününü döner (artık yıl şubatı dahil).
DateTime _endOfMonth(int year, int month) =>
    DateTime(year, month, DateTime(year, month + 1, 0).day);

Campaign _c({
  required String id,
  required List<String> brandIds,
  required String title,
  required DateTime startsAt,
  DateTime? endsAt,
  String? note,
}) => Campaign(
  id: id,
  brandIds: brandIds,
  title: title,
  startsAt: startsAt,
  endsAt: endsAt ?? startsAt,
  confidence: CampaignConfidence.predicted,
  source: CampaignSource.computed,
  note: note,
);

/// Verilen yıl için hesaplanabilen tüm kampanyalar.
///
/// Gratis / Watsons / Sephora / Rossmann'ın sabit bir indirim takvimi yok;
/// o markaların kampanyaları yalnızca canlı katmanlardan gelir.
List<Campaign> computedCampaignsForYear(int year) => <Campaign>[
  _c(
    id: 'inditex-kis-$year',
    brandIds: kInditexBrandIds,
    title: 'Inditex Kış Sezon Sonu İndirimi',
    // Kural: ocağın ilk çarşambası. 2026'da 7 Ocak.
    startsAt: nthWeekdayOfMonth(year, 1, DateTime.wednesday, 1),
    endsAt: _endOfMonth(year, 2),
    note: 'Zara, Bershka, Pull&Bear, Stradivarius ve Oysho aynı gün indirime giriyor. '
        'Online satış genelde mağazalardan bir gün önce başlıyor.',
  ),
  _c(
    id: 'sevgililer-$year',
    brandIds: <String>['genel'],
    title: 'Sevgililer Günü',
    startsAt: DateTime(year, 2, 14),
    note: 'Şubat başından itibaren kozmetik ve giyim markalarında hediye kampanyaları başlıyor.',
  ),
  _c(
    id: 'kadinlar-gunu-$year',
    brandIds: <String>['genel'],
    title: 'Dünya Kadınlar Günü',
    startsAt: DateTime(year, 3, 8),
    note: 'Kişisel bakım markalarının en yoğun kampanya günlerinden biri.',
  ),
  _c(
    id: 'anneler-gunu-$year',
    brandIds: <String>['genel'],
    title: 'Anneler Günü',
    // Kural: mayısın ikinci pazarı. 2026'da 10 Mayıs.
    startsAt: nthWeekdayOfMonth(year, 5, DateTime.sunday, 2),
  ),
  _c(
    id: 'inditex-yaz-$year',
    brandIds: kInditexBrandIds,
    title: 'Inditex Yaz Sezon Sonu İndirimi',
    // Kural: haziranın son çarşambası. 2026'da 24 Haziran — habere birebir uyuyor.
    startsAt: lastWeekdayOfMonth(year, 6, DateTime.wednesday),
    endsAt: DateTime(year, 8, 31),
    note: 'Yılın en büyük indirimi. Online satış genelde mağazalardan bir gün önce başlıyor.',
  ),
  _c(
    id: '11-11-$year',
    brandIds: <String>['genel'],
    title: '11.11 İndirim Günü',
    startsAt: DateTime(year, 11, 11),
  ),
  _c(
    id: 'black-friday-$year',
    brandIds: <String>['genel'],
    title: 'Black Friday (Kara Cuma)',
    // Kural: kasımın dördüncü cuması. 2026'da 27 Kasım.
    startsAt: nthWeekdayOfMonth(year, 11, DateTime.friday, 4),
    endsAt: nthWeekdayOfMonth(year, 11, DateTime.friday, 4).add(const Duration(days: 3)),
    note: 'Cuma başlar, Cyber Monday ile pazartesi biter. Birçok marka haftanın başında erken indirim yapıyor.',
  ),
  _c(
    id: 'yilbasi-$year',
    brandIds: <String>['genel'],
    title: 'Yılbaşı İndirimleri',
    startsAt: DateTime(year, 12, 26),
    endsAt: DateTime(year, 12, 31),
  ),
];

/// [now] ile [monthsAhead] ay sonrası arasındaki, henüz bitmemiş kampanyalar.
///
/// Yıl sınırını aşacak şekilde birden fazla yılı kapsar; başlangıç tarihine
/// göre sıralı döner.
List<Campaign> upcomingComputedCampaigns({
  required DateTime now,
  int monthsAhead = 18,
}) {
  final DateTime horizon = DateTime(now.year, now.month + monthsAhead, now.day);
  final List<Campaign> all = <Campaign>[
    for (int y = now.year; y <= horizon.year; y++) ...computedCampaignsForYear(y),
  ];
  final List<Campaign> result = all
      .where((Campaign c) => !c.isOver(now) && !c.startsAt.isAfter(horizon))
      .toList();
  result.sort((Campaign a, Campaign b) => a.startsAt.compareTo(b.startsAt));
  return result;
}
