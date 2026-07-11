import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/bd_apps_config.dart';
import '../providers/language_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/bd_api_client.dart';
import '../theme/app_theme.dart';
import 'root_shell.dart';

/// Paywall screen — shown when the user is not subscribed.
///
/// Layout:
///   - warm gradient background (cream -> soft orange)
///   - top half: food emoji collage + brand
///   - glowing card with title / subtitle / 4-feature checklist
///   - phone input -> "Send OTP" button
///   - after OTP sent: OTP field + "Verify & Subscribe" button
///   - test-mode toggle visible only in test mode
class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _api = BdApiClient();

  String? _phone880; // 8801XXXXXXXXX — set when OTP is sent successfully
  bool _sending = false;
  bool _verifying = false;
  String? _statusOk; // green status
  String? _statusErr; // red status

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _api.close();
    super.dispose();
  }

  void _setError(String? msg) {
    setState(() {
      _statusErr = msg;
      if (msg != null) _statusOk = null;
    });
  }

  void _setOk(String? msg) {
    setState(() {
      _statusOk = msg;
      if (msg != null) _statusErr = null;
    });
  }

  Future<void> _onSendOtp() async {
    final raw = _phoneCtrl.text.trim();
    if (!BdApiClient.isValidBdMobile(raw)) {
      _setError(context.read<LanguageProvider>().t.enterValidPhone);
      return;
    }
    final phone880 = BdApiClient.toBd880(raw)!;
    setState(() => _sending = true);
    _setError(null);
    _setOk(null);
    final res = await _api.sendOtp(phone880);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!res.ok) {
      _setError(res.error);
      return;
    }
    setState(() => _phone880 = phone880);
    _setOk(context.read<LanguageProvider>().t.otpSent);
  }

  Future<void> _onVerify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otp)) {
      _setError(context.read<LanguageProvider>().t.enterValidOtp);
      return;
    }
    if (_phone880 == null) {
      _setError(context.read<LanguageProvider>().t.enterValidPhone);
      return;
    }
    setState(() => _verifying = true);
    _setError(null);
    final res = await _api.verifyOtp(_phone880!, otp);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!res.ok) {
      _setError(res.error);
      return;
    }
    await context.read<SubscriptionProvider>().subscribe(
          phone880: _phone880!,
          subscriberId: res.subscriberId ?? 'unknown',
        );
    if (!mounted) return;
    _setOk(context.read<LanguageProvider>().t.subscriptionSuccess);
    // Push home, wipe back-stack so back button cannot return to subscribe.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  void _onChangeNumber() {
    setState(() {
      _phone880 = null;
      _otpCtrl.clear();
      _statusOk = null;
      _statusErr = null;
    });
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
                  const SizedBox(height: 16),
                  if (BdAppsConfig.testMode)
                    _TestModeBadge(testMode: true, label: t.testModeOn)
                  else
                    _TestModeBadge(testMode: false, label: t.testModeOff),
                  const SizedBox(height: 24),
                  const _EmojiCollage(),
                  const SizedBox(height: 24),
                  _GlowingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.subscribeTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.subscribeSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B4A2F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('👨‍🍳',
                                      style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 6),
                                  Text(
                                    '৳${BdAppsConfig.displayPricePerDay}/day',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _FeatureRow(text: t.featureRecipes, icon: '🍛'),
                        const SizedBox(height: 8),
                        _FeatureRow(text: t.featureAiChef, icon: '🤖'),
                        const SizedBox(height: 8),
                        _FeatureRow(text: t.featurePlanner, icon: '📅'),
                        const SizedBox(height: 8),
                        _FeatureRow(text: t.featureOffline, icon: '📶'),
                        const SizedBox(height: 20),
                        if (_phone880 == null) ...[
                          _PhoneInput(
                            controller: _phoneCtrl,
                            label: t.phoneLabel,
                            hint: t.phoneHint,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _sending ? null : _onSendOtp,
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(t.sendOtp),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor:
                                  AppTheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                        ] else ...[
                          _OtpInput(
                            controller: _otpCtrl,
                            label: t.otpLabel,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _verifying ? null : _onVerify,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(t.verifyOtp),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor:
                                  AppTheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _sending || _verifying
                                ? null
                                : () async {
                                    setState(() => _sending = true);
                                    final res = await _api.sendOtp(_phone880!);
                                    if (!mounted) return;
                                    setState(() => _sending = false);
                                    if (res.ok) {
                                      _setOk(t.otpSent);
                                    } else {
                                      _setError(res.error);
                                    }
                                  },
                            child: Text(t.resendOtp),
                          ),
                          TextButton(
                            onPressed:
                                _sending || _verifying ? null : _onChangeNumber,
                            child: Text(t.changeNumber),
                          ),
                        ],
                        if (_statusOk != null) ...[
                          const SizedBox(height: 12),
                          _StatusBanner(message: _statusOk!, isError: false),
                        ],
                        if (_statusErr != null) ...[
                          const SizedBox(height: 12),
                          _StatusBanner(message: _statusErr!, isError: true),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      t.poweredByBdapps,
                      style: const TextStyle(
                        color: Color(0xFF6B4A2F),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

class _TestModeBadge extends StatelessWidget {
  final bool testMode;
  final String label;
  const _TestModeBadge({required this.testMode, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = testMode ? const Color(0xFFF9A825) : AppTheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            testMode ? Icons.science_outlined : Icons.verified_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCollage extends StatelessWidget {
  const _EmojiCollage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // glow
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Centerpiece
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🍳', style: TextStyle(fontSize: 52)),
          ),
          // Floating emojis
          const Positioned(top: 0, left: 24, child: _Floater('🍚', 36, -8)),
          const Positioned(top: 8, right: 30, child: _Floater('🥘', 30, 6)),
          const Positioned(top: 64, left: 0, child: _Floater('🍗', 28, 12)),
          const Positioned(top: 76, right: 6, child: _Floater('🫘', 28, -8)),
          const Positioned(bottom: 0, left: 50, child: _Floater('🍛', 28, 6)),
          const Positioned(bottom: 8, right: 60, child: _Floater('🥗', 26, -4)),
          const Positioned(top: 30, left: 90, child: _Floater('🥕', 24, 0)),
          const Positioned(top: 40, right: 90, child: _Floater('🍲', 24, 0)),
        ],
      ),
    );
  }
}

class _Floater extends StatelessWidget {
  final String emoji;
  final double size;
  final double rotation;
  const _Floater(this.emoji, this.size, this.rotation);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.1415 / 180,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

class _GlowingCard extends StatelessWidget {
  final Widget child;
  const _GlowingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 0,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFCE7D3), width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: child,
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final String icon;
  const _FeatureRow({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 16, color: AppTheme.secondary),
        ),
        const SizedBox(width: 10),
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _PhoneInput({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  State<_PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<_PhoneInput> {
  // Allow either the 11-digit local form (`01XXXXXXXXX`) or the 10-digit
  // shorthand form (`1XXXXXXXXX`, since `880` is implied by the prefix).
  static const int _maxLen = 11;

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

  /// Hide the `+880 ` prefix once the user starts typing — the user's
  /// input already encodes the country code (the leading `1` of the
  /// shorthand, or the full `01...` local form).
  bool get _shouldShowCountryPrefix {
    final text = widget.controller.text;
    if (text.isEmpty) return true;
    // User typed a leading `0` -> they want the full local form.
    if (text.startsWith('0')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      maxLength: _maxLen,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.phone_android_rounded),
        prefixText: _shouldShowCountryPrefix ? '+880 ' : null,
        prefixStyle: const TextStyle(
          color: Color(0xFF1B1B1B),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        helperText: 'Only Robi (018) or Airtel (016)',
        helperStyle: const TextStyle(
          fontSize: 11,
          color: Color(0xFF6B4A2F),
          fontWeight: FontWeight.w500,
        ),
        counterText: '',
      ),
    );
  }
}

class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _OtpInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
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