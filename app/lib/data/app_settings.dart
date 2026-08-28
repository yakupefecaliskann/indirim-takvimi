import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda saklanan küçük durumlar.
///
/// Hiçbir veri dışarı gönderilmez; "işe yaramadı" işaretleri de dahil olmak
/// üzere her şey yalnızca telefonda kalır.
class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings(await SharedPreferences.getInstance());

  static const String _kWelcomeSeen = 'welcome_seen';
  static const String _kBrokenCodes = 'broken_codes';
  static const String _kLastFetch = 'last_fetch_ms';
  static const String _kPermissionAsked = 'permission_asked';
  static const String _kMutedBrands = 'muted_brands';

  bool get welcomeSeen => _prefs.getBool(_kWelcomeSeen) ?? false;
  Future<void> setWelcomeSeen() => _prefs.setBool(_kWelcomeSeen, true);

  bool get permissionAsked => _prefs.getBool(_kPermissionAsked) ?? false;
  Future<void> setPermissionAsked() => _prefs.setBool(_kPermissionAsked, true);

  Set<String> get brokenCodeIds =>
      (_prefs.getStringList(_kBrokenCodes) ?? <String>[]).toSet();

  Future<void> setCodeBroken(String id, bool broken) {
    final Set<String> ids = brokenCodeIds;
    broken ? ids.add(id) : ids.remove(id);
    return _prefs.setStringList(_kBrokenCodes, ids.toList());
  }

  /// Bildirim almak istemediği markalar.
  Set<String> get mutedBrandIds =>
      (_prefs.getStringList(_kMutedBrands) ?? <String>[]).toSet();

  Future<void> setBrandMuted(String id, bool muted) {
    final Set<String> ids = mutedBrandIds;
    muted ? ids.add(id) : ids.remove(id);
    return _prefs.setStringList(_kMutedBrands, ids.toList());
  }

  DateTime? get lastFetch {
    final int? ms = _prefs.getInt(_kLastFetch);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastFetch(DateTime t) =>
      _prefs.setInt(_kLastFetch, t.millisecondsSinceEpoch);
}
