import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _HomePlaceholder(),
    _InventoryPlaceholder(),
    _RecipesPlaceholder(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Afegir producte — pròximament')),
          );
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.surface,
        elevation: 8,
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Inici'),
                _buildNavItem(1, Icons.kitchen_outlined, Icons.kitchen, 'Rebost'),
                const SizedBox(width: 56), // Espai per al FAB
                _buildNavItem(2, Icons.menu_book_outlined, Icons.menu_book, 'Receptes'),
                _buildNavItem(3, Icons.person_outline, Icons.person, 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏠', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Inici', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Pròximament', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _InventoryPlaceholder extends StatelessWidget {
  const _InventoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧺', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Rebost', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Pròximament', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RecipesPlaceholder extends StatelessWidget {
  const _RecipesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📖', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Receptes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('Pròximament', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}