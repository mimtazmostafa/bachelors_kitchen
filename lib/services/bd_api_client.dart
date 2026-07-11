import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/bd_apps_config.dart';

/// Result of an OTP send / verify call. Either [ok] is true, or [error]
/// carries a user-facing message.
class OtpResult {
  final bool ok;
  final String? error;
  final String? subscriberId;
  const OtpResult.success({this.subscriberId}) : ok = true, error = null;
  const OtpResult.failure(this.error) : ok = false, subscriberId = null;
}

/// Allowed mobile prefixes for Robi & Airtel in Bangladesh.
///
/// bdapps / Robi-Airtel charging only works on these two operators, so
/// we reject every other prefix early to avoid a wasted OTP round-trip.
const Set<String> _kAllowedPrefixes = {
  '018', // Robi
  '016', // Airtel
};

/// Thin HTTP wrapper around the bdapps / Robi-Airtel subscription gateway.
///
/// While [BdAppsConfig.testMode] is true, no network call is made:
///   - `sendOtp` returns success immediately
///   - `verifyOtp` succeeds iff [otp] == `BdAppsConfig.testOtp`
///
/// Flip `BdAppsConfig.testMode = false` and paste real credentials into
/// `BdAppsConfig` to switch to the live gateway — no other code changes
/// required.
class BdApiClient {
  BdApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  void close() => _client.close();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'X-Application-Id': BdAppsConfig.appId,
        'X-Application-Secret': BdAppsConfig.appSecret,
      };

  /// Convert a user-entered Bangladeshi number to bdapps's `880XXXXXXXXX`
  /// form. Accepts:
  ///   - `01XXXXXXXXX` (11 digits, e.g. `01812345678`) — the local form
  ///   - `1XXXXXXXXX`   (10 digits starting with `1`, e.g. `1812345678`) —
  ///     shorthand when the `880` country code is already implied
  ///   - `8801XXXXXXXXX` (13 digits, full international) — already canonical
  /// Returns null when the digits don't match an allowed operator prefix
  /// (Robi `018` or Airtel `016`).
  static String? toBd880(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // 13-digit full form, already in the format bdapps expects.
    if (digits.length == 13 && digits.startsWith('8801')) {
      if (!_kAllowedPrefixes.contains(digits.substring(3, 6))) return null;
      return digits;
    }

    // 11-digit local form `01XXXXXXXXX`.
    if (digits.length == 11 && digits.startsWith('01')) {
      if (!_kAllowedPrefixes.contains(digits.substring(1, 4))) return null;
      return '880${digits.substring(1)}';
    }

    // 10-digit shorthand `1XXXXXXXXX` — `880` is already implied.
    if (digits.length == 10 && digits.startsWith('1')) {
      if (!_kAllowedPrefixes.contains('0${digits.substring(0, 3)}')) {
        return null;
      }
      return '880$digits';
    }

    // 14-digit form `880XXXXXXXXXX` (rare).
    if (digits.length == 14 && digits.startsWith('880')) {
      return digits;
    }

    return null;
  }

  /// Validate the user-entered phone before sending. Must be a Robi or
  /// Airtel number (see [_kAllowedPrefixes]) and must match one of the
  /// accepted digit-length formats.
  static bool isValidBdMobile(String raw) {
    return toBd880(raw) != null;
  }

  /// Send OTP to the user's phone. In test mode, returns success after a
  /// short artificial delay so the UI animation looks natural.
  Future<OtpResult> sendOtp(String phone880) async {
    if (BdAppsConfig.testMode) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return const OtpResult.success();
    }
    try {
      final uri = Uri.parse('${BdAppsConfig.baseUrl}/otp/send');
      final resp = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'phone': phone880,
              'charge_code': BdAppsConfig.chargeCode,
            }),
          )
          .timeout(BdAppsConfig.networkTimeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return const OtpResult.success();
      }
      return OtpResult.failure(
        'OTP পাঠানো যায়নি (${resp.statusCode}). পরে আবার চেষ্টা করুন।',
      );
    } on TimeoutException {
      return const OtpResult.failure(
        'সময় শেষ। ইন্টারনেট সংযোগ চেক করুন।',
      );
    } catch (e) {
      return OtpResult.failure('OTP পাঠানো যায়নি: $e');
    }
  }

  /// Verify OTP and subscribe the user. On success, returns the
  /// [subscriberId] assigned by bdapps. In test mode, generates a synthetic
  /// id of the form `test_<timestamp>`.
  Future<OtpResult> verifyOtp(String phone880, String otp) async {
    if (BdAppsConfig.testMode) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (otp.trim() == BdAppsConfig.testOtp) {
        return OtpResult.success(
          subscriberId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      return const OtpResult.failure(
        'ভুল OTP। সঠিক ৪ সংখ্যার কোড দিন।',
      );
    }
    try {
      final uri = Uri.parse('${BdAppsConfig.baseUrl}/otp/verify');
      final resp = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'phone': phone880,
              'otp': otp,
              'charge_code': BdAppsConfig.chargeCode,
            }),
          )
          .timeout(BdAppsConfig.networkTimeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final id = (data['subscriber_id'] ?? data['id'])?.toString();
          return OtpResult.success(subscriberId: id);
        } catch (_) {
          return const OtpResult.success();
        }
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const OtpResult.failure(
          'ভুল বা মেয়াদোত্তীর্ণ OTP।',
        );
      }
      return OtpResult.failure(
        'যাচাই ব্যর্থ (${resp.statusCode}). আবার চেষ্টা করুন।',
      );
    } on TimeoutException {
      return const OtpResult.failure(
        'সময় শেষ। ইন্টারনেট সংযোগ চেক করুন।',
      );
    } catch (e) {
      return OtpResult.failure('যাচাই ব্যর্থ: $e');
    }
  }
}