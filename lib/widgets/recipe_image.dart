import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// A photo-style thumbnail for a recipe.
///
/// We don't have real food photos in this prototype, so we generate a
/// visually appealing stand-in: a soft gradient using the recipe's brand
/// color, a large food emoji, and a subtle icon watermark. This is
/// easily swapped for `Image.asset(recipe.imagePath!)` once the user
/// drops PNGs into `assets/images/recipes/`.
class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final double size;
  final double radius;
  final String? emoji;
  final double? width;
  final double? height;

  const RecipeImage({
    super.key,
    required this.recipe,
    this.size = 64,
    this.radius = 16,
    this.emoji,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final c = recipe.color;
    final w = width ?? size;
    final h = height ?? size;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: 0.85),
            c.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (emoji != null)
            Text(
              emoji!,
              style: TextStyle(
                fontSize: h * 0.55,
                height: 1,
              ),
            )
          else
            Icon(
              recipe.icon,
              color: Colors.white,
              size: h * 0.45,
            ),
        ],
      ),
    );
  }
}

/// Lookup emoji for a recipe id — keeps the data close to the image.
const Map<String, String> kRecipeEmojis = {
  'rice_egg_fry': '🍳',
  'aloo_bharta': '🥔',
  'begun_bhaja': '🍆',
  'dal_tadka': '🍲',
  'murgi_torkari': '🍗',
  'ilish_bhapa': '🐟',
  'dim_bhuna': '🥚',
  'shobji_bhaja': '🥦',
  'rui_kalia': '🐠',
  'mangsho_torkari': '🍖',
  'cholar_dal': '🥣',
  'muri_ghonto': '🍚',
  'kacchi_biryani': '🍛',
  'fuchka': '🥟',
  'beguni': '🍤',
  'mishti_doi': '🍮',
  'cha': '☕',
  'panta_bhat': '🥗',
};

String emojiFor(Recipe r) => kRecipeEmojis[r.id] ?? '🍽️';
