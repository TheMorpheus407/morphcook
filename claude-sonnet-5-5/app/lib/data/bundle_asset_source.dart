import 'package:flutter/services.dart';

import 'asset_source.dart';

/// Reads corpus files from the Flutter asset bundle (`assets/<path>`).
class BundleAssetSource extends AssetSource {
  BundleAssetSource({AssetBundle? bundle, this.prefix = 'assets/'}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String prefix;

  @override
  Future<String> loadString(String path) => _bundle.loadString('$prefix$path', cache: false);
}
