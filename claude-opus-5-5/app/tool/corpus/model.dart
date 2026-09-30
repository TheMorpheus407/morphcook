// Compact authoring model for the corpus build. These classes only exist at
// build time; the app reads the emitted JSON.

class T {
  const T(this.en, this.de);
  final String en;
  final String de;
  Map<String, String> toJson() => {'en': en, 'de': de};
}

class Ing {
  const Ing(this.id, this.qty, this.unit, [this.note]);
  final String id;
  final num? qty;
  final String unit;
  final T? note;
}

class St {
  const St(this.en, this.de, [this.timerSeconds]);
  final String en;
  final String de;
  final int? timerSeconds;
}

class Rec {
  const Rec({
    required this.id,
    required this.diet,
    required this.effort,
    required this.time,
    required this.servings,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.title,
    required this.blurb,
    required this.note,
    required this.meals,
    required this.techniques,
    required this.ingredients,
    required this.steps,
    this.attributes = const [],
    this.tags = const [],
  });
  final String id;
  final String diet;
  final String effort;
  final int time;
  final int servings;
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;
  final T title;
  final T blurb;
  final T note;
  final List<String> meals;
  final List<String> techniques;
  final List<String> attributes;
  final List<T> tags;
  final List<Ing> ingredients;
  final List<St> steps;
}

class DishSpec {
  const DishSpec({
    required this.id,
    required this.name,
    required this.hero,
    required this.caption,
    required this.stripe,
    required this.cuisine,
    required this.partition,
    required this.tier,
    required this.recipes,
    this.secondary = const [],
  });
  final String id;
  final T name;
  final T hero;
  final T caption;
  final String stripe;
  final String cuisine;
  final String partition;
  final List<String> secondary;
  final String tier;
  final List<Rec> recipes;
}

T t(String en, String de) => T(en, de);
Ing i(String id, num? qty, String unit, [T? note]) => Ing(id, qty, unit, note);
St st(String en, String de, [int? timer]) => St(en, de, timer);
const salt = Ing('salt', null, 'to-taste');
const pepper = Ing('black-pepper', null, 'to-taste');
