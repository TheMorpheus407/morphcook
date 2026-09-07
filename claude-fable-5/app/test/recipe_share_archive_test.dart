import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/sharing/recipe_share_archive.dart';

const _jsonName = 'morphcook-recipes.json';
final _json = utf8.encode('{"format":"morphcook-recipes","recipes":[]}');

Uint8List _decode(List<int> bytes, {int maxBytes = 4096}) =>
    decodeRecipeShareArchive(bytes, maxBytes: maxBytes);

void main() {
  test('native stored ZIP and recompressed deflate ZIP return recipe JSON', () {
    for (final level in [0, 6]) {
      final archive = Archive()
        ..add(ArchiveFile(_jsonName, _json.length, _json))
        ..add(ArchiveFile.string('recipes.txt', 'Recipes for friends.'));
      final bytes = ZipEncoder().encodeBytes(archive, level: level);
      expect(_decode(bytes), orderedEquals(_json));
    }
  });

  test('supports conventional signed and unsigned data descriptors', () {
    for (final method in [0, 8]) {
      for (final signed in [false, true]) {
        final bytes = _zip([
          _Entry(
            _jsonName,
            _json,
            method: method,
            descriptor: true,
            descriptorSignature: signed,
          ),
        ]);
        expect(_decode(bytes), orderedEquals(_json));
      }
    }
  });

  test('does not require central directory to use local entry order', () {
    final bytes = _zip([
      _Entry('recipes.txt', utf8.encode('A readable copy')),
      _Entry(_jsonName, _json),
    ], reverseDirectory: true);
    expect(_decode(bytes), orderedEquals(_json));
  });

  test(
    'bounds raw input, entry count and declared per-file/total expansion',
    () {
      expect(() => _decode(Uint8List(4097)), throwsFormatException);
      for (final count in [0, 3, 65535]) {
        final bytes = _zip([_Entry(_jsonName, _json)]);
        _set16(bytes, bytes.length - 22 + 8, count);
        _set16(bytes, bytes.length - 22 + 10, count);
        expect(() => _decode(bytes), throwsFormatException);
      }
      for (final name in [_jsonName, 'recipes.txt']) {
        final files = [
          if (name != _jsonName) _Entry(_jsonName, _json),
          _Entry(name, [1], method: 8, declaredSize: 4097),
        ];
        expect(() => _decode(_zip(files)), throwsFormatException);
      }
      final two = _zip([
        _Entry(_jsonName, List.filled(700, 32), method: 8),
        _Entry('recipes.txt', List.filled(700, 32), method: 8),
      ]);
      expect(two.length, lessThan(1024));
      expect(() => _decode(two, maxBytes: 1024), throwsFormatException);
    },
  );

  test('actual decompression is bounded even when both headers lie', () {
    // The compressed source fits the raw input limit, while actual expansion
    // is 256 times larger. Both local and central headers falsely claim 16 B.
    final bomb = _zip([
      _Entry(
        _jsonName,
        List.filled(1024 * 1024, 65),
        method: 8,
        declaredSize: 16,
      ),
    ]);
    expect(bomb.length, lessThan(4096));
    expect(
      () => _decode(bomb),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('declared size'),
        ),
      ),
    );
    // The optional human-readable file must not bypass validation either.
    final textBomb = _zip([
      _Entry(_jsonName, _json),
      _Entry(
        'recipes.txt',
        List.filled(1024 * 1024, 65),
        method: 8,
        declaredSize: 16,
      ),
    ]);
    expect(() => _decode(textBomb), throwsFormatException);
    expect(_decode(_zip([_Entry(_jsonName, _json)])), orderedEquals(_json));
  });

  test('rejects mismatched actual sizes and CRC on either file', () {
    expect(
      () => _decode(
        _zip([
          _Entry(_jsonName, _json, method: 8, declaredSize: _json.length + 1),
        ]),
      ),
      throwsFormatException,
    );
    for (final name in [_jsonName, 'recipes.txt']) {
      final files = [
        if (name != _jsonName) _Entry(_jsonName, _json),
        _Entry(name, _json, crcOverride: 123),
      ];
      expect(() => _decode(_zip(files)), throwsFormatException);
    }
  });

  test('rejects every truncated prefix and malformed deflate', () {
    final bytes = _zip([_Entry(_jsonName, _json)]);
    for (var end = 0; end < bytes.length; end++) {
      expect(
        () => _decode(bytes.sublist(0, end)),
        throwsFormatException,
        reason: 'prefix ending at $end',
      );
    }
    for (final payload in [
      <int>[],
      [3],
      [255, 255, 255],
    ]) {
      expect(
        () => _decode(
          _zip([
            _Entry(
              _jsonName,
              const [1],
              method: 8,
              compressedOverride: payload,
            ),
          ]),
        ),
        throwsFormatException,
      );
    }
  });

  test('JSON cannot be empty, while an optional readable file can be', () {
    for (final method in [0, 8]) {
      expect(
        () => _decode(_zip([_Entry(_jsonName, const [], method: method)])),
        throwsFormatException,
      );
      final bytes = _zip([
        _Entry(_jsonName, _json, method: method),
        _Entry('recipes.txt', const [], method: method),
      ]);
      expect(_decode(bytes), orderedEquals(_json));
    }
  });

  test('rejects missing JSON, duplicates, unknown files and unsafe paths', () {
    for (final files in [
      [_Entry('recipes.txt', _json)],
      [_Entry(_jsonName, _json), _Entry(_jsonName, _json)],
      for (final name in [
        '../morphcook-recipes.json',
        '/morphcook-recipes.json',
        r'folder\morphcook-recipes.json',
        'folder/morphcook-recipes.json',
        'morphcook-recipes.json/',
        'other.json',
      ])
        [_Entry(name, _json)],
    ]) {
      expect(() => _decode(_zip(files)), throwsFormatException);
    }
  });

  test('rejects encrypted, ZIP64, unsupported methods and special files', () {
    for (final entry in [
      _Entry(_jsonName, _json, flags: 0x801),
      _Entry(_jsonName, _json, flags: 0x840),
      _Entry(_jsonName, _json, version: 45),
      _Entry(_jsonName, _json, method: 12),
      _Entry(_jsonName, _json, attributes: 0xa1ff << 16),
      _Entry(_jsonName, _json, attributes: 0x10),
      _Entry(_jsonName, _json, extra: [1, 0, 0, 0]),
      _Entry(_jsonName, _json, extra: [1, 0x99, 0, 0]),
      _Entry(_jsonName, _json, extra: [2, 0, 255, 255]),
    ]) {
      expect(() => _decode(_zip([entry])), throwsFormatException);
    }
    final split = _zip([_Entry(_jsonName, _json)]);
    _set16(split, split.length - 22 + 4, 1);
    expect(() => _decode(split), throwsFormatException);
  });

  test(
    'rejects inconsistent headers, descriptors and overlapping file ranges',
    () {
      final original = _zip([_Entry(_jsonName, _json)]);
      for (final (offset, width, value) in [
        (8, 2, 8), // Local method disagrees with central method.
        (22, 4, _json.length + 1),
        (30, 2, 0x7878), // Different local filename.
        (_centralOffset(original) + 42, 4, 1),
        (original.length - 22 + 12, 4, 0xffffffff),
        (original.length - 22 + 16, 4, 0xffffffff),
      ]) {
        final bytes = Uint8List.fromList(original);
        if (width == 2) {
          _set16(bytes, offset, value);
        } else {
          _set32(bytes, offset, value);
        }
        expect(() => _decode(bytes), throwsFormatException);
      }
      final descriptor = _zip([_Entry(_jsonName, _json, descriptor: true)]);
      _set32(descriptor, _centralOffset(descriptor) - 4, _json.length + 1);
      expect(() => _decode(descriptor), throwsFormatException);
      final overlap = _zip([
        _Entry(_jsonName, _json),
        _Entry('recipes.txt', _json),
      ]);
      final secondHeader = _centralOffset(overlap) + 46 + _jsonName.length;
      _set32(overlap, secondHeader + 42, 0);
      expect(() => _decode(overlap), throwsFormatException);
      expect(() => _decode([...original, 0]), throwsFormatException);
    },
  );
}

