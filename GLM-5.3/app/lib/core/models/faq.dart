import 'localized_text.dart';

/// One FAQ entry of the Help Center.
class Faq {
  Faq({required this.id, required this.category, required this.question, required this.answer});

  final String id;
  final String category; // matching | visibility | features | troubleshooting
  final LocalizedText question;
  final LocalizedText answer;

  static Faq fromMap(Map<String, dynamic> map) => Faq(
        id: map['id'] as String,
        category: map['category'] as String,
        question: parseLocalized(map['q']),
        answer: parseLocalized(map['a']),
      );
}

/// A category of the FAQ with a localized label.
class FaqCategory {
  FaqCategory({required this.id, required this.label});

  final String id;
  final LocalizedText label;

  static FaqCategory fromMap(Map<String, dynamic> map) =>
      FaqCategory(id: map['id'] as String, label: parseLocalized(map['label']));
}

/// All bundled FAQs plus their categories.
class FaqBook {
  FaqBook(this.categories, this.faqs);

  final List<FaqCategory> categories;
  final List<Faq> faqs;

  static FaqBook fromMap(Map<String, dynamic> map) => FaqBook(
        (map['categories'] as List).map((e) => FaqCategory.fromMap(e as Map<String, dynamic>)).toList(),
        (map['faqs'] as List).map((e) => Faq.fromMap(e as Map<String, dynamic>)).toList(),
      );

  Faq? byId(String id) {
    for (final f in faqs) {
      if (f.id == id) return f;
    }
    return null;
  }

  String categoryLabel(String id, String lang) {
    for (final c in categories) {
      if (c.id == id) return lt(c.label, lang, id);
    }
    return id;
  }

  /// Search by free text (question + answer) in [lang].
  List<Faq> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return faqs;
    return faqs.where((f) {
      return lt(f.question, lang).toLowerCase().contains(q) ||
          lt(f.answer, lang).toLowerCase().contains(q);
    }).toList();
  }
}
