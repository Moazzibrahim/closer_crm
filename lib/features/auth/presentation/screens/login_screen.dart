// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/main_shell.dart'; // عدّل المسار حسب مكان الملف
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/auth/providers/crm_settings.dart';
import 'package:flutter_application_1/features/splash/closer_logo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// LOGIN SCREEN
/// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  // الباسورد في تخزين مشفّر، والإيميل وحالة الـ checkbox في prefs عادي
  final _secure = const FlutterSecureStorage();
  static const _kRemember = 'remember_me';
  static const _kEmail = 'remember_email';
  static const _kPass = 'remember_pass';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  // يرجّع البيانات المحفوظة ويملا الحقول
  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kRemember) != true) return;
      final email = prefs.getString(_kEmail) ?? '';
      final pass = await _secure.read(key: _kPass) ?? '';
      if (!mounted) return;
      setState(() {
        _rememberMe = true;
        _emailController.text = email;
        _passwordController.text = pass;
      });
    } catch (_) {}
  }

  // يحفظ أو يمسح حسب حالة الـ checkbox (بيتنده بعد نجاح اللوجين بس)
  Future<void> _persistCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool(_kRemember, true);
        await prefs.setString(_kEmail, _emailController.text.trim());
        await _secure.write(key: _kPass, value: _passwordController.text);
      } else {
        await prefs.remove(_kRemember);
        await prefs.remove(_kEmail);
        await _secure.delete(key: _kPass);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    // الـ platform والـ deviceId بيتحددوا تلقائياً جوه الـ provider
    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!success) {
      _showError(auth.error ?? 'Login failed');
      return;
    }
    final role = userRoleFromString(auth.role);
    if (role == null) {
      _showError('Unknown role: ${auth.role}');
      return;
    }
    await _persistCredentials(); // 👈 نحفظ بس لو اللوجين نجح
    await context.read<CrmSettingsProvider>().load();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(role: role)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);

    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 48),

            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35),

                  /// TOP LOGO
                  Row(
                    children: [
                      /// TOP LOGO (الأيقونة + اسم التطبيق closercrm)
                      // CloserLogo بيرسم الأيقونة + كلمة closer (كحلي) + crm (دهبي)
                      const CloserLogo(size: 52),
                    ],
                  ),

                  const SizedBox(height: 65),

                  /// TITLE
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Sign in to manage your real estate business.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 38),

                  /// FORM
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 9),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,

                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),

                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }

                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Password',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 9),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,

                          decoration: InputDecoration(
                            hintText: 'Enter your password',

                            prefixIcon: const Icon(Icons.lock_outline_rounded),

                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),

                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }

                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        /// REMEMBER + FORGOT
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppColors.navy,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            const Text(
                              'Remember me',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),

                            const Spacer(),

                            // TextButton(
                            //   onPressed: () {
                            //     Navigator.of(context).push(
                            //       MaterialPageRoute(
                            //         builder: (_) =>
                            //             const ForgotPasswordScreen(),
                            //       ),
                            //     );
                            //   },
                            //   child: const Text(
                            //     'Forgot Password?',
                            //     style: TextStyle(
                            //       color: AppColors.navy,
                            //       fontWeight: FontWeight.w700,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        /// LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,

                              elevation: 0,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  /// FOOTER
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: Text(
                        '© 2026 Closer CRM ',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                        ),
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
