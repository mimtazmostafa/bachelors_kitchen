import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'app_translations.dart';

/// Immutable recipe draft returned by Gemini.
///
/// The new schema is Bangla-first:
///   * [recipeNameBn] / [recipeNameEn] — recipe title in both languages
///   * [ingredients] — list of [DraftIngredient]s (qty + name in both langs)
///   * [steps] — Bangla-only step strings (English falls back to Bangla)
///   * [costTaka] — integer ৳/Taka per serving
///   * [timeMinutes] — integer minutes (prep + cook)
///   * [difficultyBn] — one of "সহজ", "মাঝারি", "কঠিন"
///   * [bachelorTip] — short tip card text in Bangla
class RecipeDraft {
  final String recipeNameBn;
  final String recipeNameEn;
  final List<DraftIngredient> ingredients;
  final List<String> steps; // Bangla (English view falls back to Bangla)
  final int costTaka;
  final int timeMinutes;
  final String difficultyBn; // "সহজ" | "মাঝারি" | "কঠিন"
  final String bachelorTip;

  const RecipeDraft({
    required this.recipeNameBn,
    required this.recipeNameEn,
    required this.ingredients,
    required this.steps,
    required this.costTaka,
    required this.timeMinutes,
    required this.difficultyBn,
    required this.bachelorTip,
  });

  /// True if at least the title and one step are present.
  bool get isUsable =>
      (recipeNameBn.isNotEmpty || recipeNameEn.isNotEmpty) &&
      steps.isNotEmpty &&
      ingredients.isNotEmpty;
}

/// One ingredient line in a [RecipeDraft].
class DraftIngredient {
  final String nameBn;
  final String nameEn;
  final String quantity;

  const DraftIngredient({
    required this.nameBn,
    required this.nameEn,
    required this.quantity,
  });

  /// Display string in Bangla mode: "আলু — ২টা মাঝারি".
  String displayBn(AppTranslations _) => '$nameBn — $quantity';

  /// Display string in English mode: "Potato — 2 medium".
  String displayEn(AppTranslations _) => '$nameEn — $quantity';
}

/// Exception thrown by [GeminiRecipeService] when generation fails.
class GeminiRecipeException implements Exception {
  final String message;
  const GeminiRecipeException(this.message);
  @override
  String toString() => 'GeminiRecipeException: $message';
}

/// Isolated wrapper around the Gemini API for recipe generation.
///
/// Uses `gemini-2.0-flash` against the stable `v1` API endpoint.
/// `gemini-1.5-flash` was deprecated and is no longer discoverable on the
/// `v1beta` endpoint, which is why we pin both the model AND the API version.
///
/// API key resolution order:
///   1. `dotenv.env['GEMINI_API_KEY']` (loaded from the gitignored .env file)
///   2. Compile-time `--dart-define=GEMINI_API_KEY=...` override
///
/// Throws [GeminiRecipeException] with a user-friendly message on any failure
/// (missing key, network, parse error, refusal, etc.).
class GeminiRecipeService {
  /// Primary model — fast, free-tier friendly, available on `v1`.
  static const String defaultModel = 'gemini-2.0-flash';

  /// Stable GA API version. `v1beta` no longer lists 1.5-flash and returns
  /// "models/gemini-1.5-flash is not found for API version v1beta" errors.
  static const String _apiVersion = 'v1';

