import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/bd_api_client.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'subscribe_screen.dart';

/// Settings page — reachable from the home AppBar gear icon.
///
/// Shows the subscriber's phone + bdapps subscriber id, the app version,
/// and two distinct actions:
///   - Log out     — clears isSubscribed only; routes to LoginScreen
///   - Unsubscribe — confirms, calls the unsubscribe API, clears both
///                   isSubscribed and the saved phone, routes to SubscribeScreen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = BdApiClient();
  bool _unsubscribing = false;
  String _savedPhone = '—';

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same key SubscriptionProvider writes to. Value is in
    // 8801XXXXXXXXX form — strip the country prefix for display.
    final raw = prefs.getString('subscriber_phone') ?? '';
    String display = '—';
    if (raw.isNotEmpty) {
      if (raw.startsWith('880') && raw.length >= 13) {
        display = '0${raw.substring(3)}';
      } else {
        display = raw;
      }
    }
    if (!mounted) return;
    setState(() => _savedPhone = display);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _confirmAndLogout() async {
    final t = context.read<LanguageProvider>().t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.logoutConfirmTitle),
        content: Text(t.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SubscriptionProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmAndUnsubscribe() async {
    final t = context.read<LanguageProvider>().t;
    final sub = context.read<SubscriptionProvider>();
    final phone = sub.subscriberPhone;
    if (phone == null || phone.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.unsubscribeConfirmTitle),
        content: Text(t.unsubscribeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: Text(t.unsubscribeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _unsubscribing = true);
    final res = await _api.unsubscribe(phone);
    if (!mounted) return;
    setState(() => _unsubscribing = false);

    // Always clear local state, even if the server call failed, so the
    // user is no longer treated as subscribed in this app.
    await context.read<SubscriptionProvider>().unsubscribe();
    if (!mounted) return;

    if (!res.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Unsubscription failed.')),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SubscribeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final sub = context.watch<SubscriptionProvider>();
    final phone = sub.subscriberPhoneDisplay.isEmpty
        ? _savedPhone
        : sub.subscriberPhoneDisplay;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(text: t.account),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.phone_android_rounded,
                label: t.subscribedWith,
                value: phone,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(text: t.appVersion),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.info_outline,
                label: t.appVersion,
                value: '1.0.0',
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.cloud_outlined,
                label: t.poweredByBdapps,
                value: 'bdapps',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _ActionButton(
            label: t.logout,
            icon: Icons.logout_rounded,
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            onPressed: _confirmAndLogout,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: t.unsubscribe,
            icon: Icons.cancel_outlined,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFC62828),
            borderColor: const Color(0xFFC62828),
            onPressed: _unsubscribing ? null : _confirmAndUnsubscribe,
            trailing: _unsubscribing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC62828),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;
  final Widget? trailing;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.onPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size.fromHeight(52),
          side: borderColor == null
              ? null
              : BorderSide(color: borderColor!, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF6B4A2F),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCE7D3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
      ],
    );
  }
}