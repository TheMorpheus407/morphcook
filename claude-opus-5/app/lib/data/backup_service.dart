import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/collections.dart';
import '../domain/profile.dart';
import 'backup_crypto.dart';

/// The document written to disk. Mirrors the shape in SPEC.md exactly.
class BackupDocument {
  const BackupDocument({
    required this.schemaVersion,
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
    required this.shopping,
  });

  static const int currentSchemaVersion = 1;

  factory BackupDocument.fromJson(Map<String, dynamic> j) {
    final version = (j['schema_version'] as num?)?.toInt();
    if (version == null) {
      throw const BackupFormatException('missing schema_version');
    }
    if (version > currentSchemaVersion) {
      throw BackupFormatException(
        'backup schema $version is newer than this app supports',
      );
    }
    return BackupDocument(
      schemaVersion: version,
      exportedAt:
          DateTime.tryParse(j['exported_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      profile: Profile.fromJson(
        ((j['profile'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      saved: ((j['saved'] as List?) ?? const [])
          .map(_savedFrom)
          .whereType<SavedRecipe>()
          .toList(),
      mealPlan: MealPlan.fromJson(
        ((j['meal_plan'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      history: ((j['history'] as List?) ?? const [])
          .map(
            (e) =>
                CookHistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      contentRequests: ((j['content_requests'] as List?) ?? const [])
          .map(ContentRequest.fromJson)
          .toList(),
      shopping: ((j['shopping'] as List?) ?? const [])
          .map(
            (e) => ShoppingEntry.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  /// `saved` is documented as a plain id list; we also accept the richer object
  /// form so a future export can carry the save date without a version bump.
  static SavedRecipe? _savedFrom(Object? raw) {
    if (raw is String) {
      return SavedRecipe(
        recipeId: raw,
        savedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    if (raw is Map) return SavedRecipe.fromJson(raw.cast<String, dynamic>());
    return null;
  }

  final int schemaVersion;
  final DateTime exportedAt;
  final Profile profile;
  final List<SavedRecipe> saved;
  final MealPlan mealPlan;
  final List<CookHistoryEntry> history;
  final List<ContentRequest> contentRequests;
  final List<ShoppingEntry> shopping;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'profile': profile.toJson(),
    'saved': saved.map((e) => e.toJson()).toList(),
    'meal_plan': mealPlan.toJson(),
    'history': history.map((e) => e.toJson()).toList(),
    'content_requests': contentRequests.map((e) => e.toJson()).toList(),
    'shopping': shopping.map((e) => e.toJson()).toList(),
  };
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.detail);

  final String detail;

  @override
  String toString() => 'BackupFormatException: $detail';
}

enum ImportMode { merge, replace }

/// The two files an export produces, plus their sizes for the UI to report.
class ExportBundle {
  const ExportBundle({
    required this.jsonBytes,
    required this.gzipBytes,
    required this.encrypted,
  });

  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
  final bool encrypted;

  static const String jsonFilename = 'morphcook-backup.json';
  static const String gzipFilename = 'morphcook-backup.json.gz';

  int get uncompressedLength => jsonBytes.length;
  int get compressedLength => gzipBytes.length;

  /// 0.0–1.0. Typically 0.7–0.9 for JSON of this shape.
  double get compressionRatio =>
      uncompressedLength == 0 ? 0 : 1 - (compressedLength / uncompressedLength);
}

/// Pure file-format logic: no platform calls, no share sheet, no disk. That
/// keeps the round-trip fully testable.
class BackupService {
  BackupService({BackupCrypto? crypto}) : _crypto = crypto ?? BackupCrypto();

  final BackupCrypto _crypto;

  static final GZipCodec _gzip = GZipCodec(level: 9);

  /// Builds both files side by side. When [password] is set the JSON file is
  /// encrypted; the GZip file stays plain so it remains universally readable.
  ExportBundle export(BackupDocument document, {String? password}) {
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(document.toJson());
    final plainBytes = Uint8List.fromList(utf8.encode(pretty));

    final gzipBytes = Uint8List.fromList(_gzip.encode(plainBytes));
    final jsonBytes = (password != null && password.isNotEmpty)
        ? _crypto.encrypt(pretty, password)
        : plainBytes;

    return ExportBundle(
      jsonBytes: jsonBytes,
      gzipBytes: gzipBytes,
      encrypted: password != null && password.isNotEmpty,
    );
  }

  /// Detects encryption first, then GZip, then plain JSON.
  ///
  /// Throws [DecryptionException] with [DecryptionFailure.passwordRequired]
  /// when the file is encrypted and no password was supplied — the caller is
  /// expected to prompt and call [importEncrypted].
  BackupDocument import(List<int> bytes) {
    if (BackupCrypto.isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionFailure.passwordRequired);
    }
    return _parse(_decodeMaybeGzip(bytes));
  }

  BackupDocument importEncrypted(List<int> bytes, String password) {
    if (!BackupCrypto.isEncrypted(bytes)) {
      // Somebody supplied a password for a plain file — that is harmless.
      return import(bytes);
    }
    return _parse(_crypto.decrypt(bytes, password));
  }

  String _decodeMaybeGzip(List<int> bytes) {
    if (BackupCrypto.isGzip(bytes)) {
      try {
        return utf8.decode(_gzip.decode(bytes));
      } on Object {
        throw const DecryptionException(DecryptionFailure.corrupted);
      }
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
  }

  BackupDocument _parse(String text) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (decoded is! Map) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final map = decoded.cast<String, dynamic>();
    if (!map.containsKey('schema_version')) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    return BackupDocument.fromJson(map);
  }
}

/// The result of folding an imported document into the live collections.
/// Nothing here touches the bundled corpus — only user data moves.
class MergeOutcome {
  const MergeOutcome({
    required this.profile,
    required this.saved,
    required this.history,
    required this.plan,
    required this.shopping,
    required this.requests,
    required this.addedSaved,
    required this.addedHistory,
    required this.addedPlanSlots,
  });

  final Profile profile;
  final List<SavedRecipe> saved;
  final List<CookHistoryEntry> history;
  final MealPlan plan;
  final List<ShoppingEntry> shopping;
  final List<ContentRequest> requests;

  final int addedSaved;
  final int addedHistory;
  final int addedPlanSlots;
}

MergeOutcome applyBackup({
  required BackupDocument document,
  required ImportMode mode,
  required Profile currentProfile,
  required List<SavedRecipe> currentSaved,
  required List<CookHistoryEntry> currentHistory,
  required MealPlan currentPlan,
  required List<ShoppingEntry> currentShopping,
  required List<ContentRequest> currentRequests,
}) {
  if (mode == ImportMode.replace) {
    return MergeOutcome(
      profile: document.profile,
      saved: List.of(document.saved),
      history: List.of(document.history),
      plan: MealPlan.fromJson(document.mealPlan.toJson()),
      shopping: List.of(document.shopping),
      requests: List.of(document.contentRequests),
      addedSaved: document.saved.length,
      addedHistory: document.history.length,
      addedPlanSlots: document.mealPlan.filledSlotCount,
    );
  }

  final saved = List.of(currentSaved);
  final knownSaved = saved.map((e) => e.recipeId).toSet();
  var addedSaved = 0;
  for (final item in document.saved) {
    if (knownSaved.add(item.recipeId)) {
      saved.add(item);
      addedSaved++;
    }
  }

  final history = List.of(currentHistory);
  final knownHistory = history
      .map((e) => '${e.recipeId}@${e.cookedAt.toUtc().toIso8601String()}')
      .toSet();
  var addedHistory = 0;
  for (final item in document.history) {
    if (knownHistory.add(
      '${item.recipeId}@${item.cookedAt.toUtc().toIso8601String()}',
    )) {
      history.add(item);
      addedHistory++;
    }
  }

  final plan = MealPlan.fromJson(currentPlan.toJson());
  final before = plan.filledSlotCount;
  plan.mergeFrom(document.mealPlan);
  final addedPlanSlots = plan.filledSlotCount - before;

  final shopping = List.of(currentShopping);
  final knownShopping = shopping.map((e) => e.ingredientId).toSet();
  for (final item in document.shopping) {
    if (knownShopping.add(item.ingredientId)) shopping.add(item);
  }

  final requests = <String, ContentRequest>{
    for (final r in currentRequests) r.query.toLowerCase(): r,
  };
  for (final r in document.contentRequests) {
    final key = r.query.toLowerCase();
    final existing = requests[key];
    requests[key] = existing == null
        ? r
        : ContentRequest(
            query: existing.query,
            firstAskedAt: existing.firstAskedAt.isBefore(r.firstAskedAt)
                ? existing.firstAskedAt
                : r.firstAskedAt,
            count: existing.count + r.count,
          );
  }

  history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
  saved.sort((a, b) => b.savedAt.compareTo(a.savedAt));

  return MergeOutcome(
    profile: currentProfile,
    saved: saved,
    history: history,
    plan: plan,
    shopping: shopping,
    requests: requests.values.toList(),
    addedSaved: addedSaved,
    addedHistory: addedHistory,
    addedPlanSlots: addedPlanSlots,
  );
}
