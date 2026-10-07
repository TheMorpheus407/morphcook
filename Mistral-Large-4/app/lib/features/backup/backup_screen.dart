import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Typography;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../state/app_state.dart';
import '../../state/backup_service.dart';
import '../../widgets/controls.dart';
import '../../widgets/paper.dart';

/// Backup & restore. Export writes two files to the OS share sheet:
/// `morphcook-backup.json` (human-readable, AES-256-GCM encrypted when a
/// password is given) and `morphcook-backup.json.gz` (GZip, always
/// unencrypted). Import auto-detects encryption (magic bytes "ENC") and GZip,
/// prompts for a password when needed, and merges or replaces — never touches
/// the bundled corpus.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _service = BackupService();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload(AppState appState) => _service.buildPayload(
        profile: appState.profile.toJson(),
        saved: appState.savedRecipeIds,
        mealPlan: {
          for (final entry in appState.mealPlan.entries) entry.key: entry.value,
        },
        history: appState.history.map((h) => h.toJson()).toList(),
        contentRequests: appState.contentRequests,
        shopping: {
          for (final item in appState.shoppingItems) item.ingredientId: item.toJson(),
        },
        shoppingLog: {
          'entries': appState.shoppingLog.map((l) => l.toJson()).toList(),
        },
      );

  Future<void> _export(AppState appState, Strings s) async {
    setState(() => _busy = true);
    try {
      final password = _passwordController.text.trim();
      final bytes = await _service.exportBytes(
        _payload(appState),
        password: password.isEmpty ? null : password,
      );
      final dir = await getTemporaryDirectory();
      final jsonFile = File('${dir.path}/morphcook-backup.json');
      final gzFile = File('${dir.path}/morphcook-backup.json.gz');
      await jsonFile.writeAsBytes(bytes.json);
      await gzFile.writeAsBytes(bytes.gzip);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(jsonFile.path), XFile(gzFile.path)],
        text: 'morphcook backup',
      ));
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(AppState appState, Strings s) async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return; // cancelled
      final path = files.first.path;
      if (path == null) return;
      final Uint8List bytes = await File(path).readAsBytes();

      Map<String, dynamic> payload;
      try {
        payload = await _service.parseBackup(bytes);
      } on DecryptionException catch (e) {
        if (e.reason == 'password-required') {
          final password = await _promptPassword(s);
          if (password == null) return; // cancelled
          try {
            payload = await _service.parseBackup(bytes, password: password);
          } on DecryptionException catch (e2) {
            _toast(e2.reason == 'wrong-password' ? s.backupWrongPassword : s.backupCorrupted);
            return;
          }
        } else {
          _toast(s.backupCorrupted);
          return;
        }
      } on FormatException {
        _toast(s.backupInvalid);
        return;
      }

      final replace = await _chooseMergeOrReplace(s);
      if (replace == null) return; // cancelled
      await appState.restoreFromBackup(payload, replace: replace);
      if (mounted) _toast(s.backupImported);
    } catch (e) {
      if (mounted) _toast(s.backupInvalid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassword(Strings s) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.backupEnterPassword, style: Typography.display(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.backupEncryptedNotice, style: Typography.mono(10, color: Palette.inkFaint)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: Typography.hand(20),
              decoration: InputDecoration(
                hintText: s.backupPassword,
                hintStyle: Typography.hand(20, color: Palette.inkFaint),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.line, width: 1.4)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.4)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.commonCancel)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(s.commonSave)),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool?> _chooseMergeOrReplace(Strings s) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(s.backupImport, style: Typography.display(20)),
          content: Text(
            s.backupMergeNote,
            style: Typography.body(14, italic: true),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.backupMerge)),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.backupReplace)),
          ],
        ),
      );

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);

    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('← ${s.navSettings}', style: Typography.mono(10, letterSpacing: 1.4, color: Palette.teal)),
              ),
            ),
            Text(s.backupTitle, style: Typography.display(28)),
            const DashedRule(),

            // ── export ─────────────────────────────────────────────────────
            SectionLabel(s.backupExport),
            Text(s.backupPasswordOptional, style: Typography.body(14, italic: true)),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: Typography.hand(20),
              decoration: InputDecoration(
                hintText: s.backupPassword,
                helperText: s.backupPasswordHint,
                helperStyle: Typography.mono(9.5, color: Palette.inkFaint, letterSpacing: 0.4),
                hintStyle: Typography.hand(20, color: Palette.inkFaint),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.line, width: 1.4)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.4)),
              ),
            ),
            const SizedBox(height: 14),
            InkButton(
              s.backupExport.toUpperCase(),
              icon: Icons.save_alt_outlined,
              onTap: _busy ? null : () => _export(appState, s),
            ),
            const DashedRule(),

            // ── import ─────────────────────────────────────────────────────
            SectionLabel(s.backupImport),
            Text(
              'morphcook-backup.json · morphcook-backup.json.gz — ${s.backupEncryptedNotice.toLowerCase()}',
              style: Typography.body(14, italic: true),
            ),
            const SizedBox(height: 14),
            InkButton(
              s.backupImport.toUpperCase(),
              outlined: true,
              icon: Icons.file_open_outlined,
              onTap: _busy ? null : () => _import(appState, s),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}
