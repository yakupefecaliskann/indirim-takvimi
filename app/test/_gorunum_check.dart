import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/data/computed_calendar.dart';
import 'package:indirim_takvimi/data/merge.dart';
import 'package:indirim_takvimi/models/brand.dart';
import 'package:indirim_takvimi/models/campaign.dart';
import 'package:indirim_takvimi/models/discount_code.dart';

void main() {
  test('bugun ekranda ne var', () {
    final DateTime now = DateTime.now();
    final RemoteData d = RemoteData.parse(
        File('../data/campaigns.json').readAsStringSync());
    final List<Campaign> list = mergeCampaigns(
        computed: upcomingComputedCampaigns(now: now),
        remote: d.campaigns,
        now: now);
    stdout.writeln('### TAKVIM SEKMESI (${list.length} kampanya)');
    for (final Campaign c in list) {
      final String brands = c.brandIds
          .map((String i) => brandById(i)?.name)
          .whereType<String>()
          .join(', ');
      stdout.writeln('  ${c.daysUntilStart(now).toString().padLeft(4)} gun · '
          '${c.startsAt.toIso8601String().substring(0, 10)} · '
          '${c.title}  [$brands]');
    }
    final List<DiscountCode> codes =
        visibleCodes(codes: d.codes, now: now);
    stdout.writeln('\n### FIRSATLAR SEKMESI (${codes.length} firsat)');
    final Map<String, int> per = <String, int>{};
    for (final DiscountCode c in codes) {
      per[c.brandId] = (per[c.brandId] ?? 0) + 1;
    }
    for (final Brand b in kBrands) {
      final int n = per[b.id] ?? 0;
      final bool takvimde =
          list.any((Campaign c) => c.brandIds.contains(b.id));
      stdout.writeln('  ${b.name.padRight(14)} takvimde:'
          '${takvimde ? "EVET" : "hayir"}  firsat:$n');
    }
    stdout.writeln('\n  ornek: ${jsonEncode(codes.first.title)}');
  });
}
