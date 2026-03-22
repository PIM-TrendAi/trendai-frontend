/// Login screen — email/password form, social login buttons, form validation.
/// Matches Figma: dark bg, glass inputs, gradient submit button.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../auth_repository.dart';
import 'package:dio/dio.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (!mounted) return;
    final auth = ref.read(authNotifierProvider);
    if (auth.hasValue && auth.value != null) {
      context.go('/dashboard');
    } else if (auth.hasError) {
      String errorMessage = 'An unexpected error occurred';
      if (auth.error is DioException) {
        final dioErr = auth.error as DioException;
        final responseData = dioErr.response?.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'].toString();
          } else if (responseData.containsKey('non_field_errors')) {
            errorMessage = (responseData['non_field_errors'] as List).first.toString();
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'].toString();
          } else if (responseData.isNotEmpty) {
            final firstVal = responseData.values.first;
            errorMessage = firstVal is List ? firstVal.first.toString() : firstVal.toString();
          }
        } else {
          errorMessage = dioErr.message ?? 'Network error';
        }
      } else {
        errorMessage = auth.error.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final isLoading = auth.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedParticleBackground(count: 15),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text('Welcome Back 👋',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue creating',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                    const SizedBox(height: 40),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Password too short' : null,
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // Remember me + forgot password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v!),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            const Text('Remember me',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Forgot password?',
                              style: TextStyle(color: AppColors.primary, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sign In button
                    GradientButton(
                      label: 'Sign In',
                      onPressed: _submit,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 28),

                    // Divider
                    const Row(children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or', style: TextStyle(color: AppColors.textMuted)),
                      ),
                      Expanded(child: Divider(color: Colors.white12)),
                    ]),
                    const SizedBox(height: 20),

                    // Social buttons
                    _SocialButton(
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                      label: 'Continue with Google',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      icon: const Icon(Icons.apple_rounded, size: 22),
                      label: 'Continue with Apple',
                      onTap: () {},
                    ),
                    const SizedBox(height: 32),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(color: AppColors.textMuted)),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: const Text('Sign Up',
                              style: TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
