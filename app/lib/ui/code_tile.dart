import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/brand.dart';
import '../models/discount_code.dart';
import 'countdown_format.dart';

/// Tek bir fırsat satırı.
///
/// Kodlu fırsatta kopyalanabilir kod kutusu, kodsuz kampanyada başlık
/// gösterilir. İşaretlemeler yalnızca cihazda saklanır.
class CodeTile extends StatelessWidget {
  const CodeTile({
    super.key,
    required this.code,
    required this.now,
    required this.isBroken,
    required this.onMarkBroken,
  });

  final DiscountCode code;
  final DateTime now;
  final bool isBroken;
  final ValueChanged<bool> onMarkBroken;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String brandName = brandById(code.brandId)?.name ?? code.brandId;

    return Opacity(
      opacity: isBroken ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    brandName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  if (code.requiresCode && !code.hasCode)
                    _Chip(
                      label: 'Kod gerekli',
                      icon: Icons.vpn_key_rounded,
                      scheme: scheme,
                    ),
                  const Spacer(),
                  Text(
                    lastSeenLabel(code.lastSeenAt, now),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (code.hasCode)
                _CodeBox(
                  code: code.code!,
                  isBroken: isBroken,
                  onCopy: () => _copy(context, code.code!),
                )
              else
                Text(
                  code.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        decoration: isBroken
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                ),
              if (code.hasCode && code.title.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(code.title, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (code.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  code.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
              if (code.expiresAt != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Son gün: ${kLongDate.format(code.expiresAt!)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              _ActionRow(
                sourceUrl: code.sourceUrl,
                isBroken: isBroken,
                onMarkBroken: onMarkBroken,
                onCopyLink: (String url) =>
                    _copy(context, url, message: 'Bağlantı kopyalandı'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text, {String? message}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? '$text kopyalandı')),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.sourceUrl,
    required this.isBroken,
    required this.onMarkBroken,
    required this.onCopyLink,
  });

  final String? sourceUrl;
  final bool isBroken;
  final ValueChanged<bool> onMarkBroken;
  final ValueChanged<String> onCopyLink;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        if (sourceUrl != null)
          TextButton.icon(
            onPressed: () => onCopyLink(sourceUrl!),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Bağlantı'),
            style:
                TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Yaradı',
          onPressed: () => onMarkBroken(false),
          icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
          color: isBroken ? scheme.onSurfaceVariant : scheme.primary,
        ),
        IconButton(
          tooltip: 'Yaramadı',
          onPressed: () => onMarkBroken(true),
          icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
          color: isBroken ? scheme.error : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.code,
    required this.isBroken,
    required this.onCopy,
  });

  final String code;
  final bool isBroken;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: scheme.onPrimaryContainer,
                  decoration: isBroken
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            Icon(Icons.copy_rounded, size: 18, color: scheme.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.scheme,
  });

  final String label;
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: scheme.onTertiaryContainer),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
