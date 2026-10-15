import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final TextEditingController _exportPasswordCtrl = TextEditingController();
  final TextEditingController _importPasswordCtrl = TextEditingController();
  final TextEditingController _importJsonPasteCtrl = TextEditingController();

  RestoreMode _restoreMode = RestoreMode.replace;
  BackupExportResult? _lastExport;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _exportPasswordCtrl.dispose();
    _importPasswordCtrl.dispose();
    _importJsonPasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleExport(MorphCookAppState appState) async {
    final pwd = _exportPasswordCtrl.text.trim();
    final result = await appState.exportBackup(
      password: pwd.isEmpty ? null : pwd,
    );
    setState(() {
      _lastExport = result;
      _isError = false;
      _statusMessage = appState.lang == 'de'
          ? 'Backup erstellt: morphcook-backup.json (${result.isEncrypted ? "AES-256-GCM verschlüsselt" : "unverschlüsselt"}, ${result.jsonFileBytes.length} B) & morphcook-backup.json.gz (${result.gzipFileBytes.length} B, ${(result.compressionRatio * 100).toStringAsFixed(0)} % kleiner).'
          : 'Generated morphcook-backup.json (${result.isEncrypted ? "AES-256-GCM encrypted" : "plain"}, ${result.jsonFileBytes.length} B) & morphcook-backup.json.gz (${result.gzipFileBytes.length} B, ${(result.compressionRatio * 100).toStringAsFixed(0)}% smaller).';
    });
  }

  Future<void> _shareExportedFiles() async {
    final exp = _lastExport;
    if (exp == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              exp.jsonFileBytes,
              name: 'morphcook-backup.json',
              mimeType: 'application/json',
            ),
            XFile.fromData(
              exp.gzipFileBytes,
              name: 'morphcook-backup.json.gz',
              mimeType: 'application/gzip',
            ),
          ],
          subject: 'MorphCook Backup',
        ),
      );
    } catch (_) {
      // Share sheet may not be available in headless test environments
    }
  }

  Future<void> _handleImportBytes(
    MorphCookAppState appState,
    Uint8List bytes,
  ) async {
    try {
      await appState.restoreFromBackupBytes(
        bytes,
        password: _importPasswordCtrl.text.trim().isEmpty
            ? null
            : _importPasswordCtrl.text.trim(),
        mode: _restoreMode,
      );
      setState(() {
        _isError = false;
        _statusMessage = appState.lang == 'de'
            ? 'Backup erfolgreich wiederhergestellt (${_restoreMode.name}).'
            : 'Backup restored successfully (${_restoreMode.name}).';
      });
    } on DecryptionException catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final isDe = appState.lang == 'de';

    return Scaffold(
      appBar: AppBar(
        title: Text(isDe ? 'backup & wiederherstellung' : 'backup & restore'),
      ),
      body: PaperGrainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            // Export Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NostalgicPalette.cardStock,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: NostalgicPalette.mutedRule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDe
                        ? '1. daten exportieren (.json & .json.gz)'
                        : '1. export backup (.json & .json.gz)',
                    style: NostalgicTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.terracotta,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDe
                        ? 'Erstellt morphcook-backup.json (optional mit AES-256-GCM Passwort geschützt, Header „ENC“) sowie morphcook-backup.json.gz (GZip-komprimiert).'
                        : 'Writes morphcook-backup.json (optionally AES-256-GCM encrypted with "ENC" magic header) and morphcook-backup.json.gz (GZip compressed).',
                    style: NostalgicTheme.serifBody(
                      fontSize: 14,
                      color: NostalgicPalette.fadedInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('backup_export_password_input'),
                    controller: _exportPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isDe
                          ? 'Optionales Passwort (AES-256-GCM, PBKDF2 10.000 Iter.)'
                          : 'Optional password (AES-256-GCM, PBKDF2 10,000 iter.)',
                      labelStyle: NostalgicTheme.mono(fontSize: 11),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('generate_backup_btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: NostalgicPalette.terracotta,
                          foregroundColor: NostalgicPalette.cardStock,
                        ),
                        icon: const Icon(Icons.download_outlined, size: 17),
                        label: Text(
                          isDe ? 'Backup generieren' : 'Generate Backup',
                        ),
                        onPressed: () => _handleExport(appState),
                      ),
                      if (_lastExport != null) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.share_outlined, size: 17),
                          label: Text(isDe ? 'Teilen' : 'Share Sheet'),
                          onPressed: _shareExportedFiles,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const DashedRule(),
            const SizedBox(height: 18),

            // Import Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NostalgicPalette.cardStock,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: NostalgicPalette.mutedRule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDe
                        ? '2. backup importieren (auto-erkennung: enc / gzip / json)'
                        : '2. import backup (auto-detects enc / gzip / json)',
                    style: NostalgicTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NostalgicPalette.sage,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        key: const ValueKey('restore_mode_replace'),
                        selected: _restoreMode == RestoreMode.replace,
                        label: Text(isDe ? 'Ersetzen (Replace)' : 'Replace'),
                        onSelected: (_) =>
                            setState(() => _restoreMode = RestoreMode.replace),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const ValueKey('restore_mode_merge'),
                        selected: _restoreMode == RestoreMode.merge,
                        label: Text(isDe ? 'Zusammenführen (Merge)' : 'Merge'),
                        onSelected: (_) =>
                            setState(() => _restoreMode = RestoreMode.merge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('backup_import_password_input'),
                    controller: _importPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isDe
                          ? 'Passwort für verschlüsseltes Backup (falls ENC)'
                          : 'Decryption password (if encrypted ENC file)',
                      labelStyle: NostalgicTheme.mono(fontSize: 11),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('backup_import_json_paste_input'),
                    controller: _importJsonPasteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isDe
                          ? 'Oder Backup-JSON hier direkt einfügen…'
                          : 'Or paste backup JSON payload directly here…',
                      hintStyle: NostalgicTheme.mono(fontSize: 11),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const ValueKey('import_pasted_json_btn'),
                        onPressed: () {
                          final raw = _importJsonPasteCtrl.text;
                          _handleImportBytes(
                            appState,
                            Uint8List.fromList(utf8.encode(raw)),
                          );
                        },
                        child: Text(
                          isDe ? 'JSON importieren' : 'Restore Pasted JSON',
                        ),
                      ),
                      if (_lastExport != null) ...[
                        OutlinedButton(
                          key: const ValueKey('restore_last_json_btn'),
                          onPressed: () => _handleImportBytes(
                            appState,
                            _lastExport!.jsonFileBytes,
                          ),
                          child: Text(
                            isDe
                                ? 'Letzte .json wiederherstellen'
                                : 'Restore Last .json',
                          ),
                        ),
                        OutlinedButton(
                          key: const ValueKey('restore_last_gzip_btn'),
                          onPressed: () => _handleImportBytes(
                            appState,
                            _lastExport!.gzipFileBytes,
                          ),
                          child: Text(
                            isDe
                                ? 'Letzte .json.gz wiederherstellen'
                                : 'Restore Last .json.gz',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const ValueKey('backup_status_banner'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isError
                      ? NostalgicPalette.berry.withValues(alpha: 0.12)
                      : NostalgicPalette.sage.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isError
                        ? NostalgicPalette.berry
                        : NostalgicPalette.sage,
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: NostalgicTheme.mono(
                    fontSize: 11.5,
                    color: _isError
                        ? NostalgicPalette.berry
                        : NostalgicPalette.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
