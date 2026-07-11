import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _prefsKey = 'favorite_recipe_ids';

  final Set<String> _ids = <String>{};

  Set<String> get ids => _ids;

  FavoritesProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const <String>[];
      _ids
        ..clear()
        ..addAll(list);
    } catch (_) {
      // keep empty set
    }
    notifyListeners();
  }

  bool isFavorite(String id) => _ids.contains(id);

  Future<void> toggle(String id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _ids.toList());
    } catch (_) {}
  }
}