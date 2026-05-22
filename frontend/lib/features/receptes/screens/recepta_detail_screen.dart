import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../inventari/providers/inventory_provider.dart';
import '../providers/receptes_provider.dart';
import '../../llista_compra/screens/compra_screen.dart';
import '../../llista_compra/providers/compra_provider.dart';

class ReceptaDetailScreen extends StatefulWidget {
  final String idApi;

  const ReceptaDetailScreen({super.key, required this.idApi});

  @override
  State<ReceptaDetailScreen> createState() => _ReceptaDetailScreenState();
}

class _ReceptaDetailScreenState extends State<ReceptaDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceptesProvider>().fetchDetall(widget.idApi);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceptesProvider>();
    final recepta = provider.receptaDetall;
    final loading = provider.loadingDetall;
    final esFav = provider.esFavorit(widget.idApi);
    final toggling = provider.isToggling(widget.idApi);

    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : recepta == null
              ? _buildError(context)
              : _buildContent(context, recepta, esFav, toggling),
    );
  }

  Widget _buildError(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No s\'ha pogut carregar la recepta',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.read<ReceptesProvider>().fetchDetall(widget.idApi),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Recepta recepta, bool esFav, bool toggling) {
    return CustomScrollView(
      slivers: [
        // ── SliverAppBar amb imatge ──
        SliverAppBar(
          expandedHeight: recepta.imatgeUrl != null ? 260 : 120,
          pinned: true,
          backgroundColor: AppColors.background,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: toggling
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          esFav ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(esFav),
                          color: esFav ? AppColors.error : AppColors.textPrimary,
                          size: 26,
                        ),
                      ),
                      onPressed: () =>
                          context.read<ReceptesProvider>().toggleFavorit(widget.idApi),
                    ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: recepta.imatgeUrl != null && recepta.imatgeUrl!.isNotEmpty
                ? Image.network(
                    recepta.imatgeUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imatgePlaceholder(),
                  )
                : _imatgePlaceholder(),
          ),
        ),

        // ── Contingut ──
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Títol
                    Text(
                      recepta.nom,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Meta xips
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _metaChip(Icons.schedule_outlined,
                            '${recepta.tempsPreparacio} min'),
                        _metaChip(
                            Icons.people_outline, '${recepta.porcions} porcions'),
                        _metaChip(Icons.restaurant_outlined,
                            '${recepta.ingredients.length} ingredients'),
                      ],
                    ),

                    // Dietes
                    if (recepta.dietes != null && recepta.dietes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recepta.dietes!
                            .map((d) => _dietaChip(d, AppColors.primaryLight,
                                AppColors.primary))
                            .toList(),
                      ),
                    ],

                    // Intoleràncies
                    if (recepta.intolerancias != null &&
                        recepta.intolerancias!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recepta.intolerancias!
                            .map((i) => _dietaChip(
                                'Sense $i',
                                AppColors.accentLight,
                                AppColors.accent))
                            .toList(),
                      ),
                    ],

                    // Descripció
                    if (recepta.descripcio != null &&
                        recepta.descripcio!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        recepta.descripcio!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],

                    // ── Botó afegir a la compra ──
                    if (recepta.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final inventoryItems =
                              context.watch<InventoryProvider>().items;
                          final inventariIds = inventoryItems
                              .map((i) => i.producte)
                              .toSet();
                          final ingredients = recepta.ingredients
                              .map((ing) => {
                                    'producte': ing.producte,
                                    'quantitat': ing.quantitat,
                                    'unitat': ing.unitat,
                                    'producte_nom': ing.producteNom,
                                    'producte_emoji': ing.producteEmoji,
                                  })
                              .toList();
                          return SizedBox(
                            width: double.infinity,
                            child: AddToCompraButton(
                              ingredients: ingredients,
                              inventariIds: inventariIds,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Tabs: Ingredients / Preparació ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Ingredients (${recepta.ingredients.length})'),
                    Tab(
                        text: recepta.instruccions != null
                            ? 'Preparació (${recepta.instruccions!.length})'
                            : 'Preparació'),
                  ],
                ),
              ),

              // ── Tab: Ingredients ──
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  if (_tabController.index == 0) {
                    return _buildIngredients(recepta);
                  } else {
                    return _buildPreparacio(recepta);
                  }
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredients(Recepta recepta) {
    if (recepta.ingredients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Sense ingredients disponibles',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final inventoryItems = context.watch<InventoryProvider>().items;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: recepta.ingredients.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, i) {
        final ing = recepta.ingredients[i];
        final quantitatStr = ing.quantitat % 1 == 0
            ? ing.quantitat.toInt().toString()
            : ing.quantitat.toString();

        // Cerquem si el producte és a l'inventari
        final inventariItems = inventoryItems
            .where((item) => item.producte == ing.producte)
            .toList();
        final quantitatInventari = inventariItems.isNotEmpty
            ? inventariItems.map((item) => item.quantitat).reduce((a, b) => a + b)
            : null;
        final unitatInventari =
            inventariItems.isNotEmpty ? inventariItems.first.unitat : null;
        final teAlInventari = quantitatInventari != null;
        final quantitatInventariStr = quantitatInventari != null
            ? (quantitatInventari % 1 == 0
                ? quantitatInventari.toInt().toString()
                : quantitatInventari.toStringAsFixed(1))
            : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Emoji / imatge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: teAlInventari ? AppColors.primaryLight : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: ing.producteImatgeUrl != null && ing.producteImatgeUrl!.isNotEmpty
                    ? Image.network(
                        ing.producteImatgeUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(ing.producteEmoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      )
                    : Center(
                        child: Text(ing.producteEmoji,
                            style: const TextStyle(fontSize: 22)),
                      ),
              ),
              const SizedBox(width: 12),
              // Nom + quantitat inventari
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ing.producteNom.isNotEmpty ? ing.producteNom : ing.nomOriginal,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    ),
                    if (teAlInventari) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.kitchen_outlined,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            'Tens $quantitatInventariStr $unitatInventari',
                            style: const TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Quantitat necessària + check
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$quantitatStr ${ing.unitat}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    teAlInventari ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: teAlInventari ? AppColors.success : AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreparacio(Recepta recepta) {
    final instruccions = recepta.instruccions;

    if (instruccions == null || instruccions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Instruccions no disponibles',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: instruccions.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Número del pas
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    instruccions[i],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imatgePlaceholder() => Container(
        color: AppColors.primaryLight,
        child: const Center(
          child: Text('🍽️', style: TextStyle(fontSize: 56)),
        ),
      );

  Widget _metaChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _dietaChip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      );
}