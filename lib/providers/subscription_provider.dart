import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscription state for the bdapps / Robi-Airtel paywall.
///
/// Persists three values in [SharedPreferences]:
///   - `is_subscribed`     : bool — gates access to the home shell
///   - `subscriber_id`     : String? — opaque id returned by bdapps
///   - `subscriber_phone`  : String? — phone in `8801XXXXXXXXX` form
///
/// After logout, all three are cleared and the back-stack is wiped by the
/// caller via `Navigator.pushAndRemoveUntil(... (route) => false)`.
class SubscriptionProvider extends ChangeNotifier {
  static const _kIsSubscribed = 'is_subscribed';
  static const _kSubscriberId = 'subscriber_id';
  static const _kSubscriberPhone = 'subscriber_phone';

  bool _isSubscribed = false;
  String? _subscriberId;
  String? _subscriberPhone;
  bool _loaded = false;

  bool get isSubscribed => _isSubscribed;
  String? get subscriberId => _subscriberId;
  String? get subscriberPhone => _subscriberPhone;

  /// Phone formatted for display, e.g. `8801712345678` -> `+880 1712-345678`.
  /// Falls back to the raw value if formatting fails.
  String get subscriberPhoneDisplay {
    final raw = _subscriberPhone;
    if (raw == null || raw.length < 9) return raw ?? '';
    // strip leading "880" for display, then re-format as 0XX-XXXX-XXXX
    final digits = raw.startsWith('880') ? raw.substring(3) : raw;
    if (digits.length == 10 && digits.startsWith('1')) {
      return '0${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return '+$raw';
  }

  bool get isLoaded => _loaded;

  /// Read persisted subscription state. Safe to call multiple times.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSubscribed = prefs.getBool(_kIsSubscribed) ?? false;
      _subscriberId = prefs.getString(_kSubscriberId);
      _subscriberPhone = prefs.getString(_kSubscriberPhone);
    } catch (_) {
      // first launch / no prefs — leave defaults
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persist subscription success and notify listeners.
  Future<void> subscribe({
    required String phone880,
    required String subscriberId,
  }) async {
    _isSubscribed = true;
    _subscriberId = subscriberId;
    _subscriberPhone = phone880;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsSubscribed, true);
      await prefs.setString(_kSubscriberId, subscriberId);
      await prefs.setString(_kSubscriberPhone, phone880);
    } catch (_) {
      // state is in-memory; will retry on next load if persistence failed
    }
  }

  /// Clear all subscription state. Caller is responsible for navigating to
  /// the SubscribeScreen with `pushAndRemoveUntil((route) => false)` so that
  /// the back button cannot return to the home shell.
  Future<void> logout() async {
    _isSubscribed = false;
    _subscriberId = null;
    _subscriberPhone = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsSubscribed);
      await prefs.remove(_kSubscriberId);
      await prefs.remove(_kSubscriberPhone);
    } catch (_) {/* ignore */}
  }
}