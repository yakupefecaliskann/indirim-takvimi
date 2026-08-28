import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/data/computed_calendar.dart';
import 'package:indirim_takvimi/models/brand.dart';
import 'package:indirim_takvimi/models/campaign.dart';

Campaign campaignWithId(List<Campaign> list, String id) =>
    list.firstWhere((Campaign c) => c.id == id);

void main() {
  group('tarih yardımcıları', () {
    test('ayın n. hafta günü', () {
      // Kasım 2026: 1'i pazar, cumalar 6/13/20/27
      expect(nthWeekdayOfMonth(2026, 11, DateTime.friday, 4), DateTime(2026, 11, 27));
      expect(nthWeekdayOfMonth(2026, 11, DateTime.friday, 1), DateTime(2026, 11, 6));
      // Ocak 2026: 1'i perşembe, çarşambalar 7/14/21/28
      expect(nthWeekdayOfMonth(2026, 1, DateTime.wednesday, 1), DateTime(2026, 1, 7));
      // Mayıs 2026: 1'i cuma, pazarlar 3/10/17/24/31
      expect(nthWeekdayOfMonth(2026, 5, DateTime.sunday, 2), DateTime(2026, 5, 10));
    });

    test('ayın son hafta günü', () {
      // Haziran 2026: 1'i pazartesi, çarşambalar 3/10/17/24
      expect(lastWeekdayOfMonth(2026, 6, DateTime.wednesday), DateTime(2026, 6, 24));
      expect(lastWeekdayOfMonth(2026, 11, DateTime.friday), DateTime(2026, 11, 27));
    });

    test('artık yıl şubatında son hafta günü doğru', () {
      // Şubat 2028 artık yıl: 29 gün, 1'i salı, salılar 1/8/15/22/29
      expect(lastWeekdayOfMonth(2028, 2, DateTime.tuesday), DateTime(2028, 2, 29));
    });
  });

  group('2026 doğrulanmış tarihler', () {
    late List<Campaign> y2026;
    setUp(() => y2026 = computedCampaignsForYear(2026));

    test('Inditex yaz indirimi 24 Haziran 2026 (habere uyuyor)', () {
      expect(campaignWithId(y2026, 'inditex-yaz-2026').startsAt,
          DateTime(2026, 6, 24));
    });

    test('Inditex kış indirimi 7 Ocak 2026', () {
      expect(campaignWithId(y2026, 'inditex-kis-2026').startsAt,
          DateTime(2026, 1, 7));
    });

    test('Black Friday 27 Kasım 2026', () {
      expect(campaignWithId(y2026, 'black-friday-2026').startsAt,
          DateTime(2026, 11, 27));
    });

    test('sabit tarihli günler', () {
      expect(campaignWithId(y2026, 'sevgililer-2026').startsAt, DateTime(2026, 2, 14));
      expect(campaignWithId(y2026, 'kadinlar-gunu-2026').startsAt, DateTime(2026, 3, 8));
      expect(campaignWithId(y2026, '11-11-2026').startsAt, DateTime(2026, 11, 11));
      expect(campaignWithId(y2026, 'anneler-gunu-2026').startsAt, DateTime(2026, 5, 10));
      expect(campaignWithId(y2026, 'yilbasi-2026').startsAt, DateTime(2026, 12, 26));
    });
  });

  group('kampanya nitelikleri', () {
    late List<Campaign> y2027;
    setUp(() => y2027 = computedCampaignsForYear(2027));

    test('hepsi tahmini olarak işaretlenir', () {
      expect(y2027.every((Campaign c) => c.confidence == CampaignConfidence.predicted),
          isTrue);
      expect(y2027.every((Campaign c) => c.source == CampaignSource.computed), isTrue);
    });

    test('Inditex kampanyaları beş markayı da kapsar', () {
      final Campaign yaz = campaignWithId(y2027, 'inditex-yaz-2027');
      expect(yaz.brandIds, containsAll(<String>['zara', 'bershka', 'pullandbear']));
      expect(yaz.brandIds.length, 5);
    });

    test('her kampanyanın markası bilinen bir marka', () {
      for (final Campaign c in y2027) {
        for (final String id in c.brandIds) {
          expect(brandById(id), isNotNull, reason: 'bilinmeyen marka: $id');
        }
      }
    });

    test('kimlikler yıl içinde benzersiz', () {
      final Set<String> ids = y2027.map((Campaign c) => c.id).toSet();
      expect(ids.length, y2027.length);
    });

    test('bitiş tarihi varsa başlangıçtan sonra', () {
      for (final Campaign c in y2027) {
        if (c.endsAt != null) {
          expect(c.endsAt!.isBefore(c.startsAt), isFalse, reason: c.id);
        }
      }
    });
  });

  group('upcomingComputedCampaigns', () {
    test('geçmiş kampanyaları elemez ama biteni eler', () {
      final DateTime now = DateTime(2026, 7, 1);
      final List<Campaign> list = upcomingComputedCampaigns(now: now, monthsAhead: 18);
      // 24 Haziran'da başlayan yaz indirimi ağustos sonuna kadar sürüyor: hâlâ görünür
      expect(list.any((Campaign c) => c.id == 'inditex-yaz-2026'), isTrue);
      // Şubat'ta biten sevgililer günü artık görünmemeli
      expect(list.any((Campaign c) => c.id == 'sevgililer-2026'), isFalse);
    });

    test('gelecek yılın kampanyalarını da üretir', () {
      final List<Campaign> list =
          upcomingComputedCampaigns(now: DateTime(2026, 12, 1), monthsAhead: 18);
      expect(list.any((Campaign c) => c.id == 'inditex-kis-2027'), isTrue);
      expect(list.any((Campaign c) => c.id == 'sevgililer-2027'), isTrue);
    });

    test('başlangıç tarihine göre sıralı', () {
      final List<Campaign> list =
          upcomingComputedCampaigns(now: DateTime(2026, 1, 1), monthsAhead: 24);
      for (int i = 1; i < list.length; i++) {
        expect(list[i].startsAt.isBefore(list[i - 1].startsAt), isFalse);
      }
    });

    test('pencere dışına taşan kampanya üretilmez', () {
      final List<Campaign> list =
          upcomingComputedCampaigns(now: DateTime(2026, 1, 1), monthsAhead: 6);
      expect(list.every((Campaign c) => c.startsAt.isBefore(DateTime(2026, 7, 2))),
          isTrue);
    });
  });
}
