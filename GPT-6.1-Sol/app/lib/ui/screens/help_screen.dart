import 'package:flutter/material.dart';
import '../../core/matching.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> openHelp(BuildContext context, [String? entry]) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => HelpScreen(initialEntry: entry)),
);

class HelpScreen extends StatefulWidget {
  final String? initialEntry;
  const HelpScreen({super.key, this.initialEntry});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String query = '';
  String category = 'all';
  late Set<String> expanded;
  @override
  void initState() {
    super.initState();
    expanded = {if (widget.initialEntry != null) widget.initialEntry!};
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final categories = [
      'all',
      'diet',
      'recipes',
      'shopping',
      'planning',
      'backup',
      'cooking',
      'help',
    ];
    final tokens = normalizeSearch(query).split(' ').where((t) => t.isNotEmpty);
    final entries = state.repository.faqs.where((entry) {
      final text = normalizeSearch(
        '${textFor(context, localized(entry['question']))} ${textFor(context, localized(entry['answer']))}',
      );
      return (category == 'all' || entry['category'] == category) &&
          tokens.every(text.contains);
    }).toList();
    if (widget.initialEntry != null && query.isEmpty && category == 'all') {
      entries.sort(
        (a, b) => a['id'] == widget.initialEntry
            ? -1
            : b['id'] == widget.initialEntry
            ? 1
            : 0,
      );
    }
    return PaperScaffold(
      appBar: KitchenAppBar(title: t(context, 'help')),
      body: Column(
        children: [
          PageHeading(title: t(context, 'helpTitle'), subtitle: ''),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: t(context, 'helpHint'),
              ),
            ),
          ),
          ChipStrip(
            values: categories,
            label: (value) =>
                t(context, value == 'all' ? 'all' : 'help_$value'),
            selected: (value) => category == value,
            onTap: (value) => setState(() => category = value),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyPaper(
                    title: t(context, 'helpEmpty'),
                    body: '',
                    icon: Icons.help_outline,
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    cacheExtent: 100,
                    addAutomaticKeepAlives: false,
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final id = entry['id'] as String;
                      final open = expanded.contains(id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashedRule(),
                          InkWell(
                            onTap: () => setState(
                              () =>
                                  open ? expanded.remove(id) : expanded.add(id),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      textFor(
                                        context,
                                        localized(entry['question']),
                                      ),
                                      style: serif(20, italic: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    open ? Icons.remove : Icons.add,
                                    size: 18,
                                    color: KitchenColors.teal,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          MotionSize(
                            alignment: Alignment.topLeft,
                            child: open
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: Text(
                                      textFor(
                                        context,
                                        localized(entry['answer']),
                                      ),
                                      style: mono(12, color: KitchenColors.ink),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
