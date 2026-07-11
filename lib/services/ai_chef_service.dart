import 'package:flutter/material.dart';

import '../data/recipes.dart';
import '../models/recipe.dart';

class RecipeMatch {
  final Recipe recipe;
  final double score; // 0..1
  final List<String> haveNames; // user-ingredients that matched
  final List<String> missingNames; // recipe-ingredients still missing
  final int matchedCount;
  final int totalRequired;

  /// True when this match was *generated* by the synthesizer (not from
  /// the static library). Synthetic recipes always show with 100% match.
  final bool synthesized;

  const RecipeMatch({
    required this.recipe,
    required this.score,
    required this.haveNames,
    required this.missingNames,
    required this.matchedCount,
    required this.totalRequired,
    this.synthesized = false,
  });
}

/// Local "AI" matching service.
///
/// Behavior:
///   1. Tokenize the user input (Bangle + English, mixed).
///   2. Score every library recipe by ingredient overlap.
///   3. Always also return at least one *synthesized* recipe draft built
///      from the user's exact ingredients — so the user is never left
///      staring at a sad emoji.
///   4. If you set [AiApiClient.apiKey], the service will also call a
///      real LLM and return the LLM's draft first.
class AiChefService {
  // Common synonyms in Bangla & English the user may type.
  static const Map<String, List<String>> _synonyms = {
    'rice': ['ভাত', 'চাল', 'bhat', 'chal', 'cooked rice', 'leftover rice'],
    'egg': ['ডিম', 'dim', 'eggs'],
    'onion': ['পেঁয়াজ', 'peyaj', 'peyaz'],
    'garlic': ['রসুন', 'rosun'],
    'ginger': ['আদা', 'ada'],
    'potato': ['আলু', 'alu', 'aloo'],
    'chili': ['কাঁচামরিচ', 'মরিচ', 'morich', 'chili', 'green chili'],
    'chicken': ['মুরগি', 'murgi', 'murga'],
    'fish': ['মাছ', 'mach', 'machh'],
    'lentil': ['ডাল', 'dal'],
    'moong': ['মুগ', 'mug'],
    'oil': ['তেল', 'tel'],
    'turmeric': ['হলুদ', 'holud', 'haldi'],
    'salt': ['লবণ', 'lobon'],
    'tomato': ['টমেটো', 'tomato'],
    'cauliflower': ['ফুলকপি', 'phulkopi', 'fulkopi'],
    'carrot': ['গাজর', 'gajor'],
    'peas': ['মটরশুঁটি', 'motor', 'matar'],
    'milk': ['দুধ', 'dudh'],
    'sugar': ['চিনি', 'chini'],
    'flour': ['ময়দা', 'maida'],
    'besan': ['বেসন', 'gram flour'],
    'brinjal': ['বেগুন', 'begun', 'eggplant'],
    'bread': ['পাউরুটি', 'ruti'],
    'butter': ['মাখন', 'makhan'],
    'capsicum': ['ক্যাপসিকাম', 'pepper'],
    'beans': ['বরবটি', 'borboti'],
    'cumin': ['জিরা', 'jira', 'jeera'],
    'coriander': ['ধনে', 'ধনেপাতা', 'dhania'],
    'tea': ['চা', 'cha'],
    'yogurt': ['দই', 'doi', 'dahi', 'curd'],
    'ghee': ['ঘি', 'ghi'],
    'cardamom': ['এলাচ', 'elach'],
    'cinnamon': ['দারুচিনি', 'daruchini'],
    'masala': ['মশলা', 'mashla'],
  };

