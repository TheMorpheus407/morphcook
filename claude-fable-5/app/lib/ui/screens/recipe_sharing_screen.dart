import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/local_file_bytes.dart';
import '../../logic/sharing/native_recipe_share.dart';
import '../../logic/sharing/recipe_share.dart';
import '../../models/personal_recipe.dart';
import '../strings.dart';

/// Explicit sharing and previewed imports of portable recipe files.
class RecipeSharingScreen extends StatefulWidget {
  final String? recipeId;
  final Future<void> Function(Uint8List, String, Rect)? shareFiles;
  final Future<Uint8List?> Function()? pickBytes;

  const RecipeSharingScreen({
    super.key,
    this.recipeId,
    this.shareFiles,
    this.pickBytes,
  });

  @override
  State<RecipeSharingScreen> createState() => _RecipeSharingScreenState();
}

class _RecipeSharingScreenState extends State<RecipeSharingScreen> {
  bool _includeImages = false;
  bool _busy = false;
  bool _importing = false;
  RecipeShareData? _preview;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final photoBytes =
        _preview?.images.fold<int>(
          0,
          (total, image) => total + image.bytes.length,
        ) ??
        0;
    return PopScope(
      canPop: !_importing,
      child: Scaffold(
        appBar: AppBar(title: Text(s('recipeSharingTitle'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(s('shareCookbookHint')),
            SwitchListTile(
              key: const ValueKey('share-recipe-photos'),
              contentPadding: EdgeInsets.zero,
              title: Text(s('sharePhotos')),
              subtitle: Text(s('sharePhotosHint')),
              value: _includeImages,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _includeImages = value),
            ),
            if (widget.recipeId != null)
              FilledButton.icon(
                key: const ValueKey('share-selected-recipe'),
                onPressed: _busy
                    ? null
                    : () => _share(state, s, recipeId: widget.recipeId),
                icon: const Icon(Icons.share_outlined),
                label: Text(s('shareRecipe')),
              ),
            OutlinedButton.icon(
              key: const ValueKey('share-cookbook'),
              onPressed: _busy ? null : () => _share(state, s),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(s('shareCookbook')),
            ),
            const SizedBox(height: 24),
            Text(s('sharedImportHint')),
            OutlinedButton.icon(
              key: const ValueKey('pick-shared-recipes'),
              onPressed: _busy ? null : () => _pick(s),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(s('importSharedFile')),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _message!,
                  key: const ValueKey('recipe-share-message'),
                ),
              ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text(
                '${s('sharedImportPreview')}: ${_preview!.recipes.length}',
                key: const ValueKey('shared-recipes-preview'),
              ),
              Text(
                '${s('sharedPhotoPreview')}: ${_preview!.images.length} '
                '(${(photoBytes / 1000000).toStringAsFixed(1)} MB)',
                key: const ValueKey('shared-photos-preview'),
              ),
              for (final recipe in _preview!.recipes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(recipe.title),
                ),
              FilledButton(
                key: const ValueKey('confirm-shared-recipes'),
                onPressed: _busy ? null : () => _import(state, s),
                child: Text(s('confirmSharedImport')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _share(AppState state, S s, {String? recipeId}) async {
    if (_busy) return;
    final renderBox = context.findRenderObject();
    final origin = renderBox is RenderBox && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await collectRecipeShare(
        state,
        recipeId: recipeId,
        includeImages: _includeImages,
      );
      if (!mounted) return;
      final bytes = encodeRecipeShare(data);
      final readable = recipeShareText(data, lang: state.lang);
      final share = widget.shareFiles;
      if (share != null) {
        await share(bytes, readable, origin);
      } else {
        await shareRecipeFiles(
          jsonBytes: bytes,
          text: readable,
          sharePositionOrigin: origin,
        );
      }
    } on RecipeShareException catch (error) {
      if (mounted) {
        setState(
          () => _message = s(
            error.failure == RecipeShareFailure.empty
                ? 'shareEmpty'
                : 'shareFailed',
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = s('shareFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(S s) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await (widget.pickBytes ?? _pickFromDevice)();
      if (bytes == null || !mounted) return;
      final data = decodeRecipeShare(bytes);
      setState(() => _preview = data);
    } on LocalFileTooLargeException {
      if (mounted) {
        setState(() {
          _preview = null;
          _message = s('sharedImportTooLarge');
        });
      }
    } on RecipeShareException catch (error) {
      if (mounted) {
        setState(() {
          _preview = null;
          _message = s(
            error.failure == RecipeShareFailure.tooLarge
                ? 'sharedImportTooLarge'
                : 'sharedImportFailed',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preview = null;
          _message = s('sharedImportFailed');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _pickFromDevice() => withMorphCookShareFiles(() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      final file = result?.files.firstOrNull;
      if (file == null) return null;
      return await readPickedFileBytes(file, maxBytes: maxRecipeShareBytes);
    } finally {
      await clearPickerTemporaryFiles();
    }
  });

  Future<void> _import(AppState state, S s) async {
    final data = _preview;
    if (_busy || data == null) return;
    setState(() {
      _busy = true;
      _importing = true;
      _message = null;
    });
    try {
      final count = await state.importSharedRecipes(data);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _message = count == 0
            ? s('sharedImportAlreadyPresent')
            : '${s('sharedImportSuccess')}: $count';
      });
    } on PersonalRecipeLimitException catch (error) {
      if (mounted) {
        setState(
          () => _message = s(
            error.reason == PersonalRecipeLimitReason.count
                ? 'personalRecipeLimit'
                : 'personalRecipeBackupLimit',
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = s('sharedImportFailed'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _importing = false;
        });
      }
    }
  }
}
