import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/file_gateway.dart';
import '../../domain/backup_codec.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';

/// Export two files to the share sheet; restore from either, with an
/// optional password on the .json.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  bool _busyExport = false;
  bool _busyImport = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    final app = context.read<AppController>();
    final s = context.s;
    setState(() => _busyExport = true);
    try {
      await Future<void>.delayed(Duration.zero);
      final data = app.buildBackup();
      final pw = _password.text;
      final json = BackupCodec.encodeJson(data, password: pw.isEmpty ? null : pw);
      final gz = BackupCodec.encodeGzip(data);
      await FileGateway.instance.shareFiles(
        [
          SharedFile(name: BackupCodec.jsonFileName, bytes: json, mimeType: 'application/json'),
          SharedFile(name: BackupCodec.gzipFileName, bytes: gz, mimeType: 'application/gzip'),
        ],
        text: 'MorphCook backup',
      );
      _snack(s('backup.exported'));
    } catch (e) {
      _snack(s('backup.exportFailed', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  Future<void> _import() async {
    final app = context.read<AppController>();
    final s = context.s;
    setState(() => _busyImport = true);
    try {
      final picked = await FileGateway.instance.pickFile();
      if (picked == null || !mounted) return;
      BackupData? data;
      String? password;
      while (data == null) {
        try {
          data = BackupCodec.decode(picked.bytes, password: password);
        } on DecryptionException catch (e) {
          switch (e.reason) {
            case DecryptionReason.needsPassword:
            case DecryptionReason.wrongPassword:
              final pw = await _askPassword(
                error: e.reason == DecryptionReason.wrongPassword ? s('backup.error.wrongPassword') : null,
              );
              if (pw == null) return;
              password = pw;
            case DecryptionReason.corrupted:
              await _showError(s('backup.error.corrupted'));
              return;
            case DecryptionReason.invalidFormat:
              await _showError(s('backup.error.invalid'));
              return;
          }
        } on BackupFormatException catch (e) {
          await _showError(e.message.contains('newer') ? s('backup.error.newer') : s('backup.error.invalid'));
          return;
        }
      }
      if (!mounted) return;
      final mode = await _askMode(data);
      if (mode == null || !mounted) return;
      await app.applyBackup(data, mode);
      _snack(s('backup.restored'));
    } on FileGatewayException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyImport = false);
    }
  }

  Future<String?> _askPassword({String? error}) {
    final s = context.s;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('backup.needsPassword')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              style: AppText.body(size: 15),
              decoration: InputDecoration(hintText: s('backup.enterPassword')),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error, style: AppText.mono(color: Palette.terracotta, size: 12)),
            ],
          ],
        ),
        actions: [
          PaperButton(label: s('common.cancel'), kind: PaperButtonKind.quiet, onPressed: () => Navigator.of(ctx).pop()),
          PaperButton(label: s('backup.decrypt'), onPressed: () => Navigator.of(ctx).pop(ctrl.text)),
        ],
      ),
    );
  }

  Future<void> _showError(String message) {
    final s = context.s;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('backup.import')),
        content: Text(message),
        actions: [PaperButton(label: s('common.ok'), onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  Future<MergeMode?> _askMode(BackupData data) {
    final s = context.s;
    final planned = data.mealPlan.weeks.values.fold<int>(0, (n, w) => n + w.length);
    return showDialog<MergeMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('backup.mode.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s('backup.mode.note', {
              'date': s.longDate(data.exportedAt.toLocal()),
              'saved': '${data.saved.length}',
              'history': '${data.history.length}',
              'plan': '$planned',
            })),
            const SizedBox(height: 16),
            _ModeOption(
              title: s('backup.mode.merge'),
              note: s('backup.mode.merge.note'),
              icon: Icons.call_merge,
              onTap: () => Navigator.of(ctx).pop(MergeMode.merge),
            ),
            const SizedBox(height: 8),
            _ModeOption(
              title: s('backup.mode.replace'),
              note: s('backup.mode.replace.note'),
              icon: Icons.swap_horiz,
              onTap: () => Navigator.of(ctx).pop(MergeMode.replace),
            ),
          ],
        ),
        actions: [PaperButton(label: s('common.cancel'), kind: PaperButtonKind.quiet, onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    const pad = EdgeInsets.symmetric(horizontal: 20);
    return Scaffold(
      appBar: AppBar(title: Text(s('backup.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: MonoLabel(s('backup.kicker'))),
          SectionHeader(title: s('backup.export'), padding: const EdgeInsets.fromLTRB(20, 18, 20, 8)),
          Padding(padding: pad, child: Text(s('backup.export.note'), style: AppText.body(size: 14.5, color: Palette.inkSoft))),
          const SizedBox(height: 14),
          Padding(
            padding: pad,
            child: TextField(
              controller: _password,
              obscureText: true,
              style: AppText.body(size: 15),
              decoration: InputDecoration(hintText: s('backup.password'), prefixIcon: const Icon(Icons.lock_outline, size: 18)),
            ),
          ),
          const SizedBox(height: 6),
          Padding(padding: pad, child: HandNote(s('backup.password.note'), size: 18, color: Palette.inkFaint)),
          const SizedBox(height: 14),
          Padding(
            padding: pad,
            child: _busyExport
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                : PaperButton(label: s('backup.exportNow'), icon: Icons.ios_share, expand: true, onPressed: _export),
          ),
          const SizedBox(height: 16),
          Padding(padding: pad, child: PaperNote(text: s('backup.includes'), kicker: s('settings.data'), tone: Palette.sage)),
          const SizedBox(height: 8),
          Padding(padding: pad, child: MonoLabel(s('backup.contentRequests', {'n': '${app.contentRequests.length}'}))),
          const Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 0), child: DashedRule()),
          SectionHeader(title: s('backup.import'), padding: const EdgeInsets.fromLTRB(20, 18, 20, 8)),
          Padding(padding: pad, child: Text(s('backup.import.note'), style: AppText.body(size: 14.5, color: Palette.inkSoft))),
          const SizedBox(height: 14),
          Padding(
            padding: pad,
            child: _busyImport
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                : PaperButton(label: s('backup.importNow'), icon: Icons.folder_open_outlined, kind: PaperButtonKind.secondary, expand: true, onPressed: _import),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.title, required this.note, required this.icon, required this.onTap});
  final String title;
  final String note;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Palette.ruleStrong), borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Palette.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toLowerCase(), style: AppText.title(size: 16)),
                    const SizedBox(height: 2),
                    Text(note, style: AppText.mono(color: Palette.inkFaint, size: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
