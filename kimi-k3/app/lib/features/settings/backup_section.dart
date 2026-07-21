import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup_service.dart';
import '../../core/l10n.dart';
import '../../core/models/profile.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';

/// Backup & restore section of the settings screen.
///
/// Export writes `morphcook-backup.json` (optionally AES-encrypted) plus a
/// plain `morphcook-backup.json.gz` to the temp dir and opens the share sheet.
/// Import auto-detects gzip/encryption, prompts for a password when needed,
/// then asks merge-or-replace. The bundled corpus is never touched.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final s = S(context);
    setState(() => _busy = true);
    try {
      final profile = context.read<ProfileStore>().profile;
      final localStore = context.read<LocalStore>();
      final backup = BackupService();
      final payload = backup.buildPayload(
        profile: profile,
        localData: localStore.exportData(),
      );

      final password = _passwordController.text.trim();
      final jsonBytes = backup.exportJson(
        payload,
        password: password.isEmpty ? null : password,
      );
      final gzBytes = backup.exportGzip(payload);

      final dir = await getTemporaryDirectory();
      final jsonFile = File('${dir.path}/morphcook-backup.json');
      final gzFile = File('${dir.path}/morphcook-backup.json.gz');
      await jsonFile.writeAsBytes(jsonBytes, flush: true);
      await gzFile.writeAsBytes(gzBytes, flush: true);

      await Share.shareXFiles(
        [XFile(jsonFile.path), XFile(gzFile.path)],
        subject: s.t('backup.share.subject'),
      );
      _snack(s.t('backup.export.success'));
    } catch (_) {
      _snack(s.t('backup.export.failure'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final s = S(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (!mounted) return;
    final picked = result?.files.single;
    if (picked == null) return;

    final Uint8List? bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (!mounted || bytes == null) return;
    final localStore = context.read<LocalStore>();
    final profileStore = context.read<ProfileStore>();

    final backup = BackupService();
    Map<String, dynamic> payload;
    try {
      payload = backup.importBackup(bytes);
    } on DecryptionException catch (e) {
      if (e.reason != DecryptionFailure.needsPassword) {
        await _showError(e.message);
        return;
      }
      final password = await _promptPassword();
      if (!mounted || password == null || password.isEmpty) return;
      try {
        payload = backup.importBackup(bytes, password: password);
      } on DecryptionException catch (e2) {
        await _showError(e2.message);
        return;
      }
    }
    if (!mounted) return;

    final merge = await _askMergeOrReplace();
    if (!mounted || merge == null) return;

    final profileJson = payload['profile'];
    if (profileJson is Map) {
      await profileStore.save(
        UserProfile.fromJson(profileJson.cast<String, dynamic>()),
      );
    }
    await localStore.importData(payload, merge: merge);
    _snack(s.t('backup.import.success'));
  }

  Future<String?> _promptPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final s = S(ctx);
        return AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text(
            s.t('backup.password.title'),
            style: AppText.headline(size: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('backup.password.body'), style: AppText.body(size: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                cursorColor: AppColors.coral,
                decoration: InputDecoration(
                  hintText: s.t('backup.password.label'),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.t('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(s.t('backup.password.confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showError(String message) {
    if (!mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final s = S(ctx);
        return AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text(
            s.t('backup.error.title'),
            style: AppText.headline(size: 20),
          ),
          content: Text(message, style: AppText.body(size: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.t('common.close')),
            ),
          ],
        );
      },
    );
  }

  /// Returns true for merge, false for replace, null when dismissed.
  Future<bool?> _askMergeOrReplace() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = S(ctx);
        return AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text(
            s.t('backup.merge.title'),
            style: AppText.headline(size: 20),
          ),
          content: Text(
            s.t('backup.merge.body'),
            style: AppText.body(size: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.t('backup.merge.merge')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                s.t('backup.merge.replace'),
                style: const TextStyle(color: AppColors.coral),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('settings.backup.section')),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          cursorColor: AppColors.coral,
          style: AppText.body(size: 15),
          decoration: InputDecoration(
            labelText: s.t('backup.password.label'),
            labelStyle: AppText.monoLabel(),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.coral),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(s.t('backup.password.hint'), style: AppText.handwritten(size: 17)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share, size: 16),
            label: Text(
              s.t('backup.export'),
              style: AppText.monoLabel(size: 12, color: AppColors.ink),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: 1.1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open_outlined, size: 16),
            label: Text(
              s.t('backup.import'),
              style: AppText.monoLabel(size: 12, color: AppColors.ink),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: 1.1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('backup.import.corpusNote'),
          style: AppText.handwritten(size: 17),
        ),
      ],
    );
  }
}
