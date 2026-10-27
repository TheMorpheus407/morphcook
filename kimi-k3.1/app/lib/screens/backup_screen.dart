import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/user_data.dart';
import '../services/backup_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService service = BackupService();
  final TextEditingController passwordController = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.t('backup_restore'))),
    body: Paper(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(23, 18, 23, 30),
          children: [
            Text(
              context.l10n.t('backup_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.t('backup_body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Polaroid(
              turns: -0.002,
              padding: 18,
              child: Column(
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('backup_password'),
                      hintText: context.l10n.t('backup_password_hint'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.t('gzip_unencrypted'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: context.l10n.t('export_backup'),
                icon: Icons.ios_share_outlined,
                onPressed: busy ? null : export,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : importBackup,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(context.l10n.t('import_backup')),
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 25),
              const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
              const SizedBox(height: 10),
              Text(context.l10n.t('loading'), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 28),
            const DashedRule(),
            Text(
              context.l10n.t('offline_note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final app = context.read<AppState>();
      await app.writesSettled;
      final backup = await service.create(
        app.profile,
        app.snapshot,
        password: passwordController.text,
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await service.share(
        backup,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
      if (mounted) message(context.l10n.t('backup_created'));
    } catch (error) {
      if (mounted) message('${context.l10n.t('backup_error')} $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importBackup() async {
    setState(() => busy = true);
    try {
      final bytes = await service.pick();
      if (bytes == null || !mounted) return;
      var data = await decode(bytes);
      if (data == null) {
        final password = await askPassword();
        if (password == null || !mounted) return;
        data = await service.import(bytes, password: password);
      }
      if (!mounted) return;
      final merge = await askRestoreMode();
      if (merge == null || !mounted) return;
      await context.read<AppState>().restore(data, merge: merge);
      if (mounted) message(context.l10n.t('restore_success'));
    } on DecryptionException catch (error) {
      if (mounted) message(localizeError(error));
    } on BackupValidationException catch (error) {
      if (mounted) message(error.message);
    } catch (error) {
      if (mounted) message('${context.l10n.t('backup_error')} $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<BackupData?> decode(List<int> bytes) async {
    try {
      return await service.import(bytes);
    } on DecryptionException catch (error) {
      if (error.reason == DecryptionFailure.passwordRequired) return null;
      rethrow;
    }
  }

  Future<String?> askPassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paperLight,
        title: Text(context.l10n.t('import_password_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.l10n.t('import_password_hint'),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.t('continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool?> askRestoreMode() => showDialog<bool>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: AppColors.paperLight,
      title: Text(context.l10n.t('restore_choice_title')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('restore_merge'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(context.l10n.t('restore_merge_body')),
              ],
            ),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('restore_replace'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(context.l10n.t('restore_replace_body')),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String localizeError(DecryptionException error) {
    if (context.lang == 'en') return error.message;
    return switch (error.reason) {
      DecryptionFailure.wrongPassword =>
        'Falsches Passwort. Bitte versuche es erneut.',
      DecryptionFailure.corrupted =>
        'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.',
      DecryptionFailure.passwordRequired =>
        'Für diese Sicherung wird ein Passwort benötigt.',
      DecryptionFailure.invalidFormat => context.l10n.t('invalid_backup'),
    };
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
