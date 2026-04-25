import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isGoogle = user?.provider == 'GOOGLE';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        user?.username.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.username ?? 'Usuari',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (user?.email.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(user!.email, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                  if (isGoogle) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/google_logo.png', height: 14, width: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Compte Google',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Avisos de caducitat',
                    subtitle: 'Avisar ${user?.diesAvisCaducitat ?? 5} dies abans',
                    onTap: () => _showExpiryDaysDialog(context, auth),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Editar perfil',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  if (!isGoogle) ...[
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.lock_outline,
                      title: 'Canviar contrasenya',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Tancar sessió',
                    textColor: AppColors.error,
                    onTap: () => _confirmLogout(context, auth),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.delete_forever_outlined,
                    title: 'Eliminar compte',
                    textColor: AppColors.error,
                    onTap: () => isGoogle
                        ? _confirmDeleteAccountGoogle(context, auth)
                        : _confirmDeleteAccountLocal(context, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('FreshTrack v1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: textColor ?? AppColors.textPrimary),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: Icon(Icons.chevron_right, color: textColor ?? AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => Divider(height: 1, indent: 56, color: Colors.grey.shade200);

  void _showExpiryDaysDialog(BuildContext context, AuthProvider auth) {
    int currentDays = auth.user?.diesAvisCaducitat ?? 5;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Dies d'avís de caducitat"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rebre notificacions quan un producte caduca en:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: currentDays > 0 ? () => setState(() => currentDays--) : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      currentDays == 0 ? 'Desactivat' : '$currentDays dies',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: currentDays < 30 ? () => setState(() => currentDays++) : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
            ElevatedButton(
              onPressed: () async {
                await auth.updateProfile(diesAvisCaducitat: currentDays);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preferències actualitzades'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tancar sessió?'),
        content: const Text('Segur que vols sortir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sortir'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccountLocal(BuildContext context, AuthProvider auth) {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Eliminar compte?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aquesta acció és irreversible. Es perdran totes les teves dades.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              const Text('Introdueix la teva contrasenya per confirmar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contrasenya',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                if (password.isEmpty) return;
                Navigator.pop(context);
                passwordController.dispose();
                final success = await auth.deleteAccount(password: password);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.error ?? 'Error en eliminar el compte'), backgroundColor: AppColors.error),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccountGoogle(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar compte?'),
        content: const Text('Aquesta acció és irreversible. Es perdran totes les teves dades.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await auth.deleteAccount(password: '');
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(auth.error ?? 'Error en eliminar el compte'), backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}