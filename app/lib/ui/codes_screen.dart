import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/brand.dart';
import '../models/discount_code.dart';
import 'code_tile.dart';

class CodesScreen extends StatelessWidget {
  const CodesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<DiscountCode> codes = state.codes;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => state.refresh(force: true),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(title: const Text('Fırsatlar')),
            if (codes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('🏷️', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 14),
                        Text(
                          'Şu an doğrulanmış fırsat yok',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Burada yalnızca son 30 gün içinde geçerliliği '
                          'görülen fırsatlar listelenir. Eskiyenler '
                          'kendiliğinden gizlenir.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Kodlu fırsatta koda dokununca panoya kopyalanır.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: codes.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int i) => CodeTile(
                    code: codes[i],
                    now: state.now,
                    isBroken:
                        state.settings.brokenCodeIds.contains(codes[i].id),
                    onMarkBroken: (bool v) =>
                        state.setCodeBroken(codes[i].id, v),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String categoryLabel(BrandCategory c) => switch (c) {
      BrandCategory.kisiselBakim => 'Kişisel Bakım',
      BrandCategory.giyim => 'Giyim',
      BrandCategory.genel => 'Genel',
    };
