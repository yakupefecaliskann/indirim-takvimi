import 'package:flutter/material.dart';

import '../config.dart';
import '../data/app_state.dart';
import '../models/brand.dart';
import '../models/campaign.dart';
import 'campaign_card.dart';
import 'campaign_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BrandCategory? _category;

  List<Campaign> get _filtered {
    final List<Campaign> all = widget.state.campaigns;
    final BrandCategory? cat = _category;
    if (cat == null) return all;
    return all.where((Campaign c) {
      return c.brandIds.any((String id) {
        final Brand? b = brandById(id);
        return b != null &&
            (b.category == cat || b.category == BrandCategory.genel);
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppState s = widget.state;
    final DateTime now = s.now;
    final List<Campaign> list = _filtered;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => s.refresh(force: true),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(
              title: const Text('İndirim Takvimi'),
              actions: <Widget>[
                if (s.refreshing)
                  const Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Merhaba $kHerName 💕',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryChips(
                selected: _category,
                onChanged: (BrandCategory? c) => setState(() => _category = c),
              ),
            ),
            if (s.offline) const SliverToBoxAdapter(child: _OfflineNotice()),
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int i) => CampaignCard(
                    campaign: list[i],
                    now: now,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CampaignDetailScreen(
                          campaign: list[i],
                          state: s,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final BrandCategory? selected;
  final ValueChanged<BrandCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<(BrandCategory?, String)> items = <(BrandCategory?, String)>[
      (null, 'Tümü'),
      (BrandCategory.kisiselBakim, 'Kişisel Bakım'),
      (BrandCategory.giyim, 'Giyim'),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: <Widget>[
          for (final (BrandCategory?, String) item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: selected == item.$1,
                onSelected: (bool _) => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Canlı kampanyalara şu an ulaşılamıyor. Aşağıdaki takvim '
                'uygulamanın kendi hesabından geliyor ve çalışmaya devam ediyor.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('🛍️', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(
                'Bu seçimde yaklaşan kampanya yok',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      );
}
