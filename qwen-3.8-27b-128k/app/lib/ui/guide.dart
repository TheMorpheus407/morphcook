/// Kitchen reference: searchable ingredient guide — name, aisle, unit,
/// seasonal months, treatment note, and the editorial guide line.
library;

import 'package:flutter/material.dart';


import '../core/theme.dart';
import 'morph.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _month(int n) =>
      ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec'][n - 1];

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final q = _q.trim().toLowerCase();
    final metas = m.c.ingredients.values
        .where((met) =>
            q.isEmpty ||
            met.name.s('en').toLowerCase().contains(q) ||
            met.name.s(m.lang).toLowerCase().contains(q) ||
            met.id.contains(q))
        .toList()
                                ..sort((a, b) => a.name.s(m.lang)
                    .toLowerCase()
                    .compareTo(b.name.s(m.lang).toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(m.t('ig.title'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.t('ig.sub'),
                      style: T.body.copyWith(fontSize: 13)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 16),
                        hintText: m.t('ig.search')),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: metas.isEmpty
                  ? Center(child: Text(m.t('ig.none'), style: T.body))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        for (final met in metas)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Palette.cardPaper,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Palette.ink
                                        .withValues(alpha: 0.09)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                            met.name.s(m.lang),
                                            style: const TextStyle(
                                                fontFamily:
                                                    'PlayfairDisplay',
                                                fontSize: 17,
                                                color: Palette.ink)),
                                      ),
                                      Text('${met.aisle} · ${met.unit}',
                                          style: T.mono.copyWith(
                                              fontSize: 10)),
                                    ],
                                  ),
                                  if (met.note.s(m.lang).isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(met.note.s(m.lang),
                                        style: T.body
                                            .copyWith(fontSize: 13)),
                                  ],
                                  if (met.seasonalMonths.isNotEmpty)
                                    Row(
                                      children: [
                                        for (final mo in met.seasonalMonths)
                                          if (mo >= 1 && mo <= 12) ...[
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  right: 3),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: Palette
                                                      .ink
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text(
                                                  _month(mo),
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontFamily:
                                                          'JetBrainsMono',
                                                      color:
                                                          Palette.inkSoft)),
                                            ),
                                          ],
                                      ],
                                    ),
                                  if ((m.c.guide[met.id]?[m.lang] ??
                                          m.c.guide[met.id]?['en'] ??
                                          '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                        m.c.guide[met.id]?[m.lang] ??
                                            m.c.guide[met.id]?['en'] ??
                                            '',
                                        style: const TextStyle(
                                            fontFamily: 'PlayfairDisplay',
                                            fontStyle: FontStyle.italic,
                                            fontSize: 13,
                                            color: Palette.inkSoft,
                                            height: 1.4)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
