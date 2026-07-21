import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class FaqEntry {
  FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    Map<String, List<String>> keywords = const {},
    Set<String> contextualLinks = const {},
    this.relatedRoute,
    Set<String> relatedFaqIds = const {},
  }) : keywords = UnmodifiableMapView({
         for (final entry in keywords.entries)
           normalizeLanguageCode(entry.key): UnmodifiableListView(
             List.of(entry.value),
           ),
       }),
       relatedFaqIds = UnmodifiableSetView(Set.of(relatedFaqIds)),
       contextualLinks = UnmodifiableSetView(
         _allContextualLinks(contextualLinks, relatedRoute, relatedFaqIds),
       );

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    final rawKeywordValue = json['keywords'] ?? json['search_terms'];
    final rawKeywords = jsonMap(rawKeywordValue);
    return FaqEntry(
      id: jsonString(json['id']),
      category: jsonString(json['category'], 'general'),
      question: LocalizedText.fromJson(json['question']),
      answer: LocalizedText.fromJson(json['answer']),
      keywords: rawKeywords.isEmpty && rawKeywordValue is List
          ? {'en': jsonStringList(rawKeywordValue)}
          : {
              for (final entry in rawKeywords.entries)
                entry.key: jsonStringList(entry.value),
            },
      contextualLinks: jsonStringSet(json['contextual_links'] ?? json['links']),
      relatedRoute: json['related_route']?.toString(),
      relatedFaqIds: jsonStringSet(json['related_faq_ids']),
    );
  }

  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final Map<String, List<String>> keywords;
  final Set<String> contextualLinks;
  final String? relatedRoute;
  final Set<String> relatedFaqIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'question': question.toJson(),
    'answer': answer.toJson(),
    'search_terms': keywords,
    if (relatedRoute != null) 'related_route': relatedRoute,
    if (relatedFaqIds.isNotEmpty)
      'related_faq_ids': relatedFaqIds.toList()..sort(),
    if (contextualLinks.isNotEmpty)
      'contextual_links': contextualLinks.toList()..sort(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaqEntry &&
          id == other.id &&
          category == other.category &&
          question == other.question &&
          answer == other.answer &&
          const DeepCollectionEquality().equals(keywords, other.keywords) &&
          const SetEquality<String>().equals(
            contextualLinks,
            other.contextualLinks,
          ) &&
          relatedRoute == other.relatedRoute &&
          const SetEquality<String>().equals(
            relatedFaqIds,
            other.relatedFaqIds,
          );

  @override
  int get hashCode => Object.hash(
    id,
    category,
    question,
    answer,
    const DeepCollectionEquality().hash(keywords),
    const SetEquality<String>().hash(contextualLinks),
    relatedRoute,
    const SetEquality<String>().hash(relatedFaqIds),
  );
}

Set<String> _allContextualLinks(
  Iterable<String> links,
  String? route,
  Iterable<String> relatedFaqIds,
) {
  final result = <String>{...links, ...relatedFaqIds};
  if (route != null) result.add(route);
  return result;
}
