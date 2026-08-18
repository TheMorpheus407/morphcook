class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(json.map((k, v) => MapEntry(k, '$v')));

  static const empty = LocalizedText({});

  String of(String lang) =>
      values[lang] ?? values['en'] ?? (values.isEmpty ? '' : values.values.first);

  bool get isEmpty => values.values.every((v) => v.trim().isEmpty);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}

class LocalizedList {
  final Map<String, List<String>> values;

  const LocalizedList(this.values);

  factory LocalizedList.fromJson(Map<String, dynamic> json) => LocalizedList(
        json.map((k, v) => MapEntry(k, List<String>.from(v as List))),
      );

  static const empty = LocalizedList({});

  List<String> of(String lang) =>
      values[lang] ?? values['en'] ?? const <String>[];

  Iterable<String> get all => values.values.expand((v) => v);
}