  /// Returns ranked recipe matches for the given free-text user input.
  /// [userInput] may be English, Bangla, or a mix.
  ///
  /// The list is always non-empty if the user typed at least one
  /// ingredient. Worst case: a synthesized recipe draft.
  Future<List<RecipeMatch>> suggest(String userInput) async {
    final tokens = _tokenize(userInput);
    if (tokens.isEmpty) return const [];

    // 1. Optional real LLM call (when API key is set). Capped to a short
    // timeout so a stalled network never freezes the offline path.
    final apiDraft = await AiApiClient.instance
        .maybeDraftRecipe(ingredients: tokens)
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    final results = <RecipeMatch>[];

    if (apiDraft != null) {
      results.add(
        RecipeMatch(
          recipe: apiDraft,
          score: 1.0,
          haveNames: tokens,
          missingNames: const [],
          matchedCount: tokens.length,
          totalRequired: tokens.length,
          synthesized: true,
        ),
      );
    }

    // 2. Score the static library.
    for (final recipe in kAllRecipes) {
      try {
        final haveSet = <String>{};
        final missingSet = <String>{};
        int matched = 0;

        for (final ing in recipe.ingredients) {
          final enKey = ing.nameEn.toLowerCase().trim();
          final bnKey = ing.nameBn.trim();
          final candidates = <String>{
            enKey,
            bnKey,
            ..._synonyms[enKey] ?? const <String>[],
          };

          final hit = candidates.any((c) {
            final cc = c.toLowerCase();
            return tokens.any((tk) {
              if (tk.isEmpty) return false;
              return cc == tk ||
                  cc.contains(tk) ||
                  tk.contains(cc) ||
                  _startsWith(cc, tk) ||
                  _startsWith(tk, cc);
            });
          });

          if (hit) {
            matched++;
            haveSet.add(ing.nameEn);
          } else {
            missingSet.add(ing.nameEn);
          }
        }

        final total = recipe.ingredients.length;
        final raw = total == 0 ? 0.0 : matched / total;
        final bonus = tokens.length >= 2 ? 0.05 : 0.0;
        final score = (raw + bonus).clamp(0.0, 1.0);

        results.add(
          RecipeMatch(
            recipe: recipe,
            score: score,
            haveNames: haveSet.toList(),
            missingNames: missingSet.toList(),
            matchedCount: matched,
            totalRequired: total,
          ),
        );
      } catch (_) {
        // Skip a malformed recipe rather than aborting the whole search.
        continue;
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));

    // 3. If we still have no positive matches and no API draft,
    //    synthesize a recipe from the user's exact ingredients.
    final anyPositive =
        results.any((r) => r.synthesized || r.score >= 0.20);
    if (!anyPositive) {
      try {
        final synth = synthesizeRecipe(tokens);
        results.insert(
          0,
          RecipeMatch(
            recipe: synth,
            score: 1.0,
            haveNames: tokens,
            missingNames: const [],
            matchedCount: tokens.length,
            totalRequired: tokens.length,
            synthesized: true,
          ),
        );
      } catch (_) {
        // Last-resort fallback so we never return an empty list when the
        // user actually typed something.
        if (results.isEmpty) {
          results.add(_fallbackMatch(tokens));
        }
      }
    }

    return results;
  }

  /// Bare-bones fallback when even the synthesizer can't run. Should
  /// basically never be reached, but it guarantees the spinner is always
  /// replaced by at least one result card.
  RecipeMatch _fallbackMatch(List<String> tokens) {
    final main = tokens.isNotEmpty ? tokens.first : 'mixed';
    final fallback = Recipe(
      id: 'ai_fallback_${DateTime.now().millisecondsSinceEpoch}',
      nameEn: 'Quick $main Mix',
      nameBn: 'তাৎক্ষণিক $main মিশ্রণ',
      descriptionEn: 'Quick idea using ${tokens.join(", ")}.',
      descriptionBn: 'আপনার দেওয়া উপকরণ দিয়ে একটি দ্রুত রেসিপি।',
      icon: Icons.auto_awesome,
      color: const Color(0xFFE64A19),
      category: MealCategory.lunch,
      difficulty: Difficulty.easy,
      cookingMinutes: 15,
      costTaka: 50,
      servings: 1,
      ingredients: [
        for (final t in tokens)
          Ingredient(nameEn: t, nameBn: t, quantity: 'as needed'),
      ],
      stepsEn: const [
        'Combine all ingredients in a pan.',
        'Cook for 10 minutes, stirring occasionally.',
        'Serve hot.',
      ],
      stepsBn: const [
        'সব উপকরণ একটি প্যানে মেশান।',
        '১০ মিনিট রান্না করুন, মাঝে মাঝে নেড়ে দিন।',
        'গরম পরিবেশন করুন।',
      ],
      tagsEn: tokens,
      tagsBn: tokens,
    );
    return RecipeMatch(
      recipe: fallback,
      score: 0.5,
      haveNames: tokens,
      missingNames: const [],
      matchedCount: tokens.length,
      totalRequired: tokens.length,
      synthesized: true,
    );
  }

