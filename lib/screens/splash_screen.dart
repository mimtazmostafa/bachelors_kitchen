import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'root_shell.dart';
import 'subscribe_screen.dart';

/// Entry-point screen: shows the brand for ~2 seconds, then routes to the
/// home shell (subscribed) or the paywall (not subscribed).
///
/// The home shell must already be loaded with subscription state by the
/// time this screen decides where to go. Because [SubscriptionProvider.load]
/// is called from `main()`, this resolves immediately.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final sub = context.read<SubscriptionProvider>();
    // Make sure load() has resolved before we read state.
    if (!sub.isLoaded) {
      await sub.load();
    }
    if (!mounted) return;

    // 3-way routing:
    //   subscribed + saved phone → home
    //   not subscribed + saved phone (logged out or expired) → login
    //   no saved phone at all → subscribe (fresh install / unsubscribed)
    final hasPhone =
        sub.subscriberPhone != null && sub.subscriberPhone!.isNotEmpty;
    Widget destination;
    if (sub.isSubscribed && hasPhone) {
      destination = const RootShell();
    } else if (!sub.isSubscribed && hasPhone) {
      // Logged-out / expired user — keep the phone so they can re-verify.
      destination = const LoginScreen();
    } else if (sub.isSubscribed && !hasPhone) {
      // Inconsistent state: flag is set but phone is gone. Clear and
      // route to subscribe so the user can start fresh.
      await sub.clear();
      if (!mounted) return;
      destination = const SubscribeScreen();
    } else {
      destination = const SubscribeScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8F0), Color(0xFFFFE8D6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scale.value,
                    child: Opacity(
                      opacity: _fade.value,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🍳',
                          style: TextStyle(fontSize: 76),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: _fade.value,
                    child: Text(
                      t.appName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary.withValues(alpha: 0.95),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: _fade.value,
                    child: Text(
                      t.subscribeTagline,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF7C2D12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}