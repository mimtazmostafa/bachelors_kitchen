import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../models/recipe.dart';

import '../providers/language_provider.dart';

import '../services/ai_chef_service.dart';

import '../services/app_translations.dart';

import '../services/gemini_recipe_service.dart';

import '../theme/app_theme.dart';

import '../widgets/language_toggle.dart';

import '../widgets/recipe_card.dart';

import '../widgets/recipe_image.dart';



class AiChefScreen extends StatefulWidget {

  const AiChefScreen({super.key});



  @override

  State<AiChefScreen> createState() => _AiChefScreenState();

}



class _AiChefScreenState extends State<AiChefScreen> {

  final _controller = TextEditingController();

  List<RecipeMatch> _results = const [];

  bool _searched = false;

  bool _loading = false;

  _Mode _lastMode = _Mode.idle;

  String? _geminiError;

  List<String> _inputTokens = const [];

  RecipeDraft? _geminiDraft;

  final _service = AiChefService();

  final _gemini = GeminiRecipeService();



  static const _quickSuggestions = [

    'rice, egg, onion, chili',

    'potato, onion, chili, oil',

    'chicken, onion, garlic, ginger',

    'tomato, onion, garlic, oil',

    'besan, onion, chili, oil',

    'dal, onion, garlic, turmeric',

  ];



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  Future<void> _run() async {

    final input = _controller.text.trim();

    if (input.isEmpty) {

      setState(() {

        _searched = false;

        _results = const [];

        _inputTokens = const [];

        _geminiDraft = null;

        _geminiError = null;

        _lastMode = _Mode.idle;

      });

      return;

    }



    setState(() {

      _searched = true;

      _loading = true;

      _geminiError = null;

      _geminiDraft = null;

      _lastMode = _Mode.idle;

    });



    try {

      final isIngredientList = _looksLikeIngredientList(input);



      if (isIngredientList) {

        // Offline matching path — fast, no network needed.

        final results = await _service.suggest(input);

        if (!mounted) return;

        setState(() {

          _results = results;

          _inputTokens = _tokenize(input);

          _lastMode = _Mode.ingredients;

        });

        return;

      }



      // Free-text prompt: route to Gemini when configured, otherwise fall

      // back to the offline ingredient matcher so the screen still does

      // something useful.

      if (!_gemini.isConfigured) {

        final results = await _service.suggest(input);

        if (!mounted) return;

        setState(() {

          _results = results;

          _inputTokens = _tokenize(input);

          _geminiError =

              'Gemini API key not configured — showing offline AI match instead.';

          _lastMode = _Mode.ingredients;

        });

        return;

      }



      try {

        final draft = await _gemini.generateRecipe(input);

        if (!mounted) return;

        setState(() {

          _geminiDraft = draft;

          _inputTokens = const [];

          _lastMode = _Mode.gemini;

        });

      } on GeminiRecipeException catch (e) {

        if (!mounted) return;

        setState(() {

          _geminiError = e.message;

          _lastMode = _Mode.geminiError;

        });

      } catch (e) {

        if (!mounted) return;

        setState(() {

          _geminiError = 'Unexpected error: $e';

          _lastMode = _Mode.geminiError;

        });

      }

    } catch (e, st) {

      // Final safety net: if anything in the offline path throws (e.g. a

      // bad RecipeMatch from a future change), we still need to clear the

      // loading spinner so the user isn't stuck.

      debugPrint('AI Chef _run error: $e\n$st');

      if (!mounted) return;

      setState(() {

        _geminiError = 'AI Chef failed: $e';

        _lastMode = _Mode.geminiError;

      });

    } finally {

      if (mounted) {

        setState(() => _loading = false);

      }

    }

  }



  /// Heuristic: comma-separated input or many short tokens = ingredient list.

  /// Anything else (a full sentence) is treated as a free-text prompt.

  bool _looksLikeIngredientList(String input) {

    final hasComma = input.contains(',') || input.contains(';');

    final tokens = input

        .toLowerCase()

        .split(RegExp(r'[\s,;]+'))

        .where((t) => t.isNotEmpty);

    final shortTokens = tokens.where((t) => t.length <= 18).length;

    final isShort = input.length <= 50;

    return hasComma || (isShort && shortTokens >= 2);

  }



  static List<String> _tokenize(String s) => s

      .toLowerCase()

      .replaceAll(RegExp(r'[,;\n\r\t]+'), ' ')