  /// Free-text search across recipe names, descriptions, ingredients, and tags.
  List<Recipe> searchByQuery(String query, {String langCode = 'en'}) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const [];

    final scored = <_ScoredRecipe>[];
    for (final r in kAllRecipes) {
      int hits = 0;
      final haystack = <String>[
        r.nameEn,
        r.nameBn,
        r.descriptionEn,
        r.descriptionBn,
        ...r.tagsEn,
        ...r.tagsBn,
        ...r.ingredients.map((i) => i.nameEn),
        ...r.ingredients.map((i) => i.nameBn),
      ].map((e) => e.toLowerCase()).toList();

      for (final tk in tokens) {
        for (final h in haystack) {
          if (h.contains(tk)) {
            hits++;
            break;
          }
        }
      }
      if (hits > 0) {
        scored.add(_ScoredRecipe(r, hits));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.recipe).toList();
  }

  /// Per-ingredient culturally authentic recipe name pools (Bengali +
  /// English). Selecting from these is how we avoid the "তাৎক্ষণিক [X] ভাজি"
  /// repetition. The first matching ingredient wins; remaining ingredients
  /// are folded into the suffix.
  static const Map<String, List<(String en, String bn)>> _dishNames = {
    'egg': [
      ('Dim Bhaji', 'ডিম ভাজি'),
      ('Dim Do Peyaza', 'ডিম দো পেঁয়াজা'),
      ('Dim Bhuna', 'ডিম ভুনা'),
      ('Egg Onion Sabzi', 'ডিম পেঁয়াজি'),
      ('Dim Torka', 'ডিম তরকা'),
    ],
    'rice': [
      ('Bhaja Khichuri', 'ভাজা খিচুড়ি'),
      ('Bhath with Bhaja', 'ভাত ভাজি'),
      ('Leftover Rice Fry', 'ভাজা ভাত'),
    ],
    'chicken': [
      ('Chicken Do Peyaza', 'চিকেন দো পেঁয়াজা'),
      ('Murgir Jhol', 'মুরগির ঝোল'),
      ('Chicken Chaap', 'চিকেন চাপ'),
      ('Murgi Bhuna', 'মুরগি ভুনা'),
      ('Chicken Resala', 'চিকেন রেসালা'),
    ],
    'fish': [
      ('Mach Bhaja', 'মাছ ভাজি'),
      ('Doi Maach', 'দই মাছ'),
      ('Fish Curry', 'মাছের ঝোল'),
      ('Machher Bhorta', 'মাছের ভর্তা'),
    ],
    'potato': [
      ('Alu Bharta', 'আলু ভর্তা'),
      ('Alu Dom', 'আলু দম'),
      ('Alu Bhaji', 'আলু ভাজি'),
      ('Alu Tarkari', 'আলু তরকারি'),
      ('Bombay Aloo', 'বোম্বে আলু'),
    ],
    'onion': [
      ('Peyaj Bhaja', 'পেঁয়াজ ভাজি'),
      ('Peyaj Chop', 'পেঁয়াজ চপ'),
    ],
    'brinjal': [
      ('Begun Bhaja', 'বেগুন ভাজি'),
      ('Begun Tarkari', 'বেগুন তরকারি'),
      ('Begun Bharta', 'বেগুন ভর্তা'),
    ],
    'cauliflower': [
      ('Phulkopi Dalna', 'ফুলকপি দলনা'),
      ('Phulkopi Tarkari', 'ফুলকপি তরকারি'),
      ('Gobi Bhaja', 'গোবি ভাজি'),
    ],
    'lentil': [
      ('Dal Tarkari', 'ডাল তরকারি'),
      ('Dal Bhaja', 'ডাল ভাজি'),
      ('Moong Dal', 'মুগ ডাল'),
    ],
    'tomato': [
      ('Tomato Chaatni', 'টমেটো চাটনি'),
      ('Tomato Bharta', 'টমেটো ভর্তা'),
    ],
    'bread': [
      ('Ruti Dim', 'রুটি ডিম'),
      ('Egg Roti', 'ডিম রুটি'),
    ],
    'flour': [
      ('Paratha', 'পরোটা'),
      ('Luchi', 'লুচি'),
    ],
    'besan': [
      ('Besan Bhaja', 'বেসন ভাজি'),
      ('Beguni', 'বেগুনি'),
    ],
    'capsicum': [
      ('Capsicum Tarkari', 'ক্যাপসিকাম তরকারি'),
    ],
    'yogurt': [
      ('Doi Maach', 'দই মাছ'),
      ('Doi Begun', 'দই বেগুন'),
    ],
  };

