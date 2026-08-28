import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/config.dart';
import 'package:indirim_takvimi/theme.dart';
import 'package:indirim_takvimi/ui/welcome_screen.dart';

void main() {
  testWidgets('karşılama ekranı ismi ve mesajı gösterir', (WidgetTester t) async {
    bool tapped = false;
    await t.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: WelcomeScreen(onContinue: () async => tapped = true),
    ));

    expect(find.textContaining(kHerName), findsOneWidget);
    expect(find.text(kWelcomeMessage), findsOneWidget);
    expect(find.text('Başlayalım'), findsOneWidget);

    await t.tap(find.text('Başlayalım'));
    await t.pump();
    expect(tapped, isTrue);
  });

  testWidgets('karşılama ekranı bildirim kademelerini anlatır',
      (WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: WelcomeScreen(onContinue: () async {}),
    ));
    expect(find.textContaining('30, 14, 7, 3 ve 1 gün kala'), findsOneWidget);
    // Kod dizeleri toplanmiyor; karsilama ekrani kod vaadi vermemeli.
    expect(find.textContaining('indirim kodlarını'), findsNothing);
  });
}