      .split(' ')

      .where((w) => w.trim().isNotEmpty)

      .toList();



  @override

  Widget build(BuildContext context) {

    final t = context.watch<LanguageProvider>().t;

    final isBn = t.isBn;



    return Scaffold(

      appBar: AppBar(title: Text(t.aiChef)),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.only(bottom: 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              // Info banner — explains both ingredient-list AND free-text use

              Padding(

                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),

                child: Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: AppTheme.primary.withValues(alpha: 0.10),

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(

                      color: AppTheme.primary.withValues(alpha: 0.25),

                    ),

                  ),

                  child: Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Icon(Icons.psychology_alt,

                          color: AppTheme.primary, size: 28),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Text(

                          t.aiHint,

                          style: const TextStyle(

                            color: Color(0xFF1F1F1F),

                            height: 1.4,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ),



              // ONE unified input box for both ingredient lists and free-text prompts

              Padding(

                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),

                child: Row(

                  children: [

                    Expanded(

                      child: TextField(

                        controller: _controller,

                        minLines: 1,

                        maxLines: 3,

                        textInputAction: TextInputAction.done,

                        onSubmitted: (_) => _run(),

                        decoration: InputDecoration(

                          hintText: t.aiHint,

                          prefixIcon: const Padding(

                            padding: EdgeInsets.only(left: 12, right: 6),

                            child: Icon(Icons.kitchen, color: AppTheme.primary),

                          ),

                          prefixIconConstraints:

                              const BoxConstraints(minWidth: 40),

                        ),

                      ),

                    ),

                    const SizedBox(width: 10),

                    SizedBox(

                      height: 54,

                      child: ElevatedButton(

                        onPressed: _loading ? null : _run,

                        style: ElevatedButton.styleFrom(

                          shape: const StadiumBorder(),

                          padding: const EdgeInsets.symmetric(horizontal: 18),

                        ),

                        child: _loading

                            ? const SizedBox(

                                width: 18,

                                height: 18,

                                child: CircularProgressIndicator(

                                  strokeWidth: 2,

                                  color: Colors.white,

                                ),

                              )

                            : Text(t.findRecipes),

                      ),

                    ),

                  ],

                ),

              ),



          // Quick suggestions chips

          Padding(

            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),

            child: SingleChildScrollView(

              scrollDirection: Axis.horizontal,

              child: Row(

                children: _quickSuggestions.map((s) {

                  return Padding(

                    padding: const EdgeInsets.only(right: 8),

                    child: ActionChip(

                      label: Text(s, style: const TextStyle(fontSize: 12)),

                      backgroundColor: Colors.white,

                      side: const BorderSide(color: Color(0xFFEEE5DE)),

                      onPressed: () {

                        _controller.text = s;

                        _run();

                      },

                    ),

                  );

                }).toList(),

              ),

            ),

          ),



          // Ingredient chips once user has searched

          if (_searched && _inputTokens.isNotEmpty)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),

              child: SizedBox(

                height: 36,

                child: ListView.separated(

                  scrollDirection: Axis.horizontal,

                  itemCount: _inputTokens.length,

                  separatorBuilder: (_, __) => const SizedBox(width: 6),

                  itemBuilder: (_, i) {

                    final tk = _inputTokens[i];

                    return Chip(

                      label: Text(

                        tk,

                        style: const TextStyle(

                          fontSize: 12,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                      visualDensity: VisualDensity.compact,

                      backgroundColor:

                          AppTheme.secondary.withValues(alpha: 0.12),

                      side: BorderSide(

                        color: AppTheme.secondary.withValues(alpha: 0.35),

                      ),

                    );

                  },

                ),

              ),

            ),



          const SizedBox(height: 4),



          // Gemini error banner (shown only when the last attempt failed)

          if (_lastMode == _Mode.geminiError && _geminiError != null)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),

              child: Container(

                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(

                  color: const Color(0xFFFFEBEB),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: const Color(0xFFE0B0B0)),

                ),

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Icon(Icons.error_outline,

                        color: Color(0xFFB00020), size: 18),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        _geminiError!,

                        style: const TextStyle(

                          color: Color(0xFFB00020),

                          fontSize: 12,

                          height: 1.4,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ),



          // Unified results body — switches on _lastMode

