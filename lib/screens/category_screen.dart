import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipes.dart';
import '../models/recipe.dart';
import '../providers/language_provider.dart';
import '../widgets/category_chip.dart';
import '../widgets/recipe_card.dart';

class CategoryScreen extends StatelessWidget {
  final MealCategory category;
  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final info = CategoryUtils.of(category);
    final recipes = kAllRecipes
        .where((r) => r.category == category)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.isBn ? info.labelBn : info.labelEn),
        backgroundColor: info.color.withValues(alpha: 0.12),
      ),
      body: recipes.isEmpty
          ? Center(child: Text(t.noFavorites))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  RecipeCard(recipe: recipes[i]),
            ),
    );
  }
}