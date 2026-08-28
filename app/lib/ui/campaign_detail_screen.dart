import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../models/brand.dart';
import '../models/campaign.dart';
import '../models/discount_code.dart';
import 'campaign_card.dart';
import 'code_tile.dart';
import 'countdown_format.dart';

class CampaignDetailScreen extends StatelessWidget {
  const CampaignDetailScreen({
    super.key,
    required this.campaign,
    required this.state,
  });

  final Campaign campaign;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime now = state.now;
    final List<DiscountCode> related = state.codes
        .where((DiscountCode c) => campaign.brandIds.contains(c.brandId))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kampanya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Text(
            campaign.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              ConfidenceBadge(confidence: campaign.confidence),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  countdownLabel(campaign, now),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoTile(
            icon: Icons.event_rounded,
            label: 'Tarih',
            value: dateRangeLabel(campaign),
          ),
          _InfoTile(
            icon: Icons.storefront_rounded,
            label: 'Markalar',
            value: campaign.brandIds
                .map((String id) => brandById(id)?.name)
                .whereType<String>()
                .join(', '),
          ),
          if (campaign.confidence == CampaignConfidence.predicted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu tarih geçmiş yılların desenine göre tahmin edildi. '
                        'Marka resmi tarihi açıkladığında burası kendiliğinden '
                        'güncellenir.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (campaign.note != null) ...<Widget>[
            const SizedBox(height: 20),
            Text('Not', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              campaign.note!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ],
          if (campaign.sourceUrl != null) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _copyLink(context, campaign.sourceUrl!),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Kaynağı kopyala'),
            ),
          ],
          if (related.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            Text('Bu markaların fırsatları',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final DiscountCode c in related)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CodeTile(
                  code: c,
                  now: now,
                  isBroken: state.settings.brokenCodeIds.contains(c.id),
                  onMarkBroken: (bool v) => state.setCodeBroken(c.id, v),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _copyLink(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaynak bağlantısı kopyalandı')),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
