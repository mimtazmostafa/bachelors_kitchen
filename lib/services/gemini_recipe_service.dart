import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Immutable recipe draft returned by Gemini.
class RecipeDraft {
  final String title;
  final int prepMinutes;
  final List<String> ingredients;
  final List<String> steps;

  const RecipeDraft({
    required this.title,
    required this.prepMinutes,
    required this.ingredients,
    required this.steps,
  });
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
        maxOutputTokens: 1024,
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
    "title": string,                 // short, appetizing recipe name in English
    "prep_minutes": integer,         // total time in minutes (prep + cook)
    "ingredients": [string, ...],    // 5-12 items, "qty + item" form, English
    "steps": [string, ...]           // 4-10 short imperative steps in English
  }
- Prefer affordable, common ingredients available in Dhaka / local bazaars
  (e.g. ডিম, আলু, পেঁয়াজ, টমেটো, মরিচ, কাঁচামরিচ, হলুদ, লবণ, চাল, ডাল, মুরগি,
  মাছ, বেগুন, ফুলকপি, গাজর, মটর, শসা, ক্যাপসিকাম, ধনেপাতা, রসুন, আদা,
  সরিষার তেল, তেল, ঘি, মশলা, জিরা, এলাচ, দারুচিনি, চা, চিনি, লবণ, মাখন, দই).

CREATIVE NAMING (mandatory):
- DO NOT use generic placeholders like "Quick X Stir-Fry", "Easy X Dish",
  "X Bhaji", or "X Curry" unless the dish truly is a stir-fry / curry.
- Invent a culturally authentic name that matches what the dish actually is.
  Examples of the *kind* of variety expected:
    * eggs + onion + chili      → "Dim Peyaj Bhaji" or "Egg Onion Sabzi"
    * chicken + onion + tomato  → "Chicken Do Peyaza" or "Murgir Jhol"
    * potato + cauliflower      → "Alu Phulkopi Dalna"
    * rice + lentil + onion     → "Bhaja Khichuri"
    * brinjal + tomato + chili  → "Begun Tarkari"
    * plain bread + eggs        → "Ruti Dim Roti"
- The title must be a real dish name, not "<ingredient> recipe".

TEXT ENCODING (mandatory):
- You must output clean, standard UTF-8 text. Do not escape Bengali Unicode
  characters with backslashes (e.g. never write "\\u09A6" or "\\u09BF" — write
  the actual characters: "ডিম").
- Do not HTML-encode, hex-encode, or otherwise mangle non-ASCII characters.

VARIETY RULES (mandatory):
- Every request must produce a UNIQUE title. If the user has asked twice
  with the same ingredients, vary the title, technique (bhaja / jhol / chop /
  bhorta / torkari / dom), or spice profile so the second response is not a
  copy of the first.
- Vary the cooking technique based on what the user described. Bhaja means
  stir-fry, Jhol means light gravy, Dalna is a thick curry, Bhorta is a
  mashed mix, Chop is a cutlet, Torkari is a general vegetable dish.
- Keep steps short (one sentence each), numbered mentally but do NOT prefix
  with numbers in the output.
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

    final title = (json['title'] as String?)?.trim() ?? '';
    final prepRaw = json['prep_minutes'];
    final prepMinutes = prepRaw is int
        ? prepRaw
        : (prepRaw is num ? prepRaw.toInt() : 0);
    final ingredients = (json['ingredients'] as List?)
            ?.whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final steps = (json['steps'] as List?)
            ?.whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    if (title.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing a title.');
    }
    if (ingredients.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing ingredients.');
    }
    if (steps.isEmpty) {
      throw const GeminiRecipeException('Recipe was missing steps.');
    }

    return RecipeDraft(
      title: title,
      prepMinutes: prepMinutes,
      ingredients: ingredients,
      steps: steps,
    );
  }
}
