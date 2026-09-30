import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/backup.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'help_screen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final password = TextEditingController();
  final service = BackupService();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  String errorKey(DecryptionReason reason) => switch (reason) {
    DecryptionReason.passwordRequired => 'enterPassword',
    DecryptionReason.incorrectPassword => 'incorrectPassword',
    DecryptionReason.corrupted => 'corruptedBackup',
    DecryptionReason.invalidFormat => 'invalidBackup',
  };
  Future<void> export() async {
    final state = AppScope.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? const Rect.fromLTWH(0, 0, 100, 100)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => busy = true);
    try {
      await state.flush();
      final files = await service.export(
        state.backupData(),
        password: password.text,
      );
      final temp = await getTemporaryDirectory();
      final folder = Directory('${temp.path}/morphcook-backup');
      await folder.create(recursive: true);
      final json = File('${folder.path}/morphcook-backup.json');
      final gz = File('${folder.path}/morphcook-backup.json.gz');
      await json.writeAsBytes(files.json, flush: true);
      await gz.writeAsBytes(files.compressed, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(json.path), XFile(gz.path)],
          fileNameOverrides: [
            'morphcook-backup.json',
            'morphcook-backup.json.gz',
          ],
          title: t(context, 'exportBackup'),
          sharePositionOrigin: shareOrigin,
        ),
      );
      password.clear();
      if (mounted) toast(context, 'backupExported');
    } catch (_) {
      if (mounted) toast(context, 'shareError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> askPassword({String? error}) async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(context, 'enterPassword'),
          style: serif(24, italic: true),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              Text(
                t(context, error),
                style: mono(11, color: KitchenColors.coral),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: field,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => Navigator.pop(context, field.text),
              decoration: InputDecoration(
                labelText: t(context, 'backupPassword'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: Text(t(context, 'next')),
          ),
        ],
      ),
    );
    // The closing route can still animate; keep the controller alive until then.
    Future.delayed(const Duration(milliseconds: 350), field.dispose);
    return value;
  }

  Future<void> restore() async {
    final state = AppScope.of(context);
    setState(() => busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'gz'],
        withData: true,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      if (file.size > BackupService.maxBytes) {
        toast(context, 'invalidBackup');
        return;
      }
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        if (mounted) toast(context, 'fileError');
        return;
      }
      Map<String, dynamic>? data;
      String? inputPassword;
      String? passwordError;
      while (data == null && mounted) {
        try {
          data = await service.import(bytes, password: inputPassword);
        } on DecryptionException catch (e) {
          if (e.reason == DecryptionReason.passwordRequired ||
              e.reason == DecryptionReason.incorrectPassword) {
            if (!mounted) return;
            passwordError = e.reason == DecryptionReason.incorrectPassword
                ? 'incorrectPassword'
                : null;
            inputPassword = await askPassword(error: passwordError);
            if (inputPassword == null || inputPassword.isEmpty) return;
          } else {
            if (mounted) toast(context, errorKey(e.reason));
            return;
          }
        }
      }
      if (!mounted || data == null) return;
      final merge = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            t(context, 'restoreChoose'),
            style: serif(26, italic: true),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t(context, 'merge'),
                  style: mono(12, color: KitchenColors.ink),
                ),
                subtitle: Text(t(context, 'mergeNote'), style: mono(10)),
                onTap: () => Navigator.pop(context, true),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t(context, 'replace'),
                  style: mono(12, color: KitchenColors.ink),
                ),
                subtitle: Text(t(context, 'replaceNote'), style: mono(10)),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t(context, 'cancel')),
            ),
          ],
        ),
      );
      if (merge == null) return;
      await state.restore(data, merge: merge);
      if (mounted) toast(context, 'restored');
    } on DecryptionException catch (e) {
      if (mounted) toast(context, errorKey(e.reason));
    } catch (_) {
      if (mounted) toast(context, 'fileError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PaperScaffold(
    appBar: KitchenAppBar(
      title: t(context, 'backup'),
      actions: [
        IconButton(
          tooltip: t(context, 'help'),
          onPressed: () => openHelp(context, 'backup'),
          icon: const Icon(Icons.help_outline, size: 20),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(t(context, 'backup'), style: serif(33, italic: true)),
        const SizedBox(height: 12),
        Text(t(context, 'backupSubtitle'), style: mono(12)),
        const SizedBox(height: 30),
        const Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: KitchenColors.teal,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: password,
          obscureText: true,
          enabled: !busy,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: t(context, 'backupPassword'),
            hintText: t(context, 'passwordHint'),
          ),
        ),
        const SizedBox(height: 16),
        NoteCard(child: Text(t(context, 'backupPrivacy'), style: mono(11))),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.ios_share, size: 18),
          label: Text(t(context, 'exportBackup')),
        ),
        const SizedBox(height: 25),
        const DashedRule(),
        const SizedBox(height: 25),
        OutlinedButton.icon(
          onPressed: busy ? null : restore,
          icon: const Icon(Icons.file_open_outlined, size: 18),
          label: Text(t(context, 'importBackup')),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}
