import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/data/app_settings.dart';
import 'package:indirim_takvimi/data/app_state.dart';
import 'package:indirim_takvimi/data/computed_calendar.dart';
import 'package:indirim_takvimi/data/merge.dart';
import 'package:indirim_takvimi/models/brand.dart';
import 'package:indirim_takvimi/models/campaign.dart';
import 'package:indirim_takvimi/models/discount_code.dart';
import 'package:indirim_takvimi/theme.dart';
import 'package:indirim_takvimi/ui/campaign_card.dart';
import 'package:indirim_takvimi/ui/code_tile.dart';
import 'package:indirim_takvimi/ui/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Toplayicinin urettigi **gercek** dosya. Bu testin amaci, boru hatti ile
/// uygulama arasindaki sozlesmeyi dogrulamak: collector'un yazdigi JSON
/// uygulamada gercekten ayrisiyor ve ciziliyor mu?
File get generatedData => File('../data/campaigns.json');

Future<AppState> makeState() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(settings: await AppSettings.load());
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr_TR');
  });

  group('boru hatti sözleşmesi', () {
    test('üretilen dosya var ve okunabiliyor', () {
      expect(generatedData.existsSync(), isTrue,
          reason: 'collector çalıştırılmamış: cd collector && npm start');
    });

    test('üretilen JSON uygulamada ayrışıyor', () {
      final RemoteData data =
          RemoteData.parse(generatedData.readAsStringSync());
      expect(data.generatedAt, isNotNull);
      expect(data.codes, isNotEmpty,
          reason: 'toplayıcı en az bir fırsat üretmeli');
    });

    test('her fırsatın markası uygulamada tanınıyor', () {
      final RemoteData data =
          RemoteData.parse(generatedData.readAsStringSync());
      for (final DiscountCode c in data.codes) {
        expect(brandById(c.brandId), isNotNull,
            reason: 'toplayıcı bilinmeyen marka kimliği üretti: ${c.brandId}');
      }
    });

    test('üretilen fırsatlar bugün gösterilebilir durumda', () {
      final RemoteData data =
          RemoteData.parse(generatedData.readAsStringSync());
      final List<DiscountCode> shown =
          visibleCodes(codes: data.codes, now: DateTime.now());
      expect(shown, isNotEmpty,
          reason: 'lastSeenAt alanı yanlış üretiliyor olabilir');
    });

    test('kod dizesi uydurulmamış', () {
      final RemoteData data =
          RemoteData.parse(generatedData.readAsStringSync());
      // Kaynak kod dizelerini yayınlamıyor; hiçbiri uydurulmamalı.
      expect(data.codes.every((DiscountCode c) => !c.hasCode), isTrue);
    });
  });

  group('ağsız çalışma', () {
    testWidgets('uzak veri hiç yokken takvim yine de dolu', (WidgetTester t) async {
      final AppState s = await makeState();
      s.campaigns = mergeCampaigns(
        computed: upcomingComputedCampaigns(now: DateTime.now()),
        remote: <Campaign>[],
        now: DateTime.now(),
      );
      s.loading = false;
      s.offline = true;

      await t.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(state: s),
      ));
      await t.pump();

      expect(find.byType(CampaignCard), findsWidgets);
      expect(find.textContaining('Canlı kampanyalara şu an ulaşılamıyor'),
          findsOneWidget);
    });

    testWidgets('tahmini kampanyalar rozetle işaretleniyor',
        (WidgetTester t) async {
      final AppState s = await makeState();
      s.campaigns = upcomingComputedCampaigns(now: DateTime.now());
      s.loading = false;

      await t.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(state: s),
      ));
      await t.pump();

      expect(find.text('Tahmini'), findsWidgets);
    });
  });

  group('gerçek veri arayüzde çiziliyor', () {
    testWidgets('toplayıcıdan gelen fırsat kartı hatasız çiziliyor',
        (WidgetTester t) async {
      final RemoteData data =
          RemoteData.parse(generatedData.readAsStringSync());
      final DiscountCode first =
          visibleCodes(codes: data.codes, now: DateTime.now()).first;

      await t.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: CodeTile(
            code: first,
            now: DateTime.now(),
            isBroken: false,
            onMarkBroken: (bool _) {},
          ),
        ),
      ));
      await t.pump();

      expect(find.text(first.title), findsOneWidget);
    });
  });
}
