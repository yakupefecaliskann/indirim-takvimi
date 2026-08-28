import 'package:intl/intl.dart';

import '../models/campaign.dart';

final DateFormat kLongDate = DateFormat('d MMMM y', 'tr_TR');
final DateFormat kShortDate = DateFormat('d MMM', 'tr_TR');

/// "30 gün kaldı" / "Yarın" / "Bugün başlıyor" / "5 gün sürüyor"
String countdownLabel(Campaign c, DateTime now) {
  final int days = c.daysUntilStart(now);
  if (days > 1) return '$days gün kaldı';
  if (days == 1) return 'Yarın başlıyor';
  if (days == 0) return 'Bugün başlıyor';
  if (c.isActiveOn(now)) {
    final DateTime? end = c.endsAt;
    if (end == null) return 'Şu an devam ediyor';
    final int left = dateOnly(end).difference(dateOnly(now)).inDays;
    if (left == 0) return 'Son gün!';
    return 'Devam ediyor · $left gün kaldı';
  }
  return 'Bitti';
}

String dateRangeLabel(Campaign c) {
  final DateTime? end = c.endsAt;
  if (end == null || dateOnly(end) == dateOnly(c.startsAt)) {
    return kLongDate.format(c.startsAt);
  }
  return '${kShortDate.format(c.startsAt)} – ${kLongDate.format(end)}';
}

String confidenceLabel(CampaignConfidence c) => switch (c) {
      CampaignConfidence.predicted => 'Tahmini',
      CampaignConfidence.announced => 'Açıklandı',
      CampaignConfidence.live => 'Şu an aktif',
    };

String lastSeenLabel(DateTime? lastSeen, DateTime now) {
  if (lastSeen == null) return 'Doğrulama bilgisi yok';
  final int days = dateOnly(now).difference(dateOnly(lastSeen)).inDays;
  if (days <= 0) return 'Bugün doğrulandı';
  if (days == 1) return 'Dün doğrulandı';
  return '$days gün önce doğrulandı';
}
