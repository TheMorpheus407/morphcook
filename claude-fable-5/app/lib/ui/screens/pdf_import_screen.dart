import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/import/pdf_recipe_import.dart';
import '../../logic/import/pdf_text_extractor.dart';
import '../../logic/local_file_bytes.dart';
import 'personal_recipe_editor_screen.dart';

class PdfImportScreen extends StatefulWidget {
  final Future<(String, Uint8List)?> Function()? pickPdf;
  final PdfTextExtractor extractor;
  const PdfImportScreen({
    super.key,
    this.pickPdf,
    this.extractor = const PdfTextExtractor(),
  });
  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  bool _busy = false;
  List<PdfRecipeImport> _entries = [];
  String? _filename;
  String? _error;
  String tr(String en, String de) =>
      context.read<AppState>().lang == 'de' ? de : en;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Import PDF', 'PDF importieren'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(
              'Import a text PDF, including recipes created with Sonnet. Everything is processed on this device. Review ingredients, quantities, steps, servings and time before saving.',
              'Importiere ein Text-PDF, auch mit Sonnet erstellte Rezepte. Alles wird auf diesem Gerät verarbeitet. Prüfe Zutaten, Mengen, Schritte, Portionen und Zeit vor dem Speichern.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Up to 10 MiB and 50 pages. Scanned images and password-protected PDFs are unsupported. Photos are not extracted.',
              'Bis zu 10 MiB und 50 Seiten. Gescannte Bilder und passwortgeschützte PDFs werden nicht unterstützt. Fotos werden nicht übernommen.',
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('pick-pdf-recipe'),
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(tr('Choose PDF', 'PDF auswählen')),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, key: const ValueKey('pdf-import-error')),
          if (_filename != null)
            Text(_filename!, style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _entries.length; i++) ...[
            const Divider(),
            Text(
              _entries[i].recipe?.title ??
                  tr('Unstructured text', 'Unstrukturierter Text'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_entries[i].isStructured)
              Text(
                tr(
                  'Recipe sections could not be recognized reliably. Copy the extracted text or use it as a reference while entering the recipe manually.',
                  'Die Rezeptabschnitte wurden nicht sicher erkannt. Kopiere den Text oder nutze ihn beim manuellen Anlegen des Rezepts als Vorlage.',
                ),
              ),
            if (_entries[i].usedDefaultTime || _entries[i].usedDefaultServings)
              Text(
                tr(
                  'Missing or unclear values use 30 minutes and/or 2 servings. Check these in the editor.',
                  'Für fehlende oder unklare Angaben werden 30 Minuten und/oder 2 Portionen eingesetzt. Bitte im Editor prüfen.',
                ),
              ),
            ExpansionTile(
              title: Text(tr('Extracted text', 'Extrahierter Text')),
              children: [
                SizedBox(
                  height: 240,
                  child: SingleChildScrollView(
                    child: SelectableText(_entries[i].sourceText),
                  ),
                ),
                TextButton(
                  onPressed: () => _copy(_entries[i].sourceText),
                  child: Text(tr('Copy text', 'Text kopieren')),
                ),
              ],
            ),
            FilledButton(
              key: ValueKey('review-pdf-recipe-$i'),
              onPressed: _busy ? null : () => _edit(_entries[i]),
              child: Text(
                _entries[i].isStructured
                    ? tr('Review recipe', 'Rezept prüfen')
                    : tr('Create manually', 'Manuell anlegen'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Text copied.', 'Text kopiert.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Could not copy. Select the text to copy it.',
            'Kopieren fehlgeschlagen. Text zum Kopieren markieren.',
          ),
        );
      }
    }
  }

  Future<(String, Uint8List)?> _pickDefault() =>
      withMorphCookShareFiles(() async {
        try {
          final selection = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            withData: false,
            withReadStream: true,
          );
          final file = selection?.files.firstOrNull;
          if (file == null) return null;
          return (
            file.name,
            await readPickedFileBytes(file, maxBytes: maxPdfImportBytes),
          );
        } finally {
          await clearPickerTemporaryFiles();
        }
      });

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await (widget.pickPdf ?? _pickDefault)();
      if (picked == null) return;
      final text = await widget.extractor.extract(picked.$2);
      final entries = parsePdfRecipeText(text, filename: picked.$1);
      if (mounted) {
        setState(() {
          _entries = entries;
          _filename = picked.$1;
        });
      }
    } on LocalFileTooLargeException {
      if (mounted) setState(() => _error = _failure(PdfImportFailure.tooLarge));
    } on PdfImportException catch (error) {
      if (mounted) setState(() => _error = _failure(error.failure));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Could not import this PDF. Try a text PDF or enter the recipe manually.',
            'Dieses PDF konnte nicht importiert werden. Bitte ein Text-PDF versuchen oder das Rezept manuell anlegen.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _failure(PdfImportFailure failure) => switch (failure) {
    PdfImportFailure.tooLarge => tr(
      'This PDF exceeds 10 MiB.',
      'Dieses PDF ist größer als 10 MiB.',
    ),
    PdfImportFailure.tooManyPages => tr(
      'This PDF exceeds 50 pages. Export only the recipe pages.',
      'Dieses PDF hat mehr als 50 Seiten. Bitte nur die Rezeptseiten exportieren.',
    ),
    PdfImportFailure.textTooLarge => tr(
      'This PDF contains too much or overly complex text. Export a shorter recipe PDF.',
      'Dieses PDF enthält zu viel oder zu komplexen Text. Bitte ein kürzeres Rezept-PDF exportieren.',
    ),
    PdfImportFailure.encrypted => tr(
      'Password-protected PDFs are unsupported. Export an unprotected copy you can access.',
      'Passwortgeschützte PDFs werden nicht unterstützt. Bitte eine zugängliche, ungeschützte Kopie exportieren.',
    ),
    PdfImportFailure.permissionDenied => tr(
      'This PDF does not allow text extraction.',
      'Dieses PDF erlaubt keine Textextraktion.',
    ),
    PdfImportFailure.noText => tr(
      'No selectable text found. Scanned PDFs need OCR first, or enter the recipe manually.',
      'Kein auswählbarer Text gefunden. Gescannte PDFs benötigen zuerst OCR, oder du legst das Rezept manuell an.',
    ),
    PdfImportFailure.unavailable => tr(
      'PDF import is unavailable on this device.',
      'PDF-Import ist auf diesem Gerät nicht verfügbar.',
    ),
    PdfImportFailure.invalidPdf => tr(
      'This PDF could not be read. Try exporting it again.',
      'Dieses PDF konnte nicht gelesen werden. Bitte erneut exportieren.',
    ),
  };

  Future<void> _edit(PdfRecipeImport entry) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PersonalRecipeEditorScreen(
          recipe: entry.recipe,
          importing: true,
          importSourceText: entry.sourceText,
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(
        () => _entries = _entries.where((e) => !identical(e, entry)).toList(),
      );
      if (_entries.isEmpty) Navigator.of(context).pop();
    }
  }
}
