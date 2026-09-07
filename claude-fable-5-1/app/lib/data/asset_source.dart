import 'dart:io';

/// Where bundled assets come from. The app uses the root bundle; tests and
/// the build tool read straight from disk.
abstract class AssetSource {
  Future<String> loadString(String path);
}

class FileAssetSource implements AssetSource {
  const FileAssetSource(this.root);
  final String root;

  @override
  Future<String> loadString(String path) => File('$root/$path').readAsString();
}

class MapAssetSource implements AssetSource {
  const MapAssetSource(this.files);
  final Map<String, String> files;

  @override
  Future<String> loadString(String path) async {
    final f = files[path];
    if (f == null) throw StateError('missing asset $path');
    return f;
  }
}