          if (!_searched)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),

              child: _idleView(t.aiEmpty, isBn: isBn),

            )

          else if (_lastMode == _Mode.gemini && _geminiDraft != null)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),

              child: _geminiResultCard(_geminiDraft!, t, isBn: isBn),

            )

          else if (_lastMode == _Mode.gemini)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),

              child: Center(

                child: Text(

                  t.aiGenerating,

                  style: const TextStyle(

                    color: AppTheme.primary,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

            )

          else if (_results.isEmpty)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),

              child: _noResultsView(t, isBn: isBn),

            )

          else

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  for (int i = 0; i < _results.length; i++) ...[

                    if (i > 0) const SizedBox(height: 14),

                    _matchBadge(_results[i], t, isBn: isBn),

                    const SizedBox(height: 8),

                    if (_results[i].synthesized)

                      _synthHeader(t, isBn: isBn)

                    else

                      RecipeCard(

                        recipe: _results[i].recipe,

                        matchPercent: _results[i].score,

                      ),

                    if (_results[i].synthesized)

                      _synthCard(_results[i].recipe, t, isBn: isBn),

                    if (!_results[i].synthesized &&

                        _results[i].missingNames.isNotEmpty)

                      Padding(

                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),

                        child: Text(

                          '${t.missing}: ${_results[i].missingNames.join(', ')}',

                          style: const TextStyle(

                            color: Color(0xFF777777),

                            fontSize: 12,

                          ),

                        ),

                      ),

                  ],

                ],

              ),

            ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _synthHeader(AppTranslations t, {required bool isBn}) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Row(

        children: [

          const Icon(Icons.auto_awesome,

              size: 18, color: AppTheme.primary),

          const SizedBox(width: 6),

          Text(

            isBn ? 'AI রেসিপি' : 'AI recipe draft',
            style: const TextStyle(

              fontWeight: FontWeight.w800,

              color: AppTheme.primary,

              fontSize: 13,

            ),

          ),

        ],

      ),

    );

  }



  Widget _synthCard(Recipe r, AppTranslations t, {required bool isBn}) {

    final title = isBn ? r.nameBn : r.nameEn;

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: const [

          BoxShadow(

            color: Color(0x14000000),

            blurRadius: 18,

            offset: Offset(0, 6),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          ClipRRect(

            borderRadius:

                const BorderRadius.vertical(top: Radius.circular(20)),

            child: RecipeImage(

              recipe: r,

              emoji: emojiFor(r),

              height: 140,

            ),

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: const TextStyle(

                    fontSize: 18,

                    fontWeight: FontWeight.w800,

                    color: Color(0xFF1F1F1F),

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  isBn ? r.descriptionBn : r.descriptionEn,

                  style: const TextStyle(

                    color: Color(0xFF6F6F6F),

                    fontSize: 13,

                    height: 1.4,

                  ),

                ),

                const SizedBox(height: 12),

                Wrap(

                  spacing: 8,

                  runSpacing: 6,

                  children: [

                    _chip(Icons.timer, '${r.cookingMinutes} min'),

                    _chip(Icons.payments, '?${r.costTaka}'),

                    _chip(Icons.bar_chart, isBn ? '???' : 'Easy'),

                  ],

                ),

                const SizedBox(height: 14),

                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton.icon(

                    onPressed: () {

                      Navigator.of(context).push(

                        fadeRoute(_SynthDetailScreen(recipe: r)),

                      );

                    },

                    icon: const Icon(Icons.menu_book, size: 18),

                    label: Text(

                      isBn ? 'রান্নার ধাপ দেখুন' : 'See cooking steps',
                    ),

                    style: ElevatedButton.styleFrom(

                      shape: const StadiumBorder(),

                      padding: const EdgeInsets.symmetric(vertical: 12),

                    ),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _chip(IconData icon, String label) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(

        color: const Color(0xFFFFF3EC),

        borderRadius: BorderRadius.circular(20),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(icon, size: 14, color: AppTheme.primary),

          const SizedBox(width: 4),

          Text(

            label,

            style: const TextStyle(

              fontSize: 12,

              fontWeight: FontWeight.w700,

              color: Color(0xFF4A2A12),

            ),

          ),

        ],

      ),

    );

  }



  Widget _matchBadge(RecipeMatch m, AppTranslations t,

      {required bool isBn}) {

    final score = m.score;

    final color = score >= 0.99

        ? AppTheme.secondary

        : score >= 0.6

            ? AppTheme.primary

            : const Color(0xFF777777);

    final label = m.synthesized

        ? (isBn ? 'AI-এর পছন্দ' : "Chef\u2019s pick")

        : '${t.matchLabel(score)} \u2014 ${m.matchedCount}/${m.totalRequired}';

    return Row(

      children: [

        Container(

          padding:

              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

          decoration: BoxDecoration(

            color: color.withValues(alpha: 0.12),

            borderRadius: BorderRadius.circular(20),

          ),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(Icons.psychology_alt, size: 14, color: color),

              const SizedBox(width: 4),

              Text(

                label,

                style: TextStyle(

                  color: color,

                  fontSize: 11.5,

                  fontWeight: FontWeight.w800,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }



  Widget _idleView(String hint, {required bool isBn}) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Container(

              width: 110,

              height: 110,

              decoration: BoxDecoration(

                color: AppTheme.primary.withValues(alpha: 0.08),

                shape: BoxShape.circle,

              ),

              child: const Icon(

                Icons.restaurant_menu,

                size: 56,

                color: AppTheme.primary,

              ),

            ),

            const SizedBox(height: 18),

            Text(

              hint,

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: Color(0xFF777777),

                height: 1.4,

              ),

            ),

            const SizedBox(height: 8),

            Text(

              isBn

                  ? 'আপনার উপকরণ লিখুন — AI সাজেশন দেবে।'

                  : 'Type what you have \u2014 AI will draft a recipe.',

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: Color(0xFF9A9A9A),

                fontSize: 12.5,

                height: 1.4,

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _noResultsView(AppTranslations t, {required bool isBn}) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(28),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            const Icon(Icons.lightbulb,

                size: 64, color: Color(0xFFE0B589)),

            const SizedBox(height: 14),

            Text(

              isBn

                  ? 'হুম, বেশ কঠিন কম্বো! তবে চিন্তা নেই —'

                  : "Hmm, that's a tough combo! But don't worry \u2014",

              textAlign: TextAlign.center,

              style: const TextStyle(

                fontSize: 15,

                fontWeight: FontWeight.w700,

                color: Color(0xFF4A2A12),

                height: 1.4,

              ),

            ),

            const SizedBox(height: 6),

            Text(

              isBn

                  ? 'আপনার পছন্দের সাজেশন চিপে ট্যাপ করুন অথবা অন্য উপকরণ যোগ করুন।'

                  : 'Try a quick suggestion chip or add a different ingredient.',

              textAlign: TextAlign.center,

              style: const TextStyle(

                color: Color(0xFF777777),

                fontSize: 13,

                height: 1.4,

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _geminiResultCard(RecipeDraft d, AppTranslations t, {

        required bool isBn,

      }) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: const [

          BoxShadow(

            color: Color(0x14000000),

            blurRadius: 12,

            offset: Offset(0, 4),

          ),

        ],

      ),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Container(

                  padding:

                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                  decoration: BoxDecoration(

                    color: const Color(0xFFFFF1CC),

                    borderRadius: BorderRadius.circular(8),

                  ),

                  child: Text(

                    t.aiRecipeTitle,

                    style: const TextStyle(

                      fontSize: 10,

                      fontWeight: FontWeight.w800,

                      color: Color(0xFF8C6A1A),

                    ),

                  ),

                ),

                const SizedBox(width: 8),

                if (d.prepMinutes > 0)

                  Row(

                    children: [

                      const Icon(Icons.timer_outlined,

                          size: 14, color: Color(0xFF6B4900)),

                      const SizedBox(width: 3),

                      Text(

                        '${t.aiPrepTime}: ${d.prepMinutes} min',

                        style: const TextStyle(

                          fontSize: 12,

                          fontWeight: FontWeight.w600,

                          color: Color(0xFF6B4900),

                        ),

                      ),

                    ],

                  ),

              ],

            ),

            const SizedBox(height: 8),

            Text(

              d.title,

              style: const TextStyle(

                fontSize: 17,

                fontWeight: FontWeight.w800,

                color: Color(0xFF1F1F1F),

                height: 1.2,

              ),

            ),

            const SizedBox(height: 12),

            Text(

              t.aiIngredients,

              style: const TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w800,

                color: Color(0xFFB57A00),

              ),

            ),

            const SizedBox(height: 4),

            ...d.ingredients.map(

              (ing) => Padding(

                padding: const EdgeInsets.symmetric(vertical: 2),

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text('•  ',

                        style: TextStyle(

                            color: Color(0xFFB57A00),

                            fontWeight: FontWeight.w800)),

                    Expanded(

                      child: Text(

                        ing,

                        style: const TextStyle(

                          fontSize: 13,

                          color: Color(0xFF333333),

                          height: 1.35,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ),

            const SizedBox(height: 12),

            Text(

              t.aiSteps,

              style: const TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w800,

                color: Color(0xFFB57A00),

              ),

            ),

            const SizedBox(height: 4),

            ...List.generate(d.steps.length, (i) {

              return Padding(

                padding: const EdgeInsets.symmetric(vertical: 3),

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Container(

                      width: 20,

                      height: 20,

                      alignment: Alignment.center,

                      decoration: const BoxDecoration(

                        color: Color(0xFFB57A00),

                        shape: BoxShape.circle,

                      ),

                      child: Text(

                        '${i + 1}',

                        style: const TextStyle(

                          color: Colors.white,

                          fontSize: 11,

                          fontWeight: FontWeight.w800,

                        ),

                      ),

                    ),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        d.steps[i],

                        style: const TextStyle(

                          fontSize: 13,

                          color: Color(0xFF333333),

                          height: 1.4,

                        ),

                      ),

                    ),

                  ],

                ),

              );

            }),

          ],

        ),

      ),

    );

  }

}



