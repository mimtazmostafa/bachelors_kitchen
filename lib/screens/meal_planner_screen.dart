import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipes.dart';
import '../models/recipe.dart';
import '../providers/language_provider.dart';
import '../providers/meal_planner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';

class MealPlannerScreen extends StatelessWidget {
  const MealPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final planner = context.watch<MealPlannerProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(t.weeklyPlan)),
      body: _PlannerBody(planner: planner, isBn: t.isBn),
    );
  }
}

class _PlannerBody extends StatelessWidget {
  final MealPlannerProvider planner;
  final bool isBn;
  const _PlannerBody({required this.planner, required this.isBn});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final days = isBn
        ? const [
            'সোমবার',
            'মঙ্গলবার',
            'বুধবার',
            'বৃহস্পতিবার',
            'শুক্রবার',
            'শনিবার',
            'রবিবার',
          ]
        : const [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isBn
                      ? 'এই সপ্তাহের মিল প্ল্যান করুন'
                      : 'Plan this week\'s meals',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => planner.clearWeek(),
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: Text(t.clearWeek),
              ),
            ],
          ),
        ),

        // 7-day list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final recipeId = planner.recipeForDay(i);
              final recipe = recipeId == null
                  ? null
                  : kAllRecipes.firstWhere(
                      (r) => r.id == recipeId,
                      orElse: () => kAllRecipes.first,
                    );
              return _DayRow(
                day: days[i],
                dayIndex: i,
                recipe: recipe,
                isBn: isBn,
              );
            },
          ),
        ),

        // Summary
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Row(
            children: [
              Expanded(
                child: _summaryCell(
                  icon: Icons.shopping_basket,
                  label: t.shoppingList,
                  value: '${planner.totalIngredients} items',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: const Color(0xFFEEE5DE),
              ),
              Expanded(
                child: _summaryCell(
                  icon: Icons.payments,
                  label: t.totalCost,
                  value: '৳${planner.totalCost}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B6B6B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final String day;
  final int dayIndex;
  final Recipe? recipe;
  final bool isBn;

  const _DayRow({
    required this.day,
    required this.dayIndex,
    required this.recipe,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final planner = context.read<MealPlannerProvider>();
    final picked = recipe != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: picked
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : const Color(0xFFEEE5DE),
            ),
          ),
          child: Row(
            children: [
              if (picked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RecipeImage(
                    recipe: recipe!,
                    emoji: emojiFor(recipe!),
                    size: 56,
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppTheme.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      picked
                          ? (isBn ? recipe!.nameBn : recipe!.nameEn)
                          : t.pickADish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: picked
                            ? const Color(0xFF333333)
                            : const Color(0xFF888888),
                        fontWeight: picked ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (picked)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => planner.setDay(dayIndex, null),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final t = context.read<LanguageProvider>().t;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _RecipePickerSheet(isBn: t.isBn);
      },
    );
    if (picked != null && context.mounted) {
      context.read<MealPlannerProvider>().setDay(dayIndex, picked);
    }
  }
}

class _RecipePickerSheet extends StatelessWidget {
  final bool isBn;
  const _RecipePickerSheet({required this.isBn});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0DCD7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu,
                        color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isBn ? 'একটি রেসিপি বেছে নিন' : 'Pick a dish',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: kAllRecipes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = kAllRecipes[i];
                    return Material(
                      color: const Color(0xFFFFF8F2),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(context, r.id),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: RecipeImage(
                                  recipe: r,
                                  emoji: emojiFor(r),
                                  size: 50,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isBn ? r.nameBn : r.nameEn,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '৳${r.costTaka} • ${r.cookingMinutes} min',
                                      style: const TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}