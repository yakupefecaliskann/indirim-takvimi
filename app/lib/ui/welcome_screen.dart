import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// İlk açılışta bir kez görünen kişisel karşılama.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer,
              scheme.surface,
              scheme.tertiaryContainer.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Spacer(flex: 3),
                Text('💕', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 24),
                Text(
                  'Merhaba $kHerName',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 20),
                Text(
                  kWelcomeMessage,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
                const Spacer(flex: 2),
                _InfoRow(
                  icon: Icons.calendar_month_rounded,
                  text: 'Sevdiğin markaların indirim günleri tek yerde',
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.notifications_active_rounded,
                  text: '30, 14, 7, 3 ve 1 gün kala hatırlatır',
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.local_offer_rounded,
                  text: 'Geçerli indirim kodlarını kopyalayabilirsin',
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(backgroundColor: kRose),
                    child: const Text('Başlayalım'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: kRose),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
