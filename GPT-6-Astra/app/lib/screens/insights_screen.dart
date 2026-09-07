import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/design.dart';

class InsightsScreen extends StatelessWidget {
  final AppState state;
  const InsightsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final counts = <String, int>{};
      final months = <String, int>{};
      for (final event in state.shoppingHistory) {
        final id = event['ingredient_id']?.toString();
        if (id == null || id.isEmpty) continue;
        final count = (event['count'] as num?)?.toInt() ?? 1;
        counts.update(id, (n) => n + count, ifAbsent: () => count);
        final at = DateTime.tryParse(event['added_at']?.toString() ?? '');
        if (at != null) {
          final key = '${at.year}-${at.month.toString().padLeft(2, '0')}';
          months.update(key, (n) => n + count, ifAbsent: () => count);
        }
      }
      final ranked = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final monthEntries = months.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final recent = monthEntries.length > 12
          ? monthEntries.sublist(monthEntries.length - 12)
          : monthEntries;
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      return PaperScaffold(
        appBar: AppBar(
          title: mono(tr(state, 'SHOPPING NOTES', 'EINKAUFSNOTIZEN')),
          backgroundColor: Palette.paper,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                PageHeader(
                  title: tr(
                    state,
                    'what fills your basket.',
                    'was deinen Korb füllt.',
                  ),
                  subtitle: tr(
                    state,
                    'Small patterns from your everyday table.',
                    'Kleine Muster rund um deinen Esstisch.',
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Palette.sage.withValues(alpha: .55),
                    border: Border.all(color: Palette.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            mono(
                              tr(
                                state,
                                'YOUR VARIETY SCORE',
                                'DEINE ZUTATENVIELFALT',
                              ),
                            ),
                            const SizedBox(height: 10),
                            display(
                              '${counts.length}',
                              size: 66,
                              italic: false,
                            ),
                            Text(
                              tr(
                                state,
                                'different ingredients explored',
                                'verschiedene Zutaten entdeckt',
                              ),
                              style: const TextStyle(
                                color: Palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            mono(
                              tr(state, 'LITTLE ADDITIONS', 'KLEINE EINKÄUFE'),
                            ),
                            const SizedBox(height: 10),
                            display('$total', size: 66, italic: false),
                            Text(
                              tr(
                                state,
                                'ingredients added over time',
                                'Zutaten insgesamt hinzugefügt',
                              ),
                              style: const TextStyle(
                                color: Palette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (ranked.isEmpty) ...[
                  EmptyState(
                    title: tr(
                      state,
                      'your story starts here.',
                      'deine Geschichte beginnt.',
                    ),
                    message: tr(
                      state,
                      'Add recipes to your shopping list and your kitchen’s favourite ingredients will appear here.',
                      'Füge Rezepte zur Einkaufsliste hinzu. Hier erscheinen dann die Lieblingszutaten deiner Küche.',
                    ),
                    icon: Icons.bar_chart,
                  ),
                ] else ...[
                  SectionLabel(
                    tr(
                      state,
                      'THE FAMILIAR FAVOURITES',
                      'DIE VERTRAUTEN LIEBLINGE',
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...ranked
                      .take(10)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _ingredientName(entry.key),
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  mono(
                                    tr(
                                      state,
                                      '${entry.value} ${entry.value == 1 ? 'addition' : 'additions'}',
                                      '${entry.value} × hinzugefügt',
                                    ),
                                    size: 10,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: entry.value / ranked.first.value,
                                  child: Container(
                                    height: 7,
                                    color: Palette.coral.withValues(alpha: .7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  SectionLabel(
                    tr(state, 'THROUGH THE SEASONS', 'DURCH DIE JAHRESZEITEN'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      state,
                      'Ingredient additions by month · most recent 12 months with activity',
                      'Hinzugefügte Zutaten pro Monat · letzte 12 aktive Monate',
                    ),
                    style: const TextStyle(fontSize: 12, color: Palette.muted),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 205,
                    child: Semantics(
                      label: recent
                          .map((e) => '${_monthLabel(e.key)}: ${e.value}')
                          .join(', '),
                      child: CustomPaint(
                        size: const Size(double.infinity, 205),
                        painter: _MonthBars(recent, state.profile.lang),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...recent.reversed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Expanded(child: Text(_monthLabel(entry.key))),
                          mono('${entry.value}', size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                hand(
                  tr(
                    state,
                    'a pantry is a portrait of a life.',
                    'eine Vorratskammer erzählt vom Leben.',
                  ),
                  color: Palette.coral,
                ),
                const SizedBox(height: 10),
                Text(
                  tr(
                    state,
                    'These notes live only on this device and travel with your backup.',
                    'Diese Notizen bleiben auf deinem Gerät und sind in deinem Backup enthalten.',
                  ),
                  style: const TextStyle(
                    color: Palette.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  String _ingredientName(String id) {
    for (final ingredient in state.repo.ingredients) {
      if (ingredient.id == id) {
        return localized(ingredient.name, state.profile.lang);
      }
    }
    for (final event in state.shoppingHistory) {
      if (event['ingredient_id'] == id && event['custom_name'] is String) {
        return event['custom_name'] as String;
      }
    }
    return id.replaceFirst('custom:', '').replaceAll('-', ' ');
  }

  String _monthLabel(String key) {
    final names = state.profile.lang == 'de'
        ? [
            'Januar',
            'Februar',
            'März',
            'April',
            'Mai',
            'Juni',
            'Juli',
            'August',
            'September',
            'Oktober',
            'November',
            'Dezember',
          ]
        : [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    final parts = key.split('-');
    return '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
  }
}

class _MonthBars extends CustomPainter {
  final List<MapEntry<String, int>> months;
  final String lang;
  _MonthBars(this.months, this.lang);
  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;
    final maximum = months.map((e) => e.value).reduce(math.max);
    final plotHeight = size.height - 36;
    final step = size.width / months.length;
    for (var guide = 0; guide <= 3; guide++) {
      final y = plotHeight * guide / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Palette.line
          ..strokeWidth = 1,
      );
    }
    for (var i = 0; i < months.length; i++) {
      final height = maximum == 0
          ? 0.0
          : months[i].value / maximum * (plotHeight - 15);
      final width = math.min(38.0, step * .55);
      final center = step * i + step / 2;
      canvas.drawRect(
        Rect.fromLTWH(center - width / 2, plotHeight - height, width, height),
        Paint()
          ..color = i == months.length - 1
              ? Palette.coral
              : const Color(0xFF9EAD94),
      );
      final p = TextPainter(
        text: TextSpan(
          text: months[i].key.substring(5),
          style: const TextStyle(
            fontSize: 10,
            color: Palette.muted,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset(center - p.width / 2, plotHeight + 12));
      final count = TextPainter(
        text: TextSpan(
          text: '${months[i].value}',
          style: const TextStyle(fontSize: 10, color: Palette.ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      count.paint(
        canvas,
        Offset(center - count.width / 2, plotHeight - height - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthBars oldDelegate) =>
      oldDelegate.months != months || oldDelegate.lang != lang;
}
