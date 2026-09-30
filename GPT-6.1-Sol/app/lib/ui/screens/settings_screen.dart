import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'backup_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  Widget link(BuildContext context, String key, IconData icon, Widget screen) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: KitchenColors.teal, size: 23),
        title: Text(t(context, key), style: mono(12, color: KitchenColors.ink)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => screen),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    return PaperScaffold(
      appBar: KitchenAppBar(title: t(context, 'settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
        children: [
          Text(t(context, 'settingsTitle'), style: serif(34, italic: true)),
          const SizedBox(height: 12),
          Text(t(context, 'settingsSubtitle'), style: mono(11)),
          const SizedBox(height: 28),
          NoteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'hello', {'name': profile.name}),
                  style: hand(31),
                ),
                const SizedBox(height: 10),
                Text(
                  textFor(
                    context,
                    state.repository.ontology.label('diets', profile.diet),
                  ),
                  style: mono(12, color: KitchenColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  '${t(context, 'minutes', {'count': profile.maxTimeMinutes})} · ${t(context, 'kcal', {'count': profile.calorieTarget})} ±${profile.calorieTolerance}',
                  style: mono(10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          link(context, 'profile', Icons.tune, const ProfileScreen()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.translate,
              color: KitchenColors.teal,
              size: 23,
            ),
            title: Text(
              t(context, 'language'),
              style: mono(12, color: KitchenColors.ink),
            ),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'de', label: Text('DE')),
              ],
              selected: {profile.lang},
              onSelectionChanged: (selection) {
                final draft = profile.copy()..lang = selection.first;
                state.updateProfile(draft);
              },
            ),
          ),
          const SizedBox(height: 20),
          SectionHeading(title: t(context, 'adaptationPreferences')),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              t(context, 'showVariantTags'),
              style: mono(12, color: KitchenColors.ink),
            ),
            subtitle: Text(t(context, 'showVariantTagsBody'), style: mono(10)),
            value: profile.showVariantTags,
            onChanged: (value) =>
                state.updateProfile(profile.copy()..showVariantTags = value),
          ),
          const SizedBox(height: 15),
          Text(
            t(context, 'reduceMotion'),
            style: mono(12, color: KitchenColors.ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in <bool?>[null, true, false])
                ChoiceChip(
                  label: Text(
                    t(
                      context,
                      value == null
                          ? 'system'
                          : value
                          ? 'on'
                          : 'off',
                    ),
                  ),
                  selected: profile.reduceMotion == value,
                  onSelected: (_) =>
                      state.updateProfile(profile.copy()..reduceMotion = value),
                ),
            ],
          ),
          const SizedBox(height: 15),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              t(context, 'visualAlert'),
              style: mono(12, color: KitchenColors.ink),
            ),
            subtitle: Text(t(context, 'visualAlertBody'), style: mono(10)),
            value: profile.visualAlertEnabled,
            onChanged: (value) =>
                state.updateProfile(profile.copy()..visualAlertEnabled = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              t(context, 'quickTap'),
              style: mono(12, color: KitchenColors.ink),
            ),
            subtitle: Text(t(context, 'quickTapBody'), style: mono(10)),
            value: profile.quickNextTapEnabled,
            onChanged: (value) => state.updateProfile(
              profile.copy()..quickNextTapEnabled = value,
            ),
          ),
          const SizedBox(height: 26),
          SectionHeading(title: t(context, 'yourData')),
          link(
            context,
            'insights',
            Icons.bar_chart_outlined,
            const InsightsScreen(),
          ),
          link(context, 'history', Icons.history, const HistoryScreen()),
          link(
            context,
            'backup',
            Icons.inventory_2_outlined,
            const BackupScreen(),
          ),
          link(
            context,
            'contentRequests',
            Icons.edit_note_outlined,
            const WishesScreen(),
          ),
          const SizedBox(height: 20),
          SectionHeading(title: t(context, 'help')),
          link(context, 'help', Icons.help_outline, const HelpScreen()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.menu_book_outlined,
              color: KitchenColors.teal,
            ),
            title: Text(
              t(context, 'about'),
              style: mono(12, color: KitchenColors.ink),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  t(context, 'brand'),
                  style: serif(30, italic: true),
                ),
                content: Text(t(context, 'aboutBody'), style: mono(12)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t(context, 'close')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text(t(context, 'tagline'), style: hand(23))),
        ],
      ),
    );
  }
}

class WishesScreen extends StatelessWidget {
  const WishesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final requests = state.contentRequests.toList()..sort();
    return PaperScaffold(
      appBar: KitchenAppBar(title: t(context, 'contentRequests')),
      body: Column(
        children: [
          PageHeading(
            title: t(context, 'contentRequests'),
            subtitle: t(context, 'wishesBody'),
          ),
          Expanded(
            child: requests.isEmpty
                ? EmptyPaper(
                    title: t(context, 'emptyWishes'),
                    body: '',
                    icon: Icons.edit_note_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    cacheExtent: 100,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) {
                      if (index >= requests.length) return null;
                      final query = requests[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(query, style: hand(27)),
                        trailing: IconButton(
                          tooltip: t(context, 'remove'),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            state.contentRequests.remove(query);
                            state.changed();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
