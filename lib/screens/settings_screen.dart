import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/bd_apps_config.dart';
import '../providers/language_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'subscribe_screen.dart';

/// Settings page — reachable from the home AppBar gear icon.
///
/// Shows the subscriber's phone + bdapps subscriber id, a test-mode badge,
/// the app version, and the Log out button. Logging out clears all
/// persisted subscription state and navigates to [SubscribeScreen] with the
/// entire back stack removed so the back button cannot return here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
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
    if (ok != true) return;
    if (!context.mounted) return;
    await context.read<SubscriptionProvider>().logout();
    if (!context.mounted) return;
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
        ? '—'
        : sub.subscriberPhoneDisplay;
    final subId = sub.subscriberId ?? '—';

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
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.tag_rounded,
                label: t.subscriberId,
                value: subId,
                mono: true,
              ),
              const Divider(height: 24),
              const _InfoRow(
                icon: Icons.science_outlined,
                label: BdAppsConfig.testMode ? 'Test mode' : 'Live mode',
                value: BdAppsConfig.testMode ? 'ON' : 'OFF',
                valueColor:
                    BdAppsConfig.testMode ? Color(0xFFF9A825) : AppTheme.secondary,
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
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _confirmAndLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(t.logout),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                'DEBUG BUILD',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
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
  final bool mono;
  final Color? valueColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontFamily: mono ? 'monospace' : null,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1B1B1B),
          ),
        ),
      ],
    );
  }
}