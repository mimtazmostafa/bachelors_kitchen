import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipes.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/recipe_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final favs = context.watch<FavoritesProvider>();
    final favRecipes = kAllRecipes
        .where((r) => favs.isFavorite(r.id))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(t.favorites)),
      body: favRecipes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 70, color: Color(0xFFCFCFCF)),
                    const SizedBox(height: 14),
                    Text(
                      t.noFavorites,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: favRecipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  RecipeCard(recipe: favRecipes[i]),
            ),
    );
  }
}