import 'package:flutter/material.dart';

import '../models/recipe.dart';

class CategoryInfo {
  final MealCategory? category;
  final IconData icon;
  final String labelEn;
  final String labelBn;
  final Color color;
  const CategoryInfo({
    required this.category,
    required this.icon,
    required this.labelEn,
    required this.labelBn,
    required this.color,
  });
}

class CategoryUtils {
  static const List<CategoryInfo> all = [
    CategoryInfo(
      category: MealCategory.breakfast,
      icon: Icons.wb_sunny_outlined,
      labelEn: 'Breakfast',
      labelBn: 'সকালের নাস্তা',
      color: Color(0xFFF9A825),
    ),
    CategoryInfo(
      category: MealCategory.lunch,
      icon: Icons.lunch_dining,
      labelEn: 'Lunch',
      labelBn: 'দুপুরের খাবার',
      color: Color(0xFF2E7D32),
    ),
    CategoryInfo(
      category: MealCategory.dinner,
      icon: Icons.dinner_dining,
      labelEn: 'Dinner',
      labelBn: 'রাতের খাবার',
      color: Color(0xFF3949AB),
    ),
    CategoryInfo(
      category: MealCategory.snack,
      icon: Icons.local_pizza_outlined,
      labelEn: 'Snacks',
      labelBn: 'নাস্তা',
      color: Color(0xFFC62828),
    ),
  ];

  static CategoryInfo of(MealCategory c) =>
      all.firstWhere((e) => e.category == c);
}

class CategoryTile extends StatelessWidget {
  final CategoryInfo info;
  final VoidCallback onTap;
  final bool isBn;
  const CategoryTile({
    super.key,
    required this.info,
    required this.onTap,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed-height tile so the row never overflows.
    return Material(
      color: info.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: info.color.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(info.icon, color: info.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBn ? info.labelBn : info.labelEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1B),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 26,
                    height: 3,
                    decoration: BoxDecoration(
                      color: info.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppChipButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const AppChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : const Color(0xFFEEE5DE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

