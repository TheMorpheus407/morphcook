/// Backup & restore screen: export two files (optional AES-256-GCM
/// password), import + merge-or-replace, inline status + error surfacing.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/backup_crypt.dart';
import '../core/backup_service.dart';
import '../core/theme.dart';
import 'morph.dart';
import 'widgets.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _pw = TextEditingController();
  bool _busy = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _note(String? status, [String? error]) =>
      setState(() { _status = status; _error = error; });

  Future<void> _export() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    final pw = _pw.text.trim();
    try {
      await BackupService(Morph.of(context).store)
          .export(password: pw.isEmpty ? null : pw);
      if (!mounted) return;
      _note(Morph.of(context).t('bk.exported'));
    } catch (e) {
      if (!mounted) return;
      _note(null, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _choose(MorphData m) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Palette.cardPaper,
        title: Text(m.t('bk.choose'), style: T.h2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, null),
            child: Text(m.t('common.cancel'), style: T.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(m.t('bk.merge'), style: T.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(m.t('bk.replace'), style: T.body),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    if (_busy) return;
    final m = Morph.of(context);
    setState(() { _busy = true; _error = null; });
    try {
      final payload = await pickAndDecode(
          m.store,
          password: _pw.text.trim().isEmpty ? null : _pw.text.trim());
      if (!mounted) return;
      final choice = await _choose(m);
      if (choice == null) {
        _note(null);
        return;
      }
      m.store.restoreFromSnapshot(payload, replace: choice == false);
      final n = m.store.saved.length;
      final h = m.store.history.length;
      final p = m.store.mealPlan.values.length;
      _note(m.tf('bk.imported-sub', {'n': '$n', 'm': '$h', 'p': '$p'}));
    } on NoFileException {
      _note(null, m.t('bk.no-file'));
    } on DecryptionException catch (e) {
      _note(null,
          e.reason == 'wrong-password' ? m.t('bk.err.badpass') : m.t('bk.err.corrupt'));
    } catch (e) {
      _note(null, m.t('bk.err.invalid'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(m.t('bk.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(m.t('bk.sub'),
                style: T.body.copyWith(fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            SectionHeader(label: m.t('bk.export')),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _pw,
                decoration: InputDecoration(
                  labelText: m.t('bk.password'),
                  helperText: m.t('bk.password.sub'),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.ios_share),
                label: Text(m.t('bk.export')),
                onPressed: _busy ? null : _export,
              ),
            ),
            const SizedBox(height: 28),
            SectionHeader(label: m.t('bk.import')),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.file_download),
                label: Text(m.t('bk.import')),
                onPressed: _busy ? null : _import,
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: Palette.ink.withValues(alpha: 0.04),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Palette.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_status!, style: T.body)),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: T.body.copyWith(color: Colors.red))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
