import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.dart';
import '../../logic/backup_codec.dart';
import '../../state/backup_service.dart';
import '../../state/library_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _errorText(DecryptionFailure f) => context.trRead(switch (f) {
    DecryptionFailure.wrongPassword => 'backup.error.wrongPassword',
    DecryptionFailure.corrupted => 'backup.error.corrupted',
    DecryptionFailure.invalidFormat => 'backup.error.invalidFormat',
    DecryptionFailure.passwordRequired => 'backup.import.password',
  });

  Future<void> _export() async {
    final tr = context.trRead;
    if (_password.text != _confirm.text) {
      setState(() => _status = tr('backup.password.mismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final files = await context.read<BackupService>().exportAndShare(
        password: _password.text.isEmpty ? null : _password.text,
        origin: origin,
      );
      final kb = (files.gzip.length / 1024).toStringAsFixed(1);
      if (mounted) setState(() => _status = tr('backup.export.done', {'size': '$kb KB'}));
    } catch (e) {
      if (mounted) setState(() => _status = tr('backup.error.generic', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final tr = context.trRead;
    final service = context.read<BackupService>();
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final bytes = await service.pickFile();
      if (bytes == null || !mounted) return;
      final doc = await _decode(service, bytes);
      if (doc == null || !mounted) return;
      final mode = await _askMode();
      if (mode == null || !mounted) return;
      await service.apply(doc, mode);
      if (mounted) setState(() => _status = tr('backup.import.done'));
    } on DecryptionException catch (e) {
      if (mounted) setState(() => _status = _errorText(e.reason));
    } catch (e) {
      if (mounted) setState(() => _status = tr('backup.error.generic', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plain/gzip decode; on an encrypted file, prompt for the password and
  /// retry until it's right or the user cancels.
  Future<Map<String, dynamic>?> _decode(BackupService service, Uint8List bytes) async {
    try {
      return service.codec.decode(bytes);
    } on DecryptionException catch (e) {
      if (e.reason != DecryptionFailure.passwordRequired) rethrow;
    }
    String? error;
    while (mounted) {
      final pw = await _askPassword(error);
      if (pw == null) return null;
      try {
        return service.codec.decodeEncrypted(bytes, pw);
      } on DecryptionException catch (e) {
        if (e.reason != DecryptionFailure.wrongPassword) rethrow;
        error = _errorText(e.reason);
      }
    }
    return null;
  }

  Future<String?> _askPassword(String? error) {
    final tr = context.trRead;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('backup.import.password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('import-password'),
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(hintText: tr('backup.password')),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            if (error != null) ...[const SizedBox(height: 8), Text(error, style: MT.mono(11, color: MC.coralDeep))],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(tr('common.ok'))),
        ],
      ),
    );
  }

  Future<ImportMode?> _askMode() {
    final tr = context.trRead;
    Widget option(ImportMode mode, String title, String body) => ListTile(
      title: Text(title, style: MT.display(20)),
      subtitle: Text(body, style: MT.serif(13.5, color: MC.inkSoft)),
      onTap: () => Navigator.pop(context, mode),
    );
    return showModalBottomSheet<ImportMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(tr('backup.import.mode'), style: MT.display(24)),
            ),
            option(ImportMode.merge, tr('backup.import.merge'), tr('backup.import.merge.body')),
            option(ImportMode.replace, tr('backup.import.replace'), tr('backup.import.replace.body')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    context.watch<LibraryStore>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('backup.title'))),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(tr('backup.export'), style: MT.display(26)),
            const SizedBox(height: 8),
            Text(tr('backup.export.body'), style: MT.serif(15, color: MC.inkSoft)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('export-password'),
              controller: _password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr('backup.password'),
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
              ),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('export-password-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: tr('backup.password.confirm'),
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Text(tr('backup.password.note'), style: MT.mono(10.5, color: MC.coralDeep)),
            ],
            const SizedBox(height: 16),
            InkButton(
              key: const Key('export-btn'),
              label: tr('backup.export.cta'),
              icon: Icons.ios_share,
              expand: true,
              onPressed: _busy ? null : _export,
            ),
            const SizedBox(height: 34),
            const DashedRule(),
            const SizedBox(height: 26),
            Text(tr('backup.import'), style: MT.display(26)),
            const SizedBox(height: 8),
            Text(tr('backup.import.body'), style: MT.serif(15, color: MC.inkSoft)),
            const SizedBox(height: 16),
            PaperButton(
              key: const Key('import-btn'),
              label: tr('backup.import.cta'),
              icon: Icons.file_open_outlined,
              onPressed: _busy ? null : _import,
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 20), child: LinearProgressIndicator()),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: HandNote(_status!, size: 22, color: MC.tealDeep, angle: 0),
              ),
            const SizedBox(height: 20),
            TextLink(tr('backup.help'), onTap: () => openFaq(context, entryId: 'backup')),
          ],
        ),
      ),
    );
  }
}
