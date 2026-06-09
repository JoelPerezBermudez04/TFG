import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/config/api_config.dart';
import '../../products/models/product_model.dart';
import '../models/compra_item_model.dart';
import '../providers/compra_provider.dart';
import '../../inventari/screens/add_product_screen.dart';
import '../../inventari/widgets/product_image.dart';

class CompraScreen extends StatefulWidget {
  const CompraScreen({super.key});

  @override
  State<CompraScreen> createState() => _CompraScreenState();
}

class _CompraScreenState extends State<CompraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompraProvider>().fetchItems();
    });
  }

  // Agrupa una llista d'items per categoria, mantenint l'ordre d'aparició
  Map<String, List<CompraItem>> _agrupaPorCategoria(List<CompraItem> items) {
    final mapa = <String, List<CompraItem>>{};
    for (final item in items) {
      final clau = item.categoriaNom ?? 'Altres';
      mapa.putIfAbsent(clau, () => []).add(item);
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompraProvider>();
    final pendents = provider.pendents;
    final comprats = provider.comprats;
    final pendentsPerCategoria = _agrupaPorCategoria(pendents);
    final compratsPerCategoria = _agrupaPorCategoria(comprats);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Llista de la compra'),
        actions: [
          if (comprats.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmDeleteComprats(context, provider),
              icon: const Icon(Icons.delete_sweep_outlined,
                  size: 18, color: AppColors.textSecondary),
              label: const Text(
                'Netejar',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
              ? _buildEmpty(context)
              : RefreshIndicator(
                  onRefresh: provider.fetchItems,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      // ── Pendents per categoria ──
                      if (pendents.isNotEmpty) ...[
                        _sectionLabel('Per comprar (${pendents.length})'),
                        const SizedBox(height: 12),
                        for (final entry in pendentsPerCategoria.entries) ...[
                          _categoryLabel(
                            entry.key,
                            pendents
                                .firstWhere((i) => (i.categoriaNom ?? 'Altres') == entry.key)
                                .categoriaEmoji,
                          ),
                          const SizedBox(height: 6),
                          ...entry.value.map((item) => _CompraItemTile(
                            item: item,
                            onMarcarComprat: _showAfegirARebostDialog,
                          )),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // ── Comprats per categoria ──
                      if (comprats.isNotEmpty) ...[
                        _sectionLabel('Ja comprat (${comprats.length})'),
                        const SizedBox(height: 12),
                        for (final entry in compratsPerCategoria.entries) ...[
                          _categoryLabel(
                            entry.key,
                            comprats
                                .firstWhere((i) => (i.categoriaNom ?? 'Altres') == entry.key)
                                .categoriaEmoji,
                          ),
                          const SizedBox(height: 6),
                          ...entry.value.map((item) => _CompraItemTile(item: item)),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddManualDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Afegir producte'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _categoryLabel(String nom, String? emoji) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
          ],
          Text(
            nom,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade200, height: 1)),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'La llista és buida',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Afegeix productes manualment o des d\'una recepta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddManualDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Afegir producte'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteComprats(
      BuildContext context, CompraProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Netejar comprats'),
        content: const Text(
            'S\'eliminaran tots els productes marcats com a comprats.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel·lar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteAllComprats();
    }
  }

  void _showAddManualDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddManualSheet(),
    );
  }

  void _showAfegirARebostDialog(CompraItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.producteNom ?? 'Producte',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Text(
          'Vols afegir aquest producte al rebost?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Ara no',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddProductScreen(
                    producteIdInicial: item.producte,
                    quantitatInicial: item.quantitat,
                    unitatInicial: item.unitat,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Afegir al rebost'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tile d'un item de la llista
// ─────────────────────────────────────────────
class _CompraItemTile extends StatefulWidget {
  final CompraItem item;
  final void Function(CompraItem)? onMarcarComprat;

  const _CompraItemTile({required this.item, this.onMarcarComprat});

  @override
  State<_CompraItemTile> createState() => _CompraItemTileState();
}

class _CompraItemTileState extends State<_CompraItemTile> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<CompraProvider>();
    final item = widget.item;
    final quantitatStr = item.quantitat % 1 == 0
        ? item.quantitat.toInt().toString()
        : item.quantitat.toString();

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => provider.deleteItem(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: item.comprat
              ? AppColors.surface.withOpacity(0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: item.comprat
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Imatge del producte
              Opacity(
                opacity: item.comprat ? 0.4 : 1.0,
                child: ProductImage(
                  imatgeUrl: item.producteImatgeUrl,
                  emoji: item.producteEmoji ?? '🛒',
                  size: 48,
                  backgroundColor: AppColors.primaryLight,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 12),
              // Nom i quantitat
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCompraItemScreen(item: item),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.producteNom ?? 'Producte',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: item.comprat
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration: item.comprat
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$quantitatStr ${item.unitat}',
                        style: TextStyle(
                          fontSize: 13,
                          color: item.comprat
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Check circle
              GestureDetector(
                onTap: () async {
                  final estavaComprat = widget.item.comprat;
                  final itemCaptura = widget.item;
                  final onMarcarComprat = widget.onMarcarComprat;
                  final provider = context.read<CompraProvider>();
                  await provider.toggleComprat(itemCaptura.id);
                  if (!estavaComprat) {
                    onMarcarComprat?.call(itemCaptura);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.comprat
                        ? AppColors.success
                        : Colors.transparent,
                    border: Border.all(
                      color: item.comprat
                          ? AppColors.success
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: item.comprat
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
// Bottom sheet per afegir manualment
// ─────────────────────────────────────────────
class _AddManualSheet extends StatefulWidget {
  const _AddManualSheet();

  @override
  State<_AddManualSheet> createState() => _AddManualSheetState();
}

class _AddManualSheetState extends State<_AddManualSheet> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  static const _unitOptions = ['unitat', 'g', 'kg', 'ml', 'L'];

  List<Product> _results = [];
  bool _searching = false;
  Product? _selected;
  String _selectedUnit = 'unitat';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await _api
          .get('${ApiConfig.products}?cerca=${Uri.encodeComponent(query)}');
      if (response['statusCode'] == 200) {
        setState(() {
          _results = (response['body'] as List)
              .map((j) => Product.fromJson(j))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _searching = false);
  }

  Future<void> _handleAdd() async {
    if (_selected == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<CompraProvider>();
    final ok = await provider.addItem(
      producteId: _selected!.id,
      quantitat: double.parse(_quantityController.text.replaceAll(',', '.')),
      unitat: _selectedUnit,
    );
    setState(() => _saving = false);

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selected!.nom} afegit a la llista'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      final errorRaw = provider.error ?? '';
      final missatge = (errorRaw.toLowerCase().contains('ja') ||
              errorRaw.toLowerCase().contains('exist') ||
              errorRaw.toLowerCase().contains('unique') ||
              errorRaw.toLowerCase().contains('duplicate'))
          ? 'Aquest producte ja és a la llista de la compra'
          : errorRaw.isNotEmpty
              ? errorRaw
              : 'Error afegint producte';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missatge),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Afegir a la llista',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Cerca
            if (_selected == null) ...[
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cerca un producte...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: (v) => _search(v),
              ),
              const SizedBox(height: 8),
              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: Text(p.emoji,
                            style: const TextStyle(fontSize: 22)),
                        title: Text(p.nom,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary)),
                        subtitle: p.categoriaNom != null
                            ? Text(p.categoriaNom!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary))
                            : null,
                        onTap: () {
                          setState(() {
                            _selected = p;
                            // Pre-seleccionar unitat amb sugerència del producte
                            if (p.diesCaducitatAprox != null) {
                              _selectedUnit = 'unitat';
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
            ] else ...[
              // Producte seleccionat
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(_selected!.emoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selected!.nom,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selected = null),
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantitat i unitat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantitat'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatori';
                        final parsed =
                            double.tryParse(v.replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0) return 'Invàlid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unitat'),
                      items: _unitOptions
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedUnit = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleAdd,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Afegir a la llista'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widget reutilitzable: botó per afegir
// ingredients d'una recepta a la llista
// (s'usa des de recepta_detail_screen.dart)
// ─────────────────────────────────────────────
class AddToCompraButton extends StatefulWidget {
  /// Ingredients de la recepta: [{producte, quantitat, unitat}]
  final List<Map<String, dynamic>> ingredients;
  /// Ingredients que ja estan a l'inventari (IDs de producte)
  final Set<int> inventariIds;

  const AddToCompraButton({
    super.key,
    required this.ingredients,
    required this.inventariIds,
  });

  @override
  State<AddToCompraButton> createState() => _AddToCompraButtonState();
}

class _AddToCompraButtonState extends State<AddToCompraButton> {
  bool _loading = false;

  List<Map<String, dynamic>> get _mancants => widget.ingredients
      .where((i) => !widget.inventariIds.contains(i['producte'] as int))
      .toList();

  @override
  Widget build(BuildContext context) {
    final total = widget.ingredients.length;
    final mancants = _mancants.length;

    return OutlinedButton.icon(
      onPressed: _loading ? null : () => _showSelector(context),
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.add_shopping_cart_outlined),
      label: Text(
        mancants > 0
            ? 'Afegir a la compra ($mancants falten)'
            : 'Afegir tots a la compra',
      ),
    );
  }

  void _showSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IngredientSelectorSheet(
        ingredients: widget.ingredients,
        inventariIds: widget.inventariIds,
        onConfirm: (selected) async {
          setState(() => _loading = true);
          final provider = context.read<CompraProvider>();
          final added = await provider.addMultiple(selected);
          setState(() => _loading = false);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(added > 0
                    ? '$added ingredient${added != 1 ? 's' : ''} afegit${added != 1 ? 's' : ''} a la llista'
                    : 'No s\'ha pogut afegir cap ingredient'),
                backgroundColor:
                    added > 0 ? AppColors.success : AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom sheet selector d'ingredients
// ─────────────────────────────────────────────
class _IngredientSelectorSheet extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  final Set<int> inventariIds;
  final Future<void> Function(List<Map<String, dynamic>>) onConfirm;

  const _IngredientSelectorSheet({
    required this.ingredients,
    required this.inventariIds,
    required this.onConfirm,
  });

  @override
  State<_IngredientSelectorSheet> createState() =>
      _IngredientSelectorSheetState();
}

class _IngredientSelectorSheetState
    extends State<_IngredientSelectorSheet> {
  late Set<int> _selected; // índexs seleccionats
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Per defecte selecciona els que no estan a l'inventari
    _selected = widget.ingredients
        .asMap()
        .entries
        .where((e) =>
            !widget.inventariIds.contains(e.value['producte'] as int))
        .map((e) => e.key)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Afegir a la llista de la compra',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Selecciona els ingredients que vols afegir',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == widget.ingredients.length) {
                      _selected = {};
                    } else {
                      _selected =
                          Set.from(Iterable.generate(widget.ingredients.length));
                    }
                  });
                },
                child: Text(
                  _selected.length == widget.ingredients.length
                      ? 'Cap'
                      : 'Tots',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.ingredients.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final ing = widget.ingredients[i];
                final producteId = ing['producte'] as int;
                final alInventari =
                    widget.inventariIds.contains(producteId);
                final isSelected = _selected.contains(i);
                final quantitatStr =
                    (ing['quantitat'] as double) % 1 == 0
                        ? (ing['quantitat'] as double).toInt().toString()
                        : (ing['quantitat'] as double).toString();

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(i);
                      } else {
                        _selected.remove(i);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Row(
                    children: [
                      Text(
                        ing['producte_emoji'] as String? ?? '🛒',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ing['producte_nom'] as String? ?? 'Producte',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (alInventari)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Al rebost',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '$quantitatStr ${ing['unitat']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || _selected.isEmpty
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      final toAdd = _selected
                          .map((i) => widget.ingredients[i])
                          .toList();
                      Navigator.pop(context);
                      await widget.onConfirm(toAdd);
                    },
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _selected.isEmpty
                          ? 'Selecciona ingredients'
                          : 'Afegir ${_selected.length} ingredient${_selected.length != 1 ? 's' : ''}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pantalla d'edició d'un item de la compra
// ─────────────────────────────────────────────
class EditCompraItemScreen extends StatefulWidget {
  final CompraItem item;

  const EditCompraItemScreen({super.key, required this.item});

  @override
  State<EditCompraItemScreen> createState() => _EditCompraItemScreenState();
}

class _EditCompraItemScreenState extends State<EditCompraItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantityController;
  late String _selectedUnit;

  static const _unitOptions = ['unitat', 'g', 'kg', 'ml', 'L'];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantitat % 1 == 0
          ? widget.item.quantitat.toInt().toString()
          : widget.item.quantitat.toString(),
    );
    _selectedUnit = _unitOptions.contains(widget.item.unitat)
        ? widget.item.unitat
        : 'unitat';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final api = ApiService();
    final quantitat =
        double.parse(_quantityController.text.replaceAll(',', '.'));

    try {
      final response = await api.patch('/compra/${widget.item.id}/', {
        'quantitat': quantitat,
        'unitat': _selectedUnit,
      });

      if (mounted) {
        if (response['statusCode'] == 200) {
          await context.read<CompraProvider>().fetchItems();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producte actualitzat'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error actualitzant el producte'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de connexió'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.producteNom ?? 'Editar'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Capçalera amb imatge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ProductImage(
                    imatgeUrl: widget.item.producteImatgeUrl,
                    emoji: widget.item.producteEmoji ?? '🛒',
                    size: 56,
                    backgroundColor: Colors.white.withOpacity(0.6),
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.producteNom ?? 'Producte',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Edita la quantitat de la llista',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Quantitat',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: '1'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Obligatori';
                      final parsed =
                          double.tryParse(value.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) return 'Valor invàlid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(),
                    items: _unitOptions
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedUnit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _handleSave,
              child: const Text('Guardar canvis'),
            ),
          ],
        ),
      ),
    );
  }
}