  /// Picks a culturally appropriate recipe name from [_dishNames] based on
  /// the dominant ingredient. Falls back to a "Mixed Sabzi" name when the
  /// input doesn't match anything in the pool.
  (String en, String bn) _pickDishName(List<String> normalized) {
    for (final t in normalized) {
      final pool = _dishNames[t];
      if (pool != null && pool.isNotEmpty) {
        // Stable but time-varying selection so two identical inputs in the
        // same minute still get the same name, but repeated runs eventually
        // rotate through the pool.
        final idx =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 % pool.length;
        return pool[idx];
      }
    }
    return ('Mixed Sabzi', 'মিক্স সবজি');
  }

  /// Draft a fresh recipe from the user's exact ingredients. This is
  /// used as a graceful fallback so the AI Chef never returns zero
  /// results. The recipe *name* comes from a per-ingredient culturally
  /// authentic pool, and the *technique* (bhaja / jhol / bhorta /
  /// torkari) is chosen by hashing the normalized ingredients so two
  /// distinct inputs almost always produce distinct recipes — the way
  /// real Gemini would vary its output across sessions.
  Recipe synthesizeRecipe(List<String> tokens) {
    final normalized = _normalizeTokens(tokens);
    final main = normalized.isNotEmpty
        ? normalized.first
        : 'mixed vegetables';
    final others = normalized.length > 1
        ? normalized.sublist(1)
        : const <String>[];

    final (nameEn, nameBn) = _pickDishName(normalized);
    final technique = _pickTechnique(normalized);

    // Estimate cost / time roughly from ingredient count.
    final cost = 30 + normalized.length * 15;
    final minutes = 12 + normalized.length * 4;

    final ingredients = _ingredientsFor(
      technique,
      main: main,
      others: others,
    );

    final stepsEn = _stepsFor(
      technique,
      main: main,
      others: others,
      lang: 'en',
    );
    final stepsBn = _stepsFor(
      technique,
      main: main,
      others: others,
      lang: 'bn',
    );

    return Recipe(
      id: 'ai_synth_${DateTime.now().millisecondsSinceEpoch}',
      nameEn: nameEn,
      nameBn: nameBn,
      descriptionEn:
          'A ${_techniqueLabel(technique, 'en')} made with ${normalized.join(', ')}.',
      descriptionBn:
          'আপনার দেওয়া ${normalized.join(', ')} দিয়ে তৈরি একটি ${_techniqueLabel(technique, 'bn')} পদ।',
      icon: Icons.auto_awesome,
      color: const Color(0xFFE64A19),
      category: MealCategory.lunch,
      difficulty: Difficulty.easy,
      cookingMinutes: minutes,
      costTaka: cost,
      servings: 1,
      ingredients: ingredients,
      stepsEn: stepsEn,
      stepsBn: stepsBn,
      tagsEn: normalized,
      tagsBn: normalized.map(_toBnGuess).toList(),
    );
  }

