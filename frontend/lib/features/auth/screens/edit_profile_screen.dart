import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late bool _isGoogle;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _isGoogle = user?.provider == 'GOOGLE';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      username: _usernameController.text.trim(),
      email: _isGoogle ? null : _emailController.text.trim(),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualitzat correctament'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Error en actualitzar el perfil'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Usuari',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: _isGoogle ? TextInputAction.done : TextInputAction.next,
                  onFieldSubmitted: _isGoogle ? (_) => _handleSave() : null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return "Introdueix un nom d'usuari";
                    if (value.trim().length < 3) return "L'usuari ha de tenir mínim 3 caràcters";
                    return null;
                  },
                ),
                if (!_isGoogle) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSave(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Introdueix el teu email';
                      if (!_emailRegex.hasMatch(value.trim())) return 'Introdueix un email vàlid';
                      return null;
                    },
                  ),
                ],
                if (_isGoogle) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "L'email el gestiona Google i no es pot canviar aquí.",
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.isSubmitting ? null : _handleSave,
                      child: auth.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar canvis'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}