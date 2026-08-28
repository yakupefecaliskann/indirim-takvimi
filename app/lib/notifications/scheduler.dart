import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/campaign.dart';
import 'notification_plan.dart';

/// Yerel bildirimleri işletim sistemine kuran katman.
///
/// Bildirimler **yerel** olduğu için uygulama hiç açılmasa, telefon çevrimdışı
/// olsa, sunucu tamamen kapansa bile düşmeye devam eder. Planı üreten saf
/// mantık [notification_plan.dart] içinde ve ayrıca test ediliyor.
class NotificationScheduler {
  NotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const String _channelId = 'kampanya_hatirlatma';
  static const String _channelName = 'Kampanya Hatırlatmaları';
  static const String _channelDescription =
      'İndirim günleri yaklaştığında hatırlatır.';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Uygulama Türkiye'ye özel; cihaz saat dilimini okumak için ek bir paket
    // eklemek yerine sabit konum kullanılıyor.
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+ bildirim izni. Reddedilirse uygulama çalışmaya devam eder,
  /// yalnızca hatırlatma düşmez.
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  Future<bool> hasPermission() async =>
      await _android?.areNotificationsEnabled() ?? true;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Tüm bildirimleri baştan kurar.
  ///
  /// Önce hepsi iptal edilip yeniden kuruluyor: kampanya tarihi haberlerden
  /// güncellendiğinde eski bildirimin ortalıkta kalmaması için en güvenli yol
  /// bu. Kimlikler kararlı olduğu için mükerrer kayıt oluşmuyor.
  Future<int> rescheduleAll(List<Campaign> campaigns, {DateTime? now}) async {
    await init();
    final List<NotificationPlan> plans = planNotifications(
      campaigns: campaigns,
      now: now ?? DateTime.now(),
    );

    await _plugin.cancelAll();
    int scheduled = 0;
    for (final NotificationPlan p in plans) {
      try {
        await _plugin.zonedSchedule(
          id: p.id,
          title: p.title,
          body: p.body,
          scheduledDate: tz.TZDateTime.from(p.scheduledFor, tz.local),
          notificationDetails: _details,
          payload: p.campaignId,
          // Gün bazlı hatırlatmada saniye hassasiyeti gerekmiyor. Bu mod
          // sayesinde Android 12+'ta SCHEDULE_EXACT_ALARM izin ekranı hiç
          // çıkmıyor — kullanıcı için sıfır kurulum sürtünmesi.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      } catch (e) {
        // Tek bir bildirimin kurulamaması diğerlerini engellememeli.
        debugPrint('Bildirim kurulamadı (${p.campaignId}/${p.daysBefore}): $e');
      }
    }
    return scheduled;
  }

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  /// Ayarlar ekranındaki "bildirimleri dene" düğmesi için.
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      id: 999999,
      title: 'Bildirimler çalışıyor 💕',
      body: 'İndirim günü yaklaştığında burada göreceksin.',
      notificationDetails: _details,
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
