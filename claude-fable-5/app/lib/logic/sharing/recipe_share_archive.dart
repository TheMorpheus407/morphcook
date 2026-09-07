import 'dart:io' show ZLibDecoder;
import 'dart:math' show min, max;
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

const _recipeFileName = 'morphcook-recipes.json';
const _readableFileName = 'recipes.txt';

/// Reads the recipe JSON from the portable cookbook ZIP without extracting
/// files. Both stored and deflated files are supported. Directory declarations
/// are checked before decoding; the output sink independently enforces the
/// actual decompressed size, including for dishonest compressed archives.
Uint8List decodeRecipeShareArchive(List<int> bytes, {required int maxBytes}) {
  if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  if (bytes.length > maxBytes || bytes.length < 22) {
    throw const FormatException('Invalid recipe archive size');
  }
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final reader = _ZipReader(data);
  final end = reader.endRecord();
  final count = reader.uint16(end + 10);
  final directorySize = reader.uint32(end + 12);
  final directoryOffset = reader.uint32(end + 16);
  if (reader.uint16(end + 4) != 0 ||
      reader.uint16(end + 6) != 0 ||
      reader.uint16(end + 8) != count ||
      count < 1 ||
      count > 2 ||
      directoryOffset + directorySize != end) {
    throw const FormatException('Unsupported recipe archive directory');
  }

  final entries = <_ZipEntry>[];
  final names = <String>{};
  var position = directoryOffset;
  var declaredTotal = 0;
  for (var i = 0; i < count; i++) {
    reader.range(position, 46, end);
    if (reader.uint32(position) != 0x02014b50) {
      throw const FormatException('Invalid recipe archive directory entry');
    }
    final version = reader.uint16(position + 6);
    final flags = reader.uint16(position + 8);
    final method = reader.uint16(position + 10);
    final crc = reader.uint32(position + 16);
    final compressedSize = reader.uint32(position + 20);
    final size = reader.uint32(position + 24);
    final nameLength = reader.uint16(position + 28);
    final extraLength = reader.uint16(position + 30);
    final commentLength = reader.uint16(position + 32);
    final disk = reader.uint16(position + 34);
    final attributes = reader.uint32(position + 38);
    final offset = reader.uint32(position + 42);
    final next = position + 46 + nameLength + extraLength + commentLength;
    reader.range(position, next - position, end);
    final name = reader.fileName(position + 46, nameLength);
    final fileType = (attributes >> 16) & 0xf000;
    // Reject encryption, unsupported compression, ZIP64, directories, links,
    // special files, duplicates and anything outside our two root filenames.
    if (version > 20 ||
        (flags & ~0x080e) != 0 ||
        (method != 0 && method != 8) ||
        disk != 0 ||
        (attributes & 0x10) != 0 ||
        (fileType != 0 && fileType != 0x8000) ||
        !names.add(name) ||
        (name == _recipeFileName && size == 0) ||
        size > maxBytes ||
        compressedSize > maxBytes ||
        offset >= directoryOffset) {
      throw const FormatException('Unsupported recipe archive entry');
    }
    declaredTotal += size;
    if (declaredTotal > maxBytes) {
      throw const FormatException('Recipe archive expands beyond the limit');
    }
    reader.extraFields(position + 46 + nameLength, extraLength);
    final entry = reader.localEntry(
      name: name,
      offset: offset,
      directoryOffset: directoryOffset,
      version: version,
      flags: flags,
      method: method,
      crc: crc,
      compressedSize: compressedSize,
      size: size,
    );
    entries.add(entry);
    position = next;
  }
  if (position != end || !names.contains(_recipeFileName)) {
    throw const FormatException('Recipe JSON is missing from the archive');
  }
  // No overlapping entries, hidden files, executable prefix or trailing
  // records. Central-directory order itself need not match local-file order.
  entries.sort((a, b) => a.offset.compareTo(b.offset));
  position = 0;
  for (final entry in entries) {
    if (entry.offset != position) {
      throw const FormatException('Invalid recipe archive file boundaries');
    }
    position = entry.end;
  }
  if (position != directoryOffset) {
    throw const FormatException('Invalid recipe archive directory boundary');
  }

  Uint8List? json;
  for (final entry in entries) {
    final output = _BoundedFileSink(
      entry.size,
      retain: entry.name == _recipeFileName,
    );
    final payload = Uint8List.sublistView(
      data,
      entry.dataOffset,
      entry.dataOffset + entry.compressedSize,
    );
    if (entry.method == 0) {
      output.add(payload);
      output.close();
    } else {
      // The native decoder produces bounded chunks. Never use convert(),
      // which would accumulate the entire expansion before a size check.
      final decoder = ZLibDecoder(raw: true).startChunkedConversion(output);
      for (var start = 0; start < payload.length; start += 65536) {
        decoder.addSlice(
          payload,
          start,
          min(start + 65536, payload.length),
          false,
        );
      }
      decoder.close();
    }
    if (output.length != entry.size || output.crc != entry.crc) {
      throw const FormatException('Recipe archive size or checksum mismatch');
    }
    if (entry.name == _recipeFileName) json = output.takeBytes();
  }
  return json!;
}

