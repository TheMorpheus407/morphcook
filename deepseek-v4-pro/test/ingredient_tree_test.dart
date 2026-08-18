import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/ingredient.dart';

IngredientTree tree() => IngredientTree.fromJson(const {
      'tree': [
        {
          'id': 'dairy',
          'name': {'en': 'Dairy', 'de': 'Milchprodukte'},
          'children': [
            {'id': 'dairy.milk', 'name': {'en': 'milk', 'de': 'Milch'}},
            {
              'id': 'dairy.cheese',
              'name': {'en': 'cheese', 'de': 'Käse'},
              'children': [
                {'id': 'dairy.cheese.parmesan', 'name': {'en': 'parmesan', 'de': 'Parmesan'}},
                {'id': 'dairy.cheese.feta', 'name': {'en': 'feta', 'de': 'Feta'}},
              ],
            },
          ],
        },
        {
          'id': 'nuts',
          'name': {'en': 'Nuts', 'de': 'Nüsse'},
          'children': [
            {'id': 'nuts.peanuts', 'name': {'en': 'peanuts', 'de': 'Erdnüsse'}},
          ],
        },
      ]
    });

void main() {
  test('subtree includes the node itself and all descendants', () {
    final t = tree();
    expect(t.subtree('dairy.cheese'), {
      'dairy.cheese',
      'dairy.cheese.parmesan',
      'dairy.cheese.feta',
    });
    expect(t.subtree('dairy.cheese.feta'), {'dairy.cheese.feta'});
  });

  test('propagation unions subtrees of every avoided id', () {
    final t = tree();
    expect(
      t.propagationOf(['dairy.cheese', 'nuts.peanuts']),
      {
        'dairy.cheese',
        'dairy.cheese.parmesan',
        'dairy.cheese.feta',
        'nuts.peanuts',
      },
    );
  });

  test('search matches leaves and parents by language', () {
    final t = tree();
    expect(t.search('parm', 'en').map((n) => n.id), contains('dairy.cheese.parmesan'));
    expect(t.search('käse', 'de').map((n) => n.id), contains('dairy.cheese'));
    expect(t.search('zzz', 'en'), isEmpty);
    expect(t.search('', 'en'), isEmpty);
  });

  test('bilingual names fall back to en', () {
    final t = tree();
    expect(t.byId('dairy.milk')!.name['de'], 'Milch');
    expect(t.byId('dairy.milk')!.name['en'], 'milk');
  });

  test('leaf detection', () {
    final t = tree();
    expect(t.byId('dairy.cheese')!.isLeaf, isFalse);
    expect(t.byId('dairy.milk')!.isLeaf, isTrue);
  });
}
