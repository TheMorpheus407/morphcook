import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/models.dart';

void main() {
  test('ontology asset parses', () {
    final j = jsonDecode(File('assets/data/ontology.json').readAsStringSync())
        as Map<String, dynamic>;
    final o = Ontology.fromJson(j);
    expect(o.attributes.keys.toSet(), {
      'effort',
      'time_bucket',
      'calorie_bucket',
      'techniques',
    });
    expect(o.attributes['techniques']!.keys,
        containsAll(['bake', 'sauté', 'grill', 'roast']));
  });
}