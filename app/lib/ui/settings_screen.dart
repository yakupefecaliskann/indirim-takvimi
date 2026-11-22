import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/brand.dart';
import 'codes_screen.dart';
import 'countdown_format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  /// Yalnızca ilk açılış için: uygulama bu oturumda bildirimleri yeniden
  /// kurana kadar işletim sisteminde kayıtlı olan sayıyı gösterir.
  ///
  /// Bu ekran IndexedStack içinde olduğu için [initState] uygulama açılır
  /// açılmaz — bildirimler kurulmadan önce — çalışıyor. Bu yüzden asıl kaynak
  /// [AppState.scheduledCount]; burası yalnızca yedek.
  Future<void> _loadPending() async {
    try {
      final int n = await widget.state.scheduler.pendingCount();
      if (mounted) setState(() => _pending = n);
    } catch (_) {
      // Sayaç okunamazsa ekran yine çalışır.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState s = widget.state;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Set<String> muted = s.settings.mutedBrandIds;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar.large(title: const Text('Ayarlar')),
          SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _SectionTitle('Bildirimler'),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Kurulu hatırlatma'),
                subtitle: Text(
                  switch (s.scheduledCount ?? _pending) {
                    null => 'Kontrol ediliyor…',
                    0 => 'Hatırlatma kurulmadı · bildirim izni kapalı olabilir',
                    final int n =>
                      '$n hatırlatma kurulu · 30, 14, 7, 3, 1 gün kala ve '
                          'başladığı gün',
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded),
                title: const Text('Deneme bildirimi gönder'),
                subtitle: const Text('Bildirimlerin çalıştığını doğrula'),
                onTap: () async {
                  await s.scheduler.showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bildirim gönderildi')),
                    );
                  }
                },
              ),
              const Divider(height: 32),
              _SectionTitle('Takip edilen markalar'),
              for (final Brand b in kBrands)
                SwitchListTile(
                  title: Text(b.name),
                  subtitle: Text(categoryLabel(b.category)),
                  value: !muted.contains(b.id),
                  onChanged: (bool on) async {
                    await s.setBrandMuted(b.id, !on);
                    if (mounted) setState(() {});
                    await _loadPending();
                  },
                ),
              const Divider(height: 32),
              _SectionTitle('Veri'),
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Şimdi güncelle'),
                subtitle: Text(lastFetchLabel(s.settings.lastFetch, s.now)),
                onTap: () async {
                  await s.refresh(force: true);
                  await _loadPending();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.offline
                            ? 'Sunucuya ulaşılamadı, takvim çalışmaya devam ediyor'
                            : 'Güncellendi'),
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Text(
                  'Kampanya tarihleri iki kaynaktan geliyor: uygulamanın kendi '
                  'hesapladığı takvim (internet olmasa da çalışır) ve günde '
                  'birkaç kez otomatik toplanan canlı veriler. Tahmini tarihler '
                  'ayrı rozetle işaretlenir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}
