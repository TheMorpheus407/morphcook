import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/import/website_recipe_import.dart';
import '../strings.dart';
import 'personal_recipe_editor_screen.dart';

/// Loading a URL is explicit; opening the cookbook never contacts a website.
class WebsiteImportScreen extends StatefulWidget {
  final WebsiteRecipeImporter? importer;
  const WebsiteImportScreen({super.key, this.importer});

  @override
  State<WebsiteImportScreen> createState() => _WebsiteImportScreenState();
}

class _WebsiteImportScreenState extends State<WebsiteImportScreen> {
  final _url = TextEditingController();
  late final _importer = widget.importer ?? WebsiteRecipeImporter();
  List<WebsiteRecipeImport> _recipes = [];
  bool _busy = false;
  bool _photo = false;
  String? _errorKey;
  WebsiteRecipeImport? _photoFailed;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s('importWebsite'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s('importWebsiteHint')),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('website-url'),
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: s('recipeUrl')),
          ),
          FilledButton(
            key: const ValueKey('fetch-website-recipe'),
            onPressed: _busy ? null : _fetch,
            child: Text(s('fetchRecipe')),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_errorKey != null)
            Text(s(_errorKey!), key: const ValueKey('website-error')),
          if (_photoFailed != null)
            TextButton(
              onPressed: _busy ? null : () => _edit(_photoFailed!),
              child: Text(s('importWithoutPhoto')),
            ),
          if (_recipes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s('importReviewHint')),
            SwitchListTile(
              key: const ValueKey('download-website-photo'),
              value: _photo,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _photo = value),
              title: Text(s('importPhoto')),
              subtitle: Text(s('importPhotoHint')),
            ),
            for (final entry in _recipes)
              ListTile(
                title: Text(entry.recipe.title),
                subtitle: Text(s('reviewRecipe')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy ? null : () => _review(entry),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetch() async {
    setState(() {
      _busy = true;
      _errorKey = null;
      _photoFailed = null;
      _recipes = [];
    });
    try {
      final result = await _importer.fetch(Uri.parse(_url.text.trim()));
      if (mounted) setState(() => _recipes = result);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'importFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(WebsiteRecipeImport entry) async {
    setState(() {
      _busy = true;
      _errorKey = null;
      _photoFailed = null;
    });
    Uint8List? bytes;
    try {
      if (_photo && entry.imageUrl != null) {
        bytes = await _importer.fetchImage(entry.imageUrl!);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorKey = 'importPhotoDownloadFailed';
          _photoFailed = entry;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _edit(entry, bytes);
  }

  Future<void> _edit(WebsiteRecipeImport entry, [Uint8List? bytes]) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PersonalRecipeEditorScreen(
          recipe: entry.recipe,
          importing: true,
          importImage: bytes,
        ),
      ),
    );
    if (saved != null && mounted) Navigator.of(context).pop();
  }
}
