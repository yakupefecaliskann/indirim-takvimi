import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/data/merge.dart';
import 'package:indirim_takvimi/models/campaign.dart';
import 'package:indirim_takvimi/models/discount_code.dart';

Campaign c(String id, DateTime start,
        {DateTime? end,
        CampaignConfidence conf = CampaignConfidence.predicted,
        List<String>? brands}) =>
    Campaign(
      id: id,
      brandIds: brands ?? <String>['zara'],
      title: id,
      startsAt: start,
      endsAt: end ?? start,
      confidence: conf,
      source: CampaignSource.computed,
    );

void main() {
  final DateTime now = DateTime(2026, 8, 28);

  group('RemoteData.parse — bozuk veriye dayanıklılık', () {
    test('geçersiz JSON istisna fırlatmaz, boş döner', () {
      expect(RemoteData.parse('bu json değil').campaigns, isEmpty);
      expect(RemoteData.parse('').codes, isEmpty);
      expect(RemoteData.parse('[1,2,3]').campaigns, isEmpty);
      expect(RemoteData.parse('null').campaigns, isEmpty);
    });

    test('bozuk kayıt atlanır, sağlam kayıt korunur', () {
      const String json = '''
      {"campaigns":[
        {"id":"iyi","brands":["zara"],"title":"İyi Kayıt","startsAt":"2026-12-01"},
        {"id":"tarihsiz","brands":["zara"],"title":"Tarih Yok"},
        {"id":"marka-yok","brands":[],"title":"Marka Yok","startsAt":"2026-12-01"},
        "bu bir metin",
        {"başlıksız":true}
      ]}''';
      final RemoteData d = RemoteData.parse(json);
      expect(d.campaigns.length, 1);
      expect(d.campaigns.single.id, 'iyi');
      expect(d.campaigns.single.title, 'İyi Kayıt');
    });

    test('confidence ve source alanları okunur, bilinmeyen değer tahmine düşer', () {
      const String json = '''
      {"campaigns":[
        {"id":"a","brands":["zara"],"title":"A","startsAt":"2026-12-01",
         "confidence":"announced","source":"news"},
        {"id":"b","brands":["zara"],"title":"B","startsAt":"2026-12-01",
         "confidence":"uydurma","source":"uydurma"}
      ]}''';
      final RemoteData d = RemoteData.parse(json);
      expect(d.campaigns[0].confidence, CampaignConfidence.announced);
      expect(d.campaigns[0].source, CampaignSource.news);
      expect(d.campaigns[1].confidence, CampaignConfidence.predicted);
      expect(d.campaigns[1].source, CampaignSource.computed);
    });

    test('kodlu ve kodsuz firsatlar okunur, bos kayit atlanir', () {
      const String json = '''
      {"codes":[
        {"id":"k1","brand":"gratis","code":"HOSGELDIN20","title":"Ilk siparise %20",
         "lastSeenAt":"2026-08-27"},
        {"id":"k2","brand":"gratis","title":"2 al 1 ode","lastSeenAt":"2026-08-27"},
        {"id":"k3","brand":"gratis"}
      ]}''';
      final RemoteData d = RemoteData.parse(json);
      expect(d.codes.length, 2);
      expect(d.codes[0].code, 'HOSGELDIN20');
      expect(d.codes[0].hasCode, isTrue);
      expect(d.codes[1].hasCode, isFalse);
      expect(d.codes[1].title, '2 al 1 ode');
    });
  });

  group('mergeCampaigns', () {
    test('uzak kayıt aynı kimlikli hesaplanan kaydı ezer', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[c('inditex-kis-2027', DateTime(2027, 1, 6))],
        remote: <Campaign>[
          c('inditex-kis-2027', DateTime(2027, 1, 9),
              conf: CampaignConfidence.announced)
        ],
        now: now,
      );
      expect(merged.length, 1);
      expect(merged.single.startsAt, DateTime(2027, 1, 9));
      expect(merged.single.confidence, CampaignConfidence.announced);
    });

    test('uzak kayıt bitiş tarihi vermezse hesaplanan bitiş korunur', () {
      // Haber kaynağı yalnızca başlangıcı bilir; bitişi silmemeli.
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[
          c('inditex-yaz-2027', DateTime(2027, 6, 30), end: DateTime(2027, 8, 31))
        ],
        remote: <Campaign>[
          Campaign(
            id: 'inditex-yaz-2027',
            brandIds: <String>['zara'],
            title: 'Inditex Yaz İndirimi',
            startsAt: DateTime(2027, 6, 23),
            confidence: CampaignConfidence.announced,
            source: CampaignSource.news,
          )
        ],
        now: now,
      );
      expect(merged.single.startsAt, DateTime(2027, 6, 23));
      expect(merged.single.endsAt, DateTime(2027, 8, 31));
      expect(merged.single.confidence, CampaignConfidence.announced);
    });

    test('hesaplanan kaydın markaları korunur', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[
          c('inditex-yaz-2027', DateTime(2027, 6, 30),
              end: DateTime(2027, 8, 31),
              brands: <String>['zara', 'bershka', 'oysho'])
        ],
        remote: <Campaign>[
          c('inditex-yaz-2027', DateTime(2027, 6, 23),
              end: DateTime(2027, 8, 31), brands: <String>['zara'])
        ],
        now: now,
      );
      expect(merged.single.brandIds.length, 3);
    });

    test('yalnızca uzakta olan kampanya eklenir', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[c('hesaplanan', DateTime(2026, 12, 1))],
        remote: <Campaign>[c('gratis-canli', DateTime(2026, 9, 1))],
        now: now,
      );
      expect(merged.map((Campaign x) => x.id),
          containsAll(<String>['hesaplanan', 'gratis-canli']));
    });

    test('uzak veri boşken hesaplanan takvim olduğu gibi kalır', () {
      final List<Campaign> computed = <Campaign>[
        c('a', DateTime(2026, 12, 1)),
        c('b', DateTime(2027, 1, 1)),
      ];
      final List<Campaign> merged =
          mergeCampaigns(computed: computed, remote: <Campaign>[], now: now);
      expect(merged.length, 2);
    });

    test('bitmiş kampanya elenir', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[],
        remote: <Campaign>[c('gecmis', DateTime(2026, 1, 1))],
        now: now,
      );
      expect(merged, isEmpty);
    });

    test('bilinmeyen markalı kampanya elenir', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[],
        remote: <Campaign>[
          c('bilinmeyen', DateTime(2026, 12, 1), brands: <String>['uydurma-marka'])
        ],
        now: now,
      );
      expect(merged, isEmpty);
    });

    test('başlangıç tarihine göre sıralı döner', () {
      final List<Campaign> merged = mergeCampaigns(
        computed: <Campaign>[
          c('gec', DateTime(2027, 3, 1)),
          c('erken', DateTime(2026, 9, 1)),
        ],
        remote: <Campaign>[c('orta', DateTime(2026, 11, 1))],
        now: now,
      );
      expect(merged.map((Campaign x) => x.id).toList(),
          <String>['erken', 'orta', 'gec']);
    });
  });

  group('visibleCodes', () {
    DiscountCode code(String id, {DateTime? seen, DateTime? expires}) =>
        DiscountCode(
          id: id,
          brandId: 'gratis',
          title: id,
          code: id.toUpperCase(),
          lastSeenAt: seen,
          expiresAt: expires,
        );

    test('taze kod gösterilir', () {
      final List<DiscountCode> v = visibleCodes(
        codes: <DiscountCode>[code('taze', seen: DateTime(2026, 8, 27))],
        now: now,
      );
      expect(v.length, 1);
    });

    test('30 günden eski kod gizlenir', () {
      final List<DiscountCode> v = visibleCodes(
        codes: <DiscountCode>[code('bayat', seen: DateTime(2026, 7, 1))],
        now: now,
      );
      expect(v, isEmpty);
    });

    test('son görülme bilgisi olmayan kod gizlenir', () {
      expect(visibleCodes(codes: <DiscountCode>[code('bilinmiyor')], now: now),
          isEmpty);
    });

    test('süresi geçmiş kod gizlenir', () {
      final List<DiscountCode> v = visibleCodes(
        codes: <DiscountCode>[
          code('gecmis', seen: DateTime(2026, 8, 27), expires: DateTime(2026, 8, 1))
        ],
        now: now,
      );
      expect(v, isEmpty);
    });

    test('işe yaramadı işaretlenen kod listenin sonuna düşer', () {
      final List<DiscountCode> v = visibleCodes(
        codes: <DiscountCode>[
          code('bozuk', seen: DateTime(2026, 8, 27)),
          code('calisan', seen: DateTime(2026, 8, 27)),
        ],
        now: now,
        brokenIds: <String>{'bozuk'},
      );
      expect(v.map((DiscountCode x) => x.id).toList(),
          <String>['calisan', 'bozuk']);
    });
  });
}
