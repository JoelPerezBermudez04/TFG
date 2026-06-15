import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../inventari/models/inventory_item_model.dart';
import '../../inventari/providers/inventory_provider.dart';
import '../providers/receptes_provider.dart';
import '../../llista_compra/screens/compra_screen.dart';

class ReceptaDetailScreen extends StatefulWidget {
  final String idApi;

  const ReceptaDetailScreen({super.key, required this.idApi});

  @override
  State<ReceptaDetailScreen> createState() => _ReceptaDetailScreenState();
}

class _ReceptaDetailScreenState extends State<ReceptaDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  bool _cookingInProgress = false;
  bool _descripcioExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    // Sync TabBar → PageViewx
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceptesProvider>().fetchDetall(widget.idApi);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
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
    final inventoryItems = context.watch<InventoryProvider>().items;
    final ingredientsAlInventari = recepta.ingredients
        .where((ing) => inventoryItems.any((item) => item.producte == ing.producte))
        .toList();
    final tenIngredients = ingredientsAlInventari.isNotEmpty;

    return Scaffold(
      bottomNavigationBar: tenIngredients
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _cookingInProgress
                      ? null
                      : () => _handleCuinar(context, recepta, inventoryItems),
                  icon: _cookingInProgress
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.outdoor_grill_outlined),
                  label: Text(
                    _cookingInProgress
                        ? 'Marcant ingredients...'
                        : 'Cuinar — marcar ${ingredientsAlInventari.length} ingredient${ingredientsAlInventari.length == 1 ? '' : 's'} com a consumit${ingredientsAlInventari.length == 1 ? '' : 's'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
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
                      _buildDescripcio(recepta.descripcio!),
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

              // ── Contingut amb swipe ──
              SizedBox(
                height: _estimatedTabHeight(recepta),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    _tabController.animateTo(index);
                  },
                  children: [
                    _buildIngredients(recepta),
                    _buildPreparacio(recepta),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    ),
    );
  }

  // Alçada aproximada per al PageView (evitar scroll infinit dins sliver)
  double _estimatedTabHeight(Recepta recepta) {
    final ingCount = recepta.ingredients.length;
    final noVinculatsCount = recepta.ingredientsNoVinculats?.length ?? 0;
    final stepCount = recepta.instruccions?.length ?? 0;
    final ingHeight = (ingCount + noVinculatsCount) * 65.0 + (noVinculatsCount > 0 ? 48 : 24);
    final stepHeight = stepCount * 80.0 + 32;
    return (ingHeight > stepHeight ? ingHeight : stepHeight).clamp(200.0, 2000.0);
  }

  // ── Lògica de compatibilitat d'unitats ──
  // Famílies: pes (g, kg), volum (ml, L), unitat (unitat, unitats)
  bool _unitatsCompatibles(String u1, String u2) {
    const pes = {'g', 'kg'};
    const volum = {'ml', 'L'};
    const unitat = {'unitat', 'unitats'};
    if (pes.contains(u1) && pes.contains(u2)) return true;
    if (volum.contains(u1) && volum.contains(u2)) return true;
    if (unitat.contains(u1) && unitat.contains(u2)) return true;
    return false;
  }

  // Converteix quantitat a la unitat base de la família
  double _aUnitatBase(double quantitat, String unitat) {
    if (unitat == 'kg') return quantitat * 1000; // → g
    if (unitat == 'L') return quantitat * 1000;  // → ml
    if (unitat == 'unitats') return quantitat;   // → unitat (equivalent)
    return quantitat; // g, ml, unitat: ja en base
  }

  String _unitatBase(String unitat) {
    if (unitat == 'kg') return 'g';
    if (unitat == 'L') return 'ml';
    if (unitat == 'unitats') return 'unitat';
    return unitat;
  }

  Future<void> _handleCuinar(BuildContext context, Recepta recepta,
      List<InventoryItem> inventoryItems) async {
    final inventory = context.read<InventoryProvider>();

    // Ingredients de la recepta que tenim al rebost
    final ingredientsAlInventari = recepta.ingredients
        .where((ing) => inventoryItems.any((item) => item.producte == ing.producte))
        .toList();

    if (ingredientsAlInventari.isEmpty) return;

    // Per cada ingredient, determinem l'acció: resta automàtica o diàleg
    // Resultat: llista de futures accions a executar
    // _CuinarAccio: tipus = 'resta' | 'elimina' | 'parcial' | 'deixar'
    final accions = <_CuinarAccio>[];

    for (final ing in ingredientsAlInventari) {
      final items = inventoryItems
          .where((item) => item.producte == ing.producte)
          .toList();

      // Si hi ha duplicats, preguntem quin vol fer servir
      InventoryItem? invItemTriat;
      if (items.length > 1) {
        if (!context.mounted) return;
        invItemTriat = await _mostrarDialegTriarItem(context, ing, items);
        if (invItemTriat == null) return; // cancel·lat
      } else {
        invItemTriat = items.first;
      }

      final invItem = invItemTriat;
      {
        if (_unitatsCompatibles(ing.unitat, invItem.unitat)) {
          // Convertim tot a unitat base per comparar
          final necessariBase = _aUnitatBase(ing.quantitat, ing.unitat);
          final tincsBase = _aUnitatBase(invItem.quantitat, invItem.unitat);
          final restaBase = tincsBase - necessariBase;

          if (restaBase <= 0) {
            // S'elimina tot
            accions.add(_CuinarAccio(
              item: invItem,
              ingredient: ing,
              tipus: _TipusAccio.elimina,
            ));
          } else {
            // Convertim la resta a la unitat original de l'inventari
            double novaQuantitat;
            if (invItem.unitat == 'kg') {
              novaQuantitat = restaBase / 1000;
            } else if (invItem.unitat == 'L') {
              novaQuantitat = restaBase / 1000;
            } else {
              novaQuantitat = restaBase;
            }
            accions.add(_CuinarAccio(
              item: invItem,
              ingredient: ing,
              tipus: _TipusAccio.resta,
              novaQuantitat: novaQuantitat,
            ));
          }
        } else {
          // Unitats incompatibles → necessita decisió de l'usuari
          accions.add(_CuinarAccio(
            item: invItem,
            ingredient: ing,
            tipus: _TipusAccio.incompatible,
          ));
        }
      }
    }

    // Mostrem resum + diàlegs per incompatibles
    if (!context.mounted) return;
    final accionsConfirmades = await _mostrarDialegCuinar(context, accions);
    if (accionsConfirmades == null || !context.mounted) return;

    setState(() => _cookingInProgress = true);

    int processats = 0;
    for (final accio in accionsConfirmades) {
      bool ok = false;
      if (accio.tipus == _TipusAccio.elimina) {
        ok = await inventory.deleteItem(accio.item.id);
      } else if (accio.tipus == _TipusAccio.resta && accio.novaQuantitat != null) {
        ok = await inventory.updateItem(
          accio.item.id,
          quantitat: accio.novaQuantitat!,
          unitat: accio.item.unitat,
          dataCaducitat: accio.item.dataCaducitat,
        );
      } else if (accio.tipus == _TipusAccio.parcial && accio.novaQuantitat != null) {
        if (accio.novaQuantitat! <= 0) {
          ok = await inventory.deleteItem(accio.item.id);
        } else {
          ok = await inventory.updateItem(
            accio.item.id,
            quantitat: accio.novaQuantitat!,
            unitat: accio.novaUnitat ?? accio.item.unitat,
            dataCaducitat: accio.item.dataCaducitat,
          );
        }
      }
      // _TipusAccio.deixar → no fem res
      if (ok || accio.tipus == _TipusAccio.deixar) processats++;
    }

    if (!context.mounted) return;
    setState(() => _cookingInProgress = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rebost actualitzat. Bon profit! 🍽️'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // Diàleg per triar quin duplicat de l'inventari fer servir
  Future<InventoryItem?> _mostrarDialegTriarItem(
      BuildContext context, ingredient, List<InventoryItem> items) async {
    final nom = ingredient.producteNom as String;
    final emoji = ingredient.producteEmoji as String;

    return showDialog<InventoryItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quin $nom vols fer servir?',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tens ${items.length} entrades d\'aquest producte al rebost. Tria quina vols consumir:',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final quantStr = item.quantitat % 1 == 0
                  ? item.quantitat.toInt().toString()
                  : item.quantitat.toStringAsFixed(1);
              final caducitat = item.dataCaducitat != null
                  ? 'Caduca: ${item.dataCaducitat!.day.toString().padLeft(2, '0')}/${item.dataCaducitat!.month.toString().padLeft(2, '0')}/${item.dataCaducitat!.year}'
                  : 'Sense data de caducitat';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$quantStr ${item.unitat}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    item.dataCaducitat != null
                                        ? Icons.event_outlined
                                        : Icons.event_busy_outlined,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    caducitat,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel·lar'),
          ),
        ],
      ),
    );
  }

  // Diàleg principal de cuinar: mostra resum i gestiona incompatibles
  Future<List<_CuinarAccio>?> _mostrarDialegCuinar(
      BuildContext context, List<_CuinarAccio> accions) async {
    // Separem automàtiques d'incompatibles
    final automatiques = accions.where((a) => a.tipus != _TipusAccio.incompatible).toList();
    final incompatibles = accions.where((a) => a.tipus == _TipusAccio.incompatible).toList();

    // Copiem la llista per poder modificar-la (decisions incompatibles)
    final resultat = List<_CuinarAccio>.from(automatiques);

    // Primer mostrem el diàleg resum
    final confirmat = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.outdoor_grill_outlined, size: 22),
            const SizedBox(width: 8),
            const Text('Cuinar recepta'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (automatiques.isNotEmpty) ...[
                Text(
                  'S\'actualitzaran automàticament:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...automatiques.map((a) {
                  final emoji = a.item.producteEmoji ?? '🛒';
                  final nom = a.item.producteNom ?? a.ingredient.producteNom;
                  if (a.tipus == _TipusAccio.elimina) {
                    return _resumFila(emoji, nom, 'S\'eliminarà del rebost', AppColors.error);
                  } else {
                    final quantStr = a.novaQuantitat! % 1 == 0
                        ? a.novaQuantitat!.toInt().toString()
                        : a.novaQuantitat!.toStringAsFixed(1);
                    return _resumFila(emoji, nom,
                        'Quedarà: $quantStr ${a.item.unitat}', AppColors.success);
                  }
                }),
              ],
              if (incompatibles.isNotEmpty) ...[
                if (automatiques.isNotEmpty) const SizedBox(height: 12),
                Text(
                  'Necessiten la teva decisió:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ...incompatibles.map((a) {
                  final emoji = a.item.producteEmoji ?? '🛒';
                  final nom = a.item.producteNom ?? a.ingredient.producteNom;
                  return _resumFila(emoji, nom,
                      'Unitats incompatibles (${a.item.unitat} vs ${a.ingredient.unitat})',
                      AppColors.warning);
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.outdoor_grill_outlined),
            label: Text(incompatibles.isNotEmpty ? 'Continuar' : 'Cuinar'),
          ),
        ],
      ),
    );

    if (confirmat != true || !context.mounted) return null;

    // Per cada incompatible, mostrem un diàleg individual
    for (final accio in incompatibles) {
      if (!context.mounted) return null;
      final decisio = await _mostrarDialegIncompatible(context, accio);
      if (decisio == null) return null; // cancel·lat
      resultat.add(decisio);
    }

    return resultat;
  }

  Future<_CuinarAccio?> _mostrarDialegIncompatible(
      BuildContext context, _CuinarAccio accio) async {
    final controller = TextEditingController();
    final nom = accio.item.producteNom ?? accio.ingredient.producteNom;
    final emoji = accio.item.producteEmoji ?? '🛒';
    final quantitatInventariStr = accio.item.quantitat % 1 == 0
        ? accio.item.quantitat.toInt().toString()
        : accio.item.quantitat.toStringAsFixed(1);
    final quantitatReceptaStr = accio.ingredient.quantitat % 1 == 0
        ? accio.ingredient.quantitat.toInt().toString()
        : accio.ingredient.quantitat.toString();

    const unitatsDisponibles = ['g', 'kg', 'ml', 'L', 'unitat', 'unitats'];
    String unitatSeleccionada = accio.item.unitat;

    return showDialog<_CuinarAccio>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('$emoji $nom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoPill('Al rebost', '$quantitatInventariStr ${accio.item.unitat}',
                  AppColors.primaryLight, AppColors.primary),
              const SizedBox(height: 6),
              _infoPill('Recepta demana', '$quantitatReceptaStr ${accio.ingredient.unitat}',
                  AppColors.accentLight, AppColors.accent),
              const SizedBox(height: 16),
              Text(
                'Les unitats no són compatibles. Quant et queda al rebost?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantitat restant',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: unitatSeleccionada,
                        items: unitatsDisponibles
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => unitatSeleccionada = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel·lar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                ctx,
                _CuinarAccio(
                  item: accio.item,
                  ingredient: accio.ingredient,
                  tipus: _TipusAccio.deixar,
                ),
              ),
              child: const Text('Deixar com està'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(
                ctx,
                _CuinarAccio(
                  item: accio.item,
                  ingredient: accio.ingredient,
                  tipus: _TipusAccio.elimina,
                ),
              ),
              child: const Text('Eliminar tot'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(
                    controller.text.replaceAll(',', '.'));
                if (val == null) return;
                Navigator.pop(
                  ctx,
                  _CuinarAccio(
                    item: accio.item,
                    ingredient: accio.ingredient,
                    tipus: _TipusAccio.parcial,
                    novaQuantitat: val,
                    novaUnitat: unitatSeleccionada,
                  ),
                );
              },
              child: const Text('Desar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumFila(String emoji, String nom, String detall, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(detall, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: fg),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // ── Descripció expandible ──
  static const _maxDescripcioChars = 200;

  Widget _buildDescripcio(String text) {
    final isCurt = text.length <= _maxDescripcioChars;
    final textMostrat = (!isCurt && !_descripcioExpanded)
        ? '${text.substring(0, _maxDescripcioChars).trimRight()}…'
        : text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textMostrat,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (!isCurt) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _descripcioExpanded = !_descripcioExpanded),
            child: Text(
              _descripcioExpanded ? 'Llegir menys ▲' : 'Llegir més ▼',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.separated(
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
    ),

        // ── Ingredients no vinculats al sistema ──
        if (recepta.ingredientsNoVinculats != null &&
            recepta.ingredientsNoVinculats!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'Ingredients no disponibles al sistema',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: recepta.ingredientsNoVinculats!.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, i) {
              final item = recepta.ingredientsNoVinculats![i];

              final nomOriginal =
                  item['original']?.toString() ??
                  item['nom']?.toString() ??
                  'Ingredient';

              final quantitat = item['quantitat'];
              final unitat = item['unitat']?.toString() ?? '';

              final quantitatText = quantitat != null
                  ? '$quantitat $unitat'
                  : unitat;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '❓',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        nomOriginal,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    Text(
                      quantitatText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
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

  static const _dietesInfo = {
    'Vegetarià': (emoji: '🥦', desc: 'No inclou carn ni peix, però sí ous, làctics i mel.'),
    'Vegà': (emoji: '🌱', desc: 'Exclou tots els productes d\'origen animal: carn, peix, ous, làctics i mel.'),
    'Lacto-ovo-vegetarià': (emoji: '🥚', desc: 'No inclou carn ni peix. Permet ous i productes làctics.'),
    'Pescatarià': (emoji: '🐟', desc: 'Exclou la carn però permet peix i marisc.'),
    'Sense gluten': (emoji: '🌾', desc: 'No conté blat, ordi, sègol ni espelta. Apta per a celíacs i sensibles al gluten.'),
    'Sense làctics': (emoji: '🥛', desc: 'No conté llet ni cap derivat làctic (formatge, iogurt, mantega...).'),
    'Cetogènica': (emoji: '🥑', desc: 'Molt baixa en carbohidrats i alta en greixos. Indueix la cetosi per cremar greix com a font d\'energia.'),
    'Paleolítica': (emoji: '🍖', desc: 'Basada en aliments no processats: carn, peix, fruita, verdura i fruits secs. Exclou cereals, llegums i làctics.'),
    'Primal': (emoji: '🫙', desc: 'Similar a la paleolítica però permet làctics d\'alta qualitat i alguns aliments fermentats.'),
    'Whole30': (emoji: '📅', desc: 'Programa de 30 dies que elimina sucre afegit, cereals, llegums, làctics i additius.'),
    'Baix en FODMAP': (emoji: '🔬', desc: 'Redueix els hidrats de carboni fermentables per alleujar símptomes de l\'intestí irritable.'),
    'Compatible amb FODMAP': (emoji: '✅', desc: 'Apta per a persones amb síndrome de l\'intestí irritable.'),
  };

  void _mostrarInfoDieta(String dieta) {
    final info = _dietesInfo[dieta];
    if (info == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text(
                dieta,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                info.desc,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tancar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dietaChip(String label, Color bg, Color fg) => GestureDetector(
        onLongPress: () => _mostrarInfoDieta(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
        ),
      );
}
// ── Models auxiliars per a la lògica de cuinar ──

enum _TipusAccio { resta, elimina, parcial, deixar, incompatible }

class _CuinarAccio {
  final InventoryItem item;
  final ingredient; // Ingredient de la recepta
  final _TipusAccio tipus;
  final double? novaQuantitat;
  final String? novaUnitat;

  const _CuinarAccio({
    required this.item,
    required this.ingredient,
    required this.tipus,
    this.novaQuantitat,
    this.novaUnitat,
  });
}