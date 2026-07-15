import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/recipe_image.dart';

import 'helpers.dart';

void main() {
  test('detects supported image formats from bytes, not filenames', () {
    expect(detectRecipeImageMimeType(testPngBytes()), 'image/png');
    expect(
      detectRecipeImageMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00])),
      'image/jpeg',
    );
    expect(
      detectRecipeImageMimeType(
        Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      'image/webp',
    );
    expect(detectRecipeImageMimeType(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('accepts complete JPEG and WebP files and reads their dimensions', () {
    final jpeg = base64Decode(
      '/9j/4AAQSkZJRgABAQAASABIAAD/4QCMRXhpZgAATU0AKgAAAAgABQESAAMAAAABAAEAAAEaAAUAAAABAAAASgEbAAUAAAABAAAAUgEoAAMAAAABAAIAAIdpAAQAAAABAAAAWgAAAAAAAABIAAAAAQAAAEgAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAAAygAwAEAAAAAQAAAAcAAAAA/8AAEQgABwAMAwERAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgMDBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAv/aAAwDAQACEQMRAD8A9S8ZfsFeG/sH/IUboe7V/JHgR4t4v+2/4XVdj908aPHLG/2P/B6PsfO5/YL8O7m/4mjdT3av966fi1ivZw/ddF2P8VZ+OeN9pP8Ac9X2P//Z',
    );
    final webp = base64Decode(
      'UklGRmIAAABXRUJQVlA4IFYAAADwAgCdASoMAAcAAgA0JbACdLoB8gFKA+wCuAAPQBPAQAD+zgeDPr1Nt++xzMd++pP/lXpu/V9e3k9vx/4zXuAijaP/6TI74hwoeND/W7C9rod3/GrgAA==',
    );

    for (final bytes in [jpeg, webp]) {
      final dimensions = readRecipeImageDimensions(bytes);
      expect(dimensions?.width, 12);
      expect(dimensions?.height, 7);
      expect(
        RecipeImage(
          recipeId: 'doener-vegan',
          bytes: bytes,
          updatedAt: DateTime.utc(2026),
        ).bytes,
        isNotEmpty,
      );
    }
  });

  test('backup JSON roundtrip preserves exact image bytes and metadata', () {
    final image = RecipeImage(
      recipeId: 'doener-vegan',
      bytes: testPngBytes(),
      updatedAt: DateTime.utc(2026, 7, 15, 12),
    );
    final restored = RecipeImage.fromBackupJson(image.toBackupJson());

    expect(restored.recipeId, 'doener-vegan');
    expect(restored.mimeType, 'image/png');
    expect(restored.updatedAt, DateTime.utc(2026, 7, 15, 12));
    expect(restored.bytes, orderedEquals(testPngBytes()));
  });

  test('validates dimensions and keeps stored bytes immutable', () {
    final source = testPngBytes();
    final image = RecipeImage(
      recipeId: 'doener-vegan',
      bytes: source,
      updatedAt: DateTime.utc(2026),
    );
    expect(readRecipeImageDimensions(source)?.width, 1);
    source[0] = 0;
    expect(image.bytes.first, 0x89);
    expect(() => image.bytes[0] = 0, throwsUnsupportedError);
  });

  test('truncated files and excessive pixel dimensions are rejected', () {
    for (final truncated in <List<int>>[
      const [0xFF, 0xD8, 0xFF, 0x00],
      testPngBytes().sublist(0, 24),
      const [
        0x52,
        0x49,
        0x46,
        0x46,
        12,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
        0x56,
        0x50,
        0x38,
        0x20,
        4,
        0,
        0,
        0,
      ],
    ]) {
      expect(
        () => RecipeImage(
          recipeId: 'doener-vegan',
          bytes: truncated,
          updatedAt: DateTime.utc(2026),
        ),
        throwsA(
          isA<RecipeImageException>().having(
            (error) => error.failure,
            'failure',
            RecipeImageFailure.unsupportedType,
          ),
        ),
      );
    }

    final bomb = Uint8List.fromList(testPngBytes());
    // 30,000 x 30,000 pixels in the PNG IHDR, while encoded bytes stay tiny.
    bomb.setRange(16, 24, const [0, 0, 0x75, 0x30, 0, 0, 0x75, 0x30]);
    expect(
      () => RecipeImage(
        recipeId: 'doener-vegan',
        bytes: bomb,
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(
        isA<RecipeImageException>().having(
          (error) => error.failure,
          'failure',
          RecipeImageFailure.dimensionsTooLarge,
        ),
      ),
    );
  });

  test('unsupported, mismatched and oversized image data is rejected', () {
    expect(
      () => RecipeImage(
        recipeId: 'doener-vegan',
        bytes: const [1, 2, 3],
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(
        isA<RecipeImageException>().having(
          (e) => e.failure,
          'failure',
          RecipeImageFailure.unsupportedType,
        ),
      ),
    );
    expect(
      () => RecipeImage(
        recipeId: 'doener-vegan',
        bytes: testPngBytes(),
        mimeType: 'image/jpeg',
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(isA<RecipeImageException>()),
    );
    final huge = Uint8List(maxRecipeImageBytes + 1)
      ..setRange(0, 8, testPngBytes().take(8));
    expect(
      () => RecipeImage(
        recipeId: 'doener-vegan',
        bytes: huge,
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(
        isA<RecipeImageException>().having(
          (e) => e.failure,
          'failure',
          RecipeImageFailure.tooLarge,
        ),
      ),
    );
  });
}
