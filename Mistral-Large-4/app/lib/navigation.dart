import 'package:flutter/material.dart';

import 'features/dish/dish_screen.dart';
import 'features/faq/faq_screen.dart';

/// Central navigation helpers so feature screens don't wire routes by hand.
void openDish(BuildContext context, String dishId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => DishScreen(dishId: dishId)),
  );
}

void openFaq(BuildContext context, {String? initialId, String? category}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FaqScreen(initialId: initialId, initialCategory: category),
    ),
  );
}
