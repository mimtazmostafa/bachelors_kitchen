import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/recipes.dart';
import '../models/recipe.dart';

/// Weekly meal planner. Stores one recipe id per weekday (Mon..Sun).
class MealPlannerProvider extends ChangeNotifier {
  static const _key = 'meal_plan_v1';
  static const _len = 7;

  /// Index 0 = Monday, 6 = Sunday. Each value is a recipe id (or null).
  final List<String?> _plan = List.filled(_len, null, growable: false);
  bool _loaded = false;

  List<String?> get plan => List.unmodifiable(_plan);
  bool get loaded => _loaded;

  String? recipeForDay(int dayIndex) =>
      (dayIndex >= 0 && dayIndex < _len) ? _plan[dayIndex] : null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    for (int i = 0; i < _len; i++) {
      _plan[i] = i < raw.length ? raw[i] : null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDay(int dayIndex, String? recipeId) async {
    if (dayIndex < 0 || dayIndex >= _len) return;
    _plan[dayIndex] = recipeId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _plan.map((e) => e ?? '').toList());
  }

  Future<void> clearWeek() async {
    for (int i = 0; i < _len; i++) {
      _plan[i] = null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _plan.map((e) => e ?? '').toList());
  }

  /// Total cost in Taka across the week.
  int get totalCost {
    int total = 0;
    for (final id in _plan) {
      if (id == null) continue;
      final r = kAllRecipes.firstWhere(
        (r) => r.id == id,
        orElse: () => kAllRecipes.first,
      );
      total += r.costTaka;
    }
    return total;
  }

  /// Aggregated unique ingredient count for the shopping list.
  int get totalIngredients {
    final seen = <String>{};
    for (final id in _plan) {
      if (id == null) continue;
      final r = kAllRecipes.firstWhere(
        (r) => r.id == id,
        orElse: () => kAllRecipes.first,
      );
      for (final ing in r.ingredients) {
        seen.add(ing.nameEn.toLowerCase());
      }
    }
    return seen.length;
  }

  /// Flat shopping list with name + quantity per ingredient.
  List<({String name, String quantity})> get shoppingList {
    final map = <String, _IngredientRow>{};
    for (final id in _plan) {
      if (id == null) continue;
      final r = kAllRecipes.firstWhere(
        (r) => r.id == id,
        orElse: () => kAllRecipes.first,
      );
      for (final ing in r.ingredients) {
        final key = ing.nameEn.toLowerCase();
        final existing = map[key];
        if (existing == null) {
          map[key] = _IngredientRow(
            nameEn: ing.nameEn,
            nameBn: ing.nameBn,
            quantity: ing.quantity,
          );
        }
      }
    }
    final out = <({String name, String quantity})>[];
    for (final row in map.values) {
      out.add((name: row.nameEn, quantity: row.quantity));
    }
    return out;
  }
}

class _IngredientRow {
  final String nameEn;
  final String nameBn;
  final String quantity;
  const _IngredientRow({
    required this.nameEn,
    required this.nameBn,
    required this.quantity,
  });
}

extension RecipeLookup on Recipe {
  Recipe safeById(String id) => kAllRecipes.firstWhere(
        (r) => r.id == id,
        orElse: () => kAllRecipes.first,
      );
}