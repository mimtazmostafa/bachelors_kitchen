import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_translations.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'lang_code';
  String _code = 'en';

  LanguageProvider() {
    _load();
  }

  String get code => _code;
  bool get isBn => _code == 'bn';

  AppTranslations get t => AppTranslations(_code);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && (saved == 'en' || saved == 'bn')) {
        _code = saved;
      }
    } catch (_) {
      // first launch or no prefs available — fall back to English
      _code = 'en';
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _code = _code == 'en' ? 'bn' : 'en';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _code);
    } catch (_) {
      // ignore persistence failure
    }
  }

  Future<void> setCode(String code) async {
    if (code != 'en' && code != 'bn') return;
    if (_code == code) return;
    _code = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _code);
    } catch (_) {}
  }
}