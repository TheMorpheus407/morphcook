import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full corpus load with real bundled assets', () async {
    final c = Corpus();
    await c.load();
    expect(c.ready, isTrue);
    expect(c.ontology.attributes['techniques']!.keys,
        containsAll(['bake', 'sauté', 'grill', 'roast']));
    expect(c.dishesById, isNotEmpty);
    expect(c.recipesById, isNotEmpty);
    expect(c.ingredientRoots, isNotEmpty);
  });
}