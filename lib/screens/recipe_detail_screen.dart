import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';

/// Look-up map of common English ingredient words/phrases → Bangla.
/// Keyed on lowercase ASCII so callers can do `dictionary[token.toLowerCase()]`.
/// Used as a safety net in the recipe-detail screen so that any stray
/// English wording (e.g. for a recipe whose data only has an English name)
/// still reads as Bangla when the UI language is Bangla.
const Map<String, String> _kIngredientEnToBn = {
  // Vegetables & aromatics
  'potato': 'আলু',
  'potatoes': 'আলু',
  'aloo': 'আলু',
  'onion': 'পেঁয়াজ',
  'onions': 'পেঁয়াজ',
  'peyaj': 'পেঁয়াজ',
  'tomato': 'টমেটো',
  'tomatoes': 'টমেটো',
  'chili': 'কাঁচামরিচ',
  'chilies': 'কাঁচামরিচ',
  'green chili': 'কাঁচামরিচ',
  'green chilies': 'কাঁচামরিচ',
  'red chili': 'শুকনো মরিচ',
  'garlic': 'রসুন',
  'ginger': 'আদা',
  'turmeric': 'হলুদ',
  'coriander': 'ধনেপাতা',
  'cumin': 'জিরা',
  'mustard': 'সরিষা',
  'capsicum': 'ক্যাপসিকাম',
  'cauliflower': 'ফুলকপি',
  'carrot': 'গাজর',
  'peas': 'মটর',
  'cucumber': 'শসা',
  'eggplant': 'বেগুন',
  'brinjal': 'বেগুন',
  'spinach': 'পালংশাক',
  // Proteins
  'egg': 'ডিম',
  'eggs': 'ডিম',
  'chicken': 'মুরগির মাংস',
  'mutton': 'খাসির মাংস',
  'beef': 'গরুর মাংস',
  'fish': 'মাছ',
  'prawn': 'চিংড়ি',
  'shrimp': 'চিংড়ি',
  'lentil': 'ডাল',
  'lentils': 'ডাল',
  'dal': 'ডাল',
  'chickpea': 'ছোলা',
  'chickpeas': 'ছোলা',
  'besan': 'বেসন',
  // Grains & staples
  'rice': 'ভাত',
  'flour': 'ময়দা',
  'wheat': 'গম',
  'bread': 'পাউরুটি',
  'roti': 'রুটি',
  'ruti': 'রুটি',
  // Dairy
  'milk': 'দুধ',
  'yogurt': 'দই',
  'curd': 'দই',
  'butter': 'মাখন',
  'ghee': 'ঘি',
  // Oils & liquids
  'oil': 'তেল',
  'mustard oil': 'সরিষার তেল',
  'water': 'পানি',
  // Seasonings
  'salt': 'লবণ',
  'sugar': 'চিনি',
  'pepper': 'গোলমরিচ',
  'bay leaf': 'তেজপাতা',
  'cardamom': 'এলাচ',
  'cinnamon': 'দারুচিনি',
  'cloves': 'লবঙ্গ',
  // Misc
  'tea': 'চা',
};

/// Translates a single ingredient name string to Bangla if it (or any of
/// its whitespace-separated tokens) is present in [_kIngredientEnToBn].
/// Returns the input unchanged when no mapping exists, so callers can
/// safely use it as a drop-in for any name.
String bnIngredientName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  // Whole-phrase lookup first.
  final whole = _kIngredientEnToBn[trimmed.toLowerCase()];
  if (whole != null) return whole;
  // Token-level lookup (longest tokens first so "green chili" beats "chili").
  final tokens = trimmed.toLowerCase().split(RegExp(r'[\s,]+'));
  final reordered = [...tokens]..sort((a, b) => b.length.compareTo(a.length));
  for (final t in reordered) {
    final mapped = _kIngredientEnToBn[t];
    if (mapped != null) return mapped;
  }
  return trimmed;
}

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  double _checkedProgress = 0;
  bool _cooking = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final favs = context.watch<FavoritesProvider>();
    final r = widget.recipe;
    final isFav = favs.isFavorite(r.id);
    final color = r.color;

    final steps = t.isBn ? r.stepsBn : r.stepsEn;
    final checkedCount = (_checkedProgress * steps.length).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(r.displayName(t.langCode)),
        actions: [
          IconButton(
            tooltip: isFav ? t.saved : t.save,
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            onPressed: () => favs.toggle(r.id),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // Hero
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Icon(r.icon, color: color, size: 80),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            r.displayName(t.langCode),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            r.displayDescription(t.langCode),
            style: const TextStyle(color: Color(0xFF555555), height: 1.4),
          ),
          const SizedBox(height: 16),

          // Info chips row
          Row(
            children: [
              Expanded(
                child: _infoBox(
                  Icons.timer_outlined,
                  t.cookingTime,
                  '${r.cookingMinutes} ${t.minutes}',
                  const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoBox(
                  Icons.account_balance_wallet_outlined,
                  t.cost,
                  '${t.taka}${r.costTaka} ${t.perServing}',
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoBox(
                  Icons.signal_cellular_alt,
                  t.difficulty,
                  t.difficultyLabel(r.difficulty),
                  t.difficultyColor(r.difficulty),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoBox(
            Icons.people_outline,
            t.servings,
            '${r.servings}',
            AppTheme.primary,
            fullWidth: true,
          ),

          const SizedBox(height: 24),
          // Ingredients
          Text(t.ingredients,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...r.ingredients.map(
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEE5DE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shopping_basket_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.isBn ? bnIngredientName(i.nameBn) : i.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    i.quantity,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          // Steps
          Row(
            children: [
              Text(t.steps,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_cooking)
                Text(
                  '$checkedCount / ${steps.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _checkedProgress,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.10),
            color: AppTheme.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),

          ...List.generate(steps.length, (i) {
            final isChecked = (checkedCount > i);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _cooking
                  ? () {
                      setState(() {
                        if (isChecked) {
                          _checkedProgress =
                              (i / steps.length).clamp(0.0, 1.0);
                        } else {
                          _checkedProgress =
                              ((i + 1) / steps.length).clamp(0.0, 1.0);
                        }
                        if (_checkedProgress >= 1.0) _done = true;
                      });
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _cooking && isChecked
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEE5DE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: _cooking && isChecked
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.10),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _cooking && isChecked
                              ? Colors.white
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          height: 1.4,
                          decoration: _cooking && isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: _cooking && isChecked
                              ? const Color(0xFF7B7B7B)
                              : const Color(0xFF1F1F1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (!_cooking) {
                setState(() {
                  _cooking = true;
                  _checkedProgress = 0;
                  _done = false;
                });
              } else if (!_done) {
                setState(() {
                  _checkedProgress = 1.0;
                  _done = true;
                });
              } else {
                setState(() {
                  _cooking = false;
                  _checkedProgress = 0;
                  _done = false;
                });
              }
            },
            icon: Icon(_done
                ? Icons.refresh
                : (_cooking ? Icons.restaurant : Icons.play_arrow)),
            label: Text(_done
                ? t.cookNow
                : (_cooking ? 'Mark all done' : t.cookNow)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _done ? AppTheme.secondary : AppTheme.primary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(
      IconData icon, String label, String value, Color color,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ],
      ),
    );
  }
}