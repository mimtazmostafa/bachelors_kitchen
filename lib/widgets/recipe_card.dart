import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../screens/recipe_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';
import '../widgets/recipe_image.dart';

Widget _cardTarget(BuildContext context, Recipe r) =>
    RecipeDetailScreen(recipe: r);

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  /// Optional short badge text shown as an info chip (e.g. "ভালো মিল",
  /// "Chef's pick"). Replaces the old "100% match" percentage display.
  final String? matchLabel;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.matchLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final favs = context.watch<FavoritesProvider>();
    final isFav = favs.isFavorite(recipe.id);
    final emoji = emojiFor(recipe);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                fadeRoute(_cardTarget(context, recipe)),
              );
            },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEE5DE)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecipeImage(recipe: recipe, emoji: emoji),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.displayName(t.langCode),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recipe.displayDescription(t.langCode),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFav ? t.saved : t.save,
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.grey,
                      ),
                      onPressed: () => favs.toggle(recipe.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _infoChip(
                      Icons.timer_outlined,
                      '${recipe.cookingMinutes} ${t.minutes}',
                      const Color(0xFF1565C0),
                    ),
                    _infoChip(
                      Icons.account_balance_wallet_outlined,
                      '${t.taka}${recipe.costTaka}',
                      const Color(0xFF2E7D32),
                    ),
                    _infoChip(
                      Icons.signal_cellular_alt,
                      t.difficultyLabel(recipe.difficulty),
                      t.difficultyColor(recipe.difficulty),
                    ),
                    if (matchLabel != null)
                      _infoChip(
                        Icons.psychology_alt,
                        matchLabel!,
                        AppTheme.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
