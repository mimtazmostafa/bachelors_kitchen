/// BdApps / Robi-Airtel subscription gateway configuration.
///
/// --------------------------------------------------------------------------
/// IMPORTANT — Single source of truth for bdapps credentials
/// --------------------------------------------------------------------------
/// When the APK is approved by bdapps and you receive:
///   - base URL of the subscription API
///   - appId / appKey / appSecret / charge code
///   - subscription price / short-code
/// Paste them into the placeholder constants below. The rest of the app reads
/// from this file only — no other place needs editing.
///
/// While [testMode] is `true`, no real network call is made: any phone number
/// + the OTP `1234` will succeed and unlock the app. Flip [testMode] to
/// `false` after pasting real credentials.
class BdAppsConfig {
  BdAppsConfig._();

  /// When true, the SubscribeScreen accepts any phone + OTP `1234` and the
  /// app is unlocked without contacting bdapps. Flip to false for production.
  static const bool testMode = true;

  /// Test-mode magic OTP accepted only when [testMode] is true.
  static const String testOtp = '1234';

  /// Base URL of the bdapps subscription REST API.
  /// Example: 'https://api.bdapps.com/v1'
  static const String baseUrl = 'https://api.bdapps.com/v1';

  /// App id issued by bdapps after APK approval.
  static const String appId = 'YOUR_APP_ID';

  /// App key / secret issued by bdapps.
  static const String appSecret = 'YOUR_APP_SECRET';

  /// Charge code (the short-code that identifies the subscription product).
  static const String chargeCode = 'YOUR_CHARGE_CODE';

  /// Friendly display price shown on the subscribe screen.
  /// Used purely for UI; the real charge is enforced server-side by bdapps.
  static const String displayPricePerDay = '2.78';

  /// Network timeout for OTP send / verify calls.
  static const Duration networkTimeout = Duration(seconds: 15);
}