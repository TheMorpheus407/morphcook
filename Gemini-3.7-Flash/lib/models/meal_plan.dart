class MealSlotKey {
  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const List<String> mealTypes = ['breakfast', 'lunch', 'dinner'];

  static String key(String day, String mealType) => '${day.toLowerCase()}.${mealType.toLowerCase()}';
  static String dayLabel(String day, String lang) {
    switch (day.toLowerCase()) {
      case 'mon': return lang == 'de' ? 'Montag' : 'Monday';
      case 'tue': return lang == 'de' ? 'Dienstag' : 'Tuesday';
      case 'wed': return lang == 'de' ? 'Mittwoch' : 'Wednesday';
      case 'thu': return lang == 'de' ? 'Donnerstag' : 'Thursday';
      case 'fri': return lang == 'de' ? 'Freitag' : 'Friday';
      case 'sat': return lang == 'de' ? 'Samstag' : 'Saturday';
      case 'sun': return lang == 'de' ? 'Sonntag' : 'Sunday';
      default: return day;
    }
  }
  static String mealTypeLabel(String mealType, String lang) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return lang == 'de' ? 'Frühstück' : 'Breakfast';
      case 'lunch': return lang == 'de' ? 'Mittagessen' : 'Lunch';
      case 'dinner': return lang == 'de' ? 'Abendessen' : 'Dinner';
      default: return mealType;
    }
  }
}

class WeeklyMealPlan {
  final String weekId; // e.g. "2026-W33"
  final Map<String, String> slots; // e.g. {"mon.dinner": "doener-vegan"}

  WeeklyMealPlan({
    required this.weekId,
    Map<String, String>? slots,
  }) : slots = slots ?? {};

  factory WeeklyMealPlan.fromJson(String weekId, Map<String, dynamic> json) {
    final map = <String, String>{};
    json.forEach((k, v) {
      if (v != null) map[k] = v.toString();
    });
    return WeeklyMealPlan(weekId: weekId, slots: map);
  }

  Map<String, dynamic> toJson() => slots;

  String? getRecipeId(String day, String mealType) {
    return slots[MealSlotKey.key(day, mealType)];
  }

  void setRecipeId(String day, String mealType, String? recipeId) {
    final k = MealSlotKey.key(day, mealType);
    if (recipeId == null || recipeId.isEmpty) {
      slots.remove(k);
    } else {
      slots[k] = recipeId;
    }
  }

  void moveSlot(String fromDay, String fromMeal, String toDay, String toMeal) {
    final fromKey = MealSlotKey.key(fromDay, fromMeal);
    final toKey = MealSlotKey.key(toDay, toMeal);
    final moving = slots[fromKey];
    final target = slots[toKey];

    if (moving != null) {
      slots[toKey] = moving;
      if (target != null) {
        slots[fromKey] = target;
      } else {
        slots.remove(fromKey);
      }
    }
  }

  static String getIsoWeekId(DateTime date) {
    // Basic ISO 8601 week calculation
    final d = DateTime.utc(date.year, date.month, date.day);
    final dayNr = (d.weekday + 6) % 7;
    final thisThursday = d.subtract(Duration(days: dayNr - 3));
    final firstThursday = DateTime.utc(thisThursday.year, 1, 4);
    final weekNumber = ((thisThursday.difference(firstThursday).inDays) / 7).floor() + 1;
    return '${thisThursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
