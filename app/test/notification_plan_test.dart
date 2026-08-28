import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/models/campaign.dart';
import 'package:indirim_takvimi/notifications/notification_plan.dart';

Campaign camp(String id, DateTime start,
        {CampaignConfidence conf = CampaignConfidence.predicted,
        String title = 'Test Kampanyası'}) =>
    Campaign(
      id: id,
      brandIds: <String>['zara'],
      title: title,
      startsAt: start,
      endsAt: start,
      confidence: conf,
      source: CampaignSource.computed,
    );

void main() {
  final DateTime now = DateTime(2026, 8, 28, 9);

  test('kademeler 30/14/7/3/1/0 olarak planlanır', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[camp('a', DateTime(2026, 12, 1))],
      now: now,
    );
    expect(plans.map((NotificationPlan p) => p.daysBefore).toList(),
        <int>[30, 14, 7, 3, 1, 0]);
  });

  test('bildirim saati sabit ve tarih doğru hesaplanır', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[camp('a', DateTime(2026, 12, 1))],
      now: now,
    );
    final NotificationPlan otuz =
        plans.firstWhere((NotificationPlan p) => p.daysBefore == 30);
    expect(otuz.scheduledFor, DateTime(2026, 11, 1, kNotificationHour));
    final NotificationPlan basladi =
        plans.firstWhere((NotificationPlan p) => p.daysBefore == 0);
    expect(basladi.scheduledFor, DateTime(2026, 12, 1, kNotificationHour));
  });

  test('geçmişte kalan kademeler atlanır', () {
    // 10 gün sonra başlıyor: 30 ve 14 günlük kademeler geçmişte kaldı
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[camp('a', DateTime(2026, 9, 7))],
      now: now,
    );
    expect(plans.map((NotificationPlan p) => p.daysBefore).toList(),
        <int>[7, 3, 1, 0]);
  });

  test('aynı gün ama saati geçmiş kademe atlanır', () {
    final DateTime lateNow = DateTime(2026, 8, 28, 23);
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[camp('a', DateTime(2026, 8, 29))],
      now: lateNow,
    );
    // 1 gün kaldı bildirimi bugün saat 10'da olacaktı, geçti
    expect(plans.map((NotificationPlan p) => p.daysBefore).toList(), <int>[0]);
  });

  test('tamamen geçmiş kampanya hiç bildirim üretmez', () {
    expect(
      planNotifications(
          campaigns: <Campaign>[camp('a', DateTime(2026, 1, 1))], now: now),
      isEmpty,
    );
  });

  test('bildirim kimlikleri benzersiz', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[
        camp('a', DateTime(2026, 12, 1)),
        camp('b', DateTime(2027, 1, 1)),
        camp('c', DateTime(2027, 2, 1)),
      ],
      now: now,
    );
    final Set<int> ids = plans.map((NotificationPlan p) => p.id).toSet();
    expect(ids.length, plans.length);
  });

  test('bildirim kimlikleri çağrılar arasında kararlı', () {
    List<int> ids() => planNotifications(
          campaigns: <Campaign>[camp('inditex-yaz-2027', DateTime(2027, 6, 30))],
          now: now,
        ).map((NotificationPlan p) => p.id).toList();
    expect(ids(), ids());
  });

  test('kimlikler Android 32-bit sınırında', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[
        for (int i = 0; i < 40; i++)
          camp('kampanya-numara-$i', DateTime(2027, 1, 1).add(Duration(days: i))),
      ],
      now: now,
      maxCount: 500,
    );
    expect(plans.every((NotificationPlan p) => p.id >= 0 && p.id <= 0x7fffffff),
        isTrue);
  });

  test('maxCount uygulanır ve en yakın tarihler korunur', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[
        for (int i = 0; i < 30; i++)
          camp('k$i', DateTime(2027, 1, 1).add(Duration(days: i * 10))),
      ],
      now: now,
      maxCount: 12,
    );
    expect(plans.length, 12);
    for (int i = 1; i < plans.length; i++) {
      expect(plans[i].scheduledFor.isBefore(plans[i - 1].scheduledFor), isFalse);
    }
  });

  test('sonuç tarihe göre sıralı', () {
    final List<NotificationPlan> plans = planNotifications(
      campaigns: <Campaign>[
        camp('gec', DateTime(2027, 5, 1)),
        camp('erken', DateTime(2026, 10, 1)),
      ],
      now: now,
    );
    for (int i = 1; i < plans.length; i++) {
      expect(plans[i].scheduledFor.isBefore(plans[i - 1].scheduledFor), isFalse);
    }
  });

  group('bildirim metni', () {
    test('gün sayısını ve marka adını içerir', () {
      final NotificationPlan p = planNotifications(
        campaigns: <Campaign>[
          camp('a', DateTime(2026, 12, 1), title: 'Inditex Yaz İndirimi')
        ],
        now: now,
      ).firstWhere((NotificationPlan x) => x.daysBefore == 30);
      expect(p.title, contains('Inditex Yaz İndirimi'));
      expect(p.body, contains('30 gün kaldı'));
    });

    test('başladığı gün farklı metin kullanır', () {
      final NotificationPlan p = planNotifications(
        campaigns: <Campaign>[camp('a', DateTime(2026, 12, 1))],
        now: now,
      ).firstWhere((NotificationPlan x) => x.daysBefore == 0);
      expect(p.body, contains('başlıyor'));
      expect(p.body, isNot(contains('gün kaldı')));
    });

    test('tahmini tarihte metin bunu belli eder', () {
      final NotificationPlan tahmini = planNotifications(
        campaigns: <Campaign>[
          camp('a', DateTime(2026, 12, 1), conf: CampaignConfidence.predicted)
        ],
        now: now,
      ).first;
      expect(tahmini.body.toLowerCase(), contains('tahmin'));
    });

    test('kesinleşmiş tarihte tahmin uyarısı yok', () {
      final NotificationPlan kesin = planNotifications(
        campaigns: <Campaign>[
          camp('a', DateTime(2026, 12, 1), conf: CampaignConfidence.announced)
        ],
        now: now,
      ).first;
      expect(kesin.body.toLowerCase(), isNot(contains('tahmin')));
    });
  });
}
