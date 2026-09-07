import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/user_manual.dart';
import '../theme.dart';
import 'feedback_screen.dart';

class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final de = lang == 'de';
    final morph = MorphTheme.of(context);
    final sections = userManualSections
        .where((section) => section.matches(_query, lang))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          de ? 'Bedienungsanleitung' : 'User manual',
          style: morph.text.display.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            key: const ValueKey('manual-feedback'),
            tooltip: 'Feedback',
            icon: const Icon(Icons.feedback_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
          ),
        ],
      ),
      body: PaperBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    de
                        ? 'Offline verfügbar. Tippe ein Thema an, um die Anleitung zu lesen.'
                        : 'Available offline. Tap a topic to read its instructions.',
                    style: TextStyle(color: morph.colors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('manual-search'),
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      labelText: de ? 'Anleitung durchsuchen' : 'Search manual',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Text(
                        de ? 'Keine passenden Themen.' : 'No matching topics.',
                        key: const ValueKey('manual-no-results'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return ExpansionTile(
                          key: PageStorageKey('manual-${section.id}-$lang'),
                          title: Text(section.title(lang)),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            20,
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SelectableText owns a Scrollable. Give it its
                            // own storage key so its scroll offset cannot
                            // collide with ExpansionTile's stored bool.
                            SelectableText(
                              section.body(lang),
                              key: PageStorageKey(
                                'manual-text-${section.id}-$lang',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
