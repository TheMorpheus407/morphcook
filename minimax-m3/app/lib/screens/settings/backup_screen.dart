import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../backup/backup_encryption.dart';
import '../../localization/i18n.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';

enum BackupMode { export, import }

class BackupScreen extends StatefulWidget {
  final BackupMode mode;
  const BackupScreen({super.key, required this.mode});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doExport() async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final state = AppScope.of(context);
      final pwd = _passwordCtrl.text.trim();
      await state.backupService.exportToShare(password: pwd.isEmpty ? null : pwd);
      if (pwd.isNotEmpty) {
        await state.profileRepo.update((p) => p.copyWith(hasBackupPassword: true));
      }
      if (mounted) {
        setState(() => _message = I18n.of(context).backupShared);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString();
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doImport() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });

    final state = AppScope.of(context);
    final s = I18n.of(context);
    final notifier = I18n.notifierOf(context);

    try {
      var pwd = _passwordCtrl.text.trim();
      Map<String, dynamic> payload;
      try {
        payload = await state.backupService
            .readBackupFile(File(path), password: pwd.isEmpty ? null : pwd);
      } on WrongPasswordException {
        // Ask for a password
        final entered = await _askForPassword();
        if (entered == null) {
          setState(() => _busy = false);
          return;
        }
        pwd = entered;
        payload = await state.backupService
            .readBackupFile(File(path), password: pwd);
      }

      final replace = await _askMergeOrReplace();
      if (replace == null) {
        setState(() => _busy = false);
        return;
      }

      await state.backupService.applyBackup(payload, replace: replace);
      if (mounted) {
        setState(() => _message = s.backupImported);
        notifier.setLang(state.profileRepo.profile.lang);
      }
    } on WrongPasswordException {
      _setError(s.backupWrongPassword);
    } on CorruptedBackupException {
      _setError(s.backupCorrupted);
    } on InvalidBackupFormatException {
      _setError(s.backupNotValid);
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _message = msg;
        _error = true;
      });
    }
  }

  Future<String?> _askForPassword() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(I18n.of(context).backupPasswordPrompt),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: Text(I18n.of(context).done),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askMergeOrReplace() async {
    final s = I18n.of(context);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.backupMergeOrReplace),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.backupMerge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.backupReplace),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final isExport = widget.mode == BackupMode.export;
    return Scaffold(
      appBar: AppBar(
        title: Text(isExport ? s.backupExportTitle : s.backupImportTitle),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Masthead(
                title: isExport ? s.backupExportTitle : s.backupImportTitle,
                subtitle: isExport ? s.backupExportBody : s.backupImportBody,
                align: TextAlign.left,
                titleSize: 30,
              ),
              const SizedBox(height: 24),
              if (isExport) ...[
                Text(s.backupOptionalPassword.toUpperCase(),
                    style: MCTypography.eyebrow()),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '••••••••'),
                ),
                const SizedBox(height: 12),
                Text(s.backupHumanReadable, style: MCTypography.italic(size: 13)),
                Text(s.backupCompressed,
                    style: MCTypography.italic(size: 13, color: MCColors.inkFaded)),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _doExport,
                  icon: const Icon(Icons.share, size: 16),
                  label: Text(s.backupCreateFiles),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _busy ? null : _doImport,
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: Text(s.backupImportPick),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_message != null) ...[
                const SizedBox(height: 18),
                const DashedRule(),
                const SizedBox(height: 12),
                HandwrittenNote(
                  text: _message!,
                  color: _error ? MCColors.coral : MCColors.olive,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
