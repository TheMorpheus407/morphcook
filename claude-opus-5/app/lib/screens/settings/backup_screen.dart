import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup_crypto.dart';
import '../../data/backup_service.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../faq/faq_screen.dart';

/// Export writes both files to a temp directory and hands them to the OS share
/// sheet. Import accepts a pasted file body, which keeps the app free of a
/// file-picker plugin and of any platform-specific storage permission.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _paste = TextEditingController();

  ImportMode _mode = ImportMode.merge;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final state = context.read<AppState>();
    final s = S(state.lang);
    setState(() {
      _busy = true;
      _status = s.backupExporting;
    });

    try {
      final password = _password.text.trim();
      final bundle = state.exportBackup(
        password: password.isEmpty ? null : password,
      );
      final dir = await getTemporaryDirectory();

      final jsonFile = File('${dir.path}/${ExportBundle.jsonFilename}');
      final gzipFile = File('${dir.path}/${ExportBundle.gzipFilename}');
      await jsonFile.writeAsBytes(bundle.jsonBytes, flush: true);
      await gzipFile.writeAsBytes(bundle.gzipBytes, flush: true);

      await Share.shareXFiles([
        XFile(jsonFile.path),
        XFile(gzipFile.path),
      ], subject: 'MorphCook backup');

      if (!mounted) return;
      setState(() {
        _status = s.backupExported(
          ExportBundle.jsonFilename,
          ExportBundle.gzipFilename,
          (bundle.compressionRatio * 100).round(),
        );
      });
    } on Object catch (err) {
      if (!mounted) return;
      setState(() => _status = '${s.somethingWentWrong} $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final state = context.read<AppState>();
    final s = S(state.lang);
    final text = _paste.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    try {
      final bytes = _decodeInput(text);
      BackupDocument document;
      try {
        document = state.readBackup(bytes);
      } on DecryptionException catch (err) {
        if (err.reason != DecryptionFailure.passwordRequired) rethrow;
        final password = await _askPassword(s);
        if (password == null) {
          setState(() => _busy = false);
          return;
        }
        document = state.readEncryptedBackup(bytes, password);
      }

      final outcome = await state.applyImportedBackup(document, _mode);
      if (!mounted) return;
      setState(() {
        _paste.clear();
        _status = s.backupImported(
          outcome.addedSaved,
          outcome.addedHistory,
          outcome.addedPlanSlots,
        );
      });
    } on DecryptionException catch (err) {
      if (!mounted) return;
      setState(() => _status = err.message(s.lang));
    } on BackupFormatException catch (err) {
      if (!mounted) return;
      setState(() => _status = '${s.somethingWentWrong} ${err.detail}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Accepts raw JSON or a base64 blob, which is how an encrypted or gzipped
  /// file survives a copy-paste round trip.
  static List<int> _decodeInput(String text) {
    if (text.startsWith('{')) return utf8.encode(text);
    try {
      return base64Decode(text.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      return utf8.encode(text);
    }
  }

  Future<String?> _askPassword(S s) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.backupPasswordPrompt),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: s.backupPasswordField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(s.done),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsData.toLowerCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SectionHeader(s.settingsExport),
          const SizedBox(height: 10),
          Text(
            s.settingsExportNote,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: s.settingsBackupPassword),
          ),
          const SizedBox(height: 8),
          Text(
            s.settingsBackupPasswordNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FaqLink(anchor: 'backup-password', label: s.helpLinkLabel),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.ios_share, size: 17),
              label: Text(s.settingsExport),
            ),
          ),
          if (_password.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              s.backupEncrypted,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: 34),
          SectionHeader(s.settingsImport),
          const SizedBox(height: 10),
          Text(
            s.backupPasteInstead,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Eyebrow(s.backupImportMode),
          const SizedBox(height: 10),
          Row(
            children: [
              InkChip(
                label: s.backupMerge,
                dense: true,
                selected: _mode == ImportMode.merge,
                tooltip: s.backupMergeNote,
                onTap: () => setState(() => _mode = ImportMode.merge),
              ),
              const SizedBox(width: 8),
              InkChip(
                label: s.backupReplace,
                dense: true,
                tone: colors.accent,
                selected: _mode == ImportMode.replace,
                tooltip: s.backupReplaceNote,
                onTap: () => setState(() => _mode = ImportMode.replace),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _mode == ImportMode.merge ? s.backupMergeNote : s.backupReplaceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _paste,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(hintText: s.backupPasteHint),
            style: MorphType.numeric(colors.inkSoft, size: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.download_outlined, size: 17),
              label: Text(s.settingsImport),
            ),
          ),
          const SizedBox(height: 12),
          FaqLink(anchor: 'import-error', label: s.helpLinkLabel),

          if (_status != null) ...[
            const SizedBox(height: 24),
            DashedRule(color: colors.edge),
            const SizedBox(height: 14),
            Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
