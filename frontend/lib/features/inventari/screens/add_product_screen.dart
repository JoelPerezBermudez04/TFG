import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/models/product_model.dart';
import '../models/inventory_item_model.dart';
import '../widgets/product_image.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  Product? _selectedProduct;
  String _selectedUnit = 'unitat';
  DateTime? _expiryDate;

  static const _pluralMap = {
    'unitat': 'unitats',
    'unitats': 'unitats',
  };

  static const _unitBases = ['g', 'kg', 'ml', 'L', 'unitat'];

  String get _resolvedUnit {
    final qty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    if (_pluralMap.containsKey(_selectedUnit)) {
      return qty == 1 ? 'unitat' : 'unitats';
    }
    return _selectedUnit;
  }

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _handleSubmit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un producte primer'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final inventory = context.read<InventoryProvider>();
    final qty = double.parse(_quantityController.text.replaceAll(',', '.'));

    final existing = inventory.items
        .where((i) => i.producte == _selectedProduct!.id)
        .firstOrNull;

    if (existing != null && mounted) {
      final update = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Producte ja al rebost'),
          content: Text(
            '"${_selectedProduct!.nom}" ja està al teu rebost '
            '(${existing.quantitat % 1 == 0 ? existing.quantitat.toInt() : existing.quantitat} ${existing.unitat}).\n\n'
            'Vols actualitzar la quantitat i la data de caducitat?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Actualitzar'),
            ),
          ],
        ),
      );

      if (update != true) return;

      final success = await inventory.updateItem(
        existing.id,
        quantitat: qty,
        unitat: _resolvedUnit,
        dataCaducitat: _expiryDate,
        clearDate: _expiryDate == null,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producte actualitzat al rebost'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(inventory.error ?? 'Error actualitzant producte'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    final success = await inventory.addItem(
      producteId: _selectedProduct!.id,
      quantitat: qty,
      unitat: _resolvedUnit,
      dataCaducitat: _expiryDate,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producte afegit al rebost'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inventory.error ?? 'Error afegint producte'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Afegir producte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionLabel('Producte'),
            const SizedBox(height: 8),

            if (_selectedProduct != null)
              _buildSelectedProduct()
            else ...[
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cercar producte...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  if (value.length >= 2) {
                    context.read<ProductsProvider>().fetchProducts(cerca: value);
                  } else if (value.isEmpty) {
                    context.read<ProductsProvider>().clearProducts();
                  }
                  setState(() {});
                },
              ),
              if (_searchController.text.length >= 2) ...[
                const SizedBox(height: 8),
                _buildProductDropdown(products),
              ],
            ],
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Quantitat'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '1'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Obligatori';
                          final parsed = double.tryParse(value.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Valor invàlid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Unitat'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(),
                        items: _unitBases.map((u) {
                          final qty = double.tryParse(
                                _quantityController.text.replaceAll(',', '.'),
                              ) ??
                              1;
                          final display = (u == 'unitat' && qty != 1)
                              ? 'unitats'
                              : u;
                          return DropdownMenuItem(value: u, child: Text(display));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedUnit = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionLabel('Data de caducitat'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _expiryDate != null
                            ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                            : 'Seleccionar data (opcional)',
                        style: TextStyle(
                          color: _expiryDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_expiryDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiryDate = null),
                        child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Consumer<InventoryProvider>(
              builder: (context, inventory, _) => ElevatedButton(
                onPressed: inventory.isLoading ? null : _handleSubmit,
                child: inventory.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Afegir al rebost'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  Widget _buildSelectedProduct() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ProductImage(
            imatgeUrl: _selectedProduct!.imatgeUrl,
            emoji: _selectedProduct!.emoji,
            size: 48,
            backgroundColor: Colors.white.withOpacity(0.6),
            borderRadius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedProduct!.nom,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_selectedProduct!.categoriaNom != null)
                  Text(
                    _selectedProduct!.categoriaNom!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () {
              setState(() {
                _selectedProduct = null;
                _searchController.clear();
                context.read<ProductsProvider>().clearProducts();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdown(ProductsProvider products) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: products.isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          : products.products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No s\'han trobat productes',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: products.products.length,
                  itemBuilder: (context, index) {
                    final product = products.products[index];
                    return ListTile(
                      leading: ProductImage(
                        imatgeUrl: product.imatgeUrl,
                        emoji: product.emoji,
                        size: 40,
                        backgroundColor: AppColors.primaryLight,
                        borderRadius: 8,
                      ),
                      title: Text(product.nom),
                      subtitle: product.categoriaNom != null
                          ? Text(product.categoriaNom!,
                              style: const TextStyle(fontSize: 12))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProduct = product;
                          _searchController.clear();
                        });
                        context.read<ProductsProvider>().clearProducts();
                      },
                    );
                  },
                ),
    );
  }
}