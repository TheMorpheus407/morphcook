import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../domain/backup/backup_models.dart';
import '../../platform/platform_services.dart';
import '../../state/app_services.dart';
import '../../state/backup_service.dart';
import '../../widgets/help_link.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// File-based backup and restore. Export writes `morphcook-backup.json`
/// (readable, encrypted when a password is set) and `morphcook-backup.json.gz`
/// (compressed, never encrypted) to the OS share sheet. Import detects
/// encryption and compression by itself.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final GlobalKey _exportKey = GlobalKey();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _exportInfo;
  String? _importInfo;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _size(int bytes) => bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

  String _reasonText(AppStrings s, DecryptionException e) => switch (e.reason) {
    DecryptionFailure.passwordRequired => s('backup.err.passwordRequired'),
    DecryptionFailure.wrongPassword => s('backup.err.wrongPassword'),
    DecryptionFailure.corrupted => s('backup.err.corrupted'),
    DecryptionFailure.invalidFormat => s('backup.err.invalidFormat'),
    DecryptionFailure.unsupportedVersion => s('backup.err.unsupportedVersion'),
  };

  Future<void> _export() async {
    final s = context.sRead;
    final backup = context.read<BackupService>();
    final platform = context.read<AppServices>().platform;
    final password = _password.text;
    if (password.isNotEmpty && password != _confirm.text) {
      setState(() => _error = s('backup.export.mismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _exportInfo = null;
    });
    try {
      final bundle = await backup.export(password: password.isEmpty ? null : password);
      final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await platform.files.shareFiles([
        BackupFile(
          name: bundle.jsonName,
          bytes: bundle.json,
          mimeType: bundle.encrypted ? 'application/octet-stream' : 'application/json',
        ),
        BackupFile(name: bundle.gzipName, bytes: bundle.gzip, mimeType: 'application/gzip'),
      ], origin: origin);
      final saving = bundle.json.isEmpty ? 0 : ((1 - bundle.gzip.length / bundle.json.length) * 100).round();
      if (mounted) {
        setState(
          () => _exportInfo = s('backup.export.done', {
            'json': _size(bundle.json.length),
            'gz': _size(bundle.gzip.length),
            'saving': saving.clamp(0, 99),
          }),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = s('backup.export.failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final s = context.sRead;
    final backup = context.read<BackupService>();
    final platform = context.read<AppServices>().platform;
    setState(() {
      _error = null;
      _importInfo = null;
    });
    final bytes = await platform.files.pickBackupFile();
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      BackupData data;
      try {
        data = backup.read(bytes);
      } on DecryptionException catch (e) {
        if (e.reason != DecryptionFailure.passwordRequired) rethrow;
        final decrypted = await _askPasswordAndDecrypt(bytes);
        if (decrypted == null) return;
        data = decrypted;
      }
      if (!mounted) return;
      final mode = await _askMode(data);
      if (mode == null || !mounted) return;
      final summary = await backup.apply(data, mode);
      if (mounted) {
        setState(
          () => _importInfo = s('backup.import.done', {
            'saved': summary.saved,
            'history': summary.history,
            'plan': summary.planSlots,
          }),
        );
      }
    } on DecryptionException catch (e) {
      if (mounted) setState(() => _error = _reasonText(s, e));
    } catch (_) {
      if (mounted) setState(() => _error = s('backup.err.invalidFormat'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks for the password until it fits, or the person gives up.
  Future<BackupData?> _askPasswordAndDecrypt(List<int> bytes) async {
    final backup = context.read<BackupService>();
    String? problem;
    while (mounted) {
      final password = await showDialog<String>(
        context: context,
        builder: (context) => _PasswordDialog(problem: problem),
      );
      if (password == null || !mounted) return null;
      try {
        return await backup.readEncrypted(bytes, password);
      } on DecryptionException catch (e) {
        if (e.reason != DecryptionFailure.wrongPassword) rethrow;
        problem = _reasonText(context.sRead, e);
      }
    }
    return null;
  }

  Future<ImportMode?> _askMode(BackupData data) {
    final s = context.sRead;
    return showDialog<ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(s('backup.import.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s('backup.import.contents', {
                'saved': data.saved.length,
                'history': data.history.length,
                'plan': data.mealPlan.values.fold<int>(0, (a, w) => a + w.length),
              }),
              style: AppText.mono(size: 12),
            ),
            const SizedBox(height: 12),
            Text(s('backup.import.mergeBody'), style: AppText.serif(size: 15)),
            const SizedBox(height: 6),
            Text(s('backup.import.replaceBody'), style: AppText.serif(size: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.replace),
            child: Text(s('backup.import.replace')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.merge),
            child: Text(s('backup.import.merge')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: PaperIconButton(
                          icon: Icons.arrow_back,
                          tooltip: s('common.back'),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                  TabHeader(title: s('backup.title'), note: s('backup.note')),
                  Text(s('backup.intro'), style: AppText.serif(size: 16, height: 1.55)),
                  const SizedBox(height: 4),
                  HelpLink(label: s('help.backup'), entryId: 'backup-restore'),
                  const SizedBox(height: 22),
                  FormSection(
                    title: s('backup.export.title'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s('backup.export.body'),
                          style: AppText.serif(size: 15, color: Palette.inkSoft, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: AppText.mono(size: 15, color: Palette.ink),
                          decoration: InputDecoration(
                            labelText: s('backup.export.password'),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? s('backup.showPassword') : s('backup.hidePassword'),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_password.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _confirm,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: AppText.mono(size: 15, color: Palette.ink),
                            decoration: InputDecoration(labelText: s('backup.export.confirm')),
                          ),
                          const SizedBox(height: 6),
                          Text(s('backup.export.encryptedNote'), style: AppText.hand(size: 19, color: Palette.inkSoft)),
                        ],
                        const SizedBox(height: 14),
                        KeyedSubtree(
                          key: _exportKey,
                          child: PaperButton(
                            label: s('backup.export.action'),
                            icon: Icons.ios_share,
                            onPressed: _busy ? null : _export,
                          ),
                        ),
                        if (_exportInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(_exportInfo!, style: AppText.mono(size: 12, color: Palette.tealDeep)),
                          ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('backup.import.heading'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s('backup.import.body'),
                          style: AppText.serif(size: 15, color: Palette.inkSoft, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        PaperButton(
                          label: s('backup.import.action'),
                          icon: Icons.file_open_outlined,
                          style: PaperButtonStyle.outline,
                          onPressed: _busy ? null : _import,
                        ),
                        if (_importInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(_importInfo!, style: AppText.mono(size: 12, color: Palette.tealDeep)),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Palette.coral.withValues(alpha: 0.1),
                          border: Border.all(color: Palette.coral),
                        ),
                        child: Text(
                          _error!,
                          style: AppText.serif(size: 15.5, color: Palette.coralDeep, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({this.problem});

  final String? problem;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      scrollable: true,
      title: Text(s('backup.password.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s('backup.password.body'), style: AppText.serif(size: 15)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: AppText.mono(size: 15, color: Palette.ink),
            decoration: InputDecoration(labelText: s('backup.export.password')),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          if (widget.problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.problem!,
                style: AppText.serif(size: 14.5, color: Palette.coralDeep, weight: FontWeight.w700),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s('common.cancel'))),
        TextButton(onPressed: () => Navigator.of(context).pop(_text.text), child: Text(s('backup.password.unlock'))),
      ],
    );
  }
}
