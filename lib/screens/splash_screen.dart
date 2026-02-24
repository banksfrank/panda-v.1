import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;
    
    final authService = context.read<AuthService>();
    await authService.initialize();
    
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_complete') ?? false;
      if (authService.isAuthenticated) {
        context.go(completed ? '/home' : '/onboarding');
      } else {
        context.go('/auth');
      }
    } catch (_) {
      // Fallback
      context.go(authService.isAuthenticated ? '/home' : '/auth');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PandaColors.bgPrimary, PandaColors.bgSecondary],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundParticles(),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildTitle(),
                      const SizedBox(height: 8),
                      _buildSubtitle(),
                      const SizedBox(height: 48),
                      _buildLoadingIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundParticles() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PandaColors.pink.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PandaColors.purple.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: PandaColors.bgCard,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: PandaColors.pink.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '🐼',
          style: TextStyle(fontSize: 56),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => PandaColors.gradientPrimary.createShader(bounds),
      child: const Text(
        'Panda',
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'FIND YOUR PERSON',
      style: TextStyle(
        color: PandaColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 4,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Container(
          width: 220,
          height: 3,
          decoration: BoxDecoration(
            color: PandaColors.bgCard,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _controller.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: PandaColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Loading...',
          style: TextStyle(
            color: PandaColors.textMuted,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
