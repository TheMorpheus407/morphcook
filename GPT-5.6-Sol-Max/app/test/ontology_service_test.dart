import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/content.dart';
import 'package:morphcook/services/ontology_service.dart';

void main() {
  final service = OntologyService(
    compoundFlags: {
      'vegan': {'egg', 'dairy', 'honey'},
      'nuts': {'peanuts', 'tree-nuts'},
    },
    ingredients: const [
      IngredientNode(id: 'dairy', name: {'en': 'dairy', 'de': 'milch'}),
      IngredientNode(
        id: 'cheese',
        name: {'en': 'cheese', 'de': 'käse'},
        parentId: 'dairy',
      ),
      IngredientNode(
        id: 'parmesan',
        name: {'en': 'parmesan', 'de': 'parmesan'},
        parentId: 'cheese',
      ),
    ],
    labels: const {
      'vegan': {'en': 'vegan', 'de': 'vegan'},
      'high-protein': {'en': 'high protein', 'de': 'proteinreich'},
    },
  );

  test('compound flags expand while ordinary flags remain additive', () {
    expect(service.expandFlags({'vegan', 'gluten'}), {
      'egg',
      'dairy',
      'honey',
      'gluten',
    });
  });

  test('parent avoidance recursively includes all descendants', () {
    expect(service.expandIngredients({'dairy'}), {
      'dairy',
      'cheese',
      'parmesan',
    });
    expect(service.expandIngredients({'cheese'}), {'cheese', 'parmesan'});
  });

  test('typeahead searches localized names and ids', () {
    expect(service.searchIngredients('käse', 'de').single.id, 'cheese');
    expect(service.searchIngredients('parm', 'en').single.id, 'parmesan');
  });

  test('serves user-visible ontology labels from data', () {
    expect(service.label('high-protein', 'de'), 'proteinreich');
    expect(service.label('new-value', 'fr'), 'new value');
  });
}
