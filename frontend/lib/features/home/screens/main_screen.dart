import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/profile_screen.dart';
import '../../inventari/providers/inventory_provider.dart';
import '../../inventari/models/inventory_item_model.dart';
import '../../inventari/screens/inventory_screen.dart';
import '../../inventari/screens/product_detail_screen.dart';
import '../../inventari/screens/add_product_screen.dart';
import '../../inventari/widgets/product_image.dart';
import '../../receptes/providers/receptes_provider.dart';
import '../../receptes/screens/receptes_screen.dart';
import '../../receptes/screens/recepta_detail_screen.dart';
import '../../llista_compra/screens/compra_screen.dart';
import '../../llista_compra/providers/compra_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // Clau global per permetre la navegació cap a receptes des de qualsevol lloc
  static final GlobalKey<MainScreenState> navigatorKey = GlobalKey<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Navega a la tab de receptes i aplica un filtre per producte
  void switchToReceptesWithProducte(int producteId, String producteNom) {
    context.read<ReceptesProvider>().setProducte(producteId, producteNom);
    setState(() => _currentIndex = 2);
  }

  final List<Widget> _screens = [
    HomeScreen(),
    InventoryScreen(),
    ReceptesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().fetchInventory();
      context.read<CompraProvider>().fetchItems();
    });
  }

  bool get _mostrarIconaCompra => _currentIndex < 3;

  void _onTabSelected(int index) {
    // Refrescar l'inventari cada cop que es navega a la pestanya d'inici o rebost
    if (index == 0 || index == 1) {
      context.read<InventoryProvider>().fetchInventory();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pendents = context.watch<CompraProvider>().totalPendents;

    return Scaffold(
      appBar: _mostrarIconaCompra
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Llista de la compra',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CompraScreen()),
                    ),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            color: AppColors.textPrimary, size: 26),
                        if (pendents > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 17, minHeight: 17),
                              child: Text(
                                pendents > 99 ? '99+' : '$pendents',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
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
                const SizedBox(width: 56),
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
        onTap: () => _onTabSelected(index),
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

// ──────────────────────────────────────────────
// Model lleuger per a recomanacions a la home
// ──────────────────────────────────────────────
class _RecomanacioResumida {
  final String idApi;
  final String nom;
  final String? imatgeUrl;
  final int tempsPreparacio;
  final int porcions;
  final double score;
  final int ingredientsCoberts;
  final int totalIngredients;

  const _RecomanacioResumida({
    required this.idApi,
    required this.nom,
    this.imatgeUrl,
    required this.tempsPreparacio,
    required this.porcions,
    required this.score,
    required this.ingredientsCoberts,
    required this.totalIngredients,
  });

  factory _RecomanacioResumida.fromJson(Map<String, dynamic> j) =>
      _RecomanacioResumida(
        idApi: j['id_api'] as String,
        nom: j['nom'] as String,
        imatgeUrl: j['imatge_url'] as String?,
        tempsPreparacio: j['temps_preparacio'] as int,
        porcions: j['porcions'] as int,
        score: (j['score'] as num).toDouble(),
        ingredientsCoberts: j['ingredients_coberts'] as int,
        totalIngredients: j['total_ingredients'] as int,
      );
}

// ──────────────────────────────────────────────
// Pantalla principal
// ──────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.api});

  final ApiService? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ApiService _api;

  List<_RecomanacioResumida> _recomanacions = [];
  bool _loadingRec = false;
  String? _errorRec;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? ApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecomanacions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refrescar inventari quan l'app torna al primer pla
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<InventoryProvider>().fetchInventory();
    }
  }

  Future<void> _fetchRecomanacions() async {
    if (!mounted) return;
    setState(() {
      _loadingRec = true;
      _errorRec = null;
    });
    try {
      final response =
          await _api.get('${ApiConfig.inventory.replaceAll('inventari', 'recomanacions')}?limit=5');
      // endpoint: /recomanacions/
      if (response['statusCode'] == 200) {
        final body = response['body'];
        final results = (body['results'] ?? body) as List;
        setState(() {
          _recomanacions =
              results.map((e) => _RecomanacioResumida.fromJson(e as Map<String, dynamic>)).toList();
        });
      } else {
        setState(() => _errorRec = 'No s\'han pogut carregar les receptes');
      }
    } catch (_) {
      setState(() => _errorRec = 'Error de connexió');
    } finally {
      if (mounted) setState(() => _loadingRec = false);
    }
  }

  Future<void> _refresh() async {
    await context.read<InventoryProvider>().fetchInventory();
    await _fetchRecomanacions();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();
    final diesAvis = auth.user?.diesAvisCaducitat ?? 5;
    final username = auth.user?.username ?? '';

    // Productes urgents (caducat o caduca aviat)
    final urgents = inventory.items
        .where((i) =>
            i.expiryStatusFor(diesAvis) == ExpiryStatus.expired ||
            i.expiryStatusFor(diesAvis) == ExpiryStatus.urgent ||
            i.expiryStatusFor(diesAvis) == ExpiryStatus.soon)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──
            SliverAppBar(
              expandedHeight: 130,
              floating: true,
              snap: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _buildHeader(username),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Targetes resum ──
                  _buildSummaryCards(inventory, diesAvis),
                  const SizedBox(height: 28),

                  // ── Productes urgents ──
                  if (inventory.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (urgents.isNotEmpty) ...[
                    _sectionHeader(
                      '⚠️ Atenció al rebost',
                      subtitle: '${urgents.length} producte${urgents.length != 1 ? 's' : ''} requereix atenció',
                    ),
                    const SizedBox(height: 12),
                    ...urgents.take(5).map((item) => _buildUrgentCard(item, diesAvis)),
                    if (urgents.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const InventoryScreen()),
                          ),
                          child: Text(
                            'Veure tots (${urgents.length})',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                  ] else if (!inventory.isLoading && inventory.items.isEmpty) ...[
                    _buildEmptyInventory(),
                    const SizedBox(height: 28),
                  ] else ...[
                    _buildAllFreshBanner(),
                    const SizedBox(height: 28),
                  ],

                  // ── Recomanacions ──
                  _sectionHeader(
                    '🍳 Receptes recomanades',
                    subtitle: 'Basades en el teu rebost',
                  ),
                  const SizedBox(height: 12),
                  _buildRecomanacions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header amb salutació
  // ─────────────────────────────────────────────
  Widget _buildHeader(String username) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bon dia'
        : hour < 20
            ? 'Bona tarda'
            : 'Bona nit';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$greeting${username.isNotEmpty ? ', $username' : ''}! 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat("EEEE, d MMMM", 'ca').format(DateTime.now()),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Targetes de resum (total / urgents / caducats)
  // ─────────────────────────────────────────────
  Widget _buildSummaryCards(InventoryProvider inventory, int diesAvis) {
    final total = inventory.items.length;
    final urgents = inventory.items
        .where((i) =>
            i.expiryStatusFor(diesAvis) == ExpiryStatus.urgent ||
            i.expiryStatusFor(diesAvis) == ExpiryStatus.soon)
        .length;
    final caducats = inventory.items
        .where((i) => i.expiryStatusFor(diesAvis) == ExpiryStatus.expired)
        .length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.kitchen_outlined,
            value: '$total',
            label: 'Productes',
            color: AppColors.primary,
            bg: AppColors.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.schedule_outlined,
            value: '$urgents',
            label: 'Aviat',
            color: AppColors.expirySoonText,
            bg: AppColors.expirySoon,
            onTap: urgents > 0
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InventoryScreen(initialFilter: 'Aviat')),
                    )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.warning_amber_outlined,
            value: '$caducats',
            label: 'Caducats',
            color: AppColors.expiryUrgentText,
            bg: AppColors.expiryUrgent,
            onTap: caducats > 0
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InventoryScreen(initialFilter: 'Caducat')),
                    )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bg,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────
  Widget _sectionHeader(String title, {String? subtitle, Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Targeta de producte urgent
  // ─────────────────────────────────────────────
  Widget _buildUrgentCard(InventoryItem item, int diesAvis) {
    final (bg, textColor, label) = _statusDisplay(item, diesAvis);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(itemId: item.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: bg.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ProductImage(
              imatgeUrl: item.producteImatgeUrl,
              emoji: item.producteEmoji,
              size: 48,
              backgroundColor: bg.withOpacity(0.3),
              borderRadius: 10,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.producteNom ?? 'Producte',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.producteCategoriaNom ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantitat % 1 == 0 ? item.quantitat.toInt() : item.quantitat} ${item.unitat}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Banner tot fresc
  // ─────────────────────────────────────────────
  Widget _buildAllFreshBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.expiryFresh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tot en ordre!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expiryFreshText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cap producte caduca aviat. El rebost està perfecte.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.expiryFreshText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Rebost buit
  // ─────────────────────────────────────────────
  Widget _buildEmptyInventory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          const Text('🛒', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'El rebost és buit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Comença afegint productes al teu inventari',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Afegir producte'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Secció de recomanacions
  // ─────────────────────────────────────────────
  Widget _buildRecomanacions() {
    if (_loadingRec) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorRec != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorRec!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: _fetchRecomanacions,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_recomanacions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Text('📖', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Afegeix més productes al rebost per obtenir recomanacions de receptes.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recomanacions
          .map((rec) => _buildRecomanacioCard(rec))
          .toList(),
    );
  }

  Widget _buildRecomanacioCard(_RecomanacioResumida rec) {
    final pct = rec.totalIngredients > 0
        ? rec.ingredientsCoberts / rec.totalIngredients
        : 0.0;
    final pctLabel = '${rec.ingredientsCoberts}/${rec.totalIngredients} ingredients';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceptaDetailScreen(idApi: rec.idApi),
            ),
          ).then((_) {
            // Refrescar inventari i recomanacions quan es torna del detall
            if (mounted) {
              context.read<InventoryProvider>().fetchInventory();
              _fetchRecomanacions();
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Imatge o emoji
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: rec.imatgeUrl != null && rec.imatgeUrl!.isNotEmpty
                      ? Image.network(
                          rec.imatgeUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('🍽️', style: TextStyle(fontSize: 28)),
                          ),
                        )
                      : const Center(
                          child: Text('🍽️', style: TextStyle(fontSize: 28)),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.nom,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            '${rec.tempsPreparacio} min',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.people_outline, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            '${rec.porcions} p.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Barra de cobertura d'ingredients
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 1.0
                                ? AppColors.success
                                : pct >= 0.5
                                    ? AppColors.expirySoonText
                                    : AppColors.textMuted,
                          ),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pctLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helper: estat de caducitat
  // ─────────────────────────────────────────────
  (Color, Color, String) _statusDisplay(InventoryItem item, int diesAvis) {
    switch (item.expiryStatusFor(diesAvis)) {
      case ExpiryStatus.expired:
        return (AppColors.expiryUrgent, AppColors.expiryUrgentText, 'Caducat');
      case ExpiryStatus.urgent:
        final d = item.daysUntilExpiry;
        return (
          AppColors.expiryUrgent,
          AppColors.expiryUrgentText,
          d == 0 ? 'Avui!' : d == 1 ? 'Demà' : 'En $d dies',
        );
      case ExpiryStatus.soon:
        return (
          AppColors.expirySoon,
          AppColors.expirySoonText,
          'En ${item.daysUntilExpiry} dies',
        );
      case ExpiryStatus.fresh:
        return (AppColors.expiryFresh, AppColors.expiryFreshText, 'Fresc');
      case ExpiryStatus.none:
        return (AppColors.primaryLight, AppColors.primary, 'Sense data');
    }
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