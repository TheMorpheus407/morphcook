import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../services/backup_io.dart';
import '../services/backup_service.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  final _io = const BackupIo();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    return Scaffold(
      appBar: AppBar(title: Text(Copy.text('backup', lang))),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            Text(
              lang == 'de'
                  ? 'dein buch, in deiner hand.'
                  : 'your book, in your hands.',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            Text(
              lang == 'de'
                  ? 'MorphCook hat kein Konto und keine Cloud. Exportiere deine lokale Kopie, wann immer du sie sichern oder auf ein anderes Gerät bringen möchtest.'
                  : 'MorphCook has no account and no cloud. Export your local copy whenever you want to keep it safe or move it to another device.',
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _password,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: Copy.text('password_optional', lang).toUpperCase(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang == 'de'
                  ? 'Mit Passwort wird die JSON-Datei per AES-256-GCM geschützt. Die kleinere GZip-Datei bleibt für Kompatibilität unverschlüsselt.'
                  : 'With a password, the JSON file is protected with AES-256-GCM. The smaller GZip file stays unencrypted for compatibility.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BrandColors.fadedInk),
            ),
            const SizedBox(height: 25),
            _FormatCard(
              title: 'morphcook-backup.json',
              note: lang == 'de'
                  ? 'menschenlesbar · mit Passwort verschlüsselt'
                  : 'human-readable · encrypted when password is set',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: 9),
            _FormatCard(
              title: 'morphcook-backup.json.gz',
              note: lang == 'de'
                  ? 'typisch 70–90 % kleiner · immer unverschlüsselt'
                  : 'typically 70–90% smaller · always unencrypted',
              icon: Icons.folder_zip_outlined,
            ),
            const SizedBox(height: 27),
            FilledButton.icon(
              onPressed: _busy ? null : () => _export(app, lang),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(Copy.text('export', lang).toUpperCase()),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _import(app, lang),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(Copy.text('import', lang).toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(AppController app, String lang) async {
    setState(() => _busy = true);
    try {
      final bundle = await app.createBackup(
        password: _password.text.isEmpty ? null : _password.text,
      );
      await _io.share(bundle);
      if (mounted) showPaperSnack(context, Copy.text('backup_ready', lang));
    } catch (error) {
      if (mounted) showPaperSnack(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(AppController app, String lang) async {
    final bytes = await _io.pick();
    if (bytes == null || !mounted) return;
    final merge = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Copy.text('import', lang)),
        content: Text(
          lang == 'de'
              ? 'Möchtest du die Sicherung mit den Daten auf diesem Gerät zusammenführen oder sie vollständig ersetzen? Der gebündelte Rezeptbestand bleibt unverändert.'
              : 'Merge this backup with data on this device, or replace local data completely? The bundled recipe corpus is never changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Copy.text('cancel', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Copy.text('replace', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(Copy.text('merge', lang)),
          ),
        ],
      ),
    );
    if (merge == null || !mounted) return;
    setState(() => _busy = true);
    var password = _password.text;
    try {
      try {
        await app.restoreBackup(
          bytes,
          password: password.isEmpty ? null : password,
          merge: merge,
        );
      } on DecryptionException catch (error) {
        if (error.reason != DecryptionFailure.wrongPassword || !mounted) {
          rethrow;
        }
        final prompted = await _promptPassword(lang, error.message(lang));
        if (prompted == null) return;
        password = prompted;
        await app.restoreBackup(bytes, password: password, merge: merge);
      }
      if (mounted) {
        showPaperSnack(context, Copy.text('restore_done', app.language));
      }
    } on DecryptionException catch (error) {
      if (mounted) showPaperSnack(context, error.message(lang));
    } catch (error) {
      if (mounted) showPaperSnack(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassword(String lang, String message) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Copy.text('password_optional', lang)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Copy.text('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(Copy.text('continue', lang)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.title,
    required this.note,
    required this.icon,
  });
  final String title;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F5EA),
      border: Border.all(color: BrandColors.ink),
    ),
    child: Row(
      children: [
        Icon(icon, color: BrandColors.coral),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(note),
            ],
          ),
        ),
      ],
    ),
  );
}