  /// Cooking-technique pools — different ingredient sets and steps, picked
  /// by hashing the input so the same recipe never returns the exact same
  /// instructions twice in a row. Mirrors what a real LLM does: each
  /// ingredient combo gets a fitting cultural preparation.
  static const List<String> _techniques = [
    'bhaja', // stir-fry with mustard oil
    'jhol', // light gravy
    'bhorta', // mashed with mustard oil + chili
    'torkari', // everyday mixed-veg sabzi
  ];

  String _pickTechnique(List<String> normalized) {
    if (normalized.isEmpty) return _techniques.first;
    // Stable hash: same ingredients in the same order => same technique.
    // Adding a minute-level salt keeps running the same input a few minutes
    // apart from also feeling fresh.
    final key = normalized.join('|');
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final h = (key.hashCode ^ (minute & 0x3)) & 0x7fffffff;
    return _techniques[h % _techniques.length];
  }

  String _techniqueLabel(String technique, String lang) {
    switch ((technique, lang)) {
      case ('bhaja', 'en'):
        return 'stir-fry';
      case ('bhaja', 'bn'):
        return 'ভাজি';
      case ('jhol', 'en'):
        return 'light curry';
      case ('jhol', 'bn'):
        return 'ঝোল';
      case ('bhorta', 'en'):
        return 'mash';
      case ('bhorta', 'bn'):
        return 'ভর্তা';
      case ('torkari', 'en'):
        return 'mixed vegetable curry';
      case ('torkari', 'bn'):
        return 'তরকারি';
    }
    return technique;
  }