  /// Resolves the API key from .env or --dart-define.
  /// Returns `null` if no key is configured (callers should fall back).
  static String? resolveApiKey() {
    // 1. .env file (loaded at app startup via dotenv.load()).
    final fromEnv = dotenv.env['GEMINI_API_KEY']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty &&
        fromEnv != 'PASTE_YOUR_GEMINI_API_KEY_HERE') {
      return fromEnv;
    }
    // 2. Compile-time dart-define override.
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return null;
  }

  final String apiKey;
  final String modelName;

  GeminiRecipeService({
    String? apiKey,
    this.modelName = defaultModel,
  }) : apiKey = apiKey ?? resolveApiKey() ?? '';

  /// Returns true if a non-placeholder API key is available.
  bool get isConfigured => apiKey.isNotEmpty;

  /// Generates a recipe draft from a free-text user prompt.
  ///
  /// [userPrompt] is the natural-language request (e.g. "cheap chicken
  /// dinner with rice for one person"). The service embeds it in a strict
  /// system instruction that forces Gemini to return ONLY a JSON object.
  Future<RecipeDraft> generateRecipe(String userPrompt) async {
    if (userPrompt.trim().isEmpty) {
      throw const GeminiRecipeException(
          'Please describe what you want to cook.');
    }
    if (!isConfigured) {
      throw const GeminiRecipeException(
        'No Gemini API key configured. Paste your key into .env and restart the app.',
      );
    }

    // Build the model once with the pinned v1 API version.
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.95,
        maxOutputTokens: 1536,
        responseMimeType: 'application/json',
      ),
      // CRITICAL: Pin v1 so we don't hit the deprecated v1beta endpoint
      // where 1.5-flash returns "model not found".
      requestOptions: const RequestOptions(apiVersion: _apiVersion),
    );

    final systemInstruction = Content.system(_buildSystemPrompt());
    final userContent = Content.text(userPrompt.trim());

    final response = await model.generateContent(
      [systemInstruction, userContent],
    );

    final raw = response.text;
    if (raw == null || raw.trim().isEmpty) {
      throw const GeminiRecipeException(
        'Gemini returned an empty response. Please try again.',
      );
    }

    // Defensive UTF-8 sanity check: the google_generative_ai SDK already
    // returns a Dart String, but if any future code path drops to raw
    // bytes (e.g. switching to a hand-rolled http.Client), we want
    // bad decodes to throw a friendly error instead of silently mojibake-
    // ing the UI. Round-trip through latin1→utf8; a clean string survives
    // unchanged, a wrongly-decoded one surfaces as a FormatException.
    final sanitized = _assertUtf8Clean(raw);

    return _parseDraft(sanitized);
  }

  /// Throws [GeminiRecipeException] if [s] round-trips through
  /// `latin1 → utf8` differently from itself (a reliable signal that
  /// the string was mis-decoded). Returns [s] unchanged otherwise.
  String _assertUtf8Clean(String s) {
    try {
      final roundTrip = utf8.decode(latin1.encode(s));
      if (roundTrip != s) {
        throw const FormatException('UTF-8 round-trip mismatch');
      }
      return s;
    } on FormatException catch (e) {
      throw GeminiRecipeException(
        'Gemini response was not valid UTF-8: ${e.message}',
      );
    }
  }

  /// Strict system prompt — forces JSON-only output with a fixed schema.
  /// Bangla-first: every human-readable field is required in Bangla, and
  /// most fields also carry an English copy for non-Bangla UI mode.
  String _buildSystemPrompt() {
    return '''
You are an expert, creative Bangladeshi home chef who cooks for university
students and bachelors living alone on a tight budget. The user will describe
what they have on hand or what they want to eat. Your only job is to produce
a single, realistic, low-budget recipe a single student can cook with common
Bangladeshi kitchen tools.

OUTPUT RULES (mandatory):
- Respond with a single JSON object and NOTHING ELSE.
- No markdown fences, no commentary, no prose before or after the JSON.
- Use exactly this schema:
  {
    "recipe_name_bn": string,          // Bangla title, e.g. "ডিম পেঁয়াজ ভাজি"
    "recipe_name_en": string,          // English title, e.g. "Egg Onion Bhaji"
    "ingredients": [                   // 5-10 items, each an object
      {
        "name_bn": string,             // Bangla name, e.g. "ডিম"
        "name_en": string,             // English name, e.g. "Egg"
        "quantity": string             // Bangla quantity phrase, e.g. "৩টা"
      }
    ],
    "steps": [string, ...],            // EXACTLY 5 short imperative steps in Bangla
    "cost_taka": integer,              // estimated cost per serving in Taka (৳), 15-200
    "time_minutes": integer,           // total time in minutes (prep + cook), 5-60
    "difficulty_bn": string,           // MUST be exactly "সহজ", "মাঝারি", or "কঠিন"
    "bachelor_tip": string             // one short practical tip for a bachelor (Bangla)
  }

BANGLA CONTENT RULES (mandatory):
- All Bangla fields (recipe_name_bn, name_bn, steps, bachelor_tip) MUST be
  written in proper Bengali script. No transliteration, no Roman letters.
- Steps MUST be in Bangla (not English). Each step is one short imperative
  sentence in Bangla.
- Ingredient "quantity" field MUST also be in Bangla (e.g. "৩টা", "১ কাপ",
  "২ চা চামচ", "১/২ চিমটি"). Do NOT write quantities in English.
- difficulty_bn must be exactly one of the three Bangla words listed above.

CREATIVE NAMING (mandatory):
- DO NOT use generic placeholders like "Quick X Stir-Fry", "Easy X Dish",
  "X Bhaji", or "X Curry" unless the dish truly is a stir-fry / curry.
- The Bangla title must be a real Bangladeshi dish name, not "<ingredient> রেসিপি".
- Examples of the kind of variety expected:
    * eggs + onion + chili      → "ডিম পেঁয়াজ ভাজি" / "Dim Peyaj Bhaji"
    * chicken + onion + tomato  → "মুরগির ঝোল" / "Murgir Jhol"
    * potato + cauliflower      → "আলু ফুলকপি দলনা" / "Alu Phulkopi Dalna"
    * rice + lentil + onion     → "ভাজা খিচুড়ি" / "Bhaja Khichuri"
    * brinjal + tomato + chili  → "বেগুন তরকারি" / "Begun Tarkari"
    * plain bread + eggs        → "রুটি ডিম রোল" / "Ruti Dim Roll"

TEXT ENCODING (mandatory):
- Output clean, standard UTF-8 text. Write Bengali characters directly
  (e.g. "ডিম"), never as escapes like "\\u09A6\\u09BF\\u09AE".
- Do not HTML-encode, hex-encode, or otherwise mangle non-ASCII characters.

COOKING RULES (mandatory):
- cost_taka MUST be realistic for a bachelor in Bangladesh: 15-200 ৳/serving.
- time_minutes MUST be realistic: 5-60 minutes total.
- Use affordable, common ingredients from Dhaka / local bazaars
  (ডিম, আলু, পেঁয়াজ, টমেটো, মরিচ, কাঁচামরিচ, হলুদ, লবণ, চাল, ডাল, মুরগি,
  মাছ, বেগুন, ফুলকপি, গাজর, মটর, শসা, ক্যাপসিকাম, ধনেপাতা, রসুন, আদা,
  সরিষার তেল, তেল, ঘি, মশলা, জিরা, এলাচ, দারুচিনি, চা, চিনি, লবণ, মাখন, দই).
- Steps should fit on one short line each (15-25 Bangla words max).
- The bachelor_tip should be one practical sentence that helps a beginner
  cook (e.g. about heat level, salt, or timing).
''';
  }

  /// Strips optional ```json fences and parses the JSON payload.
  RecipeDraft _parseDraft(String raw) {
    var text = raw.trim();

    // Strip leading/trailing code fences if the model added them despite
    // the strict prompt.
    if (text.startsWith('```')) {
      final fenceEnd = text.indexOf('\n');
      if (fenceEnd != -1) text = text.substring(fenceEnd + 1);
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const GeminiRecipeException(
          'Gemini response was not a JSON object.',
        );
      }
      json = decoded;
    } on FormatException catch (e) {
      throw GeminiRecipeException(
        'Could not parse Gemini response as JSON: ${e.message}',
      );
    }

    final recipeNameBn =
        (json['recipe_name_bn'] as String?)?.trim() ?? '';
    final recipeNameEnRaw =
        (json['recipe_name_en'] as String?)?.trim() ?? '';
    final recipeNameEn = recipeNameEnRaw.isNotEmpty
        ? recipeNameEnRaw
        : recipeNameBn; // fall back to Bangla if model omitted EN

    // Ingredients: list of objects with {name_bn, name_en, quantity}.
    final rawIngredients = json['ingredients'];
    final ingredients = <DraftIngredient>[];
    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        if (item is Map<String, dynamic>) {
          final nameBn = (item['name_bn'] as String?)?.trim() ?? '';
          final nameEnRaw = (item['name_en'] as String?)?.trim() ?? '';
          final qty = (item['quantity'] as String?)?.trim() ?? '';
          if (nameBn.isEmpty && nameEnRaw.isEmpty && qty.isEmpty) continue;
          ingredients.add(DraftIngredient(
            nameBn: nameBn,
            nameEn: nameEnRaw.isNotEmpty ? nameEnRaw : nameBn,
            quantity: qty,
          ));
        } else if (item is String) {
          // Back-compat: if Gemini returns the old flat-string schema,
          // treat the whole string as a Bangla ingredient name.
          final s = item.trim();
          if (s.isNotEmpty) {
            ingredients.add(DraftIngredient(
              nameBn: s,
              nameEn: s,
              quantity: '',
            ));
          }
        }
      }
    }

    final steps = (json['steps'] as List?)
            ?.whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    int costTaka = 0;
    final rawCost = json['cost_taka'];
    if (rawCost is int) {
      costTaka = rawCost;
    } else if (rawCost is num) {
      costTaka = rawCost.toInt();
    } else if (rawCost is String) {
      costTaka = int.tryParse(rawCost.trim()) ?? 0;
    }
    if (costTaka < 0) costTaka = 0;

    int timeMinutes = 0;
    final rawTime = json['time_minutes'] ?? json['prep_minutes'];
    if (rawTime is int) {
      timeMinutes = rawTime;
    } else if (rawTime is num) {
      timeMinutes = rawTime.toInt();
    } else if (rawTime is String) {
      timeMinutes = int.tryParse(rawTime.trim()) ?? 0;
    }
    if (timeMinutes < 0) timeMinutes = 0;

    final difficultyRaw =
        (json['difficulty_bn'] as String?)?.trim() ?? 'সহজ';
    const allowedDifficulty = {'সহজ', 'মাঝারি', 'কঠিন'};
    final difficultyBn =
        allowedDifficulty.contains(difficultyRaw) ? difficultyRaw : 'সহজ';

    final bachelorTip =
        (json['bachelor_tip'] as String?)?.trim() ?? '';

    // Back-compat: if old "title" field exists but no Bangla title,
    // promote it to English title.
    final recipeNameEnResolved = recipeNameEn.isNotEmpty
        ? recipeNameEn
        : ((json['title'] as String?)?.trim() ?? '');

    if (recipeNameBn.isEmpty && recipeNameEnResolved.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing a title.');
    }
    if (ingredients.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing ingredients.');
    }
    if (steps.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing steps.');
    }

    return RecipeDraft(
      recipeNameBn: recipeNameBn.isNotEmpty ? recipeNameBn : recipeNameEnResolved,
      recipeNameEn: recipeNameEnResolved,
      ingredients: ingredients,
      steps: steps,
      costTaka: costTaka,
      timeMinutes: timeMinutes,
      difficultyBn: difficultyBn,
      bachelorTip: bachelorTip,
    );
  }
}
