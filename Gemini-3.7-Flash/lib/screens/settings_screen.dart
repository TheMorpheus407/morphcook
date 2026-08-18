import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';
import 'shopping_insights_screen.dart';
import 'faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  final TextEditingController _ingredientSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<AppState>(context, listen: false).profile;
    _nameController = TextEditingController(text: profile.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientSearchController.dispose();
    super.dispose();
  }

  void _showExportBackupDialog(BuildContext context, String lang) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VintageColors.paperCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: VintageColors.paperBorder),
        ),
        title: Text(
          lang == 'de' ? 'Datensicherung exportieren' : 'Export File Backup',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'de'
                    ? 'Erstellt morphcook-backup.json und morphcook-backup.json.gz mit deinen Profilen, gespeicherten Rezepten, Speiseplänen und Notizen.'
                    : 'Generates morphcook-backup.json and morphcook-backup.json.gz with your profile, saved recipes, meal plans, and notes.',
                style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.inkLight),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: lang == 'de' ? 'Optionales Passwort (AES-256-GCM)' : 'Optional Password (AES-256-GCM)',
                  labelStyle: GoogleFonts.ebGaramond(fontSize: 14),
                  hintText: lang == 'de' ? 'Freilassen für unverschlüsselt' : 'Leave empty for unencrypted',
                  hintStyle: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: VintageColors.paperBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'de' ? 'Abbrechen' : 'Cancel', style: GoogleFonts.jetBrainsMono(color: VintageColors.inkLight)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VintageColors.terracotta),
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              final backupData = appState.generateBackupData();
              final password = passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null;

              final result = BackupService.exportBackup(data: backupData, password: password);
              Navigator.pop(ctx);

              _showExportSuccessDialog(context, result, lang);
            },
            child: Text(lang == 'de' ? 'Exportieren' : 'Export', style: GoogleFonts.jetBrainsMono()),
          ),
        ],
      ),
    );
  }

  void _showExportSuccessDialog(BuildContext context, BackupFilesResult result, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VintageColors.paperCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: VintageColors.paperBorder),
        ),
        title: Text(
          lang == 'de' ? 'Backup erfolgreich erstellt' : 'Backup Created Successfully',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'de'
                  ? 'Deine Backup-Dateien stehen bereit:'
                  : 'Your backup files have been generated:',
              style: GoogleFonts.ebGaramond(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VintageColors.paperBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: VintageColors.paperBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${result.jsonFileName} (${result.jsonBytes.length} bytes)', style: GoogleFonts.jetBrainsMono(fontSize: 12)),
                  Text('• ${result.gzipFileName} (${result.gzipBytes.length} bytes, GZip compressed)', style: GoogleFonts.jetBrainsMono(fontSize: 12)),
                  if (result.isEncrypted) ...[
                    const SizedBox(height: 4),
                    Text('🔒 AES-256-GCM Encrypted', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: VintageColors.sage, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VintageColors.terracotta),
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'de' ? 'Fertig' : 'Done', style: GoogleFonts.jetBrainsMono()),
          ),
        ],
      ),
    );
  }

  void _showRestoreBackupDialog(BuildContext context, String lang) {
    final rawJsonController = TextEditingController();
    final passwordController = TextEditingController();
    bool replaceMode = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VintageColors.paperCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: VintageColors.paperBorder),
          ),
          title: Text(
            lang == 'de' ? 'Datensicherung wiederherstellen' : 'Restore Backup',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'de'
                      ? 'Füge den Backup-JSON-Text oder Hex-Code hier ein:'
                      : 'Paste your backup JSON or payload here:',
                  style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.inkLight),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rawJsonController,
                  maxLines: 4,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '{"schema_version": 1, ...}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: VintageColors.paperBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: lang == 'de' ? 'Passwort (falls verschlüsselt)' : 'Password (if encrypted)',
                    labelStyle: GoogleFonts.ebGaramond(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: VintageColors.paperBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      activeColor: VintageColors.terracotta,
                      value: replaceMode,
                      onChanged: (val) => setDialogState(() => replaceMode = val ?? false),
                    ),
                    Expanded(
                      child: Text(
                        lang == 'de' ? 'Bestehende Daten vollständig ersetzen (statt zusammenführen)' : 'Replace existing data (instead of merging)',
                        style: GoogleFonts.ebGaramond(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang == 'de' ? 'Abbrechen' : 'Cancel', style: GoogleFonts.jetBrainsMono(color: VintageColors.inkLight)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: VintageColors.terracotta),
              onPressed: () async {
                final text = rawJsonController.text.trim();
                if (text.isEmpty) return;

                final appState = Provider.of<AppState>(context, listen: false);
                final password = passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null;

                try {
                  final bytes = Uint8List.fromList(utf8.encode(text));
                  final restored = BackupService.restoreFromBytes(bytes: bytes, password: password);

                  await appState.restoreBackupData(restored, replace: replaceMode);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: VintageColors.paperCard,
                      content: Text(
                        lang == 'de' ? 'Backup erfolgreich eingespielt!' : 'Backup restored successfully!',
                        style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFFBA1A1A),
                      content: Text(
                        e.toString(),
                        style: GoogleFonts.jetBrainsMono(color: Colors.white),
                      ),
                    ),
                  );
                }
              },
              child: Text(lang == 'de' ? 'Wiederherstellen' : 'Restore', style: GoogleFonts.jetBrainsMono()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final profile = appState.profile;
    final lang = appState.lang;
    final ontology = appState.corpus.ontology;
    final ingredientDict = appState.corpus.ingredientDictionary;

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Einstellungen & Profil' : 'Settings & Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Profile Name & Language Section
          _buildSectionHeader(lang == 'de' ? 'PROFIL & SPRACHE' : 'PROFILE & LANGUAGE'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: lang == 'de' ? 'Dein Name' : 'Your Name',
                    labelStyle: GoogleFonts.ebGaramond(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: VintageColors.terracotta),
                      onPressed: () {
                        profile.name = _nameController.text.trim();
                        appState.saveProfile();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: VintageColors.paperCard,
                            content: Text(
                              lang == 'de' ? 'Name gespeichert' : 'Name updated',
                              style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang == 'de' ? 'Sprache / Language' : 'Language / Sprache', style: GoogleFonts.ebGaramond(fontSize: 16)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN')),
                        ButtonSegment(value: 'de', label: Text('DE')),
                      ],
                      selected: {profile.lang},
                      onSelectionChanged: (set) {
                        appState.setLanguage(set.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dietary Lifestyles & Avoidances
          _buildSectionHeader(lang == 'de' ? 'ERNÄHRUNGSFORMEN & FILTER' : 'DIET & RESTRICTIONS'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ontology != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ontology.compoundAvoidFlags.values.map((f) {
                      final isSelected = profile.avoidFlags.contains(f.id);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(f.label.get(lang)),
                        labelStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isSelected ? Colors.white : VintageColors.ink,
                        ),
                        selectedColor: VintageColors.terracotta,
                        backgroundColor: VintageColors.paperSurface,
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          if (val) {
                            profile.avoidFlags.add(f.id);
                          } else {
                            profile.avoidFlags.remove(f.id);
                          }
                          appState.saveProfile();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Specific ingredients typeahead
                Text(
                  lang == 'de' ? 'Spezifische Zutaten ausschließen' : 'Specific Ingredient Avoidance',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _ingredientSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: lang == 'de' ? 'Zutat suchen (z. B. Koriander)...' : 'Search ingredient to avoid (e.g. Cilantro)...',
                    hintStyle: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkMuted),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: VintageColors.paperBorder),
                    ),
                  ),
                ),
                if (ingredientDict != null && _ingredientSearchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: VintageColors.paperBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: VintageColors.paperBorder),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: ingredientDict
                          .search(_ingredientSearchController.text, lang)
                          .take(5)
                          .map((node) {
                        final isAvoided = profile.avoidIngredients.contains(node.id);
                        return ListTile(
                          dense: true,
                          title: Text(node.name.get(lang), style: GoogleFonts.ebGaramond(fontSize: 15)),
                          trailing: isAvoided
                              ? const Icon(Icons.check, color: VintageColors.terracotta, size: 18)
                              : const Icon(Icons.add, size: 18),
                          onTap: () {
                            if (isAvoided) {
                              profile.avoidIngredients.remove(node.id);
                            } else {
                              profile.avoidIngredients.add(node.id);
                            }
                            appState.saveProfile();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
                if (profile.avoidIngredients.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.avoidIngredients.map((id) {
                      final node = ingredientDict?.getNode(id);
                      final label = node != null ? node.name.get(lang) : id;
                      return Chip(
                        label: Text(label),
                        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 11),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          profile.avoidIngredients.remove(id);
                          appState.saveProfile();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Budget & Cooking Targets
          _buildSectionHeader(lang == 'de' ? 'KÜCHEN-LIMITS & AUFWAND' : 'TIME & ENERGY TARGETS'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang == 'de' ? 'Max. Zeit' : 'Max Time', style: GoogleFonts.ebGaramond(fontSize: 16)),
                    VintageBadge(label: '${profile.maxTimeMinutes} min'),
                  ],
                ),
                Slider(
                  value: profile.maxTimeMinutes.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 7,
                  activeColor: VintageColors.terracotta,
                  onChanged: (val) {
                    profile.maxTimeMinutes = val.round();
                    appState.saveProfile();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang == 'de' ? 'Kalorien-Ziel' : 'Calorie Target', style: GoogleFonts.ebGaramond(fontSize: 16)),
                    VintageBadge(label: '~${profile.calorieTarget} kcal'),
                  ],
                ),
                Slider(
                  value: profile.calorieTarget.toDouble(),
                  min: 300,
                  max: 900,
                  divisions: 12,
                  activeColor: VintageColors.mustard,
                  onChanged: (val) {
                    profile.calorieTarget = val.round();
                    appState.saveProfile();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Accessibility & App Settings
          _buildSectionHeader(lang == 'de' ? 'BARRIEREFREIHEIT & GESTEN' : 'ACCESSIBILITY & COOK GESTURES'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: VintageColors.sage,
                  title: Text(lang == 'de' ? 'Optisches Timer-Blinksignal' : 'Visual Flash Alert on Timer', style: GoogleFonts.ebGaramond(fontSize: 16)),
                  subtitle: Text(
                    lang == 'de' ? 'Farbblitz bei Timer-Ende (für Hörbeeinträchtigte)' : 'Screen color flash on timer finish (for deaf/hard of hearing)',
                    style: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkLight),
                  ),
                  value: profile.visualAlertEnabled,
                  onChanged: (val) {
                    profile.visualAlertEnabled = val;
                    appState.saveProfile();
                  },
                ),
                const Divider(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: VintageColors.sage,
                  title: Text(lang == 'de' ? 'Schnell-Tipp Weiter' : 'Quick-Tap Next Step', style: GoogleFonts.ebGaramond(fontSize: 16)),
                  subtitle: Text(
                    lang == 'de' ? 'Einfacher Tipp auf Schrittkarte springt zum nächsten Schritt' : 'Single tap on step content advances with haptic feedback',
                    style: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkLight),
                  ),
                  value: profile.quickNextTapEnabled,
                  onChanged: (val) {
                    profile.quickNextTapEnabled = val;
                    appState.saveProfile();
                  },
                ),
                const Divider(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: VintageColors.sage,
                  title: Text(lang == 'de' ? 'Reduzierte Bewegung' : 'Reduce Motion', style: GoogleFonts.ebGaramond(fontSize: 16)),
                  subtitle: Text(
                    lang == 'de' ? 'Dämpft Übergangsanimationen' : 'Disables flashes and soft transitions',
                    style: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkLight),
                  ),
                  value: profile.reduceMotion ?? false,
                  onChanged: (val) {
                    profile.reduceMotion = val;
                    appState.saveProfile();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Features Navigation
          _buildSectionHeader(lang == 'de' ? 'WISSEN & EINBLICKE' : 'INSIGHTS & KNOWLEDGE'),
          Container(
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.analytics_outlined, color: VintageColors.terracotta),
                  title: Text(lang == 'de' ? 'Einkaufs-Einblicke & Statistik' : 'Shopping Insights & Analytics', style: GoogleFonts.ebGaramond(fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShoppingInsightsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: VintageColors.paperBorder),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: VintageColors.sage),
                  title: Text(lang == 'de' ? 'Hilfe, FAQ & Handbuch' : 'FAQ & Knowledge Base', style: GoogleFonts.ebGaramond(fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Backup & Restore Section
          _buildSectionHeader(lang == 'de' ? 'DATEI-DATENSICHERUNG' : 'FILE BACKUP & RESTORE'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'de'
                      ? 'MorphCook ist 100% offline. Deine Daten verbleiben auf deinem Gerät. Exportiere oder importiere Backups jederzeit.'
                      : 'MorphCook is 100% offline. Your data stays on your device. Export or restore backups at any time.',
                  style: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkLight),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: VintageColors.terracotta)),
                        icon: const Icon(Icons.download, size: 18, color: VintageColors.terracotta),
                        label: Text(
                          lang == 'de' ? 'Backup Export' : 'Export File',
                          style: GoogleFonts.jetBrainsMono(color: VintageColors.terracotta, fontSize: 12),
                        ),
                        onPressed: () => _showExportBackupDialog(context, lang),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: VintageColors.inkLight)),
                        icon: const Icon(Icons.upload, size: 18, color: VintageColors.inkLight),
                        label: Text(
                          lang == 'de' ? 'Wiederherstellen' : 'Restore File',
                          style: GoogleFonts.jetBrainsMono(color: VintageColors.ink, fontSize: 12),
                        ),
                        onPressed: () => _showRestoreBackupDialog(context, lang),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Halal / Kosher Disclaimer Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VintageColors.paperSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: VintageColors.inkLight),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == 'de'
                        ? 'Hinweis: Wir gewährleisten halal-/koscher-kompatible Zutaten (Ausschluss von Schwein, Alkohol etc.). Offizielle Zertifizierung unterliegt den Einkaufsketten vor Ort.'
                        : 'Note: We surface halal/kosher compatible ingredients (excluding pork, alcohol, etc.). Official certification is a property of physical sourcing.',
                    style: GoogleFonts.ebGaramond(fontSize: 13, color: VintageColors.inkLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: VintageColors.inkLight,
        ),
      ),
    );
  }
}
