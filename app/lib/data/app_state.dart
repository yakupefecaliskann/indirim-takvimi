import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/campaign.dart';
import '../models/discount_code.dart';
import '../notifications/scheduler.dart';
import 'app_settings.dart';
import 'computed_calendar.dart';
import 'merge.dart';
import 'remote_repository.dart';

/// Uygulamanın tek durum kaynağı.
///
/// Açılış sırası bilinçli: önce **hesaplanan takvim + önbellek** ile ekran
/// anında dolar, ağ isteği arkada çalışır. Böylece internet yokken ya da
/// yavaşken bile uygulama boş açılmaz.
class AppState extends ChangeNotifier {
  AppState({
    required this.settings,
    RemoteRepository? repository,
    NotificationScheduler? scheduler,
  })  : _repo = repository ?? RemoteRepository(),
        _scheduler = scheduler ?? NotificationScheduler();

  final AppSettings settings;
  final RemoteRepository _repo;
  final NotificationScheduler _scheduler;

  NotificationScheduler get scheduler => _scheduler;

  List<Campaign> campaigns = <Campaign>[];
  List<DiscountCode> codes = <DiscountCode>[];
  DateTime? dataGeneratedAt;
  bool loading = true;
  bool refreshing = false;

  /// Uzak veriye hiç ulaşılamadı; ekrandakiler hesaplanan takvimden geliyor.
  bool offline = false;

  DateTime get now => DateTime.now();

  Future<void> bootstrap() async {
    final RemoteData cached = await _repo.readCache();
    _apply(cached);
    loading = false;
    notifyListeners();

    await _scheduler.init();
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    final DateTime? last = settings.lastFetch;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < kMinFetchInterval) {
      await _rescheduleNotifications();
      return;
    }

    refreshing = true;
    notifyListeners();

    final RemoteData fresh = await _repo.refresh();
    offline = fresh.isEmpty;
    if (!fresh.isEmpty) {
      await settings.setLastFetch(DateTime.now());
    }
    _apply(fresh);
    refreshing = false;
    notifyListeners();

    await _rescheduleNotifications();
  }

  void _apply(RemoteData data) {
    final DateTime n = now;
    campaigns = mergeCampaigns(
      computed: upcomingComputedCampaigns(now: n),
      remote: data.campaigns,
      now: n,
    );
    codes = visibleCodes(
      codes: data.codes,
      now: n,
      brokenIds: settings.brokenCodeIds,
    );
    dataGeneratedAt = data.generatedAt;
  }

  /// Bildirimler her açılışta baştan kurulur; tarihi güncellenen kampanyanın
  /// eski hatırlatması böylece ortada kalmaz.
  Future<void> _rescheduleNotifications() async {
    final Set<String> muted = settings.mutedBrandIds;
    final List<Campaign> wanted = campaigns
        .where((Campaign c) => !c.brandIds.every(muted.contains))
        .toList();
    await _scheduler.rescheduleAll(wanted, now: now);
  }

  Future<void> setCodeBroken(String id, bool broken) async {
    await settings.setCodeBroken(id, broken);
    codes = visibleCodes(
      codes: codes,
      now: now,
      brokenIds: settings.brokenCodeIds,
    );
    notifyListeners();
  }

  Future<void> setBrandMuted(String id, bool muted) async {
    await settings.setBrandMuted(id, muted);
    notifyListeners();
    await _rescheduleNotifications();
  }

  List<Campaign> campaignsForBrand(String? brandId) {
    if (brandId == null) return campaigns;
    return campaigns
        .where((Campaign c) =>
            c.brandIds.contains(brandId) || c.brandIds.contains('genel'))
        .toList();
  }

  List<DiscountCode> codesForBrand(String? brandId) => brandId == null
      ? codes
      : codes.where((DiscountCode c) => c.brandId == brandId).toList();
}
