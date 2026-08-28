import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../models/campaign.dart';
import 'countdown_format.dart';

/// Listedeki tek bir kampanya kartı.
class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.now,
    required this.onTap,
  });

  final Campaign campaign;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int days = campaign.daysUntilStart(now);
    final bool active = campaign.isActiveOn(now);
    final bool soon = days >= 0 && days <= 7;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              _CountBadge(days: days, active: active),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      campaign.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateRangeLabel(campaign),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        ConfidenceBadge(confidence: campaign.confidence),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            brandListLabel(campaign.brandIds),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: soon || active
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String brandListLabel(List<String> ids) {
  final List<String> names = <String>[
    for (final String id in ids)
      if (brandById(id) case final Brand b) b.name,
  ];
  if (names.isEmpty) return '';
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2}';
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.days, required this.active});

  final int days;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool urgent = active || (days >= 0 && days <= 7);
    final Color bg = urgent ? scheme.primary : scheme.primaryContainer;
    final Color fg = urgent ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: active && days < 0
            ? Icon(Icons.local_fire_department_rounded, color: fg, size: 26)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '$days',
                    style: TextStyle(
                      color: fg,
                      fontSize: days > 99 ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'gün',
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: 11,
                        height: 1),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tahmini tarihi kesin tarihten görsel olarak ayıran rozet.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence});

  final CampaignConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (confidence) {
      CampaignConfidence.predicted => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.help_outline_rounded,
        ),
      CampaignConfidence.announced => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.verified_rounded,
        ),
      CampaignConfidence.live => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.bolt_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            confidenceLabel(confidence),
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
