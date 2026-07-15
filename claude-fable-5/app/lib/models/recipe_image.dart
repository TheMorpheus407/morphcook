import 'dart:convert';
import 'dart:typed_data';

const maxRecipeImageBytes = 8 * 1024 * 1024;
const maxBackupRecipeImages = 100;
// Keep portable, base64-backed exports within a mobile-safe memory envelope.
const maxBackupImageBytes = 20 * 1024 * 1024;
const maxRecipeImagePixels = 120 * 1000 * 1000;
const maxRecipeImageDimension = 30000;

enum RecipeImageFailure {
  invalidRecipeId,
  unsupportedType,
  tooLarge,
  dimensionsTooLarge,
  storageLimit,
}

class RecipeImageException implements Exception {
  final RecipeImageFailure failure;

  const RecipeImageException(this.failure);

  @override
  String toString() => 'RecipeImageException: ${failure.name}';
}

/// Metadata stored in the regular JSON collection; bytes live separately in
/// app-private binary storage to avoid base64 overhead during normal use.
class RecipeImageMetadata {
  final String recipeId;
  final String mimeType;
  final DateTime updatedAt;

  const RecipeImageMetadata({
    required this.recipeId,
    required this.mimeType,
    required this.updatedAt,
  });

  factory RecipeImageMetadata.fromJson(Map<String, dynamic> json) =>
      RecipeImageMetadata(
        recipeId: json['recipe_id'] as String,
        mimeType: json['mime_type'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'mime_type': mimeType,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

/// A local photo override for either a bundled or personal recipe.
class RecipeImage {
  final String recipeId;
  final String mimeType;
  final Uint8List bytes;
  final DateTime updatedAt;

  RecipeImage._({
    required this.recipeId,
    required this.mimeType,
    required this.bytes,
    required this.updatedAt,
  });

  factory RecipeImage({
    required String recipeId,
    required List<int> bytes,
    String? mimeType,
    required DateTime updatedAt,
  }) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,200}$').hasMatch(recipeId)) {
      throw const RecipeImageException(RecipeImageFailure.invalidRecipeId);
    }
    if (bytes.length > maxRecipeImageBytes) {
      throw const RecipeImageException(RecipeImageFailure.tooLarge);
    }
    final copy = Uint8List.fromList(bytes);
    final detected = detectRecipeImageMimeType(copy);
    final dimensions = readRecipeImageDimensions(copy, detected);
    if (detected == null ||
        dimensions == null ||
        (mimeType != null && mimeType != detected)) {
      throw const RecipeImageException(RecipeImageFailure.unsupportedType);
    }
    if (dimensions.width > maxRecipeImageDimension ||
        dimensions.height > maxRecipeImageDimension ||
        dimensions.width * dimensions.height > maxRecipeImagePixels) {
      throw const RecipeImageException(RecipeImageFailure.dimensionsTooLarge);
    }
    return RecipeImage._(
      recipeId: recipeId,
      mimeType: detected,
      bytes: copy.asUnmodifiableView(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  factory RecipeImage.fromStored(
    RecipeImageMetadata metadata,
    List<int> bytes,
  ) => RecipeImage(
    recipeId: metadata.recipeId,
    mimeType: metadata.mimeType,
    bytes: bytes,
    updatedAt: metadata.updatedAt,
  );

  factory RecipeImage.fromBackupJson(Map<String, dynamic> json) {
    final encoded = json['data_base64'] as String;
    // Reject unreasonable strings before allocating decoded bytes.
    if (encoded.length > ((maxRecipeImageBytes + 2) ~/ 3) * 4 + 4) {
      throw const RecipeImageException(RecipeImageFailure.tooLarge);
    }
    return RecipeImage(
      recipeId: json['recipe_id'] as String,
      mimeType: json['mime_type'] as String,
      bytes: base64Decode(encoded),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  RecipeImageMetadata get metadata => RecipeImageMetadata(
    recipeId: recipeId,
    mimeType: mimeType,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toBackupJson() => {
    ...metadata.toJson(),
    'data_base64': base64Encode(bytes),
  };
}

class RecipeImageDimensions {
  final int width;
  final int height;

  const RecipeImageDimensions(this.width, this.height);
}

/// Content sniffing intentionally ignores picker-provided names/extensions.
/// Flutter decodes these three formats consistently on both target platforms.
String? detectRecipeImageMimeType(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Reads dimensions without decoding the bitmap. This rejects truncated files
/// and compressed dimension bombs before Flutter's platform codec sees them.
RecipeImageDimensions? readRecipeImageDimensions(
  List<int> bytes, [
  String? mimeType,
]) {
  final type = mimeType ?? detectRecipeImageMimeType(bytes);
  return switch (type) {
    'image/png' => _pngDimensions(bytes),
    'image/jpeg' => _jpegDimensions(bytes),
    'image/webp' => _webpDimensions(bytes),
    _ => null,
  };
}

RecipeImageDimensions? _pngDimensions(List<int> bytes) {
  if (bytes.length < 45) return null;
  RecipeImageDimensions? dimensions;
  var hasImageData = false;
  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final chunkLength = _uint32Be(bytes, offset);
    final dataStart = offset + 8;
    final dataEnd = dataStart + chunkLength;
    if (dataEnd + 4 > bytes.length) return null;
    final chunkType = String.fromCharCodes(
      bytes.sublist(offset + 4, offset + 8),
    );
    if (offset == 8) {
      if (chunkType != 'IHDR' || chunkLength != 13) return null;
      dimensions = _positiveDimensions(
        _uint32Be(bytes, dataStart),
        _uint32Be(bytes, dataStart + 4),
      );
      if (dimensions == null) return null;
    } else if (chunkType == 'IDAT') {
      hasImageData = true;
    } else if (chunkType == 'IEND') {
      return chunkLength == 0 && hasImageData ? dimensions : null;
    }
    offset = dataEnd + 4;
  }
  return null;
}

RecipeImageDimensions? _jpegDimensions(List<int> bytes) {
  var offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) return null;
    final marker = bytes[offset++];
    if (marker == 0xD8 || marker == 0xD9 || marker == 0x01) continue;
    if (marker >= 0xD0 && marker <= 0xD7) continue;
    if (offset + 1 >= bytes.length) return null;
    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) {
      return null;
    }
    if (_jpegStartOfFrameMarkers.contains(marker)) {
      if (segmentLength < 7) return null;
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      final dimensions = _positiveDimensions(width, height);
      if (dimensions == null) return null;
      var hasScan = false;
      for (var i = offset + segmentLength; i + 1 < bytes.length; i++) {
        if (bytes[i] != 0xFF) continue;
        if (bytes[i + 1] == 0xDA) hasScan = true;
        if (bytes[i + 1] == 0xD9) return hasScan ? dimensions : null;
      }
      return null;
    }
    offset += segmentLength;
  }
  return null;
}

const _jpegStartOfFrameMarkers = {
  0xC0,
  0xC1,
  0xC2,
  0xC3,
  0xC5,
  0xC6,
  0xC7,
  0xC9,
  0xCA,
  0xCB,
  0xCD,
  0xCE,
  0xCF,
};

RecipeImageDimensions? _webpDimensions(List<int> bytes) {
  if (bytes.length < 25) return null;
  final riffEnd = 8 + _uint32Le(bytes, 4);
  if (riffEnd > bytes.length || riffEnd < 20) return null;
  RecipeImageDimensions? dimensions;
  var hasImagePayload = false;
  var offset = 12;
  while (offset + 8 <= riffEnd) {
    final chunk = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkLength = _uint32Le(bytes, offset + 4);
    final dataStart = offset + 8;
    final dataEnd = dataStart + chunkLength;
    final paddedEnd = dataEnd + (chunkLength.isOdd ? 1 : 0);
    if (dataEnd > riffEnd || paddedEnd > riffEnd) return null;

    if (chunk == 'VP8X' && chunkLength >= 10) {
      dimensions = _positiveDimensions(
        1 + _uint24Le(bytes, dataStart + 4),
        1 + _uint24Le(bytes, dataStart + 7),
      );
    } else if (chunk == 'VP8 ' &&
        chunkLength >= 10 &&
        bytes[dataStart + 3] == 0x9D &&
        bytes[dataStart + 4] == 0x01 &&
        bytes[dataStart + 5] == 0x2A) {
      dimensions ??= _positiveDimensions(
        (bytes[dataStart + 6] | (bytes[dataStart + 7] << 8)) & 0x3FFF,
        (bytes[dataStart + 8] | (bytes[dataStart + 9] << 8)) & 0x3FFF,
      );
      hasImagePayload = true;
    } else if (chunk == 'VP8L' &&
        chunkLength >= 5 &&
        bytes[dataStart] == 0x2F) {
      dimensions ??= _positiveDimensions(
        1 + (bytes[dataStart + 1] | ((bytes[dataStart + 2] & 0x3F) << 8)),
        1 +
            ((bytes[dataStart + 2] >> 6) |
                (bytes[dataStart + 3] << 2) |
                ((bytes[dataStart + 4] & 0x0F) << 10)),
      );
      hasImagePayload = true;
    } else if (chunk == 'ANMF' && chunkLength >= 16) {
      hasImagePayload = true;
    }
    offset = paddedEnd;
  }
  return offset == riffEnd && hasImagePayload ? dimensions : null;
}

RecipeImageDimensions? _positiveDimensions(int width, int height) =>
    width > 0 && height > 0 ? RecipeImageDimensions(width, height) : null;

int _uint24Le(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

int _uint32Be(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _uint32Le(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
