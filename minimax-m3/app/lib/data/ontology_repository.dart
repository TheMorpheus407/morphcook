import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/ontology.dart';
import 'local_storage.dart';

class OntologyRepository {
  final Ontology ontology;
  const OntologyRepository(this.ontology);

  static Future<OntologyRepository> load() async {
    final json = await loadJsonAsset('assets/ontology.json');
    return OntologyRepository(Ontology.fromJson(json));
  }
}

class IngredientRepository {
  final IngredientTree tree;
  const IngredientRepository(this.tree);

  static Future<IngredientRepository> load() async {
    final json = await loadJsonAsset('assets/ingredients.json');
    return IngredientRepository(IngredientTree.fromJson(json));
  }
}

class CombinedReferenceRepository extends ChangeNotifier {
  final OntologyRepository ontologyRepo;
  final IngredientRepository ingredientRepo;
  CombinedReferenceRepository({
    required this.ontologyRepo,
    required this.ingredientRepo,
  });

  Ontology get ontology => ontologyRepo.ontology;
  IngredientTree get ingredients => ingredientRepo.tree;
}