class _Entry {
  final String name;
  final List<int> bytes;
  final int method;
  final int? declaredSize;
  final int? crcOverride;
  final int flags;
  final int version;
  final int attributes;
  final List<int> extra;
  final bool descriptor;
  final bool descriptorSignature;
  final List<int>? compressedOverride;

  _Entry(
    this.name,
    this.bytes, {
    this.method = 0,
    this.declaredSize,
    this.crcOverride,
    this.flags = 0x800,
    this.version = 20,
    this.attributes = 0,
    this.extra = const [],
    this.descriptor = false,
    this.descriptorSignature = true,
    this.compressedOverride,
  });
}

// Independent ZIP fixture writer: permits malformed headers and duplicate
// names that Archive's higher-level builder normalizes away.
Uint8List _zip(List<_Entry> files, {bool reverseDirectory = false}) {
  final output = BytesBuilder();
  final directory = <List<int>>[];
  for (final file in files) {
    final offset = output.length;
    final name = utf8.encode(file.name);
    final compressed =
        file.compressedOverride ??
        (file.method == 8
            ? io.ZLibEncoder(raw: true).convert(file.bytes)
            : file.bytes);
    final size = file.declaredSize ?? file.bytes.length;
    final crc = file.crcOverride ?? getCrc32(file.bytes);
    final flags = file.flags | (file.descriptor ? 8 : 0);
    output.add([
      ..._u32(0x04034b50),
      ..._u16(file.version),
      ..._u16(flags),
      ..._u16(file.method),
      ..._u16(0),
      ..._u16(0),
      ..._u32(file.descriptor ? 0 : crc),
      ..._u32(file.descriptor ? 0 : compressed.length),
      ..._u32(file.descriptor ? 0 : size),
      ..._u16(name.length),
      ..._u16(file.extra.length),
      ...name,
      ...file.extra,
      ...compressed,
      if (file.descriptor) ...[
        if (file.descriptorSignature) ..._u32(0x08074b50),
        ..._u32(crc),
        ..._u32(compressed.length),
        ..._u32(size),
      ],
    ]);
    directory.add([
      ..._u32(0x02014b50),
      ..._u16(20),
      ..._u16(file.version),
      ..._u16(flags),
      ..._u16(file.method),
      ..._u16(0),
      ..._u16(0),
      ..._u32(crc),
      ..._u32(compressed.length),
      ..._u32(size),
      ..._u16(name.length),
      ..._u16(file.extra.length),
      ..._u16(0),
      ..._u16(0),
      ..._u16(0),
      ..._u32(file.attributes),
      ..._u32(offset),
      ...name,
      ...file.extra,
    ]);
  }
  final directoryOffset = output.length;
  for (final entry in reverseDirectory ? directory.reversed : directory) {
    output.add(entry);
  }
  final directorySize = output.length - directoryOffset;
  output.add([
    ..._u32(0x06054b50),
    ..._u16(0),
    ..._u16(0),
    ..._u16(files.length),
    ..._u16(files.length),
    ..._u32(directorySize),
    ..._u32(directoryOffset),
    ..._u16(0),
  ]);
  return output.takeBytes();
}

List<int> _u16(int value) => [value & 255, (value >> 8) & 255];
List<int> _u32(int value) => [..._u16(value), ..._u16(value >> 16)];
int _centralOffset(Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint32(bytes.length - 6, Endian.little);
void _set16(Uint8List bytes, int offset, int value) =>
    ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
void _set32(Uint8List bytes, int offset, int value) =>
    ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