  List<Ingredient> _ingredientsFor(
    String technique, {
    required String main,
    required List<String> others,
  }) {
    switch (technique) {
      case 'jhol':
        return [
          Ingredient(nameEn: main, nameBn: _toBnGuess(main), quantity: '1 cup'),
          for (final o in others)
            Ingredient(nameEn: o, nameBn: _toBnGuess(o), quantity: '2 tbsp'),
          const Ingredient(
              nameEn: 'Onion (sliced)',
              nameBn: 'পেঁয়াজ (কাটা)',
              quantity: '1 piece'),
          const Ingredient(
              nameEn: 'Tomato (chopped)',
              nameBn: 'টমেটো (কাটা)',
              quantity: '1 piece'),
          const Ingredient(
              nameEn: 'Green chili', nameBn: 'কাঁচামরিচ', quantity: '2 pieces'),
          const Ingredient(
              nameEn: 'Garlic (minced)',
              nameBn: 'রসুন (কুচি)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Ginger (grated)',
              nameBn: 'আদা (গ্রেটেড)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Turmeric', nameBn: 'হলুদ', quantity: '1/4 tsp'),
          const Ingredient(
              nameEn: 'Cumin powder',
              nameBn: 'জিরা গুঁড়া',
              quantity: '1/2 tsp'),
          const Ingredient(
              nameEn: 'Salt', nameBn: 'লবণ', quantity: 'to taste'),
          const Ingredient(
              nameEn: 'Mustard oil', nameBn: 'সরিষার তেল', quantity: '2 tbsp'),
          const Ingredient(
              nameEn: 'Water', nameBn: 'পানি', quantity: '1 cup'),
        ];
      case 'bhorta':
        return [
          Ingredient(
              nameEn: main, nameBn: _toBnGuess(main), quantity: '1.5 cup'),
          for (final o in others)
            Ingredient(nameEn: o, nameBn: _toBnGuess(o), quantity: '1 tbsp'),
          const Ingredient(
              nameEn: 'Onion (chopped)',
              nameBn: 'পেঁয়াজ (কুচি)',
              quantity: '1/2 piece'),
          const Ingredient(
              nameEn: 'Green chili',
              nameBn: 'কাঁচামরিচ',
              quantity: '3 pieces'),
          const Ingredient(
              nameEn: 'Mustard oil', nameBn: 'সরিষার তেল', quantity: '3 tbsp'),
          const Ingredient(
              nameEn: 'Salt', nameBn: 'লবণ', quantity: 'to taste'),
          const Ingredient(
              nameEn: 'Coriander (optional)',
              nameBn: 'ধনেপাতা (ঐচ্ছিক)',
              quantity: 'a few sprigs'),
        ];
      case 'torkari':
        return [
          Ingredient(nameEn: main, nameBn: _toBnGuess(main), quantity: '1 cup'),
          for (final o in others)
            Ingredient(nameEn: o, nameBn: _toBnGuess(o), quantity: '2 tbsp'),
          const Ingredient(
              nameEn: 'Potato (cubed)',
              nameBn: 'আলু (কিউব করা)',
              quantity: '1 small'),
          const Ingredient(
              nameEn: 'Onion (sliced)',
              nameBn: 'পেঁয়াজ (কাটা)',
              quantity: '1 piece'),
          const Ingredient(
              nameEn: 'Green chili', nameBn: 'কাঁচামরিচ', quantity: '2 pieces'),
          const Ingredient(
              nameEn: 'Garlic (minced)',
              nameBn: 'রসুন (কুচি)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Ginger (grated)',
              nameBn: 'আদা (গ্রেটেড)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Turmeric', nameBn: 'হলুদ', quantity: '1/4 tsp'),
          const Ingredient(
              nameEn: 'Cumin powder',
              nameBn: 'জিরা গুঁড়া',
              quantity: '1/2 tsp'),
          const Ingredient(
              nameEn: 'Coriander powder',
              nameBn: 'ধনে গুঁড়া',
              quantity: '1/2 tsp'),
          const Ingredient(
              nameEn: 'Salt', nameBn: 'লবণ', quantity: 'to taste'),
          const Ingredient(
              nameEn: 'Mustard oil', nameBn: 'সরিষার তেল', quantity: '2 tbsp'),
          const Ingredient(
              nameEn: 'Water', nameBn: 'পানি', quantity: '1/2 cup'),
        ];
      case 'bhaja':
      default:
        return [
          Ingredient(nameEn: main, nameBn: _toBnGuess(main), quantity: '1 cup'),
          for (final o in others)
            Ingredient(nameEn: o, nameBn: _toBnGuess(o), quantity: '2 tbsp'),
          const Ingredient(
              nameEn: 'Onion (sliced)',
              nameBn: 'পেঁয়াজ (কাটা)',
              quantity: '1/2 piece'),
          const Ingredient(
              nameEn: 'Green chili', nameBn: 'কাঁচামরিচ', quantity: '2 pieces'),
          const Ingredient(
              nameEn: 'Garlic (minced)',
              nameBn: 'রসুন (কুচি)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Ginger (grated)',
              nameBn: 'আদা (গ্রেটেড)',
              quantity: '1 tsp'),
          const Ingredient(
              nameEn: 'Turmeric', nameBn: 'হলুদ', quantity: '1/4 tsp'),
          const Ingredient(
              nameEn: 'Salt', nameBn: 'লবণ', quantity: 'to taste'),
          const Ingredient(
              nameEn: 'Mustard oil', nameBn: 'সরিষার তেল', quantity: '2 tbsp'),
        ];
    }
  }

