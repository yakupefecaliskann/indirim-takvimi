import '../models/campaign.dart';

/// Bildirimlerin düşeceği saat (yerel saat).
const int kNotificationHour = 10;

/// Kaç gün kala hatırlatılacağı. 0 = kampanyanın başladığı gün.
const List<int> kReminderTiers = <int>[30, 14, 7, 3, 1, 0];

/// Android'in bekleyen alarm sayısını zorlamamak için üst sınır.
const int kMaxScheduledNotifications = 64;

/// Planlanmış tek bir bildirim. Saf veri — platform bağımlılığı yok.
class NotificationPlan {
  const NotificationPlan({
    required this.id,
    required this.campaignId,
    required this.scheduledFor,
    required this.daysBefore,
    required this.title,
    required this.body,
  });

  final int id;
  final String campaignId;
  final DateTime scheduledFor;
  final int daysBefore;
  final String title;
  final String body;
}

/// Kampanya listesinden bildirim planı üretir.
///
/// Saf fonksiyon: test edilebilir olsun diye platform çağrısı içermez.
/// [scheduler.dart] bu planı alıp işletim sistemine kurar.
List<NotificationPlan> planNotifications({
  required List<Campaign> campaigns,
  required DateTime now,
  List<int> tiers = kReminderTiers,
  int maxCount = kMaxScheduledNotifications,
}) {
  final List<NotificationPlan> plans = <NotificationPlan>[];

  for (final Campaign c in campaigns) {
    final DateTime start = dateOnly(c.startsAt);
    for (final int tier in tiers) {
      final DateTime fireDay = start.subtract(Duration(days: tier));
      final DateTime fireAt = DateTime(
        fireDay.year,
        fireDay.month,
        fireDay.day,
        kNotificationHour,
      );
      // Geçmiş kademeyi kurmanın anlamı yok; bazı cihazlarda anında patlar.
      if (!fireAt.isAfter(now)) continue;
      plans.add(NotificationPlan(
        id: notificationIdFor(c.id, tier),
        campaignId: c.id,
        scheduledFor: fireAt,
        daysBefore: tier,
        title: c.title,
        body: notificationBody(c, tier),
      ));
    }
  }

  plans.sort((NotificationPlan a, NotificationPlan b) {
    final int byDate = a.scheduledFor.compareTo(b.scheduledFor);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  // Sınırı aşarsa en uzaktakiler düşer; onlar zaten sonraki
  // yeniden planlamada tekrar kurulacak.
  return plans.length <= maxCount ? plans : plans.sublist(0, maxCount);
}

String notificationBody(Campaign c, int daysBefore) {
  // Tahmini bir tarihi kesinmiş gibi bildirmek, uygulamanın güvenilirliğini
  // kaybettiği yer olurdu. Metin bunu her zaman belli eder.
  final String hedge =
      c.confidence == CampaignConfidence.predicted ? ' (tahmini tarih)' : '';
  if (daysBefore == 0) {
    return 'Bugün başlıyor$hedge';
  }
  return '$daysBefore gün kaldı$hedge';
}

/// Kimlik, uygulama her açıldığında aynı olmalı; aksi hâlde yeniden
/// planlamada aynı bildirim iki kez kurulur. Bu yüzden `String.hashCode`
/// yerine sürümler arası kararlı olan FNV-1a kullanılıyor.
int notificationIdFor(String campaignId, int daysBefore) =>
    _fnv1a('$campaignId#$daysBefore');

int _fnv1a(String s) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < s.length; i++) {
    hash ^= s.codeUnitAt(i) & 0xff;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
