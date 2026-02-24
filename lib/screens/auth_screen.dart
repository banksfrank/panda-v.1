import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final authService = context.read<AuthService>();
    bool success;

    if (_isLogin) {
      success = await authService.signIn(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      success = await authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        age: int.tryParse(_ageController.text) ?? 18,
        phone: _phoneController.text,
      );
    }

    if (success && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final completed = prefs.getBool('onboarding_complete') ?? false;
        context.go(completed ? '/home' : '/onboarding');
      } catch (_) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        try {
          final prefs = await SharedPreferences.getInstance();
          final completed = prefs.getBool('onboarding_complete') ?? false;
          context.go(completed ? '/home' : '/onboarding');
        } catch (_) {
          context.go('/home');
        }
      });
    }

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
            _buildBackgroundDecor(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 36),
                        _buildAuthTabs(),
                        const SizedBox(height: 28),
                        _buildAuthForm(authService),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PandaColors.pink.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -150,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PandaColors.purple.withValues(alpha: 0.06),
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
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: PandaColors.bgCard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PandaColors.pink.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: const Center(
            child: Text('🐼', style: TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => PandaColors.gradientPrimary.createShader(bounds),
          child: const Text(
            'Panda',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find Your Perfect Match',
          style: TextStyle(
            color: PandaColors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PandaColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: PandaColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab('Login', _isLogin, () {
              setState(() => _isLogin = true);
            }),
          ),
          Expanded(
            child: _buildTab('Sign Up', !_isLogin, () {
              setState(() => _isLogin = false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isActive ? PandaColors.gradientButton : null,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: isActive ? [
            BoxShadow(
              color: PandaColors.pink.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : PandaColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm(AuthService authService) {
    return Column(
      children: [
        if (!_isLogin) ...[
          _buildInputField(
            controller: _nameController,
            label: 'NAME',
            hint: 'Enter your name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            controller: _ageController,
            label: 'AGE',
            hint: 'Enter your age',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            controller: _phoneController,
            label: 'PHONE (OPTIONAL)',
            hint: '+1 234 567 890',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),
        ],
        _buildInputField(
          controller: _emailController,
          label: 'EMAIL',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _passwordController,
          label: 'PASSWORD',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        _buildSubmitButton(authService),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: PandaColors.borderColor.withValues(alpha: 0.5))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: TextStyle(color: PandaColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Container(height: 1, color: PandaColors.borderColor.withValues(alpha: 0.5))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: authService.isLoading
                    ? null
                    : () async {
                        final ok = await authService.signInWithGoogle();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google sign-in failed. Please try again.'),
                              backgroundColor: PandaColors.bgCard,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.g_mobiledata, color: Colors.white),
                label: const Text('Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showBackendRequiredSnack(context, 'Phone Auth'),
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text('Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: authService.isLoading
              ? null
              : () async {
                  final ok = await authService.continueAsGuest();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not start offline mode.'), backgroundColor: PandaColors.bgCard),
                    );
                  }
                },
          icon: const Icon(Icons.person_outline, color: Colors.white),
          label: const Text('Continue as Guest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PandaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: PandaColors.bgInput,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: PandaColors.borderColor, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType: keyboardType,
            style: const TextStyle(color: PandaColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: PandaColors.textMuted),
              prefixIcon: Icon(icon, color: PandaColors.textMuted, size: 20),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: PandaColors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AuthService authService) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: authService.isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: PandaColors.gradientButton,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: authService.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isLogin ? 'Sign In' : 'Create Account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showBackendRequiredSnack(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName requires a backend. Open the Firebase or Supabase panel in Dreamflow to enable it.'),
        backgroundColor: PandaColors.bgCard,
      ),
    );
  }
}