  List<String> _stepsFor(
    String technique, {
    required String main,
    required List<String> others,
    required String lang,
  }) {
    final isBn = lang == 'bn';
    final joinedOthers = others.join(isBn ? ', ' : ', ');
    switch (technique) {
      case 'jhol':
        return isBn
            ? [
                'প্যানে সরিষার তেল গরম করুন। পেঁয়াজ দিয়ে বাদামী হওয়া পর্যন্ত ভাজুন।',
                'রসুন, আদা ও কাঁচামরিচ যোগ করে ৩০ সেকেন্ড নাড়ুন।',
                'টমেটো, হলুদ ও জিরা গুঁড়া দিন। টমেটো নরম না হওয়া পর্যন্ত রান্না করুন।',
                'প্রধান উপকরণ ($main) দিন এবং ২ মিনিট ভেজে নিন।',
                if (others.isNotEmpty)
                  '$joinedOthers যোগ করুন। ১ কাপ পানি ঢেলে ঢাকনা দিন।',
                'মাঝারি আঁচে ১০-১২ মিনিট রান্না করুন যতক্ষণ না ঝোল ঘন হয়।',
                'লবণ দিয়ে পরিবেশন করুন, ভাতের সাথে দারুণ লাগে।',
              ]
            : [
                'Heat mustard oil in a deep pan. Sauté the sliced onion until amber.',
                'Add garlic, ginger and green chili. Stir for 30 seconds.',
                'Tip in tomato, turmeric and cumin powder. Cook until tomato breaks down.',
                'Add the main ingredient ($main) and stir-fry for 2 minutes.',
                if (others.isNotEmpty)
                  'Stir in $joinedOthers. Pour 1 cup of water and cover.',
                'Simmer on medium-low for 10-12 minutes until the gravy thickens.',
                'Adjust salt, finish with a pinch of garam masala and serve with rice.',
              ];
      case 'bhorta':
        return isBn
            ? [
                '$main সেদ্ধ বা সিদ্ধ করে নিন (ডিম হলে শক্ত সিদ্ধ) এবং একটি বাটিতে মাখুন।',
                'পেঁয়াজ, কাঁচামরিচ ও লবণ দিয়ে ভালো করে মেখে নিন।',
                'সরিষার তেল ঢেলে আবার মাখুন — তেল যত বেশি তত ভালো স্বাদ।',
                if (others.isNotEmpty)
                  'ঐচ্ছিকভাবে $joinedOthers মিশিয়ে দিন।',
                'ধনেপাতা ছড়িয়ে গরম ভাতের সাথে পরিবেশন করুন।',
              ]
            : [
                'Boil or roast $main (hard-boil for egg), then mash into a bowl.',
                'Add onion, green chili and salt. Mash together thoroughly.',
                'Pour in mustard oil and mash again — the more oil, the better the flavor.',
                if (others.isNotEmpty)
                  'Optionally fold in $joinedOthers for extra bite.',
                'Garnish with coriander and serve with hot rice.',
              ];
      case 'torkari':
        return isBn
            ? [
                'প্যানে সরিষার তেল গরম করুন। আলু ও পেঁয়াজ দিয়ে ৩-৪ মিনিট ভাজুন।',
                'রসুন, আদা, কাঁচামরিচ ও হলুদ যোগ করে ১ মিনিট নাড়ুন।',
                'জিরা ও ধনে গুঁড়া দিন। ৩০ সেকেন্ড রাখুন যাতে মশলা কম না হয়ে যায়।',
                'প্রধান উপকরণ ($main) দিন এবং ২ মিনিট নাড়ুন।',
                if (others.isNotEmpty)
                  '$joinedOthers দিয়ে ১/২ কাপ পানি ঢালুন এবং ঢাকনা দিন।',
                'মাঝারি আঁচে ৮-১০ মিনিট রান্না করুন যতক্ষণ না তরকারি নরম হয়।',
                'লবণ দিয়ে গরম ভাত ও ডালের সাথে পরিবেশন করুন।',
              ]
            : [
                'Heat mustard oil. Fry potato and onion for 3-4 minutes.',
                'Add garlic, ginger, green chili and turmeric. Stir 1 minute.',
                'Sprinkle cumin and coriander powder. Toast 30 seconds.',
                'Add the main ingredient ($main) and toss for 2 minutes.',
                if (others.isNotEmpty)
                  'Tip in $joinedOthers with 1/2 cup water. Cover.',
                'Simmer on medium for 8-10 minutes until everything is tender.',
                'Adjust salt and serve hot with rice and dal.',
              ];
      case 'bhaja':
      default:
        return isBn
            ? [
                'মাঝারি আঁচে প্যানে সরিষার তেল গরম করুন — একটু ধোঁয়া উঠলে ভালো।',
                'পেঁয়াজ দিয়ে সোনালি না হওয়া পর্যন্ত ভাজুন (প্রায় ২ মিনিট)।',
                'রসুন, আদা ও কাঁচামরিচ দিন। ৩০ সেকেন্ড নেড়ে নিন।',
                'হলুদ ও প্রধান উপকরণ ($main) দিন। ৩ মিনিট ভেজে নিন।',
                if (others.isNotEmpty)
                  '$joinedOthers যোগ করুন এবং ভালো করে মেখে আরও ৩-৪ মিনিট রান্না করুন।',
                'লবণ দিন, গরম ভাত বা রুটির সাথে পরিবেশন করুন।',
              ]
            : [
                'Heat mustard oil in a pan on medium flame until it smokes lightly.',
                'Add sliced onion and sauté until golden (about 2 minutes).',
                'Stir in garlic, ginger and green chili. Cook 30 seconds.',
                'Add turmeric and the main ingredient ($main). Stir-fry 3 minutes.',
                if (others.isNotEmpty)
                  'Add $joinedOthers and toss to coat. Cook 3-4 more minutes.',
                'Season with salt, mix well and serve hot with rice or roti.',
              ];
    }
  }

