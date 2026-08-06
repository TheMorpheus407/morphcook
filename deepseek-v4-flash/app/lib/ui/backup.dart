import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../services/backup_service.dart';
import 'widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _encrypt = false;
  bool _busy = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(L10n.tBackup),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: svc.state,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Center(
              child: ZinePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: t(L10n.tExportBackup)),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export(svc, t),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text(t(L10n.tExportBackup),
                          style: AppText.mono(context, size: 11)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(L10n.tEncryptToggle),
                          style: AppText.serif(context, size: 15)),
                      value: _encrypt,
                      onChanged: (v) => setState(() => _encrypt = v),
                    ),
                    if (_encrypt) ...[
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: AppText.mono(context, size: 12),
                        decoration: InputDecoration(
                            hintText: t(L10n.tBackupPassword)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      t(L10n.tBackupNote),
                      style: AppText.mono(
                          context, size: 10, color: AppColors.inkFaint),
                    ),
                    const DottedDivider(),
                    SectionHeader(title: t(L10n.tImportBackup)),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _import(svc, t),
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: Text(t(L10n.tImportBackup),
                          style: AppText.mono(context, size: 11)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(
      Services svc, String Function(String) t) async {
    setState(() => _busy = true);
    try {
      final pw = _encrypt && _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null;
      final bytes =
          BackupService.encode(svc.state.exportPayload(), password: pw);
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final path = '${dir.path}/morphcook-backup-$stamp.mcbk';
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'MorphCook backup'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t(L10n.tExportOk))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t(L10n.tExportFail))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(
      Services svc, String Function(String) t) async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() => _busy = true);

    BackupErrorType? error;
    BackupPayload? payload;
    try {
      final bytes = await File(path).readAsBytes();
      String? pw;
      if (BackupCrypto.isEncrypted(bytes)) {
        final entered = await _askPassword(t);
        if (entered == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        pw = entered;
      }
      payload = BackupService.decode(bytes, password: pw);
    } catch (e) {
      error = e is BackupException ? e.type : BackupErrorType.unknown;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      final msg = _messageFor(error, t);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final merge = await _askMerge(t);
    if (merge == null || !mounted) return;
    await svc.state.importPayload(payload!, merge: merge);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t(L10n.tRestoreOk))));
  }

  String _messageFor(BackupErrorType error, String Function(String) t) {
    switch (error) {
      case BackupErrorType.notMorphcook:
        return t(L10n.tInvalidFormat);
      case BackupErrorType.corrupted:
        return t(L10n.tCorrupted);
      case BackupErrorType.wrongPassword:
        return t(L10n.tWrongPassword);
      case BackupErrorType.unknown:
        return t(L10n.tInvalidFormat);
    }
  }

  Future<String?> _askPassword(String Function(String) t) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t(L10n.tEncryptedPrompt),
          style: AppText.serif(context, size: 16, weight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: AppText.mono(context, size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(L10n.tCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t(L10n.tDone)),
          ),
        ],
      ),
    );
    controller.dispose();
    return text;
  }

  Future<bool?> _askMerge(String Function(String) t) async {
    var merge = true;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            t(L10n.tImportBackup),
            style: AppText.serif(context, size: 16, weight: FontWeight.w700),
          ),
          content: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true, label: Text(t(L10n.tMerge))),
              ButtonSegment(
                  value: false, label: Text(t(L10n.tReplace))),
            ],
            selected: {merge},
            onSelectionChanged: (s) => setState(() => merge = s.first),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t(L10n.tCancel)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, merge),
              child: Text(t(L10n.tConfirm)),
            ),
          ],
        ),
      ),
    );
  }
}