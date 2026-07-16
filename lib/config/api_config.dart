/// Production API endpoints for the Bachelor's Kitchen subscription flow.
///
/// Every endpoint expects a JSON body containing a `phone` field in the
/// 11-digit local form (`01XXXXXXXXX`) and returns JSON with at least a
/// `statusCode` field. `S1000` means success; any other code is a failure.
class ApiConfig {
  ApiConfig._();

  /// POST  body: {"phone": "01XXXXXXXXX"}
  /// Used to request an OTP to be sent to the user's phone via SMS.
  static const String sendOtp =
      'https://ruetandroiddevelopers.com/Mimtaz(Bachelors_Kitchen)/send_otp.php';

  /// POST  body: {"phone": "01XXXXXXXXX", "otp": "XXXX"}
  /// Used to verify the OTP and complete the subscription activation.
  static const String verifyOtp =
      'https://ruetandroiddevelopers.com/Mimtaz(Bachelors_Kitchen)/verify_otp.php';

  /// POST  body: {"phone": "01XXXXXXXXX"}
  /// Used to check whether an existing phone number has an active
  /// subscription. Returns `S1000` when the subscription is active.
  static const String checkStatus =
      'https://ruetandroiddevelopers.com/Mimtaz(Bachelors_Kitchen)/check_subscription.php';

  /// POST  body: {"phone": "01XXXXXXXXX"}
  /// Used to cancel an active subscription.
  static const String unsubscribe =
      'https://ruetandroiddevelopers.com/Mimtaz(Bachelors_Kitchen)/unsubscribe.php';

  /// Success status code returned by every endpoint.
  static const String successCode = 'S1000';

  /// Network timeout for all four calls.
  static const Duration networkTimeout = Duration(seconds: 15);
}