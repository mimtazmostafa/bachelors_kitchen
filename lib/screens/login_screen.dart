import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/app_translations.dart';
import '../services/bd_api_client.dart';
import '../theme/app_theme.dart';
import 'root_shell.dart';
import 'subscribe_screen.dart';

/// Translates raw server / network error strings into localized copy the
/// user sees across the app. Used by both Login screen and Subscribe
/// screen when surfacing a backend failure. Matches a handful of common
/// English/technical fragments case-insensitively; anything that does
/// not match falls back to [AppTranslations.networkError].
///
/// The optional [statusCode] parameter lets the caller pass through the
/// gateway's `statusCode` field (e.g. `E1115`) so we can do exact-code
/// matching in addition to text matching. When both are available, the
/// statusCode check runs first because it's the most reliable signal.
String getBanglaError(
  String? detail, {
  required AppTranslations t,
  String? statusCode,
}) {
  final fallback = t.networkError;
  final raw = detail?.trim() ?? '';
  final code = statusCode?.trim().toUpperCase() ?? '';
  final lower = raw.toLowerCase();

  // 1. Server-provided text — ALWAYS first. Whatever the gateway put in
  //    `statusDetail` (or `message` / `error`) is the authoritative
  //    description of the problem; matching on it gives the user the
  //    exact reason instead of a guessed category.
  if (raw.isNotEmpty) {
    // Subscription problems.
    if (lower.contains('no active subscription') ||
        lower.contains('no subscription') ||
        lower.contains('not subscribed') ||
        lower.contains('not a subscriber') ||
        lower.contains('user already unregistered') ||
        lower.contains('user not registered') ||
        lower.contains('already unregistered') ||
        lower.contains('unregistered') ||
        lower.contains('কোনো সক্রিয় সাবস্ক্রিপশন নেই')) {
      return t.noSubscription;
    }

    // Phone / number format problems — covers "format of the address
    // is invalid" and "address is invalid" phrasing from the gateway.
    if (lower.contains('invalid phone') ||
        lower.contains('invalid number') ||
        lower.contains('invalid mobile') ||
        lower.contains('bad phone') ||
        lower.contains('phone format') ||
        lower.contains('number format') ||
        lower.contains('address is invalid') ||
        lower.contains('format of the address')) {
      return t.enterValidPhone;
    }
    // Operator mismatch (E1301). The gateway says the app id is not
    // allowed for the operator prefix on this number, e.g. a GP
    // number hitting an app registered for Robi.
    if (lower.contains('operator unknown') ||
        lower.contains('not allowed within the system') ||
        lower.contains('applicationid is not allowed')) {
      return t.operatorNotAllowed;
    }
    // OTP problems.
    if (lower.contains('invalid otp') ||
        lower.contains('wrong otp') ||
        lower.contains('incorrect otp') ||
        lower.contains('otp expired') ||
        lower.contains('otp mismatch')) {
      return t.enterValidOtp;
    }

    // Throttling / rate limiting (text-based — trust the server's word).
    if (lower.contains('too many') ||
        lower.contains('rate limit') ||
        lower.contains('try again later') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('temporarily  unavailable')) {
      return t.tooManyAttempts;
    }

    // Network / timeout / connection failures (incl. server 5xx).
    if (lower.contains('socketexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('no internet') ||
        lower.contains('service unavailable') ||
        lower.contains('server error') ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout')) {
      return t.networkError;
    }
  }

  // 2. If the server didn't give us text, fall back to mapping the
  //    statusCode to a generic English phrase. We only map codes we
  //    are CONFIDENT about — never guess. `_describeStatusCode` itself
  //    returns "Request failed" for everything it doesn't recognise,
  //    so this branch maps to a neutral generic Bangla message.
  if (code.isNotEmpty) {
    if (code == 'E1301') return t.operatorNotAllowed;
    if (code == 'E1314') return t.enterValidPhone;
    if (code == 'E1240' || code == 'E1241') return t.enterValidOtp;
    if (code == 'E1600' || code == 'E1614') return t.tooManyAttempts;
  }

  // 3. Default — show the generic network-error copy. We never leak raw
  //    server English to the user, but we also don't fabricate a
  //    specific category we can't actually prove.
  return fallback;
}

/// Login screen — shown when the user has a previously saved phone number
/// but is not currently subscribed. Calls `check_subscription` on submit:
///   - `S1000` → save subscription, push Home (wipe back-stack)
///   - else    → show "no active subscription" + button to Subscribe
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _phoneCtrl;
  final _api = BdApiClient();
  bool _checking = false;
  bool _showNoSubscription = false;
  bool _showSubscribeButton = false;
  String? _error;
  String _savedPhoneLocal = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same key SubscriptionProvider writes to.
    final raw = prefs.getString('subscriber_phone') ?? '';
    final local = _displayLocal(raw);
    if (!mounted) return;
    setState(() {
      _savedPhoneLocal = local;
      _phoneCtrl = TextEditingController(text: local);
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _api.close();
    super.dispose();
  }

  /// Convert a stored `8801XXXXXXXXX` (or already-local `01XXXXXXXXX`) into
  /// the local form `01XXXXXXXXX` for the input. Returns empty string when
  /// no phone is saved.
  String _displayLocal(String? phone880) {
    if (phone880 == null || phone880.isEmpty) return '';
    if (phone880.startsWith('880') && phone880.length >= 13) {
      return '0${phone880.substring(3)}';
    }
    return phone880;
  }

  void _setError(String? msg) {
    setState(() {
      _error = msg;
      if (msg != null) {
        _showNoSubscription = false;
        _showSubscribeButton = false;
      }
    });
  }

  Future<void> _onCheck() async {
    final raw = _phoneCtrl.text.trim();
    final phone11 = BdApiClient.toBd880(raw);
    if (phone11 == null) {
      _setError(context.read<LanguageProvider>().t.enterValidPhone);
      return;
    }
    // Local comparison: only the saved phone may log in. No API call.
    final matchesSaved = _savedPhoneLocal.isNotEmpty &&
        raw == _savedPhoneLocal;
    if (!matchesSaved) {
      // Phone doesn't match the one we previously saved. Offer to
      // re-subscribe with this new number.
      setState(() {
        _showNoSubscription = false;
        _showSubscribeButton = true;
        _error = null;
      });
      return;
    }
    setState(() {
      _checking = true;
      _showNoSubscription = false;
      _showSubscribeButton = false;
      _error = null;
    });
    // Mark subscribed locally — the real server check is not needed
    // here because the saved phone is already the trusted source.
    await context.read<SubscriptionProvider>().subscribe(
          phone880: phone11,
          subscriberId: 'local',
        );
    if (!mounted) return;
    setState(() => _checking = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  void _onSubscribe() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SubscribeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8F0), Color(0xFFFFE8D6)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('👋',
                          style: TextStyle(fontSize: 60)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.loginTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B4A2F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.18),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFFFCE7D3), width: 1.2),
                      ),
                      padding:
                          const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PhoneInput(controller: _phoneCtrl),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _checking ? null : _onCheck,
                            icon: _checking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_user_outlined),
                            label: Text(t.loginButton),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor:
                                  AppTheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          if (_showNoSubscription) ...[
                            const SizedBox(height: 14),
                            _NoSubscriptionPanel(
                              message: t.noSubscription,
                              buttonLabel: t.subscribeButton,
                              onSubscribe: _onSubscribe,
                            ),
                          ],
                          if (_showSubscribeButton) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _onSubscribe,
                              icon: const Icon(
                                Icons.workspace_premium_outlined,
                                size: 18,
                              ),
                              label: Text(t.subscribeButton),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(
                                  color: AppTheme.primary,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _StatusBanner(message: _error!, isError: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneInput extends StatefulWidget {
  final TextEditingController controller;
  const _PhoneInput({required this.controller});

  @override
  State<_PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<_PhoneInput> {
  static const int _maxLen = 11;
  static const String _invalidMsg =
      'শুধুমাত্র Robi (018) বা Airtel (016) নম্বর দিন';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final cleaned = widget.controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      return;
    }
    setState(() {});
  }

  String? get _errorText {
    final text = widget.controller.text;
    if (text.length != 11) return null;
    if (text.startsWith('016') || text.startsWith('018')) return null;
    return _invalidMsg;
  }

  @override
  Widget build(BuildContext context) {
    final err = _errorText;
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      maxLength: _maxLen,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '01XXXXXXXXX',
        prefixIcon: const Icon(Icons.phone_android_rounded),
        errorText: err,
        counterText: '',
      ),
    );
  }
}

class _NoSubscriptionPanel extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onSubscribe;
  const _NoSubscriptionPanel({
    required this.message,
    required this.buttonLabel,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 20, color: Color(0xFFEF6C00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFEF6C00),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSubscribe,
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC62828) : AppTheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
