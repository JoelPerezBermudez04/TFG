import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error en iniciar sessió'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();

    if (!success && mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text('🥦', style: TextStyle(fontSize: 48)),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Benvingut!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inicia sessió per continuar',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Camp usuari
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Usuari',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Introdueix el teu usuari";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Camp contrasenya
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contrasenya',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Introdueix la contrasenya';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Botó login
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.isSubmitting ? null : _handleLogin,
                      child: auth.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Iniciar sessió'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Separador
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'o continua amb',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                // Botó Google
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return OutlinedButton(
                      onPressed: auth.isSubmitting ? null : _handleGoogleLogin,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text('Continuar amb Google'),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Enllaç registre
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No tens compte? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text("Registra't"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}