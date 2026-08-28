import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/campaign.dart';
import '../notifications/scheduler.dart';
import 'app_settings.dart';
import 'computed_calendar.dart';
import 'merge.dart';
import 'remote_repository.dart';

/// Uygulama hiç açılmasa bile veriyi tazeleyen arka plan görevi.
///
/// Hatırlatmalar zaten yereldir ve hesaplanan takvim sayesinde bu görev hiç
/// çalışmasa da düşer. Bu görev yalnızca **canlı verinin** ve haberlerden
/// gelen kesinleşmiş tarihlerin arada bir güncellenmesini sağlar.
const String kSyncTaskName = 'veri-senkronu';
const String kSyncUniqueName = 'gunluk-veri-senkronu';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await syncAndReschedule();
    } catch (e) {
      debugPrint('Arka plan senkronu başarısız: $e');
    }
    // Her durumda true: false döndürmek yeniden deneme fırtınası başlatır,
    // oysa bir sonraki periyodik çalıştırma zaten yeterli.
    return true;
  });
}

Future<void> syncAndReschedule() async {
  final AppSettings settings = await AppSettings.load();
  final RemoteData data = await RemoteRepository().refresh();
  if (!data.isEmpty) {
    await settings.setLastFetch(DateTime.now());
  }

  final DateTime now = DateTime.now();
  final List<Campaign> merged = mergeCampaigns(
    computed: upcomingComputedCampaigns(now: now),
    remote: data.campaigns,
    now: now,
  );
  final Set<String> muted = settings.mutedBrandIds;
  final List<Campaign> wanted = merged
      .where((Campaign c) => !c.brandIds.every(muted.contains))
      .toList();

  await NotificationScheduler().rescheduleAll(wanted, now: now);
}

Future<void> registerBackgroundSync() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      kSyncUniqueName,
      kSyncTaskName,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  } catch (e) {
    // Arka plan görevi kurulamazsa uygulama yine çalışır; veri uygulama
    // açıldığında tazelenir.
    debugPrint('Arka plan görevi kurulamadı: $e');
  }
}
