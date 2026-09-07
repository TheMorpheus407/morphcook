import 'package:flutter/services.dart';

import 'asset_source.dart';

class BundleAssetSource implements AssetSource {
  const BundleAssetSource([this.bundle]);
  final AssetBundle? bundle;

  @override
  Future<String> loadString(String path) => (bundle ?? rootBundle).loadString(path, cache: false);
}
