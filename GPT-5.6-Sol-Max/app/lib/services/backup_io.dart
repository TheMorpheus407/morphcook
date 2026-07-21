import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service.dart';

class BackupIo {
  const BackupIo();

  Future<void> share(BackupBundle bundle) async {
    final directory = await getTemporaryDirectory();
    final jsonFile = File('${directory.path}/morphcook-backup.json');
    final gzipFile = File('${directory.path}/morphcook-backup.json.gz');
    await jsonFile.writeAsBytes(bundle.jsonBytes, flush: true);
    await gzipFile.writeAsBytes(bundle.gzipBytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(jsonFile.path), XFile(gzipFile.path)],
        subject: 'MorphCook backup',
      ),
    );
  }

  Future<List<int>?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'gz'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    return path == null ? null : File(path).readAsBytes();
  }
}
