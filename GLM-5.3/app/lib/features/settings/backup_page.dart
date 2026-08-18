import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_crypto.dart';
import '../../core/services/backup_service.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';

/// Backup & restore (SPEC): export json + gzip to the OS share sheet,
/// optional AES-256-GCM password on the json; import auto-detects
/// encrypted / gzipped / plain, validates schema, merge or replace.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final payload = BackupPayload(
        profile: state.profile,
        saved: state.saved.map((e) => e.recipeId).toList(),
        mealPlan: state.mealPlan.toJson(),
        history: state.history,
        contentRequests: state.contentRequests,
      );
      final password = _passwordController.text;
      final export = BackupService.buildExport(payload,
          password: password.isEmpty ? null : password);
      final dir = await getTemporaryDirectory();
      final paths = await writeExportFiles(dir, export);
      await Share.shareXFiles(
        paths.map((p) => XFile(p)).toList(),
        text: 'morphcook backup',
      );
      if (mounted) {
        final ratio = (export.compressionRatio * 100).round();
        _snack('${context.trRead('bak.exported')} · '
            '${context.trRead('bak.ratio', {'p': '$ratio'})}');
      }
    } catch (_) {
      if (mounted) _snack(context.trRead('common.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _import() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    try {
      final document = BackupService.importBytes(bytes);
      _askMode(document);
    } on DecryptionException catch (e) {
      if (e.reason == DecryptionReason.needsPassword) {
        _promptPassword(bytes);
      } else if (mounted) {
        _snack(e.message(context.read<AppState>().lang));
      }
    }
  }

  Future<void> _promptPassword(List<int> bytes) async {
    final controller = TextEditingController();
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperCard,
        title:
            Text(dialogContext.trRead('bak.needsPassword'), style: AppFonts.display(size: 18)),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: dialogContext.trRead('bak.passwordAgain')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.trRead('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.trRead('common.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final document = BackupService.importEncrypted(bytes, controller.text);
      _askMode(document);
    } on DecryptionException catch (e) {
      if (mounted) {
        _snack(e.message(state.lang));
        if (e.reason == DecryptionReason.wrongPassword) _promptPassword(bytes);
      }
    }
  }
  Future<void> _askMode(BackupDocument document) async {
    final state = context.read<AppState>();
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperCard,
        title: Text(dialogContext.trRead('bak.import'), style: AppFonts.display(size: 20)),
        content: Text(
          dialogContext.trRead('bak.summary', {
            'saved': '${document.saved.length}',
            'history': '${document.history.length}',
            'requests': '${document.contentRequests.length}',
          }),
          style: AppFonts.serif(size: 14, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ImportMode.merge),
            child: Text(dialogContext.trRead('bak.merge')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ImportMode.replace),
            child: Text(dialogContext.trRead('bak.replace')),
          ),
        ],
      ),
    );
    if (mode == null) return;
    await state.collections.importData(
      mode: mode,
      saved: document.saved,
      mealPlan: document.mealPlan,
      history: document.history,
      contentRequests: document.contentRequests,
    );
    await state.updateProfile(document.profile);
    await state.load();
    if (mounted) _snack(context.trRead('bak.imported'));
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      seed: 81,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(context.tr('bak.title'), style: AppFonts.display(size: 34)),
          const SizedBox(height: 8),
          Text(
            context.tr('bak.body'),
            style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 10),
          const DashedRule(glyph: '&'),
          const SizedBox(height: 14),
          Text(context.tr('bak.password'),
              style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: AppFonts.serif(size: 15),
            decoration: InputDecoration(
              hintText: context.tr('bak.passwordHint'),
              hintStyle: AppFonts.mono(size: 11, color: AppColors.inkFaint),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.inkFaint),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.teal),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _bigButton(context.tr('bak.export'), Icons.ios_share, _busy ? null : _export),
          const SizedBox(height: 12),
          _bigButton(context.tr('bak.import'), Icons.restore, _busy ? null : _import),
        ],
      ),
    );
  }

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.teal),
          color: AppColors.teal.withOpacity(0.07),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.teal),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppFonts.mono(size: 12, color: AppColors.teal, weight: FontWeight.w700),
            ),
            const Spacer(),
            if (_busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
              ),
          ],
        ),
      ),
    );
  }
}
