import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled corpus parses and matching runs', () async {
    final corpus = CorpusRepository(bundle: rootBundle);
    await corpus.initialize();
    expect(corpus.dishes, isNotEmpty);
    expect(corpus.loadedRecipes, isNotEmpty);
    expect(corpus.ontology.compoundFlags, isNotEmpty);
    expect(corpus.faqs.entries, isNotEmpty);
    expect(corpus.guide, isNotEmpty);

    final matcher = Matcher(
      ontology: corpus.ontology,
      dictionary: corpus.dictionary,
    );
    final vegan = const Profile(avoidFlags: {'vegan'});
    final visible = corpus.loadedRecipes.where((r) => matcher.isVisible(r, vegan));
    expect(visible, isNotEmpty);
    expect(
      visible.every((r) => r.contains.intersection({
            'pork',
            'beef',
            'lamb',
            'poultry',
            'fish',
            'shellfish',
            'molluscs',
            'egg',
            'dairy',
            'honey',
          }).isEmpty),
      isTrue,
    );
  });
}
