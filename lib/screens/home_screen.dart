import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipes.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_chip.dart';
import '../widgets/language_toggle.dart';
import '../widgets/recipe_card.dart';
import 'ai_chef_screen.dart';
import 'category_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _budgetIndex = 0; // 0 = All, 1..4 = under 50/100/150/200
  int _tipSeed = 0; // for "shake to refresh" of the rotating tip

  static const List<int?> _budgetCaps = [null, 50, 100, 150, 200];

  void _refreshTip() {
    setState(() {
      _tipSeed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    final cap = _budgetCaps[_budgetIndex];

    // Apply budget filter to featured recipes.
    final featured = kAllRecipes
        .where((r) => cap == null || r.costTaka <= cap)
        .take(6)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ---------- Top bar ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.appName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.tagline,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    LanguageToggle(isBn: t.isBn),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: t.search,
                      onPressed: () {
                        Navigator.push(
                          context,
                          fadeRoute(const SearchScreen()),
                        );
                      },
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
            ),

            // ---------- AI Chef banner ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                child: Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        fadeRoute(const AiChefScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.psychology_alt_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.aiChef,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.aiHint,
                                  style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---------- Categories title + Budget chips ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🗂', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          t.isBn ? 'বিভাগসমূহ' : 'Categories',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _BudgetChipRow(
                      selected: _budgetIndex,
                      onChanged: (i) => setState(() => _budgetIndex = i),
                      isBn: t.isBn,
                      labels: const [
                        'All',
                        '<৳50',
                        '<৳100',
                        '<৳150',
                        '<৳200',
                      ],
                      bnLabels: const [
                        'সব',
                        '<৳৫০',
                        '<৳১০০',
                        '<৳১৫০',
                        '<৳২০০',
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Category tiles ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              sliver: SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: CategoryUtils.all.length,
                itemBuilder: (context, i) {
                  final info = CategoryUtils.all[i];
                  return CategoryTile(
                    info: info,
                    isBn: t.isBn,
                    onTap: () {
                      Navigator.push(
                        context,
                        fadeRoute(CategoryScreen(category: info.category!)),
                      );
                    },
                  );
                },
              ),
            ),

            // ---------- Featured recipes ----------
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Text('🍳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      t.recipes,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              sliver: featured.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            t.isBn
                                ? 'এই বাজেটে কোনো রেসিপি পাওয়া যায়নি।'
                                : 'No recipes match this budget.',
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: featured.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        return RecipeCard(recipe: featured[i]);
                      },
                    ),
            ),

            // ---------- Bachelor tip card ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.tipTitle,
                                    style: const TextStyle(
                                      color: AppTheme.secondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: t.refresh,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: AppTheme.secondary,
                                  ),
                                  onPressed: _refreshTip,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: Text(
                                t.tipBodyForToday(seed: _tipSeed),
                                key: ValueKey(_tipSeed),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetChipRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final bool isBn;
  final List<String> labels;
  final List<String> bnLabels;

  const _BudgetChipRow({
    required this.selected,
    required this.onChanged,
    required this.isBn,
    required this.labels,
    required this.bnLabels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final picked = i == selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: picked
                  ? AppTheme.primary
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: picked
                    ? AppTheme.primary
                    : const Color(0xFFEEE5DE),
                width: 1.2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: Center(
                    child: Text(
                      isBn ? bnLabels[i] : labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: picked
                            ? Colors.white
                            : const Color(0xFF4A2A12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