enum _Mode {

  idle,

  ingredients,

  gemini,

  geminiError,

}



class _SynthDetailScreen extends StatelessWidget {

  final Recipe recipe;

  const _SynthDetailScreen({required this.recipe});



  @override

  Widget build(BuildContext context) {

    final t = context.watch<LanguageProvider>().t;

    final isBn = t.isBn;

    final steps = isBn ? recipe.stepsBn : recipe.stepsEn;

    return Scaffold(

      appBar: AppBar(

        title: Text(isBn ? recipe.nameBn : recipe.nameEn),

      ),

      body: ListView(

        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),

        children: [

          ClipRRect(

            borderRadius: BorderRadius.circular(20),

            child: RecipeImage(

              recipe: recipe,

              emoji: emojiFor(recipe),

              height: 200,

            ),

          ),

          const SizedBox(height: 14),

          Text(

            isBn ? 'উপকরণ' : 'Ingredients',
            style: const TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.w800,

            ),

          ),

          const SizedBox(height: 8),

          ...recipe.ingredients.map((i) => Padding(

                padding: const EdgeInsets.only(bottom: 4),

                child: Row(

                  children: [

                    const Icon(Icons.fiber_manual_record,

                        size: 6, color: AppTheme.primary),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        '${isBn ? i.nameBn : i.nameEn} \u2014 ${i.quantity}',

                      ),

                    ),

                  ],

                ),

              )),

