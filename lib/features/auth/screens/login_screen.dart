import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import 'auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signIn(
          _emailController.text, _passwordController.text);
      // Profil yoksa HomeScreen kullanıcıyı onboarding'e yönlendirir.
      if (mounted) context.go('/home');
    } catch (e) {
      _showMessage(SupabaseService.authErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (AuthValidators.email(email) != null) {
      _showMessage('Önce e-posta adresinizi girin.', isError: true);
      return;
    }
    try {
      await SupabaseService.resetPassword(email);
      _showMessage('Şifre sıfırlama bağlantısı $email adresine gönderildi.');
    } catch (e) {
      _showMessage(SupabaseService.authErrorMessage(e), isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text,
          style: TextStyle(
              color: isError ? AppColors.danger : AppColors.primary)),
    ));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      const Icon(
                        Icons.monitor_weight_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Hoş Geldin!',
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kalori bankana giriş yap',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: AuthValidators.email,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          hintText: 'ornek@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _isLoading ? null : _login(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Şifrenizi girin' : null,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _forgotPassword,
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.background),
                              )
                            : const Text('Giriş Yap'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('Hesabın yok mu? Kayıt Ol'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
