import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_requests_service.dart';
import 'cook_progress_service.dart';
import 'cookbook_service.dart';
import 'history_service.dart';
import 'meal_plan_service.dart';
import 'profile_service.dart';
import 'shopping_list_service.dart';

/// Opens Hive boxes + shared_preferences and wires up every service. Created
/// once at launch and handed to the widget tree via [AppScope].
class Services {
  Services({
    required this.profile,
    required this.cookbook,
    required this.history,
    required this.mealPlan,
    required this.shopping,
    required this.contentRequests,
    required this.cookProgress,
  });

  final ProfileService profile;
  final CookbookService cookbook;
  final HistoryService history;
  final MealPlanService mealPlan;
  final ShoppingListService shopping;
  final ContentRequestsService contentRequests;
  final CookProgressService cookProgress;

  static Future<Services> open() async {
    await Hive.initFlutter();
    final prefs = await SharedPreferences.getInstance();
    final cookbookBox = await Hive.openBox('cookbook');
    final historyBox = await Hive.openBox('history');
    final mealPlanBox = await Hive.openBox('meal_plan');
    final shoppingBox = await Hive.openBox('shopping');
    final contentBox = await Hive.openBox('content_requests');
    final cookBox = await Hive.openBox('cook_progress');
    return Services(
      profile: ProfileService(prefs),
      cookbook: CookbookService(cookbookBox),
      history: HistoryService(historyBox),
      mealPlan: MealPlanService(mealPlanBox),
      shopping: ShoppingListService(shoppingBox),
      contentRequests: ContentRequestsService(contentBox),
      cookProgress: CookProgressService(cookBox),
    );
  }
}