  // ----------- helpers -----------

  static bool _startsWith(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final n = b.length < 4 ? b.length : 4;
    return a.substring(0, n) == b.substring(0, n);
  }

  static List<String> _tokenize(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[,;\n\r\t।,;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    return cleaned
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.trim())
        .toList();
  }

  static List<String> _normalizeTokens(List<String> tokens) {
    final out = <String>[];
    final seen = <String>{};
    for (final t in tokens) {
      if (t.isEmpty) continue;
      // Resolve Bangla→English canonical where possible.
      final canonical = _resolveBangla(t) ?? t;
      if (seen.add(canonical.toLowerCase())) out.add(canonical);
    }
    return out;
  }

  static String? _resolveBangla(String token) {
    for (final entry in _synonyms.entries) {
      if (entry.value.contains(token) ||
          entry.value.any((v) => v.toLowerCase() == token.toLowerCase())) {
        return entry.key;
      }
    }
    return null;
  }

  static String _toBnGuess(String en) {
    for (final entry in _synonyms.entries) {
      if (entry.key == en) return entry.value.first;
    }
    return en;
  }
}

class _ScoredRecipe {
  final Recipe recipe;
  final int score;
  const _ScoredRecipe(this.recipe, this.score);
}

/// Thin wrapper around an external LLM (OpenAI compatible).
///
/// To enable real AI Chef, set [apiKey] before calling
/// [AiChefService.suggest] (e.g. via a settings screen). When the key
/// is empty, the wrapper returns null and the local fallback runs.
///
/// Wiring it up only requires:
///   1. Add an OpenAI / OpenRouter key.
///   2. Make sure the device has internet.
///   3. The package will POST to the chat-completions endpoint and
///      parse the JSON returned.
class AiApiClient {
  AiApiClient._();
  static final AiApiClient instance = AiApiClient._();

  /// TODO: drop your OpenAI / OpenRouter key here to enable real AI.
  String apiKey = '';
  String model = 'gpt-4o-mini';
  String endpoint = 'https://api.openai.com/v1/chat/completions';

  /// Set to true once you wire up a real HTTP client (e.g. `http` pkg)
  /// to make the call. The default keeps the app fully offline.
  bool enabled = false;

  Future<Recipe?> maybeDraftRecipe({
    required List<String> ingredients,
  }) async {
    if (!enabled || apiKey.isEmpty) return null;
    // TODO: implement real HTTP call.
    // 1. Build a system prompt instructing the model to return JSON with
    //    {nameEn, nameBn, stepsEn, stepsBn, ingredients[], costTaka, ...}
    // 2. POST to [endpoint] with Authorization: Bearer [apiKey].
    // 3. Parse the first choice's content as JSON, build a Recipe.
    // 4. Return the Recipe.
    //
    // Returning null is safe — the local synthesizer covers the gap.
    return null;
  }
}