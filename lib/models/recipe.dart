import 'package:flutter/material.dart';

enum MealCategory {
  breakfast,
  lunch,
  dinner,
  snack;

  String get key => name;

  static MealCategory fromKey(String key) {
    return MealCategory.values.firstWhere(
      (c) => c.name == key,
      orElse: () => MealCategory.lunch,
    );
  }
}

enum Difficulty { easy, medium, hard }

class Ingredient {
  final String nameEn;
  final String nameBn;
  final String quantity;

  const Ingredient({
    required this.nameEn,
    required this.nameBn,
    required this.quantity,
  });
}

class Recipe {
  final String id;
  final String nameEn;
  final String nameBn;
  final String descriptionEn;
  final String descriptionBn;
  final IconData icon;
  final Color color;
  final MealCategory category;
  final Difficulty difficulty;
  final int cookingMinutes;
  final int costTaka; // per serving, in ৳
  final int servings;
  final List<Ingredient> ingredients;
  final List<String> stepsEn;
  final List<String> stepsBn;
  final List<String> tagsEn; // searchable ingredient keywords
  final List<String> tagsBn;

  /// Optional per-step time estimate in minutes (parallel to stepsEn/Bn).
  /// If null, the timer screen will ask the user to set it.
  final List<int>? stepMinutesEn;

  /// Optional image asset path under `assets/images/recipes/`. When null,
  /// the recipe card will show a colored gradient + icon stand-in.
  // ignore: unused_element
  final String? imagePath;

  const Recipe({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.descriptionEn,
    required this.descriptionBn,
    required this.icon,
    required this.color,
    required this.category,
    required this.difficulty,
    required this.cookingMinutes,
    required this.costTaka,
    required this.servings,
    required this.ingredients,
    required this.stepsEn,
    required this.stepsBn,
    required this.tagsEn,
    required this.tagsBn,
    this.stepMinutesEn,
    this.imagePath,
  });

  String displayName(String langCode) =>
      langCode == 'bn' ? nameBn : nameEn;
  String displayDescription(String langCode) =>
      langCode == 'bn' ? descriptionBn : descriptionEn;
  List<String> get displaySteps => stepsEn;
  List<String> get displayStepsBn => stepsBn;
}
