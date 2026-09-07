// Platform file I/O (share sheet out, file picker in) behind an interface
// so the backup flow can be tested without plugins.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SharedFile {
  const SharedFile({required this.name, required this.bytes, this.mimeType = 'application/octet-stream'});
  final String name;
  final Uint8List bytes;
  final String mimeType;
}

class PickedFile {
  const PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class FileGatewayException implements Exception {
  const FileGatewayException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class FileGateway {
  /// Hands the files to the OS share sheet; the user picks where they go.
  Future<void> shareFiles(List<SharedFile> files, {String? text});

  /// Lets the user pick one file; null when they cancel.
  Future<PickedFile?> pickFile();

  static FileGateway instance = PlatformFileGateway();
}

class PlatformFileGateway implements FileGateway {
  @override
  Future<void> shareFiles(List<SharedFile> files, {String? text}) async {
    try {
      final dir = await getTemporaryDirectory();
      final xfiles = <XFile>[];
      for (final f in files) {
        final file = File('${dir.path}${Platform.pathSeparator}${f.name}');
        await file.writeAsBytes(f.bytes, flush: true);
        xfiles.add(XFile(file.path, mimeType: f.mimeType, name: f.name));
      }
      await SharePlus.instance.share(ShareParams(files: xfiles, text: text));
    } catch (e) {
      throw FileGatewayException('could not open the share sheet ($e)');
    }
  }

  @override
  Future<PickedFile?> pickFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return null;
      final f = files.first;
      final bytes = await f.readAsBytes();
      return PickedFile(name: f.name, bytes: bytes);
    } on FileGatewayException {
      rethrow;
    } catch (e) {
      throw FileGatewayException('could not open the file picker ($e)');
    }
  }
}