          const SizedBox(height: 18),

          Text(

            isBn ? 'প্রণালী' : 'Steps',
            style: const TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.w800,

            ),

          ),

          const SizedBox(height: 8),

          for (int i = 0; i < steps.length; i++)

            Padding(

              padding: const EdgeInsets.only(bottom: 10),

              child: Row(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Container(

                    width: 26,

                    height: 26,

                    decoration: const BoxDecoration(

                      color: AppTheme.primary,

                      shape: BoxShape.circle,

                    ),

                    alignment: Alignment.center,

                    child: Text(

                      '${i + 1}',

                      style: const TextStyle(

                        color: Colors.white,

                        fontWeight: FontWeight.w800,

                      ),

                    ),

                  ),

                  const SizedBox(width: 10),

                  Expanded(

                    child: Text(

                      steps[i],

                      style: const TextStyle(

                        color: Color(0xFF1F1F1F),

                        fontSize: 14,

                        height: 1.5,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          const SizedBox(height: 12),

          Container(

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(

              color: AppTheme.secondary.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(16),

              border: Border.all(

                color: AppTheme.secondary.withValues(alpha: 0.30),

              ),

            ),

            child: Row(

              children: [

                const Icon(Icons.timer, color: AppTheme.secondary),

                const SizedBox(width: 8),

                Text(

                  '${recipe.cookingMinutes} ${isBn ? '?????' : 'min'} \u2014 ?${recipe.costTaka} \u2014 ${isBn ? '???' : 'Easy'}',

                  style: const TextStyle(

                    fontWeight: FontWeight.w700,

                    color: Color(0xFF1F3D2E),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}


