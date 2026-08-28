import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/app_settings.dart';
import 'data/app_state.dart';
import 'data/background_sync.dart';
import 'theme.dart';
import 'ui/codes_screen.dart';
import 'ui/home_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final AppSettings settings = await AppSettings.load();
  final AppState state = AppState(settings: settings);
  unawaitedBootstrap(state);
  await registerBackgroundSync();
  runApp(IndirimTakvimiApp(state: state));
}

void unawaitedBootstrap(AppState state) {
  // Açılış ekranı beklemesin: veri arkada yüklenir.
  state.bootstrap();
}

class IndirimTakvimiApp extends StatelessWidget {
  const IndirimTakvimiApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'İndirim Takvimi',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RootPage(state: state),
      );
}

class RootPage extends StatefulWidget {
  const RootPage({super.key, required this.state});

  final AppState state;

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late bool _showWelcome = !widget.state.settings.welcomeSeen;

  Future<void> _finishWelcome() async {
    await widget.state.settings.setWelcomeSeen();
    if (!widget.state.settings.permissionAsked) {
      await widget.state.settings.setPermissionAsked();
      await widget.state.scheduler.requestPermission();
    }
    if (mounted) setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return WelcomeScreen(onContinue: _finishWelcome);
    }
    return AppShell(state: widget.state);
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulamaya her dönüşte veri tazelenir (kMinFetchInterval sınırıyla).
    if (state == AppLifecycleState.resumed) {
      widget.state.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.state,
        builder: (BuildContext context, Widget? _) {
          final List<Widget> pages = <Widget>[
            HomeScreen(state: widget.state),
            CodesScreen(state: widget.state),
            SettingsScreen(state: widget.state),
          ];
          return Scaffold(
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (int i) => setState(() => _index = i),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Takvim',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_offer_outlined),
                  selectedIcon: Icon(Icons.local_offer_rounded),
                  label: 'Fırsatlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Ayarlar',
                ),
              ],
            ),
          );
        },
      );
}
