import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Result of a bdapps API call. Either [ok] is true (response statusCode
/// equals [ApiConfig.successCode]) or [error] carries a user-facing message.
class OtpResult {
  final bool ok;
  final String? error;
  final String? statusCode;
  final String? subscriberId;
  final String? referenceNo;

  /// For `check_subscription` responses: whether the user actually
  /// has an active subscription. `null` when this field is not
  /// applicable (e.g. send_otp / verify_otp results).
  final bool? isSubscribed;

  /// For `check_subscription` responses: the gateway's textual status
  /// such as `REGISTERED`, `UNREGISTERED`, `ACTIVE`, `PENDING`.
  /// `null` when not applicable.
  final String? subscriptionStatus;

  const OtpResult.success({
    this.subscriberId,
    this.referenceNo,
    this.statusCode = 'S1000',
    this.isSubscribed,
    this.subscriptionStatus,
  })  : ok = true,
        error = null;

  const OtpResult.failure(this.error, {this.statusCode})
      : ok = false,
        subscriberId = null,
        referenceNo = null,
        isSubscribed = null,
        subscriptionStatus = null;
}

/// Allowed mobile prefixes for Robi & Airtel in Bangladesh.
const Set<String> _kAllowedPrefixes = {
  '018', // Robi
  '016', // Airtel
};

/// Thin HTTP wrapper around the production subscription gateway.
///
/// Every endpoint expects `Content-Type: application/json` with a body
/// containing at least a `phone` field in the 11-digit local form
/// (`01XXXXXXXXX`). A response is considered success iff its `statusCode`
/// field equals [ApiConfig.successCode] (`S1000`).
class BdApiClient {
  BdApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  void close() => _client.close();

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Convert a user-entered Bangladeshi number to the local 11-digit form
  /// (`01XXXXXXXXX`) for the API body. Accepts:
  ///   - `01XXXXXXXXX` (11 digits, e.g. `01812345678`) — local form
  ///   - `1XXXXXXXXX`   (10 digits starting with `1`)
  ///   - `8801XXXXXXXXX` (13 digits, full international)
  ///   - `880XXXXXXXXXX` (14 digits, full international)
  /// Returns null when the digits don't match an allowed operator prefix
  /// (Robi `018` or Airtel `016`).
  static String? toBd880(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // 13-digit full form `8801XXXXXXXXX` (e.g. `8801812345678`).
    if (digits.length == 13 && digits.startsWith('8801')) {
      if (!_kAllowedPrefixes.contains(digits.substring(2, 5))) return null;
      return digits;
    }

    // 11-digit local form `01XXXXXXXXX` (e.g. `01812345678`).
    // The 3-digit operator prefix begins at index 0 (e.g. `018`).
    if (digits.length == 11 && digits.startsWith('01')) {
      if (!_kAllowedPrefixes.contains(digits.substring(0, 3))) return null;
      return digits;
    }

    // 10-digit shorthand `1XXXXXXXXX` (e.g. `1812345678` ->
    // local `01812345678`). The operator prefix in the local form is
    // `0` + the first two digits of the shorthand.
    if (digits.length == 10 && digits.startsWith('1')) {
      if (!_kAllowedPrefixes.contains('0${digits.substring(0, 2)}')) {
        return null;
      }
      return '0$digits';
    }

    // 14-digit form `880XXXXXXXXXX`.
    if (digits.length == 14 && digits.startsWith('880')) {
      return digits;
    }

    return null;
  }

  /// Validate the user-entered phone. Must be a Robi or Airtel number.
  static bool isValidBdMobile(String raw) => toBd880(raw) != null;

  /// POST an arbitrary JSON [body] to [endpoint], expecting a `statusCode`
  /// in the response. Success is determined by [ApiConfig.successCode].
  Future<OtpResult> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final resp = await _client
          .post(
            Uri.parse(endpoint),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.networkTimeout);

      // Debug-only raw response log (stripped from release builds).
      if (kDebugMode) {
        final label = _rawLabelFor(endpoint);
        // ignore: avoid_print
        print('$label RAW: ${resp.body}');
        // ignore: avoid_print
        print('[BdApiClient] $endpoint '
            'HTTP=${resp.statusCode} body=${resp.body}');
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return OtpResult.failure(
          'সার্ভারে সমস্যা হচ্ছে (${resp.statusCode}). একটু পরে আবার চেষ্টা করুন।',
          statusCode: 'HTTP_${resp.statusCode}',
        );
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        return const OtpResult.failure('সার্ভার থেকে সঠিক উত্তর পাওয়া যায়নি।');
      }
      // Success detection. The three endpoints return three different
      // response shapes — we have to handle all of them:
      //
      //   * check_subscription.php → bdapps envelope with
      //     `statusCode: "S1000"` and `subscriptionStatus` field.
      //   * send_otp.php         → minimal `{"referenceNo": null}`
      //     (no `statusCode` field at all when the gateway accepted
      //     the request and dispatched the SMS).
      //   * verify_otp.php       → bdapps envelope with
      //     `statusCode: "S1000"` on success, `E1600` etc. on failure.
      //
      // A request is a SUCCESS when ANY of these signals hold:
      //   1. `statusCode == "S1000"`
      //   2. `statusCode` is missing AND `referenceNo` key exists
      //      (send_otp accepted the dispatch even when it has no
      //      reference to give back)
      //   3. `subscriptionStatus` is present and equals "REGISTERED"
      //      or "ACTIVE" (already-paid check_subscription result)
      final code = data['statusCode']?.toString();
      final subStatus = data['subscriptionStatus']?.toString().toUpperCase();
      final hasReferenceKey = data.containsKey('referenceNo') ||
          data.containsKey('reference_no');
      final isSuccess = code == ApiConfig.successCode ||
          (code == null && hasReferenceKey) ||
          subStatus == 'REGISTERED' ||
          subStatus == 'ACTIVE';

      if (isSuccess) {
        final id = (data['subscriber_id'] ?? data['id'] ?? data['subscriberId'])
            ?.toString();
        final ref = (data['referenceNo'] ?? data['reference_no'])?.toString();
        // Subscription fields — only meaningful for check_subscription
        // responses. We forward them when present so the caller can
        // distinguish "subscribed" from "registered but not subscribed".
        bool? isSubs;
        String? subStatus;
        if (data.containsKey('isSubscribed')) {
          final v = data['isSubscribed'];
          if (v is bool) {
            isSubs = v;
          } else if (v is num) {
            isSubs = v != 0;
          } else if (v is String) {
            isSubs = v.toLowerCase() == 'true' || v == '1';
          }
        }
        if (data.containsKey('subscriptionStatus')) {
          subStatus = data['subscriptionStatus']?.toString();
        }
        return OtpResult.success(
          subscriberId: id,
          referenceNo: ref,
          statusCode: code ?? ApiConfig.successCode,
          isSubscribed: isSubs,
          subscriptionStatus: subStatus,
        );
      }

      // Failure path. Pull whatever the gateway returned.
      final rawMsg = (data['statusDetail'] ??
              data['message'] ??
              data['error'] ??
              data['subscriptionStatus'] ??
              '')
          .toString()
          .trim();
      final fallbackMsg = _describeStatusCode(code);
      final msg = rawMsg.isNotEmpty ? rawMsg : fallbackMsg;
      return OtpResult.failure(msg, statusCode: code);
    } on TimeoutException {
      return const OtpResult.failure(
        'অনুরোধের সময় শেষ হয়েছে। ইন্টারনেট সংযোগ চেক করুন।',
      );
    } on http.ClientException catch (e) {
      return OtpResult.failure('নেটওয়ার্ক সমস্যা: ${e.message}');
    } catch (e) {
      return OtpResult.failure('অনুরোধ ব্যর্থ হয়েছে: $e');
    }
  }

  /// Send an OTP to the user's phone.
  /// Body: `{"phone": "01XXXXXXXXX"}`
  Future<OtpResult> sendOtp(String phone11) =>
      _post(ApiConfig.sendOtp, {'phone': phone11});

  /// Verify the OTP and activate the subscription.
  /// Body: `{"phone": "01XXXXXXXXX", "otp": "XXXX", "referenceNo": "..."}`
  Future<OtpResult> verifyOtp(
    String phone11,
    String otp, {
    String? referenceNo,
  }) =>
      _post(
        ApiConfig.verifyOtp,
        {
          'phone': phone11,
          'otp': otp,
          if (referenceNo != null && referenceNo.isNotEmpty)
            'referenceNo': referenceNo,
        },
      );

  /// Check whether a phone has an active subscription.
  /// Body: `{"phone": "01XXXXXXXXX"}`
  Future<OtpResult> checkSubscription(String phone11) =>
      _post(ApiConfig.checkStatus, {'phone': phone11});

  /// Cancel an active subscription.
  /// Body: `{"phone": "01XXXXXXXXX"}`
  Future<OtpResult> unsubscribe(String phone11) =>
      _post(ApiConfig.unsubscribe, {'phone': phone11});

  /// Friendly log label for the per-endpoint debug print.
  static String _rawLabelFor(String endpoint) {
    if (endpoint == ApiConfig.sendOtp) return 'SEND OTP';
    if (endpoint == ApiConfig.verifyOtp) return 'VERIFY OTP';
    if (endpoint == ApiConfig.checkStatus) return 'CHECK STATUS';
    if (endpoint == ApiConfig.unsubscribe) return 'UNSUBSCRIBE';
    return 'API';
  }

  /// Build a short English phrase describing a gateway error code so the
  /// UI layer can translate it via [getBanglaError]. IMPORTANT: this
  /// helper runs ONLY when the server didn't return a `statusDetail`
  /// text — server text always wins because it's authoritative.
  ///
  /// We only map codes here that we are confident about from the
  /// bdapps gateway documentation. Unknown codes return a neutral
  /// generic message rather than a specific-but-wrong guess, because
  /// guessing wrong (e.g. showing "Too many attempts" for an unrelated
  /// `E1301`) is worse than showing a generic "Request failed".
  static String _describeStatusCode(String? code) {
    if (code == null || code.isEmpty) return 'Request failed';
    final c = code.toUpperCase();

    // Codes we have observed from the real backend responses:
    //   E1301 — ApplicationID is not allowed for the destination
    //           operator (the PHP's appId is not registered for the
    //           operator prefix on the user's phone, e.g. Robi 018 /
    //           Airtel 016). Surface a clear operator-related message.
    //   E1314 — phone / address format problem
    //   E1240, E1241 — invalid or expired OTP
    //   E1600 — gateway temporarily unavailable (verify_otp)
    //   E1614 — application / reference error
    if (c == 'E1301') {
      return 'This number is not allowed for the subscribed operator. '
          'Please use a Robi (018) or Airtel (016) number.';
    }
    if (c == 'E1314') return 'Phone number format is invalid';
    if (c == 'E1240' || c == 'E1241') return 'Invalid or expired OTP code';
    if (c == 'E1600' || c == 'E1614') {
      return 'Service temporarily unavailable. Please try again later';
    }

    // Anything else — generic. The text-based detection in
    // `getBanglaError` will still try to match the actual server
    // message if one is present.
    return 'Request failed';
  }
}
