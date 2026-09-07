import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/recipe_share.dart';
import '../local_file_bytes.dart';

bool _shareInFlight = false;

/// Hands one ZIP containing portable recipes and readable text to the OS.
/// The OS offers installed destinations such as Bluetooth and Quick Share.
Future<void> shareRecipeFiles({
  required Uint8List jsonBytes,
  required String text,
  required Rect sharePositionOrigin,
  Directory? temporaryDirectory,
  Future<ShareResult> Function(ShareParams)? invokeShare,
}) async {
  if (_shareInFlight) throw StateError('A recipe share is already in progress');
  _shareInFlight = true;
  try {
    await withMorphCookShareFiles(() async {
      final textBytes = utf8.encode(text);
      if (jsonBytes.length + textBytes.length > maxRecipeShareBytes) {
        throw const RecipeShareException(RecipeShareFailure.tooLarge);
      }
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('morphcook-recipes.json', jsonBytes))
        ..addFile(ArchiveFile.bytes('recipes.txt', textBytes));
      final zipBytes = ZipEncoder().encodeBytes(archive, level: 0);
      if (zipBytes.length > maxRecipeShareBytes) {
        throw const RecipeShareException(RecipeShareFailure.tooLarge);
      }
      Directory? export;
      try {
        final temporary = temporaryDirectory ?? await getTemporaryDirectory();
        export = await temporary.createTemp('morphcook-export-');
        final zipFile = File('${export.path}/morphcook-recipes.zip');
        await zipFile.writeAsBytes(zipBytes, flush: true);
        await (invokeShare ?? SharePlus.instance.share)(
          ShareParams(
            // Bluetooth accepts a single application/zip attachment. Sending
            // separate JSON/text files hides it on many Android devices.
            files: [XFile(zipFile.path, mimeType: 'application/zip')],
            subject: 'MorphCook recipes',
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      } finally {
        // share_plus retains its own Android cache copy for the receiving app.
        // Only our source files are removed here; clearing that cache now could
        // interrupt a transfer after the user has chosen its destination.
        try {
          await export?.delete(recursive: true);
        } catch (_) {
          // Existing cache cleanup can remove a stale source directory.
        }
      }
    });
  } finally {
    _shareInFlight = false;
  }
}