class _ZipReader {
  final Uint8List bytes;
  late final ByteData data = ByteData.sublistView(bytes);

  _ZipReader(this.bytes);

  int uint16(int offset) => data.getUint16(offset, Endian.little);
  int uint32(int offset) => data.getUint32(offset, Endian.little);

  void range(int offset, int length, int limit) {
    if (offset < 0 ||
        length < 0 ||
        offset + length > limit ||
        limit > bytes.length) {
      throw const FormatException('Truncated recipe archive');
    }
  }

  int endRecord() {
    // ZIP comments are at most 65535 bytes. Require the record's comment to
    // end exactly at EOF instead of mistaking a signature inside data for EOCD.
    for (
      var offset = bytes.length - 22;
      offset >= max(0, bytes.length - 22 - 65535);
      offset--
    ) {
      if (uint32(offset) == 0x06054b50 &&
          offset + 22 + uint16(offset + 20) == bytes.length) {
        return offset;
      }
    }
    throw const FormatException('Missing recipe archive directory');
  }

  String fileName(int offset, int length) {
    if (length != _recipeFileName.length &&
        length != _readableFileName.length) {
      throw const FormatException('Unsupported recipe archive filename');
    }
    final name = String.fromCharCodes(bytes, offset, offset + length);
    if (name != _recipeFileName && name != _readableFileName) {
      throw const FormatException('Unsupported recipe archive filename');
    }
    return name;
  }

  void extraFields(int offset, int length) {
    final end = offset + length;
    while (offset < end) {
      range(offset, 4, end);
      final type = uint16(offset);
      final size = uint16(offset + 2);
      if (type == 0x0001 || type == 0x9901) {
        throw const FormatException(
          'ZIP64 and encrypted archives are unsupported',
        );
      }
      offset += 4;
      range(offset, size, end);
      offset += size;
    }
  }

  _ZipEntry localEntry({
    required String name,
    required int offset,
    required int directoryOffset,
    required int version,
    required int flags,
    required int method,
    required int crc,
    required int compressedSize,
    required int size,
  }) {
    range(offset, 30, directoryOffset);
    final nameLength = uint16(offset + 26);
    final extraLength = uint16(offset + 28);
    final dataOffset = offset + 30 + nameLength + extraLength;
    range(offset, dataOffset - offset, directoryOffset);
    if (uint32(offset) != 0x04034b50 ||
        uint16(offset + 4) != version ||
        uint16(offset + 6) != flags ||
        uint16(offset + 8) != method ||
        fileName(offset + 30, nameLength) != name) {
      throw const FormatException('Recipe archive headers disagree');
    }
    extraFields(offset + 30 + nameLength, extraLength);
    final descriptor = (flags & 8) != 0;
    for (final (at, expected) in [
      (offset + 14, crc),
      (offset + 18, compressedSize),
      (offset + 22, size),
    ]) {
      final value = uint32(at);
      if (value != expected && (!descriptor || value != 0)) {
        throw const FormatException('Recipe archive headers disagree');
      }
    }
    if (method == 0 && compressedSize != size) {
      throw const FormatException('Invalid stored recipe archive size');
    }
    range(dataOffset, compressedSize, directoryOffset);
    var end = dataOffset + compressedSize;
    if (descriptor) {
      range(end, 12, directoryOffset);
      if (uint32(end) == 0x08074b50) {
        end += 4;
        range(end, 12, directoryOffset);
      }
      if (uint32(end) != crc ||
          uint32(end + 4) != compressedSize ||
          uint32(end + 8) != size) {
        throw const FormatException('Recipe archive descriptor disagrees');
      }
      end += 12;
    }
    return _ZipEntry(
      name,
      offset,
      dataOffset,
      end,
      method,
      compressedSize,
      size,
      crc,
    );
  }
}

class _ZipEntry {
  final String name;
  final int offset;
  final int dataOffset;
  final int end;
  final int method;
  final int compressedSize;
  final int size;
  final int crc;

  const _ZipEntry(
    this.name,
    this.offset,
    this.dataOffset,
    this.end,
    this.method,
    this.compressedSize,
    this.size,
    this.crc,
  );
}

class _BoundedFileSink implements Sink<List<int>> {
  final int limit;
  final BytesBuilder? _bytes;
  int length = 0;
  int crc = 0;

  _BoundedFileSink(this.limit, {required bool retain})
    : _bytes = retain ? BytesBuilder(copy: false) : null;

  @override
  void add(List<int> bytes) {
    if (length + bytes.length > limit) {
      throw const FormatException(
        'Recipe archive expands beyond its declared size',
      );
    }
    length += bytes.length;
    crc = getCrc32(bytes, crc);
    _bytes?.add(bytes);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _bytes!.takeBytes();
}
