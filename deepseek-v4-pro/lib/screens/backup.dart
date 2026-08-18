import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../logic/backup_service.dart';
import '../state/app_state.dart';

/// File-based backup/restore: JSON + GZip export to the share sheet,
/// optional AES-256-GCM password encryption, import with auto-detection.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('buTitle'))),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              context.t('buExport'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              context.t('buExportSub'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _passwordNote(context),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _export(context),
              icon: const Icon(Icons.ios_share, size: 16),
              label: Text(context.t('buExport')),
            ),
            const SizedBox(height: 28),
            const DashedOrnament(),
            const SizedBox(height: 28),
            Text(
              context.t('buImport'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              context.t('buImportSub'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _import(context),
              icon: const Icon(Icons.file_open_outlined, size: 16),
              label: Text(context.t('buImport')),
            ),
            const SizedBox(height: 16),
            Text(
              'morphcook-backup.json · morphcook-backup.json.gz',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: MC.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.t('buPasswordSub'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final store = context.read<AppStore>();
    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MC.paper,
        title: Text(
          context.t('buPassword'),
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 20,
            color: MC.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('buPasswordSub'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: context.t('buPassword'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(context.t('skip')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, passwordController.text),
            child: Text(context.t('confirm')),
          ),
        ],
      ),
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final payload = store.buildBackupPayload();
      final json = BackupService.encodeBackupJson(payload);
      final jsonBytes = BackupService.encodeJson(json, password: password.isEmpty ? null : password);
      final gzBytes = BackupService.encodeGz(json);

      final dir = await getTemporaryDirectory();
      final jsonFile = File('${dir.path}/${BackupService.jsonFileName}');
      final gzFile = File('${dir.path}/${BackupService.gzFileName}');
      await jsonFile.writeAsBytes(jsonBytes);
      await gzFile.writeAsBytes(gzBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(jsonFile.path), XFile(gzFile.path)],
          text: 'MorphCook backup',
        ),
      );

      if (!context.mounted) return;
      final doneLabel = context.t('buDone');
      final enc = password.isNotEmpty
          ? ' · ${context.t('buEncryptedJson')}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$doneLabel$enc')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = Uint8List.fromList(result.files.first.bytes ?? const []);
    if (!context.mounted) return;

    setState(() => _busy = true);
    try {
      var decoded = await _decodeWithPasswordPrompt(context, bytes);
      if (decoded == null || !context.mounted) return;
      final parsed = BackupService.parse(decoded);
      final mode = await _askMode(context);
      if (mode == null || !context.mounted) return;
      final store = context.read<AppStore>();
      if (mode == 'merge') {
        await store.applyBackupMerge(parsed);
      } else {
        await store.applyBackupReplace(parsed);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('buImported'))),
      );
    } on DecryptionException catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message(context.lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _decodeWithPasswordPrompt(
      BuildContext context, Uint8List bytes) async {
    final format = BackupService.detect(bytes);
    if (format != BackupFormat.encrypted) {
      try {
        return BackupService.decode(bytes);
      } on DecryptionException catch (e) {
        if (!context.mounted) return null;
        _showError(context, e.message(context.lang));
        return null;
      }
    }
    // Encrypted: prompt for the password.
    while (true) {
      if (!context.mounted) return null;
      final password = await _askPassword(context);
      if (password == null) return null; // cancelled
      try {
        return BackupService.decode(bytes, password: password);
      } on DecryptionException catch (e) {
        if (!context.mounted) return null;
        if (e.reason == 'wrongPassword') {
          _showError(context, e.message(context.lang));
          continue; // ask again
        }
        _showError(context, e.message(context.lang));
        return null;
      }
    }
  }

  Future<String?> _askPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MC.paper,
        title: Text(context.t('buPasswordPrompt'),
            style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: context.t('buPassword')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.t('confirm')),
          ),
        ],
      ),
    );
  }

  Future<String?> _askMode(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MC.paper,
        title: Text(context.t('buImport'),
            style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('buMerge'),
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono', fontSize: 13)),
              onTap: () => Navigator.pop(dialogContext, 'merge'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('buReplace'),
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono', fontSize: 13)),
              onTap: () => Navigator.pop(dialogContext, 'replace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MC.coralDeep,
      ),
    );
  }
}
