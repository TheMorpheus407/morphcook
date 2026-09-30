import 'dart:convert';
import 'dart:io';

/// Where bundled corpus files come from. The app reads the Flutter asset
/// bundle, tests and build tools read the `assets/` folder from disk.
abstract class AssetSource {
  const AssetSource();

  Future<String> loadString(String path);

  Future<Map<String, dynamic>> loadJson(String path) async {
    return (jsonDecode(await loadString(path)) as Map).cast<String, dynamic>();
  }
}

/// Reads files below [rootPath] (normally `app/assets`).
class FileAssetSource extends AssetSource {
  const FileAssetSource(this.rootPath);

  final String rootPath;

  @override
  Future<String> loadString(String path) => File('$rootPath/$path').readAsString();
}

/// In-memory source for tests.
class MemoryAssetSource extends AssetSource {
  MemoryAssetSource(this.files);

  final Map<String, String> files;

  @override
  Future<String> loadString(String path) async {
    final content = files[path];
    if (content == null) throw FileSystemException('Missing asset', path);
    return content;
  }
}
